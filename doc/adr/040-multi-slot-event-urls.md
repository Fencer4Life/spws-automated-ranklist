# ADR-040: Multi-Slot Event Result URLs with Compact-on-Save

**Status:** Accepted
**Date:** 2026-04-25
**Relates to:** ADR-028 (EVF Calendar + Results Import — refresh invariant generalises), ADR-029 (Tournament URL Auto-Population — discovery loop becomes multi-URL), ADR-030 (Event Registration URL — same form), ADR-036 (PROD Export — schema-driven, auto-handles), ADR-039 (EVF Dedup — unaffected).

## Context

The EVF Circuit Budapest event (2025-09-20/21) has **three** organiser-published Engarde URLs, one per weapon:

```
2025_09_20_pbt   → Day 1, Épée
2025_09_21_kard  → Day 2, Sabre
2025_09_21_tor   → Day 2, Foil
```

Our schema models `tbl_event.url_event` as a single TEXT column. ADR-029's `populate-urls.yml` reads exactly one event-level URL and runs platform discovery once — which means for Budapest only one weapon's tournaments can be auto-populated; the other two must be entered manually for each of ~10 tournaments. Same problem will recur for any event the organiser splits across multiple platform URLs (per-weapon, per-day, or per-day×weapon).

The naming itself was always a slight lie: `url_event` is not the *event's* URL — it's the URL of the **publishing platform's grouping entity** (an Engarde "tournament", an FTL "event", a 4Fence base path). In simple cases (Naples), one such grouping covers everything. In Budapest, three do.

## Decision

Add **4 nullable URL columns** on `tbl_event` (`url_event_2`, `url_event_3`, `url_event_4`, `url_event_5`) alongside the existing `url_event`. Total: up to 5 result-platform URL slots per event. Slots are equal-status — no role labels, no per-slot enum, no primary pointer.

On every save (`fn_create_event` / `fn_update_event` / `fn_refresh_evf_event_urls`), the 5 inputs are **compacted**:

1. **Trim** whitespace and treat empty as NULL.
2. **Drop** NULL values.
3. **Dedupe** preserving first occurrence.
4. **Pad** with NULL to length 5.
5. Assign `[1] → url_event`, `[2..5] → url_event_2..5`.

This is implemented as a single helper `fn_compact_urls(VARIADIC TEXT[]) RETURNS TEXT[]`, called by every write path so the invariant holds regardless of caller.

**Invariant after every save:** *if any URL is set, slot #1 (`url_event`) is set.* All existing code that special-cases `url_event` (calendar 🔗 link, ⬇ Import button visibility, ADR-029 auto-populate seed, EVF refresh write order) keeps working unchanged.

The tournament URL discovery script (ADR-029, `python/tools/populate_tournament_urls.py`) iterates all non-null slots, runs platform-detection-and-discovery per URL, and merges the per-(weapon, gender, category) results, deduplicating on first occurrence with a logged warning on collision.

`tbl_tournament.url_results` is **unchanged** — it remains the leaf URL rendered in the ranklist drilldown.

## Why this shape

1. **Schema simplicity.** Four nullable TEXT columns; no new tables, no enums, no JSONB, no array column. ADR-036 schema-driven export auto-includes them. Promote.py needs one payload-key extension. Migrations stay a single ALTER + helper function.
2. **No semantic break.** `url_event` keeps its column name, RPC parameter name, calendar exposure, and "primary" role. Frontend, scrapers, promote.py, and seed exports keep working. Compact-on-save makes "URL #1 = the canonical one" a structural invariant rather than a coincidence.
3. **Slot positions are non-semantic.** The admin doesn't care if Budapest's `pbt` URL lives in slot #1 vs #3 — it's just one of three discovery seeds. Compaction loses nothing meaningful and prevents the gap-handling pathologies (slot #1 NULL, #2 set → 🔗 link disappears even though URLs exist).
4. **Refresh invariant generalises trivially.** ADR-028 NULL-only refresh still applies per slot. After compaction, NULL slots are always at the bottom, so newly-discovered URLs land in the lowest empty slot — predictable and idempotent.
5. **5-slot ceiling is intentionally arbitrary.** Covers Budapest (3) with 2× headroom. If a real event with 6+ URLs ever appears, that's the moment the slot-based design becomes wrong-shaped and we revisit (probably via a `tbl_event_url` child table). YAGNI for now.

## Alternatives considered

1. **Move `url_event` to `tbl_tournament` (per-tournament URL).** Cleanest data model — URL is a property of the publishing-platform-grouping which maps M:1 to tournaments. Rejected by the user: the drilldown UI already renders `tbl_tournament.url_results` (the leaf), and decoupling event-level platform URLs from event-level admin would require touching ADR-029 discovery, EVF scraper writes, and the event-card 🔗 link path simultaneously. The 5-slot extension is additive and lets us ship the actual fix without that refactor.

2. **`url_event TEXT` → `arr_url_event JSONB` array.** One-column change, but the NULL-only refresh invariant becomes ambiguous on arrays (does adding a 4th URL "overwrite" an existing 3-element value?), the UI loses per-slot input identity, and CRUD/promote/locales all need rework. Rejected for higher cost than 4 nullable columns at no semantic gain.

3. **`tbl_event_url(id_event, url, enum_role, int_seq)` child table.** First-class modelling of N URLs per event with optional role labels. Rejected as overkill for an event-shape that's 1-URL in the 95% case and never observed beyond 5; cost-correct only if 6+ URLs become routine, which we'd revisit then.

4. **Store as-given (no compaction), with `if url_event OR url_event_2 OR ...` checks everywhere.** Spreads the change across every consumer of `url_event` for no real gain. Slot positions are non-semantic, so admin's choice of "which slot got cleared" carries no information worth preserving.

5. **Explicit `int_primary_url_slot` pointer column.** Solves a problem we don't have — nobody's argued slot identity needs to survive across edits. YAGNI.

## Consequences

### Positive

- **Backward-compatible.** Every existing caller of `fn_create_event` / `fn_update_event` / `fn_refresh_evf_event_urls` keeps working — new params are nullable defaults, JSONB payloads ignore unknown keys.
- **`url_event` semantics preserved.** Calendar 🔗 link, ⬇ Import button, ADR-029 single-URL seed path, EVF scraper write order — all unchanged because compact-on-save guarantees slot #1 holds the first non-null value.
- **Discovery generalises.** Budapest auto-populates from 3 URLs in one ⬇ click instead of 1 + 20 manual entries.
- **Refresh invariant still trivial.** ADR-028's "scraper only writes when target NULL/empty" extends per-slot.
- **PROD seed export auto-handles.** ADR-036 schema-driven export picks up the 4 new columns from `information_schema.columns`.

### Negative

- **Slot positions reshuffle on save.** Admin who pastes URLs into [NULL, B, NULL, D, NULL] sees them re-rendered as [B, D, NULL, NULL, NULL] after save. Mildly surprising once; structurally consistent forever after.
- **EVF scraper still writes only slot #1.** ADR-028 scraper auto-fills `url_event` from the EVF detail page; it does not auto-populate slots #2–5 (would require teaching the scraper that one EVF event maps to N platform URLs, which is a separate, harder problem). Admin manually fills slots #2–5 for the rare multi-URL events. Acceptable: the gap is small (single-digit events per season).
- **`fn_compact_urls` is centrally damaging if buggy.** Mitigated by direct unit tests of the helper independent of caller RPCs (15.2, 15.3).

### Outbound surface (none)

No new Telegram messages, no new RPCs beyond `fn_compact_urls` (helper), no new admin commands.

## Test plan

| ID | Assertion |
|---|---|
| `15.1` | `tbl_event` has columns `url_event_2..5` (TEXT, nullable). |
| `15.2` | `fn_compact_urls` exists and returns a 5-element TEXT[]. |
| `15.3` | `fn_compact_urls` trims, drops empties, dedupes preserving first occurrence, pads NULL — `[' A ', NULL, 'A', 'B', '   ']` → `['A','B',NULL,NULL,NULL]`. |
| `15.4` | `fn_create_event` accepts `p_url_event_2..5` and applies compact (gap input → compacted storage). |
| `15.5` | `fn_update_event` applies compact when admin clears slot #1 of [A,B,C] → stored [B,C,NULL,NULL,NULL]. |
| `15.6` | `fn_refresh_evf_event_urls` accepts the new keys, applies per-slot NULL-only invariant, then re-compacts. |
| `9.44a–f` | EventManager.svelte: 5 inputs, disclosure auto-open when slots #2–5 set, filled-count, save handler trims/drops/dedupes/pads, primary styling on slot #1. |
| `3.16k–m` | `populate_tournament_urls`: iterates non-null slots, merges by (weapon,gender,category) preserving first occurrence, logs warning on collision. |
| `prom.8` | Calendar-promote payload carries `url_event_2..5` to PROD via `fn_refresh_evf_event_urls`. |

## References

- Mockup: [`doc/mockups/m12_event_edit_multi_url.html`](../mockups/m12_event_edit_multi_url.html) (two states: typical 1-URL event + Budapest 3-URL event).
- Migration: `supabase/migrations/20260425000001_event_multi_url.sql`.
- Helper: `fn_compact_urls(VARIADIC TEXT[]) RETURNS TEXT[]` — pure, side-effect-free, idempotent.
- Discovery: [`python/tools/populate_tournament_urls.py`](../../python/tools/populate_tournament_urls.py) — `main()` loop extended.
- Promote: [`python/pipeline/promote.py`](../../python/pipeline/promote.py) — calendar-mode payload extension.
