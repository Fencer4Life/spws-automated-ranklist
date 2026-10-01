# ADR-104: SPWS 2026/2027 — the Place-and-Medal Engine and Its Columns Are Removed; EVF with a Joined-Bracket Premium and a Whole-Bracket Cap Replaces It

**Status:** Accepted (signed off 2026-09-30 with the implementation plan, decisions D0, D1 A, D2 A, D3 A, D4 A; implemented 2026-09-30 in `supabase/migrations/20260930000001_remove_place_medal_engine.sql`, `20260930000002_add_evf_joined_score_method.sql` and `20260930000003_spws_evf_joined_engine.sql`; released to CERT and PROD on 2026-10-01, main `2ec1ab27`, Release run 36899760353; the Admin editor's rules panel for the new engine, JB27.UI.02, implemented 2026-10-01 after the mockup's revision 3 was approved as shown)
**Date:** 2026-09-30
**Supersedes:** [ADR-103](103-spws-place-medal-engine-per-type.md) §1 (the place-and-medal strategy) and §5 (K, m, b and the components `num_field_pts`, `num_below_pts`, `num_medal_bonus`); the part of §4 and of ADR-103's amendment that writes and keeps K, m and b, including b in the PZSz review queue. ADR-103 §3 (field-scaled deleted) and §6 (ranking entry through PPW/MPW) stand.
**Amends:** [ADR-103](103-spws-place-medal-engine-per-type.md) §2 (PPW, MPW and the 2026/27 default name the new engine), §4 (the joined module writes the bracket's category order) and §7 (the pages); [ADR-102](102-published-pages-share-one-scoring-module.md) (the shared module gains the engine and a whole-bracket function, and loses place-and-medal); [ADR-092](092-scoring-table-annex-bilingual-static-page.md) (the annex's content and order); [ADR-085](085-points-calculator-temporary-static-page.md) (the calculator is rebuilt in line with the annex, without the SPWS/EVF toggle); [ADR-024](024-combined-category-splitting.md) (a joined bracket on the new engine is still scored whole, now with its order instead of K, m and b); [ADR-100](100-pzsz-senior-result-ingestion.md) (a senior result no longer records K, m and b; the review queue returns to five parameters)
**Relates to:** [ADR-097](097-scoring-governance-lock-and-privileged-revision.md) (the season lock, the §11 gate, the privileged revision), [ADR-042](042-carryover-engine-dispatcher.md) and [ADR-045](045-engine-selector-default-flip.md) (the static dispatcher), [ADR-049](049-joint-pool-split-flag.md) (`PER_CATEGORY_RENUMBER`, unchanged), [ADR-069](069-participant-count-url-validator.md) and [ADR-066](066-min-participants-ingestion-gate.md) (the joined N is still the tournament's participant count), [ADR-002](002-calculate-once-store-forever.md) (the cap is computed and stored at write time), [ADR-022](022-ingestion-db-transaction.md) (the atomic ingest RPC gains the order), [ADR-083](083-server-enforced-authorization.md) (the anon allowlist keeps its names), the ADR-036 amendment (bootstrap ordering). Checked and clean: [ADR-090](090-prod-surface-as-wordpress-menu-item.md), [ADR-094](094-release-docs-only-skip.md).
**Source:** `doc/plans/adr-104-joined-engine-implementation-plan-2026-09-30.html`; rule `doc/plans/joined-scoring-final-spec-2026-09-30.html`; annex `doc/plans/scoring-table-rewrite-plan-2026-09-30.html`

## Context

`SPWS_PLACE_MEDAL_V1_2026_2027` ([ADR-103](103-spws-place-medal-engine-per-type.md)) was released to CERT and PROD on 28 September 2026 and assigned to PPW, MPW and the 2026/27 season default. It scores a bracket of 4–31 as log₂N + 3.5 × fencers below + a category medal, which moves single-category scoring away from EVF: the winner of a single-category bracket of 8 scores 53.5 points, where EVF gives 98.00.

On 30 September the user locked a different rule (`doc/plans/joined-scoring-final-spec-2026-09-30.html`):

- a bracket of 1–3 fencers is a meeting: N − place + 1;
- a single-category bracket of 4 or more, and any bracket of 16 or more, scores plain EVF;
- in a joined bracket of 4–15 the youngest category scores EVF, and an older category scores max(EVF × (1 + 0.05 · d), EVF + d), where d is the category steps from the youngest category present;
- nobody scores more than the fencer directly ahead, of any category, minus 1 point;
- the rank coefficient multiplies after the cap.

Its guarantees (the youngest category is never capped; a category of 1–3 never scores below its own meeting; every fencer is at least 1 point below the fencer ahead; nobody gains by placing lower) were checked on 261,984 and 43,704 exhaustive finishing orders and on every joined bracket of PPW and MPW in 2023/24–2025/26.

Verified read-only on 30 September 2026 (LOCAL via `psql`, CERT and PROD via `scripts/cloud-sql.sh`):

- SPWS-2026-2027 is unlocked everywhere, with 0 results.
- No result and no revision names the place-and-medal engine.
- Of 2,811 results in each environment, none holds a value other than −1 in `int_category_count`, `int_category_place`, `int_below_count`, `num_field_pts`, `num_below_pts` or `num_medal_bonus`; neither do the 256 draft rows on CERT, nor any row of `tbl_pzsz_match_review.int_below_count`.
- No seed file under `supabase/` names these columns.

The cap reads across categories, but each category of a joined listing is stored as its own tournament (`python/pipeline/plugins/ingest.py`, `Commit.run`), and fencers without a category — a pending match, or no birth year — are never stored (`python/pipeline/stages.py`, `s7_split_by_vcat`). Scoring from the stored sibling rows would therefore break exactly where a fencer is missing.

## Decision

### 1 · Cleanup first, in its own migration

The place-and-medal engine and everything it added that nothing will use are removed before the new engine is introduced, in a migration of their own:

- `fn_score_spws_place_medal_v1_2026_2027`, its dispatcher branch and its registry row. The row is deleted when nothing names it; otherwise it is marked inactive and anything still assigned to it fails closed with "Unknown scoring engine".
- From `tbl_result` and `tbl_result_draft`: `int_category_count`, `int_category_place`, `int_below_count`, `num_field_pts`, `num_below_pts`, `num_medal_bonus`, their CHECKs, and the PLACE_MEDAL arm of `chk_result_components_match_method`.
- `tbl_pzsz_match_review.int_below_count`, its CHECK, and the sixth parameter of `fn_queue_pzsz_match_review`.
- The PLACE_MEDAL value of `enum_score_method` and three fields of `typ_score_breakdown`.
- The same columns from `vw_score` and `fn_fencer_scores_rolling_*`, which are recreated and regranted as before.

The migration starts with a guard that aborts, changing nothing, if any row holds a value in a column it would drop. It moves the 2026/27 default, PPW and MPW to EVF classic only while the season holds no scored result; the engine migration of §2 moves them on within the same deploy.

Kept, because the new engine reuses them: the per-type engine assignment (`tbl_scoring_type_config.id_scoring_engine`, `fn_get_type_engine`, `type_engines` in export, import and apply), `tbl_scoring_engine.txt_joined_bracket_module` and its two module names, the `enum_score_method` column, `json_ranking_rules.entry_types` with the PPW/MPW ranking entry, and `fn_public_scoring_params`.

### 2 · The new released strategy and the whole-bracket chain

`fn_score_spws_evf_joined_v1_2026_2027(n, place, d, joined, mp_value, de_round, podium_gold, podium_silver, podium_bronze)` is registered as `SPWS_EVF_JOINED_V1_2026_2027`, labelled „SPWS — punkty EVF i premia w stawce łączonej (od sezonu 2026/2027)” and paired with `JOINED_BRACKET_CATEGORY_PLACE`. It scores one row, IMMUTABLE, without the cap:

- **TABLE** for N ≤ 3: N − place + 1;
- **EVF_CLASSIC** for a single-category bracket and for N ≥ 16: `fn_score_evf_classic_v1_2025_2026` on the joined place and N;
- **EVF_JOINED** for every row of a joined bracket of 4–15: the EVF parts plus the premium max(EVF × (1 + 0.05 · d), EVF + d) − EVF, which is 0 at d = 0.

`fn_score_joined_bracket(engine, order, mp_value, de_round, podium_gold, podium_silver, podium_bronze)` scores a whole bracket from its order: it calls the dispatcher for every place and walks the cap from 1st place down, capped(p) = min(raw(p), capped(p − 1) − 1), on unrounded values. The writer, the preview and the tests all use it, so the cap exists in one SQL function. The coefficient multiplies the capped value, and `num_final_score` is rounded once.

Its constants — the meeting up to 3, the premium up to 15, 5% per category step, the 1-point cap — belong to the engine version. Only the EVF settings and the coefficient remain season configuration.

### 3 · The bracket's category order is stored, not derived

Every category tournament of a listing on the new engine stores the listing's category order in `tbl_tournament.txt_joined_order`, one digit (0 = V0 … 4 = V4) per place, for example `343344`; `tbl_tournament_draft` carries it too. A CHECK admits only digits 0–4 with length N. The writer refuses a tournament of a type on the new engine without an order, and a row whose place carries another category's digit.

The writer scores the whole bracket from the order and updates only its own tournament's rows, so no sibling row is read, scoring does not depend on who was stored, and rescoring one tournament gives the same numbers as rescoring all. d for each row is written to `int_category_steps`.

Recompute after a birth-year correction rewrites the digits of stored places whose category changed, and keeps the digits of places that were never stored.

### 4 · Ingestion refuses what cannot be scored

Under `JOINED_BRACKET_CATEGORY_PLACE`:

- a joined listing (two or more categories) with a repeated place is refused, and the operator asks the organiser for the fenced order;
- a listing with a fencer who has no category (a pending match, or no birth year) is refused until that is resolved;
- a single-category listing with a tie still scores as EVF classic always has.

The module no longer writes K, m or b. `CommitPzszSenior` no longer writes them either; PPS and MPS stay on EVF classic.

### 5 · The assignment

For SPWS-2026-2027 the season default, PPW and MPW move to the new engine; PPS, MPS, PEW, MEW, MSW and PSW stay on EVF classic. The move replaces `fn_backfill_scoring_engines`, which `supabase/seed_post_backfill.sql` calls again (ADR-036 amendment), and keeps the §11 gate of [ADR-097](097-scoring-governance-lock-and-privileged-revision.md): a season with a scored result is not reassigned; a privileged revision is required.

### 6 · Storage of the new components

`tbl_result` and `tbl_result_draft` gain `num_joined_premium`, `num_cap_reduction` and `int_category_steps`, NOT NULL DEFAULT −1 with a CHECK admitting only ≥ 0 or −1. The cap reduction is stored as a positive amount so it never collides with −1, "not used". `enum_score_method` gains EVF_JOINED; the components-match-method CHECK covers TABLE, EVF_CLASSIC and EVF_JOINED.

### 7 · An automatic check of § 2, never a sign-off

At the end of each event ingestion run and after each recompute of a PPW or MPW event, the pipeline reads the stored orders of the event's listings per weapon and gender (they give every category's exact size and which categories fenced together), computes § 2's grouping with `plan_brackets` (`python/pipeline/joined_brackets/`, a port of the spec's reference implementation), and stores the verdict in `tbl_joining_check`. When the verdict changes, to a mismatch or back, it sends one Telegram message through `TelegramNotifier` (`python/pipeline/notifications.py`). Every listing is scored as fenced; nothing waits for a person.

### 8 · Public pages

`frontend/src/lib/scoring.ts` implements the engine and `scoreBracket`, mirroring §2. The annex (Załącznik nr 1) is the rewrite of 30 September: W skrócie, then the tools, then the rules §§ 1–6. The points calculator is rebuilt from the annex's tools — calculator, premium table and bracket simulator — follows the active season and has no SPWS/EVF toggle. Both compute only with the new engine. `fn_public_scoring_params` keeps its shape and grants.

## Alternatives considered

1. **Keep K, m, b and the three components "for a later season".** Rejected (D0): they hold only −1 everywhere, no engine reads them, and each one keeps readers, CHECKs and tests alive with no consumer. The guard makes their removal fail closed.
2. **Edit the place-and-medal strategy in place.** Rejected: released strategies are immutable, and the name would describe a formula it no longer is.
3. **Cap within the fencer's own category** (the 29 September plan). Rejected: the locked rule caps at the fencer directly ahead, of any category.
4. **Read the sibling tournaments' rows for the cap** (D1 B). Rejected: a fencer who is not stored breaks the chain, and rescoring one category would silently require rescoring all.
5. **A separate bracket table referenced by each tournament** (D1 C). Rejected: the same information as the stored order, with a new table and more RPC changes.
6. **The cap inside the strategy.** Impossible: it needs the scores of the places above.
7. **The cap as a negative component.** Rejected: it would collide with −1.
8. **Re-join or split listings to follow § 2** (D2 B). Rejected: categories fenced apart have no common order, so only over-joining could be repaired, and a split replaces a fenced result with an estimate.
9. **A human sign-off on § 2 mismatches.** Rejected by the user: the check is automatic.

## Consequences

- A single-category bracket of 4 or more, and every bracket of 16 or more, scores exactly EVF. The premium and the cap apply only to joined brackets of 4–15.
- Every reader of components moves in the same release: `vw_score`, `fn_fencer_scores_rolling_*`, `fn_ingest_tournament_results` (a new `p_joined_order`), `fn_commit_event_draft`, `frontend/src/lib/export.ts`, `frontend/src/lib/types.ts`, `python/pipeline/export_seed.py`, the Admin editor's engine panel and the drilldown export.
- The PZSz review queue returns to its five-parameter RPC.
- The operator must resolve pending matches in a joined PPW or MPW listing before commit, and obtain the fenced order when a joined listing repeats a place.
- If a 2026/27 result is scored before the deploy, the season needs one privileged revision per affected environment, and the old engine stays registered, inactive. None was: at the release on 2026-10-01, CERT and PROD each held 0 scored 2026/27 results, and the old engine's registry row was deleted.
- **Tests:** `supabase/tests/83_spws_place_medal_engine.sql` (35 assertions) is deleted with the engine; SE27.RANK.01–05 move unchanged into `supabase/tests/85_spws_evf_joined_engine.sql`; SE27.TYPE, SE27.STORE and SE27.CALC are retargeted there as JB27.TYPE, JB27.STORE and SS26/SE27.CALC; SE27.ING.05 (K, m and b) is retired. The new tests are JB27.CLEAN, ENG, CAP, ORD, PRE, TYPE, STORE, ING, JOIN, UI and PAGE.
- **New files:** the cleanup and engine migrations (the enum value `EVF_JOINED` in a file of its own, because Postgres refuses a new enum value inside the transaction that added it), `python/pipeline/joined_brackets/joining_check.py`, `supabase/tests/85_spws_evf_joined_engine.sql`, `python/tests/test_joining_rules.py`.
- **New table:** `tbl_joining_check`, service role only.
- The 2026/27 coefficients differed between environments on 30 September (PROD: MEW 1.3, MPS 1.3, MSW 1.4, PPS 1.1, PSW 1.1; CERT and LOCAL: 2, 1.0, 1.2, 1.0, 2.0). PROD's values are the intended ones (D4). CERT was aligned through the Admin editor on 2026-10-01, before the release, and read back equal to PROD.
