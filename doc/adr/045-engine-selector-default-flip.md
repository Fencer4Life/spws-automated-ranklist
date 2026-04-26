# ADR-045: Carry-over engine selectable per-season via admin UI; default flipped to FK

**Status:** Accepted (Phase 3a backend implemented 2026-04-26; UI dropdown lands in Phase 3b)
**Date:** 2026-04-26
**Relates to:** ADR-042 (engine dispatcher — amended by this ADR), ADR-044 (Phase 3 wizard)

## Context

ADR-042 introduced the strangler-fig dispatcher with two engines (`EVENT_CODE_MATCHING` legacy, `EVENT_FK_MATCHING` Phase 1B). The column DEFAULT was deliberately left at `EVENT_CODE_MATCHING` so that no existing season changed behavior on Phase 1A/1B deploy. Admin would opt seasons in once each was verified safe via `fn_compare_carryover_engines`.

Two things have changed since then:

1. **The FK engine has been verified safe.** Phase 1B's deploy (2026-04-26) ran A/B comparison on SPWS-2025-2026; the only deltas were corrections (slug PEWs that legacy mis-attributed via prefix collision; PEW10 with no current-season slot; IMEW carrying biennially via FK rather than via prefix-string heuristic). No regressions.
2. **Phase 3's `fn_init_season` now creates skeletons with `id_prior_event` linked.** New seasons going forward will have a complete FK chain by construction. Without flipping the default, every greenfield season would route to the legacy engine despite having a perfect FK substrate sitting unused.

Plus the runbook §5 ("flip via SQL") flow — admin SSH-ing into psql to `UPDATE tbl_season SET enum_carryover_engine = ...` — is exactly the kind of friction Phase 3 is supposed to eliminate.

## Decision

Two changes, made in the same Phase 3a migration:

### 1. Flip the column DEFAULT for new rows

```sql
ALTER TABLE tbl_season
  ALTER COLUMN enum_carryover_engine
    SET DEFAULT 'EVENT_FK_MATCHING'::enum_event_carryover_engine;
```

Existing rows are **not** rewritten. Pre-Phase-3 seasons keep whatever value they currently hold (almost always `EVENT_CODE_MATCHING`). Admin opts each one in via the UI dropdown.

### 2. Engine selection moves into ScoringConfigEditor as a dropdown

A new Section 4b "🔀 Silnik carry-over" between Intake and Rules sections. Dropdown lists **all values** of `enum_event_carryover_engine` dynamically (via PostgREST enum introspection or a hard-coded list synced from the enum) so future engines (`EVENT_CITY_MATCHING`, etc.) automatically appear.

Per-engine descriptive hint + (where applicable) deprecation tag:
- `EVENT_FK_MATCHING — default (FK based, ADR-042/043)` — preferred
- `EVENT_CODE_MATCHING — (legacy) prefix-string` — kept for compatibility, has the `(legacy)` tag

Save flow: ScoringConfigEditor's `onsave` payload gains an `engine` field; App.svelte's handler patches `tbl_season.enum_carryover_engine` separately from the `tbl_scoring_config` patch (instant flip, no migration needed).

### 3. Reachability rule — past-complete seasons hide the 🎯 button

To avoid an admin accidentally flipping the engine on a finalised historical season, the `🎯 Konfiguracja punktacji` button is rendered only on **future** + **active** seasons. Past-complete (`dt_end < today`) seasons hide the button entirely. The existing `readonly` prop on `ScoringConfigEditor` stays as defense-in-depth in case the editor is reached via a bookmarked URL.

### Why inside ScoringConfigEditor and not on the season form?

The season form is the wizard's Step 1 — used only at season creation. Engine flips happen throughout a season's life (e.g. flipping CODE→FK after slug-event cleanup). ScoringConfigEditor is reachable from every active/future season's card, so the engine dropdown is reachable any time.

The wizard's Step 2 embeds `ScoringConfigEditor`, so the engine choice for a brand-new season is implicitly carried via the editor's `onsave` payload — Step 1 stays clean.

## Alternatives considered

1. **Flip the default and rewrite all existing rows in the same migration.** Reject — silent behavior change on existing seasons would invalidate finalised ranklists and contradict ADR-042's "per-season opt-in" guarantee. Phase 1B's A/B verification is per-season, not global.
2. **Keep CODE as default; require explicit engine choice on every wizard run.** Reject — the wizard's whole point is "good defaults"; making admin choose CODE-or-FK every time is friction without value (FK is now strictly better for new seasons because skeletons have FKs by construction).
3. **Hard-code only `EVENT_FK_MATCHING` in the UI; remove the dropdown.** Reject — the strangler-fig design's whole value is being able to ship new engines without rewriting existing ones. A dropdown is the right abstraction; the UI should grow with the enum.
4. **Engine dropdown on the season identity form.** Reject — see "Why inside ScoringConfigEditor" above.

## Consequences

**Positive:**
- Greenfield seasons get the correct engine for free. No `psql` step.
- Admin can flip engine on existing seasons via UI — runbook §5 ("flip via SQL") is superseded.
- Past-complete seasons are protected from accidental engine flips by the visibility rule.
- The dropdown is extensible by design: adding a new engine = `ALTER TYPE … ADD VALUE` + new engine function + new i18n key. UI auto-renders.

**Negative / accepted costs:**
- Two writes for an engine flip (scoring config patch + season patch). Acceptable; both are sub-ms.
- `ScoringConfigEditor`'s `onsave` payload widens to include a non-scoring field. Acceptable; the editor already passes `id_season` which is also non-scoring metadata.
- Past-complete season hidden button = admin can't open the editor at all on those seasons. Acceptable since post-finalisation reads happen through CalendarView/Ranklist, not the editor.

## Migration & test references

- Migration: [`20260428000001_phase3_schema_extensions.sql`](../../supabase/migrations/20260428000001_phase3_schema_extensions.sql)
- Tests: [`supabase/tests/19_phase3_wizard.sql`](../../supabase/tests/19_phase3_wizard.sql) — ph3.22a (DEFAULT is FK), ph3.22b (`fn_create_season_with_skeletons` honors `p_carryover_engine`), ph3.22c (existing rows preserved)
- Phase 3b vitest assertions to come: ph3.37a–e (dropdown lists all enum values, default-FK-on-new, legacy tag on CODE, `onsave` payload patches season separately, existing season's editor shows current engine), ph3.37f–g (button visibility rule)

## Future work

- **Phase 3b** lands the dropdown in `ScoringConfigEditor.svelte` + 🎯 button visibility guard in `SeasonManager.svelte` + i18n keys (`sc_section_engine`, `sc_engine_label`, `sc_engine_opt_*`, `sc_engine_hint_*`).
- **Eventually**, when no live season uses `EVENT_CODE_MATCHING`, drop the legacy engine functions and remove the dropdown's CODE option. The dropdown's extensibility supports this — just remove an enum value.
- **Audit-log integration**: engine flips should fire an `tbl_audit_log` entry (changing engine alters reported scores). The existing `trg_audit_season` trigger covers UPDATEs on `tbl_season`, so this is already in place; verify the audit row captures `enum_carryover_engine` in the JSONB diff.
