# Phase 2 — Draft tables + dry-run loop (M)

**Prerequisites:** Phase 1 ([p1-ir-parsers.md](p1-ir-parsers.md)) — IR + parsers conforming.

## Goal

Crash-consistent, transactional, resumable scratch state for ingest runs, with a CLI that lets the operator dry-run, list, resume, commit, and discard drafts by `run_id`.

## Deliverables

### Migration

- File: `supabase/migrations/2026MMDD_draft_tables.sql`
- Tables:
  - `tbl_tournament_draft (LIKE tbl_tournament INCLUDING ALL, txt_run_id TEXT NOT NULL)`
  - `tbl_result_draft (LIKE tbl_result INCLUDING ALL, txt_run_id TEXT NOT NULL)`
  - Indexes on `txt_run_id` for both.

### Python

- New file: `python/pipeline/draft_store.py` — write/read/discard draft per `run_id`.
- Extend [python/pipeline/ingest_cli.py](../../../python/pipeline/ingest_cli.py) with:
  - `--dry-run`
  - `--resume-run-id UUID`
  - `--list-drafts`
  - `--commit-draft UUID`
  - `--discard-draft UUID`

### RPCs

- `fn_commit_event_draft(p_run_id TEXT)` — moves draft → live, sets joint-pool flag, deletes draft, writes audit.
- `fn_discard_event_draft(p_run_id TEXT)`.

## Risk gate

- Dry-run on a known event produces a markdown diff **without touching live tables**.
- `--resume-run-id` reloads the draft state across terminal sessions.

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p1-ir-parsers.md](p1-ir-parsers.md)
- Successor: [p3-pipeline.md](p3-pipeline.md) — Stages 1-7 are layered on top of these draft tables
- `fn_commit_event_draft` is invoked by [p4-commit-ui.md](p4-commit-ui.md)
