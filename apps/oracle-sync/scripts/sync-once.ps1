$ErrorActionPreference = "Stop"
$logPath = Join-Path $PSScriptRoot "sync-scheduled.log"
$configPath = Join-Path $PSScriptRoot "..\.env.sync.local"
if (-not (Test-Path -LiteralPath $configPath)) { throw "Local sync configuration is missing." }

Get-Content -LiteralPath $configPath | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1].Trim(),$matches[2].Trim().Trim('"'),"Process")
  }
}

$env:ORACLE_CONNECT_STRING = "192.168.0.222:1521/TSDPROD"
$env:ORACLE_CREDENTIAL_TARGET = "TSDPROD_KPI_ORACLE"
$env:INGEST_API_URL = "https://tsd-production-control.vercel.app/api/ingest"
if (-not $env:AUDIT_AFTER_ID) { $env:AUDIT_AFTER_ID = "12705793" }

if (-not $env:ORGANIZATION_ID) {
  $organization=Invoke-RestMethod -Uri "$($env:INGEST_API_URL)/organization" -Headers @{Authorization="Bearer $($env:INGEST_SECRET)"}
  $env:ORGANIZATION_ID=$organization.organizationId
}

Push-Location (Join-Path $PSScriptRoot "..")
try {
  $pnpm = "C:\Users\Felipe.Santos\.cache\codex-runtimes\codex-primary-runtime\dependencies\bin\fallback\pnpm.cmd"
  $nodeBin = "C:\Users\Felipe.Santos\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin"
  if (-not (Test-Path -LiteralPath $pnpm)) { throw "Bundled pnpm runtime is missing." }
  if (-not (Test-Path -LiteralPath $nodeBin)) { throw "Bundled Node runtime is missing." }
  $env:PATH = "$nodeBin;$env:PATH"
  $succeeded = $false
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $ErrorActionPreference = "Continue"
    & $pnpm exec tsx src/cli.ts sync:once *>> $logPath
    $ErrorActionPreference = "Stop"
    if ($LASTEXITCODE -eq 0) { $succeeded = $true; break }
    Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) RETRY $attempt/3"
    if ($attempt -lt 3) { Start-Sleep -Seconds 20 }
  }
  if (-not $succeeded) { throw "Connector failed after 3 attempts." }
  Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) SUCCESS"
} catch {
  Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) ERROR: $($_.Exception.Message)"
  exit 1
} finally { Pop-Location }
