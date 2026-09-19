$ErrorActionPreference="Stop"
$logPath=Join-Path $PSScriptRoot "sync-agent.log"
$configPath=Join-Path $PSScriptRoot "..\.env.sync.local"
if(-not(Test-Path -LiteralPath $configPath)){throw"Local sync configuration is missing."}

Get-Content -LiteralPath $configPath|ForEach-Object{
 if($_ -match '^\s*([^#][^=]*)=(.*)$'){
  [Environment]::SetEnvironmentVariable($matches[1].Trim(),$matches[2].Trim().Trim('"'),"Process")
 }
}

if(-not $env:ORACLE_CONNECT_STRING){$env:ORACLE_CONNECT_STRING="192.168.0.222:1521/TSDPROD"}
if(-not $env:ORACLE_CREDENTIAL_TARGET){$env:ORACLE_CREDENTIAL_TARGET="TSDPROD_KPI_ORACLE"}
if(-not $env:SYNC_INTERVAL_SECONDS){$env:SYNC_INTERVAL_SECONDS="300"}
if(-not $env:AUDIT_AFTER_ID){$env:AUDIT_AFTER_ID="0"}

foreach($required in @("INGEST_API_URL","INGEST_SECRET","EXPECTED_SUPABASE_PROJECT_REF","AGENT_ID","CONNECTOR_VERSION")){
 if(-not [Environment]::GetEnvironmentVariable($required,"Process")){throw"Required sync configuration is missing: $required"}
}

if(-not $env:ORGANIZATION_ID){
 $organization=Invoke-RestMethod -Uri "$($env:INGEST_API_URL.TrimEnd('/'))/organization" -Headers @{Authorization="Bearer $($env:INGEST_SECRET)"}
 $env:ORGANIZATION_ID=$organization.organizationId
}

Push-Location(Join-Path $PSScriptRoot "..")
try{
 $pnpm="C:\Users\Felipe.Santos\.cache\codex-runtimes\codex-primary-runtime\dependencies\bin\fallback\pnpm.cmd"
 $nodeBin="C:\Users\Felipe.Santos\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin"
 $env:PATH="$nodeBin;$env:PATH"
 $ErrorActionPreference="Continue"
 & $pnpm exec tsx src/cli.ts agent:tick *>>$logPath
 $code=$LASTEXITCODE
 $ErrorActionPreference="Stop"
 if($code-ne 0){Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) TICK_FAILED exit=$code";exit $code}
 Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) TICK_OK"
}finally{Pop-Location}
