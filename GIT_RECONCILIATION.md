# Git Reconciliation

## Scope

- Production commit: `507992b5733b8c26352d00afad2dc268296f090f`
- Current `origin/main`: `55db6cfbdb476b21f31045fbd282fa7bfb93da68`
- Merge base: `55db6cfbdb476b21f31045fbd282fa7bfb93da68`
- Ahead/behind (`origin/main...production`): `0 / 33`

## Ancestry

`origin/main` is a direct ancestor of the production commit. The production
commit is not an ancestor of `origin/main`. There are no commits unique to
`main`, so no merge conflict or history rewrite is required.

## Reconciliation Strategy

The safe strategy is a fast-forward of `main` to a clean, validated commit
containing the currently deployed application state plus only the approved
infrastructure guard/documentation changes from this consolidation phase.

Before moving `main`:

1. Validate lint, typecheck, tests, and production build.
2. Ensure no local-only diagnostic files or `.superpowers` state are committed.
3. Ensure Preview cannot target the production Supabase project.
4. Create a clean deployment from the exact committed tree.
5. Preserve rollback tag `prod-pre-consolidation-2026-09-22`.

## Dirty Deployment Assessment

The active Vercel deployment reports `gitDirty=1`. The known untracked files
are documentation, `.superpowers` state, and an Oracle-sync diagnostic script;
none are part of the `apps/web` deployment root. This makes an application-code
delta unlikely, but a new clean deployment is still required before the Git and
deployment identities can be declared reconciled.

## Gate

Git ancestry: PASS.

Fast-forward readiness: PENDING full validation, Preview isolation, and a clean
deployment.
