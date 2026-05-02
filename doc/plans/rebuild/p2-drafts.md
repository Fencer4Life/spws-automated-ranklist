# Phase 2 — Draft tables + dry-run loop (M) ✅ DONE 2026-05-02

**Prerequisites:** Phase 1 ([p1-ir-parsers.md](p1-ir-parsers.md)) — IR + parsers conforming. ✅ shipped.

**Status:** All deliverables shipped on `main`. pgTAP 427 → 457, pytest 402 → 422 (excluding pre-existing `test_prod_mirror` CI skip), vitest unchanged at 332.

## Goal

Crash-consistent, transactional, resumable scratch state for ingest runs, with a CLI that lets the operator dry-run, list, resume, commit, and discard drafts by `run_id`.

## Locked design decisions (conversation 2026-05-01)

| # | Decision | Locked form |
|---|---|---|
| D1 | `--dry-run` semantics | Python computes diff from in-memory IR; `fn_dry_run_event_draft` is a stateless validator/counter. **No DB writes anywhere** (cleaner than rollback-then-discard). |
| D2 | RPC error semantics | All 3 RPCs return JSONB with counts; **never throw** on missing `run_id`. CLI inspects counts. Zero-count outcomes route to Telegram via `notifier.warning()` + exit code 1. Successes go to stdout only. |
| D3 | Diff richness | Tournament-level table + match-method aggregate counters. Per-fencer detail and 3-way diff against live = Phase 3. |
| D4 | Migration filename | `supabase/migrations/20260501000004_phase2_draft_tables.sql` (today's date + next slot). Future phases drift to commit date if past the week. |
| D5 | DB access layer | Extend the existing `DbConnector` (Supabase REST). All transaction boundaries inside SQL functions — **no psycopg2 at runtime**. |

## Deliverables (all shipped 2026-05-02)

### Migration

✅ `supabase/migrations/20260501000004_phase2_draft_tables.sql`:

- **`tbl_tournament_draft`** (22 cols) — `id_tournament_draft SERIAL PK` + 20 mirror columns from `tbl_tournament` (incl. Phase 1 stamps `enum_parser_kind` / `dt_last_scraped` / `txt_source_url_used`) + `txt_run_id UUID NOT NULL`. Index on `txt_run_id`.
- **`tbl_result_draft`** (17 cols) — `id_result_draft SERIAL PK` + `id_tournament_draft INT NOT NULL` (renamed linkage column) + 13 mirror columns from `tbl_result` (incl. ADR-050 provenance cols `txt_scraped_name` / `num_match_confidence` / `enum_match_method`) + `txt_run_id UUID NOT NULL`. Index on `txt_run_id`.
- **Loose**: zero FK constraints on either table (drafts may stage unresolved values).
- **`fn_commit_event_draft(p_run_id UUID) RETURNS JSONB`** — atomic move drafts → live via CTE chain mapping `txt_code` → live `id_tournament`, sets `bool_joint_pool_split` on siblings sharing `url_results`, appends `tbl_event_ingest_history` + `tbl_tournament_ingest_history` (Phase 1 ADR-055), writes `tbl_audit_log` rows, deletes drafts. Returns `{run_id, tournaments_committed, results_committed, joint_pool_siblings_flagged, history_rows}`.
- **`fn_discard_event_draft(p_run_id UUID) RETURNS JSONB`** — deletes draft rows, writes `DRAFT_DISCARD` audit (always, even on zero counts). Returns `{run_id, tournaments_discarded, results_discarded}`.
- **`fn_dry_run_event_draft(p_drafts JSONB) RETURNS JSONB`** — pure function; counts tournaments/results from IR payload, detects joint-pool sibling groups by `(weapon, gender, url_results)`. Never writes.

**Deviation note (in migration header):** Plan text said `LIKE tbl_tournament INCLUDING ALL`. Reality uses explicit DDL — `LIKE INCLUDING ALL` would inherit the SERIAL sequence and collide draft inserts with live PK allocation. Explicit DDL gives drafts their own `id_tournament_draft` sequence and renames the linkage on `tbl_result_draft` for clarity. The `txt_run_id` column type is `UUID NOT NULL` (not `TEXT NOT NULL` as plan-text sketched) to match the type Phase 1 already shipped on `tbl_*_ingest_history.txt_run_id`.

### Python

✅ `python/pipeline/draft_store.py` — `DraftStore` class wrapping the supabase REST client. Methods: `write_tournament_drafts`, `write_result_drafts`, `read_drafts`, `list_drafts`, `commit`, `discard`, `dry_run`. Accepts either a `DbConnector` (uses `_sb`) or a raw supabase client.

✅ `python/pipeline/draft_diff.py` — `format_diff(run_id, payload, rpc_result, event_match) -> str`. Renders title, event match, would-create counts, per-tournament table (code, weapon, gender, cat, date, results count, source URL), match-method aggregate (Auto-matched / Pending / Auto-created / Excluded / Unspecified).

✅ Extended `python/pipeline/ingest_cli.py`:
- `--commit-draft <UUID>` → invokes `DraftStore.commit`; zero-count → `notifier.warning()` + exit 1
- `--discard-draft <UUID>` → invokes `DraftStore.discard`; zero-count → `notifier.warning()` + exit 1
- `--list-drafts` → tabular print of outstanding `run_id`s, counts, first-seen
- `--resume-run-id <UUID>` → reads existing drafts, formats markdown diff, prints to stdout
- The 4 new flags are **mutually exclusive** with each other (argparse mutex group).
- `--season-end-year` is now optional when a draft-management flag is used.

**Phase 3 deferral:** `--dry-run` keeps existing path-based behaviour (calls `process_xml_file(dry_run=True)`). The IR-driven dry-run that builds a JSONB payload from the new parsers and invokes `fn_dry_run_event_draft` is wired in Phase 3 once the orchestrator is rewritten against the IR.

### Tests

✅ pgTAP `supabase/tests/27_draft_tables.sql` — `plan(30)`. Covers shape (tables/columns/indexes/FK absence), all 3 RPC signatures, fn_commit_event_draft behaviour (move semantics, joint-pool flag, audit, history, idempotency), fn_discard_event_draft (delete + audit + zero-count), fn_dry_run_event_draft (no-persist + empty payload).

✅ pytest `python/tests/test_draft_store.py` — 9 assertions (P2.D1-D9). Covers all DraftStore methods + resumability across instances + empty-read returns `([], [])`.

✅ pytest `python/tests/test_draft_diff.py` — 5 assertions (P2.M1-M5). Covers header, per-tournament table, match-method aggregation, empty payload, joint-pool sibling group display.

✅ pytest `python/tests/test_ingest_cli.py::TestDraftManagementCli` — 6 assertions (P2.C1-C6). Covers each new flag + zero-count Telegram routing + mutex.

## Risk gate (all met 2026-05-02)

- ✅ Dry-run on a known event produces a markdown diff **without touching live tables** — `format_diff` + `fn_dry_run_event_draft` proven by `test_diff_renders_tournament_table` and pgTAP `27.24`.
- ✅ `--resume-run-id` reloads draft state across terminal sessions — proven by `test_read_drafts_resumable_across_instances` (separate `DraftStore` instances, same supabase backing, same `run_id`).
- ✅ All three test suites GREEN (pgTAP 457, pytest 422, vitest 332).

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p1-ir-parsers.md](p1-ir-parsers.md)
- Successor: [p3-pipeline.md](p3-pipeline.md) — Stages 1-7 are layered on top of these draft tables; the orchestrator gets rewritten to populate drafts via the IR + invoke `fn_dry_run_event_draft` for the IR-driven dry-run path.
- `fn_commit_event_draft` is invoked by [p4-commit-ui.md](p4-commit-ui.md)
