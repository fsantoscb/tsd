create index if not exists source_audit_events_dtg_history_idx
  on source_audit_events(order_no, from_zone, to_zone, event_at);
