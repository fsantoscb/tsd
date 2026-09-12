[CmdletBinding()]
param(
    [string]$ApplicationUrl = "http://localhost:3000",
    [string]$OracleHost = "192.168.0.222",
    [int]$OraclePort = 1521,
    [switch]$CheckOracleNetwork
)

$ErrorActionPreference = "Stop"
$service = Get-Service -Name "TSDProductionControl" -ErrorAction SilentlyContinue
$task = $null
try {
    $scheduler = New-Object -ComObject "Schedule.Service"
    $scheduler.Connect()
    $task = $scheduler.GetFolder("\").GetTask("TSD Production Control - Oracle Sync")
}
catch { $task = $null }
$taskStates = @{
    0 = "Unknown"
    1 = "Disabled"
    2 = "Queued"
    3 = "Ready"
    4 = "Running"
}
$health = try { Invoke-RestMethod "$($ApplicationUrl.TrimEnd('/'))/api/health" -TimeoutSec 15 } catch { $null }
$oracleTcp = if ($CheckOracleNetwork) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $connection = $client.BeginConnect($OracleHost, $OraclePort, $null, $null)
        if (-not $connection.AsyncWaitHandle.WaitOne(5000, $false)) {
            $false
        }
        else {
            $client.EndConnect($connection)
            $true
        }
    }
    catch { $false }
    finally { $client.Dispose() }
} else { $null }

$result = [pscustomobject]@{
    CheckedAt = Get-Date
    ServiceInstalled = [bool]$service
    ServiceStatus = if ($service) { [string]$service.Status } else { "Missing" }
    ServiceStartType = if ($service) { [string]$service.StartType } else { "Missing" }
    WebHealth = if ($health) { [string]$health.status } else { "unavailable" }
    OracleTaskInstalled = [bool]$task
    OracleTaskState = if ($task) { $taskStates[[int]$task.State] } else { "Missing" }
    OracleLastResult = if ($task) { $task.LastTaskResult } else { $null }
    OracleLastRun = if ($task) { $task.LastRunTime } else { $null }
    OracleNextRun = if ($task) { $task.NextRunTime } else { $null }
    OracleTcpReachable = $oracleTcp
}

$result | Format-List

$failed = -not $service -or $service.Status -ne "Running" -or -not $health -or $health.status -ne "ok" -or -not $task
if ($CheckOracleNetwork -and -not $oracleTcp) {
    Write-Warning "Oracle is unreachable. Confirm that the VPN is connected before treating this as an application incident."
}
if ($failed) { exit 1 }
exit 0
