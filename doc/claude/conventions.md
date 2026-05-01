# Conventions

## Documentation
See [documenting.md](documenting.md) for the scope-change pass, RTM post-implementation
check, ADR maintenance workflow, and diagram rules. Mandatory before marking any task complete.

## Active rebuild - read first

A LOCAL DB rebuild is in progress per
/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md.

Rules below carry REBUILD WAIVER or REBUILD-NEW markers where behavior
differs from steady-state. Waivers expire at end of Phase 6 (ADR-051).

## Data integrity (hard rules — user has been burned)

- **Never delete tournament/result/event rows without per-row approval.**
  Show mapping, propose reassignment, ask first.
  REBUILD-WAIVER active until Phase 6 (ADR-051).
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
