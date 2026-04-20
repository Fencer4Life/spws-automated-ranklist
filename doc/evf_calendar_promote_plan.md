# EVF Calendar Promote (CERT → PROD) — Implementation Plan

**Date:** 2026-04-20
**ADR:** [ADR-026](adr/026-cert-prod-promotion.md) — Calendar Promote Mode amendment
**Related:** [ADR-011](adr/011-artifact-release-pipeline.md) (three-tier pipeline), [ADR-028](adr/028-evf-calendar-results-import.md) (EVF scraper), [ADR-036](adr/036-prod-export-local-mirror.md) (PROD export)
**RTM:** FR-58 (EVF calendar import), FR-86 (CERT→PROD promotion)

## Problem

The EVF scraper (`evf-sync.yml`, cron every 3 days) lands events in CERT as `PLANNED` with URL enrichment (event page, invitation PDF, registration link, venue address, fee). The existing per-event promote workflow (`promote.yml` + `python/pipeline/promote.py`) is manual, `--event EVENT_CODE` driven, and **skips tournaments with zero results** — so it never promotes upcoming calendar events. Result: PROD's public calendar is weeks behind CERT.

## Intended outcome

A new `--mode calendar` on `promote.py` propagates new EVF events and URL-refresh updates from CERT to PROD without touching tournaments or results. Runs automatically as a second job of the 3-day `evf-sync.yml` cron. Per-event promote (ADR-026 original contract) remains unchanged. The two are protected against overlapping writes to PROD by a GitHub Actions concurrency group.

## Design

### Data flow

```
CERT (evf-sync cron, mode=both)
  ├── fn_import_evf_events      (new events)
  └── fn_refresh_evf_event_urls (URL enrichment on existing)
          │
          ▼  same workflow, second job, same 3-day cron
PROD (promote.py --mode calendar)
  ├── Read active season + existing EVF events on PROD
  ├── Read EVF events on CERT for active season
  ├── Diff by txt_code:
  │     ├── On CERT, not on PROD → fn_import_evf_events (PROD)     [new]
  │     └── On both               → fn_refresh_evf_event_urls (PROD) [refresh]
  └── Telegram summary: Imported N, Refreshed M
```

### `--mode calendar` semantics

Implemented in [python/pipeline/promote.py](../python/pipeline/promote.py):

1. Resolve **active season** from PROD (`_get_active_season`) — raises if none.
2. Read CERT EVF events in that season (filter `txt_code LIKE 'PEW%' OR LIKE 'MEW%'`) with all URL / enrichment fields.
3. Read PROD existing events `(id_event, txt_code)` for the same season.
4. Diff by `txt_code`:
   - **New on CERT only** → call `fn_import_evf_events(payload_jsonb, season_id)` on PROD. Payload keys: `code, name, dt_start, dt_end, location, country, address, weapons, is_team, url_event, url_invitation, url_registration, dt_registration_deadline, fee, fee_currency`.
   - **On both sides** → call `fn_refresh_evf_event_urls(payload_jsonb)` on PROD. Payload keys: `id_event` (PROD PK!), plus the URL/enrichment fields that the refresh RPC accepts. `txt_code`, `txt_name`, `enum_status`, `dt_start`, `dt_end`, `id_season` are deliberately **not** in the payload — they're admin-curated.
5. Print a per-code summary and send Telegram (`Imported: N · Refreshed: M`).

`--dry-run` returns the diff without calling either RPC. Useful for smoke-testing.

### CLI shape

```
python -m python.pipeline.promote --event PEW7                   # unchanged (ADR-026)
python -m python.pipeline.promote --event PEW7 --mode event      # explicit, same
python -m python.pipeline.promote --mode calendar                # new
python -m python.pipeline.promote --mode calendar --dry-run      # smoke
```

Validation:
- `--mode event` (default): `--event` required. Missing → argparse error.
- `--mode calendar`: `--event` rejected with a clear message ("calendar promotes all EVF events for the active season").

### GitHub Actions wiring

**[promote.yml](../.github/workflows/promote.yml)** — workflow-level concurrency:
```yaml
concurrency:
  group: prod-write
  cancel-in-progress: false
```

**[evf-sync.yml](../.github/workflows/evf-sync.yml)** — new `promote-calendar` job:
- `needs: sync` — runs after the EVF scraper has landed updates in CERT.
- `if: github.event.inputs.mode != 'results'` — runs on cron (no inputs → undefined → truthy) and on any `mode != results` dispatch.
- Same `concurrency: prod-write` group.
- Failure step posts a Telegram alert mirroring the existing `Notify failure` shape.

Both workflows share the `prod-write` concurrency group → GitHub Actions serialises them. A manual event-promote dispatched while the scheduled calendar-promote is running (or vice versa) queues until the first finishes. `cancel-in-progress: false` because we never want to cancel a partial PROD write.

### Idempotency backstop

Even if the concurrency group is bypassed (e.g. running `promote.py --mode calendar` locally against PROD while the workflow is mid-flight), the RPCs are safe:

- `fn_import_evf_events` skips events whose `txt_code` already exists (ADR-028 original contract).
- `fn_refresh_evf_event_urls` only writes to NULL/empty columns (ADR-028 rev 2 invariant, pgTAP 12.11 enforced).

The worst-case concurrent race ends with the same state as a serial execution.

### Telegram summary

```
<b>EVF Calendar → PROD</b>
Imported: 2 new event(s)
Refreshed: 9 existing event(s)
```

Sent by `promote.py` on success; failure alert is sent by the workflow's `if: failure()` step and would fire in addition to any pre-raise Telegram from the Python side.

## Files modified / created

| File | Change |
|---|---|
| [python/pipeline/promote.py](../python/pipeline/promote.py) | New `--mode {event,calendar}` arg, new `promote_calendar()` + helpers (`_get_active_season`, `_read_cert_evf_events`, `_build_import_payload`, `_build_refresh_payload`). Dispatch in `main()`. |
| [python/tests/test_promote.py](../python/tests/test_promote.py) | +3 tests `prom.5–prom.7`. |
| [.github/workflows/promote.yml](../.github/workflows/promote.yml) | Added workflow-level concurrency group `prod-write`. |
| [.github/workflows/evf-sync.yml](../.github/workflows/evf-sync.yml) | New `promote-calendar` job, `needs: sync`, shared concurrency group. |
| [doc/adr/026-cert-prod-promotion.md](adr/026-cert-prod-promotion.md) | "Calendar Promote Mode (amendment, 2026-04-20)" subsection. |
| [doc/Project Specification. SPWS Automated Ranklist System.md](Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) | Appendix C revision + RTM FR-58 / FR-86 updates. |

## Explicitly NOT changed

- **No new migrations.** `fn_import_evf_events` + `fn_refresh_evf_event_urls` are already on PROD (deployed_migrations.json: `20260420000001`, `20260420000002`).
- **No RPC changes.** Same SQL contracts as ADR-028 rev 2.
- **No changes to event-promote.** Default CLI mode stays `event`; `--event EVENT_CODE` still works; `promote.yml` workflow body unchanged apart from the concurrency group.
- **No frontend changes.** The PROD calendar view just starts showing fresher data.
- **No pgTAP changes.** 12.1–12.13 already cover both RPCs; they behave identically on CERT and PROD.
- **No schema fingerprint impact.** No DDL.

## Verification

1. **RED.** `pytest python/tests/test_promote.py::TestPromoteCalendar -v` → ImportError / assertion fails before implementation.
2. **GREEN.** Same command + `pytest -m "not integration"` → all existing suites stay green.
3. **Dry-run (live).**
   ```bash
   SUPABASE_ACCESS_TOKEN=... SUPABASE_CERT_REF=... SUPABASE_PROD_REF=... \
     python -m python.pipeline.promote --mode calendar --dry-run
   ```
   Expected output: `Imported: N · Refreshed: M` with per-code lists matching the 13 EVF events currently in CERT.
4. **Coherence gate** + `supabase test db` + `cd frontend && npm test` → all green.
5. **Post-push.** Manual `workflow_dispatch` on `evf-sync.yml` (`mode=calendar`). Expected: `sync` job runs in CERT, `promote-calendar` job runs after, Telegram delivers two distinct messages.
6. **Concurrency sanity.** Dispatch `promote.yml` (event promote) while `evf-sync.yml.promote-calendar` is running. Expected: second job shows "Pending — waiting for concurrency group `prod-write`" in the GitHub UI, then runs after the first completes. No PROD state corruption.

## Rollback plan

- If `--mode calendar` misbehaves: revert [python/pipeline/promote.py](../python/pipeline/promote.py) and [.github/workflows/evf-sync.yml](../.github/workflows/evf-sync.yml) to the previous commit; concurrency group on promote.yml is cosmetic and can stay.
- If a bad refresh payload writes junk to PROD: it can't — `fn_refresh_evf_event_urls` only fills NULL columns, so the worst it can do is populate a column we'd have to manually `UPDATE tbl_event SET url_* = NULL` to reset. No destructive overwrite.
- If `fn_import_evf_events` creates a bogus event: `DELETE FROM tbl_event WHERE txt_code = '<bad>'` (cascades to child tournaments).
