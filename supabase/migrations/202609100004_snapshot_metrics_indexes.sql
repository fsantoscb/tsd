create index if not exists source_workbank_batch_zone_idx
  on source_workbank_items(sync_batch_id, from_zone);

create index if not exists source_stock_batch_location_idx
  on source_stock_items(sync_batch_id, location);
