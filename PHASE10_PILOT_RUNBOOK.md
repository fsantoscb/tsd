# Phase 10 pilot runbook

## Purpose

Operate TSD Production Control safely during the factory pilot and distinguish application failures from VPN or Oracle availability failures.

## Operational architecture

| Component | Input | Output | Runtime |
| --- | --- | --- | --- |
| Web application | Supabase configuration and production database | Production, planning, scan and KPI screens | Automatic Windows service `TSDProductionControl` |
| Oracle connector | Oracle over VPN and Windows Credential Manager | Normalized synchronization batches sent to the ingest API | Scheduled task every 5 minutes |
| PWA | Web manifest, service worker and live HTTP responses | Installable desktop/mobile application with safe offline fallback | Browser |
| Health check | Windows service, HTTP endpoint and task state | One operational status report | `deploy\windows\health-check.ps1` |

## Start-of-shift check

1. Connect the company VPN.
2. Run `powershell -ExecutionPolicy Bypass -File .\deploy\windows\health-check.ps1 -CheckOracleNetwork`.
3. Confirm `ServiceStatus: Running`, `WebHealth: ok`, `OracleTaskInstalled: True` and `OracleTcpReachable: True`.
4. Open `http://localhost:3000` and sign in.
5. Confirm that the Oracle last-run time advances within the next five-minute cycle.

## Expected VPN behavior

When VPN is disconnected, the website and Supabase features remain available, but Oracle refreshes fail with a network timeout. The task remains scheduled and retries on its next cycle after VPN reconnection. Do not reset credentials for a network timeout.

## Recovery

| Symptom | First action | Escalate when |
| --- | --- | --- |
| Website unavailable | Check `Get-Service TSDProductionControl`, then start the service as administrator | Service stops again or `/api/health` is not `ok` |
| Oracle timeout | Connect VPN and test `192.168.0.222:1521` | TCP remains unavailable while VPN is connected |
| Oracle task non-zero result | Run the health check, reconnect VPN and trigger the task once | A new run still fails with Oracle reachable |
| Stale production data | Compare task last-run time and sync-status page | Last result is zero but data timestamp does not advance |
| PWA offline page | Restore network and reload | Online reload still shows offline state |

## Deployment

From a normal PowerShell session:

```powershell
Set-Location "C:\Projects\TSD Production Control"
.\deploy\windows\setup.ps1 -SyncIntervalMinutes 5
```

Approve the UAC request for the Windows service. Oracle registration returns to the non-elevated user session so it can use that user's Credential Manager.

## Pilot acceptance criteria

- Windows restart brings the web service back automatically.
- `/api/health` returns `ok`.
- Oracle synchronization completes with result `0` while VPN is connected.
- A disconnected VPN does not stop the web service.
- No password is stored in deployment scripts, source files or documentation.
- Authenticated production, planning, capacity, KPI and scan workflows remain operational.
- PWA installs and opens on the selected desktop and mobile pilot devices.
- Factory users record issues with timestamp, order number, screen and expected behavior.

## Remaining human validation

The automated platform checks are complete. Final pilot acceptance still requires a Windows restart test, PWA installation on the selected physical devices and representative factory-user workflow validation.
