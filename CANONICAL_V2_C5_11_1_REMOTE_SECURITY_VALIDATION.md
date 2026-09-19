# Canonical V2 - C5.11.1 Remote Security Validation

Date: 2026-09-19 (Australia/Brisbane)

## Result

**C5.11.1 REMOTE SECURITY ACTIVATION: BLOCKED**

The database hardening is applied and structurally verified in Canonical V2. Runtime role validation, approved production identities, complete Vercel Production configuration, and deployed Preview regression remain incomplete. C5.12 must not start.

## Safety boundary

- Canonical V2 target: `saecycamkyvzzppxudzq`.
- Legacy production `gdajktoqmajipivpdude`: untouched.
- DEV: untouched.
- Oracle: read-only and untouched.
- Production domain: unchanged.
- Legacy scheduler: unchanged.
- V2 scheduler: OFF.

## Tooling remediation

The project-local Supabase and Vercel CLI paths were not usable in this Windows runtime: the Supabase package lacked its native executable and the Vercel package lacked `@vercel/cli-auth`. No application logic was changed to mask these packaging failures. The authenticated Supabase and Vercel dashboards were used for remote inspection and the allowed Canonical V2-only database change.

## Remote migration evidence

Pre-migration snapshot:

- migration history: `001`
- policies targeting `public` or `anon`: 7
- authenticated write policies: 17
- tables with RLS disabled: 0
- active application members: 0
- disabled application members: 1

Applied to Canonical V2 only:

- `002_access_control_hardening.sql`
- migration history registered as `002 access_control_hardening`

Post-migration snapshot:

- migration history: `001`, `002`
- policies targeting `public` or `anon`: 0
- anonymous public-schema grants: 0
- service-owned broad manage policies: 0
- `manager` role accepted by membership constraint: yes
- centralized `has_org_role` helper present and security-definer: yes
- authenticated write policies: 17, limited to explicit role-aware operational/configuration policies

## Remote SQL security test

`supabase/tests/access_control_hardening.sql` executed against `saecycamkyvzzppxudzq`.

- result: PASS
- failures: 0
- warnings: 0

This proves the deployed policy structure. It does not replace end-to-end role identity tests.

## Identity readiness

The only V2 identity remains `c58-preview@tankstreamdesign.com`. It is banned until 2126 and its application membership remains inactive. It was not reactivated or promoted.

No approved real production identity list was available in Canonical V2 during this phase. Operator, Supervisor, Manager, Admin, and Disabled runtime regressions therefore remain BLOCKED. The required strategy is to provision separate Supabase Auth identities in V2, map each identity to one active organization membership, avoid shared credentials, and validate each role before cutover. Production passwords, tokens, and sessions must never be copied.

## Vercel configuration

Vercel access to project `tsd-production-control-v2-preview` was verified. Preview contains the V2 Supabase URL/key, service credential, ingest secret, and environment guards. Production scope remains incomplete.

`ADMIN_EMAIL` was deliberately not promoted because it references the disabled temporary identity. `ORGANIZATION_ID` remains missing. No scheduler was enabled and no production alias was changed.

## Evidence matrix

| Item | Source prepared | Remote applied | Runtime tested | Status |
| --- | --- | --- | --- | --- |
| Migration 002 | Yes | Yes | SQL inventory | PASS |
| RLS | Yes | Yes | Structural SQL | PASS |
| Public access removal | Yes | Yes | Structural SQL | PASS |
| Service-only writes | Yes | Yes | Structural SQL only | BLOCKED |
| Operator | Yes | Yes | No approved identity | BLOCKED |
| Supervisor | Yes | Yes | No approved identity | BLOCKED |
| Manager | Yes | Yes | No approved identity | BLOCKED |
| Admin | Yes | Yes | No approved identity | BLOCKED |
| Disabled user | Yes | Existing user remains disabled | Authentication not exercised | BLOCKED |
| Anonymous | Yes | Yes | Structural SQL only | BLOCKED |
| Vercel Production env | Matrix prepared | Incomplete | Not deployable | BLOCKED |

## Exact blockers

1. Provision or approve separate V2 Auth identities for Operator, Supervisor, Manager, and Admin.
2. Complete Vercel Production scope using only V2 credentials and a valid approved admin identity.
3. Add and verify `ORGANIZATION_ID = f39ce894-e039-4329-aeca-85e46e193aef` in the V2 project configuration.
4. Run direct remote RLS/API tests for Anonymous, Disabled, Operator, Supervisor, Manager, Admin, and service-role.
5. Redeploy the exact clean Preview commit and run the required functional/security regression.
6. Re-run lint, typecheck, application tests, security tests, and production build after the final configuration/source state is frozen.

## Gate

**C5.11.1 REMOTE SECURITY ACTIVATION: BLOCKED**

