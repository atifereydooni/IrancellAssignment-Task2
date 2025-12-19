-- Log of updated rows (audit trail)
CREATE TABLE uds_reprocess_log (
  run_id            VARCHAR2(64)   NOT NULL,
  processed_ts      TIMESTAMP      NOT NULL,
  ref_id_v          VARCHAR2(200)  NOT NULL,
  action_v          VARCHAR2(100)  NULL,
  old_status_v      VARCHAR2(1)    NOT NULL,
  new_status_v      VARCHAR2(1)    NOT NULL,
  req_date          DATE           NULL
);

CREATE INDEX idx_uds_reprocess_log_1 ON uds_reprocess_log (run_id, processed_ts);

-- Email log (for environments without UTL_MAIL)
CREATE TABLE uds_email_log (
  run_id        VARCHAR2(64)   NOT NULL,
  created_ts    TIMESTAMP      NOT NULL,
  recipients    VARCHAR2(4000) NOT NULL,
  subject       VARCHAR2(500)  NOT NULL,
  body          CLOB           NOT NULL
);

CREATE INDEX idx_uds_email_log_1 ON uds_email_log (run_id, created_ts);
