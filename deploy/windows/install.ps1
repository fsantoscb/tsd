#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidateRange(1, 1440)]
    [int]$SyncIntervalMinutes = 5,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$deployDir = $PSScriptRoot
$projectDir = (Resolve-Path (Join-Path $deployDir "..\..")).Path
$wrapperPath = Join-Path $deployDir "TSDProductionControl.exe"
$runtimeDir = Join-Path $deployDir "runtime"
$runtimeNode = Join-Path $runtimeDir "node.exe"
$serviceName = "TSDProductionControl"
$winswUrl = "https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe"

if (-not $SkipBuild) {
    $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $pnpm) {
        throw "pnpm was not found in PATH. Build the project before installing or use -SkipBuild."
    }
    Push-Location $projectDir
    try {
        & pnpm build
        if ($LASTEXITCODE -ne 0) { throw "Production build failed." }
    }
    finally { Pop-Location }
}

if (-not (Test-Path -LiteralPath $runtimeNode)) {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        throw "Node.js was not found and the dedicated runtime has not been prepared."
    }
    New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
    Copy-Item -LiteralPath $node.Source -Destination $runtimeNode -Force
}
if (-not (Test-Path -LiteralPath $runtimeNode)) {
    throw "The dedicated Node.js runtime could not be prepared."
}

if (-not (Test-Path -LiteralPath $wrapperPath)) {
    Invoke-WebRequest -Uri $winswUrl -OutFile $wrapperPath -UseBasicParsing
}

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    & $wrapperPath stop
    & $wrapperPath uninstall
}

& $wrapperPath install
if ($LASTEXITCODE -ne 0) { throw "The web service could not be installed." }
& $wrapperPath start
if ($LASTEXITCODE -ne 0) { throw "The web service could not be started." }

Write-Host "TSD Production Control service installed and started."
