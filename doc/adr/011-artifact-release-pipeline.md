# ADR-011: Three-Tier Artifact Release Pipeline with Schema Fingerprinting

**Status:** Accepted
**Date:** 2025-03-22 (M7)
**Amended by:** [ADR-094](094-release-docs-only-skip.md) (2026-09-13) — `release.yml`'s trigger below is no longer "CI success" alone; a `gate` job now decides whether `build` runs, skipping the whole chain for a documentation-only CI run. Amended 2026-10-25 (below): every deploy job applies the commit `build` fingerprinted, and `scripts/commit-tracking.sh` records each deploy on main.

## Context

SQL migrations were being applied manually via curl to the Supabase Management API. Frontend deploys were decoupled from database deploys. PROD had no migration tracking, and there was no proof that PROD schema matched CERT or LOCAL. The team needed a build-once-deploy-twice promotion pipeline with auditable tracking.

## Decision

Implement a three-tier promotion pipeline: LOCAL (Docker) → CERT (Supabase cloud) → PROD (Supabase cloud). The same SQL migration files, same git SHA, and same schema fingerprint flow through all tiers.

Key mechanisms:
- **Schema fingerprint:** MD5 hash of function definitions + table/column structure in the `public` schema. Computed locally after pgTAP passes, then verified on CERT and PROD after migration apply. Hard fail on mismatch.
- **`deployed_migrations.json`:** Repo-committed tracking file recording which migrations are applied to each cloud environment, updated via `[skip ci]` commits after each deploy.
- **`release-manifest.json`:** Audit trail with version, SHA, schema fingerprint, test counts, and per-environment deployment timestamps.
- **`release.yml` workflow:** Triggered by CI success on `main`. Four jobs: build (frontend + fingerprint), deploy-pages, deploy-cert (auto), deploy-prod (manual approval via GitHub environment protection).
- **Coherence checks:** CI gate verifying version sync (pyproject.toml ↔ package.json), ADR file/spec parity, pgTAP assertion count, and migration↔documentation sync.

## Alternatives Considered

1. **`supabase db push`** — requires direct PostgreSQL port 5432, which is firewalled on Supabase cloud. Not viable.
2. **GitHub Actions artifacts only** — expire after 90 days, no permanent audit trail. Tracking would be lost.
3. **Separate branches per environment** (cert/prod branches) — splits commit history, creates merge conflicts, loses single-SHA traceability.
4. **Database-stored migration tracking table** — creates a chicken-and-egg problem: need migrations applied to track migrations. Also unreachable without Management API.
5. **Docker image promotion** — Supabase cloud is managed, cannot receive Docker containers. Only SQL can be applied remotely.

## Consequences

- Every release is traceable by git SHA — `deployed_migrations.json` shows exactly what's on each environment.
- PROD only receives CERT-validated migrations — the same SQL files that passed pgTAP locally and were applied to CERT.
- Schema fingerprint proves structural parity across all three tiers.
- Rollback is forward-only: push a new corrective migration through the full pipeline.
- `[skip ci]` commits from tracking updates do not trigger infinite pipeline loops.
- Frontend is built once in CI and deployed to GitHub Pages — not promoted from local dev builds (local uses `127.0.0.1:54321`).
- PROD deployment requires manual approval from the `Fencer4Life` reviewer in the GitHub `production` environment.

## Amendment (2026-10-25) — every deploy job applies the commit build fingerprinted

The Decision says the same git SHA flows through all tiers. The jobs had drifted
from it: `build` checked out main when it started, `deploy-cert` the commit that
triggered the run, and `deploy-prod` main again, pulled after its approval wait. A
commit carrying a migration that landed in between was applied without having been
fingerprinted. PROD failed "Fingerprint mismatch after applying migrations" on
28 August 2026 (run 33143154193) and 5 September 2026 (run 33985677430): `build`
fingerprinted b7ca0235 and 4a2cdcff, `deploy-prod` applied 340d2ca0 and e5ccb327,
and each time the migration stayed applied while the tracking stayed behind. It was
found while correcting the comment that claimed both deploy jobs pull main
(`doc/plans/github-actions-workflows-page-2026-10-24.html`, W2 #10).

**Decision:** `build` records the commit it checked out (`outputs.sha`), and
`deploy-cert` and `deploy-prod` check out exactly that commit; neither pulls. A
commit that lands on main meanwhile is deployed by its own release, which the
`release` lane runs next. The record of a deploy is written by
`scripts/commit-tracking.sh` on top of origin/main as it is when the deploy
finishes, in a separate worktree, so the job's tree stays the deployed one; on a
rejected push it fetches main and writes the record again. It names the deployed
commit (`.<env>.last_sha`), which ADR-094's gate measures from, and the CERT record
carries the release manifest of the deployed tree.

Tests: `python/tests/test_release_tracking_commit.py` RELTRACK.01 (the wiring) and
RELTRACK.02–05 (the script against a temporary origin whose main moved: the record
lands on top, the CERT manifest counts the deployed tree, a rejected push is
written again once, and the last failed attempt ends red).
