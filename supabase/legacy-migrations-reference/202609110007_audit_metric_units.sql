create or replace function normalize_production_event_units()returns trigger language plpgsql security definer set search_path=public as $$begin
 if new.source='ORACLE_AUDIT'and new.metric<>'DTG_PRINT'then select coalesce(a.source_weight,a.source_qty,a.production_units)into new.quantity from source_audit_events a where a.organization_id=new.organization_id and coalesce(a.source_audit_id,a.raw_hash)=new.source_record_key limit 1;end if;
 return new;end$$;
drop trigger if exists production_event_units_trigger on production_events;
create trigger production_event_units_trigger before insert or update of quantity,metric on production_events for each row execute function normalize_production_event_units();
update production_events p set quantity=coalesce(a.source_weight,a.source_qty,a.production_units)
from source_audit_events a where p.organization_id=a.organization_id and p.source='ORACLE_AUDIT'and p.metric<>'DTG_PRINT'and p.source_record_key=coalesce(a.source_audit_id,a.raw_hash);
update production_events set quality_status='PROVISIONAL'where source='ORACLE_AUDIT'and metric='DTG_PRINT'and created_at<now();
