# ADR-088: One location contract for every calendar scraper — city, venue and address

**Status:** Draft (proposed 2026-09-04; awaiting sign-off)
**Date:** 2026-09-04
**Amends:** [ADR-028](028-evf-calendar-results-import.md) (closes the recorded `txt_location` defect at the ingest, where that ADR left it), [ADR-039](039-stale-event-gate.md) §dedup (the location rung now compares cities to cities), [ADR-087](087-pzsz-senior-calendar-source.md) §7 (PZSz gains venue-title extraction from the komunikat)
**Relates to:** [ADR-084](084-calendar-quarter-barrel-event-card.md) (the tile and card that consume this), [ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md) (the evidence-ladder idiom this reuses)
**Source:** `python/scrapers/_location.py`, `python/tests/test_location.py`

## Context

`tbl_event.txt_location` is specified to hold a **city**. The EVF scraper has been
writing the source's **venue title** into it — `Palavesuvio`, `Salle Jean Zay`,
`Sporthalle der Städtischen Berufsschule für Informationstechnik` — since the
calendar import was built.

ADR-028 recorded this openly and declined to fix it:

> `txt_location` in CERT holds a venue where a city belongs, and the card demotes
> such a value to the address line rather than printing it as a city. That is a
> **rendering** accommodation of a data defect, not a fix — the defect stays
> recorded against the ingest.

The accommodation was `calendarMonths.ts:splitLocation()`, a render-time guess at
venue-vs-city. It was removed from the barrel tile on 2026-09-04 because a guess
that fails prints a hall name into a 48px tile. That removal is correct and it
makes the underlying defect visible: ten active-season EVF events render with no
city at all. **This ADR fixes the defect where ADR-028 left it — at the ingest.**

### What the sources actually publish

Both calendar sources publish the same three things, in different places and
shapes:

| | EVF | PZSz |
|---|---|---|
| City | event name, `– <City> (<CC>)` | listing `Miejsce` column |
| Venue title | `.tribe-…-event-venue-title` | komunikat `Miejsce Zawodów :` line |
| Street address | `.tribe-…-event-venue-address` | komunikat `ul./al.` line |

Measured 2026-09-04 against the live EVF calendar (18 events) and both committed
fixtures (21 events), plus all 67 EVF and 6 PZSz rows on CERT.

### The event name is EVF's best evidence, and often its only evidence

| event name → city | postal address → city |
| --- | --- |
| `– Lausanne (SUI)` → **Lausanne** | …, **Prilly**, Switzerland ✗ |
| `– Stockholm (SWE)` → **Stockholm** | …, **Bromma**, Sweden ✗ |
| `– Naples (ITA)` → **Naples** | …, Napoli, **NA**, Italy ✗ |
| `– Chania, Crete (GRE)` → **Chania** | …, Chania, **Crete**, Greece ✗ |
| `– Athens (GRE)` → **Athens** | *no address at all* |
| `– Tampere (FIN)` → **Tampere** | *no address at all* |
| `Critérium de Paris 2026` → *no separator* | …, **Paris**, France ✓ |
| `European Championships 2025` → *no separator* | …, **Plovdiv**, Bulgaria ✓ |

The name wins every disagreement because it is EVF's own editorial choice of the
city a fencer recognises: Lausanne rather than the neighbouring municipality of
Prilly, Stockholm rather than the suburb of Bromma, the exonym Naples rather than
Napoli. The address is not redundant — it is the only thing that rescues the two
names carrying no separator.

## Decision

### 1 · The city is resolved once, at scrape time

A guess made at render time is made again on every page load, cannot be corrected
by an admin, and has no access to the event name or the country. Resolution moves
into the scraper, and `txt_location` holds a real city.

`calendarMonths.ts:splitLocation()` **stays** as the render-time safety net for
admin-entered values and legacy rows. It becomes near-no-op for scraped data.

### 2 · A shared contract, source-specific rungs

`python/scrapers/_location.py` owns what is common: city normalisation, what
disqualifies a string from being a city (`looks_like_venue`), and the venue rule.
Each scraper supplies its **own ordered rungs**, because they read different
pages.

Running one source's rungs against the other produces nonsense, and this is not
hypothetical: PZSz addresses are street-only (`ul. Siennicka 40B`, no city, no
country), so EVF's address rung would return the street as the city. PZSz names
use an ASCII hyphen and end in a season (`… - Poznań 2026/2027`), which EVF's
name rung deliberately refuses to split on.

**EVF rungs:** event name → postal address → venue title (only when it is not
venue-shaped) → blank.
**PZSz rungs:** listing `Miejsce` → blank. `Miejsce` is authoritative and clean —
6 of 6 verified — so no fallback has ever been needed.

### 3 · Only en and em dashes separate a name

`–` and `—`, never the ASCII `-`. This is load-bearing rather than fussy:
`Fâches-Thumesnil` is one city containing a hyphen, and `IMEW-2026-2027` is a bare
event code. Splitting on `-` yields `Thumesnil` and `2027`.

### 4 · The final address part is dropped only when it IS the country

"Always drop the last part" destroys `Ul. Stanisława Staszica 2, 05-092 Łomianki`,
which carries no country and whose city is therefore last. The scraped country is
compared, diacritic-folded, before anything is discarded. A two-letter all-caps
administrative code (`NA` for Napoli) is skipped; a leading postcode is stripped.

### 5 · The venue title's fate

- **Address present → the venue title is dropped.** It is already invisible in the
  UI whenever an address exists (`EventCard.svelte` renders `txt_venue_address`
  and only falls back to the venue when that is blank), and the addresses usually
  already name the venue: `Palavesuvio ingresso carrabile, Napoli, NA, Italy`.
- **Address blank → the venue title becomes the address**, so the only piece of
  location detail available is not discarded.
- **Guard: unless the venue title IS the city.** Every EVF row that currently has
  no address holds a *city* in its venue field (`Samorin`, `Jabłonna`, `Napoli`,
  `Plovdiv` — 15 rows). Without the guard the city would be copied into the
  address and the card would print the same word twice.

### 6 · Never guess

A string that cannot be resolved leaves `txt_location` empty. `Levi Open (FIN)`
carries no separator, no venue and no address; blank is the honest answer and the
tile simply omits the line (ADR-084).

### 7 · No migration

`txt_location` is source-owned — `fn_sync_evf_event_fields` does
`txt_location = COALESCE(NULLIF(v_upd->>'location',''), txt_location)` — so a
corrected scrape **overwrites** the bad value. All ten venue-polluted rows are in
the active season and self-heal on the next `evf-sync` run.
`txt_venue_address` is fill-blank-only, which is exactly right for §5: blank rows
gain the venue title, populated rows are never touched. `txt_location` is already
in `promote.py`'s create and update payloads, so the correction reaches PROD
unaided.

## Alternatives considered

1. **Keep guessing at render time, and improve `splitLocation()`.** Rejected: the
   renderer cannot see the event name or the country, which is where the good
   evidence is, and it re-guesses on every page load with no way for an admin to
   correct the result.
2. **Take the city from the postal address only.** Rejected: wrong in four
   measured cases (Prilly, Bromma, NA, Crete) and unavailable in five more, where
   the event has no address at all.
3. **Take the city from the event name only.** Rejected: `Critérium de Paris 2026`
   and `European Championships 2025` carry no separator and would go blank
   despite having a perfectly good address.
4. **One shared ladder for both scrapers.** Rejected: PZSz's street-only addresses
   and ASCII-hyphenated names make EVF's rungs actively wrong there (§2). The
   contract is shared; the rungs cannot be.
5. **A new `txt_venue_name` column.** Rejected as disproportionate: a migration, a
   promote-path field and card UI work to surface a string that is usually already
   inside the address.
6. **Backfill the historical seasons by migration.** Rejected as unnecessary: the
   defect is confined to the active season, which re-scrapes (§7).

## Consequences

**New:** `python/scrapers/_location.py`, `python/tests/test_location.py`
(loc.1–loc.20).

**Changed:** `evf_calendar.py` (both the HTML and API paths),
`pzsz_calendar.py` (komunikat venue-title extraction, defensive city
normalisation), `pzsz_sync.py` (enrichment uses the shared rule),
plus evf.65–evf.68 and pzsz.35–pzsz.38.

**PZSz behaviour changes**, contrary to the first reading that it was already
compliant. It never extracted a venue title at all, so the komunikat's
`Miejsce Zawodów` hall name was read and discarded. It is now subject to §5 like
EVF's. The city path is unchanged in output — `Miejsce` was already clean — but
now passes through the shared normaliser.

**ADR-039's dedup rung is affected.** The MEDIUM location rung compares
`fuzz.token_set_ratio` of scraped location against `txt_location` when country is
missing. Both sides now converge on cities rather than one holding a venue, which
makes the rung *more* accurate, not less. During the single run where CERT still
holds venues and the scrape supplies cities the rung is weaker — but country is
present on every affected row, so the STRONG rung decides them and the MEDIUM rung
is never reached.

**Verified against live data, not only fixtures.** The live EVF calendar (18
events) resolves with zero venue strings remaining and every city correct,
including the five previously blank. The PZSz dry run is a no-op: 0 creates,
0 updates.

## Open items

1. **`Levi Open (FIN)`** resolves blank — it has no separator, no venue and no
   address. **Recommendation:** leave it. Inventing "Levi" from the title would
   set a precedent for parsing arbitrary words out of event names.
2. **`splitLocation()` retirement.** It is now a safety net for legacy and
   admin-entered rows only. **Recommendation:** keep it until the historical
   seasons are known clean, then reconsider — it costs nothing where it never
   fires.
