# Windows deployment

This deployment keeps responsibilities separate:

- `TSDProductionControl` is an automatically started Windows service for the production web application.
- `TSD Production Control - Oracle Sync` is a recurring task under the signed-in Windows user. This is required because the Oracle password remains protected in that user's Windows Credential Manager.

## Install

Open a normal PowerShell window and run. The setup requests elevation only for the Windows service, then returns to your user session to register Oracle synchronization:

```powershell
Set-Location "C:\Projects\TSD Production Control"
.\deploy\windows\setup.ps1 -SyncIntervalMinutes 5
```

The setup builds the application, prepares a dedicated Node.js runtime, downloads the pinned WinSW 2.12.0 wrapper, installs and starts the web service, then registers Oracle synchronization in the non-elevated user session. Runtime execution does not depend on Codex or the system `PATH`.

## Operational checks

```powershell
Get-Service TSDProductionControl
Get-ScheduledTask -TaskName "TSD Production Control - Oracle Sync"
Invoke-RestMethod http://localhost:3000/api/health
```

Service logs are stored in `deploy\windows`. Oracle task history is available in Windows Task Scheduler.

## Remove

```powershell
.\deploy\windows\uninstall.ps1
```

No database password is copied into these deployment files.
