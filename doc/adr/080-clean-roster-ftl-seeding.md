# ADR-080: Clean-Roster FTL Seeding

**Status:** Accepted (target design — committed direction for domestic SPWS events; rollout in progress. Phase 3 seed export partial; organizer delivery and scrape-back wiring pending — see spec §5.2 for phase status.)
**Date:** 2026-07-04
**Source:** Event Registration & Clean-Roster Seeding subsystem (spec §5.2); ADR-078, ADR-079

## Context

"FTL" is **Fencing Time** (results at fencingtimelive.com), the software the
organizer runs. A domestic SPWS event is run as, per weapon, one **mix-all pool
round** (two pool rounds, all competitors together — the `ELIMINACJE` file) feeding
per-category **DE brackets** seeded from the final pool table. The DE brackets are
what we scrape and rank. Today the scraped results expose only
`name · place · country` (plus an FTL-internal per-entry id) — **no birth date, no
gender, no stable key** — so the only scrape-back join key is the **name**, and
bracket naming/category-combining is wildly inconsistent between events (a co-equal
cause of the ~90 % automation ceiling).

Registration (ADR-079) lets us **generate the event's competition set ourselves**
with clean, exact, unique names — closing the loop so scrape-back is an exact-name
match and the operator no longer hand-names 27 brackets differently each event.

Verified empirically (2026-07-03, FTL v4.5.4, real PZS files in
`doc/external_files/`): the native format is **FIE-XML** `<BaseCompetitionIndividuelle>`
— the FIE-standard interchange XML that FTL imports — (one file = one competition),
and a round-trip test confirmed our per-fencer
category marker and synthetic birthdate survive import → pools → DE → export.

## Decision

Generate **FIE-XML seed files** (the FIE-standard XML imported by FTL) from all
**declared** registrations (this system does not track payment completion digitally —
see ADR-079 §4) and deliver them to the organizer on demand.

### 1. Seed format

- One `<BaseCompetitionIndividuelle>` XML **per competition**: the mix-all pool per
  weapon + one per gender×category DE bracket (single or predicted-combined).
- `<Tireur>` attributes: `Nom`, `Prenom`, `Sexe`, `Nation="POL"`, `ID`, `Classement`
  (seed). `Club=""` and `Licence=""` (not collected). `Lateralite` omitted (FTL
  accepts import without it).
- **Canonical name form:** `Nom` = surname in **UPPERCASE**, `Prenom` = given name in
  **Title case** (e.g. `Nom="KOWALSKI" Prenom="Jan (2)"`) — the same casing used in the
  entry list and the ranklist; normalised on export (fixes legacy all-caps given names).
- **Omit `DateNaissance`.** With a birth date present, FTL infers/enforces an age
  category; without it FTL leaves the age unset for the operator. The authoritative
  BY lives only in our DB (ADR-079); the seed carries none.
- **Per-fencer category marker `(N)`** (digit 0–4) appended to `Prenom` → renders
  and scrapes back as `NOM Prenom (N)`; `python/scrapers/ftl.py` already strips it.
  **Gender is NOT in the marker** — it is the structural `Sexe` attribute and the
  bracket itself; the K/M prefix idea is dropped. Since DOB is omitted, `(N)` is the
  operator's only visible category cue when splitting the mix-all pool (gender read
  from FTL's `Sexe` column). The marker is a cross-check only — ingestion splits by
  the authoritative declared BY (`age_split.py`), so it is not load-bearing.

### 2. Mix-all pool seeding — interleave ("snake by rank") across the 10 sub-rankings

The mix-all pool file lists every competitor of one weapon (both genders, all
categories). The seeding order — written to `Classement` (1..N) and used as the
`<Tireur>` element order — is a **round-robin by rank position** across the ten
domestic sub-rankings, in this **fixed** order:

`FV0, FV1, FV2, FV3, FV4, MV0, MV1, MV2, MV3, MV4`

Exact algorithm:

```
seed = 1
for r in 1, 2, 3, …:                       # rank position within each sub-ranking
    for sub in [FV0,FV1,FV2,FV3,FV4,MV0,MV1,MV2,MV3,MV4]:   # this fixed order
        if sub has a fencer at rank r:      # empty / exhausted sub-rankings skipped
            emit(fencer, Classement = seed)
            seed = seed + 1
```

In words: lay down the **1st-placed** fencer of every live sub-ranking (all five
women's categories first, then all five men's), then every **2nd-placed** fencer,
and so on until all ten sub-rankings are exhausted — so category leaders are spread
evenly across the pool seeding. The standings are the current-season domestic
ranking `fn_ranking_ppw(weapon, gender, category, season)`, joined to `tbl_fencer`
for the **canonical name** (§1) + birth year (birth year is used only to compute the
`(N)` marker; it is **not** emitted as `DateNaissance`).

Worked example — EPEE, season 2025-2026, real LOCAL data, first seeds:

| Seed (`Classement`) | Sub-ranking | Fencer (canonical + `(N)`) |
|---|---|---|
| 1 | FV0 #1 | `PĘCZEK Sandra (0)` |
| 2 | FV1 #1 | `KAMIŃSKA Gabriela (1)` |
| 3 | FV2 #1 | `WASILCZUK Beata (2)` |
| 4 | FV4 #1 | `BORKOWSKA Halina (4)`  ← FV3 empty, **skipped** |
| 5 | MV0 #1 | `SPŁAWA-NEYMAN Maciej (0)` |
| 6–9 | MV1…MV4 #1 | first-placed men of each category |
| 10 | FV0 #2 | `SZMAJDZIŃSKA Katarzyna (0)` |
| 11 | FV1 #2 | `SAMECKA-NACZYŃSKA Martyna (1)` |

Validated end-to-end on LOCAL: the EPEE mix-all resolves to **119 fencers, 0 NULL
birth years, FV3 (empty) correctly skipped**.

#### Implementation note — population vs ordering (2026-07-05)

The 119-fencer validation above used the **full season ranking** as the population
(a pre-registration proof: registration data did not yet exist). In production the
**population is the event's declared registrations** (`tbl_registration`, every row,
no payment gate — ADR-079 §4 / user 2026-07-04: *"the correct list of names which
declared intent to participate"*); the ranking supplies only the **ordering** inside
each sub-ranking. So a registrant who is matched + ranked seeds in `fn_ranking_ppw`
rank order; an unranked registrant (a brand-new fencer, or matched-but-never-scored)
appends after the ranked ones, ordered by registration timestamp (`ts_created`) for
a deterministic result. The `(N)` marker is derived from the registration's
**declared** birth year (read-only invariant), not `tbl_fencer`'s. Built as
`ftl_seed_export.assemble_mixall_subrankings` + `build_event_mixall_files` (pure) and
`ftl_seed_export_db.FtlSeedExporter` (Supabase glue).

**Reference artefacts — DO NOT LOSE.** The validated, ready-to-import example files
live in the repo at:
- `doc/external_files/FTL_SRC/SPWS_ppw_epee_mixall.xml` — with `Categorie="V"`;
- `doc/external_files/FTL_SRC/SPWS_ppw_epee_mixall_noCat.xml` — `Categorie` omitted;
- `doc/external_files/FTL_SRC/SPWS_ppw_epee_mixall_noBY.xml` — **the chosen variant**
  (no `DateNaissance`, §1), 119 `<Tireur>` in the interleave order above.

The round-trip that proved the `(N)` marker + synthetic birthdate survive import →
pools → DE → export is captured in `doc/external_files/FTL_OUT/` (FTL v4.5.4). The
generator is the `fn_ranking_ppw` + `tbl_fencer` join implementing the algorithm
above.

### 3. Predicted combined DE brackets (T = 4)

Per weapon × gender (**genders never merged**), order V0→V4, skip empties,
accumulate left-to-right; close a bracket once its running count ≥ **T = 4**; fold a
trailing sub-T bracket into the previous one. Yields adjacent, ascending combined
brackets matching the organizers' observed conventions (`v0v1`, `v3v4`). Combining
is ultimately an on-the-day decision, so predictions may be overridden — but
ingestion splits *any* combined bracket by BY regardless (`split_combined_results`,
ADR-024), so a wrong prediction is self-correcting.

### 4. File naming

`<season>_<eventcode>_<weapon>_<scope>.xml` — `<weapon>` = `E|F|S` (FIE `Arme`);
`<scope>` = `mixall` (both genders, all cats) or `<G>-<cat>` for a DE bracket
(`M-V2`, combined `M-V0V1`, `F-V3V4`). Root `ID` = the filename stem. Examples:
`SPWS-2025-2026_PPW5_E_mixall.xml`, `SPWS-2025-2026_PPW5_E_M-V0V1.xml`.

### 5. Delivery — on-demand email to the organizer

`tbl_event.txt_organizer_email` holds the address (from the invitation letter,
admin-entered). A single action **`send_seed_to_organizer(event)`** — generate-at-
send from all **declared** registrations (no payment gate — see ADR-079 §4) → email
the zip → stamp `ts_ftl_sent` — is fired by three triggers (DRY, one implementation):

| Trigger | Actor | Notes |
|---|---|---|
| Manual button in `EventManager.svelte` ("Organizator" section) | Admin only (GoTrue+MFA; fn REVOKEd from `anon`) | re-sendable any time |
| Cron when `dt_registration_deadline` passes | System | closing roster; reuses daily-cron infra |
| Telegram `send <EVENT_CODE> participants` (doc/gas/Code.gs) | Allowlisted user (≈ admin) | phone-friendly day-of trigger; renamed from an earlier `/seed` draft to avoid colliding with the existing DB-backup `export-seed` command |

**Generate-at-send** (never a pre-stored attachment) keeps every send fresh despite
late/day-of entries. Requires a new email/SMTP capability (current outbound is
Telegram alerts only). The roster is personal data sent to a recipient (organizer),
recorded in the ADR-078 ROPA.

**UI constraint (add-only).** The manual button + the new event fields
(`txt_organizer_email`, `ts_ftl_sent`, fee tiers, `url_entry_list`,
`bool_use_spws_registration`) are added to the existing `EventManager.svelte` (the
Event Edit Form) as an **isolated new section** — no existing field, binding, RPC
call, or layout is altered, reordered, or removed; existing `vitest` + `svelte-check`
stay green before and after.

### 6. Ingestion (unchanged writers)

Scrape-back matches the exact seeded name → the registration's declared BY →
existing reconciliation (ADR-079 §1). Per-category DE brackets give final places
directly; the mix-all pool is pools-only and not ranked.

## Consequences

- The seed exporter is a **new** `python/pipeline` module — `export_seed.py` is the
  unrelated ADR-036 whole-database backup exporter (confirmed 2026-07-04; also owns the
  `export-seed` Telegram command, hence the FTL-seed Telegram trigger is named
  `send <code> participants` instead). Reuses `age_split.py` splitting (`split_combined_results`,
  `birth_year_to_vcat`) and `fuzzy_match.py`'s `canonicalize_scraped_name`.
- Standardised naming removes the free-text bracket-parsing failure class; clean
  round-trip removes BY estimation for registered fencers.
- Roll out **pilot-first** (one upcoming PPW, validate register→seed→FTL→scrape→
  ranklist) before enabling the season; per-event `bool_use_spws_registration`
  allows event-by-event migration off competit.pl.

## References

- ADR-078 (GDPR / organizer recipient), ADR-079 (registration/identity), ADR-024
  (combined-category splitting), ADR-056 (BY→V-cat), ADR-065 (FTL marker), ADR-066
  (min-participants/walkover), ADR-027/036 (seed export), ADR-030 (registration URL).
