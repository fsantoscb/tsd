revoke all on public.sync_agent_heartbeat from anon,authenticated;
grant select,insert,update on public.sync_agent_heartbeat to service_role;
