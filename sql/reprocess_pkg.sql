CREATE OR REPLACE PACKAGE uds_reprocess_pkg AS
  PROCEDURE reprocess_rejected_last_hour(
    p_recipients   IN VARCHAR2,          -- e.g. 'a,b,c,d,e' or emails if available
    p_minutes_back IN NUMBER DEFAULT 60, -- past hour = 60 minutes
    p_run_id       IN VARCHAR2 DEFAULT NULL
  );
END uds_reprocess_pkg;
/
SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY uds_reprocess_pkg AS

  -- Send email via UTL_MAIL if available; otherwise log content into uds_email_log
  PROCEDURE send_or_log_email(
    p_run_id      IN VARCHAR2,
    p_recipients  IN VARCHAR2,
    p_subject     IN VARCHAR2,
    p_body        IN CLOB
  ) IS
  BEGIN
    -- Dynamic call avoids compile-time dependency if UTL_MAIL is not granted.
    BEGIN
      EXECUTE IMMEDIATE
        'BEGIN UTL_MAIL.SEND(sender => :sender, recipients => :rcpt, subject => :subj, message => :msg); END;'
        USING 'no-reply@oracle.local', p_recipients, p_subject, DBMS_LOB.SUBSTR(p_body, 32000, 1);
    EXCEPTION
      WHEN OTHERS THEN
        INSERT INTO uds_email_log(run_id, created_ts, recipients, subject, body)
        VALUES (p_run_id, SYSTIMESTAMP, p_recipients, p_subject, p_body);
        COMMIT;
    END;
  END send_or_log_email;

  PROCEDURE reprocess_rejected_last_hour(
    p_recipients   IN VARCHAR2,
    p_minutes_back IN NUMBER DEFAULT 60,
    p_run_id       IN VARCHAR2 DEFAULT NULL
  ) IS
    TYPE t_vc_tab IS TABLE OF VARCHAR2(4000);

    v_run_id      VARCHAR2(64) := NVL(p_run_id, RAWTOHEX(SYS_GUID()));
    v_cutoff      DATE := SYSDATE - (p_minutes_back / 1440);

    v_ref_ids     t_vc_tab;
    v_actions     t_vc_tab;
    v_statuses    t_vc_tab;
    v_req_dates   SYS.ODCIDATELIST;

    v_count       PLS_INTEGER := 0;

    v_subject     VARCHAR2(500);
    v_body        CLOB;
  BEGIN
    -- Update rejected records back to queued for reprocessing
    UPDATE UPDATE_DOWNSTREAMS
       SET STATUS_V = 'Q'
     WHERE STATUS_V = 'R'
       AND REQ_DATE >= v_cutoff
     RETURNING REF_ID_V, ACTION_V, STATUS_V, REQ_DATE
          BULK COLLECT INTO v_ref_ids, v_actions, v_statuses, v_req_dates;

    v_count := SQL%ROWCOUNT;

    -- Persist audit log of updated records
    IF v_count > 0 THEN
      FORALL i IN 1 .. v_ref_ids.COUNT
        INSERT INTO uds_reprocess_log(
          run_id, processed_ts, ref_id_v, action_v, old_status_v, new_status_v, req_date
        )
        VALUES(
          v_run_id, SYSTIMESTAMP, v_ref_ids(i), v_actions(i), 'R', v_statuses(i), v_req_dates(i)
        );

      COMMIT;
    END IF;

    -- Build email subject/body
    v_subject := 'Downstream Reprocess Report - Last ' || p_minutes_back || ' minutes';

    v_body := 'Run ID: ' || v_run_id || CHR(10) ||
              'Time Window: last ' || p_minutes_back || ' minutes (cutoff=' ||
              TO_CHAR(v_cutoff, 'YYYY-MM-DD HH24:MI:SS') || ')' || CHR(10) ||
              'Updated records (R -> Q): ' || v_count || CHR(10) || CHR(10);

    IF v_count = 0 THEN
      v_body := v_body || 'No rejected records found in the given window.' || CHR(10);
    ELSE
      v_body := v_body || 'Details:' || CHR(10) ||
                'REF_ID_V | ACTION_V | STATUS_AFTER | REQ_DATE' || CHR(10) ||
                '--------------------------------------------------------' || CHR(10);

      FOR i IN 1 .. v_ref_ids.COUNT LOOP
        v_body := v_body ||
                  v_ref_ids(i) || ' | ' ||
                  NVL(v_actions(i), '-') || ' | ' ||
                  NVL(v_statuses(i), '-') || ' | ' ||
                  TO_CHAR(v_req_dates(i), 'YYYY-MM-DD HH24:MI:SS') || CHR(10);
      END LOOP;
    END IF;

    -- Send email or log it
    send_or_log_email(
      p_run_id     => v_run_id,
      p_recipients => p_recipients,
      p_subject    => v_subject,
      p_body       => v_body
    );
  END reprocess_rejected_last_hour;

END uds_reprocess_pkg;
/
SHOW ERRORS;
