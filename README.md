# Reprocess Rejected Downstream Updates (Oracle PL/SQL)

## Overview
This project provides a **safe and auditable reprocessing solution** for rejected downstream update records in an Oracle database.

In the order management flow, records are inserted into a downstream update table with status `Q` (Queued).
Schedulers run every minute to process queued records and notify third-party systems.

Some records may fail and end up with status `R` (Rejected).
This solution reprocesses rejected records from a **controlled time window (e.g. past hour)** by moving them back to `Q`, logging all changes, and notifying support teams.

The solution is **idempotent**, **production-safe**, and **fully traceable**.

---

## Table Information

**Table Name:** `UPDATE_DOWNSTREAMS`

| Column Name | Description |
|------------|-------------|
| `REF_ID_V` | Unique reference ID |
| `REQ_DATE` | Request creation date |
| `ACTION_V` | Requested action |
| `STATUS_V` | Record status (`Q` = Queued, `R` = Rejected) |

---

## Business Requirement Summary

- Identify rejected (`R`) records from the past hour
- Reprocess them by updating status back to `Q`
- Capture reference IDs of all updated records
- Notify support members (`a, b, c, d, e`) with:
    - Number of reprocessed records
    - Reference ID, action, and status after reprocess

---

## Key Design Principles

### 1. Controlled Reprocessing Window
- Only records within a configurable time window are affected (default: last 60 minutes)
- Prevents accidental reprocessing of old or already handled records

### 2. Idempotent & Safe
- Only records with `STATUS_V = 'R'` are updated
- Re-running the procedure does not re-update already queued records
- Safe to execute multiple times

### 3. Efficient Data Handling
- Uses `UPDATE ... RETURNING ... BULK COLLECT`
- Avoids additional SELECT queries
- Captures updated reference IDs in a single operation

### 4. Full Audit Trail
- Every updated record is stored in an audit log table
- Includes run identifier, timestamps, reference ID, action, and status change

### 5. Environment-Agnostic Email Handling
- Attempts to send email via `UTL_MAIL`
- If email is not supported, email content is stored in a log table
- Ensures solution works in restricted environments (e.g. Oracle Live SQL)

---

## Project Structure

```
reprocess-downstreams/
│
├── sql/
│   ├── 10_indexes_suggested_uds.sql
│   ├── 11_logging_objects_uds.sql
│   ├── 12_reprocess_pkg.sql
│   ├── 13_run_reprocess_last_hour.sql
│   └── 14_test_data_uds.sql
│
├── docs/
│   ├── uds_design.md
│   └── uds_spec.md
│
└── README.md
```

---

## Recommended Index

```sql
CREATE INDEX IDX_UDS_STATUS_REQDATE
ON UPDATE_DOWNSTREAMS (STATUS_V, REQ_DATE);
```

---

## Setup Instructions

### Step 1: Create Logging Objects
```sql
@sql/11_logging_objects_uds.sql
```

### Step 2: Load Demo Data (Optional)
```sql
@sql/14_test_data_uds.sql
```

### Step 3: Deploy Package
```sql
@sql/12_reprocess_pkg.sql
```

---

## Run & Validate

```sql
BEGIN
  uds_reprocess_pkg.reprocess_rejected_last_hour(
    p_recipients   => 'a,b,c,d,e',
    p_minutes_back => 60
  );
END;
/
```

### Verify
```sql
SELECT STATUS_V, COUNT(*) FROM UPDATE_DOWNSTREAMS GROUP BY STATUS_V;
SELECT * FROM uds_reprocess_log ORDER BY processed_ts DESC;
SELECT subject, recipients FROM uds_email_log ORDER BY created_ts DESC;
```

---

## Why This Solution Works

- Prevents reprocessing of old data
- Provides full audit and traceability
- Safe for repeated execution
- Designed for real Oracle production systems
