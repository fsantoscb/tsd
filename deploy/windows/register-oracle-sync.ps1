[CmdletBinding()]
param(
    [ValidateRange(1, 1440)]
    [int]$SyncIntervalMinutes = 5
)

$ErrorActionPreference = "Stop"
$taskName = "TSD Production Control - Oracle Sync"
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$syncScript = Join-Path $PSScriptRoot "run-oracle-sync.cmd"
$syncCommand = "cmd.exe /d /c `"$syncScript`""

& schtasks.exe /Create /TN $taskName /TR $syncCommand /SC MINUTE /MO $SyncIntervalMinutes `
    /RU $currentUser /IT /RL LIMITED /F | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "The Oracle synchronization task could not be registered for $currentUser."
}

Write-Host "Oracle sync scheduled every $SyncIntervalMinutes minute(s) for $currentUser."
