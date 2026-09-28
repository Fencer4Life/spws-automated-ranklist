# ADR-103: SPWS 2026/2027 — Place-and-Medal Engine per Tournament Type, Joined Brackets Scored Whole, Ranking Entered through PPW/MPW

**Status:** Accepted (signed off 2026-09-28; §2 amended the same day — PPS and MPS stay on EVF classic)
**Date:** 2026-09-28
**Amends:** [ADR-097](097-scoring-governance-lock-and-privileged-revision.md) (the engine is governed per tournament type, not only per season), [ADR-098](098-ranking-schema-v2-and-generalized-ranking-rpc.md) (the Season Scoring Rules gain `entry_types`), [ADR-102](102-published-pages-share-one-scoring-module.md) (the shared module gains the new engine and loses field-scaled; public parameters are per type), [ADR-092](092-scoring-table-annex-bilingual-static-page.md) (annex content becomes the 64 × 64 table), [ADR-085](085-points-calculator-temporary-static-page.md) (calculator gains the joined mode; the toggle compares SPWS with EVF classic), [ADR-049](049-joint-pool-split-flag.md) (renumbering becomes the named module `PER_CATEGORY_RENUMBER`), [ADR-069](069-participant-count-url-validator.md) (the count check compares the joined N), [ADR-100](100-pzsz-senior-result-ingestion.md) (PPS/MPS are scored by the new engine with K = N, m = place)
**Supersedes:** [ADR-024](024-combined-category-splitting.md) in part — for tournament types assigned the new engine, a joined bracket is no longer split and renumbered per category.
**Relates to:** [ADR-042](042-carryover-engine-dispatcher.md) and [ADR-045](045-engine-selector-default-flip.md) (the static `CASE … ELSE RAISE` dispatcher pattern, reused), [ADR-056](056-vcat-from-birthyear.md) (a fencer's own category defines K and m), [ADR-066](066-min-participants-ingestion-gate.md) (the minimum-field gate reads the joined N), [ADR-083](083-server-enforced-authorization.md) (the anon allowlist pair), the ADR-036 amendment (bootstrap ordering: the assignment function is called again from `supabase/seed_post_backfill.sql`)
**Source:** `doc/plans/scoring-engine-2026-2027-implementation-plan-2026-09-28.html` §3; design `doc/plans/scoring-engine-2026-2027-brainstorm-2026-09-27.html` round 10; signed-off table `doc/plans/tabela-punktacji-propozycja-2026-09-27.html`

## Amendment (2026-09-28 — PPS and MPS stay on EVF classic)

Reviewing the per-type editor mockup on 28 September 2026, the user assigned the PZSz senior types PPS and MPS to `EVF_CLASSIC_V1_2025_2026` for 2026/2027, not to the new engine. Only PPW and MPW use `SPWS_PLACE_MEDAL_V1_2026_2027`. §2 is corrected in place; the rest of this record stands.

- A PZSz senior field is scored as [ADR-100](100-pzsz-senior-result-ingestion.md) scored it before this record: the full original field as N, the original place, EVF classic's place points, DE rounds and podium, times the type's coefficient.
- `CommitPzszSenior` still writes K = N, m = place and b, and the review queue still keeps b (§4). EVF classic does not read them. They are facts about a field that is never stored, so a later season that scores these types by place can use them.
- The ranking-entry gate (§6) is unchanged: PPS and MPS never admitted a fencer to the ranking.
- On the public pages the coefficient table shows PPS and MPS under EVF, and the annex offers no PPS or MPS shortcut on its coefficient slider, because its table is the SPWS engine's.
- Tests: SE27.TYPE.02, SE27.TYPE.04 and SE27.CALC.01 pin the corrected assignment; SE27.ING.05 pins K, m and b under both engines.

## Context

The board redefines §8 for 2026/2027: a joined bracket — fencers of two or more age categories fenced as one tournament — is scored by place in the whole bracket, not split per category. On the engine assigned in September (`SPWS_FIELD_SCALED_V1_2026_2027`), scoring the whole bracket makes 42–47% of joined configurations lose points, so older categories have no reason to join.

The signed-off formula scores only quantities a joining category cannot reduce: the size of the field, the fencers with a worse result, and a medal within one's own category. Up to 31 fencers no participant loses by joining. From 32 fencers the board prefers the EVF algorithm and accepts the drop at the boundary, which the rules state in words (§8 ust. 8).

The formula needs more than today's strategy contract passes. The contract carries two inputs (N, place). The new formula needs five: N, the place p, the number of fencers of one's own category in the bracket (K), the place among them (m), and the number of fencers strictly below (b). It must not reach international results, where EVF publishes per category. The board also limits ranking entry to fencers who start in PPW or MPW (§8 ust. 14).

Verified on 27 Sep 2026 via `scripts/cloud-sql.sh`: SPWS-2026-2027 is unlocked on CERT and PROD, with 0 tournaments and 0 results, and assigned the field-scaled engine. No PPS or MPS result is stored on PROD.

## Decision

### 1 · One new released strategy with three ranges

`fn_score_spws_place_medal_v1_2026_2027(n, place, k, m, below, mp_value, de_round, podium_gold, podium_silver, podium_bronze)` is registered as `SPWS_PLACE_MEDAL_V1_2026_2027`, label „SPWS — miejsce w stawce i premia medalowa (od sezonu 2026/2027)”. The range is chosen by the size of the whole bracket:

- **N ≤ 3 — TABLE:** N − p + 1.
- **4 ≤ N ≤ 31 — PLACE_MEDAL:** log₂N + 3.5 × b + medal. The medal is 13, 7 or 3 × ∛K for m = 1, 2 or 3, only when K > m.
- **N ≥ 32 — EVF_CLASSIC:** `fn_score_evf_classic_v1_2025_2026` on the joined place and joined N, with the season's EVF settings (base, DE round, podium coefficients). No category medal.

log₂N, 3.5, 13/7/3, the N ≤ 3 table and the switch at 32 are part of the engine version, not settings. Only the per-type coefficient stays a season setting. The result is multiplied by it and rounded once, from the raw components, exactly as before.

A place is "strictly below" only if it is worse: a fencer tied with you does not count (§8 ust. 6). The category place is 1 + the number of own-category fencers with a strictly better place, so ties run 1, 2, 3, 3, 5.

### 2 · The engine is assigned per tournament type

`tbl_scoring_type_config` gains `id_scoring_engine`. A type row that names an engine uses it; a type row with NULL uses the season's engine, `tbl_season.id_scoring_engine`, which stays the season default. `fn_resolve_scoring_params` resolves the engine from the tournament's type, and still raises "Unknown scoring engine" when neither is assigned. Nothing is chosen at calculation time.

For 2026/2027: PPW and MPW use the new engine; PPS, MPS, PEW, MEW, MSW and PSW use EVF classic (as amended 2026-09-28; the signed-off text also put PPS and MPS on the new engine). The season default becomes the new engine, and all eight type rows are set explicitly. Earlier seasons keep NULL type rows and their EVF classic season engine, which is their current scoring.

The assignment is governed like every other scoring field (ADR-097). `fn_export_scoring_config` reports `type_engines` (the resolved engine per type). `fn_import_scoring_config` rejects a change to it once the season is locked. `fn_apply_scoring_config_write` writes it, so the privileged revision can change it, and the revision snapshot records it. The ingestion pipeline reads the assignment through `fn_get_type_engine(id_season, type)`, which raises when nothing is assigned.

The dispatcher stays a static `CASE … ELSE RAISE`. It gains K, m and b, which EVF classic ignores, and returns a breakdown type (`typ_score_breakdown`) naming the method that scored the result.

### 3 · `SPWS_FIELD_SCALED_V1_2026_2027` is deleted

Its function, dispatcher branch, registry row, `scoring.ts` branch and tests are removed. It never scored anything: 0 revisions and 0 results on CERT and PROD. `fn_backfill_scoring_engines` named it and is called again from `supabase/seed_post_backfill.sql`, so it is replaced in the same migration by a version that performs the 2026/2027 per-type assignment. The §11 gate is kept: it refuses to reassign a season that already holds scored results.

### 4 · Joined-bracket modules are paired with engines

`python/pipeline/joined_brackets/` holds two named modules and a registry that maps each engine code to exactly one module:

- **`PER_CATEGORY_RENUMBER` ↔ EVF classic.** Today's behaviour, byte-identical: split the bracket per category, dense-renumber places 1..K, store N = the category's size (ADR-049). `_rerank_places` moves here unchanged.
- **`JOINED_BRACKET_CATEGORY_PLACE` ↔ the new engine.** Keep the joined place and the joined N; file each fencer under their own category's tournament as today; write K, m and b.

Ingestion (`Commit`) and `RECOMPUTE_DOMESTIC` use the module of the engine assigned to the tournament's type. `CommitPzszSenior` writes K = N, m = place and b from the full senior field, whatever the engine. The review queue keeps b so a later approval can write it. `tbl_scoring_engine` stays metadata only (ADR-097). It gains a display column naming the paired module, never a function reference.

### 5 · Storage — explicit components, −1 for "not used"

`tbl_result`, and its mirror `tbl_result_draft`, gain:

- **Inputs written at ingestion:**
  - `int_category_count` (K);
  - `int_category_place` (m);
  - `int_below_count` (b).
- **Outputs written by scoring:**
  - `num_field_pts`, `num_below_pts` and `num_medal_bonus`;
  - `enum_score_method` (TABLE, PLACE_MEDAL or EVF_CLASSIC).

**−1 means "not used"** by the method that scored the result, in every component column and in K, m and b. A `CHECK` on each column admits only real values or −1 (K and m ≥ 1; the rest ≥ 0). NULL is never written into a scored row, and NaN is never used: Postgres sorts `'NaN'` above every number and `to_json` turns it into a string. Under EVF_CLASSIC the three new components are −1. Under PLACE_MEDAL the three EVF components are −1. Under TABLE the table points are stored in `num_place_pts` (the points for the place) and every other component is −1. A method column that is NULL means the row has not been scored yet, like `ts_points_calc`. History is backfilled with −1 and EVF_CLASSIC.

`int_below_count` is stored, not derived. It depends on fencers who are not in the fencer's own tournament row set: other categories of a joined bracket, and the unstored senior field of a PZSz bracket.

### 6 · Ranking entry through PPW or MPW

The Season Scoring Rules gain `entry_types`, a top-level key of `json_ranking_rules` read in both rule schemas. From 2026/2027 it is `["PPW","MPW"]`. `fn_ranking_full_event_code_matching` and `fn_ranking_full_event_fk_matching` then admit only fencers with a result of those types in the ranking's window: the ranked season, plus the carried previous season in rolling mode, in any weapon. Their PPS, MPS, EVF and FIE results count as today. Seasons without the key are unchanged.

### 7 · Public pages

`frontend/src/lib/scoring.ts` implements the new engine (five inputs) and EVF classic; field-scaled is removed. `fn_public_scoring_params` returns one row per tournament type — engine code and label, coefficient, and the season's EVF settings — and its grant stays in both anon allowlists. The annex becomes the signed-off 64 × 64 table (1–3 flat, 4–31 SPWS, 32–64 EVF) with a complete medal table for K = 1–31 and the per-type coefficients. The calculator gains the joined mode, and its toggle compares SPWS with EVF classic. The temporary board preview (ADR-085 amendment of 2026-09-28) is deleted in the same release.

## Alternatives considered

1. **Rewrite the field-scaled strategy in place.** Rejected: released strategies are immutable, and the name would describe a formula it no longer is.
2. **One engine for every type.** Rejected: EVF points would rise by 25–32%, and small EVF categories would fall to 1–3 points.
3. **Derive K, m and b from stored rows.** Rejected: they are wrong whenever a bracket fencer is not stored with the fencer's own rows — a category fencer excluded at ingestion, another category of a joined bracket, or the senior field of a PZSz bracket. Explicit columns also make drilldown and audit exact.
4. **NULL or NaN for "not used".** Rejected at the user's request for a value that says "not used". NaN also sorts above every number in Postgres and serialises as the string "NaN".
5. **A cap of 31, or a taper, instead of the EVF switch.** The board chose the EVF switch at 32 and accepted a documented drop at the boundary.
6. **A second policy dropdown next to the engine.** Rejected: the engine and its joined-bracket module are one choice.
7. **Move the engine entirely onto the type rows and drop the season engine.** Rejected for now: the season engine is read by the revision table, the wizard and every existing test; keeping it as the default for NULL type rows changes nothing for earlier seasons.

## Consequences

- **Joining is safe only up to 31 fencers.** Crossing 31 → 32 costs existing fencers 3.5–44.9 points, and §8 ust. 8 says so.
- **The ranking loses some fencers.** Fencers with only EVF, FIE or PZSz results leave the 2026/2027 full ranking. Earlier seasons keep their published rankings. The PPW view is unaffected, since every row in it is a PPW start.
- **Every reader of score components must handle −1.** It labels components by method and never adds −1 to anything: `vw_score`, `fn_fencer_scores_rolling_*`, `export.ts`, `DrilldownModal.svelte`, `export_seed.py` and `build_scorecards.py`.
- **The anon surface changes shape, not size.** `fn_public_scoring_params` keeps its name and argument, so the allowlists are unchanged. The pgTAP total and Appendix D move.
- **CERT may need one privileged revision.** If CERT scores a 2026/2027 result before this lands (the daily `evf-sync.yml` may ingest PEW1f), the migration's gate refuses the silent switch. One privileged revision (ADR-097), run with the board's reference, reaches the new assignment.
- **New files:**
  - `supabase/migrations/20260928000001_spws_place_medal_engine.sql`;
  - `supabase/tests/83_spws_place_medal_engine.sql`;
  - `python/pipeline/joined_brackets/`.
- **Deleted:** `fn_score_spws_field_scaled_v1_2026_2027`, the field-scaled registry row, `frontend/public/tabela-punktacji-projekt-2026-2027.html` and its SE27.PREVIEW tests.
- **Joint-pool siblings (ADR-049 `bool_joint_pool_split`) are not joined across listings.** Each parsed listing is one bracket for N, K, m and b. No 2026/2027 event has used a joint pool; if one does, it is a separate decision.
