# ADR-080: Clean-Roster FTL Seeding

**Status:** Accepted (mix-all export and organizer delivery implemented; CERT pilot pending. Per-bracket DE export and scrape-back wiring remain deferred — see spec §5.2. Amended 2026-09-12: marker moves mid-name, §3's combined-bracket prediction dropped, §4's naming replaced, roster file and club added, public download page. Built 2026-09-12: the marker owner, the new naming, the maximal DE split, the public projection, the roster file and the download page (capability-gated, multi-event, bilingual); the club remains pending. See the amendment and ADR-093.)
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
late/day-of entries. The roster is personal data sent to a recipient (organizer),
recorded in the ADR-078 ROPA.

**Implemented delivery contract (2026-07-13).** `ftl-seed.yml` invokes
`python.pipeline.ftl_feed_seed_send`, builds the current mix-all bundle entirely in
memory, and sends it as the SPWS Gmail account over `SMTP_SSL` to
`smtp.gmail.com:465` with certificate and hostname verification. It stamps
`ts_ftl_sent` through service-role-only `fn_mark_ftl_sent` only after SMTP accepts
the recipient. SMTP failure therefore never stamps. If SMTP succeeds but the stamp
fails, the run fails visibly and a retry may duplicate the message: delivery is
deliberately **at-least-once**, not exactly-once. Manual UI/Telegram triggers are
explicit re-sends; the daily sweep selects only unstamped, live events whose cutoff
has passed and skips empty bundles. The scheduled PROD job ships disabled and runs
only when repository variable `ENABLE_FTL_DEADLINE_SEND=true` after the CERT pilot.

<svg viewBox="0 0 760 190" role="img" aria-label="FTL organizer delivery flow" style="width:100%;height:auto;color:var(--ink,#17202a)">
  <defs><marker id="ftl-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent,#b64b32)"/></marker></defs>
  <g fill="var(--surface,#fff)" stroke="var(--line,#cad0d8)" stroke-width="2">
    <rect x="10" y="18" width="135" height="42" rx="9"/><rect x="10" y="74" width="135" height="42" rx="9"/><rect x="10" y="130" width="135" height="42" rx="9"/>
    <rect x="205" y="62" width="145" height="66" rx="9"/><rect x="410" y="62" width="145" height="66" rx="9"/><rect x="615" y="62" width="135" height="66" rx="9"/>
  </g>
  <g fill="currentColor" font-family="system-ui,sans-serif" font-size="13" text-anchor="middle">
    <text x="77" y="44">Admin button</text><text x="77" y="100">Telegram command</text><text x="77" y="156">Gated daily sweep</text>
    <text x="277" y="88">ftl-seed.yml</text><text x="277" y="108">CERT / PROD</text>
    <text x="482" y="83">Fresh in-memory ZIP</text><text x="482" y="103">Gmail SMTP_SSL</text><text x="482" y="119">then success stamp</text>
    <text x="682" y="88">Organizer inbox</text><text x="682" y="108">+ Telegram status</text>
  </g>
  <g fill="none" stroke="var(--accent,#b64b32)" stroke-width="2" marker-end="url(#ftl-arrow)"><path d="M145 39 L205 82"/><path d="M145 95 L205 95"/><path d="M145 151 L205 108"/><path d="M350 95 L410 95"/><path d="M555 95 L615 95"/></g>
</svg>

Credentials remain server-side in GitHub Actions secrets. The Gmail App Password is
independently revocable but is still a high-value account credential: never log or
persist it, and rotate it on suspected exposure. This solves organizer delivery
only; ADR-079's public OTP-email problem is a distinct, higher-volume capability and
remains out of scope.

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
- Delivery is intentionally at-least-once. An SMTP-accepted/stamp-failed run can
  duplicate on retry; exact-once delivery would require a durable attempt/lease
  model and is not justified for the current one-recipient operational volume.

## Amendment (2026-09-12 — the organizer downloads the files; marker moves mid-name)

Accepted with the plan `doc/plans/ftl-xml-export-2026-09-12.html`. **Implementation
status: only the identity block is built** (see [ADR-093](093-registration-as-birth-year-source.md));
items (a) to (f) below are decided and not yet implemented, and this section is a record
of the decision, not a description of the system. §§1, 2, 5 and 6 stand — the FIE-XML
format, the snake interleave, organizer delivery and the ingestion writers are unchanged.

### (a) Context correction — the scrape does expose a club

§Context states the scraped results expose *"only `name · place · country`"*. That is
wrong, and has been since it was written. The Fencing Time results JSON returns
`clubs`, `club1` and `club2` per fencer; `parse_ftl_json` simply never reads them
(verified against live FTL, 2026-09-12). Nothing downstream depended on the false
claim, so no behaviour changes — but the sentence was load-bearing in argument, because
it was part of why the name is the only join key.

### (b) The V-category marker moves mid-name

ADR-065's marker is kept as the age digit only — gender still travels as the FIE `Sexe`
attribute — but its position changes to **mid-name**: `Nom="KAMIŃSKA (1)"`,
`Prenom="Gabriela"`. This is not a preference. All 20 events of MPW 2026 use that form
in the wild, including per-category brackets where the digit is redundant, and MPW 2026
ingested cleanly through our own pipeline: 20 FTL events to 28 per-category tournaments
with counts matching the scraped marker distribution exactly, and **zero rows in
`tbl_fencer` containing a digit or a parenthesis** — no marker has ever leaked into a
stored name.

The four places that currently know the convention — `python/scrapers/ftl.py:98`,
`python/pipeline/review_cli.py:544`, `python/matcher/fuzzy_match.py:83` and
`ftl_seed_export.format_prenom_with_marker` — become importers from a single owner,
`python/pipeline/vcat_marker.py`. That consolidation is a **pure refactor**: if a test
changes behaviour, the refactor is wrong. The regexes are deliberately **not** widened.

### (c) §3's predicted combined brackets are dropped

§3 predicted the combined DE brackets the organizer would build and generated files to
match. That prediction is abandoned. We emit the **maximal split** — one DE file per
gender × age category actually present — and the manual tells the organizer to combine
freely using Fencing Time's own *Combine Events*, because we re-split by birth year on
scrape-back regardless. Predicting a human's combining decision was a guess we had no
need to make.

*Not yet confirmed:* that the organizer accepts one file per gender × category rather
than the brackets they build by hand. The manual says it out loud; nobody has agreed to
it.

### (d) §4's file naming is replaced

§4's scheme is superseded by names that state event, weapon, phase, gender and category
range, ASCII and English in the filename, Polish in the in-file `TitreLong`:

```
PPW1-2026-2027_EPEE_POOLS-MIXED_all-categories_W+M.xml
PPW1-2026-2027_EPEE_DE_MEN_V2.xml
PPW1-2026-2027_EPEE_ROSTER_all-known-epee-fencers.xml
```

The reason is legibility under a real failure: MPW 2026's foil mix-all is named
*"Floret Mężczyzn V3, V4"* while actually holding 25 fencers spanning V0–V4 including
the women. A file that reads as a category it does not contain is how a bracket gets
imported into the wrong event.

### (e) A roster file per weapon, and how it is suppressed

Built 2026-09-12 as `fn_ftl_roster(p_id_event, p_weapon, p_token)`, migration
`20260912000005`, tests pgTAP 77. A third file kind: every fencer with any result in that weapon, full history, all
nationalities — imported as a pick-list so a fencer who turns up unannounced is
**ticked in rather than typed** (Fencing Time 4.7 Guide p.145, *Event Competitors →
Import from XML*). Typing is how a duplicate identity is born.

Suppression is keyed on the **fencer**, not the name: always suppress any `id_fencer` a
registration for this event and weapon already points at, and suppress by name only
when an unmatched registration bears that name **and exactly one fencer does too**. The
naive rule — exclude any fencer whose name matches a registration, ignoring birth year
— would hide the 19-result MŁYNEK Janusz from the roster because a *different* Janusz
registered, which is precisely the person the organizer might need to tick in.

### (f) Club, and the public download page

The club is harvested on scrape into `tbl_fencer.txt_club` (overwrite on non-null,
storing `club1`), asked again at registration per event, and emitted only when given.
PROD holds 0 fencers with a club today, so this starts empty by construction.

Delivery gains a public page on weteraniszermierki.pl, treated like `/znajdz-zawody/`
and **not** a menu item (ADR-090), from which the organizer downloads the files
directly, with a PL and EN manual beside it. §5's on-demand email to the organizer is
unchanged and remains the delivery path until that page exists.

*Not yet confirmed:* that the WordPress page carries a new custom element as cleanly as
`<spws-calendar>` did. The pattern is proven, but this element is the first to expose a
`lang` attribute.

### (g) How the browser gets the data, and what it is not given

Built 2026-09-12. The download page is public and static-hosted, so the XML is generated
in the browser and its data comes from one new function, migration
`20260912000004_ftl_export_entries.sql`:

```
fn_ftl_export_entries(p_id_event INT)
  RETURNS TABLE (txt_surname, txt_first_name, enum_gender,
                 enum_age_category, enum_weapon, int_order)
```

One row per registration × declared weapon. It is `SECURITY DEFINER` because it has to
be — `tbl_registration`'s RLS admits only `authenticated`, and that is correct, since
the table carries the declared birth year and the `uuid_edit_token` that authorises an
edit. What it publishes is the columns `vw_registration_entry_list` already serves
anonymously, plus one integer.

**That integer is the design.** The obvious projection would return `id_fencer` and let
the page call `fn_ranking_ppw` per sub-ranking to sort — 22 round trips at PPW1, and 22
chances to render a half-ordered file. Returning the already-resolved seed position
instead means one call, and the join key never leaves the database, so the public
surface never names a person by database identity. No birth year, no `id_fencer`, no
`id_registration`, no edit token, no e-mail hash; test 76.4 asserts their absence from
the function's own signature so a later widening cannot happen quietly, and 52.7 carries
the anon-allowlist justification.

The seed order comes from the **rolling** ranking, via `fn_ftl_export_use_rolling` — the
SQL twin of `frontend/src/lib/rolling.ts` (ADR-018/021): live or upcoming season ranks on
carry-over, a finished season on its own results. This is not a refinement. PPW1 is the
first event of SPWS-2026-2027, so the season has no results of its own: measured on the
PROD mirror on 2026-09-12, `fn_ranking_ppw('EPEE','M','V2', 4, false)` returns 0 rows and
`true` returns 22. Without carry-over the mix-all file would have seeded the entire field
in the order people happened to fill in the form, and looked perfectly correct doing it.

The generator itself now exists twice on purpose: `python/pipeline/ftl_seed_export.py`
for the e-mail path of §5, and `frontend/src/lib/ftlSeedExport.ts` for the page. The
duplication is deliberate — static hosting cannot run the Python — and is held honest by
`frontend/tests/ftlSeedExport.test.ts`, which asserts the generated XML **byte for byte**
against ElementTree's real output, attribute order and the space before `/>` included.
"Structurally equivalent" is not a property Fencing Time has been shown to accept; the
validated reference files in `doc/external_files/FTL_SRC/` are.

`<spws-ftl-export>` is registered in `frontend/src/main.ce.ts` and reachable immediately
at `register.html?view=export&event=<code>` (add `&lang=en`), which rides on the existing
page because the credential-injection step only knows about files already in the CE build
input. The WordPress page of (f) mounts the same element.

Also built: a dependency-free stored-ZIP writer (`frontend/src/lib/zip.ts`). PPW1 produces
25 files and a browser will not start 25 downloads. Verified on 2026-09-12 by opening a
bundle it produced with Python's `zipfile` — `testzip()` returned `None` and the Polish
names survived.

### (h) The page is one page, protected by a capability, and shows only live events

Built 2026-09-12, after review of (g)'s first version. Four things were wrong with it, and
each fix is a decision worth recording.

**It was one page per event.** The association always has more than one event taking
entries — two on the day this was written — and the page depended on whoever sent the link
having picked the right event code. `fn_ftl_export_events(p_token)` now lists every event
with at least one registration whose end date has not passed, and the page renders one card
per event. There is **no grace period**: the seed files set a competition up, and once it
has been fenced there is nothing left to seed.

**It had no access control at all.** ADR-090 §3 settled that administration stays on GitHub
Pages and that a sign-in modal is not reachable from a public page on the association's
site, so a login here would reverse a decision taken a week earlier. The surface is
protected by a **capability** instead — `/pliki-startowe/?k=<uuid>`, held in
`tbl_ftl_export_token` and checked *inside* all three functions. The check is in Postgres
and not in the page because the bundle is public, so a check in JavaScript would be
decoration.

Be precise about what the token defends, because it is easy to overrate: every name,
gender, weapon and age category this page shows is **already public** through
`vw_registration_entry_list`, and the ranking positions come from `fn_ranking_ppw`, which
anon has always been able to call. The token keeps an organizer-only tool off four hundred
fencers' screens, and it gives us something to rotate when a link goes astray — one
`UPDATE`. It is not the reason birth years are safe; that is the projection's column list.
An absent, unknown or revoked token returns **no rows rather than raising**: a stale link
should look empty, not broken, and an error would confirm to a prober that they had found a
real endpoint. The page's empty line is therefore worded to be true whether the cause is a
dead token or a genuinely empty calendar.

**The files were built on page load, not on download.** The page fetched once, generated
every XML into memory, and the button only serialised what was already there. A page opened
at 08:00 and used at 10:00 handed over the 08:00 entry list with nothing on screen to say
so, and the Polish copy ("powstają na bieżąco") concealed it rather than stating it. Both
download paths now re-read first — one call, ~30 ms for a full event — and the page shows
the moment the list it holds was taken.

**Twenty-eight rows buried the instruction.** The file list is now one collapsed section
per weapon whose header carries the summary ("eliminacje mix + 9 tabel DE + baza zawodników
(181)"), so the page opens as three lines and the eight-step instruction is immediately
visible. That instruction — Import Events (p. 22), Combine Events (p. 22), the marker, the
morning Re-Import (p. 144), the walk-up via Event Competitors → Import from XML (p. 145) —
is the deliverable, and the first version had replaced it with a four-word table column.

It also travels **inside the archive**, one self-contained file per language
(`INSTRUKCJA.txt`, `INSTRUCTIONS.txt`), each carrying the file list and all eight steps.
The page is read at a desk days before; the archive is opened at the venue, often without
usable wifi, which is exactly when the question gets asked. Both languages always go,
whatever the page was set to, because the person who downloads the files is frequently not
the person who runs the software.

Two smaller notes on this surface. The **example name in the instruction is invented** —
`PRZYKŁADOWSKA (1) Anna`. The first draft used a real fencer entered for a live event, and
this text is published; `Kowalski`, `Kowalska` and `Nowak` were all checked and rejected
too, because in an association of 367 people the stock placeholders are real members. And
the in-file `TitreLong` stays **Polish even in the English interface**: it is the string
Fencing Time displays, and `_detect_weapon_from_title` reads the weapon back out of it
(`python/scrapers/ftl.py:248`), so its language is load-bearing in both directions.

*Still pending from this amendment:* the club of (f).

## References

- ADR-078 (GDPR / organizer recipient), ADR-079 (registration/identity), ADR-024
  (combined-category splitting), ADR-056 (BY→V-cat), ADR-065 (FTL marker), ADR-066
  (min-participants/walkover), ADR-027/036 (seed export), ADR-030 (registration URL).
