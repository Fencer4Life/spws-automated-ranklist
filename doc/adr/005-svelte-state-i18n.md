# ADR-005: Svelte 5 $state for Internationalisation

**Status:** Accepted
**Date:** 2025-03-06 (M6)

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
