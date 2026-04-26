# ADR-043: EVF Event Code Allocator + Classifier (Phase 2)

**Status:** Accepted (implemented 2026-04-26)
**Date:** 2026-04-26
**Relates to:** ADR-021 (IMEW biennial), ADR-028 (EVF calendar/results import), ADR-039 (stale-event gate / dedup ladder rev 2), ADR-042 (Carry-over engine dispatcher)

## Context

The Phase 1B FK-based carry-over engine (ADR-042) reads `tbl_event.id_prior_event` as the cross-season link. But the EVF scraper, untouched since ADR-028, was still emitting:

- **Venue-slug codes** like `PEW-SALLEJEANZ-2025-2026`, `PEW-SPORTHALLE-2025-2026` — these collide with the FK engine's `^PEW\d+-` numbering scheme and never get linked, becoming permanent FK orphans the admin must hand-fix.
- **A bogus "MEW" kind** for any team event (`MEW-COMPLEXESP-2025-2026` for the European Team Championships). There is no MEW kind. Team events are the singleton `DMEW-{year}` (Drużynowe Mistrzostwa Europy Weteranów); individual European championships are `IMEW-{year}` (singleton, biennial per ADR-021).
- **Wrong organizer.** All PEW/IMEW/DMEW rows were being written with `id_organizer = SPWS`. They are organized by **EVF**.

Until Phase 2, every new EVF scrape compounded the slug-event backlog and required admin SQL cleanup before the FK engine could be enabled for the season.

## Decision

Move event-code generation server-side into a **three-step allocator** (`fn_allocate_evf_event_code`) plus a small **classifier** (`fn_classify_evf_event`). The Python scraper sends the raw scraped payload (`name`, `is_team`, `location`, `country`, …) but no `code`. The RPC computes the code, sets `id_prior_event`, picks the EVF organizer, and reports back per-row how it landed.

### Classifier — `fn_classify_evf_event(p_name, p_is_team) → 'PEW' | 'IMEW' | 'DMEW'`

```
is_team = TRUE                                 → DMEW   (team championship)
is_team = FALSE AND name LIKE '%championship%' → IMEW   (individual championship)
else                                            → PEW    (individual circuit)
```

`MEW` is dead — never emitted. Its single existing seed row (`MEW-COMPLEXESP-2025-2026`) is renamed to `DMEW-2025-2026` by data migration `20260427000003_fix_slug_seed_row.sql`, which also reassigns any PEW/IMEW/DMEW row whose `id_organizer = SPWS` to `EVF`.

### Allocator — `fn_allocate_evf_event_code(p_id_season, p_kind, p_location, p_country)`

Returns `(txt_code, id_prior_event, alloc_path)` where `alloc_path` is one of:

| Path | When | Effect on the import RPC |
|---|---|---|
| `CURRENT_SLOT_REUSE` | Admin pre-created an empty `CREATED`-status slot for this kind whose `(city, country)` matches | RPC `UPDATE`s the slot in place → `PLANNED` |
| `PRIOR_SEASON_MATCH` | Prior season has exactly one matching event of this kind; reuse its `PEWn` number for current season | RPC `INSERT`s with `id_prior_event = prior.id_event` |
| `NEXT_FREE_ALLOC` | Neither current nor prior matches | RPC `INSERT`s with `id_prior_event = NULL` and adds an entry to the `alerts` array; Python fires one Telegram message per alert |

**City normalization** (`fn_normalize_city_key`) folds diacritics via `translate()` (manual NFKD-equivalent for European scripts since `unaccent` is not installed), lowercases, strips non-alphanumerics for location, and resolves country aliases (`Polska→poland`, `Österreich→austria`, `Deutschland→germany`, etc.) — mirroring the Python `_COUNTRY_ALIASES` table from ADR-039 so the allocator's match agrees with the dedup matcher.

**Slug events are skipped** in `MAX(N)+1` computation: the Step C regex `'^PEW\d+-'` excludes legacy venue-slug codes from the candidate set. Existing slug events stay admin-managed (per ADR-042 Phase 1B status memo); they don't pollute new numbering and never participate in city-match.

**Singletons (IMEW/DMEW)**: same three-step ladder but no city match — there's at most one per season. DMEW alternates biennially with IMEW per ADR-021, so `PRIOR_SEASON_MATCH` is normally only meaningful for IMEW.

**Multi-match raises.** If two CREATED slots match the same city, or two prior-season events do, the allocator raises and the import aborts. Admin must disambiguate.

**Race-safety.** `fn_import_evf_events_v2` and `fn_create_evf_event_from_results` take `LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE` before invoking the allocator, since `MAX(N)+1` is non-atomic without it.

### Pre-allocation pathway

The allocator's `CURRENT_SLOT_REUSE` step formalizes the "admin pre-creates empty slots" workflow:

```sql
INSERT INTO tbl_event (id_season, id_organizer, txt_code, txt_name,
                       enum_status, txt_location, txt_country, id_prior_event)
VALUES (
  (SELECT id_season FROM tbl_season WHERE bool_active),
  (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
  'PEW7-2025-2026', 'PEW7 placeholder', 'CREATED',
  'Salzburg', 'Austria',
  (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2024-2025')
);
```

When the EVF scraper next finds a Salzburg event, the allocator hits Step A and `UPDATE`s the slot in place (status flips to `PLANNED`, name + dates fill in, child tournaments materialize). This same pre-creation is what Phase 3's `fn_init_season` will eventually automate; Phase 2's allocator is forward-compatible.

## Alternatives considered

1. **Keep code generation in Python.** Rejected — Python has no transaction with the database, can't `MAX()+1` atomically, and would have to round-trip to look up prior-season events. SQL is the natural home.
2. **Single allocator function with no classifier.** Rejected — classification (PEW vs IMEW vs DMEW) is a separate concern and easier to test independently.
3. **Backfill existing slug events automatically.** Rejected — slug events have ambiguous mappings (which prior `PEWn` should `PEW-LIÈGE` be? Liège could be PEW3 or PEW7 historically). Phase 1B status memo explicitly leaves them as admin territory; this Phase doesn't change that. The single MEW slug row is fixed manually because it's unambiguous (only one DMEW per season).
4. **Hard-fail on multi-match instead of raise.** Same thing for our purposes — `RAISE EXCEPTION` aborts the transaction so partial state isn't committed.

## Consequences

**Positive:**
- New EVF scrapes auto-link `id_prior_event` whenever a city match exists; the FK engine works without admin intervention.
- Slug-event accumulation stops; existing slug events are orphaned but not multiplied.
- Admin gets a per-row Telegram alert only for genuinely new cities (`NEXT_FREE_ALLOC`); reuse and prior-match are summary-only — much less noise.
- `fn_init_season` (Phase 3) just needs to pre-create CREATED slots; the allocator already understands them.
- All EVF events get the correct `EVF` organizer.

**Negative / accepted costs:**
- Country-alias table now lives in two places (Python `_COUNTRY_ALIASES` + plpgsql `CASE` in `fn_normalize_city_key`). Drift would silently miss matches; covered by pgTAP test evf.25 + Python evf.15.
- Per-event detail-page enrichment fields (`url_event`, `url_invitation`, etc.) on `CURRENT_SLOT_REUSE` paths overwrite any value the admin manually set on the pre-created slot only when the new value is non-empty (`COALESCE(NULLIF(...), existing)` guard). Admin-edit policy is "admin wins for non-empty fields"; matches existing ADR-028 refresh semantics.
- `fn_import_evf_events` (v1) is left in place for the existing 12_evf_import.sql tests (4 assertions still call it). Future cleanup task will deprecate v1 once nothing references it.

## Migration & test references

- Migrations: [`20260427000001_event_code_allocator.sql`](../../supabase/migrations/20260427000001_event_code_allocator.sql), [`20260427000002_fn_import_evf_events_v2.sql`](../../supabase/migrations/20260427000002_fn_import_evf_events_v2.sql), [`20260427000003_fix_slug_seed_row.sql`](../../supabase/migrations/20260427000003_fix_slug_seed_row.sql)
- Post-seed mirror (LOCAL only): [`supabase/seed_post_backfill.sql`](../../supabase/seed_post_backfill.sql) re-applies the slug-fix after seed loads (the migration ran against an empty schema in local).
- Tests: [`supabase/tests/18_evf_event_allocator.sql`](../../supabase/tests/18_evf_event_allocator.sql) — evf.25–evf.39 (15 assertions); [`python/tests/test_evf_calendar.py`](../../python/tests/test_evf_calendar.py) — evf.40–evf.42 (3 assertions in `TestEvfPhase2Allocator`).
- Python: [`python/scrapers/evf_sync.py`](../../python/scrapers/evf_sync.py) — `sync_calendar()` calls `fn_import_evf_events_v2` and emits per-alert Telegrams; `_create_cert_event()` calls `fn_create_evf_event_from_results`.

## Cross-phase coordination

- ADR-028 amended (rev 3) — calendar import RPC is now `fn_import_evf_events_v2`; results path uses `fn_create_evf_event_from_results`; both go through the allocator and use EVF organizer.
- ADR-021 unchanged — biennial rule still expressed via the FK engine, now correctly populated by the allocator on import.
- Phase 3 (`fn_init_season` + admin UI) builds on the pre-creation pathway formalised here.
