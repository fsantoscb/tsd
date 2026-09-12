# Pre-routing baseline

- Date: 2026-09-13 (Australia/Brisbane)
- Primary branch: main
- Repository: https://github.com/fsantoscb/tsd.git
- Previous commit: none; this is the initial import of the recovered production source
- Latest migration: 202609130005_operator_downtime_timestamp.sql

## Quality status before routing architecture

- Lint: PASS
- Typecheck: PASS
- Unit and integration tests: PASS, 118 tests
- Database tests: SKIPPED, no local database harness configured
- RLS tests: SKIPPED, no local database test harness configured
- Local production build: BLOCKED when public Supabase environment variables are absent
- Vercel production build: PASS, 44 pages generated

## Existing warnings and risks

- ESLint reports that the Next.js plugin is not detected in the current configuration.
- The local production build requires NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.
- The remote repository was empty; this commit establishes the first reproducible Git baseline.
- BOM and MRP are not active. WMS remains authoritative for inventory and materials.
