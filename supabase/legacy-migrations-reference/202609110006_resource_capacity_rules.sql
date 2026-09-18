create table resource_capacity_rules(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references organizations(id),
 process text not null check(process in('DTG','UP','SCREEN_PRINT')),resource_code text not null,
 shift_code text check(shift_code in('SHIFT_1','SHIFT_2','SHIFT_3')),max_resources numeric not null check(max_resources>=0),
 condition_context jsonb not null default'{}',effective_from date not null,effective_to date,active boolean not null default true,
 calculation_version text not null default'ERP_KPI_V1',check(effective_to is null or effective_to>=effective_from),
 unique(organization_id,resource_code,shift_code,effective_from)
);
create index resource_capacity_rules_lookup_idx on resource_capacity_rules(organization_id,process,effective_from,effective_to)where active;
insert into resource_capacity_rules(organization_id,process,resource_code,shift_code,max_resources,condition_context,effective_from)
select o.id,x.process,x.resource,x.shift,x.maximum,x.context,date'2026-01-01'from organizations o cross join(values
 ('DTG','DTG_OPERATOR','SHIFT_1',2::numeric,'{"equipment":"2 DTG machines"}'::jsonb),
 ('DTG','DTG_OPERATOR','SHIFT_2',2,'{"equipment":"2 DTG machines"}'),
 ('DTG','DTG_OPERATOR','SHIFT_3',2,'{"equipment":"2 DTG machines"}'),
 ('UP','UP_OPERATOR','SHIFT_1',3,'{"policy":"morning practical maximum"}'),
 ('UP','UP_OPERATOR','SHIFT_2',4,'{"policy":"afternoon practical maximum"}'),
 ('UP','UP_OPERATOR','SHIFT_3',4,'{"policy":"plant maximum"}'))x(process,resource,shift,maximum,context)on conflict do nothing;
alter table resource_capacity_rules enable row level security;revoke all on resource_capacity_rules from anon,authenticated;grant select,insert,update,delete on resource_capacity_rules to service_role;
