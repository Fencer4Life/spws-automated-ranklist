# ADR-058: `staging-reports` Supabase Storage bucket for verdict `.md`

**Status:** Proposed
**Date:** 2026-05-03
**Amends:** ADR-050 (Unified Ingestion Pipeline) — Phase 5.5 closes the verdict-persistence gap.

## Context

Phase 5 of the rebuild produces a per-event `doc/staging/<event_code>.md` "verdict" document — the operator-facing summary of the unified pipeline's match decisions, alias outcomes, and pool-bracket disposition. Today this file is written by `phase5_runner.py:492` and `phase5_report.py:108` via `Path.write_text()` to the operator's local filesystem only.

This worked for the historical re-ingest (operator running `phase5_runner` from a developer laptop against LOCAL DB) but blocks the CERT-only future:

- The operator has no LOCAL access for season-current events — they arrive via email (GAS → `xml-inbox/staging` → `ingest.yml`) or via the admin-UI "Stage event" button (dispatch-workflow → `phase5-event-runner.yml`).
- In CI, `Path.write_text("doc/staging/<X>.md")` writes to an ephemeral runner that's destroyed at job exit. The operator never sees the file.
- Committing `.md` back to the git repo from CI is fragile (PR-style noise, race conditions with merges, bloats history).

## Decision

A new private Supabase Storage bucket `staging-reports` persists verdict `.md` files on CERT and PROD. Per-event subfolder structure:

```
staging-reports/
  {event_code}/
    full.md                              ← latest full verdict (replace-on-regen)
    deltas/
      20260603_034512.md                 ← EVF parity sweep delta (append-only)
      20260604_034507.md
      …
```

Bucket properties:
- **Visibility:** private. RLS allows service-role write (CI workflows + edge functions) and authenticated-admin read.
- **Retention:** keep forever. Manual cleanup only via `supabase storage rm`. Files are tiny (full ~30 KB, delta ~2-5 KB).
- **Migration:** `supabase/migrations/20260503000003_phase5_staging_reports_bucket.sql` declares the bucket via `INSERT INTO storage.buckets` + RLS policies.

`md_writer.py` (NEW, extracts the existing renderer from `phase5_runner.py::_build_*_md`) takes a `target` parameter:
- `local` — `Path.write_text()` to filesystem (LOCAL devs, default for shell invocations)
- `storage` — uploads to bucket via `storage_md.py` (CI workflows, default for `--md-target=storage`)
- `both` — writes both
- `none` — no-op (rare, for tests)

LOCAL Supabase has storage disabled in `config.toml` — the migration runs cleanly (it's a pure DDL insert) but the storage server is not operational on LOCAL. LOCAL operators continue using `--md-target=local` (filesystem) — no behavioural change from today.

## Alternatives considered

### A. Extend the existing `xml-inbox` bucket with a `staging-reports/` folder

Rejected: different lifecycles (xml-inbox is write-once-then-archive raw input data; staging-reports is write-many human-readable per-event verdict snapshots). Mixing them complicates RLS reasoning and ADR-023's archival policies.

### B. Commit `.md` back to the git repo via GH workflow `[skip ci]`

Rejected: bloats repo, makes ranklist publication race with .md regen pushes, requires write access from CI to `main`, creates merge-conflict surface area when operator's branch is open.

### C. Store the `.md` as a `TEXT` column on `tbl_event`

Rejected: wrong tool for a multi-KB blob, breaks streaming/pagination patterns, makes the table awkward to query.

### D. No verdict persistence on CERT — operator runs the pipeline locally to regenerate

Rejected: the operator no longer has LOCAL access for season-current events. This is the problem we're solving.

## Consequences

**Positive:**
- Verdicts persist on CERT/PROD without git noise.
- Operator can re-fetch any historical verdict (full.md or any prior delta).
- Per-event subfolder isolates manual cleanup (delete one event's folder, others untouched).
- Append-only deltas/ log gives a chronological change record per event.

**Negative:**
- Bucket creation is manual on each environment (no migration enforces it on LOCAL since storage is disabled there). Plan-test-ID 5.12 catches "missing bucket" loudly via pgTAP.
- Storage retention grows over time; manual cleanup eventually needed (negligible at current scale: ~30 events/year × ~30 KB full + ~365 daily deltas × ~3 KB = ~11 MB/year/event).
- LOCAL devs must remember `--md-target=local` (the default) to avoid attempts at storage write that would fail.

## Status — deliverables (proposed, not yet shipped)

- Migration `supabase/migrations/20260503000003_phase5_staging_reports_bucket.sql`
- `python/pipeline/md_writer.py` (renderer extraction + target switch)
- `python/pipeline/storage_md.py` (bucket I/O wrapper)
- `scripts/create-staging-reports-bucket.sh` (idempotent CLI helper for fresh envs)
- `supabase/tests/37_staging_reports_bucket_rls.sql` (pgTAP — bucket exists, RLS correct)
- `python/tests/test_md_writer.py`, `python/tests/test_storage_md.py`
