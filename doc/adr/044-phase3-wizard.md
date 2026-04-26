# ADR-044: Phase 3 Admin UI + Season-Init Wizard (atomic transaction model)

**Status:** Accepted (Phase 3a backend implemented 2026-04-26; Phase 3b/3c UI pending)
**Date:** 2026-04-26
**Relates to:** ADR-018 (Rolling Score), ADR-021 (IMEW biennial), ADR-042 (engine dispatcher), ADR-043 (allocator), ADR-045 (engine selector + default flip)

## Context

Phase 1B (FK carry-over engine) and Phase 2 (EVF allocator + classifier) shipped to CERT 2026-04-26. The schema is in place; rolling-score correctness is verified per-season; but the admin still has to drive the carry-over chain by hand:

- `psql` to pre-create `CREATED`-status PEW slots (runbook §9)
- `psql` to insert `IMEW`/`DMEW` placeholders in DMEW years (runbook §4)
- `psql` to manually link `id_prior_event` for slug events (runbook §3)
- SQL editor to toggle `tbl_season.int_carryover_days`, `enum_european_event_type`, `enum_carryover_engine` (runbook §5)

Phase 3 turns all of that into point-and-click. The wizard pre-allocates skeleton events, the EDIT form lets admin edit `txt_code` (with cascade to children) and pick `id_prior_event` from a dropdown, and the ScoringConfigEditor gains an engine dropdown so flipping CODE→FK is one click + Save.

The shape of the wizard, and the atomicity guarantee around it, are the architectural decisions captured here.

## Decision

**Three-step modal wizard with a single atomic backend RPC.**

### UX shape

1. **Step 1 — Identity + carry-over:** `txt_code`, `dt_start`, `dt_end`, `int_carryover_days` (default 366), `enum_european_event_type` segmented control (None / IMEW / DMEW), `bool_show_evf_toggle` checkbox.
2. **Step 2 — Scoring config:** embeds `ScoringConfigEditor` pre-filled via `fn_copy_prior_scoring_config(p_dt_start)`. Banner reads "Skopiowane z SPWS-YYYY-YYYY" when prior exists, "Wartości domyślne" when not. ScoringConfigEditor's Section 4b "🔀 Silnik carry-over" hosts the engine dropdown (defaulting to `EVENT_FK_MATCHING` for new seasons — see ADR-045).
3. **Step 3 — Confirm:** `fn_preview_init_season(...)` shows the skeleton inventory (e.g. "5 PPW + 9 PEW + 1 MPW + 1 MSW + 1 IMEW = 17") and the chosen scoring config diff. Buttons: "← Wstecz" (preserves entered values), "✓ Utwórz" (commit), "✕ Anuluj" (full discard).

### Backend atomicity

`fn_create_season_with_skeletons(p_code, p_dt_start, p_dt_end, p_carryover_days, p_european_type, p_carryover_engine, p_scoring_config, p_show_evf)` is the single RPC the wizard's "✓ Utwórz" calls. Body:

```sql
BEGIN
  v_id := INSERT INTO tbl_season (...)         -- trg_season_auto_config inserts default scoring config
  PERFORM fn_import_scoring_config(p_scoring_config || jsonb_build_object('id_season', v_id, 'show_evf_toggle', p_show_evf))
  v_count := (fn_init_season(v_id)).skeletons_created
  RETURN (v_id, v_count)
END
```

Implicit Postgres transaction. If anything raises (duplicate code, JSONB schema drift, init exception), the entire wizard's effect is rolled back — the season is gone, scoring config is gone, skeletons never existed. This matches the user's "cancel = nothing persists" requirement and removes the half-shipped-season failure mode that the runbook flow has.

### Skeleton inventory

`fn_init_season(p_id_season)` is the algorithm:

- Resolve chronological prior via `MAX(id_season) WHERE dt_end < p_id_season.dt_start`
- For each prior `^PPW\d+-` event → one CREATED skeleton with NULL location (rotating venues)
- For each prior `^PEW\d+-` event (numbered only — slugs excluded) → one CREATED skeleton with prior's location/country copied
- Always insert `MPW-{suffix}` and `MSW-{suffix}` (`MSW` prior lookup uses `^I?MSW-` to handle the IMSW seed-naming inconsistency)
- If `enum_european_event_type` is set, insert `IMEW-{suffix}` or `DMEW-{suffix}` with biennial-aware lookup (most recent prior matching event regardless of season distance — covers IMEW biennial alternation, ADR-021)
- Each skeleton gets 6 V2 child tournaments (M/F × EPEE/FOIL/SABRE) via `_fn_create_skeleton_children`
- First-ever season (no chronological prior): create `MPW` + `MSW` + optional European singletons only, all with NULL `id_prior_event`

`fn_init_season` is **idempotency-guarded** — refuses if any event exists in the target season already. The wizard never calls it twice (atomic RPC); `fn_revert_season_init` is the only path back to a pristine state.

### Revert semantics

`fn_revert_season_init(p_id_season)` is the EDIT form's "↶ Cofnij całość" link. It refuses if any skeleton has advanced past `CREATED`. Otherwise it deletes children → events → scoring_config → season in one transaction. The transition trigger's universal `→ CREATED` rollback (Phase 1B) lets admin manually demote skeletons that have been promoted, which then re-enables full revert.

### Cascade rename in `fn_update_event` v2

Adds `p_code TEXT` and `p_id_prior_event INT` (both default NULL = "leave unchanged"). When `p_code` differs from the current event code, child tournament codes are **rebuilt from scratch** using their existing `(enum_age_category, enum_gender, enum_weapon)` fields and the new event code:

- Detection key: `txt_code ~ '-V\d-'` on a sample child → PPW/PEW pattern (`{kind}-V{age}-{G}-{W}-{suffix}`)
- Otherwise: MEW/MSW/MPW pattern (`{full_event_code}-{G}-{W}`)

A naive `replace(child_code, old_code, new_code)` does not work for PPW/PEW because the season suffix is embedded mid-code, not at the start.

## Alternatives considered

1. **Inline form (no modal).** Reject — the season-create form is already cramped; embedding scoring config + preview in-line would push the FAB pattern off-screen on small admin laptops.
2. **One RPC per step (`fn_create_season` → `fn_set_scoring_config` → `fn_init_season`).** Reject — three separate transactions mean a failed step 3 leaves a half-created season + scoring config orphaned. The wizard would need defensive cleanup paths in the frontend. Atomic RPC removes this entire failure class.
3. **Skip the preview step, commit on step 2.** Reject — without a preview, admin has no chance to review the inferred skeleton inventory (which depends on prior-season state, often surprising — e.g. IMEW vs DMEW year). The preview step is cheap (read-only `fn_preview_init_season` call) and high-value as a sanity check before commit.
4. **Pre-populate skeletons on `tbl_season` INSERT trigger.** Reject — couples season identity with skeleton initialization too tightly. Admin should be able to create a season "loose" (e.g. for archival import) without skeletons. The wizard is opt-in; the legacy 3-arg `fn_create_season` still exists for that case.

## Consequences

**Positive:**
- Admin no longer needs `psql` for the routine carry-over flow — runbook §3, §4, §5, §6, §9 are all replaced by point-and-click.
- Atomic transaction = no half-shipped seasons. Cancel at any wizard step leaves zero residue.
- Skeleton-with-FK-linkage is now the default flow, which is the precondition for the FK engine to work correctly. Combined with ADR-045's default flip, greenfield seasons get correct rolling scores out of the box.
- "↶ Cofnij całość" gives a one-click panic button while the season is still pristine — useful when admin realises they entered the wrong dates.

**Negative / accepted costs:**
- `fn_create_season_with_skeletons` is a fat RPC (8 params). Mitigated by always calling via the wizard, which assembles the payload from typed UI state.
- The atomic transaction holds locks on `tbl_season`, `tbl_scoring_config`, `tbl_event`, `tbl_tournament` for the duration of skeleton init. With 17 events × 6 children = 102 inserts, this is ~50ms locally; not a concurrency concern at SPWS scale (single admin session at a time).
- `fn_init_season`'s skeleton count depends on prior-season inventory, which can surprise admin (e.g. SPWS-2025-2026 has only 9 PEWs because three more arrived as slugs and the regex excludes them). Mitigated by Step 3's explicit preview.
- Cascade rename writes the rebuilt code unconditionally; a child whose code was hand-edited to deviate from the convention would lose that hand-edit. Acceptable since the convention is enforced by `_fn_create_skeleton_children` and bulk imports; outlier children would be a bug today.

## Migration & test references

- Migrations: [`20260428000003_fn_init_season.sql`](../../supabase/migrations/20260428000003_fn_init_season.sql), [`20260428000004_fn_create_season_with_skeletons.sql`](../../supabase/migrations/20260428000004_fn_create_season_with_skeletons.sql), [`20260428000005_fn_revert_season_init.sql`](../../supabase/migrations/20260428000005_fn_revert_season_init.sql), [`20260428000006_fn_copy_prior_scoring_config.sql`](../../supabase/migrations/20260428000006_fn_copy_prior_scoring_config.sql), [`20260428000002_fn_update_event_v2.sql`](../../supabase/migrations/20260428000002_fn_update_event_v2.sql)
- Tests: [`supabase/tests/19_phase3_wizard.sql`](../../supabase/tests/19_phase3_wizard.sql) — ph3.1 – ph3.21 + ph3.22a/b/c (25 assertions)
- Plan: `~/.claude/plans/eager-knitting-fog.md`
- Mocks: [`doc/mockups/m13_event_manager_phase3.html`](../mockups/m13_event_manager_phase3.html), [`doc/mockups/m13_season_manager_phase3.html`](../mockups/m13_season_manager_phase3.html)

## Future work

- **Phase 3b**: SeasonManager 3-step wizard component + skeleton inventory rendering (calendar-style purple boxes per locked mock). 22 vitest assertions ph3.23–ph3.37g.
- **Phase 3c**: EventManager season selector at top, `txt_code` editable with cascade, `id_prior_event` picker, Skeletons collapsible panel. ~12 vitest assertions extending `EventManager.test.ts`. App.svelte rewires `fn_update_event` callsites to the v2 21-arg signature.
- **Once Phase 3c lands**, mark `project_carryover_admin_runbook.md` §3, §4, §5, §6, §9 as superseded.
