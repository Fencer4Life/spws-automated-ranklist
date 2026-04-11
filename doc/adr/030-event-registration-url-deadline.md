# ADR-030: Event Registration URL + Deadline

**Status:** Implemented  
**Date:** 2026-04-11  
**Source:** UC21, FR-90, FR-91

## Context

Fencing events typically require pre-registration. Organisers publish a registration URL and often a deadline. Currently `tbl_event` has no fields for registration information — only `url_event` (results) and `url_invitation` (organiser announcement). Participants need to see registration links in the Calendar view before the event starts, and admins need to enter this data via the Admin UI.

## Decision

Store registration URL and deadline as two nullable fields on `tbl_event`. Display conditionally based on date logic. Manual entry only for now; automation deferred to a later enhancement.

### New fields

- `url_registration TEXT` — nullable
- `dt_registration_deadline DATE` — nullable

### Display logic in Calendar View

| `url_registration` | `dt_registration_deadline` | What shows |
|---|---|---|
| set | set | Both deadline + link, **until deadline passes** |
| set | null | Link only, **until dt_start passes** |
| null | set | Deadline text only (no link), **until deadline passes** |
| null | null | Nothing |

Rules:
- **Deadline date** displays if `dt_registration_deadline` is set AND `today <= dt_registration_deadline`
- **Registration link** displays if `url_registration` is set AND `today <= (dt_registration_deadline ?? dt_start)`
- After the relevant date passes, both disappear

### Visual style

2-tier urgency color coding based on days remaining until the cutoff date (`dt_registration_deadline ?? dt_start`):

| Condition | Color | CSS class | Meaning |
|-----------|-------|-----------|---------|
| 7+ days remaining | Dark green `#2e7d32` | (default) | Plenty of time |
| < 7 days remaining | Red `#c33` | `.reg-urgent` | Act soon |

Both the deadline text (`.registration-deadline`) and the registration link (`.registration-link`) change color together — the `.reg-urgent` class is applied to the parent `.timeline-registration` container.

Implementation: `regUrgent` is computed per-event as a `@const` in the `{#each}` block:
```
regCutoff = dt_registration_deadline ?? dt_start
regUrgent = (cutoff - today) < 7 days
```

## Alternatives Considered

1. **Separate registration table** — rejected, overkill for two fields
2. **Store on tournament level** — rejected, registration is per-event not per-tournament
3. **Store deadline as part of URL field (convention)** — rejected, prevents proper date comparison logic

## Consequences

- New migration: `ALTER TABLE`, `vw_calendar` rebuild, CRUD function signature change
- No impact on scoring engine, scrapers, or ingestion pipeline
- Existing seed data unaffected (NULL defaults)
- Future automation (e.g. scraping registration URLs from organiser sites) requires no schema change — just `UPDATE tbl_event SET url_registration = ...`

---

## Implementation Plan

### 1. Spec & RTM Updates

**File:** `doc/Project Specification. SPWS Automated Ranklist System.md`

#### New Functional Requirements (after FR-89)

| ID | Requirement | Source | Tests | Status |
|----|-------------|--------|-------|--------|
| FR-90 | Event registration URL: nullable `url_registration` on `tbl_event`, displayed in Calendar before deadline/start, editable in Admin UI | UC21, ADR-030 | 8.18–8.20, 9.43a–9.43c | Pending |
| FR-91 | Event registration deadline: nullable `dt_registration_deadline` on `tbl_event`, displayed in Calendar until deadline passes, editable in Admin UI | UC21, ADR-030 | 8.18–8.20, 9.43a–9.43c | Pending |

#### Other spec updates
- FR-48: add `url_registration, dt_registration_deadline` to column list ("6 columns" → "8 columns")
- Appendix C — ADR table: add ADR-030 row
- Appendix D — Test Baseline: update counts after implementation (pgTAP +3, vitest +8)

### 2. Database Migration

**New file:** `supabase/migrations/20260411000001_event_registration.sql`

```sql
-- Add registration fields
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_registration TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS dt_registration_deadline DATE;

-- Recreate vw_calendar with new columns
DROP VIEW IF EXISTS vw_calendar;
CREATE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.id_organizer, o.txt_name AS txt_organizer_name,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee, e.txt_entry_fee_currency,
  e.arr_weapons,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  e.url_registration, e.dt_registration_deadline,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code, o.txt_name
ORDER BY e.dt_start ASC;

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;

-- Recreate fn_create_event with new params (appended after p_weapons)
CREATE OR REPLACE FUNCTION fn_create_event(
  p_code TEXT, p_name TEXT, p_id_season INT, p_id_organizer INT,
  p_location TEXT DEFAULT NULL, p_dt_start DATE DEFAULT NULL,
  p_dt_end DATE DEFAULT NULL, p_url_event TEXT DEFAULT NULL,
  p_country TEXT DEFAULT NULL, p_venue_address TEXT DEFAULT NULL,
  p_invitation TEXT DEFAULT NULL, p_entry_fee NUMERIC DEFAULT NULL,
  p_entry_fee_currency TEXT DEFAULT NULL,
  p_weapons enum_weapon_type[] DEFAULT NULL,
  p_registration TEXT DEFAULT NULL,
  p_registration_deadline DATE DEFAULT NULL
) RETURNS INT ...

-- Recreate fn_update_event with new params (appended after p_weapons)
CREATE OR REPLACE FUNCTION fn_update_event(
  p_id INT, p_name TEXT, p_location TEXT, p_dt_start DATE,
  p_dt_end DATE, p_url_event TEXT, p_country TEXT,
  p_venue_address TEXT, p_invitation TEXT, p_entry_fee NUMERIC,
  p_entry_fee_currency TEXT DEFAULT NULL, p_id_organizer INT DEFAULT NULL,
  p_weapons enum_weapon_type[] DEFAULT NULL,
  p_registration TEXT DEFAULT NULL,
  p_registration_deadline DATE DEFAULT NULL
) RETURNS VOID ...

-- REVOKE/GRANT with updated signatures
```

### 3. pgTAP Tests

**File:** `supabase/tests/05_calendar_view.sql` — plan(7) → plan(10)

| Test ID | Assertion |
|---------|-----------|
| 8.18 | `tbl_event` has columns `url_registration` (TEXT) and `dt_registration_deadline` (DATE) |
| 8.19 | `vw_calendar` includes `url_registration` and `dt_registration_deadline` columns |
| 8.20 | `fn_create_event` and `fn_update_event` accept registration params and persist them |

### 4. Frontend Types

**File:** `frontend/src/lib/types.ts`

Add to `CalendarEvent`:
```ts
url_registration: string | null
dt_registration_deadline: string | null
```

Add to `CreateEventParams` and `UpdateEventParams`:
```ts
registration?: string
registrationDeadline?: string
```

### 5. Frontend API

**File:** `frontend/src/lib/api.ts`

Add to `createEvent()` and `updateEvent()`:
```ts
p_registration: params.registration ?? null,
p_registration_deadline: params.registrationDeadline ?? null,
```

### 6. Locale Keys

**Files:** `frontend/src/lib/locales/en.json`, `pl.json`

| Key | EN | PL |
|-----|----|----|
| `event_registration` | `Registration` | `Rejestracja` |
| `event_registration_label` | `Registration URL` | `URL rejestracji` |
| `event_registration_deadline_label` | `Registration deadline` | `Termin rejestracji` |

### 7. Calendar View

**File:** `frontend/src/components/CalendarView.svelte`

Registration block in `timeline-links` section (after invitation link, before entry fee):

```svelte
{@const regCutoff = event.dt_registration_deadline ?? event.dt_start ?? ''}
{@const showRegDeadline = event.dt_registration_deadline != null && today <= event.dt_registration_deadline}
{@const showRegLink = event.url_registration != null && regCutoff !== '' && today <= regCutoff}
{@const regUrgent = regCutoff !== '' && (new Date(regCutoff).getTime() - new Date(today).getTime()) < 7 * 86400000}

{#if showRegDeadline || showRegLink}
  <div class="timeline-registration" class:reg-urgent={regUrgent}>
    {#if showRegDeadline}
      <span class="registration-deadline">
        {t('event_registration_deadline_label')}: {formatDate(event.dt_registration_deadline)}
      </span>
    {/if}
    {#if showRegLink}
      <a class="registration-link" href={event.url_registration} target="_blank" rel="noopener">
        {t('event_registration')} &rarr;
      </a>
    {/if}
  </div>
{/if}
```

Conditions (computed per-event as `@const` inside `{#each}`):
- `regCutoff` = `dt_registration_deadline ?? dt_start` — the date that drives both visibility and urgency
- `showRegDeadline` = `dt_registration_deadline != null && today <= dt_registration_deadline`
- `showRegLink` = `url_registration != null && today <= regCutoff`
- `regUrgent` = `(regCutoff - today) < 7 days` — toggles `.reg-urgent` CSS class on parent container

Color coding:
- Default (7+ days): dark green `#2e7d32` on `.registration-deadline` and `.registration-link`
- Urgent (< 7 days): red `#c33` via `.reg-urgent .registration-deadline` and `.reg-urgent .registration-link`

### 8. Event Manager (Admin Edit Form)

**File:** `frontend/src/components/EventManager.svelte`

New state: `draftRegistration`, `draftRegistrationDeadline`

Two new form fields (in both edit + create forms, after invitation field):
```html
<label>{t('event_registration_deadline_label')}
  <input data-field="form-registration-deadline" type="date" bind:value={draftRegistrationDeadline} />
</label>
<label>{t('event_registration_label')}
  <input data-field="form-registration" type="text" bind:value={draftRegistration} />
</label>
```

Wire into `openCreateForm()`, `openEditForm()`, `handleSave()`.

### 9. Vitest Tests

**CalendarView.test.ts** — +7 tests:

| Test ID | Assertion |
|---------|-----------|
| 8.21 | Registration link + deadline shown when both set and today <= deadline |
| 8.22 | Registration link only shown (no deadline) when URL set and today <= dt_start |
| 8.23 | Registration deadline text shown without link when only deadline set |
| 8.24 | Nothing shown when both null |
| 8.25 | Nothing shown when deadline/dt_start has passed (date in the past) |
| 8.26 | Registration block has `.reg-urgent` class when < 7 days remain |
| 8.26b | Registration block has no `.reg-urgent` class when 7+ days remain |

**EventManager.test.ts** — +3 tests:

| Test ID | Assertion |
|---------|-----------|
| 9.43a | Edit form populates registration URL and deadline from event data |
| 9.43b | Create form has empty registration fields |
| 9.43c | Save includes registration + registrationDeadline in params |

### 10. Development History

**File:** `doc/development_history.md` — add Post-MVP enhancement entry with ADR-030 reference.

### 11. MEMORY.md

Update ADR registry line to include ADR-030.

---

## Execution Order (TDD)

1. **Documentation first:** This ADR, Spec RTM (FR-90, FR-91), Appendix C+D
2. **Write tests (RED):** pgTAP 3 + vitest 10
3. **Run tests → confirm RED**
4. **Implementation:** migration → types → api → locales → CalendarView (+ color coding) → EventManager
5. **Run tests → confirm GREEN**
6. **Update test baseline** (pgTAP 239, vitest 212, total 727)
7. **Update development_history.md + MEMORY.md**

## Files Modified (Summary)

| File | Change |
|------|--------|
| `doc/adr/030-event-registration-url-deadline.md` | NEW — this ADR |
| `doc/Project Specification. SPWS Automated Ranklist System.md` | FR-90, FR-91 in RTM; FR-48 update; Appendix C+D |
| `doc/development_history.md` | Post-MVP enhancement entry |
| `supabase/migrations/20260411000001_event_registration.sql` | NEW — schema + view + CRUD (drops old overloads) |
| `supabase/tests/05_calendar_view.sql` | +3 assertions (8.18–8.20) |
| `frontend/src/lib/types.ts` | CalendarEvent + Create/UpdateEventParams |
| `frontend/src/lib/api.ts` | createEvent + updateEvent params |
| `frontend/src/lib/locales/en.json` | 3 new keys |
| `frontend/src/lib/locales/pl.json` | 3 new keys |
| `frontend/src/components/CalendarView.svelte` | Registration block with date logic + 2-tier color coding |
| `frontend/src/components/EventManager.svelte` | 2 new form fields + state + handlers |
| `frontend/tests/CalendarView.test.ts` | +7 tests (8.21–8.26b) |
| `frontend/tests/EventManager.test.ts` | +3 tests (9.43a–9.43c) |
| `scripts/reset-dev.sh` | NEW — local DB reset + admin user recreation |
