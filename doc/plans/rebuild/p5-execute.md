# Phase 5 — Operational rebuild (XL)

**Prerequisites:** Phase 4 ([p4-commit-ui.md](p4-commit-ui.md)) — full commit pipeline + parity gate + alias UI all live.

## Goal

Walk every event in the LOCAL DB through the unified pipeline. Per-event interactive review with operator-driven source-of-truth choice. Oldest first; SPWS first then EVF. Rebuild is **incremental**, never all-or-nothing.

## Setup

- Audit table generated: every event tagged with **source kind, status, expected count, current count**.
- Rebuild execution: oldest-first, season by season, **SPWS first then EVF**.

## Per-event review flow

```
1. ingest_cli.py review-event <event_code>
2. Display: event details, recorded URLs, cert_ref summary
   (tournament+result counts), organizer
3. Prompt: source-of-truth choice
   [1] Use recorded URL  [2] Paste URL  [3] Paste XML path
   [4] EVF API (if EVF-organized)  [5] cert_ref placements (no live URL)
   [q] Skip
4. Run unified pipeline against chosen source → write to draft tables (run_id)
5. Generate doc/staging/<event_code>.diff.md with 3 columns:
   Source (live) | CERT (cert_ref) | New LOCAL (draft)
   Highlight: source-changed / pipeline-regression / new-bug / agree-3
   Append: confidence-distribution histogram for matcher quality review
6. User reviews diff. Three actions:
   - Edit doc/overrides/<event_code>.yaml (URL, identity, splitter overrides) → re-run from Stage 0
   - Edit python/matcher/config.yaml (thresholds, normalizations, nicknames) → re-run from Stage 6
   - Approve → fn_commit_event_draft(run_id) → live + audit + alias-writeback + Telegram
7. Move to next event (oldest first, SPWS first then EVF)
```

For the cert_ref fallback (step 3 → choice 5): the cert_ref parser produces `ParsedTournament` IR from `cert_ref.tbl_*` rows; pipeline runs Stages 1-11 normally; engine still computes points. Stage 7 (URL→data validation) is skipped since there's no URL. Status remains `ENGINE_COMPUTED` like every other event.

## Per-event automation

- Parity gate triggered for every EVF-organized event automatically post-commit.
- Drafts persist via `run_id`; operator can pause and resume across sessions.

## Risk gate

- Zero rows in `vw_vcat_violation`.
- Zero events in `IN_PROGRESS` status.
- Every EVF event either parity-passed or has documented `txt_parity_notes`.
- `fn_compare_carryover_engines` shows no regression vs pre-rebuild baseline.

## Operational notes

- ~60 events total; per-event review may span weeks (open risk #4 in master).
- Rebuild is incremental — never all-or-nothing.
- Alias write-back accumulates as events are approved; later events benefit from earlier USER_CONFIRMED decisions automatically.
- If alias is appended for fencer X and later proves wrong, future ingests will auto-match to X. Admin can edit `tbl_fencer.json_name_aliases` directly via the alias UI shipped in Phase 4; track in audit log; CLI to revoke aliases.

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p4-commit-ui.md](p4-commit-ui.md)
- Successor: [p6-finalize.md](p6-finalize.md) — drop `tbl_match_candidate`, finalize, promote LOCAL → CERT → PROD
- Risk-gate signal `vw_vcat_violation = 0` is the hard exit criterion for this phase
