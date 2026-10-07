# Phase 3A disposable SQL handoff — not executed

The harness is `supabase/tests/labour_v3_read_model_concurrency.mjs`.
It requires an independently approved localhost database with all prerequisite
schema, the draft read-model migration and synthetic full-authority fixtures.
Neither it nor the migration provisions or seeds Production.

Required existing process environment:
- `TSD_V3_DISPOSABLE_APPROVED=LABOUR_V3_PHASE3A_DISPOSABLE`.
- `TSD_V3_DISPOSABLE_DATABASE` matching `tsd_v3_disposable_[a-z0-9_]+`.
- `PGDATABASE` exactly matching that name, `PGHOST=127.0.0.1` or `::1`.
- Existing disposable-only PostgreSQL credentials, never Production credentials.
- `TSD_V3_CAS_FIXTURE`: local JSON fixture file, not a connection string.

Actual server database and address are checked before mutation. Production,
Preview, absent approval or absent fixtures reject before connection. No
credential, payload or SQL error output is printed. Do not use forwarded
Production connections. The identity/authorization requirement is a precondition,
not permission to create credentials or a database automatically.

The JSON has six keys, each consumed by an actual scenario function:
1. `firstInsert`: `requests` has two selector requests with identical cohort,
   NULL expected generation and expected version 0. Exactly one commits.
2. `replacement`: two requests with the same exact existing generation/version.
   Exactly one commits and version increases once.
3. `sourceLockTimeout`: a valid enabling selector `request`. Connection A holds
   a conflicting source lock while B calls the selector. Expect 55P03 after
   approximately one second; both transactions roll back. No retries.
4. `selectionDuringCertificate`: a `period` and valid CAS `request`. A begins
   REPEATABLE READ READ ONLY and certifies; B changes selection and commits;
   A's second certificate must describe the same snapshot. A new transaction
   must observe the changed selection vector.
5. `authorityDuringCertificate`: a `period` and `mutationSQL`. Same snapshot
   check, with a bounded synthetic source/rule update by B. Fresh certificate
   must change and must not remain certified complete.
6. `certificateAfterChange`: a `period` and `mutationSQL`. Two separate
   SERIALIZABLE READ ONLY certificates straddle a committed bounded mutation;
   the later certificate must reflect the changed state.

`period` contains organizationId/from/to. Requests use the approved selector
contract and TEST-prefixed person keys. Different scenarios must use prepared
cohorts/prestates so earlier commits do not invalidate later fixtures. Mutations
are single UPDATE statements on Deputy batches/raws or shift rules with an exact
organization predicate; no semicolons, comments, DROP or cleanup DML are accepted.

Snapshot comparisons exclude checkedAt deliberately: the timestamp can advance
inside one transaction while the authority/selection snapshot remains identical.
The comparison binds statuses, blocking, completeness, required cohorts,
selection vector and full-generation checks. Certificates cannot be reused after
a selection/source change just because a numeric total is unchanged.

Ordinary PostgREST RPC invocation is NOT assumed sufficient. The certificate
requires REPEATABLE READ or SERIALIZABLE READ ONLY established by its caller;
no global setting or PostgREST configuration is changed.

Guard tests and JavaScript syntax checks are local code evidence only. Until
actual authorized disposable execution occurs, migration, SQL contract, CAS
atomicity, CAS concurrency, source-lock timeout and snapshot consistency all
remain independently NOT EXECUTION-CERTIFIED. No Production first-execution
authorization is implied by this handoff.
