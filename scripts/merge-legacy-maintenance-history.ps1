param([switch]$Apply)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/compare-erp-owned-state.ps1" -OnlyTables @('__none__')

$legacyRef = 'gdajktoqmajipivpdude'
$replacementRef = 'eziirebccovlvhaonsgw'
if ($replacementRef -in @('gdajktoqmajipivpdude', 'saecycamkyvzzppxudzq', 'tlflipdeahgwsueerkex')) {
  throw 'Unsafe target identity'
}

function Get-Rows([string]$ProjectRef, [string]$Table) {
  return @(Invoke-Query $ProjectRef "select * from public.$Table order by id")
}

function Normalize-Rows($Rows) {
  $normalized = @($Rows)
  if ($normalized.Count -eq 1 -and $normalized[0] -is [array]) { return @($normalized[0]) }
  return $normalized
}

function Invoke-WriteQuery([string]$ProjectRef, [string]$Query) {
  $headers = @{ Authorization = "Bearer $script:Token"; 'Content-Type' = 'application/json' }
  $body = @{ query = $Query; read_only = $false } | ConvertTo-Json -Compress
  return Invoke-RestMethod -Method Post -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" -Headers $headers -Body $body
}

function Merge-Rows([string]$Table, $Rows) {
  $inserted = 0
  foreach ($batch in (0..([math]::Ceiling($Rows.Count / 100.0) - 1))) {
    $slice = @($Rows | Select-Object -Skip ($batch * 100) -First 100)
    if ($slice.Count -eq 0) { continue }
    $json = ($slice | ConvertTo-Json -Depth 30 -Compress).Replace("'", "''")
    $disableTrigger = if ($Table -eq 'maintenance_downtime_events') { 'alter table public.maintenance_downtime_events disable trigger audit_change;' } else { '' }
    $enableTrigger = if ($Table -eq 'maintenance_downtime_events') { 'alter table public.maintenance_downtime_events enable trigger audit_change;' } else { '' }
    $sql = @"
begin;
$disableTrigger
with incoming as (
  select * from jsonb_populate_recordset(null::public.$Table, '$json'::jsonb)
), inserted as (
  insert into public.$Table select * from incoming
  on conflict (id) do nothing
  returning 1
)
select count(*)::integer as inserted from inserted;
$enableTrigger
commit;
"@
    $result = @(Invoke-WriteQuery $replacementRef $sql)
    if ($result.Count -eq 1 -and $result[0] -is [array]) { $result = @($result[0]) }
    $inserted += [int]$result[0].inserted
  }
  return $inserted
}

$tables = @('maintenance_downtime_events', 'maintenance_audit_log')
foreach ($table in $tables) {
  $legacy = Normalize-Rows (Get-Rows $legacyRef $table)
  $replacement = Normalize-Rows (Get-Rows $replacementRef $table)
  $replacementIds = @{}; foreach ($row in $replacement) { $replacementIds[$row.id] = $true }
  $missing = @($legacy | Where-Object { -not $replacementIds.ContainsKey($_.id) })
  Write-Output "$table legacy=$($legacy.Count) replacement=$($replacement.Count) missing=$($missing.Count)"
  if ($Apply) {
    $inserted = Merge-Rows $table $missing
    Write-Output "$table inserted=$inserted"
  }
}
