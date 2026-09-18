$ErrorActionPreference = "Stop"
$repo = "C:\Projects\tsd-canonical-v2"
$v2 = "saecycamkyvzzppxudzq"
$dev = "tlflipdeahgwsueerkex"
$prod = "gdajktoqmajipivpdude"
$org = "f39ce894-e039-4329-aeca-85e46e193aef"
Set-Location $repo
if ((git branch --show-current).Trim() -ne "canonical-v2") { throw "Wrong branch" }
if ((Get-Content -LiteralPath "supabase\.temp\project-ref" -Raw).Trim() -ne $v2) { throw "Wrong Supabase target" }

Add-Type @"
using System;using System.Runtime.InteropServices;public class C55MigrationCred{[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]public struct R{public uint a,b;public string c,d;public System.Runtime.InteropServices.ComTypes.FILETIME e;public uint f;public IntPtr g;public uint h,i;public IntPtr j;public string k,l;}[DllImport("advapi32.dll",EntryPoint="CredReadW",CharSet=CharSet.Unicode)]public static extern bool X(string t,uint y,uint z,out IntPtr p);[DllImport("advapi32.dll")]public static extern void CredFree(IntPtr p);}
"@
$pointer = [IntPtr]::Zero
if (-not [C55MigrationCred]::X("Supabase CLI:supabase",1,0,[ref]$pointer)) { throw "Supabase credential unavailable" }
try { $credential=[Runtime.InteropServices.Marshal]::PtrToStructure($pointer,[type][C55MigrationCred+R]);$bytes=New-Object byte[] $credential.f;[Runtime.InteropServices.Marshal]::Copy($credential.g,$bytes,0,$bytes.Length);$token=[Text.Encoding]::UTF8.GetString($bytes) } finally { [C55MigrationCred]::CredFree($pointer) }
$headers=@{Authorization="Bearer $token";"Content-Type"="application/json"};$base="https://api.supabase.com/v1/projects"
function Query([string]$project,[string]$sql){Invoke-RestMethod -Method Post -Uri "$base/$project/database/query" -Headers $headers -Body (@{query=$sql}|ConvertTo-Json -Compress)}
$vp=Invoke-RestMethod -Uri "$base/$v2" -Headers $headers;$dp=Invoke-RestMethod -Uri "$base/$dev" -Headers $headers;$pp=Invoke-RestMethod -Uri "$base/$prod" -Headers $headers
if($vp.status-ne"ACTIVE_HEALTHY"-or$dp.status-ne"INACTIVE"-or$pp.status-ne"ACTIVE_HEALTHY"){throw "Unsafe project state V2=$($vp.status) DEV=$($dp.status) PROD=$($pp.status)"}

function Count-V2 { [int](Query $v2 "select count(*) count from source_audit_events where organization_id='$org'")[0].count }
function Import-Pass {
  $inserted=0;$cursor="";$pageSize=3000
  while($true){
    $after=if($cursor){"and source_audit_id>'$($cursor.Replace("'","''"))'"}else{""}
    $raw=Query $prod @"
select source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash,imported_at,queue,task
from source_audit_events where organization_id='$org' $after order by source_audit_id limit $pageSize
"@
    $rows=@();foreach($item in @($raw)){if(($item-is[System.Collections.IEnumerable])-and($item-isnot[string])-and($item.PSObject.Properties.Name-notcontains"source_audit_id")){foreach($inner in $item){$rows+=$inner}}else{$rows+=$item}}
    if($rows.Count-eq 0){break}
    if(-not $rows[0].source_audit_id-or-not $rows[0].order_no){throw "Malformed source payload"}
    $json=ConvertTo-Json -InputObject $rows -Depth 6 -Compress;$encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    $result=Query $v2 @"
with payload as(select convert_from(decode('$encoded','base64'),'utf8')::jsonb j),ins as(
 insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash,imported_at,queue,task)
 select '$org',event->>'source_audit_id',event->>'order_no',event->>'username',event->>'from_zone',event->>'to_zone',event->>'from_location',event->>'to_location',event->>'product',event->>'from_pack_id',event->>'to_pack_id',nullif(event->>'source_qty','')::numeric,nullif(event->>'source_weight','')::numeric,coalesce(nullif(event->>'production_units','')::numeric,0),(event->>'event_at')::timestamptz,event->>'raw_hash',(event->>'imported_at')::timestamptz,event->>'queue',event->>'task'
 from payload,jsonb_array_elements(payload.j) event
 on conflict do nothing returning 1)select count(*) inserted from ins;
"@
    $inserted += [int]$result[0].inserted;$cursor=[string]$rows[-1].source_audit_id
  }
  return $inserted
}

$before=Count-V2;$prodCount=[int](Query $prod "select count(*) count from source_audit_events where organization_id='$org'")[0].count
if($before-eq$prodCount){
  $first=0;$afterFirst=$before
  $second=[int](Query $v2 @"
with ins as(insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash,imported_at,queue,task)
select organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash,imported_at,queue,task from source_audit_events where organization_id='$org' on conflict do nothing returning 1)select count(*) inserted from ins;
"@)[0].inserted;$afterSecond=Count-V2
}else{$first=Import-Pass;$afterFirst=Count-V2;$second=Import-Pass;$afterSecond=Count-V2}
Query $v2 @"
insert into production_events(organization_id,event_id,event_ts_utc,event_ts_local,calendar_date,operational_date,hour_bucket,shift_code,area,metric,quantity,unit,source,source_mode,source_record_key,quality_status,calculation_version)
select a.organization_id,coalesce(a.source_audit_id,a.raw_hash)||':'||m.metric,a.event_at,a.event_at at time zone'Australia/Brisbane',(a.event_at at time zone'Australia/Brisbane')::date,
 case when r.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<r.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end,
 extract(hour from a.event_at at time zone'Australia/Brisbane')::smallint,coalesce(r.shift_code,'OUT_OF_SHIFT'),m.area,m.metric,a.production_units,m.unit,'ORACLE_AUDIT','SQL',coalesce(a.source_audit_id,a.raw_hash),case when r.shift_code is null then'OUT_OF_SHIFT'else'COMPLETE'end,'ERP_KPI_V1'
from source_audit_events a cross join lateral(select*from(values('DTG'::text,'DTG_PRINT'::text,'prints'::text,upper(coalesce(a.queue,''))='PCOR'or upper(coalesce(a.task,''))='PCOR'),('DTG','DTG_PUTWALL_IN','garments',upper(coalesce(a.to_zone,''))='PWL1'),('DTG','DTG_PUTWALL_OUT','garments',upper(coalesce(a.from_zone,''))='PWL1'),('UP','UP_IN','garments',upper(coalesce(a.to_location,''))like'%UNDERPRINT%'),('UP','UP_OUT','garments',upper(coalesce(a.from_location,''))like'%UNDERPRINT%'and upper(coalesce(a.to_location,''))not like'%UNDERPRINT%'))v(area,metric,unit,accepted)where accepted)m
left join lateral(select s.*from shift_rules s where s.organization_id=a.organization_id and s.active and s.effective_from<=(a.event_at at time zone'Australia/Brisbane')::date and(s.effective_to is null or s.effective_to>=(a.event_at at time zone'Australia/Brisbane')::date)and s.weekday=extract(isodow from case when s.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end)and(case when s.cross_midnight then(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time or(a.event_at at time zone'Australia/Brisbane')::time<s.end_time else(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time end)order by s.effective_from desc limit 1)r on true
where a.organization_id='$org' and a.production_units>0 on conflict do nothing;
"@|Out-Null
$verification=(Query $v2 "select (select count(*) from source_audit_events) audit_events,(select count(*) from v_dtg_order_history) dtg_history,(select count(*) from production_events where source='ORACLE_AUDIT') production_events,(select count(*) from(select source_audit_id from source_audit_events group by source_audit_id having count(*)>1)x) duplicate_ids,(select count(*) from(select raw_hash from source_audit_events group by raw_hash having count(*)>1)x) duplicate_hashes,(select min(event_at) from source_audit_events) oldest,(select max(event_at) from source_audit_events) newest;")[0]
[pscustomobject]@{target=$v2;before=$before;first_inserted=$first;after_first=$afterFirst;second_inserted=$second;after_second=$afterSecond;verification=$verification;dev=$dp.status;prod=$pp.status}|ConvertTo-Json -Depth 6
