# Memory Disposition Matrix — Phase 0 review (2026-05-01)

Per-file disposition for `/Users/aleks/.claude/projects/-Users-aleks-coding-SPWSranklist/memory/` ahead of the rebuild lifetime. Codes:

- **KEEP** — stays as-is; rule/fact still load-bearing.
- **UPDATE-PHASE-N** — file needs revision when Phase N lands.
- **DELETED** — file removed; concept retired or rule will be reintroduced post-rebuild.
- **DELETE-IN-PHASE-6** — file is rebuild-historical; superseded after promotion.

Phase 6 will rerun this audit to confirm dispositions still apply.

## Index files

| File | Disposition | Note |
|---|---|---|
| MEMORY.md | UPDATE-AS-PHASES-LAND | ADR registry already pointer-ized in Phase 0.5; remaining sections need touch-ups when project memory below transitions |

## Project memory (`project_*`)

| File | Disposition | Note |
|---|---|---|
| project_carryover_366day_cap.md | UPDATE-PHASE-7 | Cap enforcement lands then; entry should flip from "default-only" to "enforced" |
| project_carryover_admin_runbook.md | UPDATE-PHASE-7 | Phase 3a/b/c admin UI supersedes most of the SQL runbook; keep as historical ref |
| project_carryover_phase1_status.md | KEEP | Historical state; useful baseline for Phase 7 verification |
| project_carryover_phase23_roadmap.md | UPDATE-AS-PHASES-LAND | Phase 3 backend already shipped; mark Phase 3b/3c as rebuild-merged when UI lands |
| project_dmew_imew_alternation.md | KEEP | Rule reference; cited by R008 |
| project_event_status_flow.md | KEEP | Rule reference; cited across rebuild |
| project_evf_refix_in_progress.md | UPDATE-AS-PHASES-LAND → DELETE-IN-PHASE-6 | Goal 1 done; Goals 2/3/4 absorbed into the unified pipeline. Delete when all four goals are obsolete |
| project_imew_biennial.md | KEEP | Rule reference; cited by R007/R008 |
| project_joint_pool_done.md | KEEP | Shipped feature; baseline for R002 |
| project_local_rebuild_2026-04-28.md | KEEP | Historical state; pre-Phase-0 starting point |
| project_phase3_status.md | UPDATE-PHASE-7 | Carry-over Phase 3 admin UI work folded into rebuild Phase 7 |
| project_ppw1_2025_2026_no_url.md | KEEP | Data fact; informs Phase 5 audit (PPW1 V-cats deliberately have NULL url_results) |
| project_split_combined_pool_fix.md | UPDATE-PHASE-3 → DELETE-IN-PHASE-6 | Bug class is what triggered the rebuild; the rebuild solves it. Delete when Phase 6 promotes |

## Feedback rules (`feedback_*`)

All KEEP unless noted — these are user-feedback rules that survive the rebuild.

| File | Disposition | Note |
|---|---|---|
| feedback_admin_link.md | KEEP | |
| feedback_admin_url.md | KEEP | |
| feedback_always_document.md | KEEP | Process rule |
| feedback_coherence_check.md | KEEP | Process rule |
| feedback_db_reset.md | KEEP | Always use scripts/reset-dev.sh |
| feedback_fencer_ppw_mpw_only.md | KEEP | |
| feedback_international_no_pending.md | UPDATE-PHASE-6 | "PENDING" goes away in new identity model — rule still holds (low-confidence international = skip) but framing needs the AUTO_MATCH/USER_CONFIRMED vocab |
| feedback_lang_toggle.md | KEEP | |
| ~~feedback_no_delete_without_asking.md~~ | **DELETED** | Removed 2026-05-02 at Phase 4 start; will be reintroduced post-rebuild in revised form. The Phase 4 alias-UI Discard operation handles result-row deletion with per-row preview, satisfying the rule's spirit during the rebuild. |
| feedback_no_layer_shorthand.md | KEEP | |
| feedback_no_xls_scan.md | KEEP | |
| feedback_season_create_form_top.md | KEEP | |
| feedback_telegram_not_discord.md | KEEP | |
| feedback_ui_debug_no_console.md | KEEP | |
| feedback_urls_admin_managed.md | KEEP | |
| feedback_user_calls_the_shots.md | KEEP | |
| feedback_validate_url_writes.md | KEEP | R009 implements this; rule is enforced post-rebuild |
| feedback_view_rebuild_on_tbl_event.md | KEEP | Phase 0 schema-prep migration follows this rule (rebuilt vw_calendar after adding txt_source_status) |

## Reference / domain memory

| File | Disposition | Note |
|---|---|---|
| cert-prod-environments.md | KEEP | |
| evf-api-conventions.md | KEEP | EVF API still backup source post-rebuild (ADR-053) |
| frontend-patterns.md | KEEP | |
| identity-resolution.md | UPDATE-PHASE-6 | Patterns reflect old tbl_match_candidate model; rewrite for tbl_result-provenance + alias write-back |
| local-admin-account.md | KEEP | |
| seed-data-layout.md | UPDATE-PHASE-6 | Layout extends with Phase 0 provenance columns + cert_ref schema; verify post-rebuild seed export still matches |
| t04-completion-status.md | KEEP | Historical |
| technical-patterns.md | UPDATE-PHASE-6 | New patterns added: draft tables, alias write-back, 3-way diff, provenance-on-tbl_result |
| v1-seed-data-task.md | KEEP | Historical |

## Action items

- **Phase 0 (2026-05-01):** waiver on `feedback_no_delete_without_asking.md` was originally documented in conventions.md.
- **Phase 4 start (2026-05-02):** rule deleted entirely. Architectural simplifications (cert_ref-as-parser instead of FROZEN_SNAPSHOT bypass; alias UI's per-row preview Discard) made the formal waiver unnecessary. Will be reintroduced post-rebuild in revised form.
- **Phase 3:** update `project_split_combined_pool_fix.md` with rebuild context as the unified splitter lands.
- **Phase 6:** rerun this audit; execute UPDATE-PHASE-6 / DELETE-IN-PHASE-6 dispositions; remove rebuild markers from conventions.md.
- **Phase 7:** update carry-over project memory files with cap-enforcement/FK-default-flip outcomes.
