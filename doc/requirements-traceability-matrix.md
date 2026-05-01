# Requirements Traceability Matrix (RTM)

*Externalized from Project Specification Appendix C in Phase 0.5 (2026-05-01). The spec retains Appendix C as the Architecture Decision registry only.*

Every functional and non-functional requirement is listed below with its source section and verifying test(s). Test IDs reference the development plan test numbering; test files are in `supabase/tests/`, `python/tests/`, and `frontend/tests/`.

For ADR-to-FR cross-references, see Project Specification Appendix C — Architecture Decisions.

## Functional Requirements

| ID | Requirement | Source | Tests | Status |
|----|-------------|--------|-------|--------|
| FR-01 | Scrape results from FTL (JSON + CSV), Engarde (HTML), 4Fence (HTML) | UC1(a) | 3.1a–g, 3.2a–f, 3.3a–e | Covered |
| FR-02 | Import results via CSV upload | UC2(a,b) | 3.7 | Covered |
| FR-03 | Auto-detect scraper platform from URL | UC1(a) | 3.1–3.3 URL dispatcher tests | Covered |
| FR-04 | Fuzzy match scraped names to master fencer list | UC3(a–f) | 4.1–4.5 | Covered |
| FR-05 | Alias matching (json_name_aliases) | UC3(a,b) | 4.2 (alias tests) | Covered |
| FR-06 | Duplicate name disambiguation via age category | §8.5(5) | 4.25–4.37 | Covered |
| FR-07 | Admin approve / dismiss / create-new-fencer for match candidates | UC4(b,c) | 4.6–4.8, 11.13–11.16 | Covered |
| FR-08 | Domestic intake: auto-create fencer for UNMATCHED PPW/MPW | §8.5 | 4.10–4.14b, 9.142–9.148 | Covered |
| FR-09 | International intake: skip UNMATCHED PEW/MEW fencers | §8.5 | 4.15–4.18 | Covered |
| FR-10 | Birth year estimation (youngest boundary per category) | §8.5 | 4.19–4.21, 9.83–9.84 | Covered (M9, T9.9) |
| FR-11 | Score computation: place points (log formula) | §8.1.1 | 2.1–2.3, 2.2a–b | Covered |
| FR-12 | Score computation: DE round bonus | §8.1.2 | 2.4–2.5 | Covered |
| FR-13 | Score computation: podium bonus | §8.1.3 | 2.6a–d | Covered |
| FR-14 | Tournament multipliers (PPW, MPW, PEW, MEW, MSW, PSW) | §8.2 | 2.7, 2.19, 9.85 | Covered (M9, T9.9) |
| FR-15 | PPW ranking: best-K domestic + always-include MPW; `p_rolling` parameter for active-season carry-over (ADR-018) | §8.3.1 | 5.2–5.13, 5.16, 5.20–5.21, 5.23, R.4–R.12 | Modified (M10, rolling parameter) |
| FR-16 | Kadra ranking: domestic + best-J international pool; `p_rolling` parameter for active-season carry-over (ADR-018) | §8.3.2 | 5.17, 5.19, 5.22, R.13–R.14 | Modified (M10, rolling parameter) |
| FR-17 | V0 guard: no Kadra ranking for V0 | §8.3.2 | 5.18 | Covered |
| FR-18 | Cross-category carryover (fencer ranked by birth-year category) | §8.5(2) | 5.14–5.15 | Covered |
| FR-19 | JSONB bucket-based ranking rules | §8.6.6 | 5.4–5.7, 5.20–5.22 | Covered |
| FR-20 | Legacy code path (NULL json_ranking_rules) | §8.6.6 | 5.23 | Covered |
| FR-21 | Season lifecycle: create season, auto-create scoring config (inherits json_ranking_rules from previous season), auto-activate by date (ADR-031) | UC7(a,b) | 1.13–1.14b, 9.40–9.46 | Covered |
| FR-22 | Single active season constraint (auto-derived, no overlapping dates) | UC7(c) | 1.7, 1.15, 9.41–9.46 | Covered |
| FR-23 | Event lifecycle state machine | UC10(a,b) | 1.20–1.24, 9.86–9.90 | Covered (M9, T9.9) |
| FR-24 | Audit logging for status changes | UC10(c) | 1.22a–b | Covered |
| FR-25 | Tournament multiplier auto-population (trigger) | UC9(c) | 1.19, 1.19c | Covered |
| FR-26 | Scoring config export/import (JSON) | UC18, UC19 | 2.12–2.18 | Covered |
| FR-27 | Calibration comparison against reference Excel | UC20 | 2.19–2.23 (pytest) | Covered |
| FR-28 | Minimum participant threshold (configurable per type) | §8.5(1) | 3.10–3.11 | Covered |
| FR-29 | Idempotent re-import (skip existing results) | §9.5.1 | 3.9 | Covered |
| FR-30 | Retry on transient network failure | §9.5.1 | 3.12 | Covered |
| FR-31 | Partial scrape detection (abort on incomplete data) | §9.5.1 | 3.13, 3.13b | Covered |
| FR-32 | Telegram alerting on pipeline failure | UC1(d) | 3.6 | Covered |
| FR-33 | Web Component: weapon/gender/category filters | UC12(b) | FilterBar.test.ts (5 tests) | Covered |
| FR-34 | Web Component: PPW/Kadra toggle with V0 guard (conditional on `bool_show_evf_toggle` season config, ADR-017) | UC12(b) | FilterBar.test.ts, DrilldownModal.test.ts | Modified (toggle hidden by default, visible when season config enables it) |
| FR-35 | Web Component: ranking table with mode-specific columns | UC12(c) | RanklistTable.test.ts (5 tests) | Covered |
| FR-36 | Web Component: fencer drilldown modal with score breakdown | UC13(a,b) | DrilldownModal.test.ts (24 tests) | Covered |
| FR-37 | ODS export (ranking + drilldown) | UC12, UC13 | export.test.ts (5 tests) | Covered |
| FR-38 | API client: fetch seasons, rankings, fencer scores | UC12(a) | 5.1a–b, api.test.ts (6 tests) | Covered |
| FR-39 | EN/PL internationalisation with reactive toggle | §11 | DrilldownModal.test.ts (test K) | Covered |
| FR-40 | Import status transitions (PLANNED → IMPORTED → SCORED) | UC1(b), UC5(c) | 2.9, 9.91–9.92 | Covered (M9, T9.9) |
| FR-41 | Domestic-participation requirement: fencers with 0 domestic points excluded from ranking views | §8.5(7) | 5.24–5.25 | Covered |
| FR-42 | CERT/PROD environment toggle with runtime switching | §2.2 | 8.01–8.04 | Covered (M8) |
| FR-43 | Calendar view: chronological event list with season filter | UC21(a,b) | 8.11–8.19, 8.38–8.43, 8.47 | Covered (M8) |
| FR-44 | Calendar view: past/future/all toggle (scope filter conditional on `bool_show_evf_toggle`, ADR-017) | UC21(c) | 8.44–8.45, 8.79–8.80 | Modified (M8, scope filter hidden by default) |
| FR-45 | Calendar view: mobile-friendly layout | UC21(e) | 8.46 | Covered (M8) |
| FR-46 | Admin authentication: Supabase Auth + TOTP MFA (supersedes client-side password gate) | UC22(a), ADR-016 | 9.01–9.17 | Covered (M9, T9.0) |
| FR-47 | Season CRUD via web UI | UC22(b) | 9.18–9.22, 9.27, 9.37–9.42 | Covered (M9, T9.1 SQL + T9.2 UI) |
| FR-48 | tbl_event schema extension: 12 columns (txt_country, txt_venue_address, url_invitation, num_entry_fee, txt_entry_fee_currency, arr_weapons, url_registration, dt_registration_deadline, url_event_2, url_event_3, url_event_4, url_event_5) | UC22(c), UC21(d), ADR-030, ADR-040 | 8.05–8.10, 8.18–8.20, 15.1 | Covered (M8+M9+ADR-030+ADR-040) |
| FR-49 | Tournament CRUD nested under events | UC22(d) | 9.25–9.26, 9.29, 9.50–9.55 | Covered (M9, T9.1 SQL + T9.4 UI) |
| FR-50 | Delete cascade (event → tournaments → results) | UC22(e) | 9.30–9.36 | Covered (M9, T9.1) |
| FR-51 | Tournament re-import in single transaction | UC23(a-f) | 10.1–10.7 | Covered (ADR-022, fn_ingest_tournament_results) |
| FR-52 | Multi-category expansion (30 sub-rankings) | §6.2 | 8.20–8.26 | Covered (M8) |
| FR-53 | Event-level batch import: multi-select tournament checklist modal | UC22(g) | 9.62–9.67 | Partial (file UI + Admin ⬇ button + populate-urls GHA) |
| FR-54 | Tournament-level single import: own URL or file upload (FTL / Engarde / 4fence / Dartagnan) | UC22(h) | 9.56–9.61, 3.17a–d, dart.1–dart.8, dart.url.1 | Partial (file UI + Admin ⬇ button + t-scrape + scrape-tournament GHA + Dartagnan parser) |
| FR-55 | File import: parse results from .xlsx, .xls, .json, .csv | UC22(i), UC23(c) | 9.58, 9.93–9.100 | Covered (M9, T9.5 UI + T9.10 parsers) |
| FR-56 | Identity resolution admin UI: match candidate queue with approve/dismiss/create-new/assign + gender column; Identities tab in Fencers view (ADR-035) | UC4(a-e) | 9.68–9.73, 9.77, 9.78–9.88, 11.1–11.19 | Covered (UI + RPCs + tab in App.svelte) |
| FR-57 | Identity resolution: disambiguation modal for same-name fencers with age category fit | UC3(f), UC4(b) | 9.74–9.76 | Covered (DisambiguationModal + App.svelte handlers) |
| FR-58 | EVF calendar import: HTML-primary fetch from veteransfencing.eu with JSON-API cross-reference, event-level URL harvesting (`url_event`, `url_invitation`, `url_registration`), dedup, create events via `fn_import_evf_events_v2` (allocator-driven code, EVF organizer, FK auto-link, idempotent), refresh existing events via `fn_refresh_evf_event_urls` (NULL-only, protects admin edits), raise on total failure. Deadline harvesting disabled pending real-world pattern data. Dedup algorithm rev 3 (ADR-039 2026-04-25): name comparison removed, location step added, single matcher across calendar + results paths. Code allocator (ADR-043 2026-04-26): three-step ladder (CURRENT_SLOT_REUSE → PRIOR_SEASON_MATCH → NEXT_FREE_ALLOC) + classifier (PEW/IMEW/DMEW; MEW dropped); Telegram alert per NEXT_FREE_ALLOC. Automated CERT→PROD propagation via `promote.py --mode calendar` (see FR-86). | UC8, UC9 | 12.1–12.13, pytest evf.1–evf.21, evf.24, evf.40–evf.42, evf.25–evf.39, prom.5–prom.7 | Covered (ADR-028 rev 3 2026-04-26 → ADR-043: allocator + classifier + EVF organizer; ADR-039: dedup ladder; ADR-026 calendar mode) |
| FR-59 | Two-view app shell: sidebar drawer with Ranklista + Kalendarz navigation | UC12, UC21 | 8.27–8.37 | Covered (M8) |
| FR-60 | Event CRUD via web UI (create, edit, delete events with all fields) | UC22(c) | 9.23–9.24, 9.28, 9.43–9.49 | Covered (M9, T9.1 SQL + T9.3 UI) |
| FR-61 | Scoring config editor (admin, per-season, structured form) | UC22(f) | 8.62–8.75 | Covered (M8) |
| FR-62 | Calendar view: completed events show "Wyniki" link to event results URL | UC21 | 8.76–8.77 | Covered (M8) |
| FR-63 | Calendar event links stacked vertically: Wyniki and Komunikat organizatora rendered one below the other | UC21 | 8.78 | Covered (ADR-017) |
| FR-64 | Season-level EVF toggle config: `bool_show_evf_toggle` in `tbl_scoring_config` controls PPW/+EVF toggle visibility in Ranklist and Calendar; admin checkbox in SeasonManager edit form | ADR-017 | 9.37–9.39, 8.79–8.83 | Covered |
| FR-65 | Rolling ranking for active season only: `p_rolling BOOLEAN DEFAULT FALSE` on `fn_ranking_ppw` and `fn_ranking_kadra`; position-matched carry-over from previous season; declared-counterpart constraint; category crossing via current season's end year. Future (not yet active) seasons intentionally show empty ranklist — rolling only kicks in when the season becomes active (ADR-031) | ADR-018, ADR-031, §8.3.1, §8.3.2 | R.1–R.14 | Covered |
| FR-66 | Rolling drilldown: `fn_fencer_scores_rolling` returns carried-over scores with `bool_carried_over` flag and source season code; visual distinction in DrilldownModal (grey striped bars, `↩` marker, rolling info banner) and CalendarView (progress slot bar) | ADR-018 | R.15–R.25 | Covered |
| FR-67 | Birth year range subtitle on ranklist view: displays eligible birth years for selected age category and season as enumeration (e.g. `kat. 2 — roczniki: 1976, 1975, .. 1967`); V4 open-ended ("i starsi"/"and older"); updates on category/season/locale change; PL+EN | UC12 | BY.1–BY.7 | Covered |
| FR-68 | Biennial event carry-over: rolling carry-over uses rules-based type matching (`json_ranking_rules` buckets) instead of declared-event matching; IMEW (type=MEW) results from previous season automatically carry over when MEW is in the international rules, even without an IMEW event in the current season (ADR-021) | ADR-021 | R.19–R.21 | Covered |
| FR-70 | Orchestrator parses FTL XML metadata and routes to correct DB tournament by weapon+gender+category+date | ADR-022, §2.5 | 9.149–9.151 | Covered |
| FR-71 | Orchestrator splits combined-category XML (v0v1, v0v1v2) into per-category result sets with re-ranking | ADR-024 | 9.152–9.154 | Covered |
| FR-72 | Orchestrator resolves fencer identities via fuzzy matching against DB (domestic auto-create, international skip) | UC3, ADR-020 | 9.155–9.157 | Covered |
| FR-73 | `fn_ingest_tournament_results` atomically deletes old + inserts new results + scores in single transaction | ADR-014, ADR-022 | 10.1–10.7 | Covered |
| FR-74 | CLI entry point processes single XML files, .zip archives, or Supabase Storage staging bucket | ADR-023 | 9.166–9.168 | Covered |
| FR-75 | Google Apps Script extracts email .zip attachments from Gmail → uploads to Supabase Storage staging | ADR-023 | Manual E2E ✓ | Covered |
| FR-76 | GitHub Actions `ingest.yml` downloads from Storage staging → processes → archives | ADR-023 | Manual E2E ✓ | Covered |
| FR-77 | Processed .zip archived to `archive/{season}/{event}.zip`; staging cleaned; previous event compressed | ADR-023 | 9.169–9.172, 9.191–9.192 | Covered |
| FR-78 | Telegram notifications for all pipeline events (13 use cases: routine, warnings, alerts, overdue) | ADR-025 | 9.173–9.190 | Covered |
| FR-79 | Event-centric ingestion: match XML to existing event by date, create tournaments on-the-fly | ADR-025 | 10.8–10.12, 9.193 | Covered |
| FR-80 | Event status lifecycle: PLANNED → IN_PROGRESS → COMPLETED with rollback | ADR-025 | 10.12–10.15 | Covered |
| FR-81 | Telegram command interface: 20+ admin commands for lifecycle, review, storage, season, PROD, URLs, emergency | ADR-025 | 10.16–10.22 | Covered |
| FR-82 | CERT → PROD promotion triggered from Telegram and Admin UI | ADR-026 | PPW4 E2E ✓ | Covered |
| FR-83 | Batch summary notification after each ingestion run | ADR-025 | 9.197 | Covered |
| FR-84 | ADR-024 compliance: flag PENDING for unknown DOB in combined categories | ADR-024/025 | 9.194–9.196 | Covered |
| FR-85 | Workflow failure notifications via Telegram | ADR-025 | 9.202–9.203 | Covered |
| FR-86 | CERT → PROD promotion: per-tournament transfer with url_results carry and error recovery (event mode), plus automated EVF calendar propagation (calendar mode — new events + URL refresh via `fn_import_evf_events` / `fn_refresh_evf_event_urls`; runs after 3-day EVF scrape cron, admin edits protected, concurrency-group-protected from overlap with event-promote) | ADR-026 (rev 2026-04-20), ADR-028 | 9.204–9.207, prom.5–prom.7 | Covered |
| FR-87 | Auto-export seed SQL files after promotion (committed to repo) | ADR-026 | 9.208 | Superseded by FR-88 |
| FR-88 | Monolithic PROD seed export on promote (schema-driven, single file) | ADR-027→ADR-036 | 9.209–9.213 | Covered |
| FR-89 | Auto-resume email polling on event day | ADR-027 | GAS E2E ✓ | Covered |
| FR-90 | Event registration URL: nullable `url_registration` on `tbl_event`, displayed in Calendar before deadline/start, editable in Admin UI | UC21, ADR-030 | 8.18–8.20, 8.21–8.25, 9.43a–9.43c | Covered |
| FR-91 | Event registration deadline: nullable `dt_registration_deadline` on `tbl_event`, displayed in Calendar until deadline passes, editable in Admin UI | UC21, ADR-030 | 8.18–8.20, 8.21–8.25, 9.43a–9.43c | Covered |
| FR-92 | Fencer gender column with backfill from tournament participation, inline admin edit, gender mismatch highlighting in Identity Manager, and automated cross-gender scoring enforcement (ADR-034) | ADR-033, ADR-034 | 11.16–11.19, 9.85–9.86, 9.89–9.94, 14.CG1–14.CG9 | Covered |
| FR-93 | Birth year review tab: filter/search/edit/tournament history grouped by season/birth year hints + auto-suggest/age category inconsistency flag | UC16, ADR-035 | 9.100–9.113, 13.1–13.4 | Covered |
| FR-94 | Derived event display status: PLANNED events whose `dt_end < today` render as amber "Awaiting results" / "Oczekiwanie na wyniki" instead of misleading "Planowany". View-layer helper only — underlying `enum_status` unchanged, preserving ADR-018 rolling carry-over invariant. Self-heals when `fn_ingest_tournament_results` fires. | UC21, ADR-037 | ES.1–ES.11, 8.41b | Covered |
| FR-95 | Event deletion admin tool: `fn_delete_event(prefix)` RPC (+ Telegram `delete <prefix>` command) performs rollback + removal of `tbl_event` row in a single transaction. Used when an event was created in error (wrong-ingest, erroneous scrape, dedup-bug phantom). Stricter than `rollback` (which keeps the event row for re-ingest). Prefix-matches in the active season, reuses `_resolve_event_prefix` + `fn_delete_tournament_cascade` helpers. Admin-only (REVOKE anon, GRANT authenticated). | UC22(e), UC27, ADR-025 (amendment 2026-04-21) | 10.29–10.32 | Covered |
| FR-96 | EVF stale-event gate: scraper does not auto-create or auto-update events outside the 30-day fresh window or marked `enum_status='COMPLETED'`. `is_in_scope(event)` predicate is applied to existing CERT rows AND scraped EVF events before passing them to `_find_existing_match` / `_create_cert_event`. Stale events are admin-territory; the cron only ever touches in-flight (≤30 days post-end, not COMPLETED) rows. Implemented in `python/scrapers/evf_calendar.py` (`is_in_scope`, `STALE_WINDOW_DAYS`) and applied at entry of `sync_calendar` / `sync_results` in `evf_sync.py`. | UC25, ADR-039 | pytest evf.22, evf.24 | Covered |
| FR-97 | EVF logical-integrity guard: a `tbl_event` row with `dt_start > today AND enum_status = 'COMPLETED'` is data corruption and halts the scraper. `assert_no_future_completed(events)` raises `LogicalIntegrityError` at sync entry; the caller sends the **EVF Sync HALT** Telegram alert and exits non-zero so the admin notices and reconciles the row manually before the next cron. | UC25, UC27, ADR-039 | pytest evf.23 | Covered |
| FR-98 | Multi-slot event result URLs: `tbl_event` carries up to 5 nullable result-platform URL slots (`url_event`, `url_event_2..5`); admin enters them via the Event Edit form (slot #1 visible, slots #2–5 behind a disclosure with filled-count). On every save the 5 inputs are compacted (trim → drop empty → dedupe first-occurrence → pad NULL) so any non-null URL always lives in slot #1, preserving every existing `url_event`-as-primary code path (calendar 🔗 link, ⬇ Import button, ADR-029 auto-populate seed, ADR-028 EVF refresh write order). Tournament URL discovery iterates all non-null slots and merges per-(weapon,gender,category) results dedupe-first. `tbl_tournament.url_results` unchanged (drilldown leaf). Implemented as `fn_compact_urls(VARIADIC TEXT[]) RETURNS TEXT[]` shared by `fn_create_event` / `fn_update_event` / `fn_refresh_evf_event_urls`. | UC21, UC22(c), ADR-040 | 15.1–15.6, 9.44a–9.44f, pytest 3.16k–m, prom.8 | Covered |
| FR-99 | Server-side workflow dispatch: admin UI ⬇ buttons invoke a Supabase Edge Function (`dispatch-workflow`) that holds the GitHub PAT as a Supabase env secret and forwards `workflow_dispatch` calls. PAT never appears in HTML/JS bundles. Function uses an allowlist (`populate-urls.yml`, `scrape-tournament.yml`), verifies caller JWT (built-in Supabase auth), and returns sync `{ok, runs_url}`. Per-event inline status renders below the event-row in the admin accordion (pending → success-with-link → error). `github-pat` / `github-repo` HTML attributes removed from `<spws-ranklist>`. Telegram path (GAS server-side PAT) untouched. | UC22(c), UC27, ADR-041 | 9.45a–9.45f | Covered |
| FR-100 | Season-init wizard with skeleton pre-allocation: admin creates a new season via a 3-step modal (Identity → Scoring → Confirm). On commit, `fn_create_season_with_skeletons` runs as one atomic transaction — INSERT season → overwrite default scoring config (carries `bool_show_evf_toggle`) → call `fn_init_season(p_id_season)` which produces one CREATED-status skeleton per recurring event kind (`^PPW\d+-` family, `^PEW\d+-` family, always-MPW, always-MSW, optional IMEW/DMEW per `enum_european_event_type`) plus 6 V2 child tournaments per skeleton. Cancel at any step = nothing persists (transaction rollback). Post-commit EDIT form shows skeletons as calendar-style boxes with "↶ Cofnij całość" link calling `fn_revert_season_init` (refuses if any skeleton has advanced past CREATED). EventManager exposes editable `txt_code` (cascades to children via `fn_update_event` v2) and `id_prior_event` picker. Supersedes carry-over admin runbook §3, §4, §6, §9. | UC22(a), ADR-044 | ph3.1–ph3.21 (pgTAP), ph3.23–ph3.37 (vitest wizard), ph3c.1–ph3c.12 (vitest EventManager) | Covered |
| FR-101 | Configurable carry-over engine selection per season (admin UI): `tbl_season.enum_carryover_engine` is exposed as a dropdown inside `ScoringConfigEditor` Section 4b "🔀 Silnik carry-over". Dropdown lists all `enum_event_carryover_engine` values dynamically (extensible — new engines auto-appear). Save flow patches `tbl_season` separately from `tbl_scoring_config` (instant flip, no migration). 🎯 Konfiguracja punktacji button rendered only on future + active seasons (past-complete seasons hide it; defense-in-depth via existing `readonly` prop). Greenfield seasons default to `EVENT_FK_MATCHING` after the Phase 3 column-DEFAULT flip; existing rows preserved. Supersedes carry-over admin runbook §5 ("flip via SQL"). | UC22(a), ADR-045, ADR-042 | ph3.22a/b/c (pgTAP), ph3.37a–g (vitest) | Covered |

> **Note:** FR-69 was retired before assignment; gap is intentional. Total active FRs = 100.

## Non-Functional Requirements

| ID | Requirement | Source | Tests | Status |
|----|-------------|--------|-------|--------|
| NFR-01 | API response < 500 ms; scoring engine < 2 s per tournament | §10 | — | Not tested |
| NFR-02 | 99.9% availability via Supabase managed hosting | §10 | — | Infrastructure (not testable) |
| NFR-03 | Storage < 100 MB for 5 seasons | §10 | — | Not tested |
| NFR-04 | 50 concurrent users | §10 | — | Not tested |
| NFR-05 | RLS: anon read-only on public tables | §9.2.1 | 1.10a–b, 1.25 | Covered |
| NFR-06 | RLS: authenticated full CRUD | §9.2.1 | 1.11 | Covered |
| NFR-07 | RLS: audit log not publicly readable | §9.2.1 | 1.26 | Covered |
| NFR-08 | Browser compatibility (Chrome, Firefox, Safari, Edge) | §10 | — | Not tested |
| NFR-09 | Mobile responsive ≥ 375 px | §10, ADR-032 | C.1–C.14 | Covered (drilldown cards) |
| NFR-10 | Pipeline observability (structured logs + Telegram) | §10 | 3.6 (Telegram only) | Partial |
| NFR-11 | Database migration strategy (numbered SQL files) | §9.9 | 1.1a–1.2i (schema verification) | Covered |
| NFR-12 | Data integrity (Supabase daily backups) | §10 | — | Infrastructure (not testable) |
| NFR-13 | Shadow DOM isolation (host CSS does not leak) | §5, §6 | 8.55–8.61 | Covered (M8) |

## Coverage Summary

| Status | Count | FRs |
|--------|-------|-----|
| Covered | 94 | FR-01–FR-52, FR-55–FR-58, FR-59–FR-68, FR-70–FR-86, FR-88–FR-101 |
| Partial | 2 | FR-53, FR-54 |
| Superseded | 1 | FR-87 (by FR-88) |
| Not tested (NFR) | 4 | NFR-01, NFR-03, NFR-04, NFR-08 |
| Infrastructure (NFR) | 2 | NFR-02, NFR-12 |
| Covered (NFR) | 7 | NFR-05, NFR-06, NFR-07, NFR-09, NFR-10 (partial), NFR-11, NFR-13 |

## Rebuild Infrastructure (Phase 2b — ADR-050 / ADR-055)

The rebuild introduces infrastructure tests that don't map to user-facing FRs. They are catalogued here for traceability against the architecture decisions that introduced them. For the rebuild's per-sub-phase status, see [doc/development_history.md](development_history.md) §Phase 2b.

| ADR | Scope | Tests | Status |
|-----|-------|-------|--------|
| [ADR-050](adr/050-unified-ingestion-pipeline.md) | Unified Ingestion Pipeline — IR contract + 8 parsers + parser registry | `python/tests/test_ir.py::ir.1`–`ir.7` (7 IR contract assertions, incl. cross-language enum sync); `python/tests/test_ir_contracts.py` (41 parser-contract assertions across 9 test classes — `ftl_ir.1`–`7`, `engarde_ir.1`–`5`, `file_import_ir.1`–`3`, `ftxml_ir.1`–`6`, `fourfence_ir.1`–`4`, `dartagnan_ir.1`–`5`, `evf_ir.1`–`4`, `ophardt_ir.1`–`5`, `registry.1`–`2`) | Covered (Phase 1, 2026-05-01) |
| [ADR-055](adr/055-ingest-traceability.md) | Per-parser provenance stamps on `tbl_event` + `tbl_tournament`; cap-6 history tables; 8 design decisions D1–D8 | `supabase/tests/26_ingest_traceability.sql::26.1`–`26.23` (enum + stamp columns + history tables + FK CASCADE + UNIQUE + cap-of-6 trigger + per-parent isolation) | Covered (Phase 1, 2026-05-01) |
| ADR-051 (planned) | Frozen-snapshot policy (`txt_source_status`, copy-from-PROD) | TBD — Phase 4 | Pending |
| ADR-052 (planned) | URL→data validation enforcement | TBD — Phase 3 | Pending |
| ADR-053 (planned) | EVF backup-source + parity gate | TBD — Phase 4 | Pending |
| ADR-054 (planned) | Carry-over FK + 366-day cap | TBD — Phase 7 | Pending |

The cross-language enum-sync invariant (Python `SourceKind` ↔ Postgres `enum_parser_kind`) is enforced at runtime by `test_ir.py::test_source_kind_matches_postgres_enum` — drift detector for any future source addition.

## Cross-references

- ADR registry: Project Specification Appendix C — Architecture Decisions
- Test baseline (counts per suite): Project Specification Appendix D
- Use cases: Project Specification §3
- Functional scope: Project Specification §6 (Implementation Phasing) → externalized to [doc/development_history.md](development_history.md)
