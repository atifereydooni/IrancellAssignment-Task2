-- Suggested index to quickly find rejected records in the past hour:
-- Main filter: STATUS_V = 'R' and REQ_DATE >= SYSDATE - (60/1440)

-- Recommended:
-- CREATE INDEX IDX_UDS_STATUS_REQDATE ON UPDATE_DOWNSTREAMS (STATUS_V, REQ_DATE);

-- If ACTION_V is frequently used in reporting/queries:
-- CREATE INDEX IDX_UDS_STATUS_REQDATE_ACT ON UPDATE_DOWNSTREAMS (STATUS_V, REQ_DATE, ACTION_V);
