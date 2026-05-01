# Conventions

## Documentation

See [documenting.md](documenting.md) for the scope-change pass, RTM post-implementation check, ADR maintenance workflow, and diagram rules. Mandatory before marking any task complete.

## Data integrity (hard rules — user has been burned)

- **Never delete tournament/result/event rows without per-row approval.** Show mapping, propose reassignment, ask first.
- **URLs are admin-managed only.** `url_event` / `url_results` are hand-entered (FTL/Engarde/4Fence/Ophardt). Never auto-fill from EVF site / WP API.
- **Validate URL→data match on every write**: scrape the URL, compare date/name/weapon/category, REJECT on mismatch. Plus pgTAP/pytest coverage.
- **Adding a column to `tbl_event`?** Rebuild `vw_calendar` in the same migration — admin form round-trip silently breaks otherwise.
- **`seed_tbl_fencer.sql` contains only PPW/MPW participants** — never PEW/IMSW/PS fencers.

## Working style

- **No parallel task execution** — sequential only. **No autoapprove** — explicit per-step permission. **The user calls the shots**: diagnose, propose, stop. Do not chain steps without authorization.
- **UI debug never console**: surface diagnostics in the UI (banner / inline form), never push DevTools / console.log.
- **Telegram, not Discord**, for all alerting.
- **Never read .xlsx/.xlsm/.xls files without explicit per-file authorization.**
- **Use full names, not shorthand** ("Phase 1A: …" not "Layer 6").
