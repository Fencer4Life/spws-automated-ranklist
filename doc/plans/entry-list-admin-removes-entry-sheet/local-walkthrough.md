# FR-166 — LOCAL walk-through, 2026-11-17

Plan: `doc/plans/entry-list-admin-removes-entry-tdd-plan-2026-11-17.html` §06 step 3.
Script: `tools/local-walkthrough.cjs`. LOCAL only: the Docker Supabase stack (127.0.0.1:54321) and
the full application built from the branch (`vite build`), served at `http://localhost:5199` through
Playwright `route()`. Every other host was blocked by the script.

Event: PEW5efs-2026-2027, EVF Circuit – Łomianki (POL), id 86; registration open until 2026-12-07.
Before the run LOCAL held no entry named ZZWALK…; event 86 held 0 entries.

| Step | Observed |
|---|---|
| 1 · a visitor registers ZZWALKUSUN Ewa (F, 1970, épée) through the form | „✓ Zgłoszenie potwierdzone” |
| 2 · the visitor opens „Lista zgłoszonych” | the entry is listed; „Usuń” buttons: **0** |
| 3 · signed in as the LOCAL test administrator (`scripts/reset-dev.sh`), search „zzwalk” | 1 row, 1 „Usuń”, first tile „1 z 1” |
| 3 · „Usuń” | „Usunąć zgłoszenie? ZZWALKUSUN Ewa · szpada · V2 · EVF Circuit – Łomianki (POL) · Tej operacji nie można cofnąć. Zawodniczka może zgłosić się ponownie przed końcem terminu zapisów.” |
| 3 · „Usuń zgłoszenie” | „✓ Usunięto zgłoszenie: ZZWALKUSUN Ewa”; search cleared: first tile 0, no row with the name |

Database afterwards (`docker exec supabase_db_SPWSranklist psql`): `tbl_registration` 0 rows named
ZZWALK…, `vw_registration_entry_list` 0, event 86 0 entries.

Organizer's download: `fn_ftl_export_entries` as deployed on LOCAL reads `tbl_registration` live
(`FROM tbl_registration`, no snapshot), so a removed entry cannot reach the files. It could not be
called end to end: LOCAL holds no organizer key, and without one the function returns nothing.

The walk-through browser runs with Chromium's local-network-access checks off: a page answered by
`route()` is not treated as a local origin, and Chromium refused its requests to 127.0.0.1 until then.

Screenshots: `local/local-1-visitor-list.png`, `local/local-2-admin-confirm.png`,
`local/local-3-admin-done.png`.
