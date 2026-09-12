[CmdletBinding()]
param(
    [ValidateRange(1, 1440)]
    [int]$SyncIntervalMinutes = 5,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run setup.ps1 from a normal, non-administrator PowerShell session so Oracle can use your Credential Manager."
}

$installScript = Join-Path $PSScriptRoot "install.ps1"
$arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$installScript`"", "-SyncIntervalMinutes", $SyncIntervalMinutes)
if ($SkipBuild) { $arguments += "-SkipBuild" }

$installer = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait -PassThru
if ($installer.ExitCode -ne 0) {
    throw "The elevated web-service installation failed with exit code $($installer.ExitCode)."
}

& (Join-Path $PSScriptRoot "register-oracle-sync.ps1") -SyncIntervalMinutes $SyncIntervalMinutes
Write-Host "TSD Production Control setup completed."
