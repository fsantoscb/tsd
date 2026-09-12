# Security policy and operating controls

## Secrets

- Oracle credentials must remain in Windows Credential Manager under `TSDPROD_KPI_ORACLE`.
- Supabase and ingest secrets must remain in ignored `.env` files or an approved secret store.
- Never paste passwords into source, SQL, documentation, screenshots or support tickets.
- Rotate any credential that has been shared in plaintext, even if the local copy was later removed.

## Runtime controls

- The web application runs as an automatic Windows service with restart-on-failure.
- Oracle synchronization runs in the signed-in user's context to access Windows Credential Manager.
- Offline caching excludes authenticated production data.
- Responses use frame denial, MIME sniffing protection, same-origin referrer policy and restricted browser permissions.
- `/api/health` contains no secret and is returned with `no-store`.

## Dependency control

Run before every pilot release:

```powershell
pnpm audit --prod --audit-level high
pnpm test
pnpm typecheck
pnpm lint
pnpm build
```

Do not deploy when a high or critical vulnerability, failed test, type error, lint error or build error remains unresolved.

## Incident handling

1. Preserve the timestamp and affected order number.
2. Run `deploy\windows\health-check.ps1 -CheckOracleNetwork`.
3. Determine whether the failure is web, Supabase, VPN, Oracle or synchronization-task related.
4. Do not send `.env` files, credentials or unrestricted database exports.
5. Rotate exposed credentials and document the rotation date without recording the new value.
