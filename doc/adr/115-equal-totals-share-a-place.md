# ADR-115: Equal Totals Share a Place; the Next Place Skips

**Status:** Accepted (the rule decided by the user in chat on 2026-10-18; the plan `doc/plans/equal-totals-shared-place-2026-10-18.html` signed off the same day with Q1–Q4 A and S1 A, and the seed files set to follow the ranking's row order). Implemented test-first on LOCAL (RANK.TIE.01–08, each seen failing first except the TypeScript seed guard, which was already right); before/after sheet `doc/plans/equal-totals-before-after-2026-10-18.html` approved (A1); released to CERT and PROD on 2026-10-18 (main `180be9af`; the first push, `ed2c91f5`, stopped at CI on an unrelated nondeterministic check, test 03 5.1b, fixed in `5d8a368e`) and checked on CERT and PROD, SELECT only, as the site reads the lists: 142 lists, 1,135 rows, every rank one more than the number of higher totals, the 19 ties each sharing one place in alphabetical order (before: 20 ranks off, 13 ties out of alphabetical order); PROD's ranklist page shows sabre men V3, Ranking 2026/27 as 8, 8 and the rules modal states the rule first.
**Date:** 2026-10-18
**Amends:** [ADR-098](098-ranking-schema-v2-and-generalized-ranking-rpc.md) (the rank its functions return: a shared place instead of a row count), [ADR-114](114-ranklist-whole-points-close-call-decimals.md) (open item 1 is resolved here), [ADR-080](080-clean-roster-ftl-seeding.md) (fencers sharing a seed tier follow the ranking's row order, in both generators)
**Relates to:** [ADR-101](101-ranking-ppw-public-ui-and-publication-boundary.md) (`fn_ranking_kadra` stays the parity oracle and changes with the others), [ADR-083](083-server-enforced-authorization.md) (the re-created functions keep their grants), [ADR-018](018-rolling-score.md) (totals and the carry-over are untouched)
**Source:** `supabase/migrations/20261018000001_equal_totals_share_place.sql`, `python/pipeline/ftl_seed_export.py`, `python/pipeline/ftl_seed_export_db.py`, `frontend/src/components/SeasonRulesModal.svelte`, `doc/plans/equal-totals-shared-place-2026-10-18.html`

## Context

Every ranking function numbered its rows with `ROW_NUMBER() OVER (ORDER BY total DESC)` and no second key: ten rank lines across the six variants `fn_ranking_{full,ppw,kadra}_event_{fk,code}_matching` (for the event-FK variants, `supabase/migrations/20261003000018_carry_stop_results.sql:222, :324, :408, :508, :584`). Exactly equal totals therefore took consecutive places in an order nothing fixed. The dispatchers `fn_ranking_full`, `fn_ranking_ppw` and `fn_ranking_kadra` return those rows unchanged, so every surface printed that arbitrary order: the main list, the drilldown, the ODS download and the FTL seed files.

Measured on PROD on 18 October 2026, SELECT only, every season the site shows and read as the site reads it (the running season with the rolling carry-over, past seasons without): 19 ties, 11 of them in past seasons and 8 in 2026/27. Twenty fencers stood one or two places below a fencer with exactly their total. ADR-114 had found the gap and kept those rows whole, and left the rule open (its open item 1).

No rule in the regulations, an ADR or the handbook fixed the order of equal season totals. The 2026/27 rules draft shares ex aequo places inside a bracket in the same way the user chose here: n, n, then n + 2.

The seed export was written for shared ranks before they existed. `interleave_mixall` (`python/pipeline/ftl_seed_export.py:202`) and its twin (`frontend/src/lib/ftlSeedExport.ts:263`) both say *"fn_ranking_ppw gives two fencers on the same score the same rank"*, and the organiser download's tier is that rank (`fn_ftl_export_entries`, `rk.position`). The building of this change found two places where the generators had drifted apart for a tied pair:

- The organiser download put fencers of one rank in registration order. The Python generator put them in the ranking's row order.
- The Python generator took the tier from the fencer's position in the ranking list (`index + 1`) and not from the rank. Under `ROW_NUMBER` the two are the same. Under a shared place, 16 and 16 become 16 and 17, so the two generators would have seeded a tie differently. The plan had said the Python generator needed no change. That was wrong. No organiser received such a file: the Python path feeds only the e-mail delivery, which has never run (ADR-080, 2026-09-25), and the organiser downloads the TypeScript generator's files.

## Decision

### 1 · A shared place

A fencer's place is one more than the number of fencers with a higher total: `RANK() OVER (ORDER BY total DESC)`. Fencers with exactly the same total share the place. The next place is further down by the number sharing it: two fencers on 16th leave no 17th, and the next fencer is 18th. Nobody moves down. Every place after a tie keeps its number, and only the second (and third) tied fencer moves up.

### 2 · Everywhere the rank comes from

The decision covers all six ranking variants, in both branches where a function has two: full, PPW and Kadra, event-FK and event-code. One migration re-creates them from their live definitions. It changes only the rank line and the final row order. `CREATE OR REPLACE` keeps every signature, so the grants stay as they are. Everything that prints or uses the rank follows without a code change: the main list, the drilldown headline, the ODS download, the organiser download and the national-team positions tool.

### 3 · Alphabetical inside a shared place

Fencers sharing a place are listed by the name the ranking shows, in Polish alphabetical order (`COLLATE "pl-x-icu"`, present on LOCAL, CERT and PROD). A list therefore never reshuffles between two loads, and the order inside a place carries no claim of merit.

### 4 · Every season, and said in the rules modal

The rule applies to every season, past seasons included. A past season's list keeps every total and every place after a tie. The season rules modal says it in one sentence, first among its facts, directly under the pools that sum to the ranking's total. **Polish:** „**Ta sama suma punktów** daje to samo miejsce; kolejne miejsce przesuwa się o liczbę zawodników na tym miejscu (np. 16, 16, 18).” **English:** “**The same total** shares a place; the next place moves down by the number sharing it (e.g. 16, 16, 18).”

### 5 · Seed files follow the ranking

In the FTL seed files, fencers who share a place share a seed tier and keep the ranking's own row order (§3), in both generators. Registration time orders only the unranked tail.

- `fn_ftl_export_entries` takes `fn_ranking_ppw` `WITH ORDINALITY` and orders a rank by that ordinality before registration time.
- The Python generator carries `fn_ranking_ppw`'s rank next to the order and the points: `fetch_weapon_rankings` returns it as a third map, and `assemble_mixall_subrankings` takes it as `ranks`. It no longer counts positions.
- The TypeScript generator already read the rank and the order from `fn_ftl_export_entries`, and is unchanged.

## Alternatives considered

1. **Keep consecutive places with a stable second key, such as the name.** Rejected: the alphabet would decide the place itself.
2. **Dense places (16, 16, 17).** Rejected by the user: there is no 17th.
3. **A sporting tie-break, such as the best single result or more counted results.** Rejected: the regulations have no such rule, and a shared place states what is true, that the totals are equal.
4. **Only from 2026/27 (the plan's Q2 B).** Rejected: every ranking function would need a season switch, and past lists would keep an order nothing fixed.
5. **Registration time inside a shared tier, as the organiser download did.** Rejected by the user in favour of the ranking's row order, so a seed file reads the way the ranking does.
6. **Recompute the shared rank in Python from the points.** Rejected: it would re-implement the ranking rule in a second place. The generator reads the rank the database gives it.

## Consequences

- New: `supabase/migrations/20261018000001_equal_totals_share_place.sql`, `supabase/tests/111_equal_totals_share_place.sql` (RANK.TIE.01–07, 12 assertions). Modified: `python/pipeline/ftl_seed_export.py`, `python/pipeline/ftl_seed_export_db.py`, `frontend/src/components/SeasonRulesModal.svelte` and `frontend/src/lib/locales/{pl,en}.json`. New tests sit in `python/tests/test_ftl_seed_orchestration.py` (RANK.TIE.07, two tests), `frontend/tests/ftlSeedExport.test.ts` (RANK.TIE.07, the parity case) and `frontend/tests/SeasonRulesModal.test.ts` (RANK.TIE.08).
- A list can show a gap after a tie (16, 16, 18). The rules modal explains it.
- Exact ties stay whole numbers under ADR-114, and they now share their place as well as their number.
- The main list, the drilldown, the ODS export and the TypeScript seed generator print the rank they are given and need no code change.
- **Checked, deliberately unchanged:** `fn_ftl_roster`'s `ROW_NUMBER` numbers an alphabetical pick-list, not a place. The `ROW_NUMBER`s that choose each fencer's best N results inside the ranking functions choose results, not places.

| Test | Layer | Asserts |
| --- | --- | --- |
| RANK.TIE.01 | pgTAP | `fn_ranking_ppw` on totals 40, 35, 35, 20 returns ranks 1, 2, 2, 4. |
| RANK.TIE.02 | pgTAP | The same for `fn_ranking_full`, `fn_ranking_kadra` and the dispatchers. |
| RANK.TIE.03 | pgTAP | A three-way tie: 3.00, 1.00, 1.00, 1.00, 0.50 gives 1, 2, 2, 2, 5. |
| RANK.TIE.04 | pgTAP | The event-code variants rank the same way. |
| RANK.TIE.05 | pgTAP | A shared place lists alphabetically, and the same way on every call. |
| RANK.TIE.06 | pgTAP | Over all 30 PPW 2025/26 lists, every rank is one more than the number of higher totals. |
| RANK.TIE.07 | pgTAP, pytest, Vitest | Tied fencers share one seed tier, in the ranking's row order whatever their registration times, and both generators seed the same case the same way. |
| RANK.TIE.08 | Vitest | The rules modal states the rule in Polish and English, for every season. |
