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
