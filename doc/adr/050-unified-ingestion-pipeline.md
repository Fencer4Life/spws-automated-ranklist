# ADR-050: Unified Ingestion Pipeline (rebuild — Phases 0–6)

**Status:** Accepted; rebuild active. Phase 0 schema-prep + cert_ref scaffolding committed 2026-05-01. Phases 1–6 land on `main` over the rebuild lifetime; this ADR is a stub that gets fleshed out as each phase commits.

**Date:** 2026-05-01

**Supersedes:** ADR-024 (Combined Category Splitting), ADR-025 (Event-Centric Ingestion + Telegram Admin — **narrowed by ADR-077 (2026-06-28) to the *ingestion mechanism* only; ADR-025's event-status lifecycle + Telegram admin surface live on, carried forward by ADR-077**), ADR-039 (EVF Scraper Dedup + Stale-Event Gate), ADR-049 (Joint-Pool Split Flag).
**Amended by:** ADR-052 (URL→data validation), ADR-053 (EVF backup-source + parity gate + EVF_PUBLISHED promotion), ADR-054 (Carry-over FK + 366-day cap), ADR-055 (Ingest traceability — parser-kind enum + cap-6 history tables).
**Superseded concepts:** Frozen-snapshot status was retired 2026-05-02 — cert_ref fallback became just-another-parser through the standard pipeline; no special status needed. ADR-051 was reserved for that policy and is now empty.

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
| 1 | IR + 8 parsers (7 existing + Ophardt server-rendered HTML, per spike outcome [doc/audits/ophardt_format_research.md](../audits/ophardt_format_research.md)) | [p1-ir-parsers.md](../plans/rebuild/p1-ir-parsers.md) |
| 2 | Draft tables + dry-run loop | [p2-drafts.md](../plans/rebuild/p2-drafts.md) |
| 3 | Stages 1-7 + alias writeback + 3-way diff + interactive CLI | [p3-pipeline.md](../plans/rebuild/p3-pipeline.md) |
| 4 | Commit path + EVF parity + alias UI | [p4-commit-ui.md](../plans/rebuild/p4-commit-ui.md) |
| 5 | Operational rebuild — every event reviewed and committed | [p5-execute.md](../plans/rebuild/p5-execute.md) |
| 6 | Drop tbl_match_candidate + remove old UI + finalize + LOCAL→CERT→PROD | [p6-finalize.md](../plans/rebuild/p6-finalize.md) |
| 7 | Carry-over FK + 366-day cap + admin UI | [p7-carryover.md](../plans/rebuild/p7-carryover.md) |

### Architecture

8 source mouths feed a normalized intermediate representation (IR). Stages 1–11 are uniform across sources. The IR contract (see [p1-ir-parsers.md](../plans/rebuild/p1-ir-parsers.md)):

**Stage 0 — roster reconciliation (added 2026-06-13, ADR-056 rev).** A new
FIRST stage `s0_reconcile_roster` runs *before* `s1_validate_ir` (and therefore
before the matcher). For every result row it (1) creates genuinely-new
participants by a HIGH-PRECISION exact check (so the matcher exact-matches them
instead of fuzzy-gluing them to the nearest existing name) with an estimated
band-midpoint birth year (NULL when the V-cat is unmarked), and (2) corrects a
matched fencer's stored birth year when it conflicts with the bracket's
authoritative V-cat (estimated kept; CONFIRMED downgraded, surfaced loudly).
International events (PEW/MEW/MSW, ADR-038) are skipped. It never halts and is
idempotent. See ADR-056 (2026-06-13 revision) for the full rule + midpoint
table. The full stage tuple is now:
`s0_reconcile_roster → s1_validate_ir → s2_resolve_event → s3_detect_combined_pool
→ s4_split_via_batch → s5_detect_joint_pool → s6_resolve_identity → s7_validate
→ s7_pool_round_check → s7_split_by_vcat`.

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

### Cert_ref fallback as a parser

When operator picks `[5]` in the review CLI (no live URL available), cert_ref placements are produced as a `ParsedTournament` IR via a small parser module and fed through the standard Stages 1-11 pipeline. The engine still computes points; no special status is recorded. Stage 7 (URL→data validation) is skipped for this path because there is no URL to validate.

### Status enum (Phase 4 — see ADR-053)

`tbl_event.txt_source_status` carries two values: `ENGINE_COMPUTED` (engine output, default for every event regardless of organizer) and `EVF_PUBLISHED` (EVF-organized events whose engine output passed the parity gate and was overwritten with EVF's authoritative published numbers). DB-level CHECK constraint enforces `EVF_PUBLISHED` is only valid for `txt_organizer = 'EVF'`.

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

## Status — Phase 1 deliverables (committed 2026-05-01)

Phase 1 ships the **traceability schema** (ADR-055) and the **intermediate representation + 8 parsers + parser registry**. 7 commits land between `4409f95` and `6ae21c0` on `main`.

- ✅ Migration `supabase/migrations/20260501000003_phase1_ingest_traceability.sql` (ADR-055):
  - `enum_parser_kind` Postgres enum (8 values, mirrors Python `SourceKind`)
  - Stamp columns on `tbl_event` + `tbl_tournament`: `enum_parser_kind`, `dt_last_scraped`, `txt_source_url_used`
  - History tables `tbl_event_ingest_history` + `tbl_tournament_ingest_history` with FK CASCADE, UNIQUE(parent, run_id), `BEFORE INSERT` cap-of-6 trigger
  - 23 pgTAP assertions in `supabase/tests/26_ingest_traceability.sql`
- ✅ `python/pipeline/ir.py`: `SourceKind`, `ParsedResult`, `ParsedTournament`, `make_synthetic_id()`. Cross-language enum sync test verifies Python ↔ Postgres alignment at runtime.
- ✅ All 8 parsers conform to the IR via `parse_*()` factories (see [p1-ir-parsers.md](../plans/rebuild/p1-ir-parsers.md) for the per-parser table). Native IDs where available (FencingTime XML, FTL JSON, Ophardt); `make_synthetic_id()` for the rest.
- ✅ `python/scrapers/__init__.py` `PARSERS` dict — single source of truth mapping each `SourceKind` to its canonical parser; pytest contract guards completeness.
- ✅ Ophardt parser written from scratch + spike-captured fixture (Munich 2024 EVF Circuit Memoriam Max Geuter, Foil Men's O50). Server-rendered HTML, no Playwright dep needed.
- ✅ Test totals: pgTAP 404 → 427 (+23 ADR-055); pytest 354 → 402 (+7 IR contract + 41 parser contracts); vitest 332 unchanged.
- ✅ Coherence + spec-sync gates pass.

## Status — Phase 2 deliverables (committed 2026-05-02)

Phase 2 ships the **draft scratch state + dry-run loop** — the infrastructure that Phase 3 will populate via the IR pipeline and Phase 4 will commit through.

**Locked design decisions** (5-question micro-RFC, conversation 2026-05-01):

| # | Decision | Rationale |
|---|---|---|
| D1 | `--dry-run` = no DB writes anywhere | Cleaner than rollback-then-discard. `fn_dry_run_event_draft` is a stateless validator/counter; Python computes diff from in-memory IR. |
| D2 | RPCs return JSONB; never throw on missing run_id | CLI inspects counts; zero-count routes to Telegram via `notifier.warning()` + exit code 1. Successes go to stdout only. |
| D3 | Tournament-level diff + match-method aggregate | Per-fencer detail and 3-way diff against live = Phase 3 (kept the boundary clean). |
| D4 | `20260501000004_phase2_draft_tables.sql` | Today's date + next slot; future phases drift to commit date if past the week. |
| D5 | Extend `DbConnector` (Supabase REST) | All txn boundaries inside SQL functions. **No psycopg2 at runtime.** |

**Shipped:**

- ✅ Migration `supabase/migrations/20260501000004_phase2_draft_tables.sql`:
  - `tbl_tournament_draft` (22 cols, draft-local PK + 20 mirror cols + `txt_run_id UUID`) + index on `txt_run_id`
  - `tbl_result_draft` (17 cols, draft-local PK + `id_tournament_draft` linkage + 13 mirror cols + `txt_run_id UUID`) + index on `txt_run_id`
  - **Loose**: zero FK constraints (drafts may stage unresolved values)
  - `fn_commit_event_draft(UUID) RETURNS JSONB` — atomic move via CTE chain (`txt_code` → live id mapping), sets `bool_joint_pool_split` on siblings sharing `url_results`, appends `tbl_*_ingest_history` (Phase 1 ADR-055), writes audit, deletes drafts
  - `fn_discard_event_draft(UUID) RETURNS JSONB` — deletes drafts, writes `DRAFT_DISCARD` audit always
  - `fn_dry_run_event_draft(JSONB) RETURNS JSONB` — pure function; counts + joint-pool sibling group detection from IR payload; no writes
  - 30 pgTAP assertions in `supabase/tests/27_draft_tables.sql`
- ✅ `python/pipeline/draft_store.py` — `DraftStore` wraps the supabase REST client. Methods: `write_tournament_drafts`, `write_result_drafts`, `read_drafts`, `list_drafts`, `commit`, `discard`, `dry_run`. 9 pytest assertions.
- ✅ `python/pipeline/draft_diff.py` — `format_diff(run_id, payload, rpc_result, event_match)`. Renders title, event match, would-create counts, per-tournament table, match-method aggregate. 5 pytest assertions.
- ✅ Extended `python/pipeline/ingest_cli.py` with 4 mutually-exclusive draft-management flags: `--commit-draft <UUID>`, `--discard-draft <UUID>`, `--list-drafts`, `--resume-run-id <UUID>`. Zero-count outcomes route to `notifier.warning()` + exit 1. 6 pytest assertions.
- ✅ Test totals: pgTAP 427 → 457 (+30); pytest 402 → 422 (+9 draft_store + 5 draft_diff + 6 CLI mgmt, excl. pre-existing `test_prod_mirror` CI skip); vitest 332 unchanged.
- ✅ Coherence + spec-sync gates pass.

**Deviations from plan text** (documented in migration header):

1. Plan said `LIKE tbl_tournament INCLUDING ALL`; reality uses **explicit DDL**. Reason: `LIKE INCLUDING ALL` would inherit the SERIAL sequence and collide draft inserts with live PK allocation. Explicit DDL gives drafts their own `id_tournament_draft` sequence and renames the linkage column on `tbl_result_draft` for clarity.
2. Plan said `txt_run_id TEXT NOT NULL`; reality uses **`UUID NOT NULL`** to match what Phase 1 already shipped on `tbl_*_ingest_history.txt_run_id`. The `txt_` prefix on a UUID column is a name/type mismatch inherited from Phase 1.
3. `--dry-run` orchestrator integration is **deferred to Phase 3** — Phase 2 keeps the existing path-based `--dry-run` (calls `process_xml_file(dry_run=True)`); the IR-driven dry-run that builds a JSONB payload from the new parsers and invokes `fn_dry_run_event_draft` lands in Phase 3 alongside the orchestrator rewrite. The Phase 2 risk gate is satisfied by `--resume-run-id` (re-renders diff from existing drafts) and `format_diff` proven via tests.

## Status — Phase 3 deliverables (committed 2026-05-02)

Phase 3 ships the **unified pipeline body** — Stages 1-7, the override system, the alias-writeback RPC, the 3-way diff verifier, and the interactive review CLI that operators use during the Phase 5 rebuild.

**Locked design decisions** (5-question micro-RFC, conversation 2026-05-02):

| Q | Decision | Rationale |
|---|---|---|
| Q1 | Override YAML — 5 surfaces (identity, splitter, URL, match-method, joint-pool); EVF V0 ack omitted | V0+EVF = data corruption per R005b — fix upstream, no override. |
| Q2 | Procedural pipeline + `PipelineContext` dataclass; halt-by-exception | Lower ceremony than class-based; matches existing `process_xml_file` style; cleaner unit tests. |
| Q3 | Keep `process_xml_file` untouched + deprecation note | Phase 6 deletes it; "shim" framing wrong — back-compat is just "don't touch." |
| Q4 | Separate `python/pipeline/review_cli.py` module | Own arg surface; zero breakage to ingest_cli. |
| Q5 | 3-way diff in pure Python | One-language end-to-end; SQL JOIN performance moot at event scale. |

**Shipped (10 modules, 91 new tests):**

- ✅ `python/pipeline/types.py` — `HaltError` + `HaltReason` enum + `Overrides` (5 sub-classes) + `PipelineContext` + `StageMatchResult`. 8 pytest assertions (P3.T1-P3.T8).
- ✅ `python/pipeline/overrides.py` — YAML parser for the 5 override surfaces, jsonschema-style validation, `OverrideValidationError` with file path. PyYAML promoted to runtime dep. 15 pytest assertions (P3.OV1-P3.OV15).
- ✅ Migration `supabase/migrations/20260502000001_phase3_fn_alias_writeback.sql` — `fn_update_fencer_aliases(INT, TEXT) RETURNS JSONB` with NULL→array init, case-insensitive dedup, whitespace trim, empty-rejection. 8 pgTAP assertions in `supabase/tests/28_alias_writeback.sql`.
- ✅ `python/pipeline/stages.py` — 7 stage functions S1-S7 with halt-by-exception and override application. 29 pytest assertions in `test_pipeline_stages.py` (per-stage isolation + dispatcher tests).
- ✅ Updated `python/pipeline/orchestrator.py` — added `run_pipeline()` dispatcher resolving stages by name (so monkeypatch tests work); legacy `process_xml_file` annotated with deprecation note pointing to `run_pipeline`.
- ✅ Extended `python/pipeline/db_connector.py` — `find_event_by_code()`, `fetch_cert_rows_for_event()` (Phase 3 stub), `call_age_categories_batch()` (Stage 4 batch RPC wrapper).
- ✅ `python/pipeline/three_way_diff.py` — 4-bucket classifier (`classify`, `build_diff`), 7-bin confidence histogram, markdown renderer, `write_diff` to `doc/staging/<event_code>.diff.md`. Bucket semantics per `project_cert_prod_not_baseline.md` (CERT is reference-only, not baseline). 12 pytest assertions in `test_three_way_diff.py`.
- ✅ `python/pipeline/review_cli.py` — `ReviewSession` with injectable prompt + output (testable without stdin). 4 source-of-truth choices (recorded URL / paste URL / paste path / EVF API; cert_ref fallback parser added Phase 4). Lifecycle: event summary → choice → fetch → run_iteration (overrides hot-reloaded each iteration) → diff → action prompt → commit/discard/iterate. 15 pytest assertions in `test_review_cli.py` (incl. EVF API path per `project_evf_predominance.md` — EVF events are predominant, source-of-truth on EVF site).
- ✅ End-to-end integration tests in `python/tests/test_pipeline_integration.py` — 4 tests against live LOCAL Supabase (skip cleanly when unreachable, matching the established pattern).
- ✅ Test totals: pgTAP 457 → 465 (+8); pytest 422 → 505 (+83 across 6 new test modules); vitest 332 unchanged.
- ✅ Coherence + spec-sync gates pass.

**Deferred to Phase 4 (per master plan boundaries, not time pressure):**

1. **Cert_ref fallback parser** — produces `ParsedTournament` IR from `cert_ref.tbl_*` rows; integrated as 9th parser in the registry. No special pipeline branch; engine still runs.
2. **Production fetcher wiring** — `Fetcher` raises `NotImplementedError` for `fetch_url`/`fetch_path`/`fetch_evf_api`; tests inject mocks. Phase 4 wires the existing 8 scrapers to the Fetcher methods.
3. **`fetch_cert_rows_for_event` real query** — Phase 3 stub returns `[]`; Phase 4 implements when cert_ref is operationally populated.
4. **EVF parity gate** (R011) — Phase 4 ADR-053.
5. **URL→data deep validation** (R009/ADR-052) — Phase 4.

**Domain corrections captured during Phase 3 design (saved as project memories):**

- `project_cert_prod_not_baseline.md` — CERT/PROD share LOCAL's drift; reference only, not trust source.
- `project_evf_predominance.md` — EVF events outnumber SPWS; SPWS quality is critical; EVF errors recoverable via EVF API.
- `project_evf_eligibility_v1plus.md` — EVF requires age 40+; V0 in EVF data = corruption, hard halt.
- `feedback_be_the_architect.md` — User delegated all technical decisions; ask only about domain-specific requirements.

## Status — Phase 5.5 deliverables (in progress 2026-05-03)

Phase 5.5 closes the remaining gaps preventing CERT-only operation:

1. **Legacy `process_xml_file` direct-write retired** — rewritten as a thin shim over `run_pipeline` + DraftStore so email-arrived XML produces drafts identical to manual `phase5_runner`. The "LEGACY" comment block in [orchestrator.py](../../python/pipeline/orchestrator.py) is removed. *(Pending implementation; plan-test-ID 5.7.)*

2. **Verdict `.md` persisted to Supabase Storage** — new bucket `staging-reports` with per-event subfolder structure (`{event_code}/full.md` replace-on-regen + `{event_code}/deltas/{ts}.md` append-only). Backed by new modules `python/pipeline/storage_md.py` + `python/pipeline/md_writer.py`. ADR-058. Plan-test-IDs 5.5, 5.6, 5.12.

3. **Telegram document delivery** — `TelegramNotifier.send_document` extends [notifications.py](../../python/pipeline/notifications.py) with multipart/form-data POST to Bot API `sendDocument`. Higher-level `send_staging_report(kind='full'|'delta', extras=...)` wraps with structured caption. ADR-059. Plan-test-ID 5.9.

4. **EVF parity sweep emits delta-only `.md`** — `python/pipeline/parity_delta.py` renders before→after diff tables; never overwrites `full.md` from sweep. ADR-060. Plan-test-ID 5.8.

5. **LOCAL parity preserved** — all new infra gated to CERT/PROD via `--md-target` CLI flag (default `local`) and `VITE_DEPLOY_ENV` env switch. LOCAL operator continues today's filesystem + shell-rerun habit unchanged. ADR-061.

6. **Alias triage UX overhaul** — FencerAliasManager sorts unreviewed-aliases-first with amber highlight; modal-based "Create new fencer" replaces window.prompt chain; cascade tournament list surfaced post-mutation via extended RPC return shape (`id_tournaments[]` + `tournament_labels[]`). Migrations `20260503000001` + `20260503000002`. Plan-test-IDs 5.1–5.4 (vitest, pending), 5.10, 5.11.

7. **CERT command surface via Telegram** — 4 new GAS commands `/regen`, `/stage`, `/parity`, `/verdict` + extended `/help`. Edge-fn `dispatch-workflow` allowlist gains `phase5-event-runner.yml` + `regen-report.yml`. ADR-061. *(GAS extension pending.)*

**Shipped 2026-05-03 (this date):**

- ✅ Migrations `supabase/migrations/20260503000001_phase5_alias_view_with_context.sql` (+8 pgTAP), `20260503000002_phase5_alias_rpcs_return_tournaments.sql` (+8), `20260503000003_phase5_staging_reports_bucket.sql` (+5; LOCAL skips when storage disabled).
- ✅ pgTAP suites `35_alias_view_context.sql`, `36_alias_rpcs_return_tournaments.sql`, `37_staging_reports_bucket_rls.sql` — all green on LOCAL.
- ✅ Python modules `storage_md.py`, `md_writer.py`, `parity_delta.py` — all GREEN (24 new pytest assertions).
- ✅ `TelegramNotifier.send_document` + `send_staging_report` extension — GREEN (6 new pytest assertions).
- ✅ GH workflows `.github/workflows/regen-report.yml` + `.github/workflows/phase5-event-runner.yml` (security-hardened: env vars throughout, regex-validated event_code).
- ✅ `supabase/functions/dispatch-workflow/index.ts` ALLOWED_WORKFLOWS extended (2 → 4 entries).
- ✅ Test totals: pgTAP 508 → 543 (+35); pytest +30 (24 new + 6 Telegram); vitest unchanged (pending).
- ✅ ADRs 058/059/060/061 written with `Status: Proposed`.
- ✅ `doc/claude/planning.md` written and referenced from CLAUDE.md (canonicalises planning rules).

**Pending (next sessions):**

- Frontend alias UI (Workstream 4): CreateFencerFromAliasModal.svelte, FencerAliasManager.svelte sort/highlight/auto-expand, cascade banner in App.svelte.
- `process_xml_file` rewrite (Workstream 2): the biggest refactor; plan-test-ID 5.7 will assert email path now produces drafts (not direct writes).
- `phase5_runner` / `phase5_report` CLI extensions: `--md-target` + `--send-telegram` flags wired into the existing inline `Path.write_text()` paths.
- `evf_parity_sweep.py` wiring: build ParityChange list → call `parity_delta.render` → upload + Telegram.
- GAS Telegram commands + `/help` rewrite.
- Ops manual update + LOCAL/CERT smoke runs.
