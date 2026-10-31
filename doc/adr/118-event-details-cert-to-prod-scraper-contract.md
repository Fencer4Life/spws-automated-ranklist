# ADR-118: Event Details Written on CERT Reach PROD, and Every Calendar Scraper Writes Them Under One Contract

**Status:** Accepted (signed off by the user in chat on 2026-10-31: the field scope as "Rows 1–9 as picked", from `doc/plans/event-fields-cert-to-prod-scope-2026-10-31.html`, and the plan `doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html` as "Yes, all A", S1–S3). Implemented test-first and released to CERT and PROD on 2026-10-31 (main `179b9846`, Release run 41197505747). Amended the same day (F9, below): PROD's time counts a person's changes only; built test-first on LOCAL, release pending.
**Date:** 2026-10-31
**Supersedes:** [ADR-116](116-pzsz-calendar-browser-read-and-letter-passes.md) §2's fill-blank-only rule for the PZSz letter and fee (rule 8) and §6 (the PZSz-only address overwrite; every organizer's address now follows §1 below); [ADR-117](117-results-links-admin-only.md)'s amendment sentence "An older EVF PDF on PROD (Madrid, Skopje) is not a calendar page and stays"
**Amends:** [ADR-081](081-cert-prod-event-reconciler.md) (§3: the nine details leave the overwrite and fill-blank tiers and follow CERT's write time), [ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md) (the 2026-08-29 three-tier table: the nine details become a fourth tier), [ADR-028](028-evf-calendar-results-import.md) (Refresh Semantics and the 2026-08-09 carve-out: the EVF sync no longer overwrites the details itself, and a person's value on CERT holds; F3), [ADR-043](043-evf-event-allocator.md) (a `CURRENT_SLOT_REUSE` write carries the identity and status only), [ADR-088](088-calendar-location-contract.md) (§7: a corrected EVF city reaches a row through the contract, not through `fn_sync_evf_event_fields`)
**Relates to:** [ADR-079](079-event-self-registration-identity.md) (§7 and the 2026-08-17 amendment: our own `register.html?event=` link, never copied or replaced), [ADR-089](089-event-weapons-and-card-header.md) (EVF's weapons stay written with its code), [ADR-087](087-pzsz-senior-calendar-source.md) (the PZSz identity the mirror carries, unchanged), [ADR-117](117-results-links-admin-only.md) (results links stay outside every calendar write; D7 A, an event page gives way to a letter, holds for every scraper), [ADR-108](108-promote-replays-verified-cert-ingestion.md) (promote, unchanged), [ADR-036](036-prod-export-local-mirror.md) (the PROD seed export lists its tables; the new state table, like PZSz's provenance, is not among them)
**Source:** `doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html`, `doc/plans/event-fields-cert-to-prod-scope-2026-10-31.html`, `supabase/migrations/20261031000001_cert_event_details_reach_prod.sql`, `python/scrapers/calendar_write.py`, `python/pipeline/calendar_details.py`

## Context

The CERT→PROD mirror (`fn_mirror_events_to_prod`) sorted an event's fields into tiers ([ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md), 2026-08-29). Scraped facts (name, dates, city, country, weapons) overwrote PROD. Admin enrichment (the letter, the registration link, the fee, the address) filled PROD only while it was empty. A newer value on CERT for an enrichment field therefore never reached PROD once PROD held anything.

Measured on 31 October 2026 (read-only, both environments): 20 future events on each side; two letters differ, and CERT's is newer in both. Madrid (PEW2efs) has the October letter on CERT, written 2 October, and the August one on PROD. Skopje (IMEW) has V3 on CERT, written 22 September, and V2 on PROD since its creation on 15 September.

The user's rule, 31 October 2026: *"any time we have an update on CERT we promote the whole event level data to PROD … any time you have a write on any event level field on CERT you promote all details about CERT to prod on the next run"*, excluding our own registration links, for nine fields (rows 1–9 of the field list), and *"this logic applies to all calendar scrapers … PZSz, and any future scraper too"*, with USA Fencing planned next.

The scrapers disagreed on CERT. EVF's code plan overwrote the name, dates, weapons, letter and address on every run. Its refresh filled the registration link, fee, currency, address and letter only while empty, so EVF's newer link or fee never landed. PZSz decided the city, dates and address with compare-and-set (ADR-116 §5) and wrote the letter and fee only while empty (rule 8, `pzsz_sync.py` `_FILL_BLANK`).

Three issues were found along the way, and a fourth during the build:

- **F1.** `fn_ingest_evf_calendar`'s existing-slot UPDATE (migration `20261025000001`) wrote `txt_location = NULLIF(v_location,'')` and the same for the country. On 10 August at 07:47 it blanked the city and country a person had set on 9 August for PEW8, PEW13 and PEW17 on CERT. The identity sync, which runs after it, keeps a value when EVF sends none.
- **F2.** The mirror's UPDATE set `ts_updated = NOW()` on every event on every run. PROD's audit holds 10,570 event rows since 29 June; Skopje alone has 133 since 15 September, with no change.
- **F3.** ADR-028 says the refresh "is the only auto-write path that touches existing events, and it never overwrites a populated column". The code plan has overwritten populated columns since ADR-086.
- **F4.** `supabase/tests/19_phase3_wizard.sql` planned 25 checks and pg_prove counted 5: twenty sat inside savepoints, and each `ROLLBACK TO SAVEPOINT` also rolled back pgTAP's counter.

## Decision

### 1 · The mirror: CERT's newer details reach PROD

The **nine details** are the name, the start and end dates, the city, the country, the weapons, the venue address, the invitation letter (`url_invitation`), the organizer's registration link (`url_registration`), and the entry fee with its currency.

"Details last written" is the latest audited UPDATE that changed any of the nine; with none, the row's creation time (the audit records no INSERT). `promote.py --mode calendar` reads CERT's time with an inline subquery (`_details_set_sql`, `python/pipeline/promote.py:82`) and sends it as `ts_details_set`. PROD's time is the latest change a person made there to any of the nine, `fn_event_details_set_at(id_event)`; the mirror's own copies do not count (amendment F9).

For an event on both sides, the UPDATE branch:

- **CERT wrote later:** PROD takes every one of the nine that CERT holds.
- **PROD wrote later** (a person edited PROD after CERT's last write): PROD keeps every value it holds. A field empty on PROD still takes CERT's value.
- **A blank on CERT never clears PROD** (S1 A).
- **Our own registration link** (`/register\.html\?event=`) is never copied, and a PROD value that is ours is never replaced.
- **An event page on PROD gives way to a letter** in either case ([ADR-117](117-results-links-admin-only.md) D7 A).
- Values compare as their type: a fee of 50 equals 50.0, and weapons compare as a set.
- **An event with nothing to change is not written** (F2).

Every other field keeps its tier: the deadline, the 2- and 3-weapon fee tiers, the entry list, the organizer e-mail and the payment account fill a blank; the registration switch is not synced; keys, results links, status and the ingest record are unchanged.

A payload without `ts_details_set` (a run of the previous `promote.py`) gets the earlier rules, so the migration and the Python can land in either order.

### 2 · The contract every calendar scraper follows on CERT

Every calendar scraper writes the nine details through one rule:

1. An empty field takes the source's value. An event page in the letter counts as empty (C1, ADR-117 D7 A).
2. A source that changed replaces the scraper's own earlier value.
3. A value a person set is kept, and the source's different value is reported once on Telegram (S2 A; ADR-116's rule 3, now every scraper's).
4. A blank from the source clears nothing.
5. Our own registration link is never written by a scraper.

### 3 · One shared state table and write function (S3 A)

`tbl_calendar_field_state` holds, per event and detail, the value the scraper last wrote (NULL when the current value is a person's) and the source value last reported as held. With no state yet, the audit decides: a value a person last set (`txt_admin_user` not NULL) is the person's; any other is the scraper's.

`fn_calendar_apply_fields(p_scraper, p_events)` applies the contract and returns `{written, held}`. It locks the row (`FOR UPDATE`), so each write is a compare-and-set against a concurrent Admin save, and it refuses a field outside the nine. Both are `service_role` only. `python/scrapers/calendar_write.py` is the scraper side: `apply_fields`, `held_lines` for the Telegram report, and `evf_fields`, EVF's mapping. `python/pipeline/calendar_details.py` holds the field list and the link tests, so `promote.py` can import them without the scrapers' parsers (WFDEPS.01).

- **EVF** writes all its details through the function. Its calendar ingest, identity sync and refresh stop writing them; the refresh keeps filling a blank deadline and weapons, and the slot-reuse UPDATE writes the identity and status only (F1). **C2:** EVF's weapons stay written with its event code by the code plan, because the code's letters and `arr_weapons` state the same fact ([ADR-089](089-event-weapons-and-card-header.md)).
- **PZSz** keeps its own provenance tables (ADR-116 §5), which meet the contract once rule 8 goes. The letter and fee follow rules 2–6; Pass 0 decides the letter first, so the passes read the letter that will be held.
- **A new scraper** (USA Fencing next) calls `fn_calendar_apply_fields` and passes the contract tests before it ships.

## Alternatives considered

1. **The letter only (the first plan of 31 October).** Rejected by the user: *"this improvement should apply for all EVENT level fields"*; fees, addresses and registration links change too.
2. **A blank on CERT clears PROD (S1 B).** Rejected: F1 blanked three cities and countries on CERT, and PROD would have lost them too.
3. **The source replaces a person's value (S2 B).** Rejected: PZSz would lose rule 3, the fix for listing dates reverting hand edits (21 October). Since August, EVF replaced three letters a person had set on CERT; under the contract each would have reached the user as a report.
4. **PZSz moves onto the shared table (S3 B).** Rejected: one mechanism, but its provenance, released 22 October, would be rewritten. PZSz passes the same tests with its own.
5. **CERT's time read by a new CERT function.** Rejected: the scheduled mirror can run before the migration reaches CERT. The inline subquery works on either schema.

## Consequences

- **The first run on PROD** after the release changes three fields: Madrid's letter becomes the October one, Skopje's becomes V3, and PEW5efs's address becomes CERT's EVF version (the postcode PROD holds can be typed on CERT, and the EVF sync then keeps it). The country for PEW8, PEW13 and PEW17 is blank on CERT, so PROD keeps it.
- **A person's Admin save on CERT is a CERT write**: it reaches PROD on the next run, as a scraper's write does. A later CERT write takes all nine to PROD, including over a PROD edit made in between.
- **A held value** is reported once per source value ("EVF details kept for a person"); PZSz keeps its own digest.
- **The audit on PROD** gains rows only for events that change (F2).
- **F1 data:** the three CERT rows (PEW8, PEW13, PEW17) are restored from the audit's 9 August values after the release, on the user's go.
- **New:** migration `20261031000001_cert_event_details_reach_prod.sql`; `python/scrapers/calendar_write.py`; `python/pipeline/calendar_details.py`; pgTAP `117_mirror_cert_event_details.sql` (CALSYNC.01–16) and `118_calendar_field_contract.sql` (CALSYNC.20–39); pytest `test_calendar_scraper_contract.py` (CALSYNC.40–50).
- **Changed:** `evf_sync.py`, `pzsz_sync.py`, `pzsz_write_rules.py` (rule 8 removed), `promote.py`. Earlier assertions now pin the new rules: pgTAP CALURL.10–11, 12.10, evf.37, 50.1–50.2; pytest evf.55, CALURL.02 and the PZSz rule-8 cases (now `TestRule8Removed`).
- **F4:** `19_phase3_wizard.sql` stores each value under test in a psql variable inside its savepoint and checks it after the rollback (the pattern of `103_promote_apply.sql`); all 25 checks count.
- **Left as they are:** the deadline, the fee tiers and the payment account (outside the nine, by the user's choice); results links (ADR-117); the registration switch (ADR-086, 2026-08-29).

## Amendment (2026-10-31, F9) — PROD's side counts a person's changes only

The first run under §1 (31 October, `evf-sync.yml` run 41198873894) updated one event on PROD instead of four. `fn_event_details_set_at` read every audited change on PROD, the mirror's own copies included, so each mirror run that copied a CERT write made PROD look newer than that write. Madrid and Skopje showed CERT 6 October 12:53:51 against PROD 13:00:13, the mirror's copy of it, and PROD kept the August letter and V2. §1's rule is that PROD keeps its values when a person edited PROD after CERT's last write.

Migration `20261031000002_prod_details_time_counts_people_only.sql` redefines `fn_event_details_set_at` to answer that question: the latest change a person made (`txt_admin_user` set) to any of the nine, and NULL when no person ever changed them, which the mirror reads as "CERT is newer". The name stays because the released migration `20261031000001` calls it and applied migrations are never edited; a rename would have meant either a function nobody calls or narrowing the postgrestools gate (plan F10, decided A). The function's comment states the meaning. CERT's side is unchanged: `promote.py` counts every write on CERT, a scraper's or a person's.

**Tests.** pgTAP CALSYNC.17 (a mirror write on PROD after CERT's write does not make PROD newer, Madrid's shape) and CALSYNC.19 (an event no person changed on PROD takes CERT's details) were seen failing first, with CALSYNC.13's count. CALSYNC.18 (a person's PROD edit after CERT's write keeps PROD, whatever the mirror wrote since) guards the other side and passed before and after. CALSYNC.02's wording follows the rule; CALURL.10 scans the new function.
