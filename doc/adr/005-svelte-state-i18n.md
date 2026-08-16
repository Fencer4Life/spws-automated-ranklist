# ADR-005: Svelte 5 $state for Internationalisation

**Status:** Accepted
**Date:** 2025-03-06 (M6)
**Amended by:** [ADR-084](084-calendar-quarter-barrel-event-card.md) (retires the no-pluralisation trade-off for calendar strings).

## Amendment (2026-08-09 — pluralisation is no longer deferred)

This ADR accepted a flat key-per-string model with **no pluralisation**, which is wrong for Polish and produced a live defect: `tournaments_count` rendered both *2 turniejów* and *1 tournaments*.

[ADR-084](084-calendar-quarter-barrel-event-card.md) introduces `tournamentsPluralKey()` plus three-form keys (`tournaments_one` / `_few` / `_many`, CQ.53–CQ.54) and genitive month names (`cal_month_1…12`), because a calendar cannot write *18 kwietnia* from a nominative `month_4`. The locale files remain flat JSON — this is a helper that selects the key, not a new i18n framework, so the ADR's core simplicity argument stands.

**The live defect is not yet patched.** The card drops the tournament-count field entirely, so the barrel does not show the broken string, but the helper and keys exist and the remaining consumer has not been migrated.

## Context

The Web Component needs EN/PL language support. Options ranged from full i18n libraries (i18next, svelte-i18n) to a lightweight custom solution.

## Decision

Use a minimal custom approach:
- **Locale store:** Svelte 5 module-level `$state` in `locale.svelte.ts` — zero extra dependencies
- **Translation source:** Two flat JSON files (`en.json`, `pl.json`) — hand-editable by a non-developer
- **Translation function:** `t(key, vars?)` with `{placeholder}` interpolation — intentionally mirrors i18next signature
- **Toggle component:** `LangToggle.svelte` with flag buttons, placed in app header and modal headers
- **Date localisation:** `toLocaleString('pl-PL', { month: 'short' })` for automatic month abbreviations

## Key Sub-decisions

- Default is English — all existing tests assert against English strings
- ODS export headers are never translated (stable data-format labels)
- `t()` falls back to returning the key itself on missing translations — visible bug, never silent
- `{@const}` only inside Svelte special blocks; `$derived` for plain `<div>` context

## Consequences

- 46 locale keys across 9 component groups, all in both `en.json` and `pl.json`
- Switching locale re-renders all visible strings without page reload
- Migration to i18next requires replacing only `locale.svelte.ts` — JSON files and `t()` call sites are compatible
- Trade-off: no pluralisation support (Polish has 3 grammatical forms); current 46 keys contain no plurals
- Trade-off: module-level `$state` persists across vitest suites — safe while no test calls `setLocale()`
