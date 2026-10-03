# ADR-042: Per-season carry-over engine selection via dispatcher pattern

**Status:** Accepted — Phase 1A + 1B implemented; amended 2026-08-07 to preserve FK carry-over independently of chronological numbering; amended 2026-10-02 so a result whose next edition has no row yet still carries; amended 2026-10-03 (ADR-108) so a carry stops on results, per weapon and gender.
**Date:** 2026-04-25 (created), 2026-04-26 (Phase 3 amendment)
**Relates to:** ADR-018 (Rolling Score for Active Season), ADR-021 (IMEW biennial carry-over), ADR-044 (Phase 3 wizard), ADR-045 (engine selector + default flip)

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

- **Phase 1B**: implement `fn_*_event_fk_matching` engines using `tbl_event.id_prior_event` and `vw_eligible_event`; add `fn_compare_carryover_engines` for A/B verification; flip SPWS-2025-2026 to `EVENT_FK_MATCHING` after slug-event manual cleanup. *(SHIPPED 2026-04-26 in commit 997ff30.)*
- **Phase 3 amendment (SHIPPED 2026-04-26 in commit 4da1659):** column DEFAULT flipped to `EVENT_FK_MATCHING` (greenfield seasons only); engine selection moved into the ScoringConfigEditor as a dropdown (Section 4b). Pre-Phase-3 seasons are untouched — admin opts each one in. The legacy CODE branch in the dispatcher remains for compatibility. See ADR-045 for the rationale and ADR-044 for the wizard that exercises the new default.
- **Eventual cleanup**: when no live season uses `EVENT_CODE_MATCHING`, drop the legacy engine functions and remove the `WHEN 'EVENT_CODE_MATCHING'` branch from dispatchers.
- **ADR-021** amendment pending Phase 1B (rule unchanged; expression mechanism updated to FK-based).

## Amendment (2026-08-07) — number and rolling identity are independent

Returning PPW/MPW/PEW events continue to use `id_prior_event` for rolling
replacement. For EVF calendar rows, the current-season number is strictly the entry's
chronological position under ADR-043 and never reuses or prefers the predecessor's
number. A numbering repair therefore cannot break rolling-score behavior.

Geographic continuity may cross city labels when the organizer confirms it is the
same recurring event. The approved current-season mapping links Athens directly to
the prior Chania event while Athens independently receives `PEW14es` from the
filtered current calendar position and weapon set. The FK is authoritative; country,
city and code digits are matching evidence only.

The trigger in
[`20260807000001_evf_calendar_identity_bound.sql`](../../supabase/migrations/20260807000001_evf_calendar_identity_bound.sql)
also carries reusable public-calendar identity into a new season skeleton. The
occurrence-specific EVF results id is deliberately not inherited.

## Amendment (2026-10-02) — a result whose next edition has no row yet still carries

**Decision S B** in `doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html`, signed off 2026-10-02.

**Context.** `vw_eligible_event` carried a previous-season event only through the next season's row linked to it (`id_prior_event`), until that row reached SCORED or COMPLETED. A cancelled or not yet held edition kept carrying, for the season's `int_carryover_days` after the event's end. An event whose next edition had no row at all dropped out at once. The Criterium Mondial Vétérans 2026 (EVF, Paris, July 2026) fell in that gap: EVF publishes the next edition late in the season, so Zabłocki's win (111.69) was missing from the 2026/27 EVF+ rolling score. A hand-made placeholder row would fill the gap, but [ADR-091](091-no-season-skeletons-for-scraped-events.md) forbids undated EVF placeholders (pgTAP 74.9): the calendar sync cannot match one, and a misnumbered one stops the sync at the unique index on (season, prior event).

**Decision.** A third branch of `vw_eligible_event` carries a held event of the season right before into the current season while the current season has no row linked to it, for the same window: its end date plus the current season's `int_carryover_days`. When the next edition's row appears, the linked branch takes over and the new branch stops, so an event is carried once; when that edition is held, the carry stops as before. Migration `20261002000007_carryover_without_successor.sql`; columns and grants are unchanged.

**Consequences.**
- The four `EVENT_FK_MATCHING` functions read the view, so the drilldown and every ranking (full, kadra, PPW) move together.
- On PROD on 2 October 2026 every 2025/26 event with results had a 2026/27 row, so the change adds only the Criterium 2026 once it is ingested. On CERT it also carries Stockholm and Jabłonna 2026, which are unlinked there only because CERT's 2026/27 calendar has drifted from PROD's.
- Tests: pgTAP `supabase/tests/94_carryover_without_successor.sql`, CARRY.NS.01–07 (carried once with no next row or with a linked one; not carried when not held, two seasons back or past the window; the drilldown lists it; the carry stops once the next edition is held).
- `EVENT_CODE_MATCHING` seasons are unchanged.

## Amendment (2026-10-03) — a carry stops on results, per weapon and gender

**Decision P6 A** in `doc/plans/promote-verified-replay-2026-10-03.html`, recorded in [ADR-108](108-promote-replays-verified-cert-ingestion.md) §8.

**Context.** The linked branch of `vw_eligible_event` carries the previous edition until the current edition reaches SCORED or COMPLETED, while the first branch counts the current edition from IN_PROGRESS on. While an event is IN_PROGRESS, a fencer who fenced both editions therefore has both results counted. Today's promote jumps straight to COMPLETED, which hid this on PROD. ADR-108 §7 keeps an event IN_PROGRESS until its end date has passed, which makes the overlap the normal case.

**Decision.** In the four `EVENT_FK_MATCHING` functions, the previous edition stops carrying for a weapon and gender as soon as the linked current edition has a scored result for that weapon and gender. A SCORED or COMPLETED current edition still stops every carry from its previous edition. The view alone cannot see weapons, so the stop lives in the functions, which read the view together. The third branch (2026-10-02) is unchanged.

**Consequences.** There is no double count while an event is IN_PROGRESS, and no empty slot for a weapon fenced on a later day. The engines now share ADR-018's rule. The pgTAP test for the change is written RED first, reproducing the double count, and `94_carryover_without_successor.sql` (CARRY.NS.01–07) stays green.
