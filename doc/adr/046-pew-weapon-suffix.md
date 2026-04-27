# ADR-046: PEW event codes carry weapon-letter suffix; one event = one physical weekend

**Status:** Accepted (Phase 4 implemented 2026-04-27)
**Date:** 2026-04-27
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
