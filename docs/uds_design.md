# Design Notes - Reprocess Rejected Records (UPDATE_DOWNSTREAMS)

## Problem
Order management inserts records into UPDATE_DOWNSTREAMS with STATUS_V='Q'.
Schedulers run every minute to pick queued (Q) records and update downstream systems.
Some records become rejected with STATUS_V='R'. We must reprocess rejected records from the past hour.

## Solution Overview
- Identify records where STATUS_V='R' and REQ_DATE is within the last N minutes (default 60).
- Update those records back to STATUS_V='Q' for reprocessing.
- Capture and store REF_ID_V (and ACTION_V) of updated rows for audit/reporting.
- Notify support members by email with summary and details.

## Why this is safe
- Scope limited to the last hour (or configurable window).
- Only touches records in rejected state (R).
- Re-running is safe (idempotent for the window): already-updated rows are Q and will not match.

## Performance Considerations
- Suggested index: (STATUS_V, REQ_DATE) to speed up the filter on large tables.
- Use `UPDATE ... RETURNING ... BULK COLLECT` to fetch updated identifiers efficiently.

## Email Delivery
- Uses UTL_MAIL if available.
- If UTL_MAIL is not configured/allowed, email content is stored in a log table for audit/demo.
