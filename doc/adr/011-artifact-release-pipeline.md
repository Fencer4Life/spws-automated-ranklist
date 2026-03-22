# ADR-011: Three-Tier Artifact Release Pipeline with Schema Fingerprinting

**Status:** Accepted
**Date:** 2025-03-22 (M7)

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
