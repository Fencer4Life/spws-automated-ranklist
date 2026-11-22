# ADR-079: Event Self-Registration & Identity Resolution

**Status:** Accepted (signed off 2026-10-31, `doc/plans/branch-names-and-merge-messages-2026-10-31.html` §11: Phase 1 DB schema + Phase 2 public registration UI **implemented** 2026-07-05 — spec §5.2, RTM FR-120–FR-130 — and every amendment below are in force). **Deferred:** Phases 4/5, the optional magic-link email of §2 — not started, blocked on Resend/eu.org, and **no longer blocking registration** (see the 2026-08-17 amendment). **Amended 2026-07-05 (§7):** registration URL auto-fill + in-app modal presentation. **Amended 2026-08-17:** unmatched fencers register with `id_fencer` NULL; `register.html` is PROD-only; open item 1 (unmatched dedupe) resolved same day by migration `20260817000001`. **Amended 2026-09-02:** the payment account moves out of the frontend bundle into the database — an organizer default overridable per event, a vetted IBAN, and a registration toggle that is refused without an account. Open item 7 records the deferred half: no admin screen sets an organizer's default, so only SPWS has one. **Amended 2026-08-28:** declared names are stored whitespace-normalised; the matched and unmatched branches absorb each other's twin; and a fencer may correct a submitted declaration through a new public edit path, `fn_update_registration`, authorised by a short-lived handle. Open items 2 (club) and 3 (post-deadline) remain open, joined by a rate limit for §4 defence (d). **Amended 2026-09-13:** open item 2 (club) resolved by migration `20260913000001` — `tbl_registration.txt_club` now round-trips through both write RPCs and the token-gated FTL export; `CONSENT_VERSION` bumped to `v1.1`. **Amended 2026-10-03:** a linked registration carries its fencer's roster name. **Amended 2026-11-21:** an unlinked registration's name is stored in one form (surname in capitals, given name in the organizer's files' title case); a title is kept in front of the surname and ignored by every name comparison; the form asks once when the name fields look reversed; the newcomer's name check offers „Popraw”. **Amended 2026-11-21 (release 2):** a declared birth year lies inside its season's range, this year − 120 to the season's later year − 30, computed on every use; the form offers it as a decade grid and the table refuses any other year on every write path. **Amended 2026-11-21 (release 3):** the entrant declares a country from a pick-list of the 207 fencing codes, Polska chosen at the start; the entry stores the code, which refers to `tbl_fencing_country`; the entry list shows its flag and offers a „Kraj” filter; consent text `v1.2`. **Amended 2026-11-22 (FR-171):** the monthly read of the EVF ranking also keeps each ranked fencer's EVF id, names, gender, category and country (`tbl_evf_ranking_fencer`), and a tool fills the country of an event's entries that have none from it, by name with gender and category agreeing; it links nothing. **Amended 2026-11-21 (release 4):** a signed-in administrator edits an entry from the list, and a linked entry's changed birth year, gender and country reach the roster in the same transaction. **Amended 2026-11-22 (FR-174, signed off 2026-11-22):** the read of the EVF ranking also keeps each ranked fencer's place and points per weapon, and runs when the calendar says a read is due instead of monthly.
**Date:** 2026-07-04
**Source:** Event Registration & Clean-Roster Seeding subsystem (spec §5.2); ADR-078, ADR-080
**Amended by:** [ADR-084](084-calendar-quarter-barrel-event-card.md) §7 (decouples the entry-list gate from the registration cutoff).
**Current behavior:** [Registration lifecycle](../handbook/reference/registration-lifecycle.html) — the handbook walkthrough of this decision as built, following one registration from the administrator enabling it to the row being purged after ingestion, with the failure at each stage and the screens as they appear. Read that for *what the system does*; read this ADR for *why it does it*.

## Amendment (2026-11-22, FR-174 — the EVF read keeps places, and reads when the calendar says so)

**Status:** Accepted (signed off by the user 2026-11-22, with the picture sheet `doc/plans/seed-source-line-pixel-sheet-2026-11-22.html`). Plan `doc/plans/seeding-by-organiser-ranking-2026-11-22.html` (rev 1, signed in chat 2026-11-22); business decisions T1–T10 in `doc/plans/evf-seeding-for-evf-events-brainstorm-2026-11-22.html` (rev 3).

**Context.** An event EVF organises is seeded by the EVF ranking ([ADR-080](080-clean-roster-ftl-seeding.md) amendment of the same day). The read of the EVF ranking (FR-171) kept each ranked fencer but „never points, place or birth date”, and ran on the 3rd of each month, so a seed could be up to a month behind EVF. The read takes about a minute, which the user judged too long to run while an organiser waits for files. The 19 EVF events of 2026/27 end on 17 different days.

**Decision.**

1. The read also keeps each ranked fencer's place and points per weapon in `tbl_evf_ranking_place`, replaced in full by `fn_replace_evf_ranking_places`, which refuses a payload of fewer than 24 lists and then changes nothing. The read itself checks the 24 lists first and writes nothing at all from an incomplete read. Never a birth date (EVF publishes none).
2. `evf-ranking-sync.yml` wakes every day at 05:41 UTC. A scheduled run asks each database `fn_evf_ranking_read_due()` and reads only when it names a reason: seven days after an EVF event (time for EVF to update its ranking), the day before an EVF event that uses our registration, or 31 days after the last read (so July and August keep a monthly read). Not due: it stops before EVF is asked anything, without a message. A failed read leaves the last read where it was, so the read is due again the next morning; a changed event date needs nobody. A run started by hand always reads.
3. Nobody triggers a read from a page: not the organiser's download page, not the entry list.

**Alternatives considered.**

1. Reading on demand when files are generated (rev 1 of the brainstorm) — rejected by the user: a minute's wait at the venue.
2. A fixed weekly read — rejected: about 52 reads a year for 18 read days.
3. Keeping the monthly schedule beside the new rule — rejected: two schedules for one job; the 31-day line covers what it did.

**Consequences.** FR-171's „never points, place or birth date” becomes „never a birth date”. About 18 reads a season instead of 12, each reported on Telegram with its reason. Changed: `python/tools/extract_evf_given_names.py` (`ranking_places`, `build_places_sql`, `run_if_due`, `--if-due`), `.github/workflows/evf-ranking-sync.yml`, the workflow catalog page. Tests: EVFSEED.01–07 and 16 (pgTAP 139), EVFSEED.17–22 (`test_given_names_sync.py`; RFNAME.24/26/27, EVFCTRY.04 and RNAT.14 amended for the places step). FR-174.

## Amendment (2026-11-22, FR-173 — a name list under SURNAME; the birth year stays the entrant's own)

**Status:** Accepted (signed off by the user 2026-11-22, with the picture sheet). Plan `doc/plans/registration-name-list-under-surname-2026-11-22.html` (rev 1, signed in chat 2026-11-22, P1–P4 A); the business decisions D1–D12 are in `doc/plans/registration-autocomplete-brainstorm-2026-11-22.html` (rev 2).

**Context.** Measured read-only on PROD on 22 Nov 2026: our fencer table holds 373 fencers, the EVF ranking (FR-171) 2,680, 123 of them on both. Of the 196 entries made so far, 127 were linked by an exact name and year; 6 had the name of a fencer we hold but another year; 42 were people known only to the EVF ranking (49 entries come from abroad); 3 had their two names exchanged; 18 were on neither list. A list offered while the surname is typed would have offered the right person to 178 of them. The name matching under all of this had a damaged letter table (I27, repaired the same day by migration `20261122000004`), so a name typed without its accents was not found.

**Decision.**

1. **The list (D1, D3, D8).** From the second typed letter, 200 ms after the last keystroke, the form asks `fn_registration_name_suggestions` (migration `20261122000005`) for at most eight people whose „surname given name” or „given name surname” starts with what was typed, Polish letters and case folded (`fn_fold_name`). It draws on `tbl_fencer`, then the EVF ranking (a person on both comes once, from our table), then earlier entries of people on neither. Each row shows the name, the age category in the event's season, the country and where the person comes from. The filter runs in the database: a visitor never receives the whole list, and `tbl_evf_ranking_fencer` keeps no grant to a visitor.
2. **The birth year stays the entrant's own (D2, the user's rule).** The list never shows a birth year and a pick never fills one. The year a person gives is the only check that stands between an entry and somebody else changing it, a known trade-off the user keeps. The function returns no birth year and no id (RFAC.10).
3. **A pick (D4–D6, D12).** A pick fills surname, given name (in the name form of the 2026-11-21 amendment), gender, country when it is a fencing code, and the club when the box is empty; it ticks no weapon. The cursor moves to the year box, whose grid opens on the decade of the person's age category; every other decade stays one tap away.
4. **„Dalej” is unchanged (P1).** The exact match, the reversed-name and year questions, the consent and the save run as before on the name and the year the entrant gives. A pick links nobody by itself.
5. **A person already entered (D7, the user's rule).** The row carries „już na liście”; the pick opens nothing. The earlier entry is reached on „Dalej” by name and year, as before.
6. **How the name arrived (D10, P2).** `tbl_registration.txt_name_source` holds TYPED, ROSTER, EVF or ENTRY. After a new entry is saved, the form records the source with `fn_set_registration_name_source`, authorised by that entry's edit token, when both names are still the ones the pick wrote; a failure leaves TYPED and never stops the entry. The administrator's „Edytuj” shows it as one read-only line. The PROD → CERT copy of an event's entries (`python/pipeline/promotion/refresh.py`, `fn_replace_event_registrations`) carries it, so CERT and a LOCAL mirror show the same (I28, found while building; RFAC.34–35).
7. **The browser's own list (D9)** is switched off on the surname box only; the given-name box keeps `autocomplete="given-name"` (RFNAME.15 amended).
8. **Not in this work (D11).** The administrator's „Edytuj” offers no list: a linked entry's name is locked there on purpose.

**Alternatives considered.**

1. **The whole list sent to the page once** (D3 B). Instant, but every visitor's browser would hold about 2,930 names with countries and categories. Rejected.
2. **The pick fills the birth year** (the brainstorm's rev 1). Rejected by the user: the year is the only check on an entry, so it must come from the person entering.
3. **The year question narrowed to the picked fencer** (P1 B). Deferred: it changes the question ladder, which exists so that software never chooses between namesakes; its own plan if wanted.
4. **The source written by the saving function** (P2 B). Rejected: a 13th argument and a full rewrite of `fn_create_registration`, the function every entry depends on, for one optional column.

**Consequences.** New: migration `20261122000005_registration_name_suggestions.sql`; `frontend/src/components/NameSuggest.svelte`; `supabase/tests/138_registration_name_suggestions.sql` (RFAC.01–12); `frontend/tests/NameSuggest.test.ts`, `frontend/tests/YearPicker.test.ts`. Changed: `RegistrationForm.svelte` (the surname box, the pick, the source after the save), `YearPicker.svelte` (`hintDecade`, `focusBox`), `EntryEdit.svelte` (the source line), `fn_replace_event_registrations` and `refresh.py` (the copy keeps the source), `api.ts`, `types.ts`, `birthYearRange.ts` (`vcatDecade`), both locale files, the anon allowlist (52.7, `check-security-posture.sh`). FR-171's „read by the jobs only” no longer holds: the EVF table has one visitor-facing reader, which returns no birth date (EVF publishes none) and at most eight rows. The picture sheet `doc/plans/registration-name-list-sheet-2026-11-22.html` shows the form unchanged until two letters are typed.

## Amendment (2026-11-22, FR-171 — an entry without a country takes it from the EVF ranking)

**Status:** Accepted (signed off by the user 2026-11-22).

**Context.** Entries made before release 3 have no country, and a foreign entrant who leaves „Polska” untouched is recorded as POL. On 21 Nov 2026 Łomianki (PEW5efs-2026-2027) held 105 PROD entries, one with a country. The public EVF ranking publishes each ranked fencer's country on every row, as a fencing code except EVF's own `OTH`, and no birth date on any row; its rows carry no gender or category either, which are the list's own. The monthly read kept given names only (FR-167). Plan: `doc/plans/evf-ranking-country-lomianki-2026-11-21.html` (rev 1, D1–D6 A). FR-171.

**Decision.**

1. **The read keeps the ranked fencers (D1 A).** The monthly job, renamed `evf-ranking-sync.yml`, sends each environment the insert-only given names as before, then each ranked fencer's EVF id (a UUID), surname, given name, gender and category (from the list read) and country, into `tbl_evf_ranking_fencer` (migration `20261122000001`), inserted or updated by EVF id and never deleted. Never points, place or birth date. The table starts empty and only the job fills it, so no ranked fencer's name is committed; row security is on and no visitor or signed-in user may read it.
2. **The fill rule (D5 A).** `python/tools/fill_registration_country.py` gives an entry a country only when exactly one ranked fencer has its name (titles, case and diacritics folded), of the same gender, whose EVF category is the one the declared year gives in the event's season or the season before. Setting a country links nothing; identity still rests on the birth year.
3. **What is never written (D2 A, D4 A).** A code outside `tbl_fencing_country` (EVF's `OTH`) and any entry that already has a country; a roster nationality that differs is not a reason to skip (D3 A), and the roster is not touched (ADR-106).
4. **How it writes.** Without `--apply` it only reads and prints, per entry, what it would do. With `--apply` one statement sets the countries on the entries that still have none and returns each changed row, so a second run sets nothing. PROD first; CERT takes the countries at its next PROD → CERT copy (D6 A, RFCTRY.21).

**Consequences.** On LOCAL, with Łomianki's 105 PROD entries copied in and a live read of 2,680 ranked fencers, the dry run proposed 80 countries, the same 80 entries and codes as the plan's list, and a second run after `--apply` proposed none. The rehearsal found that EVF ids are UUIDs and that rows carry no gender or category, both now pinned by tests. Tests: pytest EVFCTRY.02–08 (`test_given_names_sync.py`, `test_fill_registration_country.py`), pgTAP EVFCTRY.01 (`134_evf_ranking_fencer.sql`); RFNAME.24 and RFNAME.27 amended for the second statement and the renamed workflow.

## Amendment (2026-11-21, release 4 — a signed-in administrator edits an entry; a linked entry's correction reaches the roster)

**Context.** On 21 Nov 2026 two entries' impossible birth years (47 and −1972) were corrected on PROD by hand, through the database. FR-166 had given the administrator „Usuń” but nothing to correct an entry. Six of PROD's 127 linked entries declare a year other than the roster's, and nothing showed it. On 22 Nov the user asked that a correction of a linked entry also reach the fencers table. Plan: `doc/plans/registration-form-names-year-country-2026-11-21.html` (rev 10, release 4); sheet: `doc/plans/registration-admin-edit-release-4-pixel-sheet-2026-11-21.html` (§05, R1–R3 A; I25 A). FR-170.

**Decision.**

1. **„Edytuj” beside „Usuń”.** On the entry list reached from the admin calendar (the route of FR-166), each row carries „Edytuj” beside „Usuń”. A visitor sees neither, and a visitor's list reads no entry details.
2. **Every declared field.** The dialog (`EntryEdit.svelte`) edits surname, given name, gender, birth year, weapons, club and country (D2 A). A linked entry's name is locked, because the database keeps the roster's name for it (2026-10-03 amendment).
3. **The roster's year is shown.** For a linked entry the dialog shows the roster's birth year beside the declared one, and the signed-in list marks an entry where they differ with ≠ (D5 A).
4. **A linked entry's correction reaches the roster.** For a linked entry only (R1), what the save changed reaches the roster in the same transaction (R2): the birth year, marked as confirmed (`fn_update_fencer_birth_year`); the gender (`fn_update_fencer_gender`); and the country, as the event season's `ADMIN` row in `tbl_fencer_nationality`, never `tbl_fencer.txt_nationality` (R3). The club stays the entry's own (migration `20260913000001`). A field the save left as it was is not copied. Before „Zapisz” the dialog shows the roster's new year and any category change. A birth-year change queues the fencer's events for recompute ([ADR-072](072-cdc-recompute-debounce.md)), and the audit trigger logs the roster change. §1's read-only invariant was already replaced by [ADR-093](093-registration-as-birth-year-source.md), which lets a public registration only propose a change to a confirmed year and leaves applying it to an administrator (`fn_apply_identity_override`). This is a second administrator's path, a correction typed in the entry dialog; the public paths are unchanged.
5. **One function writes both.** `fn_update_registration_as_admin` (SECURITY DEFINER, migration `20261122000003`) replaces the admin application's direct `UPDATE` of `tbl_registration`, for signed-in users only: anon has no `EXECUTE`, and the body checks the role. The table's own rules still decide: the name form, the roster's name, the season's year range and the country code. A refused write anywhere refuses the whole save.
6. **A refused save keeps the dialog open** with the reason: the year's range line, „Takie zgłoszenie już istnieje.” for a rename into another newcomer's identity, or a general failure otherwise. An edit never links or unlinks, and never touches the consent record or the fencer's edit link.
7. **On a phone** a name too long for its row ends in „…”, and a signed-in row puts its actions on a line of their own (I25 A).

**Consequences.** An entry, and with it the fencer's roster record, is corrected from the list in one dialog, without a visit to the database. New: migration `20261122000003`; `EntryEdit.svelte`; `fetchAdminEntryDetails`, `updateRegistrationAsAdmin` and `fetchEventSeasonEndYear` in `frontend/src/lib/api.ts`. Tests: Vitest RFADM.01–08, 13–15 and 23–25 (`EntryEdit.test.ts`, `EntryList.test.ts`, `api.registration.test.ts`); pgTAP RFADM.09–12 (`133_registration_admin_edit.sql`) and 16–22 (`135_registration_admin_edit_roster.sql`). Relates to ADR-093 (who may move a confirmed year), ADR-072 (recompute on a birth-year change) and [ADR-033](033-fencer-gender-identity-enhancements.md) (the roster's gender is authoritative; an administrator's correction is not an import).

## Amendment (2026-11-21, release 3 — the entrant declares a country; the list shows its flag)

**Context.** Foreign veterans register for SPWS events, and the organizer's start files wrote every entrant as POL. The form had no country, so a German entrant reached the fencing software as Polish and had to be corrected by hand. Plan: `doc/plans/registration-form-names-year-country-2026-11-21.html` (rev 10, release 3); sheet: `doc/plans/registration-country-release-3-pixel-sheet-2026-11-21.html`. FR-169.

**Decision.**

1. **A pick-list, not free text.** The form asks for a country from the 207 fencing codes, Polska chosen at the start (`CountryPicker.svelte`, `frontend/src/lib/fencingCountries.ts`). It searches the Polish and English names, the code and a few common other names (Anglia, England, Great Britain, Holandia, Holland, Czech Republic); nothing else can be stored.
2. **The code is stored and checked.** The entry stores the three-letter code in `tbl_registration.txt_country`, which refers to `tbl_fencing_country` (each code with its flag's two-letter code, or none for AIN and TPE); an entry may have none. Every write path carries it: `fn_create_registration`, `fn_update_registration`, `fn_replace_event_registrations` and the PROD → CERT copy (migrations `20261121000004`, `20261121000005`). The code table is read by no visitor; the form carries the same list, and a test compares the two.
3. **The list shows the flag alone** at the end of the line, 18 px, labelled with the country's name; a code without a drawn flag shows its letters in small type; no country, nothing. The flag column and the filter appear only when an entry has a country, so a list without any is unchanged to the pixel.
4. **„Kraj” filter.** It lists the codes present, codes alone, and works together with the weapon, category and gender filters (FR-165).
5. **Consent `v1.2`.** The country is processed under the contract (Art. 6(1)(b)) and is shown on the public entry list; the consent screen says both.

**Consequences.** Every stored entry keeps no country and shows as before; the organizer's files take `Nation` from the entry ([ADR-080](080-clean-roster-ftl-seeding.md) amendment of the same day). Tests: Vitest RFCTRY.01–17, 24–27 (`fencingCountries.test.ts`, `CountryPicker.test.ts`, `RegistrationForm.test.ts`, `EntryList.test.ts`, `api.registration.test.ts`, `ftlSeedExport.test.ts`), pgTAP RFCTRY.18–23 (`132_registration_country.sql`), pytest RFCTRY.21, 24–26.

## Amendment (2026-11-21, release 2 — a declared birth year lies inside its season's range)

**Context.** On 21 Nov 2026 PROD held two impossible declared years, 47 (the entrant typed her age) and −1972 (a minus sign the number box accepted), both shown as V4; they were corrected by hand the same day. The box accepted any integer, and nothing below the form refused one. Plan: `doc/plans/registration-form-names-year-country-2026-11-21.html` (rev 10, release 2); sheet: `doc/plans/registration-birth-year-release-2-pixel-sheet-2026-11-21.html`. FR-168.

**Decision.**

1. **The range.** A declared birth year lies between this year minus 120 and the event's season's later year minus 30, the V0 rule itself (`fn_age_category` gives no category under 30): 1906–1997 for 2026/27 in 2026.
2. **Computed, never fixed.** Both edges are computed on every use: the form from the season and the clock (`frontend/src/lib/birthYearRange.ts`), the table from `fn_registration_birth_year_bounds(season end year, today)`. 2031/32 in 2031 gives 1911–2002; the tests pin both.
3. **The form offers only those years.** Focusing or clicking the box opens a decade grid on the decade of the year in the box, else of a 50-year-old; it pages by decade as far as the range reaches, greys out years outside it, shows the range and the chosen year's category, and keeps focus in the box while pressed (`YearPicker.svelte`). Typing still works, digits only, four at most, and closes the grid; a year outside the range shows a line under the box naming the range, and „Dalej” stays off.
4. **The table refuses any other year** on every write path — the visitor's create and edit, an administrator's direct update and the PROD → CERT copy (`trg_registration_birth_year_range`, migration `20261121000003`) — naming the range in its refusal (`REG_BIRTH_YEAR_OUT_OF_RANGE`), which the form shows as the same line.

**Consequences.** An impossible year can no longer reach the entry list or the organizer's files. Stored rows are not re-judged; on release none on PROD (195) or CERT (90) is outside the range. A mistyped year inside the range still creates a second unlinked entry. Two older tests change their fixtures: 75.15 declares 1910 instead of 1902, and 76.9 writes its below-V0 row with the rule switched off, because the export must still leave such a stored row out. Tests: Vitest RFYEAR.01–06 (`birthYearRange.test.ts`, `RegistrationForm.test.ts`), pgTAP RFYEAR.07–10 (`131_registration_birth_year.sql`), each range pinned for 2026/27 and five years on.

## Amendment (2026-11-21 — a declared name is stored in one form, a title is kept apart, reversed fields are asked about)

**Context.** On 21 Nov 2026 PROD held 193 entries. Eleven newcomers' given names were not in the form the organizer's files use, two carried a title the Austrian and Hungarian way (written with the surname), and four newcomers had typed their given name into the surname box. The 2026-10-03 amendment kept an unlinked registration's name „as typed”. Plan: `doc/plans/registration-form-names-year-country-2026-11-21.html` (rev 10, release 1); sheet: `doc/plans/registration-names-release-1-pixel-sheet-2026-11-21.html`. FR-167.

**Decision.**

1. **One name form for a newcomer.** The surname is stored in capitals, the given name in title case by the rule the organizer's files use (`pythonTitle` / `fn_python_title`), spaces trimmed and collapsed. The letters remain the fencer's; only case and spacing are written. This replaces „as typed” in the 2026-10-03 amendment for unlinked registrations; a linked registration still takes the roster's name. The form writes the form when a box is left and on „Dalej” (`frontend/src/lib/registrationName.ts`); `trg_trim_registration_names` writes it on every write of an unlinked row (`fn_registration_canonical_names`, migration `20261121000001`), and `fn_registration_realign_names` rewrote the rows already stored once.
2. **Titles.** A title — dr, ddr, prof, ing, mag, mgr, dipl-ing, doc — at either end of either box is moved in front of the surname in one written form („Dr. KOVÁCS”) and is ignored by every name comparison: the identity lookup, the unmatched-entry dedupe, the entry list's order and search (`fn_name_without_title`, `surnameWithoutTitle`).
3. **Reversed fields.** When nobody matches and the surname box holds a known given name while the given-name box does not, the form asks once whether the fields are reversed; either answer is believed. Known given names are the fencer table's, read live, and the EVF ranking's, held in `tbl_common_given_name` — given names only, insert-only, `service_role` only, refreshed monthly by `given-names-sync.yml` (`python/tools/extract_evf_given_names.py`). A visitor receives two yes/no answers from `fn_registration_name_check` and never the lists.
4. **Read-back.** The newcomer's name check offers „Popraw” beside its two buttons; the name boxes carry `autocomplete` marks.

**Not done, on evidence.** A spelling question: on the EVF ranking it would wrongly ask 5 to 9 in 100 correctly spelled foreign fencers. A hand-written names list: run against PROD's 193 entries it changed no answer.

**Consequences.** The entry list shows one form for every newcomer; a titled fencer stands under the surname; a fencer we hold is unaffected. On release the one-off rewrite changed 12 PROD entries and 1 CERT entry, with no collisions on `uq_registration_unmatched_identity`. Stored reversed entries stay as they are; correcting them is the administrator's edit (FR-170). Known limitation: a page cached from before the release re-submitting a titled newcomer through the matched branch could miss its twin, since it sends the surname unwritten. Tests: Vitest RFNAME.01–16 and 27, pgTAP `130_registration_names.sql` (RFNAME.17–23), pytest RFNAME.24–27.

## Amendment (2026-10-03 — a linked registration carries its fencer's roster name)

**Context.** "STANISLAWSKI ALBERT" registered for PPW1-2026-2027 on 20 Sep 2026. He is #282 STANISŁAWSKI Albert. The public entry list (`vw_registration_entry_list`) and the FTL export read the registration's own name. So linked entrants appeared without their Polish letters, in the case they typed, or with the name fields swapped ("MACIEJ SPLAWA - NEYMAN"). Ten linked PPW1 registrations differed from the roster that day.

Registrations made before the lookup started folding names (migration `20260925000001`, `fn_fold_name`) were never looked up again. Seven of them stayed unlinked although a folded name reaches their fencer. Among them were BUJKO Paulina and STANISŁAWSKI Albert, whose declared years therefore never reached the Birth-year review. They were linked on PROD on 3 Oct, one guarded statement, with the form's rule: MADDEN Gerard's declaration against a confirmed year became a PENDING proposal. KIEROŃSKI Tomasz got no proposal, by decision P7.

**Decision.** Once `id_fencer` is set, the registration's surname and first name are the fencer's roster name, whatever path links or edits it:

- `fn_create_registration` with a fencer;
- `fn_confirm_registration_identity`;
- `fn_update_registration`, which still changes everything else;
- an admin write;
- `fn_replace_event_registrations` on the CERT refresh.

A fencer renamed on the roster renames his linked registrations. An unlinked registration keeps the name as typed, and unlinking keeps the last name. Two `SECURITY DEFINER` triggers enforce it: `trg_registration_roster_name` on `tbl_registration` and `trg_fencer_name_to_registrations` on `tbl_fencer`. Migration `20261003000015` adds them and aligns the registrations already linked.

**Consequences.** The entry list and the export show the roster's spelling, diacritics included. The roster stays the authority on a name: a wrong roster name is corrected on the fencer, and it reaches every linked registration. pgTAP `101_registration_roster_name.sql` (REGNAME.01–09).

## Amendment (2026-09-02 — whose account the fencer pays into)

§6 described a single association account. It was a module constant compiled into the frontend
bundle, and the `payee` / `iban` attributes that were supposed to vary it were set by nobody:
`register.html` passed empty strings and the calendar modal passed nothing. Every event therefore
showed the same account, which is why an organizer other than SPWS could not run registration at all.
Nothing validated it either — on 2026-09-02 it turned out to be storing the domestic NRB under an
IBAN label, scoring 73 on the ISO 13616 check instead of 1.

### (a) The account is data, resolved event → organizer

`tbl_organizer` gains `txt_payee` / `txt_iban` (the default) and `tbl_event` the same two (the
override). `vw_calendar` resolves them and reports which level answered as `txt_payment_source`
(`EVENT` / `ORGANIZER` / `NONE`), so the admin UI states the account in force rather than inferring it
from whether a field looks empty. Both fields resolve **together** from one level: a per-event payee
with an organizer IBAN would put the right name on the wrong account.

### (b) The IBAN is vetted, not trusted

The system never handles the money — it publishes transfer instructions and does not track whether a
transfer arrives (§4). What it publishes is the account a fencer is asked to pay into, and once that
became admin-typed a typo would send the fencer's own transfer astray. `fn_is_valid_iban` implements
ISO 13616 and is enforced by a `CHECK` on both tables, so no caller can store an invalid value; the
editor repeats the check inline so the failure is understood at the field rather than arriving as a
constraint violation. Deliberately generic rather than `PL`-only — an organizer abroad is plausible.

### (c) Registration cannot be enabled without an account

This changes what the decision guarantees. Registration exists to support collecting a fee; enabling
it with nowhere to pay is a configuration mistake rather than a legitimate state — the fee cannot be
quoted against anything and the entrant reaches the end of the flow with nowhere to send it.
`trg_registration_needs_account` refuses `bool_use_spws_registration = TRUE` unless a payee **and** an
IBAN resolve. A trigger rather than a check inside `fn_update_event`, so no caller routes around it:
not the admin RPC, not a promotion, not a hand-written statement.

An earlier draft had the flow *skip* the payment step when no account resolved. Withdrawn by the
user: there must always be an account, which is why this blocks instead.

### (d) Blank is blank

NULL, empty and whitespace-only collapse to NULL on write, so one definition of absent serves the
resolution, the toggle guard and the CERT→PROD fill-blank policy alike. Without it a payee of `'   '`
would satisfy the guard. See ADR-086's 2026-09-02 amendment for the ownership tier and the
consequence — a field cannot be locked empty on PROD.

## Amendment (2026-09-02 — the amount is quoted in the event's currency)

§6 said the payment step shows the fee. It did not say in what, and the page answered with a
literal `PLN` in four places: the fee derived on step one, the amount row of the payment panel,
that row's copy button, and *copy everything*. `tbl_event.txt_entry_fee_currency` has existed
since March 2026 (FR-48, migration `20260327000004`), the event editor offers PLN/EUR/USD beside
the amount, `fn_create_event` and `fn_update_event` persist it, the EVF import writes it and the
PROD mirror carries it. Every writer honoured the column; the calendar card read it. Only the
registration page — written later and in isolation — never received it, because
`RegistrationEventInfo` did not carry the field at all, which left the literal as the only
option available to the template.

The fee is now `$derived` from the event once and used by all four sites. An event that states
no currency reads as `PLN`, which preserves exactly what the 25 events carrying NULL already
showed; blank and whitespace-only are treated as unstated, consistent with the payment fields
amended above, though a closed `<select>` means the editor cannot currently produce one.

The **display and the clipboard must agree** is the operative rule, and it is the reason this was
worth more than a cosmetic fix: a fencer pastes what the copy button gave them rather than what
they read, so a euro-priced event was putting a złoty figure into a real bank transfer. Vitest
covers the first screen, the payment panel, both copy paths and the unstated fallback; pgTAP 8.25
pins the one link that had never been asserted — that `vw_calendar`, the sole route by which the
public page learns anything about an event, exposes the column and passes an unstated value
through as NULL rather than coalescing it.

## Amendment (2026-08-28 — correcting a declaration; one row per entrant)

Three defects found while PPW1-2026-2027 was live and taking real entries, and one new
public path. §§1, 3, 5 (read-only invariant, BY reconciliation matrix, schema shape) still
hold; §2's *write* semantics gain an edit path, and §4's threat assessment is confirmed
rather than changed.

### (a) Declared names are stored whitespace-normalised

`tbl_fencer` has carried `trg_trim_fencer_names` since migration `20260503000004`.
`tbl_registration` never got the equivalent, and the live form validated with
`surname.trim()` while submitting the raw string — so two of the first fourteen PROD
entries were stored as `"Gary "` and `"KUCIĘBA "`. Migration `20260828000001` adds
`trg_trim_registration_names` and backfills. The form now normalises at its own boundary
too, as `20260503000004` paired with the admin modal.

The blast radius was narrower than first assumed and is recorded here so it is not
re-derived: the FTL seed file was never affected, because
`ftl_seed_export.to_canonical_name()` already strips on export, and dedupe was never
affected, because its arbiter normalises with `upper(btrim(...))`. Only what we store and
publish was wrong.

### (b) One entrant holds one row per event, whichever branch writes it

§5's `UNIQUE(id_event, id_fencer)` and the partial index added on 2026-08-17 arbitrate on
**different** keys, and nothing spanned them — so one person could hold a matched *and* an
unmatched row for the same event, both reaching the public roster and the organizer's seed
file. Reachable in both directions, and by design rather than accident: an unmatched
newcomer's `tbl_fencer` row is created while registration is still open, and the form
deliberately treats a failed lookup as "no match" so a network blip never blocks an entry.

Migration `20260828000002` makes each branch absorb the other's twin for the same declared
identity before inserting. **Promotion is preferred over delete-and-insert** — `ts_created`
and the consent stamp are the RODO evidence and consent was given at the first submission,
so that row survives and merely gains its fencer link. Where a matched row already exists
for that fencer, the redundant unmatched twin is removed instead. Both live environments
were checked before shipping and held none.

### (c) A fencer may correct a declaration they already submitted

§2 gave `tbl_registration` a single public write path. That path dedupes an unmatched
entrant **by the declared name and birth year**, so re-submitting a corrected spelling
inserted a *second* row rather than fixing the first — demonstrated on LOCAL, where
`KOWALKSI Adam` and `KOWALSKI Adam` ended up side by side. Adding a forgotten weapon always
worked, because that leaves the arbiter untouched.

Migration `20260828000003` adds `uuid_edit_token` and `fn_update_registration`, which
updates **by primary key** and so can change the declared name and birth year. It enforces
the same D10 window, never touches `id_fencer` (the link is re-derived at ingestion, §3),
never restamps consent, and raises rather than merging when a correction collides with
another entry at the same event. `id_registration` cannot authorise this on its own —
`vw_registration_entry_list` publishes that column.

**The handle is short-lived and deliberately not persisted.** It lives in the page's memory
and is gone when the form unmounts; a returning fencer re-enters the tuple they declared,
which upserts onto their row and mints a fresh handle. So re-submission **rotates** the
handle, which is the mechanism rather than a side effect.

The rejected alternative was persisting it in `localStorage`. That bought one property —
only the row's first registrant could rename it — and cost a real one, because
`localStorage` is per-origin and per-device: a fencer who registered on a phone could not
correct from a laptop, and `register.html` on GitHub Pages and the CMS-embedded element
cannot see each other's storage. The property it bought was also protecting a secret that
is not secret: `fn_match_registration_fencer` is anon-callable and answers **per birth
year, before any write**, so an exact birth year is recoverable in about ten silent probes
(verified on LOCAL). §4's assessment is therefore unchanged — this widens no boundary that
was closed — but its defence **(d)** is now a genuine gap, recorded below.

## Amendment (2026-08-17 — the unmatched fencer registers; register.html is PROD-only)

Two corrections, made while opening PPW1-2026-2027 for entry. §§1, 3, 5 (read-only
invariant, BY reconciliation matrix, schema) are untouched; §2's *gating* changes and
§7(c)'s credential injection was **wrong in a way that silently misrouted every entry**.

### (a) A non-exact match no longer requires email — it registers

§2's Model B table routes Paths B/C/D through "one magic-link click". Phases 4/5 never
shipped, so the form did the only other thing it could: it rendered a *"email verification
is coming soon — please contact the organizer"* panel and **wrote nothing at all**. Every
newcomer, and everyone whose stored birth year was an ingestion estimate rather than a
confirmed value, was refused outright.

That inverts the ADR's own purpose. §Context justifies this subsystem by the birth years it
would collect; the population whose BY we most need is precisely the population the form
turned away.

**A miss now continues to RODO and is written with `id_fencer` NULL.** No email, no gate.

The security argument is §4's own: email *"proves inbox control, not identity — it is
friction + accountability, never load-bearing for integrity."* Removing it therefore costs
nothing the ADR ever claimed for it. The four real defences are all intact — (a) the
read-only invariant, (b) the confirmed-BY-sacrosanct rule, (c) the organizer's venue check,
(d) the results-based ranking, under which a fake entry that never fences scores nothing.
The worst case is unchanged from §1: a junk, ephemeral, deletable `tbl_registration` row.

Nothing downstream needed changing, which is the strongest evidence the design anticipated
this:

- `fn_create_registration` already takes `p_id_fencer INT DEFAULT NULL` and inserts it.
- `vw_registration_entry_list` joins `tbl_event` and `tbl_season` — **not** `tbl_fencer` — so
  an unmatched registrant appears on the public roster with a derived age category.
- `python/pipeline/ftl_seed_export.py` already declares `id_fencer: int | None` and
  interleaves unranked registrants by `ts_created`.

So the declaration reaches both the roster and the organizer's seed file without
`tbl_fencer` ever being written. The real fencer row is still created at ingestion (§3),
where the declared BY feeds the existing reconciliation machinery unchanged.

Verified end to end against PROD before the link was shared: a fencer absent from
`tbl_fencer` completed the flow, `SELECT count(*) FROM tbl_fencer` for that surname returned
**0**, and the row surfaced on `vw_registration_entry_list` with a server-derived `V1`.

The `reg_verify_*` locale keys are retained, not deleted — Phases 4/5 will reuse them when
magic-link delivery ships. Email then becomes an *optional* strengthening of an entry that
already exists, rather than a precondition for making one.

### (b) `register.html` receives PROD credentials only

§7(c) settled that `register.html` is a CE-bundle artefact whose credentials are injected by
`release.yml`. It did not say **which** credentials, and the workflow injected all four
attributes — both the CERT and the PROD pair.

`RegistrationElement.svelte` resolves its client as `(supabaseCertUrl || supabaseProdUrl)`.
A populated CERT pair therefore always won, and **every registration made through the public
link would have been written to CERT** while the page looked entirely healthy to the fencer.
The component's own comment asserted that "build-time sed picks one pair per deploy target";
no such per-target selection existed.

`release.yml` now blanks `supabase-cert-*` for `register.html` and injects the PROD pair
only. `index.html` keeps both — it exposes a runtime admin environment toggle; this page has
none by design (§6), so it gets exactly one environment. Blanking rather than omitting is
required: the build's *"no localhost in dist"* guard would otherwise fail on the committed
LOCAL defaults.

This defect is invisible to tests and to inspection of the rendered page. It was caught only
by registering once against the deployed URL and then querying **both** databases.

### (c) Smaller corrections shipped in the same change

- **Gender no longer defaults to `M`.** A woman who never touched the select was silently
  recorded male — into her sub-ranking category, the public entry list and the FTL seed. It
  is now a declared value, required before Continue.
- **Write failures surface.** `fn_create_registration` RAISEs once the D10 window guard
  trips; the rejected promise previously left the fencer pressing a button that did nothing.
- **One Back step from RODO**, so a mistyped birth year can be corrected without re-entering
  the form.
- **A soft already-registered warning**, read from `vw_registration_entry_list` before the
  write. It is a warning, not a constraint — see Open items.
- **Payment details are real.** The IBAN was empty on both surfaces (no workflow ever filled
  `register.html`'s `iban=""`, and `CalendarView` passes no payment props at all), and three
  separate `'SPWS'` defaults overrode the full registered account name a transfer is matched
  against. Both now come from `frontend/src/lib/orgPayment.ts`, where an empty prop means
  "use the association details". The transfer note follows the association's stated
  convention — first name, surname, weapon, age category — with the event code retained,
  since several rounds share one account.
- **The payment deadline is quoted, not described.** It reads
  `COALESCE(dt_registration_deadline, dt_start)` — the same expression the D10 guard
  enforces — instead of the previous hand-written "12 hours before the event starts", which
  corresponded to no rule in the system.

### Open items

1. ~~**`UNIQUE(id_event, id_fencer)` does not constrain unmatched rows.**~~ **Resolved
   2026-08-17**, migration `20260817000001_registration_unmatched_dedupe.sql`. Postgres treats
   NULLs as distinct, so the hole described in §5 became *reachable* the moment unmatched rows
   could be written. It is now closed by a partial unique index
   `uq_registration_unmatched_identity` on
   `(id_event, upper(btrim(txt_surname)), upper(btrim(txt_first_name)), int_birth_year)
   WHERE id_fencer IS NULL`, with `fn_create_registration` branching on `p_id_fencer IS NULL`
   because a single `INSERT` cannot carry two `ON CONFLICT` arbiters. The key is normalised the
   way `fn_match_registration_fencer` normalises, so the matcher and the constraint agree on
   what "the same person" means, and birth year is part of it by design (§2) — a same-name
   namesake born in a different year keeps their own row. The unmatched branch deliberately
   does **not** update `int_birth_year`: it is part of the arbiter, so a different year is a
   different entrant rather than an edit. Pinned by pgTAP 49.28–49.31; 49.21 (distinct
   unmatched entrants never collide) passes unchanged, since it registers two *different*
   people. Existing duplicates are collapsed by the migration keeping the highest
   `id_registration` per identity — the most recent submission is the entrant's current
   intent, and is the row the upsert would have produced.
2. ~~**Club is collected and discarded.**~~ **Resolved 2026-09-13**, migration
   `20260913000001_registration_club.sql`. `tbl_registration.txt_club` now exists and is
   populated by both write RPCs; `fn_ftl_export_entries` returns it to the token-gated
   organizer export, and `vw_registration_entry_list`/`fn_ftl_roster` are unchanged, so the
   public roster still never sees it. This did invert the consent text as predicted — *"Klub
   — tylko do plików startowych · nie zapisujemy"* became untrue the moment the value was
   stored — so `CONSENT_VERSION` moved `v1.0` → `v1.1` rather than being edited under an
   unchanged stamp. See [ADR-080](080-clean-roster-ftl-seeding.md) amendment (f) and
   [ADR-078](078-gdpr-data-handling.md) §1 for the full detail.
3. **Whether registration should be accepted after the advertised deadline.** Raised as a
   revenue question and explicitly deferred by the user on 2026-08-17. The D10 guard is
   enforced in the database, so this is not a copy change. **Recommendation:** gate the guard
   on `dt_start` rather than the deadline, leaving `dt_registration_deadline` as the
   advertised date — the same decoupling [ADR-084](084-calendar-quarter-barrel-event-card.md)
   applied to the entry list. Not yet decided.

### Corpus audit

- [ADR-078](078-gdpr-data-handling.md) — **relates, unchanged.** Its processing table still
  lists the salted email hash with a lawful basis; that column simply stays NULL until
  Phases 4/5. No data is now collected that the table does not cover. (Its "payment reference
  + paid/unpaid status" row remains inconsistent with §4, which states payment is not tracked
  digitally — a pre-existing discrepancy, flagged, not fixed here.)
- [ADR-080](080-clean-roster-ftl-seeding.md) — **relates, strengthened.** Its population rule
  is "every row of `tbl_registration`". Unmatched fencers now produce rows, so the seed
  covers entrants it previously could not have seen.
- [ADR-083](083-server-enforced-authorization.md) — **relates, one factual drift.** It states
  that `fn_create_registration` and `fn_match_registration_fencer` are "the entire server
  surface" of this flow. The form now also reads `vw_registration_entry_list` for the
  duplicate warning. No new grant was needed — that view already grants SELECT to `anon` for
  the public roster — but the sentence is no longer exhaustive.
- [ADR-016](016-supabase-auth-totp-mfa.md) — **clean.** Its email-confirmation setting governs
  admin accounts, not registration.

4. **No rate limit anywhere, so §4's defence (d) does not exist.** §4 lists "the salted-hash
   abuse log + rate limit" among the real defences against impersonation. Neither is built:
   `txt_email_hash` is provisioned and always NULL (ADR-078 §1 records this), and there is no
   throttling in any migration, RPC or edge function. This matters more than it did, because
   `fn_match_registration_fencer` answers **per birth year before any write**, making an exact
   birth year recoverable in roughly ten silent probes — so every argument in this ADR that
   leans on the birth year being private is currently worth nothing. *Recommendation:* rate-limit
   the match RPC, or stop it answering per-year. It is the one genuinely missing control, and it
   is a precondition for the birth-year challenge in item 5.

5. **The declared birth year is never challenged.** `canContinue` requires only a non-null
   number — no bounds, and the computed V-category is display-only — so a mistyped year passes
   straight through. Because the year is part of the unmatched dedupe arbiter (item 1), a typo
   creates a **second** entry rather than editing the first, and both reach the roster and the
   seed file. *Recommendation:* where a name matches a fencer whose stored year is **not**
   `bool_birth_year_estimated`, challenge the mismatch — matching against every namesake, and
   challenging rather than refusing, so the estimated-BY population this subsystem exists to
   learn from is never turned away (the defect corrected on 2026-08-17). This is a data-quality
   control, not a security one: see item 4 for why it cannot be the latter.

6. **`fn_update_registration` leaves no record of what changed.** §4 accepts the residual
   impersonation exposure on the grounds that it is "minimised, detectable, reversible". A
   rename through the edit path is currently neither detectable nor reversible — the previous
   value is simply gone. Revocation already works (admins hold `UPDATE` under a `FOR ALL`
   policy, so regenerating `uuid_edit_token` makes any held handle inert), so only the record is
   missing. *Recommendation:* write each edit to `tbl_audit_log`, which already carries
   `jsonb_old_values`/`jsonb_new_values` and is written by several migrations.

7. **No admin screen sets an organizer's default account.** The 2026-09-02 amendment gives
   `tbl_organizer` `txt_payee` / `txt_iban` and resolves them for every event of that organizer, but
   only the event-level override is editable in the UI. SPWS has values because the migration seeds
   them; **EVF and FIE have none**. The practical consequence: an event organized by anyone other than
   SPWS cannot have registration enabled at all unless an administrator fills in a per-event override,
   because `trg_registration_needs_account` requires an account to resolve and there is no screen to
   give that organizer a default. *Recommendation:* an organizer editor carrying the two fields and
   the same ISO 13616 validation as the event editor — the constraint and `fn_is_valid_iban` already
   cover the write path, so this is UI only. Deferred deliberately on 2026-09-02; the per-event
   override unblocks the domestic events that exist today.

8. ~~**A transitional account fallback lives in the bundle again, and must be removed.**~~ **Resolved 2026-09-02**, once PROD carried migration `20260902000001`: `LEGACY_SPWS_PAYEE` / `LEGACY_SPWS_IBAN` and the `||` fallbacks are gone, so an event resolving no account now shows none rather than the association's — a misconfiguration is visible instead of masked behind a plausible number. `fetchEventForRegistration` keeps `select('*')` deliberately: `deploy-pages` will always publish ahead of `deploy-prod`, so naming columns explicitly would break the live page on the *next* schema addition too. The original problem was:
   `deploy-pages` needs only `build`, so the frontend publishes before `deploy-prod` — which waits on
   a required reviewer — has run. For the length of that gap the new bundle queries a PROD database
   with no payment columns. Naming them returns `42703` and the page renders *"event not found"* for
   every fencer, so `fetchEventForRegistration` selects `*` and `LEGACY_SPWS_PAYEE` /
   `LEGACY_SPWS_IBAN` in `lib/orgPayment.ts` stand in when the event resolves nothing. They match what
   the bundle showed before the account moved, so un-migrated PROD behaves exactly as it did.
   *Recommendation:* delete both constants and the `||` fallbacks once PROD carries migration
   `20260902000001`. They are unreachable from that moment, and leaving them lets a genuinely
   account-less event look configured.

## Amendment (2026-08-09 — the entry list outlives the registration window)

§7 gated the entry-list link on the same cutoff as the registration link, so both vanished together once the deadline passed. [ADR-084](084-calendar-quarter-barrel-event-card.md) **decouples them**: registration closes at `COALESCE(dt_registration_deadline, dt_start)`, but the entry list stays visible until the event **starts** (CQ.31, CQ.32, EC.22), and is never shown on a cancelled event (CQ.33).

This is the point at which people most want to see who is entered — after entries close and before the event runs.

**No existing test pinned the old coupling**, which is why the change cost new tests rather than rewrites: every test touching `.entry-list-link` set a deadline *equal to* `dt_start`, so both readings agreed. The uncomfortable half is why it was cheap — the coupling was never covered, so nothing would have caught it drifting either way.

The in-app modal presentation from the 2026-07-05 amendment is unchanged; the links moved from the timeline row to `EventCard`, which emits `onopenregistration`/`onopenentrylist` for the orchestrator to act on (EC.24, CV.12–CV.14).

## Context

Automation is stuck near 90 % because birth-year (BY) data in `tbl_fencer` is
unreliable — worst case, two different people share an identical name with
different BY. BY today flows *backwards* (scrape → fuzzy match → BY **estimated**
from the tournament's age band, `bool_birth_year_estimated=TRUE`; ADR-056). If
fencers **self-declare** identity + BY *before* the event, that BY becomes an
authoritative signal and discrepancies drop toward zero for registered fencers.

The challenge: prevent duplicate/conflicting entries and corruption of the fencer
table by mistaken or malicious registrations, while keeping the flow usable for
elderly veterans (who forget emails) and minimising stored personal data
(ADR-078).

## Decision

### 1. Core invariant — registration is READ-ONLY on `tbl_fencer`

The registration subsystem **reads** `tbl_fencer` (to match, derive category,
route the flow) and **writes only** `tbl_registration` (ephemeral) + generates the
FTL seed. It **never** writes `tbl_fencer`, results, or the ranking. Those are
mutated only by (a) the event-ingestion pipeline and (b) explicit admin actions
(merges, manual edits, GDPR erasure) — unchanged from today.

Declared BY/identity rides on the registration record as a **high-quality signal**;
ingestion name-matches the seeded exact name → pulls the declared BY → feeds the
**existing** reconciliation machinery (`stages.py`, `fuzzy_match.py`, the PENDING /
IdentityManager flow), which does the authoritative write and marks the BY
*confirmed*. New fencers are **not** created at sign-up — a fencer enters
`tbl_fencer` only when results ingest (today's behaviour), now enriched with a
declared BY instead of a guess.

**Security consequence (by construction):** a malicious registration can at most
create a junk, ephemeral, deletable `tbl_registration` row — it cannot mutate an
identity or a ranking, because that code path does not exist in the registration
flow.

### 2. Identity model — Model B (email as one-time verification, not an account)

> **Superseded in part by the 2026-08-17 amendment (a).** The Path B/C/D *gating* below —
> "every other path takes one magic-link click" — no longer holds: a non-exact match is
> accepted and written with `id_fencer` NULL, with no email step. The rest of this section
> (Model B's rationale, the no-persistent-account property, the exact-triple fast path, and
> the dedup note) stands unchanged.

The form collects **Surname, Name, Gender, BY**, normalises (case/diacritics/
spacing), and matches via `find_best_match`. One gate rule: **skip email only on an
exact `(Surname, Name, BY)` triple match; every other path takes one magic-link
click.** Email proves **inbox control, not identity** — it is friction +
accountability, never load-bearing for integrity. There is **no persistent
account**: a veteran who lost an old email just verifies whatever inbox they have
now; admin intervention shrinks to true edge cases (formal erasure, disputes).

| Path | Match result | Email? | Outcome |
|---|---|---|---|
| A | exact name **and** BY equal | No | anonymous fast-path → weapon → category → RODO → payment |
| B | strong name (≥95), BY differs | Yes | verify → reconciliation (below), record on registration |
| C | weak name (50–94) | Yes | verify → "is this you?" + admin review |
| D | no match | Yes | verify → new registration (declared BY carried to ingestion) |

Dedup on the anonymous path is enforced by `UNIQUE(id_event, id_fencer)` upsert. A
fencer correcting our BY types a different year → the triple no longer matches →
auto-routed into the verified path.

#### Implementation note — form-side routing is exact-only; no Python bridge (2026-07-05)

The four-path table above is a **conceptual** identity model. In implementation it
resolves to a **binary** form-side decision, because the step-2 mockup (the build
SSOT) deliberately collapses Paths B/C/D into a **single** "we couldn't match you
exactly — confirm by one-time email link" screen that shows **no** fuzzy candidate
and explicitly states *"final identity matching happens when the organizer loads
results."*

Consequently:

- The **public form** performs **only** the exact `(surname, first, BY)` triple
  lookup — `fn_match_registration_fencer` (SQL RPC, `anon`-callable). Exact hit →
  Path A (skip email); **any** miss (unknown, near-miss typo, or right-name/wrong-BY)
  → the email-verify path. It does **no** fuzzy matching. (Pinned by pgTAP 49.22.)
- The **fuzzy** distinctions among B/C/D (`find_best_match`, RapidFuzz) are an
  **ingestion-time reconciliation** concern (§3), realised by the **existing**
  Python matcher that already runs when results are scraped — never invoked
  synchronously from the browser.

This **closes the "invocation gap"** flagged during Phase 1 (there is no mechanism
for the public frontend to call Python's `find_best_match`) **by construction**:
there is nothing the frontend needs to invoke in Python. A synchronous
Python-from-browser bridge (a hosted Python request/response service, or a SQL
`pg_trgm` re-implementation of the matcher) was considered and **rejected** — it
would add always-on infrastructure (violating the serverless, zero-dollar
architecture) or a second divergent matcher, to serve a UX flow that intentionally
does not use a form-side fuzzy result. Path A — the only integrity-sensitive,
no-email fast path — is exact equality, so no fuzzy logic is security-load-bearing
at the form regardless.

### 3. BY reconciliation matrix (runs at INGESTION, not the form)

The declared BY is reconciled against the stored BY by the ingestion pipeline. A
**confirmed** BY is **sacrosanct** — self-service never overwrites it:

| Stored BY | Declared − stored | Interpretation | Action |
|---|---|---|---|
| Estimated | any | our guess; declaration wins | overwrite ← declared, mark confirmed |
| Confirmed | any discrepancy | may be a namesake / bad edit | **quarantine → admin review; real row untouched** |
| — (multiple same-name) | — | self-declared BY selects the twin | link closest; none in band → new |

Two genuinely different people with the **same name + same BY** is the residual
hard case — disambiguated only by email, club, or optional full DOB.

### 4. Impersonation hardening

Email verification does **not** stop a foul player entering a victim's name. The
system does **not** track payment completion digitally — it only displays
bank-transfer instructions so the fencer can pay correctly; there is no
"paid" gate on the seed or entry list (corrected 2026-07-04 — an earlier draft
of this ADR proposed one, which wrongly assumed digital payment tracking this
system does not do). The real defences: (a) the read-only invariant +
confirmed-BY-sacrosanct rule → no data corruption; (b) **venue-level check** —
the organizer verifies payment (and can challenge an unfamiliar face) in person
at check-in, before the competition starts — a physical control, not enforced
in software; (c) the ranking is **results-based**, so a fake entry that never
fences has zero ranking effect, and the victim can spot the bogus entry via
"Sprawdź zgłoszenie" for admin removal; (d) the salted-hash abuse log + rate
limit. This is the same residual exposure every open amateur registration
carries (competit.pl included) — minimised, detectable, reversible, not
eliminated.

### 5. Schema (Phase 1)

- New `tbl_registration` (EPHEMERAL, RLS-gated — **rows, not a JSON file**: public
  concurrent writes need ACID; a file has no locking, no host with Supabase Storage
  disabled, no access control, and is a GDPR hazard if committed): `id_event`,
  `id_fencer` (nullable match), declared surname/first/gender/BY, weapons,
  `txt_ftl_name`, `ts_consent`, `txt_consent_version`, salted email hash,
  `ts_created`. **No payment-status column** — payment completion is not
  tracked digitally (corrected 2026-07-04; see §4). Optional own `reg` schema.
- `tbl_event` additions: `url_entry_list`, `txt_organizer_email`, `ts_ftl_sent`,
  `num_entry_fee_2w`, `num_entry_fee_3w`, `bool_use_spws_registration`
  (`url_registration` + `dt_registration_deadline` already exist, ADR-030).
- RLS: registration insert only via a controlled RPC; a public read-only entry-list
  view (name · gender · category · weapons — **no BY, no club**); writes REVOKEd
  from `anon`.

### 6. UI

Public Svelte route + custom element `<spws-registration event="…">` (mirrors
`<spws-ranklist>`/`<spws-calendar>`), reachable from the calendar's
`url_registration`, plus a public `url_entry_list` "Lista zgłoszonych". Bilingual
PL/EN. Mockups: `doc/mockups/registration_step{1,2,3}_*.html`,
`registration_rodo_consent.html`, `registration_entry_list.html`.

### 7. Amendment (2026-07-05) — registration URL auto-fill + in-app modal presentation

Two follow-on gaps surfaced once §6's UI was live: the calendar never actually
rendered a registration link (nothing fed it a base URL), and the flow that
was reached always navigated the fencer away from the calendar. Both are fixed
here; neither changes §1–§5 (read-only invariant, Model B, BY matrix,
impersonation defence, schema are all unchanged).

**a) Self-contained URLs, admin-triggered (a deliberate, scoped exception to
[[feedback_urls_admin_managed]]).** `CalendarView.svelte` gated the SPWS links
on `bool_use_spws_registration && registrationBase !== ''`, but no entry point
(`App.svelte`, `index.ce.html`) ever supplied `registrationBase` — so the
generated link never rendered, and PPW1-2026-2027 (flag on, no
`url_registration`) showed nothing. Rather than thread a deployment-time
`registration-base` attribute through every embed (LOCAL, GH Pages, a future
WordPress iframe), **`url_registration` and `url_entry_list` are computed
client-side and persisted** the moment the admin ticks
`bool_use_spws_registration` in `EventManager.svelte`:
`new URL('register.html', window.location.href).href` + `?event=<txt_code>`
(+`&view=list`). Unticking clears both. This makes a calendar embedded on a
foreign origin self-sufficient — the stored URL, not the embedding page,
determines where registration lives. `fn_update_event` gains
`p_url_entry_list TEXT` (migration `20260705000004`, DIRECT assignment — value
sets, `NULL` clears — matching how `p_registration` already treats
`url_registration`, **not** the "NULL = unchanged" convention the function's
other trailing params use, since the two registration URLs are always sent
together by the form). `CalendarView` now renders both links straight from the
stored columns; the old `registrationBase`/`useSpwsReg` prop plumbing is
removed entirely (dead once the URLs are self-contained).

**b) In-app modal instead of navigation.** Once the links worked, clicking one
still took the fencer off the calendar to the standalone `register.html` page
— jarring, and it lost the calendar's context. `RegistrationForm.svelte` and
`EntryList.svelte` gain optional `onclose`/`onviewlist` callback props
(undefined on the standalone page — nothing to close to there); a new
`RegistrationModal.svelte` wraps them in the same backdrop-click-to-close
overlay pattern already used by `DrilldownModal`, full-bleed on ≤600px
viewports. `CalendarView` opens this modal on left-click for
`bool_use_spws_registration=true` events (`e.preventDefault()`); the `href` is
left on the anchor unchanged, so right-click "copy link" / open-in-new-tab
still resolve to the real standalone URL. Links to a plain hand-entered
`url_registration` (flag off) are untouched — plain `<a>` navigation, no modal,
by construction (only SPWS-hosted events get an `onclick` handler at all).

**c) `register.html` stays a CE-bundle artefact (a correction, not a
sequel).** The reachable-fix for (a)+(b) first tried moving `register.html`
into the **main** Vite build (`vite.config.ts`) so a single `dist/` covered
everything `release.yml` deploys. That produced completely unstyled
("bare-HTML") `<spws-registration>`/`<spws-entry-list>` output: Svelte only
inlines a nested (non-custom-element) child component's `<style>` into a
shadow root when the **whole** compile graph runs under
`customElement: true`; under the main build's plain config those styles land
in the document `<head>` instead, invisible inside the CE's shadow DOM. Fix:
`register.html` reverts to being an input of `vite.config.ce.ts` (as it always
was) alongside `index.ce.html`, and `release.yml` gains a second build step —
`vite build --config vite.config.ce.ts` — whose `dist-ce/register.html` +
`dist-ce/assets/` are copied into the already-built `dist/` so Pages still
ships one merged output (closing the original "never deployed" gap without
re-splitting the artefact). Credential `sed` now targets `register.html`
directly (shared source, injected once, read by both build configs).
`register.html` also gained an inline page-shell `<style>` (dark background +
padding matching `doc/mockups/registration_*.html`) — without it the
CE-shadow-scoped card floated on the surrounding page's default white
background.

pgTAP 652→654 (8.24 `fn_update_event` URL auto-fill + prior 12.14 EVF
null-date fix, same day); vitest 449→463 (`RegistrationModal.test.ts` new,
`CalendarView`/`RegistrationForm`/`EntryList`/`EventManager` tests extended);
`svelte-check` 0 errors throughout.

**d) The same unstyled-render bug also hit LOCAL `npm run dev` (found after
push, user report).** (c) fixed the deployed/production path — CERT and PROD
both verified rendering correctly — but the *local dev server* is a separate
code path: `npm run dev` runs plain `vite`, which reads **`vite.config.ts`**
(the main config), not `vite.config.ce.ts`. `vite.config.ts` never set
`compilerOptions.customElement: true`, so visiting `register.html` directly
on the dev server (e.g. `http://localhost:5173/register.html?event=...` — the
exact URL an admin copies out of the calendar link to paste into Facebook/a
share) hit the identical shadow-DOM-styling gap as (c), just on a different
build path that (c) never touched. The in-app modal never showed this because
it renders `RegistrationForm`/`EntryList` as ordinary imported components
(normal Vite dev CSS injection), never through the `<spws-registration>`
custom-element boundary — so a working calendar modal gave no signal that the
standalone URL was broken. Fix: add `compilerOptions.customElement: true` to
`vite.config.ts` too. Verified safe — `App.svelte`/`main.ts` (the main app)
never declare `<svelte:options customElement>`, so only the four `ce/*.svelte`
wrapper files (which already declare it) are affected; the flag has no effect
on components that don't opt in. Confirmed empirically: `register.html` on
the plain `npm run dev` server now renders identically to the in-app modal;
the main ranklist/calendar app is unaffected (screenshots, console clean
apart from a pre-existing unrelated stale-auth-token log). vitest still
463/463, `svelte-check` 0 errors, main `vite build` unaffected (still emits
only `dist/index.html` — the CE-bundle-merge path in `release.yml` from (c)
is untouched, since that path was already verified working on CERT/PROD).

## Consequences

- No new form-side write path to `tbl_fencer`; reconciliation reuses existing
  ingestion code (declared BY replaces estimation).
- Elderly-friendly: most veterans use the frictionless anonymous path; email only
  on non-exact match, never a recoverable account.
- Birth year exposed in the ranking drilldown remains lawful (ADR-078 §3, Art. 13
  transparency + legitimate interest — purpose: category verification).
- (§7) `url_registration`/`url_entry_list` are the one admin-managed-URL
  exception in the codebase: auto-derived, not hand-typed, whenever
  `bool_use_spws_registration` is on. Every other event URL keeps the
  hand-entered convention.

## References

- ADR-078 (GDPR), ADR-080 (seeding), ADR-056 (BY reconciliation), ADR-016 (admin
  auth), ADR-030 (registration URL + deadline), ADR-034/064 (gender at matcher),
  ADR-050/070–074 (ingestion pipeline).
