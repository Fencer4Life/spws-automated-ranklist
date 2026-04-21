# ADR-025: Event-Centric Ingestion + Telegram Admin Interface

**Status:** Accepted  
**Date:** 2026-04-05  
**Relates to:** ADR-022 (Ingestion DB Transaction), ADR-023 (Email Ingestion via GAS), ADR-024 (Combined Category Splitting)

## Context

The initial ingestion pipeline (ADR-022/023) routes XML files to tournaments by matching weapon+gender+category+date globally. This has several problems:

1. **No event awareness** — the pipeline doesn't know which event an XML belongs to. Multiple events on the same date would cause ambiguous matches.
2. **Tournaments must pre-exist** — but we don't know which weapon/gender/category combinations will appear until XML files arrive. Tournament creation should be automatic.
3. **No lifecycle management** — events receive XML data over 2-3 days across multiple emails. There's no way to track which events are partially imported, fully imported, or ready for promotion to PROD.
4. **No admin control** — no way to rollback wrong imports, confirm completion, or promote to PROD without direct database access.
5. **Auto-delete of staging files** — files are deleted immediately after processing with no admin review opportunity.

## Decision

### 1. Event-Centric Ingestion

Ingestion anchors to **pre-existing events**, not tournaments:

- Events must exist in the DB before ingestion (they represent scheduled competitions in the calendar).
- The pipeline matches XML metadata `Date` to `tbl_event.dt_start` in the active season.
- If no event matches → reject the XML ("no event scheduled for this date").
- **Tournaments are created on-the-fly** under the matched event from XML metadata (weapon, gender, category). Auto-generated `txt_code` follows the pattern `{event_code}-{category}-{gender}-{weapon}-{season}`.
- Re-imports of the same tournament are idempotent (delete+insert per ADR-014).

### 2. Event Status Lifecycle

```
PLANNED → IN_PROGRESS → COMPLETED → (promoted to PROD)
    ↑          |
    └──────────┘  (rollback)
```

- `PLANNED` → event in calendar, no ingestion data.
- `IN_PROGRESS` → at least one tournament has been ingested. May receive more XMLs over multiple days/emails.
- `COMPLETED` → admin confirms via Telegram that all expected data has been received.
- Rollback → admin triggers via Telegram. All ingestion-created tournaments and results under the event are deleted. Event returns to `PLANNED`.

The pipeline automatically transitions `PLANNED → IN_PROGRESS` on first successful ingest. All other transitions require explicit admin action.

### 3. Telegram Admin Command Interface

The existing GAS script (ADR-023) is extended with a `checkTelegramCommands()` function that polls the Telegram Bot API `getUpdates` endpoint every 5 minutes (same trigger as email polling).

Commands use **prefix matching within the active season**: `rollback PPW4` matches any event whose `txt_code` starts with `PPW4` in the active season.

17 commands across 6 categories:

- **Lifecycle:** `status`, `complete`, `rollback`, `delete`, `promote`
- **Data review:** `results`, `pending`, `missing`
- **Storage:** `cleanup`, `staging`
- **Season:** `season`, `ranking`
- **Emergency:** `pause`, `resume`
- **Admin:** `help`

`delete` is stricter than `rollback`: it wipes the child tournaments + results AND removes the `tbl_event` row itself. Use when an event was created in error (wrong-ingest, erroneous scrape, dedup-bug phantom row). Backed by the `fn_delete_event(prefix)` RPC (amendment 2026-04-21). `rollback` remains the safer default when you only want to re-ingest.

### 4. CERT → PROD Promotion

Promotion is triggered via Telegram (`promote PPW4`) and executed by a GitHub Actions workflow (`promote.yml`). The workflow reads event data from CERT via the Supabase Management API and writes it to PROD. Tournaments are created on PROD if they don't exist.

### 5. No Auto-Delete of Staging Files

Staging files are NOT automatically deleted after processing. The admin reviews results (via Telegram or web UI) and explicitly triggers cleanup via the `cleanup` Telegram command or the Supabase Dashboard.

## Alternatives Considered

1. **Tournament-centric ingestion (current)** — requires tournaments to pre-exist. Rejected: we don't know tournament compositions until XML files arrive.
2. **Webhook-based Telegram interaction** — requires a persistent server to receive Telegram webhooks. Rejected: adds infrastructure complexity. GAS polling every 5 min is sufficient for admin commands.
3. **Auto-complete events after N hours** — rejected: impossible to know when all emails have arrived. Only the admin knows.
4. **Direct PROD ingestion** — rejected: no review step. CERT-first allows validation before affecting production rankings.

## Consequences

### Positive
- Events serve as natural grouping for multi-day, multi-email ingestion.
- Admin has full control over the ingestion lifecycle from their phone via Telegram.
- Rollback is safe and complete — deletes all ingestion artifacts under the event.
- CERT → PROD promotion provides a review gate before production changes.

### Negative
- Two-event date collision requires manual resolution (delete/reschedule one event temporarily).
- 5-minute polling latency for Telegram commands (acceptable for admin operations).
- GAS script complexity increases (email polling + Telegram command handling).

### Note (ADR-031)
"Active season" references in this ADR (lines 24, 48) are now auto-derived from season dates rather than manually set. Behavior is unchanged — `WHERE bool_active = TRUE` still resolves to the correct season, but activation is automatic per ADR-031.

### Amendment 2026-04-21 — `fn_delete_event` RPC + Telegram `delete` command (FR-95)

**Problem** — `fn_rollback_event` wipes child tournaments + results and resets the event to `PLANNED`, but leaves the `tbl_event` row in place. When an event was created in **error** (wrong-ingest, erroneous scrape, dedup-bug phantom row like the three EVF duplicates cleaned up earlier on 2026-04-21), rollback-only leaves an orphan row the admin must then hand-delete via direct SQL. That two-step dance is not captured anywhere durable — every operator reinvents it.

**Decision** — Add a single transactional RPC:

```sql
fn_delete_event(p_prefix TEXT) RETURNS JSONB
-- 1. Resolve prefix to id_event in active season (same helper as fn_rollback_event)
-- 2. For every child tournament: fn_delete_tournament_cascade(id)
-- 3. DELETE FROM tbl_event WHERE id_event = v_event_id
-- Returns: {status: "DELETED", event_id, event_code, tournaments_deleted,
--          results_deleted, event_deleted: TRUE}
```

Same permission model as `fn_rollback_event` (REVOKE anon, GRANT authenticated). Migration: `20260421000001_fn_delete_event.sql`. Tests: `10.29–10.32` in `supabase/tests/10_ingest_pipeline.sql`.

**When to use `delete` vs `rollback`:**

| Situation | Command | Effect |
|---|---|---|
| Re-ingest same event with corrected source | `rollback` | Wipes results, event row + children stay, can re-ingest |
| Event was created in error (wrong code, phantom row, scraper dedup bug) | `delete` | Wipes everything including the event row; must re-create via calendar scraper or CRUD |

**Telegram surface** — New `delete <prefix>` command alongside the existing `rollback`. Routes to `fn_delete_event` via the same GAS polling path. Counted in the Lifecycle category of UC27 (brings the total to 17 commands).

**Historical** — This tool should have been built on 2026-04-20 during the PEW7 + EVF duplicate cleanup, when the two-step `fn_rollback_event` + manual `DELETE FROM tbl_event` sequence was used three times in the same session. It wasn't, so it's captured here retroactively as a durable artifact rather than living in ad-hoc scripts.
