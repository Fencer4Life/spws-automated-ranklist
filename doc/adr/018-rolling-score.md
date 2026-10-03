# ADR-018: Rolling Score for the Active Season

**Status:** Accepted (2026-03-29); rewritten 2026-10-03 as the single current record of the rolling score. The FK engine's results-based stop for every linked event (ADR-108 §8, decision P6 A; scope decided 3 October 2026) is implemented and not yet released.
**Date:** 2026-03-29 (M10); rewritten 2026-10-03
**Tag:** ROLLING SCORING — rolling score, carry-over, ranking kroczący, przenoszenie wyników
**Amends:** nothing. It restates its own amendments of 2026-06-26, 2026-08-09 and 2026-10-03 in one text.
**Relates to:** [ADR-010](010-age-category-by-birth-year.md) (category by birth year), [ADR-021](021-imew-biennial-carry-over.md) (types from the season's rules), [ADR-031](031-auto-active-season.md) (active season by date), [ADR-034](034-cross-gender-tournament-scoring.md) (effective gender), [ADR-037](037-derived-display-status-awaiting-results.md) (a new event replaces a carry only once it has results), [ADR-042](042-carryover-engine-dispatcher.md) (engine per season, `vw_eligible_event`), [ADR-044](044-phase3-wizard.md) (window default, prior-event picker), [ADR-045](045-engine-selector-default-flip.md) (FK engine by default), [ADR-077](077-event-lifecycle-season-skeletons.md) §3 (skeletons linked to their predecessors), [ADR-084](084-calendar-quarter-barrel-event-card.md) (calendar strip withdrawn), [ADR-098](098-ranking-schema-v2-and-generalized-ranking-rpc.md) (PPS/MPS not carried), [ADR-103](103-spws-place-medal-engine-per-type.md) §6 (ranking entry), [ADR-108](108-promote-replays-verified-cert-ingestion.md) §7–§8 (promote lifecycle, results-based stop)
**Source:** `supabase/migrations/20261002000007_carryover_without_successor.sql`, `supabase/migrations/20260425000008_fn_event_fk_matching_engines.sql`, `supabase/migrations/20260928000001_spws_place_medal_engine.sql`, `supabase/migrations/20260930000001_remove_place_medal_engine.sql`, `supabase/migrations/20260930000003_spws_evf_joined_engine.sql`, `supabase/migrations/20260906000001_no_evf_season_skeletons.sql`, `python/pipeline/promote.py`, `frontend/src/lib/rolling.ts`; analysis `doc/plans/carry-over-logic-as-built-2026-10-03.html` (ROLLING SCORING)

## Context

At the start of a season nobody has a result yet. The ranking stays continuous by counting the previous season's results until this season's results replace them. By the end of the season every result is current and the rolling score has no effect.

The rule grew in eight steps across this ADR's amendments and seven other ADRs (see History). By October 2026 nobody could state it from the documents: the 2026-10-03 amendment described code that is not released as current, and the event-status page credited SCORED to a pipeline that never sets it. This rewrite states the rule once, as it runs on 3 October 2026, with source references, and keeps the decided change that is not yet released apart (§7).

Each season names its carry-over engine (`tbl_season.enum_carryover_engine`, ADR-042):

| Season | Engine | Window (`int_carryover_days`) | Rolling on screen |
|---|---|---|---|
| 2023/24, 2024/25, 2025/26 | `EVENT_CODE_MATCHING` | 366, not read by this engine | no, closed |
| 2026/27 | `EVENT_FK_MATCHING` | 366 | yes, active |

## Decision

### 1 · When a ranking rolls

The UI asks for a rolling ranking (`p_rolling = TRUE`) for the active season, or for a season whose end date is today or later (`frontend/src/lib/rolling.ts:16-24`, used at `App.svelte:538`). A closed season's ranking shows only its own results. Every ranking function keeps `p_rolling BOOLEAN DEFAULT FALSE`, so a caller that does not ask gets the season alone.

### 2 · What can carry

- **Only the season right before.** Two seasons back never carries.
- **Only an event that was held:** its status is not CREATED, PLANNED, SCHEDULED, CHANGED or CANCELLED.
- **Only a result with a score** (`num_final_score IS NOT NULL`).
- **Only a type in the season's ranking rules** (ADR-021): the domestic rules for the PPW ranking, the international rules for the kadra ranking, both for the drilldown.
- **PPS and MPS never carry in Ranking mode** (`fn_ranking_full`, ADR-098, SS26.RANK.12). The drilldown still lists them as carried.

### 3 · The link to the next edition

`tbl_event.id_prior_event` names the previous season's event that a current event follows. It means **"this event replaces that one"**.

- **Who sets it.** The season wizard's `fn_init_season` creates every PPWn, MPW and MSW skeleton linked to the previous season's event of the same name, in the same INSERT (`20260906000001_no_evf_season_skeletons.sql:114-125, 136-146, 152-162`; ADR-077 §3, ADR-045). The EVF calendar sync links an EVF event by the previous season's city (ADR-043, ADR-028 rev 6). An admin sets or clears it in the event form, „Poprzednik (carry-over)” (`EventManager.svelte:177-193`; `-1` clears it, ADR-044 amendment 2026-06-27). That list offers only events of the season right before.
- **One claimant per season.** `idx_event_prior_unique` allows one event per season to name a given predecessor (`20260425000005_fk_carryover_schema.sql:26`).
- **Carried to PROD** by the CERT→PROD event mirror, matched by event code (ADR-081 amendment 2026-08-29). Promote's input check includes the predecessor's code (`20261003000014_ingest_run.sql:143`).
- **Not read** by the older engine, and shown on no public page.

### 4 · When a carried result stops counting (FK engine, as released)

`vw_eligible_event` (`20261002000007_carryover_without_successor.sql:26-69`) is the only source of carried events for the four `EVENT_FK_MATCHING` functions. It works on events, so it does not distinguish types.

| | Linked (branch 2, L36-48) | Not linked (branch 3, L50-69, since 2026-10-02) |
|---|---|---|
| The next edition is SCORED or COMPLETED | stops, for every weapon and gender at once | does not apply |
| End date + `int_carryover_days` has passed | stops | stops |
| The next edition is CANCELLED | carries until the window ends | does not apply |
| The next edition has results but is IN_PROGRESS | **both count** | both count |

The window is inclusive: the result still counts on its end date plus 366 days. The current event counts from IN_PROGRESS on (branch 1, L27-34), and `fn_ingest_tournament_results` sets IN_PROGRESS when the first result arrives.

**On PROD a linked result is replaced as soon as the new edition's results arrive.** The current promote writes the results and sets COMPLETED in the same run (`python/pipeline/promote.py:290-298`), so no IN_PROGRESS interval exists on PROD. This is the intended behaviour: ADR-037 records that a new event replaces the carry only once it has results. On CERT and LOCAL an ingestion leaves the event IN_PROGRESS, so both editions count there until the event is completed.

**Without a link, a result is time-bound only.** It counts for the window whether or not its next edition was held. A result whose next edition has no row yet (the Criterium 2026, published late by EVF) is carried this way (ADR-042 amendment 2026-10-02).

**The window also ends a linked result** whose next edition has no results on PROD yet. On 3 October 2026 this is the case for PPW1: PPW1-2025-2026 (ended 28 Sep 2025) counted through 29 Sep 2026, and PPW1-2026-2027 (fenced 26–27 Sep 2026) is not yet promoted (open item 1).

### 5 · How carried results count

- **One pool.** Carried and current results go into the same pool; the season's buckets pick from it (2026/27: PPW best 2 and MPW always for SPWS; best 5 of PEW, MEW, MSW, PSW, PPS, MPS for EVF+).
- **Stored points.** A carried result keeps the `num_final_score` it was given under its own season's rules. Nothing is re-scored.
- **Category from the current season.** A carried result goes into the category given by the birth year against the current season's later calendar year (`fn_age_category(birth_year, v_season_end_yr)`, `20260930000001_remove_place_medal_engine.sql:571, 609`; ADR-010). Someone born in 1977 is V1 in 2025/26 and V2 in 2026/27, and their 2025/26 results count in V2.
- **Effective gender** as for every ranking (ADR-034).
- **Ranking entry.** In Ranking mode a fencer appears only with a PPW or MPW result in the ranked season or, when rolling, anywhere in the previous season, in any weapon (`20260928000001_spws_place_medal_engine.sql:1312-1324`, ADR-103 §6). This check reads the whole previous season, not the window.

| Function | UI | Carried rows count when |
|---|---|---|
| `fn_ranking_full_event_fk_matching` | Ranking mode (`App.svelte:763`) | `p_rolling`; type in a bucket; not PPS or MPS (`20260928000001…:1290, 1296, 1306`) |
| `fn_ranking_ppw_event_fk_matching` | PPW mode (`App.svelte:746`) | `p_rolling`; type in the domestic rules (`20260425000008…:160, 166`) |
| `fn_fencer_scores_rolling_event_fk_matching` | drilldown (`App.svelte:818`) | always listed, marked carried; type in either rules section (`20260930000001…:599-611`) |
| `fn_ranking_kadra_event_fk_matching` | not called by the UI (pgTAP parity oracle for `fn_ranking_full`) | `p_rolling`; type in the international rules (`20260425000008…:362, 368`) |

### 6 · The older engine, `EVENT_CODE_MATCHING`

A previous-season result carries while the current season has no scored result at the same **position**, in the same weapon and gender. The position is the event code's prefix (`fn_event_position`: `PPW1`, `MPW`, `PEW3`). There is no window and no status test (`20260930000003_spws_evf_joined_engine.sql:938-942, 954-963, 1012-1024`). Positions taken from EVF venue slugs collide, which is why ADR-042 introduced the FK engine. All three seasons on this engine are closed and shown without rolling, so it affects no ranking on screen today.

### 7 · The results-based stop for the FK engine (decided, implemented, not yet released)

ADR-108 §7 keeps an event IN_PROGRESS until its end date has passed, and sets COMPLETED afterwards. Under §4 both editions of a linked event would then count for that whole time, and the immediate replacement PROD has today would be lost. Decision P6 A (3 October 2026, `doc/plans/promote-verified-replay-2026-10-03.html`) keeps it: a linked carry stops for a weapon and gender as soon as the linked current edition counts (branch 1 statuses) and has a scored result in that weapon and gender. **It applies to every linked event, whatever its type** (decision A, 3 October 2026): the link, not the type, decides that the new edition replaces the old one. A SCORED or COMPLETED edition still stops every carry, and the window still applies. It is the rule §6 already applies to the older engine.

- **Implementation.** `supabase/migrations/20261003000018_carry_stop_results.sql` adds `fn_carry_stopped_by_results` and one filter line after each FK function's carry filter. The view cannot see weapons, so the stop lives in the functions. Tests: `supabase/tests/104_carry_stop_results.sql`, CARRY.RS.01–11.
- **Scope history.** For a few hours on 3 October a version narrowed to PPW and MPW (a fifth parameter, `p_type`) stood on LOCAL without sign-off. It was removed the same day under decision A; RS.03 and RS.05 failed against it and pass against the version for every linked event. The full pgTAP suite passes on LOCAL (1,385 assertions).

### 8 · API and display

- **Option C, a parameter** (the original decision): `p_rolling BOOLEAN DEFAULT FALSE` on each ranking function. Totals include carried results because the database computes them, and existing callers are unchanged.
- **Drilldown.** `fn_fencer_scores_rolling(p_fencer, p_weapon, p_gender, p_category, p_season)` returns the score rows plus `bool_carried_over` and `txt_source_season_code`. Ranking rows carry `bool_has_carryover`. All three are dispatchers on the season's engine (ADR-042).
- **Display.** A carried result keeps grey text and a striped bar, and is marked „↩ Wynik z poprzedniego sezonu” with its source season. It carries ★ when the ranking counts it, like any other result. The amber banner was removed on 2026-10-01 (`doc/plans/drilldown-points-order-and-uncounted-2026-10-01.html`). The calendar progress strip was withdrawn by ADR-084: carry-over is a ranking concept, not a calendar one.

## Alternatives considered

1. **Rolling always on, no parameter.** Rejected in March 2026: it changes every caller's results implicitly and cannot be regression-tested.
2. **Separate `*_rolling` functions.** Rejected: they duplicate bucket selection and drift.
3. **Merging in the frontend.** Rejected: ranking totals would differ from the drilldown, Best-K and the category crossing would be re-implemented in JavaScript.
4. **Status-based stop for the older engine.** Rejected on 2026-06-26: an ingested event left at SCHEDULED showed both seasons. A current scored result is the trigger instead.
5. **A placeholder row for an event whose next edition is not published yet.** Rejected on 2026-10-02: ADR-091 forbids undated EVF placeholders. Branch 3 carries such an event directly.
6. **A rule per type** (PPW and MPW roll without a window, other types time-bound only, links ignored). Rejected on 2026-10-03 (decision A): it departs from the link meaning "replaces" for EVF events and changes the view as well as the functions.
7. **The results-based stop for PPW and MPW only.** Rejected on 2026-10-03 (decision A): once promote leaves events IN_PROGRESS (ADR-108 §7), a linked EVF result would count twice for that time.

## Consequences

- The rolling score has one current description, this ADR. ADR-021, ADR-037, ADR-042 and ADR-108 keep their own decisions and point here for the combined rule.
- The ranking rule book describes §1–§5 as today's behaviour.
- Corrected with this rewrite: the handbook page `doc/handbook/reference/event-status-lifecycle.html` credited SCORED to the scoring pipeline; no code sets an event to SCORED (only `tbl_tournament.enum_import_status` becomes SCORED). ADR-108 §8 said the stop holds "whatever the current edition's status is"; the current edition must itself count (CARRY.RS.11).

## Tests

| Suite | IDs | What they pin |
|---|---|---|
| `supabase/tests/09_rolling_score.sql` | R.1–R.24 | older engine: position helper, rolling on/off, merged Best-K, category crossing, results-based stop per weapon and gender, biennial IMEW, never both |
| `supabase/tests/17_fk_carryover.sql` | F.1–F.26 | FK schema, wizard links, `vw_eligible_event` (SCORED/COMPLETED stop, window cap), FK functions and dispatcher, day-1 parity |
| `supabase/tests/94_carryover_without_successor.sql` | CARRY.NS.01–07 | branch 3: carried once with or without a next row, not when not held or two seasons back, past the window, stop once held |
| `supabase/tests/104_carry_stop_results.sql` | CARRY.RS.01–11 | §7: results stop per weapon and gender for every linked event (RS.03: a PEW one), no empty slot, current edition must count, COMPLETED still stops all |
| `supabase/tests/80_season_scoring_contract.sql` | SS26.RANK.12 | PPS and MPS not carried in Ranking mode |
| `frontend/tests/DrilldownModal.test.ts` | R.19, R.20, R.22 | carried row class, ↩ marker, current rows unchanged |

Retired: R.21 (vitest, the banner, 2026-10-01); R.23–R.25 (vitest, the calendar strip, ADR-084).

## Open items

1. **Should the window end a linked PPW or MPW result before its next edition's results are on PROD?** Today it does (PPW1 from 30 Sep 2026; PPW2 if its 2026/27 results arrive after 27 Oct 2026). **Recommendation:** a linked PPW or MPW result counts until its next edition's results replace it; the one-season bound still ends it. The window stays for unlinked results.

## History

| Date | Change | Where |
|---|---|---|
| 2026-03-29 | Rolling score with `p_rolling`; position-matched carry; a declared counterpart required; stop when the counterpart is COMPLETED | this ADR |
| 2026-04-04 | Carry by type in the season's rules instead of a declared counterpart (biennial IMEW) | ADR-021 |
| 2026-04-06 | Stop when the counterpart is IN_PROGRESS as well | migration `20260406000006` |
| 2026-04-25/26 | Engine per season; `id_prior_event`; `vw_eligible_event`; window `int_carryover_days`, default 366 | ADR-042, ADR-044 |
| 2026-04-26 | FK engine is the default for new seasons; the wizard links skeletons | ADR-045 |
| 2026-06-26 | Older engine: stop on a current scored result per position, weapon and gender | migration `20260626120000` |
| 2026-06-28 | Rolling tests made fixture-self-contained | `09_rolling_score.sql` |
| 2026-08-09 | Calendar progress strip withdrawn | ADR-084 |
| 2026-09-19 | `fn_ranking_full`; PPS and MPS never carried | ADR-098 |
| 2026-10-02 | Branch 3: an event whose next edition has no row carries for the window | ADR-042 |
| 2026-10-03 | Results-based stop for the FK engine decided (P6 A), for every linked event (decision A); this ADR rewritten | ADR-108 §8 |

The text before this rewrite is in git at commit `8271dd65`.
