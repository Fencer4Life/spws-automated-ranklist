# ADR-026: CERT → PROD Event Promotion via Python Script

**Status:** Accepted (amended 2026-04-20 — calendar promote mode added for the EVF scraper; see "Calendar Promote Mode" below)
**Date:** 2026-04-05
**Relates to:** ADR-025 (Event-Centric Ingestion + Telegram Admin), ADR-011 (Three-Tier Release Pipeline), ADR-028 (EVF Calendar + Results Import)
**Companion implementation plan:** [doc/evf_calendar_promote_plan.md](../evf_calendar_promote_plan.md)

## Context

After ingesting XML results into CERT and validating them (via Telegram commands, admin UI, and ranklist review), the admin needs to push the event data to PROD. The `promote` Telegram command triggers a GitHub Actions workflow, but the actual data transfer mechanism needs to be defined.

Event data includes: tournaments (auto-created during ingestion), results, match candidates, and scoring. A typical event has 20-30 tournaments and 50-100 results.

## Decision

Use a **Python promotion script** (`python/pipeline/promote.py`) that:

1. Reads all tournaments + results for an event from CERT via Supabase Management API SQL queries
2. For each tournament on CERT:
   - Calls `fn_find_or_create_tournament()` on PROD to create the tournament if it doesn't exist
   - Calls `fn_ingest_tournament_results()` on PROD with the results (atomic delete+insert+score)
3. Updates the PROD event status to `COMPLETED`
4. Sends a Telegram summary notification
5. Handles errors per-tournament (continues on failure, reports which failed)

Triggered by: `promote.yml` GitHub Actions workflow, dispatched from Telegram `promote <event>` command.

Both CERT and PROD are accessed via the Supabase Management API (`POST /v1/projects/{ref}/database/query`), which requires the `SUPABASE_ACCESS_TOKEN` (org-level token). No direct database connections needed.

After successful promotion, the script **auto-exports seed SQL files** to `supabase/data/{season}/` matching the existing seed file convention. The workflow commits these files to `main` with `[skip ci]` to prevent CI loops. This ensures `supabase db reset` always includes the latest promoted data.

## Alternatives Considered

1. **SQL-only (fn_export + fn_import):** Single JSON blob transferred via bash curl. Rejected: JSON can be 50KB+, bash string handling is fragile, no per-tournament error recovery.
2. **Direct database connection (psycopg2):** Bypasses the Management API. Rejected: port 5432 is blocked on cloud Supabase, requires connection pooling setup.
3. **Supabase REST API (PostgREST):** Use the service_role key to call RPCs directly. Rejected: service_role key is blocked in browser-like contexts (discovered during GAS script testing).

## Consequences

### Positive
- Per-tournament error handling — one failed tournament doesn't block the rest
- Reuses existing `fn_find_or_create_tournament` and `fn_ingest_tournament_results` on PROD
- Telegram progress notification
- No new infrastructure — uses existing Management API access pattern

### Negative
- Requires `SUPABASE_ACCESS_TOKEN` in GitHub Actions secrets (already configured)
- Sequential per-tournament processing (not parallel) — acceptable for 20-30 tournaments
- Management API has rate limits (unlikely to hit for this volume)

---

## Calendar Promote Mode (amendment, 2026-04-20)

### Motivation

The EVF scraper (ADR-028, 3-day cron via `evf-sync.yml`) lands events in CERT as `PLANNED` with URL enrichment (event page, invitation PDF, registration link, venue address, fee). The original per-event promote described above **skips tournaments with zero results**, so upcoming / past-but-unreported EVF events never reach PROD. The PROD public calendar stays weeks behind CERT.

### Decision

Add a new `--mode calendar` to the same `promote.py` script. It is an **additional** mode, not a replacement: the original `--mode event` (default) contract above is untouched.

Calendar mode:

- Reads active-season EVF events (`txt_code LIKE 'PEW%' OR 'MEW%'`) from CERT.
- Reads existing events on PROD for the same season.
- Diff by `txt_code`:
  - **On CERT, not on PROD** → `SELECT fn_import_evf_events(payload, season_id)` on PROD.
  - **On both** → `SELECT fn_refresh_evf_event_urls(payload)` on PROD.
- **Touches tournaments / results / enum_status on PROD never.** The two RPCs are the only write surface.
- Sends a Telegram summary (imported N, refreshed M).

Runs automatically as a second job (`promote-calendar`) in `evf-sync.yml`, `needs: sync`, same 3-day cron.

### Concurrency protection

Both workflows (`promote.yml` + `evf-sync.yml::promote-calendar`) share a GitHub Actions concurrency group:

```yaml
concurrency:
  group: prod-write
  cancel-in-progress: false
```

If an admin dispatches `promote.yml` while the scheduled calendar-promote is running (or vice versa), GitHub queues the second one. `cancel-in-progress: false` because we never cancel a partial PROD write.

### Idempotency backstop

Even if the concurrency group is bypassed (e.g. local `python -m python.pipeline.promote --mode calendar` against PROD while the workflow is mid-flight), the RPCs are safe:

- `fn_import_evf_events` skips events whose `txt_code` already exists.
- `fn_refresh_evf_event_urls` only writes NULL / empty columns — never overwrites admin edits (invariant enforced by pgTAP 12.11).

Worst-case concurrent race converges to the same state as a serial execution.

### Alternatives considered (for calendar mode specifically)

1. **Add a cron to `promote.yml` directly.** Rejected: couples two separate concerns (per-event finalisation vs bulk calendar sync) into one workflow.
2. **Make `evf-sync.yml` write to both CERT and PROD.** Rejected: removes the CERT staging buffer that ADR-011 put there deliberately, and forces the scraper to know PROD credentials.
3. **Postgres advisory locks inside the RPCs.** Rejected as belt-and-braces — the GitHub concurrency group is the correct boundary for workflow-level serialisation; the RPCs' existing idempotency is already the cross-channel backstop.

### Consequences (calendar mode)

- **PROD public calendar stays within 3 days of CERT.** Registration URLs, invitations, fees, and venue addresses land on PROD as soon as the next scrape fires.
- **No new migrations or RPCs.** The two RPCs were already deployed (ADR-028 rev 2).
- **No changes to event-promote.** Existing `--event EVENT_CODE` contract and `promote.yml` body unchanged apart from the concurrency group.
- **Admin edits on PROD are protected.** `fn_refresh_evf_event_urls` only fills NULL/empty columns.
- **pgTAP:** coverage unchanged — 12.1–12.13 already verify both RPCs; same RPCs run on PROD via the Management API.
- **New pytest coverage:** prom.5–prom.7 in `python/tests/test_promote.py` (mocked httpx, no live calls).
