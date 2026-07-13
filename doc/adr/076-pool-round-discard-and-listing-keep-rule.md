# ADR-076: Overlapping FTL listings — discard pool-only rounds, keep one listing per category, flag duplicates (UI-resolvable)

**Status:** Accepted (implemented 2026-06-18, NEW pipeline build). Design in
[archive/legacy-2026-07/ingestion_pipeline_NEW_design.md](../archive/legacy-2026-07/ingestion_pipeline_NEW_design.md) §from-URL discovery.
**Date:** 2026-06-18
**Relates to:** **extends** ADR-067 (pools-only `<Poule>`-no-`<Tableau>` skip) to the from-URL JSON
path; ADR-014/022 (atomic delete-reimport `Commit`, the clobber mechanism); ADR-025 (event-centric
tournament keyed on event·weapon·gender·age_category); ADR-006 (JSONB-in-DB config precedent); ADR-041
(UI → Edge-Function → GitHub-Actions dispatch); ADR-075 (the staging/automation report that surfaces this).

## Context

The from-URL ingest (`ingest_event_from_url`) committed **wrong result counts**. `fn_find_or_create_tournament`
keys a tournament on `(id_event, weapon, gender, age_category)` and `fn_ingest_tournament_results` does
`DELETE FROM tbl_result WHERE id_tournament = …; INSERT …`. The FTL event schedule exposes the **same
competition under several overlapping rounds** — a combined "kat. Veteran" pools round (no DE), per-category
"kat. N" results, and an English-language duplicate ("Men's Épée") — and the pipeline ingested **each**
independently. Every round that resolved into the same `EPEE·M·V0` hit the **same** tournament row and the
**last writer won** (arbitrary, order-dependent). Verified live: `Szpada kat. Veteran`'s split V0 (17), the
single `kat. 0` (12), and `Men's Épée`'s split V0 (7) all wrote `t20214`; the committed count flipped with
schedule order.

## Decision

**There is exactly one source per `gender·weapon·age_category`. The pipeline stays fully automated —
it never stalls and never requires a hand-edited file.**

### Domain logic (the rules, worked through PPW3)

An FTL event lists several rounds. Each round either resolves to one **category** (a **single listing**)
or covers several (a **BRACKET**, split by birth year). Some rounds are **not the scored result** and
must not be ingested. The pipeline resolves every category to **exactly one** source, automatically:

**Rule 1 — drop pools-only rounds.** A round with pool results but **no DE (no Tableau)** is a
qualification phase, never a scored tournament (ADR-067). The XML parser already detected this
(`<Poule>` present & `<Tableau>` absent); the from-URL JSON path gained the equivalent
(`_ftl_has_direct_elimination` — fetch the results page, detect a DE/Tableau round). *PPW3:*
`Szpada kat. Veteran` (76) has no Tableau → **dropped**; the per-age `kat. N` rounds each have one.

**Rule 2 — one source per category** (after Rule 1), in two levels:
- **2a — a dedicated single listing beats a BRACKET.** If a `kat. N` round exists for the category, it is
  the real per-age tournament; keep it and set aside every BRACKET's slice of that category.
- **2b — else the smaller of competing BRACKETs wins.** No single listing + two-or-more BRACKETs over the
  category → ages were combined only because each is small (<5), so the genuine round is the **smaller**
  slice; the **larger** is the amateur/open round → set aside.
- *(Two dedicated single listings for one category = a real anomaly → flagged, nothing auto-committed.)*

A set-aside round is **never silently dropped** — it's recorded with its stats so an admin can see it and,
if the keep-rule guessed wrong, **switch the choice in the event accordion and re-ingest** (one click).

**Worked — PPW3 `EPEE·M`** — event schedule:
[fencingtimelive.com/…/eventSchedule/D099355B…](https://fencingtimelive.com/tournaments/eventSchedule/D099355BC4334343949BD91172023B49)

| FTL round (click → results page) | type | fencers | DE? | outcome |
|---|---|---|---|---|
| [Szpada kat. Veteran](https://www.fencingtimelive.com/events/results/2D5F87282A204AA39BF0B97DB76A9075) | BRACKET V0–V4 | 76 | **no** | **dropped** — Rule 1 (pools-only) |
| [Szpada Mężczyzn kat. 0](https://www.fencingtimelive.com/events/results/EE786DC009914DA2A4182A4632A91B8E) | single V0 | 12 | yes | **kept** → `EPEE·M·V0` |
| [Szpada Mężczyzn kat. 1](https://www.fencingtimelive.com/events/results/248068163F6D48F49953B9589A9227D8) | single V1 | 11 | yes | **kept** → `EPEE·M·V1` |
| [Szpada Mężczyzn kat. 2](https://www.fencingtimelive.com/events/results/2034F718AC554C8D89A639B0EC0984DD) | single V2 | 19 | yes | **kept** → `EPEE·M·V2` |
| [Szpada Mężczyzn kat. 3](https://www.fencingtimelive.com/events/results/177F9E9257374C718E4A1C756F4079FC) | single V3 | 8 | yes | **kept** → `EPEE·M·V3` |
| [Szpada Mężczyzn kat. 4](https://www.fencingtimelive.com/events/results/7D75E3CF201340FB84B1DAC6EA830212) | single V4 | 6 | yes | **kept** → `EPEE·M·V4` |
| [Men's Épée](https://www.fencingtimelive.com/events/results/3CEEF04EF5264CAEB061E428B8B70AA5) | BRACKET V0–V2 | 18 | yes | **set aside** — Rule 2a (dedicated `kat.0/1/2` win); flagged duplicate on V0/V1/V2 (7/3/3) |

Five clean categories, the pool phase dropped, the amateur `Men's Épée` set aside + flagged — **no admin
action needed**. (Rule 2b is not exercised by PPW3, PPW4, or PPW5 — every contested category has a
dedicated `kat. N`, or BRACKETs tile disjoint categories. It stays a safety rule for a rare case.)

### Mechanism (no stall, no scored-data pollution)

- The keep-rule (`_resolve_sources`) computes, per round, the categories it **owns** (`commit_cats`).
  `Commit` writes only its owned categories (`commit_cats` allow-set; absent on the file/XML path ⇒ write
  all — unchanged). One writer per category ⇒ no clobber.
- The discovered rounds + their status (committed / dropped / skipped, with duplicate flags) are written to
  **`tbl_event.json_ingest_sources`** (display-only — **never** in `tbl_result` or any ranking view). The
  admin's skip/process choices live in **`tbl_event.json_source_overrides`** (`fn_set_event_source_override`),
  read by the next ingest. Both JSONB (ADR-006 pattern), exposed on `vw_calendar`.
- The **event accordion** renders the rounds as committed ✅ / dropped ⊘ / skipped ⚠ rows with a
  skip/process toggle; the **Re-ingest** button dispatches `ingest-event.yml` (ADR-041 allowlist). Loop:
  flag → toggle → re-ingest. No files, no CLI.
- The bogus bundled skip reasons are also fixed — an `ELIMINACJE` round is now reported as a *pools-only
  qualifier*, not "DE / amateur / junior / U-age".

## Alternatives considered

- **Auto most-specific-merge / union the rounds.** Rejected: rounds use **incomparable place numbers** (a
  combined round ranks across ages, a single ranks within an age), so merging corrupts the re-rank.
- **Hold a conflicted category (commit nothing) until an admin decides.** Rejected: breaks automation.
- **A separate `tbl_ingest_conflict` table / `SKIPPED` tournament rows.** Rejected: pollutes scored data
  (every ranking view/export would have to exclude them).
- **File-based override + CLI rerun.** Rejected: not automated; the resolution is a UI toggle + one click.
- **A language heuristic ("prefer Polish").** Rejected: arbitrary; size + DE structure decide.

## Consequences

- Each `(id_event, weapon, gender, age_category)` is written by exactly one source — the clobber is gone.
- Clean events (PPW4, PPW5) get **zero intervention**; the messy PPW3 gets the pool round dropped + the
  amateur duplicate flagged — and an admin can override + re-ingest if a default is ever wrong.
- The from-URL path fetches each round's results page (DE check) — a few extra requests per event.
- `url_results` is still admin-managed (never scrape-filled); the accordion source rows are display only.

## Tests

pytest: `_ftl_has_direct_elimination` (N13.1), accurate skip reasons (N13.1), `commit_cats` filter (N13.2),
`_resolve_sources` keep-rule incl. Rule 2b + override (N13.3), staging duplicate flags + per-source split
(N13.5). pgTAP 45.1–45.6 (N13.4): `tbl_event` JSONB columns + `fn_set_event_source_override` + `vw_calendar`
exposure. vitest: accordion source rows + skip/process toggle (N13.6). Dry-run validated live on
PPW3 (drop + flag) and PPW4 + PPW5 (clean, no intervention).
