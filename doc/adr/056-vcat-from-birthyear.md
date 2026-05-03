# ADR-056: V-cat resolution by post-match fencer birth year

**Status:** Accepted (2026-05-02)
**Related:** ADR-047 (V-cat invariant + splitter consolidation), ADR-049 (joint-pool split flag), ADR-050 (unified ingestion pipeline), ADR-055 (ingest traceability)
**Phase:** 5 (operational rebuild)

## Context

The unified pipeline's Stage 4 split combined-pool brackets into per-V-cat tournaments using `raw_age_marker` — a per-fencer marker the parser was supposed to extract from source data (e.g. FTL's "(1)" suffix on a fencer name, FT XML's `<AgeCategory>` attribute, etc.).

In practice this is unreliable:

- **FTL JSON** (`/events/results/data/<UUID>`) doesn't emit per-fencer age markers in the default `parse_json` path; markers only appear in some legacy combined-pool paths.
- **FTL eventSchedule names** were doing parallel V-cat parsing in `python/tools/scrape_ftl_event_urls.parse_tournament_name` — splitting "Vet-50 Men's Épée" → V2 etc. — but this depends on the organizer's display-name conventions, which vary across events even within the same federation. This Phase-5 session hit four separate variants in one event (`Vet-50`, `Vet-60`, `Vet-70`, bare `Vet`, `Senior` = V0 in one organizer's convention).
- **EVF API** is the only source that reliably tags each fencer's V-cat at the source.
- **Other parsers** (Engarde, 4Fence, Dartagnan, Ophardt, FT XML) produce mixed marker quality.

Phase 5 needs to ingest ~84 historical events spanning multiple sources. The Stage 4 marker-based split silently produced wrong V-cat assignments (everything stacked on V1 default) when markers were absent. This is the kind of hidden data error that propagates into the ranklist permanently — exactly what the rebuild is meant to fix.

## Decision

**V-cat resolution moves to a post-match step, deriving V-cat from the matched fencer's `tbl_fencer.int_birth_year` against the event year.**

Concretely:

1. After Stage 6 (matcher), each `StageMatchResult` carries `id_fencer` for matched rows.
2. A new step (`s7_split_by_vcat`) batch-fetches `int_birth_year` for all matched fencers and computes `derived_vcat = vcat_for_age(event_year - birth_year)`:

    | Age (years on event_year) | V-cat |
    |---|---|
    | < 40 | V0 |
    | 40–49 | V1 |
    | 50–59 | V2 |
    | 60–69 | V3 |
    | ≥ 70 | V4 |

3. Matches are grouped by `derived_vcat`. Each group becomes one `tbl_tournament_draft` row with code `<event>-<vcat>-<weapon>-<gender>`.
4. **Joint-pool flag** (`bool_joint_pool_split`, ADR-049): set `true` on every tournament in the group iff `len(groups) > 1` — i.e. the source bracket really did mix V-cats.
5. Single-V-cat brackets (e.g. FTL's "Vet-60 Men's Épée") still produce one tournament_draft (because all fencers fall in V3 by birth year), with `bool_joint_pool_split = false`.
6. Result drafts get the correct `id_tournament_draft` linkage to their V-cat group's tournament (fixing the placeholder `=0` bug from Phase 3 that prevented `fn_commit_event_draft` from migrating result rows).

Stage 4's old marker-based split is retained as a fallback for source paths that DO carry reliable per-fencer markers (cert_ref, EVF API), but is no longer the primary V-cat assignment mechanism. PENDING/UNMATCHED rows (no `id_fencer` to derive birth year from) are surfaced for operator review and not auto-assigned to a V-cat.

## Alternatives considered

- **Keep marker-based Stage 4 + extend FTL splitter.** Tried during Phase 5 day 1 and produced cascading bugs as each new organizer convention surfaced. Splitter became a moving target.
- **Require operator to manually tag V-cat per bracket via override YAML.** Scales poorly across 84 events; fragile against organizer renames.
- **Trust the source's V-cat tag (when present) over birth year.** Would re-introduce the same fragility; sources are sometimes wrong (e.g. `int_age_category` on EVF combined-pool tournaments was the entire bug behind the Goal-1 EVF re-fix in 2026-04). Birth year is canonical.

## Consequences

**Positive**
- One canonical V-cat source (`tbl_fencer.int_birth_year`) — same logic for every parser.
- Joint-pool detection becomes a derived property, not a per-source heuristic.
- FTL splitter (`parse_tournament_name`) becomes optional metadata, not load-bearing.
- The placeholder linkage bug (`id_tournament_draft = 0`) gets fixed in the same change.

**Negative / risks**
- PENDING / UNMATCHED rows (no `id_fencer`) can't be V-cat-assigned. They appear in the staging diff for operator review and don't get committed until matched.
- Requires `int_birth_year` to be populated for every matched fencer. The existing `BY_ESTIMATED` provenance value (per ADR-050 schema) handles fencers with estimated birth years; estimated BYs are still load-bearing for V-cat — operator owns the BY-correction loop.
- Foreign fencers with unknown / nullable `int_birth_year` cannot be V-cat-assigned. They get tagged for operator review (consistent with ADR-050's "POL-only intake for EVF/FIE; SPWS = all participants").

**Neutral**
- Marker-based Stage 4 stays as a fast-path for reliable parsers. No regression for cert_ref / EVF API.

## Implementation

- Add `db.fetch_birth_years_batch(id_fencers: list[int]) -> dict[int, int | None]`.
- Add `python.pipeline.stages.s7_split_by_vcat(ctx, db)` invoked after `s6_matcher`.
- `ctx.vcat_groups: dict[str, list[StageMatchResult]]` — populated by the new stage.
- `ReviewSession._build_tournament_draft_rows`: emit one row per V-cat group; `bool_joint_pool_split` derived.
- `ReviewSession._build_result_draft_rows`: emit one row per match; set `id_tournament_draft` to the matching V-cat tournament; replace the `=0` placeholder.
- `DraftStore.write_tournament_drafts`: return assigned `id_tournament_draft` per row so the result-draft writer can link.

## Test scope (TDD)

- pgTAP — `fn_commit_event_draft` migrates results when result_drafts have proper `id_tournament_draft` linkage (regression for the placeholder bug).
- pytest — `s7_split_by_vcat`: single-V-cat group, joint-pool group (≥2 V-cats), unmatched-row carve-out, BY-NULL fencer carve-out.
- pytest — birth-year batch fetch wrapper.
- pytest — `_build_*_draft_rows`: correct linkage between tournament and result drafts.

## Revision (2026-05-03) — Bracket-label V-cat overrides BY derivation for past tournaments

### Context (revised)

Phase 5 GP1-2023-2024 ingestion surfaced a routing inconsistency: a fencer
born 1974, physically present in the FTL `Vet Men's Saber` bracket (V1),
ended up in the V2-SABRE-M ranklist tournament because `s7_split_by_vcat`
unconditionally derived V-cat from `BY + season_end_year` (50 in 2024 → V2).

The original ADR treated source bracket labels as unreliable. In practice
for SPWS-organized events, the FTL bracket label IS the organizer's
explicit placement decision for that season — the source of truth. Applying
canonical BY-math overrides it, retroactively reassigning fencers to
ranklists they never competed in. A fencer who was V1 in the 2023-2024
season (organizer placed him in V1 bracket on 2023-01-14) must STAY V1 in
that season's ranklist forever, even though the same fencer becomes V2 in
2024-2025 (next age tier).

### Decision (revised)

**Single-V-cat bracket label wins.** When the source bracket carries an
unambiguous V-cat label (e.g. FTL's `Vet-50 Men's Épée` → V2,
`Vet Men's Saber` → V1, parsed by `parse_tournament_name`), every matched
fencer in that bracket is assigned to that V-cat — regardless of the
`BY + season_end_year` canonical computation. The organizer's bracket
placement is the source of truth for past tournaments.

**BY derivation applies only to joint-pool brackets.** When the bracket
genuinely combines V-cats (parsed name returns a list, e.g. `kat.0-2`,
`Vet Mixed`, `v0v1v2` combined-pool labels), no single label exists, and
each fencer's V-cat must come from `BY + ctx.season_end_year`. ADR-049's
`bool_joint_pool_split = True` continues to flag these tournaments.

**Season-frozen V-cat rule.** A fencer's V-cat for a given season's
ranklist is frozen at ingestion time and never recomputed retroactively.
ZAWROTNIAK Przemysław (BY=1974) was V1 in the 2023-2024 season (V1 bracket
placement on 2023-01-14) and IS V2 in the 2024-2025 season (his age tier
flipped). Re-running the rebuild in 2026 does not change his 2023-2024
contributions.

**EVF events are unaffected.** EVF API tags each fencer's V-cat at the
source; this revision changes only the FTL/Engarde/4Fence/Ophardt
parser paths where bracket label is the strongest signal.

### Implementation impact

- `s7_split_by_vcat`: when `ctx.parsed.category_hint` is a single V-cat
  string, group every matched fencer under that V-cat. Skip BY-derivation
  entirely. Only when `category_hint is None` (joint-pool bracket) does
  the BY-derivation path apply.
- `fn_assert_result_vcat`: relax the assertion to use bracket-derived V-cat
  (i.e. `enum_source_age_category`) as the expected V-cat when set; fall
  back to BY-derived V-cat when source is null (joint-pool path).
- `_consolidate_duplicate_codes`: recompute `int_participant_count` from
  the merged result_drafts after consolidation (separate fix; previous
  behaviour kept the keeper's source-URL count, drifting from row count).
- Past-data rollback: any event committed under the pre-revision logic
  must be deleted from `tbl_tournament` + `tbl_result` and re-ingested.
  Phase-5 rebuild scope as of 2026-05-03: GP1-2023-2024 only.

### Consequences (additional)

**Positive**
- Tournament row count matches source bracket fencer count for non-joint
  brackets (modulo PENDING / UNMATCHED carve-outs).
- Operator's mental model ("this tournament = this URL's fencers")
  matches the data for non-joint brackets.
- Past ranklists are deterministic across re-ingestion attempts —
  re-running the rebuild produces identical ranklist contributions.

**Negative**
- A fencer mis-placed by the organizer (e.g. BY=1974 fencer wrongly
  entered in V0 bracket) gets their canonical V-cat ignored. Operator
  must catch this via the staging .md review (BY column flags the
  mismatch) before signing off.
- BY-fencer-data still required for joint-pool brackets — same constraint
  as the original ADR-056.

### Test scope (TDD, plan IDs 5.19.x)

- pytest 5.19.1 — `s7_split_by_vcat` uses `category_hint` when single V-cat (no BY-derivation, even for fencers whose canonical V-cat would differ).
- pytest 5.19.2 — `s7_split_by_vcat` falls back to BY-derivation when `category_hint is None` (joint-pool).
- pytest 5.19.3 — `_consolidate_duplicate_codes` recomputes `int_participant_count` from merged result_drafts after consolidation.
- pgTAP 5.19.4 — `fn_assert_result_vcat` uses `enum_source_age_category` when set on the result row.
- pgTAP 5.19.5 — `fn_assert_result_vcat` falls back to BY-derived V-cat when `enum_source_age_category` is null (joint-pool path).
- pytest 5.19.6 — integration: V1-bracket fencer with V2-canonical BY routes to V1-SABRE-M tournament (regression test for the GP1 bug).
