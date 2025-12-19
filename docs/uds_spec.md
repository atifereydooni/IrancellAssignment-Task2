# Procedure Specification - uds_reprocess_pkg.reprocess_rejected_last_hour

## Purpose
Reprocess rejected (R) downstream update records from the last N minutes by setting them back to queued (Q), logging updated reference IDs, and sending a support notification.

## Inputs
- `p_recipients` (VARCHAR2): recipients list (e.g. `a,b,c,d,e` or real emails if available)
- `p_minutes_back` (NUMBER, default 60): time window in minutes
- `p_run_id` (VARCHAR2, optional): run identifier for correlation/logging

## Behavior
1. Updates rows in `UPDATE_DOWNSTREAMS` where:
    - `STATUS_V = 'R'`
    - `REQ_DATE >= SYSDATE - (p_minutes_back / 1440)`
2. Sets `STATUS_V = 'Q'`
3. Captures `REF_ID_V`, `ACTION_V`, `STATUS_V` (after update), and `REQ_DATE`
4. Inserts details into `uds_reprocess_log`
5. Sends an email (or logs email content) containing:
    - count of updated rows
    - list of ref_id + action + status_after + req_date

## Output
- Updated rows in `UPDATE_DOWNSTREAMS`
- Audit records in `uds_reprocess_log`
- Email sent via `UTL_MAIL` OR content saved in `uds_email_log`
