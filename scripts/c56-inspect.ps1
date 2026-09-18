$ErrorActionPreference='Stop'
$v2='saecycamkyvzzppxudzq';$prod='gdajktoqmajipivpdude';$dev='tlflipdeahgwsueerkex';$org='f39ce894-e039-4329-aeca-85e46e193aef'
Add-Type @"
using System;using System.Runtime.InteropServices;public class C56Cred{[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]public struct R{public uint a,b;public string c,d;public System.Runtime.InteropServices.ComTypes.FILETIME e;public uint f;public IntPtr g;public uint h,i;public IntPtr j;public string k,l;}[DllImport("advapi32.dll",EntryPoint="CredReadW",CharSet=CharSet.Unicode)]public static extern bool X(string t,uint y,uint z,out IntPtr p);[DllImport("advapi32.dll")]public static extern void CredFree(IntPtr p);}
"@
$p=[IntPtr]::Zero;if(-not[C56Cred]::X('Supabase CLI:supabase',1,0,[ref]$p)){throw'No credential'}
try{$c=[Runtime.InteropServices.Marshal]::PtrToStructure($p,[type][C56Cred+R]);$b=New-Object byte[] $c.f;[Runtime.InteropServices.Marshal]::Copy($c.g,$b,0,$b.Length);$token=[Text.Encoding]::UTF8.GetString($b)}finally{[C56Cred]::CredFree($p)}
$h=@{Authorization="Bearer $token";'Content-Type'='application/json'};$base='https://api.supabase.com/v1/projects'
function Q($project,$sql){Invoke-RestMethod -Method Post -Uri "$base/$project/database/query" -Headers $h -Body (@{query=$sql}|ConvertTo-Json -Compress)}
$projects=@{};foreach($r in @($v2,$prod,$dev)){$projects[$r]=Invoke-RestMethod -Uri "$base/$r" -Headers $h}
$sql=@"
select jsonb_build_object(
'assets',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'code',a.asset_code,'name',coalesce(a.asset_name,a.name),'type',a.asset_type,'active',a.active)) from maintenance_assets a where a.id in(select asset_id from maintenance_work_orders where organization_id='$org')), '[]'::jsonb),
'downtime',coalesce((select jsonb_agg(to_jsonb(d)) from maintenance_downtime_events d where d.work_order_id in(select id from maintenance_work_orders where organization_id='$org')), '[]'::jsonb),
'constraints',coalesce((select jsonb_agg(jsonb_build_object('name',conname,'definition',pg_get_constraintdef(oid))) from pg_constraint where conrelid='public.maintenance_work_orders'::regclass), '[]'::jsonb),
'child_counts',jsonb_build_object('history',(select count(*) from maintenance_work_order_history where work_order_id in(select id from maintenance_work_orders where organization_id='$org')),'comments',(select count(*) from maintenance_work_order_comments where work_order_id in(select id from maintenance_work_orders where organization_id='$org')),'downtime',(select count(*) from maintenance_downtime_events where work_order_id in(select id from maintenance_work_orders where organization_id='$org')),'labor',(select count(*) from maintenance_work_order_labor where work_order_id in(select id from maintenance_work_orders where organization_id='$org')),'attachments',(select count(*) from maintenance_attachments where work_order_id in(select id from maintenance_work_orders where organization_id='$org')),'parts',(select count(*) from maintenance_inventory_transactions where work_order_id in(select id from maintenance_work_orders where organization_id='$org')),'checklist',(select count(*) from maintenance_work_order_checklist where work_order_id in(select id from maintenance_work_orders where organization_id='$org'))),
'pm',(select count(*) from maintenance_work_orders where organization_id='$org' and preventive_plan_id is not null)
) result;
"@
$out=[ordered]@{projects=[ordered]@{v2=$projects[$v2].status;prod=$projects[$prod].status;dev=$projects[$dev].status};prod=(Q $prod $sql)[0].result;v2=(Q $v2 $sql)[0].result;v2_counts=(Q $v2 "select (select count(*) from capacity_legacy_overrides where organization_id='$org') capacity,(select count(*) from maintenance_work_orders where organization_id='$org') work_orders,(select count(*) from maintenance_assets where organization_id='$org') assets")}
$out|ConvertTo-Json -Depth 12
