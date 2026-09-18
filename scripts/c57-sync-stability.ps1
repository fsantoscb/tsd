$ErrorActionPreference='Stop'
$repo='C:\Projects\tsd-canonical-v2';$v2='saecycamkyvzzppxudzq';$prod='gdajktoqmajipivpdude';$dev='tlflipdeahgwsueerkex';$org='f39ce894-e039-4329-aeca-85e46e193aef'
Set-Location $repo
if((git branch --show-current).Trim()-ne'canonical-v2'){throw'Wrong branch'}
if((Get-Content 'supabase\.temp\project-ref'-Raw).Trim()-ne$v2-or$v2-eq$prod-or$v2-eq$dev){throw'Unsafe target identity'}
Add-Type @"
using System;using System.Runtime.InteropServices;public class C57Cred{[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]public struct R{public uint a,b;public string c,d;public System.Runtime.InteropServices.ComTypes.FILETIME e;public uint f;public IntPtr g;public uint h,i;public IntPtr j;public string k,l;}[DllImport("advapi32.dll",EntryPoint="CredReadW",CharSet=CharSet.Unicode)]public static extern bool X(string t,uint y,uint z,out IntPtr p);[DllImport("advapi32.dll")]public static extern void CredFree(IntPtr p);}
"@
$p=[IntPtr]::Zero;if(-not[C57Cred]::X('Supabase CLI:supabase',1,0,[ref]$p)){throw'Supabase credential unavailable'}
try{$c=[Runtime.InteropServices.Marshal]::PtrToStructure($p,[type][C57Cred+R]);$b=New-Object byte[] $c.f;[Runtime.InteropServices.Marshal]::Copy($c.g,$b,0,$b.Length);$token=[Text.Encoding]::UTF8.GetString($b)}finally{[C57Cred]::CredFree($p)}
$headers=@{Authorization="Bearer $token";'Content-Type'='application/json'};$base='https://api.supabase.com/v1/projects'
function Q([string]$sql){Invoke-RestMethod -Method Post -Uri "$base/$v2/database/query" -Headers $headers -Body (@{query=$sql}|ConvertTo-Json -Compress)}
$vp=Invoke-RestMethod -Uri "$base/$v2" -Headers $headers;$pp=Invoke-RestMethod -Uri "$base/$prod" -Headers $headers;$dp=Invoke-RestMethod -Uri "$base/$dev" -Headers $headers
if($vp.status-ne'ACTIVE_HEALTHY'-or$pp.status-ne'ACTIVE_HEALTHY'-or$dp.status-ne'INACTIVE'){throw"Unsafe project states V2=$($vp.status) PROD=$($pp.status) DEV=$($dp.status)"}
function Snapshot([string]$label){
 $sql=@"
select '$label' label,clock_timestamp() captured_at,
(select count(*) from v_current_orders where organization_id='$org') orders,
(select count(*) from v_current_workbank where organization_id='$org') workbank_rows,
(select coalesce(sum(production_units),0) from v_current_workbank where organization_id='$org') workbank_qty,
(select count(*) from v_dtg_operational_orders where organization_id='$org') dtg_orders,
(select coalesce(sum(remaining_units),0) from v_dtg_operational_orders where organization_id='$org') dtg_qty,
(select count(*) from v_up_operational_orders where organization_id='$org') up_orders,
(select coalesce(sum(remaining_units),0) from v_up_operational_orders where organization_id='$org') up_qty,
(select count(*) from v_release_queue where organization_id='$org') release_orders,
(select count(*) from v_current_release_order_lines where organization_id='$org') release_lines,
(select coalesce(sum(total_process_qty),0) from v_release_queue where organization_id='$org') release_qty,
(select count(*) from v_machine_load_not_approved where organization_id='$org') not_approved_rows,
(select coalesce(sum(process_quantity),0) from v_machine_load_not_approved where organization_id='$org') not_approved_qty,
(select count(*) from v_current_workbank where organization_id='$org' and(upper(coalesce(queue,''))='PAK7'or upper(coalesce(task,''))='PAK7')) screen_wb_rows,
(select coalesce(sum(production_units),0) from v_current_workbank where organization_id='$org' and(upper(coalesce(queue,''))='PAK7'or upper(coalesce(task,''))='PAK7')) screen_wb_qty,
0::bigint screen_release_rows,0::numeric screen_release_qty,
(select count(*) from v_machine_load_not_approved where organization_id='$org' and upper(coalesce(process,''))='SCREEN_PRINT') screen_not_approved_rows,
(select count(*) from source_audit_events where organization_id='$org') audit_events,
(select count(*) from v_dtg_order_history) dtg_history,
(select count(*) from production_events where organization_id='$org') production_events,
(select count(*) from capacity_legacy_overrides where organization_id='$org') capacity,
(select count(*) from maintenance_work_orders where organization_id='$org') maintenance_wos,
(select count(*) from maintenance_work_order_history where organization_id='$org') maintenance_history,
(select count(*) from maintenance_work_order_comments where organization_id='$org') maintenance_comments,
(select count(*) from maintenance_downtime_events where organization_id='$org') maintenance_downtimes,
(select count(*) from production_orders where organization_id='$org' and production_status not in('COMPLETED','CANCELLED')) active_mos,
(select count(*) from manufacturing_order_lines where organization_id='$org' and production_demand_line_id is not null) operational_mappings,
(select count(*) from(select source_row_id from v_current_workbank where organization_id='$org' group by source_row_id having count(*)>1)x) dup_workbank,
(select count(*) from(select source_audit_id from source_audit_events where organization_id='$org' group by source_audit_id having count(*)>1)x) dup_audit_ids,
(select count(*) from(select raw_hash from source_audit_events where organization_id='$org' group by raw_hash having count(*)>1)x) dup_audit_hashes,
(select count(*) from(select order_no from v_dtg_order_history group by order_no having count(*)>1)x) dup_dtg_history,
(select count(*) from(select event_id from production_events where organization_id='$org' group by event_id having count(*)>1)x) dup_production_events,
(select count(*) from(select id from maintenance_work_orders where organization_id='$org' group by id having count(*)>1)x) dup_maintenance,
(select count(*) from(select organization_id,production_area_id,source_name from capacity_legacy_overrides where organization_id='$org' group by 1,2,3 having count(*)>1)x) dup_capacity,
(select count(*) from(select ml.production_demand_line_id from manufacturing_order_lines ml join production_demand_lines d on d.id=ml.production_demand_line_id where ml.organization_id='$org' and d.status in('READY','GROUPED') group by 1 having count(*)>1)x) dup_active_demand_mappings,
(select count(*) from maintenance_work_orders w left join maintenance_assets a on a.id=w.asset_id where w.organization_id='$org' and a.id is null) orphan_maintenance_assets,
(select count(*) from maintenance_inventory_transactions t left join maintenance_parts p on p.id=t.part_id where t.organization_id='$org' and p.id is null) orphan_parts,
(select count(*) from maintenance_work_orders where organization_id='$org' and status not in('open','in_progress','waiting_parts','waiting_external','completed','cancelled','OPEN_OPERATOR','WAITING_MAINTENANCE','REQUESTED')) invalid_maintenance_statuses,
(select count(*) from source_release_order_lines l left join source_orders o on o.sync_batch_id=l.sync_batch_id and o.order_no=l.order_no where l.organization_id='$org' and o.id is null) orphan_release_lines,
(select count(*) from production_order_operations op left join production_orders po on po.id=op.production_order_id where op.organization_id='$org' and po.id is null) orphan_mo_operations,
(select count(*) from production_events where organization_id='$org' and event_id is null) invalid_production_events,
(select count(*) from source_audit_events where organization_id='$org' and source_audit_id is null and raw_hash is null) unknown_audit_events,
(select id from v_latest_completed_batch where organization_id='$org') latest_batch_id,
(select completed_at from v_latest_completed_batch where organization_id='$org') latest_completed_at,
(select max(source_updated_at) from v_current_orders where organization_id='$org') source_order_timestamp,
(select max(created_at) from v_current_workbank where organization_id='$org') workbank_snapshot_timestamp
"@
 (Q $sql)[0]
}
function LatestBatch([string]$previous){
 $r=(Q "select id,status,started_at,completed_at,extract(epoch from(completed_at-started_at))::numeric duration_seconds,orders_count,release_line_count,workbank_count,stock_count,audit_new_count,error_message from sync_batches where organization_id='$org' and id<>'$previous' order by started_at desc limit 1")[0]
 if(-not$r-or$r.status-ne'completed'-or[int]$r.orders_count-le0-or[int]$r.workbank_count-le0-or-not$r.completed_at){throw'Invalid or partial sync batch'};$r
}
function RunSync([int]$number,[string]$previous){
 $config='apps/oracle-sync/.env.sync.local';Get-Content $config|ForEach-Object{if($_-match'^\s*([^#][^=]*)=(.*)$'){[Environment]::SetEnvironmentVariable($matches[1].Trim(),$matches[2].Trim().Trim('"'),'Process')}}
 $env:ORACLE_CONNECT_STRING='192.168.0.222:1521/TSDPROD';$env:ORACLE_CREDENTIAL_TARGET='TSDPROD_KPI_ORACLE';$env:INGEST_API_URL='http://127.0.0.1:3001/api/ingest'
 $cursor='apps/oracle-sync/.state/audit-cursor.txt';if(Test-Path $cursor){$env:AUDIT_AFTER_ID=(Get-Content $cursor -Raw).Trim()}
 $pnpm='C:\Users\Felipe.Santos\.cache\codex-runtimes\codex-primary-runtime\dependencies\bin\fallback\pnpm.cmd';$node='C:\Users\Felipe.Santos\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin';$env:PATH="$node;$env:PATH"
 Push-Location 'apps/oracle-sync';try{&$pnpm exec tsx src/cli.ts sync:once;if($LASTEXITCODE-ne0){throw"Run $number connector failed"}}finally{Pop-Location}
 LatestBatch $previous
}
$baseline=Snapshot 'C5_7_BASELINE';$runs=@();$previous=[string]$baseline.latest_batch_id
for($i=1;$i-le3;$i++){$batch=RunSync $i $previous;$metrics=Snapshot "RUN_$i";$runs+=[pscustomobject]@{run=$i;batch=$batch;metrics=$metrics};$previous=[string]$batch.id}
$result=[pscustomobject]@{target=$v2;prod='READ_ONLY';dev=$dp.status;oracle='READ_ONLY';scheduler='OFF';preview='OFF';cutover='OFF';baseline=$baseline;runs=$runs}
$result|ConvertTo-Json -Depth 10|Set-Content '.tmp/c57-results.json' -Encoding utf8
$result|ConvertTo-Json -Depth 10
