BEGIN
  uds_reprocess_pkg.reprocess_rejected_last_hour(
    p_recipients   => 'a,b,c,d,e',
    p_minutes_back => 60
  );
END;
/
