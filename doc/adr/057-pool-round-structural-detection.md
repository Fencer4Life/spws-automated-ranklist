# ADR-057: Pool-round detection by structural data signal, not bracket-name regex

**Status:** Accepted (2026-05-02)
**Related:** ADR-034 (cross-gender tournament scoring), ADR-049 (joint-pool split flag), ADR-050 (unified ingestion pipeline), ADR-056 (V-cat from birth year)
**Phase:** 5 (operational rebuild)

## Context

Every SPWS event runs **two preliminary pool rounds per weapon**. All participants — men, women, all V-cats — fence together in those pools. Pool-round results are NOT a tournament scoring source; the per-V-cat tournaments that follow are.

The unified pipeline's bracket-skip decision (which sub-tournaments to ingest, which to drop) was originally name-regex-based: skip patterns like `Mixed`, `DE`, `AMATOR`, `Junior`, `Cadet`. This works only when organizers consistently name pool rounds in a recognizable way — and they don't.

In Phase 5 day 1 this fragility burned a real tournament: I conflated "Vet Men's Épée" (V1, the base veteran category) with "Mixed Épée" (the actual pool round) and added bare-`Vet` to the skip pattern, dropping V1 men's results for every weapon in the event. Operator caught it. Same fragility could fire any time an organizer names a pool round something we don't recognize ("Open Pool", "Round Robin Combined") or names a real bracket with a skip word.

## Decision

**Pool-round detection moves from name regex to structural data analysis. Names stay as a fast-path advisory; structure is load-bearing.**

Two complementary structural signals:

### 1. Per-bracket gender mix (s7_pool_round_check)

After Stage 6 (matcher) has matched fencers to `tbl_fencer`, batch-fetch `enum_gender` for every matched fencer. The bracket halts as a pool round when **both** apply:

- `minority_count ≥ 3` — at least three cross-gender fencers (more than ADR-034 noise)
- `minority_ratio ≥ 0.20` — minority share is at least 20% (genuine mix)

Why both? ADR-034 explicitly allows a small number of cross-gender fencers in a real per-gender tournament (a woman competing in a men's bracket when no women's bracket exists for that weapon at the event). Their points re-assign at scoring time; the bracket is still a real tournament. The two conditions distinguish ADR-034 cross-gender from a true mixed pool round.

A separate halt fires when the bracket's **parsed gender disagrees with the matched-fencer majority gender** — i.e. the name says "Men's" but most matched fencers are female. This is wrong-name / data-error territory and should not become a tournament.

Halt reason: `POOL_ROUND_DETECTED`. Bracket is dropped from drafts; the event-level processing continues.

### 2. Per-event invariant (≤2 pool rounds per weapon)

After all brackets have been processed (some skipped at the FTL splitter via `Mixed` / `DE` / etc., others halted at `s7_pool_round_check`), the runner counts pool-round brackets per weapon and warns if any weapon has > 2. SPWS convention is exactly two pool rounds per weapon per event; three or more means either the splitter is over-skipping real tournaments, or the source has unusual structure that warrants operator review.

Warning is non-blocking — the runner emits it to stderr and to the staging summary `.md`.

### Name regex stays as fast-path

`Mixed [Weapon]`, `\bDE\b`, `AMATOR`, `JUNIOR`, `CADET`, `U\d+` patterns continue to skip brackets at FTL splitter time. They're cheap pre-filters for obvious cases. But if the structural check disagrees, structural wins — a bracket the name regex passes can still halt at `s7_pool_round_check`, and a real tournament whose name happens to include a skip word would now be a regression we'd see in the per-event count rather than a silent loss.

## Alternatives considered

- **Pure name-regex (status quo).** Fragile, organizer-dependent, just demonstrated broken in production. Rejected.
- **Pure structural detection, drop name regex entirely.** Possible but loses cheap early filtering for obvious junk. Combined approach is better.
- **Event-level size-dominance test instead of per-bracket gender mix.** "Pool round = bracket fencer-count ≈ sum of all weapon-tournament fencers." Considered as the primary signal but rejected because it doesn't catch a same-weapon pool round of just one gender (e.g. an organizer who runs M-only and F-only pools separately). Per-bracket gender mix catches that case.
- **Halt on minor cross-gender mix.** Would punish ADR-034 legitimate cross-gender fencers. Rejected.

## Consequences

**Positive**
- Bracket name no longer load-bearing for ingest correctness.
- Adds a structural tripwire that catches both wrong-skip (real tournament dropped) and wrong-include (pool round ingested) failures.
- Per-event invariant surfaces unusual events for operator review without blocking ingest.
- ADR-034 cross-gender cases pass through unaffected.

**Negative / risks**
- Requires post-match data to detect (gender lookup needs `id_fencer`). All-PENDING brackets can't be checked; they pass through. Operator review needed for those.
- 20% / 3-fencer thresholds are heuristic. May need tuning per organizer convention.

**Neutral**
- ≤2 pool rounds per weapon is a SPWS convention. EVF / FIE events may differ; the warning lets the operator decide rather than the system silently failing.

## Implementation

- `python/pipeline/types.py` — `HaltReason.POOL_ROUND_DETECTED`; `PipelineContext.is_pool_round`.
- `python/pipeline/stages.py` — `s7_pool_round_check` stage with thresholds `_POOL_CHECK_MIN_FENCERS=4`, `_POOL_CHECK_MIN_MINORITY_COUNT=3`, `_POOL_CHECK_MIN_MINORITY_RATIO=0.20`.
- `python/pipeline/orchestrator.py` — `s7_pool_round_check` runs after `s7_validate`, before `s7_split_by_vcat`.
- `python/pipeline/db_connector.py` — `fetch_genders_batch(id_fencers) -> {id: 'M'|'F'|None}`.
- `python/tools/phase5_runner.py` — collects pool-bracket pairs, calls `_check_pool_round_count` for the per-event invariant.
- `python/tests/test_pool_round_check.py` — 9 pytest assertions covering all-M passes, single-outlier passes, mixed halts, wrong-gender halts, all-PENDING passes, tiny-bracket passes, ≤2-per-weapon invariant.

## Test scope (TDD)

- pytest 5.8 — all-M bracket passes
- pytest 5.9 — single-outlier (10% minority) passes — ADR-034 territory
- pytest 5.10 — mixed (40% minority) halts — pool round
- pytest 5.11 — wrong-gender bracket halts — data error
- pytest 5.12 — all-PENDING passes — insufficient signal
- pytest 5.13 — tiny bracket (2 fencers) passes — insufficient signal
- pytest 5.14 — invariant: 2 pool rounds per weapon → no warning
- pytest 5.14 — invariant: 3 pool rounds for one weapon → warning surfaced
- pytest 5.14 — invariant: 0 pool rounds → no warning (event without pools allowed)
