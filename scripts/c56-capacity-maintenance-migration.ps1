$ErrorActionPreference='Stop'
$repo='C:\Projects\tsd-canonical-v2';$v2='saecycamkyvzzppxudzq';$prod='gdajktoqmajipivpdude';$dev='tlflipdeahgwsueerkex';$org='f39ce894-e039-4329-aeca-85e46e193aef'
Set-Location $repo
if((git branch --show-current).Trim()-ne'canonical-v2'){throw'Wrong branch'}
if((Get-Content 'supabase\.temp\project-ref'-Raw).Trim()-ne$v2){throw'Wrong Supabase target'}
if($v2-eq$prod-or$v2-eq$dev){throw'Unsafe target identity'}
Add-Type @"
using System;using System.Runtime.InteropServices;public class C56MigrationCred{[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]public struct R{public uint a,b;public string c,d;public System.Runtime.InteropServices.ComTypes.FILETIME e;public uint f;public IntPtr g;public uint h,i;public IntPtr j;public string k,l;}[DllImport("advapi32.dll",EntryPoint="CredReadW",CharSet=CharSet.Unicode)]public static extern bool X(string t,uint y,uint z,out IntPtr p);[DllImport("advapi32.dll")]public static extern void CredFree(IntPtr p);}
"@
$p=[IntPtr]::Zero;if(-not[C56MigrationCred]::X('Supabase CLI:supabase',1,0,[ref]$p)){throw'Supabase credential unavailable'}
try{$c=[Runtime.InteropServices.Marshal]::PtrToStructure($p,[type][C56MigrationCred+R]);$b=New-Object byte[] $c.f;[Runtime.InteropServices.Marshal]::Copy($c.g,$b,0,$b.Length);$token=[Text.Encoding]::UTF8.GetString($b)}finally{[C56MigrationCred]::CredFree($p)}
$headers=@{Authorization="Bearer $token";'Content-Type'='application/json'};$base='https://api.supabase.com/v1/projects'
function Q([string]$project,[string]$sql){Invoke-RestMethod -Method Post -Uri "$base/$project/database/query" -Headers $headers -Body (@{query=$sql}|ConvertTo-Json -Compress)}
$vp=Invoke-RestMethod -Uri "$base/$v2" -Headers $headers;$pp=Invoke-RestMethod -Uri "$base/$prod" -Headers $headers;$dp=Invoke-RestMethod -Uri "$base/$dev" -Headers $headers
if($vp.status-ne'ACTIVE_HEALTHY'-or$pp.status-ne'ACTIVE_HEALTHY'-or$dp.status-ne'INACTIVE'){throw"Unsafe states V2=$($vp.status) PROD=$($pp.status) DEV=$($dp.status)"}
$assetCheck=Q $v2 "select count(*) found from maintenance_assets where organization_id='$org' and id in('ca1766c5-c675-4c1e-b710-9a8cd0187e54','e1fdedf8-ca2b-4c99-9150-f9b847513c59','e23e399b-f288-4044-afdf-d2cbf6486887')"
if([int]$assetCheck[0].found-ne3){throw'Maintenance asset parity missing'}
function Rows([string]$table,[string]$where){@((Q $prod "select to_jsonb(t) payload from public.$table t where $where")|ForEach-Object{$_.payload})}
function Import([string]$table,[object[]]$rows){
 if($rows.Count-eq0){return 0};$json=ConvertTo-Json -InputObject $rows -Depth 20 -Compress;$encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
 $r=Q $v2 "with p as(select convert_from(decode('$encoded','base64'),'utf8')::jsonb j),i as(insert into public.$table select (jsonb_populate_record(null::public.$table,e)).* from p,jsonb_array_elements(p.j)e on conflict do nothing returning 1)select count(*) inserted from i"
 [int]$r[0].inserted
}
$wo="work_order_id in(select id from maintenance_work_orders where organization_id='$org')";$passes=@()
for($pass=1;$pass-le2;$pass++){
 $result=[ordered]@{}
 $result.capacity=Import 'capacity_legacy_overrides' (Rows 'capacity_legacy_overrides' "organization_id='$org'")
 $result.work_orders=Import 'maintenance_work_orders' (Rows 'maintenance_work_orders' "organization_id='$org'")
 $result.history=Import 'maintenance_work_order_history' (Rows 'maintenance_work_order_history' $wo)
 $result.comments=Import 'maintenance_work_order_comments' (Rows 'maintenance_work_order_comments' $wo)
 $result.downtime=Import 'maintenance_downtime_events' (Rows 'maintenance_downtime_events' $wo)
 $result.labor=Import 'maintenance_work_order_labor' (Rows 'maintenance_work_order_labor' $wo)
 $result.attachments=Import 'maintenance_attachments' (Rows 'maintenance_attachments' $wo)
 $result.parts=Import 'maintenance_inventory_transactions' (Rows 'maintenance_inventory_transactions' $wo)
 $result.checklist=Import 'maintenance_work_order_checklist' (Rows 'maintenance_work_order_checklist' $wo)
 $passes+=[pscustomobject]$result
}
$verification=(Q $v2 @"
select
(select count(*) from capacity_legacy_overrides where organization_id='$org') capacity,
(select count(*) from maintenance_work_orders where organization_id='$org') work_orders,
(select count(*) from maintenance_work_order_history where $wo) history,
(select count(*) from maintenance_work_order_comments where $wo) comments,
(select count(*) from maintenance_downtime_events where $wo) downtime,
(select count(*) from maintenance_work_order_labor where $wo) labor,
(select count(*) from maintenance_attachments where $wo) attachments,
(select count(*) from maintenance_inventory_transactions where $wo) parts,
(select count(*) from maintenance_work_order_checklist where $wo) checklist,
(select count(*) from maintenance_work_orders w left join maintenance_assets a on a.id=w.asset_id where w.organization_id='$org' and a.id is null) orphan_assets,
(select count(*) from maintenance_work_orders where organization_id='$org' and status not in('open','in_progress','waiting_parts','waiting_external','completed','cancelled','OPEN_OPERATOR','WAITING_MAINTENANCE','REQUESTED')) invalid_statuses,
(select count(*) from maintenance_audit_log where organization_id='$org' and entity_type in('maintenance_work_orders','maintenance_downtime_events')) migration_audit_events,
(select count(*) from(select organization_id,production_area_id,source_name from capacity_legacy_overrides group by 1,2,3 having count(*)>1)x) duplicate_capacity,
(select count(*) from(select id from maintenance_work_orders group by id having count(*)>1)x) duplicate_work_orders
"@)[0]
[pscustomobject]@{target=$v2;prod='READ_ONLY';dev=$dp.status;oracle='UNTOUCHED';passes=$passes;verification=$verification}|ConvertTo-Json -Depth 8
