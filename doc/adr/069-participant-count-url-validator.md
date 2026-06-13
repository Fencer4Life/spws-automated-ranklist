# ADR-069: Per-tournament participant-count URL validator (HALT gate)

**Status:** Accepted; implemented LOCAL 2026-06-04.
**Date:** 2026-06-04
**Relates to:** ADR-049 (joint-pool split + its 2026-06-04 per-V-cat amendment),
ADR-052 (URL→data validation), ADR-038 (per-cat field count), ADR-024 (combined
category splitting).

## Context

Two failure classes corrupt `int_participant_count`, which `fn_calc_tournament_scores`
reads directly:

- **(A) Joint-pool sum inflation** — the pre-amendment ADR-049 rule summed V-cat
  siblings sharing a `url_results`. Fixed by the ADR-049 amendment + its pgTAP
  invariant.
- **(B) Result-row contamination** — the stored result-row count is itself wrong
  (e.g. `PPW3-V1-F-EPEE` committed 10 rows while the FTL bracket holds 6). A
  pure internal invariant (`int_participant_count == COUNT(tbl_result)`) cannot
  see this: both sides are equally inflated.

Class (B) can only be caught by comparing the committed count against the live
result bracket. `fn_commit_event_draft` is a plain INSERT path with no such
check; the existing pre-commit S7 count check (ADR-052) compares the *combined*
`raw_pool_size` before the per-V-cat split, so it is blind to per-bracket counts.

## Decision

Add a **post-commit, per-tournament URL validator**. After `fn_commit_event_draft`,
for each committed tournament:

1. Re-fetch its `url_results` (authed FTL client where required).
2. Compute the **per-V-cat membership** the bracket actually contains — split by
   `birth_year` via `vcat_for_age(season_end_year − birth_year)`, mirroring the
   pipeline's `s7_split_by_vcat`.
3. Compare to the stored `int_participant_count`.

A mismatch is a **`PARTICIPANT_COUNT_MISMATCH` halt**: the run fails and the
event is flagged. The commit has already written, but this is safe in the
recreate/deploy flow because it wipes-and-re-ingests and nothing is promoted to
CERT/PROD until the run is clean. A missing URL (cert_ref / xlsx) or a fetch
error is a **warn** — never a silent pass, but does not block.

Implementation:
- Pure module `python/pipeline/participant_count_validation.py`
  (`validate_event_participant_counts(tournaments, fetcher, *, season_end_year)`
  → list of `CountFinding`; `has_halt(findings)`), decoupled from the DB for
  unit testing.
- Wired into `recreate_active_season_2025_2026.ingest_event` after the commit,
  re-fetching via `Fetcher(http_client=get_authed_ftl_client())`.
- New enum value `HaltReason.PARTICIPANT_COUNT_MISMATCH`.

**Scope:** SPWS-domestic events (PPW/MPW/GP), where everyone enters the ranklist
so `int_participant_count` equals the per-V-cat bracket size. International
events use ADR-038 full-field counts and are **not** validated this way (would
false-positive).

## Alternatives considered

- **Pre-commit pipeline stage** (after `s7_split_by_vcat`). Rejected: the
  per-V-cat counts are correct at that point; the inflation (class A) was applied
  later by the commit recompute, and contamination (class B) needs the live URL.
  A per-bracket pre-commit stage is structurally blind to both.
- **pgTAP-only internal invariant** (`pcount == COUNT(tbl_result)`). Kept as a
  complementary CI guard (no network), but it cannot catch class (B). The two
  layers are defense-in-depth for different failure classes.
- **Re-fetch vs. reuse rows parsed during ingest.** Re-fetch chosen: it is true
  external ground truth and catches parse + split bugs, not just downstream
  computation.

## Consequences

- Every domestic re-ingest self-verifies its committed counts against the live
  brackets; a bad scrape fails loudly instead of silently corrupting scores.
- One authed fetch per distinct bracket URL per ingest (cached per URL).
- The validator is reusable (pure function) for ad-hoc audits.

## Tests

- pytest `test_participant_count_validation.py` — C2.1–C2.6: per-V-cat match
  passes; sum-inflation halts; contamination halts; shared-URL per-V-cat correct
  passes; no-URL warns; fetch-error warns; `has_halt` helper.
- Complemented by pgTAP 25.5 / 27.27 (ADR-049 amendment) enforcing
  `int_participant_count == own result count` for joint rows.
