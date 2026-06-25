# ADR-046: PEW event codes carry weapon-letter suffix; one event = one physical weekend

**Status:** Accepted (Phase 4 implemented 2026-04-27; amended 2026-06-25 — collision guard)
**Date:** 2026-04-27 (amended 2026-06-25)
**Relates to:** ADR-043 (EVF event allocator — amended by this ADR), ADR-044 (Phase 3 wizard — adapts skeleton iteration)

## Context

PEW event codes were originally scraped from Excel under the assumption that the EVF circuit number `N` is shared across all weapons. Reality: EVF runs **per-weapon circuits**, and a single physical weekend can host one, two, or three weapons. Two concrete consequences in the seed data when this ADR was drafted:

- Bundled events (one `txt_code` covers two physical weekends): `PEW3-2024-2025` glued Munich Dec 7-8 (sabre + foil) with Guildford Jan 4 (epee); `PEW3-2025-2026` similarly glued Munich Dec 6 with Guildford Jan 10-11.
- Misleading event-level metadata: `txt_location`, `dt_start`/`dt_end` could only describe one of the two weekends.

The DrilldownModal exposed this directly — fencer Marcin Ganszczyk's PEW3 row showed "Guildford" for what was really a Munich weekend, with corrupt `dt_start = 2024-01-04` (year typo).

## Decision

Each `tbl_event` row represents **one physical weekend at one venue**. The `txt_code` carries a weapon-letter suffix listing which weapons participated:

```
PEW{N}{letters}-{season}     where letters ∈ {e,f,s}+ alphabetical, length 1-3
```

- `PEW3fs-2024-2025` — foil + sabre weekend (Munich Dec 7-8 2024)
- `PEW4efs-2024-2025` — all three weapons at one venue (hypothetical)
- `PEW3s-2025-2026` — sabre-only weekend (e.g. partial seed)

Letters are lowercase, alphabetical (`e` < `f` < `s`). A single-letter suffix is rare in practice — most EVF circuit weekends host 2-3 weapons. A `PEW{N}e-{season}` (epee-only) often signals an incomplete data import rather than a one-weapon event.

Cascade-rebuilt child codes follow the same convention:
```
PEW{N}{letters}-V{age}-{gender}-{weapon}-{season}
```

## Consequences

### Allocator changes (amends ADR-043)

`fn_allocate_evf_event_code` gains a new `p_letters TEXT DEFAULT ''` parameter. The regex matching existing PEW codes becomes `^PEW\d+[efs]*-` to accept both legacy (no suffix) and new shapes. Code generation interpolates `letters` between `N` and the season suffix.

`fn_import_evf_events_v2` derives the letter string from each event's `weapons[]` JSONB via the new helper `fn_pew_weapon_letters(enum_weapon_type[])` (alphabetical: epee → 'e', foil → 'f', sabre → 's', concat).

### Skeleton creator (Phase 3a)

`fn_init_season` regex updates from `^PEW\d+-` to `^PEW\d+[efs]*-` to match weapon-suffixed prior PEW events when iterating skeletons. The skeleton inherits the prior code verbatim except the season suffix swap.

### Cascade rename (Phase 3a)

`fn_update_event` v2 already rebuilds child tournament codes from `(parent_kind, age, gender, weapon, season)` enum fields — no code change needed. The regex extracting `parent_kind` from `txt_code` (`regexp_replace(p_code, '-\d{4}-\d{4}$', '')`) yields `PEW3fs` correctly.

### One-shot data splitter

The Phase 4 migration includes `fn_split_pew_by_weapon()` which:

1. **Splits bundled events.** Detects child tournaments with date span > 3 days; clusters by date (gap > 3 days = boundary). The earliest cluster keeps the original `id_event`; later clusters get next-free `PEW{N}` codes for that season. Tournaments are reparented by date range. Secondary clusters get `txt_location = NULL` (their original parent's location described a different cluster).
2. **Applies weapon-letter suffix to every PEW event.** Computes distinct weapons in children, builds alphabetical letter string, renames event + cascade-renames children.

Idempotent: re-running on already-suffixed events is a no-op when the child weapon set hasn't changed; new tournaments added later promote the suffix on the next run.

### Behavior change in legacy `EVENT_CODE_MATCHING` engine

`fn_event_position` (used by the legacy carryover engine) extracts the prefix via `split_part(code, '-', 1)`. With weapon-suffix codes, prior-season `PEW3fs` and current-season `PEW3s` (different weapon coverage) become **different positions** under prefix matching. This is the *intended* per-weapon semantics — but tests that asserted bundled cross-weapon carry-over now fail because the carry chain is correctly per-weapon.

Existing tests (`09_rolling_score.sql` R.15/R.18, `19_phase3_wizard.sql` ph3.1/ph3.6/ph3.13) were updated to match the new per-weapon reality.

### Frontend

`App.svelte` skeleton-count regex updates from `/^PEW\d+-/` to `/^PEW\d+[efs]*-/`. `SeasonManager.svelte`'s `codeKindLabel` regex includes the suffix in the chip display so admin sees `PEW3fs` instead of just `PEW3`.

## Out of scope

- **PPW (domestic) restructuring.** Polish domestic events run all weapons at one venue per round; the bundling problem doesn't manifest there.
- **Championship code changes.** MEW/IMEW/DMEW/MSW/MPW are single-event-per-season; weapon distinction lives at the tournament level only.
- **Renumbering existing PEW events into strict chronological order.** Splitter assigns next-free `N` for split-out clusters; chronological cleanup remains a manual admin task via the EventManager rename UI.

## Amendment (2026-06-25): collision-resilient splitter

The Step-2 rename assumed the weapon-derived target code (`PEW{N}{letters}-{season}`) was always free. A malformed EVF placeholder export can violate that: the 2026-06-19 PROD export carried `PEW3s-2025-2026` (Munich, Dec 6) and `PEW5s-2025-2026` (Stockholm, Feb 7) — **real EVF sabre weekends** — but with empty EPEE/FOIL placeholder child slots. The splitter derived `efs` and tried to rename them onto the existing `PEW3efs` / `PEW5ef` → `idx_event_code` duplicate-key, which **aborted the entire seed load** (run from `seed_post_backfill.sql`), half-populating the DB and cascading into 14 pgTAP scoring failures.

A first instinct — dropping the offending events — is wrong: it destroys real calendar data (URLs, invitations, venues) for events whose results simply hadn't all been ingested at export time. The correct fix preserves the events and never discards a result.

**Decision:** make the splitter self-healing with two additions, neither of which deletes a result row:

1. **Step 1.5 — prune spurious empty slots.** Before computing suffixes, drop child tournaments that have **no results** AND whose weapon letter is absent from the event's **explicit** `[efs]+` code suffix. This trusts the admin-set code (a sabre-coded `PEW{N}s` keeps only its sabre children; the empty EPEE/FOIL slots are spurious). Legacy `PEW{N}-` codes without a letter suffix are untouched and fall through to the derive-from-children behaviour.

2. **Step 2 — resolve collisions by provenance.** If the weapon-derived target code already belongs to a *different* event:
   - **empty (0-result) holder** → a spurious duplicate of this event (same circuit number + weapon set + season); delete it so this (result-bearing) event takes the clean code (`NOTICE`).
   - **result-bearing holder** → a genuine conflict; skip this rename with a `WARNING` for operator review (no silent data change).

Genuinely distinct events are untouched — they derive different codes and never collide (e.g. `PEW3s` Munich vs `PEW3efs` Guildford both survive). The splitter stays idempotent and a malformed export can no longer break a seed load. Migration `20260625000001_phase4_pew_split_collision_guard.sql`; pgTAP `47_pew_split_collision.sql` (C.1–C.6, TDD). Result-row count is conserved across the seed load (verified: 2673 in = 2673 after).
