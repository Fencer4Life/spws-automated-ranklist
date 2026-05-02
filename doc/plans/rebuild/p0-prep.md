# Phase 0 — Schema prep + cert_ref + rules framework + matcher config + memory review (M)

**Prerequisites:** Phase 0.0 ([p0-0-ci-upgrade.md](p0-0-ci-upgrade.md)) ✅ done; Phase 0.5 (spec refactor — inlined in master) done.

## Deliverables

### Database migrations

- Add `tbl_result.{txt_scraped_name TEXT, num_match_confidence NUMERIC, enum_match_method enum_match_method}` where `enum_match_method` is one of `AUTO_MATCH | USER_CONFIRMED | AUTO_CREATED | BY_ESTIMATED`.
- Add `tbl_event.txt_source_status` enum (Phase 0 shipped `LIVE_SOURCE | FROZEN_SNAPSHOT | NO_SOURCE`; superseded by `ENGINE_COMPUTED | EVF_PUBLISHED` per ADR-053 in Phase 4).
- Add `fn_age_categories_batch(p_birth_years INT[], p_season_end_year INT)` returning batch results — replaces per-row `fn_age_category` calls inside the splitter.
- Rewrite `fn_ingest_tournament_results` removing `tbl_match_candidate` writes (table itself stays present but unwritten until Phase 6).

### Migration files to create

- `supabase/migrations/2026MMDD_phase0_schema_prep.sql`
- `supabase/migrations/2026MMDD_cert_ref_schema.sql` (creates `cert_ref` schema)

### Tooling

- Update [python/pipeline/export_seed.py](../../../python/pipeline/export_seed.py) to omit `tbl_match_candidate` rows.
- New script `scripts/load-cert-ref.sh` — loads latest `seed_prod_<date>.sql` into a parallel read-only schema `cert_ref` (creates `cert_ref.tbl_event`, `cert_ref.tbl_tournament`, `cert_ref.tbl_result`, `cert_ref.tbl_fencer`). Refresh **once** at rebuild start; never modified during rebuild.
- New file `python/matcher/config.yaml` with:
  - Initial fuzzy-match thresholds
  - Polish normalizations: `ł→l, ó→o, ż→z, ś→s, ń→n, ę→e, ą→a`
  - Empty nickname map (populated during Phase 3 matcher tuning loop)
  - Matcher reads from this file; supports hot-reload between event runs.

### Rules registry framework

- Create `doc/rules/` directory with:
  - `Makefile` (Pandoc — builds `.md` → `.html`)
  - `README.md` index
  - **R001-R012 seed rule files** (statements only — implementation refs filled in later phases per the table below)

Format per rule file: **Statement · Why · Trigger · Implementation (file:line) · Tests (IDs) · Edge cases · Change log · Originating ADR**.

| ID | Topic | ADRs | Phase to populate impl |
|---|---|---|---|
| R001 | Combined-pool split | 024, 047, 049, 050 | 3 |
| R002 | Joint-pool flag | 049, 050 | 3 |
| R003 | Age category by birth year | 010 | 0 (single SQL impl) |
| R004 | Cross-gender scoring | 034 | reused |
| R005 | EVF POL-only filter | 038 | 3 |
| R005b | EVF/FIE V0 prohibition | new (R005 child) | 3 |
| R006 | Identity match: auto-create domestic | 003, 050 | 3 |
| R007 | Rolling-score 366-day cap | 018, 054 | 7 |
| R008 | Carry-over FK linkage | 042, 045, 054 | 7 |
| R009 | URL→data validation | 052 | 3 |
| R011 | Source priority by organizer (EVF backup-only) | 053 | 3 |
| R012 | Engarde multilingual handling | 050 | 1 |

### ADRs

- **ADR-050 stub** committed; rule files reference it.

### Memory review

Per-file disposition matrix for memory under `/Users/aleks/.claude/projects/-Users-aleks-coding-SPWSranklist/memory/`. Categories: **KEEP / UPDATE / WAIVE-DURING-REBUILD / DELETE-IN-PHASE-6**.

### Claude-guidance module alignment (separate commit BEFORE schema-prep migration)

Three files at [doc/claude/](../../claude/) are edited with **locked verbatim text** (from a redline session). Phase 6 will remove `REBUILD WAIVER`/`REBUILD-NEW` markers.

#### Edit 1 — [doc/claude/conventions.md](../../claude/conventions.md): replace whole file with locked text

```markdown
# Conventions

## Documentation
See [documenting.md](documenting.md) for the scope-change pass, RTM post-implementation
check, ADR maintenance workflow, and diagram rules. Mandatory before marking any task complete.

## Active rebuild - read first

A LOCAL DB rebuild is in progress per
/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md.

Rules below carry REBUILD-NEW markers where behavior differs from steady-state.

## Data integrity (hard rules — user has been burned)

- **URLs are admin-managed only.** `url_event` / `url_results` are hand-entered
  (FTL/Engarde/4Fence/Ophardt). Never auto-fill from EVF site / WP API.
- **Validate URL→data match on every write**: scrape the URL, compare
  date/name/weapon/category, REJECT on mismatch. Plus pgTAP/pytest coverage.
- **Adding a column to `tbl_event`?** Rebuild `vw_calendar` in the same migration —
  admin form round-trip silently breaks otherwise.
- **`seed_tbl_fencer.sql` contains only PPW/MPW participants** — never PEW/IMSW/PS fencers.

## Identity resolution (REBUILD-NEW)

- [ADR-050] tbl_match_candidate removed in Phase 6.
  Provenance: tbl_result.{txt_scraped_name, num_match_confidence, enum_match_method}.
  Audit via tbl_audit_log.
- [R006, ADR-050] Cross-event match memory: tbl_fencer.json_name_aliases.
  Append on every USER_CONFIRMED match decision.
- [ADR-050] Matcher tuning via python/matcher/config.yaml only.
- [ADR-050] Per-event source-of-truth selected at runtime via ingest_cli.py review-event.

## Rebuild reference data (REBUILD-NEW, removed Phase 6)

- [ADR-050] 3-way diff: Source / cert_ref.* / draft tables.
- [ADR-050] cert_ref schema read-only, loaded from PROD seed once.
- [ADR-050] Draft tables tbl_*_draft scratch state by txt_run_id.

## Working style

- **No parallel task execution** — sequential only. **No autoapprove** — explicit per-step
  permission. **The user calls the shots**: diagnose, propose, stop. Do not chain steps
  without authorization.
- **UI debug never console**: surface diagnostics in the UI (banner / inline form), never
  push DevTools / console.log.
- **Telegram, not Discord**, for all alerting.
- **Never read .xlsx/.xlsm/.xls files without explicit per-file authorization.**
- **Use full names, not shorthand** ("Phase 1A: …" not "Layer 6").
```

#### Edit 2 — [doc/claude/architecture.md](../../claude/architecture.md): three locked edits

**Edit 2a — Data flow section (replace):**

```markdown
## Data flow

**Steady-state (post-Phase 6):**

\```
Email (.zip/.xml)  →  Google Apps Script (gas_email_ingestion.js)
                          ↓ uploads to Supabase Storage
                          ↓ triggers GitHub Actions (ingest.yml via PAT)
                      Python pipeline (orchestrator.py)
                          ↓ Parse (scrapers/) → Match (matcher/) → Ingest (atomic txn)
                          ↓ Telegram notifications
                      LOCAL → CERT → PROD (per-tournament promotion)
\```

**During rebuild (current — through Phase 6):**

\```
Source URL/file/EVF API → ingest_cli.py review-event
                            ↓ Parse → IR (ParsedTournament)
                            ↓ Stages 1-7: validate, splitter, matcher, alias-write
                            ↓ Write to tbl_*_draft (run_id)
                        3-way diff: Source / cert_ref / draft → doc/staging/<event>.diff.md
                            ↓ admin reviews, iterates with overrides
                            ↓ fn_commit_event_draft → live tables + audit
                        After rebuild: Phase 6 promotes LOCAL → CERT → PROD
\```
```

**Edit 2b — `matcher/` bullet (replace line 29):**

```markdown
- `matcher/` — RapidFuzz fuzzy identity resolution with diacritic folding + alias support. Three outcomes per scraped name:
  - High confidence (≥95): AUTO_MATCH → tbl_result.id_fencer
  - Borderline (50–94): surface in event diff for admin pick
  - Low confidence: SPWS auto-creates fencer with estimated BY (R006); EVF/FIE skips row.
  Cross-event memory: tbl_fencer.json_name_aliases write-back on USER_CONFIRMED. Tuning: python/matcher/config.yaml only.
```

**Edit 2c — 366-day cap clause (replace within line 22):**

```markdown
- Scoring engine is in SQL (`fn_*` SECURITY DEFINER functions). Ranking config is JSONB per season. Rolling carry-over for active season is rules-based. The 366-day cap column tbl_season.int_carryover_days exists with default 366 but enforcement lands in Phase 7 (ADR-054). See ADR-018, ADR-021.
```

#### Edit 3 — [doc/claude/testing.md](../../claude/testing.md): append rebuild-period commands

```bash
# Rebuild-period commands (REBUILD-ACTIVE through Phase 6)
bash scripts/load-cert-ref.sh                              # populate cert_ref schema from PROD seed
python -m pipeline.ingest_cli review-event <code>          # interactive per-event review
python -m pipeline.ingest_cli list-drafts                  # list pending review drafts
python -m pipeline.ingest_cli resume --run-id <UUID>       # resume interrupted draft
python -m pipeline.ingest_cli commit-draft --run-id <UUID>
make -C doc/rules                                          # build doc/rules/*.html from markdown
```

#### Edit 4 — [doc/claude/documenting.md](../../claude/documenting.md): no changes

The ADR registry it references lives in MEMORY.md and Appendix C of the spec, not in this file; the workflow already covers ADRs 050-054.

#### Edit 5 — [doc/claude/key-references.md](../../claude/key-references.md): append rebuild-period rows

```markdown
| [/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md](...) | Active rebuild plan (REBUILD-ACTIVE through Phase 6) |
| [doc/rules/](../rules/) | Rules registry (R001-R012, Pandoc-built HTML) |
| [doc/overrides/](../overrides/) | Per-event override YAML files (REBUILD-ACTIVE) |
| [scripts/load-cert-ref.sh](../../scripts/load-cert-ref.sh) | Loads PROD seed into cert_ref schema (REBUILD-ACTIVE) |
```

Phase 6: update "49 ADRs" → "54 ADRs"; remove REBUILD-ACTIVE rows for plan file, overrides directory, and cert_ref script.

## Risk gate

- All three test suites pass.
- `tbl_match_candidate` still present and unwritten.
- `make rules` produces `doc/rules/rules.html` master.
- `cert_ref` schema populated and queryable.
- Matcher loads thresholds from `config.yaml`.

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p0-0-ci-upgrade.md](p0-0-ci-upgrade.md)
- Successor: [p1-ir-parsers.md](p1-ir-parsers.md) — IR + 7 parsers + Ophardt spike
- Rules registry framework feeds: [p3-pipeline.md](p3-pipeline.md) (R001, R002, R005, R006, R009, R011, R012), [p7-carryover.md](p7-carryover.md) (R007, R008). R010 (frozen snapshot) was retired 2026-05-02 along with the FROZEN_SNAPSHOT concept.
