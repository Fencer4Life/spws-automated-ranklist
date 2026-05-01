# ADR-050: Unified Ingestion Pipeline (rebuild — Phases 0–6)

**Status:** Accepted; rebuild active. Phase 0 schema-prep + cert_ref scaffolding committed 2026-05-01. Phases 1–6 land on `main` over the rebuild lifetime; this ADR is a stub that gets fleshed out as each phase commits.

**Date:** 2026-05-01

**Supersedes:** ADR-024 (Combined Category Splitting), ADR-025 (Event-Centric Ingestion + Telegram Admin), ADR-039 (EVF Scraper Dedup + Stale-Event Gate), ADR-049 (Joint-Pool Split Flag).
**Amended by:** ADR-051 (Frozen-snapshot policy), ADR-052 (URL→data validation), ADR-053 (EVF backup-source + parity gate), ADR-054 (Carry-over FK + 366-day cap).

## Context

The legacy ingestion pipeline accumulated divergence from years of partial fixes. Eight source paths (XML, FTL, Engarde, 4Fence, Dartagnan, EVF API, CSV/XLSX/JSON, Ophardt) each grew their own combined-pool detection, identity-resolution wiring, and ingest control flow. Most recently the combined-pool splitter bug (`memory: project_split_combined_pool_fix.md`) exposed that 5 of the 8 paths silently mishandled V-cat splitting — the worst kind of partial unification, because the code looked shared but wasn't.

The result: identity provenance lived in `tbl_match_candidate` (a workflow-state table, not a provenance table); ingest behavior diverged source-by-source; carry-over relied on `txt_code` prefix matching; URL→data correctness was unenforced; EVF was treated as primary source instead of a backup with parity verification.

Continuing to patch was no longer an option. The team chose a structured rebuild: drop `tbl_tournament` + `tbl_result` + `tbl_match_candidate` from LOCAL, re-ingest every event chronologically through one unified pipeline with per-event interactive admin review, then re-seed CERT and PROD from rebuilt LOCAL.

## Decision

The rebuild is structured as 9 phases (0.0a → 7), each gated by explicit deliverables and a risk-gate:

| Phase | Focus | Subplan |
|---|---|---|
| 0.0a | CI Node 24 upgrade (precondition for the rebuild lifetime) | [p0-0-ci-upgrade.md](../plans/rebuild/p0-0-ci-upgrade.md) |
| 0.0b | Plan decomposition (master + 9 subplans) | done in commit 5891bb5 |
| 0.5 | Spec refactor + RTM externalization | done in commit 12dd202 |
| 0 | Schema prep + cert_ref + rules + matcher config + Claude module edits | [p0-prep.md](../plans/rebuild/p0-prep.md) |
| 1 | IR + 7 parsers + Ophardt research spike | [p1-ir-parsers.md](../plans/rebuild/p1-ir-parsers.md) |
| 2 | Draft tables + dry-run loop | [p2-drafts.md](../plans/rebuild/p2-drafts.md) |
| 3 | Stages 1-7 + alias writeback + 3-way diff + interactive CLI | [p3-pipeline.md](../plans/rebuild/p3-pipeline.md) |
| 4 | Commit path + frozen snapshot + EVF parity + alias UI | [p4-commit-ui.md](../plans/rebuild/p4-commit-ui.md) |
| 5 | Operational rebuild — every event reviewed and committed | [p5-execute.md](../plans/rebuild/p5-execute.md) |
| 6 | Drop tbl_match_candidate + remove old UI + finalize + LOCAL→CERT→PROD | [p6-finalize.md](../plans/rebuild/p6-finalize.md) |
| 7 | Carry-over FK + 366-day cap + admin UI | [p7-carryover.md](../plans/rebuild/p7-carryover.md) |

### Architecture

8 source mouths feed a normalized intermediate representation (IR). Stages 1–11 are uniform across sources. The IR contract (see [p1-ir-parsers.md](../plans/rebuild/p1-ir-parsers.md)):

- `ParsedTournament` — date, weapon, gender, season_end_year, organizer hint, source kind, raw pool size, category hint, list of results.
- `ParsedResult` — name, country, birth year, place, raw age marker, source vcat hint, excluded flag, source row id.
- `MatchResult` gains `alternatives: list[Candidate]` so per-event diffs can render top-N candidates for ambiguous matches.

### Identity model

`tbl_match_candidate` (workflow-state table) is replaced with per-result provenance on `tbl_result`:

- `txt_scraped_name TEXT` — original name as scraped
- `num_match_confidence NUMERIC(5,2)` — fuzzy-match score at resolution time
- `enum_match_method` enum — one of `AUTO_MATCH | USER_CONFIRMED | AUTO_CREATED | BY_ESTIMATED`

Cross-event match memory: `tbl_fencer.json_name_aliases` is appended on every USER_CONFIRMED admin decision (alias write-back).

`tbl_match_candidate` stays present and unwritten (TEE behaviour during rebuild) until Phase 6, which drops the table after rewriting `supabase/tests/11_identity_resolution.sql` against the new model.

### Draft tables (Phase 2)

`tbl_tournament_draft` and `tbl_result_draft` mirror their live counterparts plus `txt_run_id TEXT`. Crash-consistent, transactional, resumable. RPCs `fn_commit_event_draft(p_run_id)` and `fn_discard_event_draft(p_run_id)` move drafts to live or discard them.

### Rules registry

R001–R012 (plus R005b) at [doc/rules/](../rules/) — Pandoc-built, per-rule markdown source-of-truth, single `rules.html` master. Rule files reference back to this ADR and to phase subplans.

### Matcher tuning

Single config file `python/matcher/config.yaml` — thresholds, Polish normalizations, nicknames map, diagnostic config. Hot-reloads between event runs in Phase 5.

### EVF role

EVF API is a **backup source** for EVF-organized events only. Post-commit parity gate (ADR-053) verifies POL count + placements + score within ±0.5; failures route to `enum_status = 'SCORED'` with notes in `tbl_event.txt_parity_notes`. Transitive trust: if the unified pipeline agrees with EVF API on EVF-organized events, the engine handles SPWS+FIE events correctly too.

### Frozen snapshot

`tbl_event.txt_source_status` enum (`LIVE_SOURCE | FROZEN_SNAPSHOT | NO_SOURCE`) — Phase 4 (ADR-051). `FROZEN_SNAPSHOT` events copy verbatim from `cert_ref` schema (a parallel read-only mirror of PROD loaded once at rebuild start by `scripts/load-cert-ref.sh`).

### Memory rule waiver

The "Never delete tournament/result/event rows without per-row approval" rule (per `memory/feedback_no_delete_without_asking.md`) is **waived for the rebuild lifetime only** — the rebuild explicitly drops `tbl_tournament` + `tbl_result` + `tbl_match_candidate` rows in bulk during Phase 5 commit operations. ADR-051 documents the waiver. Rule reactivates in Phase 6.

## Alternatives considered

### A. Continue patching the legacy pipeline source-by-source

Already attempted for ~6 months; produced the partial-unification bug class. Rejected.

### B. Rewrite in place without cert_ref / draft tables

Considered but rejected: cert_ref is the diff baseline against which Phase 5 reviews are evaluated. Without it, an operator reviewing a re-ingested event has no "what did this look like in PROD?" reference except a SQL dump file — fragile, not queryable.

### C. Run the new pipeline alongside the old one (strangler-fig at the source level)

Initial attractive option; rejected because the legacy pipeline's identity model (tbl_match_candidate) is fundamentally incompatible with per-result provenance on tbl_result. Running both at once creates two divergent provenance stories; the rebuild needs one.

### D. Defer the carry-over FK migration to part of this rebuild

Considered including ADR-054 cap enforcement + FK default flip in Phase 0–6. Rejected because:
- The rebuild scope is already large (9 phases, ~10 weeks);
- The FK engine is shipped and tested (ADR-042/045) — just not the default;
- Phase 7 can run cleanly post-rebuild against the now-consistent data without affecting the rebuild's exit gate.

## Consequences

**Positive:**
- Single ingest path for 8 sources — no source-specific divergence.
- Per-result provenance is queryable directly without a candidate-table join.
- 3-way diff (Source / cert_ref / draft) is a powerful operator tool for catching regressions and source drift.
- Rules registry is the canonical "what should the pipeline do" reference, separate from "how does the spec describe the system".
- Per-event interactive review surfaces low-confidence matches and source-of-truth choices to a human, not buried in cron logs.

**Negative:**
- Phase 5 may span weeks (~60 events × per-event review). Drafts persist via run_id; user can pause/resume.
- During the rebuild lifetime, `tbl_match_candidate` is a TEE write target — code maintenance overhead until Phase 6 drops it.
- The cert_ref schema lives in the same Postgres DB as `public.*` — accidental writes are blocked by GRANT but the surface area is larger.
- Cross-event alias drift: an incorrectly-confirmed alias propagates to future ingests via `json_name_aliases`. Mitigated by audit log + admin revocation CLI.

## Status — Phase 0 deliverables (committed 2026-05-01)

- ✅ Migration `supabase/migrations/20260501000001_phase0_schema_prep.sql`:
  - `enum_match_method` enum
  - `tbl_result.{txt_scraped_name, num_match_confidence, enum_match_method}` columns
  - `enum_source_status` enum + `tbl_event.txt_source_status` column
  - `fn_age_categories_batch(INT[], INT)` for the splitter
  - `fn_ingest_tournament_results` rewritten with TEE write to tbl_result + tbl_match_candidate
- ✅ Migration `supabase/migrations/20260501000002_cert_ref_schema.sql` — read-only `cert_ref.{tbl_fencer, tbl_event, tbl_tournament, tbl_result}` scaffold
- ✅ `scripts/load-cert-ref.sh` — populates cert_ref from public; verified against current LOCAL (329/84/756/2655 rows)
- ✅ `python/matcher/config.yaml` — thresholds + Polish folding + nicknames
- ✅ `python/pipeline/export_seed.py` — `tbl_match_candidate` export removed
- ✅ `doc/rules/` framework — Makefile + README + R001-R012 seed files
- ✅ Claude-guidance modules aligned (commit 6250f04) — REBUILD WAIVER / REBUILD-NEW markers; `tbl_match_candidate` removal noted
- ✅ pgTAP 404/404 green; pytest 360/363 (1 pre-existing data-drift, see commit body); vitest 332/332 green
