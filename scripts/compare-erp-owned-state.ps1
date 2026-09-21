param([string[]]$OnlyTables = @())

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TsdCredentialReader {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct Credential {
    public uint Flags, Type;
    public IntPtr TargetName, Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public uint CredentialBlobSize;
    public IntPtr CredentialBlob;
    public uint Persist, AttributeCount;
    public IntPtr Attributes, TargetAlias, UserName;
  }
  [DllImport("advapi32.dll", EntryPoint="CredReadW", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool Read(string target, uint type, uint flags, out IntPtr pointer);
  [DllImport("advapi32.dll")]
  public static extern void CredFree(IntPtr pointer);
}
'@

function Get-SupabaseToken {
  $pointer = [IntPtr]::Zero
  if (-not [TsdCredentialReader]::Read('Supabase CLI:supabase', 1, 0, [ref]$pointer)) {
    throw 'Supabase CLI credential unavailable'
  }
  try {
    $credential = [Runtime.InteropServices.Marshal]::PtrToStructure(
      $pointer,
      [type][TsdCredentialReader+Credential]
    )
    $bytes = [byte[]]::new($credential.CredentialBlobSize)
    [Runtime.InteropServices.Marshal]::Copy($credential.CredentialBlob, $bytes, 0, $bytes.Length)
    return [Text.Encoding]::UTF8.GetString($bytes).Trim([char]0)
  } finally {
    [TsdCredentialReader]::CredFree($pointer)
  }
}

function Invoke-Query([string]$ProjectRef, [string]$Query) {
  $headers = @{ Authorization = "Bearer $script:Token"; 'Content-Type' = 'application/json' }
  $body = @{ query = $Query; read_only = $true } | ConvertTo-Json -Compress
  return Invoke-RestMethod -Method Post -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" -Headers $headers -Body $body
}

$script:Token = Get-SupabaseToken
$legacyRef = 'gdajktoqmajipivpdude'
$replacementRef = 'eziirebccovlvhaonsgw'
$queries = [ordered]@{
  maintenance_assets = "select id::text key, asset_code, status, active, updated_at marker from public.maintenance_assets order by id"
  maintenance_work_orders = "select id::text key, work_order_number, status, updated_at marker from public.maintenance_work_orders order by id"
  maintenance_downtime_events = "select id::text key, source_system, source_key, event_status, created_at marker from public.maintenance_downtime_events order by id"
  maintenance_audit_log = "select id::text key, entity_type, action, created_at marker from public.maintenance_audit_log order by id"
  maintenance_work_order_history = "select id::text key, work_order_id::text parent, to_status, changed_at marker from public.maintenance_work_order_history order by id"
  maintenance_work_order_comments = "select id::text key, work_order_id::text parent, created_at marker from public.maintenance_work_order_comments order by id"
  maintenance_members = "select (user_id::text || ':' || organization_id::text) key, role, active, created_at marker from public.maintenance_members order by 1"
  screen_print_jobs = "select id::text key, order_no, status, planned_quantity, completed_quantity, updated_at marker from public.screen_print_jobs order by id"
  capacity_legacy_overrides = "select id::text key, source_name, daily_capacity, work_days, active, created_at marker from public.capacity_legacy_overrides order by id"
}

foreach ($entry in $queries.GetEnumerator()) {
  if ($OnlyTables.Count -gt 0 -and $entry.Key -notin $OnlyTables) { continue }
  $legacy = @(Invoke-Query $legacyRef $entry.Value)
  $replacement = @(Invoke-Query $replacementRef $entry.Value)
  if ($legacy.Count -eq 1 -and $legacy[0] -is [array]) { $legacy = @($legacy[0]) }
  if ($replacement.Count -eq 1 -and $replacement[0] -is [array]) { $replacement = @($replacement[0]) }
  $legacyByKey = @{}; foreach ($row in $legacy) { $legacyByKey[$row.key] = $row }
  $replacementByKey = @{}; foreach ($row in $replacement) { $replacementByKey[$row.key] = $row }
  $legacyOnly = @($legacy | Where-Object { -not $replacementByKey.ContainsKey($_.key) })
  $replacementOnly = @($replacement | Where-Object { -not $legacyByKey.ContainsKey($_.key) })
  $commonChanged = @($legacy | Where-Object {
    $replacementByKey.ContainsKey($_.key) -and
    (($_ | ConvertTo-Json -Compress) -ne ($replacementByKey[$_.key] | ConvertTo-Json -Compress))
  })
  [pscustomobject]@{
    table = $entry.Key
    legacy = $legacy.Count
    replacement = $replacement.Count
    legacy_only = $legacyOnly.Count
    replacement_only = $replacementOnly.Count
    common_changed = $commonChanged.Count
    legacy_only_sample = @($legacyOnly | Select-Object -First 3)
    replacement_only_sample = @($replacementOnly | Select-Object -First 3)
    changed_sample = @($commonChanged | Select-Object -First 3)
  } | ConvertTo-Json -Depth 6 -Compress
}
