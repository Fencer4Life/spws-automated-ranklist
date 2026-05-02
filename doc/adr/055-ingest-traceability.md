# ADR-055: Ingest Traceability — Per-Parser Provenance + Bounded History

**Status:** Accepted; LOCAL implementation committed 2026-05-01 as part of Phase 1 of the rebuild (`/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md`). CERT/PROD land via Phase 6 promotion.

**Date:** 2026-05-01

**Relates to:** ADR-050 (Unified Ingestion Pipeline) — this ADR fills the parser-provenance gap left open in ADR-050. Identity provenance (already on `tbl_result.{txt_scraped_name, num_match_confidence, enum_match_method}` per ADR-050 Phase 0) and parser provenance (this ADR) are complementary: identity answers "who is this fencer?", parser provenance answers "which scraper produced this row?".

## Context

The legacy ingestion pipeline gave no answer to "which parser produced this tournament's results?" or "when was this last scraped?" beyond `tbl_event.url_results` (the URL the admin entered) and the tournament's `enum_import_status`. After the unified pipeline lands, eight different parsers (FencingTime XML, FTL, Engarde, 4Fence, Dartagnan, EVF API, file_import, Ophardt-HTML) will all feed the same orchestrator. Without per-row provenance:

- Forensic queries like "every Ophardt-parsed tournament this season" are impossible.
- Re-ingest history is invisible; if a tournament was re-scraped twice via different parsers, only the latest parsing exists in the data and there is no audit trail.
- Bug-replay is hard: when a parsing bug is discovered, you can't tell which existing rows were produced by the broken code.
- Phase 5 of the rebuild reviews ~750 tournaments individually; admin needs a "what produced this last time?" badge per row, otherwise every review starts from zero context.

The orchestrator's draft tables (Phase 2, ADR-050) already carry `txt_run_id` UUID, but that lives only on drafts, not on committed live rows.

## Decision

Add per-parser provenance at two levels of the data hierarchy:

1. **Hot stamp** (the "current" answer) — three columns on each parent row: `enum_parser_kind`, `dt_last_scraped`, `txt_source_url_used`. Cheap reads in admin UI; overwritten on each successful re-scrape.
2. **Audit history** (the "how did we get here" answer) — append-only sibling table per parent. Each successful commit appends one row carrying the stamp plus `txt_run_id` (linking back to the Phase 2 draft that produced this commit). Capped at 6 rows per parent by a `BEFORE INSERT` trigger that evicts the oldest row beyond top-5-by-recency before each insert.

Hierarchy reminder (per house convention): `tbl_event` → `tbl_tournament` → `tbl_result`. Stamps live at the **event** and **tournament** levels; results inherit from their tournament. A single event can mix sources across child tournaments (e.g., FTL primary + EVF API re-fix on one tournament), so an event-level stamp alone would lie.

### Eight design decisions (locked 2026-05-01 via brainstorm)

| # | Decision | Rationale |
|---|---|---|
| **D1** | Stamp at **both** event and tournament level | Some events mix parsers across child tournaments; an event-level-only stamp would silently lie in those cases |
| **D2** | Each stamp = **parser + timestamp + source URL** | Triplet of "what / when / where" — minimum needed for the admin to replay or re-fetch |
| **D3** | **Overwrite current stamp + append to history** | Hot path stays cheap (no JOIN); forensic path stays complete |
| **D4** | **Two separate** history tables (`tbl_event_ingest_history`, `tbl_tournament_ingest_history`) | Avoids a polymorphic FK with a nullable parent pointer; each row is unambiguous |
| **D5** | **Per-parent cap of 6 rows**, older auto-deleted on insert via `BEFORE INSERT` trigger | Bounded growth without cron; absolute ceiling ~8,300 rows total at peak (~80 events + ~750 tournaments × 6 + per-parent cap-of-six) |
| **D6** | Only **successful commits** trigger a history row | Failed/discarded drafts have their own audit trail via `tbl_*_draft.txt_run_id` (Phase 2). The history table earns its keep as the *committed* record. |
| **D7** | History row carries **stamp + run_id** | Run_id (UUID) is structurally load-bearing — it's the only link from a committed history row back to the draft tables that produced it |
| **D8** | Land it in **Phase 1** (not deferred to Phase 4) | Schema is small, design is locked, and Phase 2/3/4 get a stable target instead of designing around a moving one |

### Schema

Migration: `supabase/migrations/20260501000003_phase1_ingest_traceability.sql`.

**Enum** (mirrors Python `SourceKind` in `python/pipeline/ir.py`, declared order kept aligned):

```sql
CREATE TYPE enum_parser_kind AS ENUM (
  'FENCINGTIME_XML', 'FTL', 'ENGARDE', 'FOURFENCE',
  'DARTAGNAN', 'EVF_API', 'FILE_IMPORT', 'OPHARDT_HTML'
);
```

**Stamp columns** (added to both `tbl_event` and `tbl_tournament`, all nullable — events may exist before any scrape; cert_ref-fallback events also produce stamps via the cert_ref parser):

```sql
ALTER TABLE tbl_event       ADD COLUMN enum_parser_kind     enum_parser_kind,
                            ADD COLUMN dt_last_scraped      TIMESTAMPTZ,
                            ADD COLUMN txt_source_url_used  TEXT;
ALTER TABLE tbl_tournament  ADD COLUMN enum_parser_kind     enum_parser_kind,
                            ADD COLUMN dt_last_scraped      TIMESTAMPTZ,
                            ADD COLUMN txt_source_url_used  TEXT;
```

**History tables** (one per parent, with FK CASCADE on parent delete, UNIQUE on (parent_fk, txt_run_id), and an index on (parent_fk, dt_committed DESC) for "show me the last 6"):

```sql
CREATE TABLE tbl_event_ingest_history (
  id_event_ingest_history  SERIAL PRIMARY KEY,
  id_event                 INT NOT NULL REFERENCES tbl_event(id_event) ON DELETE CASCADE,
  txt_run_id               UUID NOT NULL,
  enum_parser_kind         enum_parser_kind NOT NULL,
  dt_committed             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  txt_source_url           TEXT,
  UNIQUE (id_event, txt_run_id)
);
-- mirror: tbl_tournament_ingest_history with id_tournament FK
```

**Cap-of-6 trigger** (one per history table, defensive `OFFSET 5` deletes any rows beyond the top-5-by-recency before NEW is inserted, so post-insert total = 6):

```sql
CREATE OR REPLACE FUNCTION fn_enforce_event_history_cap()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM tbl_event_ingest_history
   WHERE id_event = NEW.id_event
     AND id_event_ingest_history IN (
       SELECT id_event_ingest_history
         FROM tbl_event_ingest_history
        WHERE id_event = NEW.id_event
        ORDER BY dt_committed DESC, id_event_ingest_history DESC
        OFFSET 5
     );
  RETURN NEW;
END;
$$;
```

### Behavior contract (verified by `supabase/tests/26_ingest_traceability.sql`)

- 26.1–26.2: enum exists with the 8 declared values in declared order.
- 26.3–26.8: stamp columns exist on both parent tables with correct types (nullable).
- 26.9–26.18: history tables exist with the correct column types (UUID, enum, TIMESTAMPTZ, TEXT).
- 26.19: deleting a parent event cascades to its history rows (zero survivors).
- 26.20: duplicate (parent_fk, txt_run_id) raises `unique_violation`.
- 26.21: inserting 7 rows for one parent leaves exactly 6 (cap holds).
- 26.22: the *oldest* row is the one evicted (verified by URL identity).
- 26.23: cap trigger fires on the tournament side too.

23 pgTAP assertions; all green (404 → 427 total).

## Alternatives considered

### A. Discriminator-only (single columns on parent rows; no history table)

Cheaper. But re-scrapes overwrite each other; no forensic chain; no answer to "this tournament was re-scraped 3 times — show me what changed each time." Rejected because the rebuild's premise (per ADR-050) is exactly that we lost the trail of how data got here. Re-creating the same gap on day one of the new pipeline isn't an improvement.

### B. History-only (no current-stamp columns; always JOIN to history for the "current" answer)

Pure normal form. But every admin-UI row needs a sub-query (`SELECT ... FROM history WHERE parent = X ORDER BY dt_committed DESC LIMIT 1`). Rejected because the admin Calendar/Event UI re-renders these badges constantly during Phase 5; the join cost grows with row count. The hybrid pays one trigger insert + a denormalized column to skip every read-time join.

### C. Single polymorphic history table with `target_kind` discriminator

One table with `target_kind ENUM('EVENT','TOURNAMENT')` + nullable `id_event` and `id_tournament`. Saves one table at the cost of polymorphism. Rejected because the FK column nullability hides bugs (orphan rows pointing to nothing), and queries always have to remember to filter by `target_kind`. Two tables with non-null FKs is the boring-and-correct option.

### D. Result-level provenance (`tbl_result.txt_run_id`)

Considered for completeness. Rejected because Stage 11 commit replaces a tournament's results atomically (drop-and-reload per ADR-050); inheritance through `tbl_result.fk_tournament → tbl_tournament.txt_last_run_id`-equivalent is sufficient. Adding result-level run_id buys nothing today and adds 4 columns × ~2,700 result rows of denormalized data.

### E. Time-based retention (delete history rows older than X months) instead of count cap

Standard pattern. Rejected because (i) it requires a scheduled job that someone has to remember; (ii) for low-volume parents like our events, 6 historical scrapes can span years — a date-based cap could erase the only previous record of a rarely-touched event.

### F. Land it in Phase 4 (commit path)

Considered. Rejected because Phase 2/3 designs the orchestrator and the diff renderer; both want a stable target schema for the run_id linkage. Pushing the schema to Phase 4 forces Phase 2/3 to use scratch state that has to be migrated later.

## Consequences

**Positive:**
- Per-tournament source badge becomes a one-row read on `tbl_tournament` columns — admin UI gets the answer for free.
- Forensic queries like "every tournament Ophardt parsed this season" become trivial: `WHERE enum_parser_kind = 'OPHARDT_HTML' AND dt_last_scraped >= ...`.
- Replay loop: an admin can pull `txt_source_url_used` and re-fetch the source bytes today, even if the admin-entered `url_results` later changes.
- Cap-of-6 trigger keeps growth bounded forever without cron — set-and-forget.
- `txt_run_id` becomes the load-bearing identifier across Phase 2 drafts, Phase 4 commit, and Phase 5 review.

**Negative:**
- Two new tables to maintain. Their schema is locked early; future evolution (e.g., adding `txt_admin_user`) requires migrations.
- The `BEFORE INSERT` trigger fires on every commit. Trigger is O(log N) due to indexes, N ≤ 6, so cost is negligible but non-zero.
- Stamp columns on `tbl_event` and `tbl_tournament` denormalize the latest history row — the trigger and Stage 11 commit must keep them in sync. Drift between the columns and the most-recent history row is a possible bug class going forward.
- Result-level provenance is **not** added (alternative D rejected). If a future use case needs per-result run linkage, this ADR will need to be revisited.

## Migration path for existing data

`enum_parser_kind`, `dt_last_scraped`, `txt_source_url_used` are nullable on add. Pre-rebuild rows have NULL — semantics: "no scrape recorded under the new model." Phase 5 (per ADR-050) re-ingests every event, populating the columns and the history table on each commit. After Phase 5: all production-active events have non-NULL stamps. Events sourced via the cert_ref fallback parser (no live URL available) get `enum_parser_kind = 'CERT_REF'` and `txt_source_url_used = NULL`.

CERT/PROD inherit the schema via Phase 6 promotion (per ADR-050). The rebuild restores from rebuilt LOCAL, so the columns and history tables arrive fully populated.

## Open follow-ups

- **Phase 2 (drafts):** when the draft → live commit path is wired, write to `tbl_*_ingest_history` atomically with the live-table writes inside `fn_commit_event_draft(p_run_id)`.
- **Phase 4 (commit + UI):** admin Calendar/Event view should surface `enum_parser_kind` as a badge and `dt_last_scraped` as a relative timestamp. History modal shows the last 6 entries.
- **Phase 5 (execute):** every event reviewed and committed populates these columns; risk-gate verifies non-NULL coverage on all active events.
- **Multi-admin futures:** `txt_admin_user` was rejected in this ADR (D7 / alternative trail) but can be added later via ALTER TABLE if SPWS adds more than one admin operator.
