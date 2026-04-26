# ADR-042: Per-season carry-over engine selection via dispatcher pattern

**Status:** Accepted (Phase 1A); Phase 1B will populate the EVENT_FK_MATCHING engine
**Date:** 2026-04-25
**Relates to:** ADR-018 (Rolling Score for Active Season), ADR-021 (IMEW biennial carry-over)

## Context

Rolling-score carry-over currently identifies a "position" by parsing the prefix of `tbl_event.txt_code` via `fn_event_position(p_code) = split_part(p_code, '-', 1)`. The carry-over rule then says: a prior-season event carries into the current-season pool unless an event with the same prefix has been COMPLETED in the current season.

This breaks for EVF-scraped events whose codes are venue slugs (`PEW-SALLEJEANZ-2025-2026`, `PEW-SPORTHALLE-2025-2026`). Their `fn_event_position` returns just `PEW`, colliding all such events into a single position and silently corrupting the rolling pool.

The intended fix is FK-based linkage: a new `tbl_event.id_prior_event` column making the cross-year relationship explicit, plus a `vw_eligible_event` view that becomes the single source of truth for what contributes to a season's rolling pool. But replacing the carry-over engine in one shot is risky:

- Three rolling-score functions, each 200–300 lines of intricate CTE logic
- Existing 21 pgTAP assertions hardcode expected scores from real seed data
- Production seasons must not silently drift after deploy
- Future engines may emerge (city-matching, organizer-matching, ranking-rule-specific) — we want a structure that admits new engines without rewriting existing ones

## Decision

Introduce a per-season carry-over engine flag and a dispatcher pattern. Each rolling-score function (`fn_ranking_ppw`, `fn_ranking_kadra`, `fn_fencer_scores_rolling`) becomes a thin dispatcher that reads the season's flag and routes to a named engine implementation. Engine implementations carry verbose suffixes (`_event_code_matching`, `_event_fk_matching`, ...) that explicitly name what they match on.

### Schema additions

```sql
CREATE TYPE enum_event_carryover_engine AS ENUM (
  'EVENT_CODE_MATCHING',  -- existing prefix-string logic
  'EVENT_FK_MATCHING'     -- Phase 1B: FK-based via id_prior_event
);

ALTER TABLE tbl_season
  ADD COLUMN enum_carryover_engine enum_event_carryover_engine
    NOT NULL DEFAULT 'EVENT_CODE_MATCHING';
```

### Dispatcher pattern

The current function bodies are renamed in-place by appending `_event_code_matching` (preserving OID and behavior). New functions with the original public names are created as dispatchers:

```sql
CREATE FUNCTION fn_ranking_ppw(...) RETURNS TABLE (...) ... AS $$
DECLARE v_engine enum_event_carryover_engine; v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(p_season, (SELECT id_season FROM tbl_season WHERE bool_active LIMIT 1));
  SELECT enum_carryover_engine INTO v_engine FROM tbl_season WHERE id_season = v_resolved_season;
  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_ranking_ppw_event_code_matching(p_weapon, p_gender, p_category, p_season, p_rolling);
    WHEN 'EVENT_FK_MATCHING' THEN
      RAISE EXCEPTION 'Carryover engine EVENT_FK_MATCHING is not yet implemented for season %', v_resolved_season;
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END $$;
```

The dispatcher's signature is byte-identical to the renamed engine. PostgREST clients (the frontend) see no change.

### Naming convention

- Enum values: SCREAMING_SNAKE matching the existing `enum_event_status` style (`PLANNED`, `IN_PROGRESS`, etc.)
- Engine functions: `<base>_<engine_name>` — `fn_ranking_ppw_event_code_matching`. Verbose by design so the engine type is unambiguous when reading code or grep results.
- Dispatcher functions: keep the original public name (e.g. `fn_ranking_ppw`).

## Alternatives considered

1. **Direct rewrite (no dispatcher).** Replace the existing function bodies with FK-based logic in one migration. Rejected: high risk, no rollback path beyond writing reverse migrations, can't A/B compare engines, can't ship in stages.

2. **Single function with branched body** (`IF engine = 'FK' THEN ... ELSE ...` inside one large function). Rejected: function bodies grow to 400+ lines mixing two engines; harder to delete legacy branch later; harder to add a third engine.

3. **Global feature flag** (one flag for all seasons). Rejected: blunt rollout. Per-season opt-in lets us migrate one season at a time, leaving finalized history untouched, and instantly revert via `UPDATE tbl_season ... WHERE id_season = X`.

4. **String-prefix fallback when FK is NULL.** Rejected: doubles the carry-over surface forever; the prefix mechanism is exactly the bug we're fixing. Fail-closed (NULL FK ⇒ no carry) forces explicit data hygiene.

## Consequences

**Positive:**
- Per-season rollout — opt seasons in to new engines independently; finalized seasons stay frozen
- Instant rollback — flip the flag via a single UPDATE; no migration needed
- Future engines slot in cheaply: ADD VALUE to the enum, CREATE FUNCTION the engine, append a `WHEN` branch to dispatchers
- Phase 1A landed with zero behavior change (default `EVENT_CODE_MATCHING` preserves existing logic)
- A/B comparison enabled — Phase 1B will add `fn_compare_carryover_engines(p_id_season)` to quantify per-fencer drift before flipping a season

**Negative / accepted costs:**
- Two function lookups per rolling-score call (dispatcher + engine). Negligible overhead.
- Dispatcher must duplicate engine signatures verbatim; signature drift would silently break PostgREST clients. Mitigated by pgTAP signature-existence tests (D.3-D.5) and dispatcher-vs-direct routing test (D.6).
- The `RAISE EXCEPTION` placeholder in the EVENT_FK_MATCHING branch leaks an admin-only error message if a season is set to that value before Phase 1B ships. Default keeps everyone on EVENT_CODE_MATCHING; admin won't manually flip until Phase 1B is ready.
- Code lives in two places (engine + dispatcher) until we eventually drop legacy engines.

## Migration & test references

- Migrations: [`20260425000003_carryover_engine_enum.sql`](../../supabase/migrations/20260425000003_carryover_engine_enum.sql), [`20260425000004_rolling_function_dispatcher.sql`](../../supabase/migrations/20260425000004_rolling_function_dispatcher.sql)
- Tests: [`supabase/tests/16_dispatcher.sql`](../../supabase/tests/16_dispatcher.sql) — D.1–D.8
- Regression gate: existing R.1–R.21 in [`supabase/tests/09_rolling_score.sql`](../../supabase/tests/09_rolling_score.sql) continue to pass (they call public dispatcher names; default engine routes to legacy logic)
- Plan: `~/.claude/plans/sequential-snacking-castle.md` (Phase 1A)

## Future work

- **Phase 1B**: implement `fn_*_event_fk_matching` engines using `tbl_event.id_prior_event` and `vw_eligible_event`; add `fn_compare_carryover_engines` for A/B verification; flip SPWS-2025-2026 to `EVENT_FK_MATCHING` after slug-event manual cleanup.
- **Eventual cleanup**: when no live season uses `EVENT_CODE_MATCHING`, drop the legacy engine functions and remove the `WHEN 'EVENT_CODE_MATCHING'` branch from dispatchers.
- **ADR-021** amendment pending Phase 1B (rule unchanged; expression mechanism updated to FK-based).
