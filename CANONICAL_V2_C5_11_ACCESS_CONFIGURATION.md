# Canonical V2 - C5.11 Production Configuration and Access Control

Date: 2026-09-19 (Australia/Brisbane)

## Result

**C5.11 PRODUCTION CONFIG + ACCESS CONTROL: BLOCKED**

Production domain, legacy PROD, inactive DEV, Oracle, and the active legacy scheduler were not changed. The V2 scheduler remains OFF.

## Production environment variable matrix

Secret values were never printed. Preview/Production presence reflects the last verified Vercel inventory; the CLI could not be re-executed in this runtime because its downloaded package was incomplete.

| Variable | Category | Preview | Production | Required | Scope | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | SUPABASE | Present, V2 | Missing | Yes | Client/server | BLOCKED |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | SUPABASE | Present | Missing | Yes | Client/server, public key | BLOCKED |
| `SUPABASE_SERVICE_ROLE_KEY` | SUPABASE | Present | Missing | Yes | Server only | BLOCKED |
| `INGEST_SECRET` | SYNC | Present | Missing | Yes | Server/agent only | BLOCKED |
| `ORGANIZATION_ID` | APPLICATION | Missing | Missing | Yes | Server/agent | BLOCKED |
| `ADMIN_EMAIL` | AUTH | Disabled test identity | Missing | Transitional | Server only | BLOCKED |
| `APP_ENV` | APPLICATION | Present | Missing | Yes | Server | BLOCKED |
| `TSD_ENVIRONMENT` | APPLICATION | Present | Missing | Yes | Server | BLOCKED |
| `NEXT_PUBLIC_APP_URL` | APPLICATION | Not verified | Missing | Deployment dependent | Client/server | BLOCKED |
| `APP_VERSION` | APPLICATION | Not verified | Missing | Recommended | Server | BLOCKED |
| `ORACLE_CONNECT_STRING` | ORACLE | Agent-local | Not a Vercel variable | Agent only | Secret/local | PASS |
| `ORACLE_CREDENTIAL_TARGET` | ORACLE | Agent-local | Not a Vercel variable | Agent only | Local reference | PASS |
| `ORACLE_USER` / `ORACLE_PASSWORD` | ORACLE | Credential manager alternative | Not a Vercel variable | Conditional | Agent secret | PASS |
| `INGEST_API_URL` | SYNC | Agent-local | Not configured for V2 agent | Yes for agent | Agent | BLOCKED |
| `EXPECTED_SUPABASE_PROJECT_REF` | SYNC | Code requires V2 ref | Not configured for V2 agent | Yes | Agent | BLOCKED |
| `AGENT_ID` | HEARTBEAT | Agent-local | V2 agent OFF | Yes | Agent | BLOCKED |
| `CONNECTOR_VERSION` | SYNC | Agent-local | V2 agent OFF | Yes | Agent | BLOCKED |
| `AUDIT_AFTER_ID` | SYNC | Agent-local | V2 agent OFF | Yes | Agent | BLOCKED |
| `SYNC_INTERVAL_SECONDS` | SCHEDULER | Agent-local | V2 scheduler OFF | Yes | Agent | BLOCKED |
| `SYNC_TIMEZONE` | SCHEDULER | Agent-local | V2 scheduler OFF | Yes | Agent | BLOCKED |

Local server configuration was positively verified against Supabase project ref `saecycamkyvzzppxudzq`. This does not substitute for Vercel Production configuration.

## Client/server safety

- Service-role usage is limited to server modules and API handlers.
- Oracle credentials and ingest secrets are not referenced through `NEXT_PUBLIC_*` variables.
- No private token or secret was found in the repository candidate scan.
- Public Supabase URL and anonymous key are intentionally browser-visible.
- The service-role key, Oracle credentials, ingest secret, and scheduler configuration were not printed or copied into source control.

## Role model

The existing `maintenance_members` table is the canonical organization membership source. C5.11 does not introduce a competing membership table.

Canonical new assignments use:

- `operator`
- `supervisor`
- `manager`
- `admin`

Legacy `maintenance` and `viewer` values remain accepted for compatibility but should not be assigned to new users without explicit mapping.

The complete capability matrix is in `CANONICAL_V2_PERMISSION_MATRIX.md` with every cell explicitly ALLOW or DENY.

## Production user readiness

V2 currently contains exactly one Auth identity:

| User | Account status | Membership | Enabled | Readiness |
| --- | --- | --- | --- | --- |
| `c58-preview@tankstreamdesign.com` | Banned until 2126 | `admin`, membership inactive | No | DISABLED / NOT PRODUCTION |

No real production users exist in V2. No person or role was invented, and no generic shared account was created.

## RLS inventory and classification

The baseline enables RLS across all public base tables. Tables without a user policy remain inaccessible through anon/authenticated clients. Service-role server paths bypass RLS intentionally.

Key categories:

| Category | Representative structures | Intended access |
| --- | --- | --- |
| AUTHENTICATED_READ | orders, production operations, routing status | Active organization members |
| ROLE_RESTRICTED_WRITE | production execution, routing exceptions | Operational/management roles |
| ROLE_RESTRICTED_READ | reconciliation, audit diagnostics | Active organization members |
| SERVICE_ONLY | Oracle source, Workbank source, sync state, canonical demand/history | Service-role writes only |
| INTERNAL_ONLY | staging/control internals without user policies | Service/database only |

## Prepared RLS changes

Migration `002_access_control_hardening.sql` was created but not applied remotely.

It:

- Adds `manager` to the existing membership constraint.
- Adds centralized security-definer helper `has_org_role`.
- Changes policies accidentally targeted to `public` so they target `authenticated`.
- Removes human manage policies from derived MO lines and production demand.
- Allows production operation execution to Operator/Supervisor/Manager/Admin.
- Restricts structural production changes to Manager/Admin.
- Restricts production order management to Supervisor/Manager/Admin.
- Restricts canonical configuration to Manager/Admin.
- Revokes authenticated mutation of Oracle source, Workbank, audit, snapshots, sync state, immutable history, and derived demand.
- Revokes all public-schema access and function execution from `anon`.
- Preserves service-role operation.

## Public and authenticated exposure

Baseline findings:

- Seven policies were declared to `public`, although their expressions still required a matching authenticated membership.
- Multiple configuration policies allowed Supervisor/Admin management.
- Derived source/demand structures had direct authenticated management policies.

Prepared target:

- Public/anon operational policies: zero.
- Anonymous table grants: zero.
- Source/snapshot writes: service only.
- Canonical configuration: Manager/Admin.
- Authenticated production execution: explicit operational roles.

Because migration 002 is not applied and SQL security tests have not run against V2, these target statements are not yet remote evidence.

## Application authorization versus RLS

The application uses server-side service-role clients for many page/read paths. Server-side page membership checks exist, and maintenance uses `maintenance_members`, but service-role usage means RLS alone cannot protect a poorly authorized server endpoint.

Required Preview regression therefore includes both direct Supabase RLS calls and direct API/route calls. Hidden buttons are not accepted as authorization evidence.

## Security tests

Created `supabase/tests/access_control_hardening.sql` to assert:

- No `public` or `anon` policy remains.
- No anonymous table grant remains.
- Central role helper exists and is security-definer.
- Service-owned derived tables have no human manage policy.

Not yet proven remotely:

- Anonymous denial.
- Disabled-user denial.
- Operator role matrix.
- Supervisor role matrix.
- Manager role matrix.
- Admin role matrix.
- Service/sync path.
- Direct API bypass denial.

No temporary role users were created merely to make the test matrix green.

## Preview validation

Not executed because migration 002 is not applied, Production/Preview environment configuration is incomplete, and only the disabled test account exists. P0/P1 cannot be honestly calculated yet.

## Local regression

- Lint: PASS.
- Typecheck: PASS.
- Tests: 197/197 PASS.
- Production build: PASS.
- SQL/RLS remote tests: BLOCKED.

Test count stayed at 197 because C5.11 added SQL security assertions rather than application Vitest cases.

## Blocker matrix

| Blocker | Status | Evidence |
| --- | --- | --- |
| V2 Production env vars | BLOCKED | Required Production scope remains incomplete |
| Production user list | BLOCKED | Only disabled C5.8 test identity exists |
| Permission matrix | PASS | `CANONICAL_V2_PERMISSION_MATRIX.md` is complete with ALLOW/DENY |
| RLS least privilege | BLOCKED | Migration prepared, not applied/tested remotely |
| Public exposure | BLOCKED | Removal prepared, remote policy inventory not revalidated |
| Authenticated over-permission | BLOCKED | Hardening prepared, role regression not executed |
| Security regression | BLOCKED | No real role users; Preview migration/config not active |

## Exact unresolved items

1. Configure all required V2 Production variables with approved values and verify scopes via Vercel.
2. Supply the names/email identifiers and role assignments of actual production users.
3. Apply migration `002_access_control_hardening.sql` to V2 after SQL syntax/dry-run validation.
4. Run the SQL access-control test against V2.
5. Create or assign approved role users without shared credentials.
6. Run direct RLS and direct API tests for Anonymous, Disabled, Operator, Supervisor, Manager, Admin, and service-role.
7. Update/deploy Preview and run login/logout/page/operation regression with P0=0 and P1=0.
8. Reconfirm Production environment completeness and positive V2 project identity.

## Final gate

**C5.11 PRODUCTION CONFIG + ACCESS CONTROL: BLOCKED**

