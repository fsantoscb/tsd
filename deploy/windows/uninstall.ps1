#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$wrapperPath = Join-Path $PSScriptRoot "TSDProductionControl.exe"
$taskName = "TSD Production Control - Oracle Sync"

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $wrapperPath) {
    & $wrapperPath stop
    & $wrapperPath uninstall
}

Write-Host "TSD Production Control Windows components removed."
