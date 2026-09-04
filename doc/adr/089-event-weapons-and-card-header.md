# ADR-089: The event's weapons live on the event, and the card header carries identity

**Status:** Draft (proposed 2026-09-04; awaiting sign-off)
**Date:** 2026-09-04
**Amends:** [ADR-084](084-calendar-quarter-barrel-event-card.md) §8 (the card's field order and its registry chip), [ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md) (the resolved weapon set now reaches `arr_weapons`, not only the event code)
**Relates to:** [ADR-046](046-pew-weapon-suffix.md) (the weapon-letter suffix this keeps as authoritative), [ADR-088](088-calendar-location-contract.md) (the sibling "resolve it at the source" decision for the city)
**Source:** `supabase/migrations/20260904000001_event_weapons_from_code.sql`, `frontend/src/components/EventCard.svelte`

## Context

The weapon pills were missing from the upcoming `PPW1-2026-2027` card. Not
obscured — never rendered.

`weaponLetters()` derived the set from the trailing `/[efs]+$/` of the event
code. `PPW1` ends in a digit, so it returned an empty list and the block was
omitted. That affected **28 of 97** non-skeleton events: every `PPW`, `MPW`,
`GP`, `IMEW`, `IMSW`, `MSW`, `DMEW` and `VFC` code. The suffix exists to
differentiate EVF events (ADR-046); it was never meant to be the UI's source of
truth for what is fenced.

The obvious repair — read `tbl_event.arr_weapons`, the column that exists for
exactly this — was blocked, because that column was wrong for most EVF events.

### A fill-blank guard that could never fire

Migration 20260327000006 declared the column with a default:

```sql
ALTER TABLE tbl_event ADD COLUMN arr_weapons enum_weapon_type[]
  DEFAULT '{EPEE,FOIL,SABRE}';
```

Migration 20260420000002 then filled it behind a guard:

```sql
arr_weapons = CASE WHEN arr_weapons IS NULL
                     THEN COALESCE(v_weapons, arr_weapons)
                   ELSE arr_weapons END
```

**A column carrying a non-null default is never NULL.** The branch never ran.
The scraper resolves an event's weapons through the ADR-086 evidence ladder and
writes them into the event code, and `evf_sync` has always passed them in the
refresh payload — but they never reached the column.

Measured on CERT: 53 of 69 events whose code carries a weapon suffix sat on the
untouched default, and **35 contradicted their own code**:

```
PEW10e   code=[EPEE]       arr={EPEE,FOIL,SABRE}   tournaments=EPEE
PEW12ef  code=[EPEE,FOIL]  arr={EPEE,FOIL,SABRE}   tournaments=EPEE,FOIL
PEW13s   code=[SABRE]      arr={FOIL,SABRE}        tournaments=SABRE
```

Nothing surfaced it because the wrong value is *plausible*: three weapons is what
a domestic PPW genuinely runs, so the default looked like data. The suffix-less
families really are three-weapon events — all 25 of them with tournaments to
check against read exactly `EPEE,FOIL,SABRE`.

## Decision

### 1 · Drop the default; the guard is fine

The repair is the default, not the guard. Removing it makes `NULL` mean "nobody
has established these", which is what the guard was always written against and
what the column needs in order to distinguish "genuinely all three" from
"untouched". The guard starts working the moment NULL is reachable.

Suffixed events are backfilled from the code, which ADR-046 and ADR-086 make the
authoritative weapon record and which is corroborated: in every one of the 35
disagreements the suffix matched the event's own tournaments and `arr_weapons`
did not.

### 2 · The card reads the field, not the code

`arr_weapons` is the single source for the card's pills. `weaponLetters(code)`
remains for the **barrel tile**, which only ever has a code to work from.

### 3 · Close the create-then-refresh gap

`evf_sync` read its roster *before* `fn_ingest_evf_calendar` created rows, so a
newly created event was absent from the matched pairs the refresh iterates and
waited a full day for its weapons. Harmless while the default made new events
look complete; a visibly empty weapon row once the default is gone. The roster is
now re-read after the ingest, mirroring the existing re-fetch after the
future-COMPLETED heal.

### 4 · The header carries identity; the date gets its own row

Row one becomes `[organizer logo] [weapon pills] · · · [short code]`, and the
date moves to a full-width row of its own.

**The code stays complete — weapon suffix and season both.** Two passes trimmed
it for row width and both discarded real information: `panelLabel()` (built for
the 48px tile, where it also strips `[efs]` and renames PEW to EVF), then the
bare prefix. The suffix is the authoritative weapon record (ADR-046, ADR-086),
and the season is what distinguishes `PPW1` across years on a calendar that
shows every season at once.

**Width is the logo's to absorb.** The card is designed against a 360px width
(~336px of content); the full code is 106px and the date 249px, which is why the
date needed its own row. The logo is the only element in row one that can give
ground without losing meaning — pills and code are text and would truncate
mid-word — so it is the one thing set to shrink. Measured at the 375px viewport:
the SPWS wordmark yields from 80px to 59px and the row fits with no overflow.

**Logos are 18px for wordmarks and 27px for roundels.** SPWS and FIE spend their
pixels on width and stay legible just above the 14px weapon pills; EVF and PZSz
are dense circular marks — a ring of text around a fencer, three crossed weapons
over a flag arc — and needed 1.5x that height to read at all. Height is what a
roundel needs and width buys it nothing, which is why the rule sets both
dimensions rather than a scale factor. An earlier pass put every logo at the registry chip's
own ~14px and failed for exactly the roundels; a pass at 56px was legible but
dominated the row. The logo is also the only shrinkable element in row one —
pills and code are text and would truncate instead, so the SPWS wordmark yields
from 80px to 59px at the 375px viewport rather than letting the code clip.

**All four registries carry a mark**: SPWS, EVF, FIE (`MEW`/`MSW`/`PSW`/`IMEW`/
`IMSW`) and PZSz. `alt` carries the abbreviation, which is now its only
appearance — the registry chip is retired, so `alt` is both the screen-reader
label and the visible fallback when an asset fails.

## Alternatives considered

1. **Read `arr_weapons` without fixing it.** Rejected: it would have printed foil
   and sabre pills on 35 single-weapon events.
2. **Keep deriving from the code and give PPW codes a weapon suffix.** Rejected:
   event codes are identity, carried by registrations and results; renaming every
   domestic event to fix a display concern is disproportionate.
3. **Keep the default and special-case it.** Rejected: "the value equals the
   default" cannot distinguish a real all-three event from an untouched one,
   which is the whole defect.
4. **Rewrite `fn_ingest_evf_calendar` to set `arr_weapons` at creation.**
   Rejected for now in favour of the roster re-read (§3), which closes the same
   gap in three lines instead of replacing a 200-line function.
5. **Logos at chip size, or at 56px.** Both tried and shown; see §4.

## Consequences

**The SPWS asset was a white-background image in an RGBA container** — every pixel fully opaque, half of them pure white — so it painted a white block on the cream card. Its white is now knocked out with a soft ramp across the anti-aliased edge, which also lets the sabre slash through the wordmark show the card behind it, as the mark intends.

**New:** `supabase/migrations/20260904000001_event_weapons_from_code.sql`,
`supabase/tests/71_event_weapons_from_code.sql` (71.1–71.9),
`frontend/public/{EVF,PZSz}-logo.png`, `frontend/public/FIE-logo.svg`.

**Changed:** `EventCard.svelte` (header, logo, pills, date row),
`evf_sync.py` (roster re-read), EC.52–EC.58 added and EC.1, EC.26, EC.27, EC.42,
EC.45 updated to the new contract.

**Nine of the card's twelve blocks are untouched** — name, location, address,
divider, fees, deadline, notes, registration links and the status chip all keep
their behaviour. The edits are row one, the new date row, the registry chip and
the weapons block.

**A regression this decision introduced and then closed.** Dropping the default
briefly meant a newly created EVF event showed *no* pills for up to a day, where
before it showed three wrong ones. §3 closes it. Recorded because "self-healing"
was the first assessment and it was too generous: an empty row is a visible
regression, not a cosmetic lag.

**The backfill is repeated in `seed_post_backfill.sql`.** On a fresh bootstrap —
CI, and `reset-dev.sh` — migrations run BEFORE the seed dump (ADR-036), so the
migration's backfill executes against an empty `tbl_event` and is a no-op; the
dump then loads 48 events whose `arr_weapons` contradicts their own code, because
it is a snapshot of PROD taken before the migration corrects it. CERT and PROD run
the migration directly against populated tables and never reach that file. Test
71.5 caught this in CI while passing locally, which is exactly the asymmetry the
fresh-bootstrap rule exists to surface. Verified by running `reset-dev.sh` and
re-running the suite: 899 assertions pass on a genuinely fresh database.

**Test-shaped guard against the bug class.** 71.3 asserts the column has no
default. The trap is not `arr_weapons` specifically but *any* fill-blank guard
written against `NULL` on a defaulted column, and it is invisible in review
because both halves read correctly on their own.

## Open items

1. **`fn_ingest_evf_calendar` still does not set `arr_weapons` at creation.**
   The roster re-read makes this invisible. **Recommendation:** fold it in when
   that function is next edited for another reason, rather than replacing it now.
2. **EVF and PZSz ship cropped raster.** Both were extracted from wider lockups —
   EVF from the site banner, PZSz from a 224×100 horizontal logo.
   **Recommendation:** ask both federations for vector versions; FIE's SVG shows
   what that buys.
3. **SPWS brand red sits beside the SPWS organizer edge, which is green.**
   Left as-is. **Recommendation:** a judgement call for the association, not one
   to make in code.
