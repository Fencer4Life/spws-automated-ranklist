# ADR-009: CERT/PROD Runtime Toggle (Single GitHub Pages Site)

**Status:** Accepted
**Date:** 2025-03-15 (M6)

## Context

The SPWS ranklist frontend needs to serve two Supabase backends: CERT (staging for new data) and PROD (verified data). Both run on Supabase cloud with separate project refs. The frontend is deployed to GitHub Pages.

## Decision

Deploy a single GitHub Pages site with a runtime CERT/PROD toggle. Credentials for both environments are injected at build time via `sed` in the GitHub Actions deploy workflow, stored as GitHub Actions secrets.

## Alternatives Considered

1. **Separate GitHub Pages per environment** (e.g., `/cert/` and `/prod/` paths or separate repos) — doubles deployment complexity, harder to keep in sync.
2. **Separate branches** (cert and prod branches deployed to different URLs) — divergent codebases, merge conflicts.
3. **Environment variable at build time** (two separate builds) — requires two workflow runs, two artifacts, two URLs to share.

## Consequences

- Single URL for stakeholders — CERT/PROD switch is in-app, no URL management.
- `dualEnv` derived flag: `$derived(!!(certUrl && certKey && prodUrl && prodKey))` — toggle hidden when any credential is missing (e.g., local dev with only CERT).
- Credentials injected via 4 `sed` commands in `deploy.yml` replacing placeholder attributes in `index.html`.
- Security: RLS enforces anon = SELECT-only on both backends. No `service_role` keys in frontend. Build step verifies no localhost URLs or service keys leak into output.
- Reactivity chain: `activeEnv` → `$derived(supabaseUrl/Key)` → `$effect` re-initializes Supabase client on switch.
- Local dev: only CERT-like local Supabase available, toggle hidden automatically.
