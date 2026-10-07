# ADR-112: PZSz Start Lists Are Stored Inputs, Captured While pzszerm.pl Serves Them

**Status:** Accepted (decided by the user in chat on 2026-10-07: Q7–Q10 of `doc/plans/pzsz-start-lists-stored-2026-10-07.html`, all A). Implemented test-first and rehearsed on LOCAL on 2026-10-07, and released to CERT and PROD the same day (main `9c6e05d2`, Release 37562304356); the table, its grants and both functions were verified on both environments, with no rows yet.
**Date:** 2026-10-07
**Amends:** [ADR-111](111-pzsz-results-admitted-by-surname-name-birth-year.md) (§6: the replay no longer reads pzszerm.pl; D1's "send it again later" becomes a stored list), [ADR-108](108-promote-replays-verified-cert-ingestion.md) (promote replays one more recorded input, the start list), [ADR-087](087-pzsz-senior-calendar-source.md) (§4: the JavaScript check no longer blocks an ingest once a list is stored), [ADR-078](078-gdpr-data-handling.md) (§1: a new personal-data store, with its purpose and retention)
**Relates to:** [ADR-083](083-server-enforced-authorization.md) (the store is `service_role` only), [ADR-100](100-pzsz-senior-result-ingestion.md) (FencingTimeLive carries no birth year)
**Source:** `doc/plans/pzsz-start-lists-stored-2026-10-07.html`

## Context

ADR-111 admits a PZSz result only when the surname, first name and birth year match exactly one fencer in the fencer table. FencingTimeLive gives the places but no birth year. The year comes from the PZSz start list (`pzszerm.pl/zawody/kalendarium-zawodow/turniej/?id=N`, column *Data urodzenia*).

The CERT ingest read that list from pzszerm.pl at the moment of the ingest. The PROD promote read it a second time and compared hashes.

pzszerm.pl puts a JavaScript cookie gate in front of its pages and switches it on and off. Our HTTP client runs no JavaScript, so while the gate is on, every request is refused. Since ADR-087's amendment of 2026-10-06, `refuse_js_check()` recognises the gate page and the run stops with nothing written.

The logs of every PZSz sync since 3 September 2026 show the gate's history:

- **Off:** 3–9 September, 17–29 September, 1–2 October.
- **On:** 11–16 September, 30 September, and from 3 October.

Poznań (`PPS1s-2026-2027`) was fenced on 3–4 October, inside the current gated stretch. Its CERT ingest failed twice on 6 October (run records 3 and 4), with nothing written.

Getting past the gate is out of bounds: no faked cookie, no browser driven by automation.

## Decision

### 1 · A start list is a captured input, stored on CERT

`tbl_pzsz_start_list` holds one row per version of each tournament's start list:

- the PZSz event and tournament, the weapon and the gender;
- the starters as `[printed name, birth year]` in page order — **the year only, never the birth date** (ADR-078 §1);
- the hash of that list, the source (`pzszerm.pl` or `saved page`) and when it was captured.

The rows are insert-only. A version is appended only when it differs from the newest version for the same event, weapon and gender. "Newest" is the highest row id, so a list that changes A → B → A ends on A.

`fn_pzsz_start_list_store(jsonb)` holds that rule, so every writer shares it. The table is `service_role` only (ADR-083). It exists on every environment for schema parity, and is filled on CERT only. It stays out of `fn_event_input_fingerprint`, because PROD's copy is always empty.

`start_list_sha256` (`python/pipeline/promotion/run_record.py`) now hashes name and birth year, the stored form. `Starter` holds the birth year only; the parser still validates the whole printed date.

### 2 · The daily capture

A `capture` job in `pzsz-sync.yml` runs after the calendar job, unless the run is cancelled or is a dry run. It reads the start lists of every PZSz event of the active season that:

- has an `id_pzsz_event`;
- is not `COMPLETED` or `CANCELLED`;
- starts within 14 days either side of today in Warsaw.

Whatever changed is stored. If any page is the gate page, the capture stops at once: repeated requests against a bot check would look like an attempt to get past it. The job then fails without a second Telegram message, because the calendar job reports the gate the same morning.

The same job deletes the start lists of events outside the active season (§4).

### 3 · The CERT ingest reads the store

The CERT ingest first tries a capture, then reads the newest stored version for each weapon and gender. On a gated day, it therefore runs from the stored list.

Only when nothing has ever been stored does it stop, with nothing written. Its message says the list is stored on the next day pzszerm.pl serves its pages. The run's log shows each list's source and capture time.

### 4 · The PROD promote never contacts pzszerm.pl

The CERT run record already keeps the PZSz event and each round's start-list hash. Promote reads the stored rows by event, weapon, gender and hash, from CERT, over the read-only connection it already uses for the run record. It recomputes each hash and hands the lists to `plan_event`.

Promote refuses in three cases:

- a stored row is missing;
- a row's content does not match its hash;
- a PZSz plan is given no lists.

This is ADR-108's rule applied to one more input: promote replays exactly what CERT used. `source_differences` keeps its start-list comparison as a tamper check.

### 5 · Telegram names the moment to ingest (Q8 A)

When the capture stores a new version for an event that has ended, has an `url_event`, and has no FINISHED CERT run, Telegram says so and names the command:

> 📋 **PZSz start list stored** for `PPS1s-2026-2027`
> Send `ingest PPS1s-2026-2027`

The ingest is not started automatically. ADR-108 §2 puts the master-data refresh from PROD before every CERT ingest, under the operator.

### 6 · Saved pages, for a gate that covers a whole window

`python -m python.scrapers.pzsz_start_list_store store <EVENT-CODE> --event-page FILE --tournament ID=FILE …` stores pages a person saved from their own browser.

- It uses the same parsers, so a saved gate page is refused.
- Every individual tournament the event page lists needs its file.
- The rows are stored with source `saved page`.

The files are kept outside the repository.

### 7 · Retention and data inventory (Q9 A)

A start list is used only to admit rows of its event. Closed seasons are never re-ingested. So the daily job deletes the lists of events outside the active season (`fn_pzsz_start_list_purge()`).

ADR-078's inventory gains this store:

- **Purpose:** telling a veteran from a namesake in a PZSz field.
- **Legal basis:** Art. 6(1)(f), legitimate interest.
- **Data:** printed name and birth year of every starter, most of them juniors who are not our members.
- **Retention:** until the event's season is no longer active.
- **Access:** `service_role` only.

The store is never part of the PROD seed export, and no real start list enters the public repository.

## Alternatives considered

1. **Keep the live reads and resend until the gate opens.** Rejected: gated stretches have lasted up to six days, and every one needs a person to resend.
2. **Keep the live reads and add only the saved-page path.** Rejected: every gated day would still need a person to save pages, while a daily capture on open days makes that rare.
3. **Start the CERT ingest automatically after a capture.** Rejected for now (Q8 B):
   - it would skip ADR-108 §2's operator-run refresh from PROD;
   - it would need a token allowed to start workflows in a job that parses pzszerm.pl's HTML.
4. **Take the birth year from FencingTimeLive.** Not possible: its live data carries no birth year (ADR-100). Only an uploaded FencingTime XML sometimes does.
5. **Get past the gate** with a set cookie or a driven browser. Out of bounds. On 2026-10-06, the in-app browser was driven to two Poznań tournament pages for the LOCAL rehearsal, which did exactly that. Those copies never reached an environment, and they were deleted on 2026-10-07.

## Consequences

**New:**

- `supabase/migrations/20261007000001_pzsz_start_list.sql`: the table, `fn_pzsz_start_list_store`, `fn_pzsz_start_list_purge`.
- `supabase/tests/109_pzsz_start_list.sql`.
- `python/scrapers/pzsz_start_list_store.py`: capture, the stored form, the Management API store, the `store` command.
- The `capture` job in `pzsz-sync.yml`.

**Changed:**

- `Starter` is year-only; `start_list_sha256` hashes name and year.
- `ingest_cli._ingest_pzsz_event_rounds` captures, then reads the store, or takes the lists it is given.
- `promotion/plan.plan_event` and `promotion/replay` pass the stored lists.
- `pzsz_sync` gains `--capture-start-lists`.
- `DbConnector` gains `store_pzsz_start_list` and `fetch_pzsz_start_lists`.

**Not changed:** ADR-111's admission rule, the bot, and `ingest-event.yml`.

**Tests:** pgTAP 109.1–109.6 (20 assertions); pytest PZSZ.SL.03–04, PZSZ.CAP.01–05, PZSZ.ROUTE.04–07, PROMO.REPLAY.29–31 and pzsz.49–53.

**LOCAL rehearsal (2026-10-07), with synthetic pages and every pzszerm.pl request answered by the gate page:**

- the saved pages stored 2 versions, and a second store 0;
- the ingest of `PPS1s-2026-2027` made one request, met the gate and ran from the store; the run finished with both start-list hashes recorded;
- promote's read-only CERT side read both lists back by their hashes, and the plan made no request and showed no source difference.

**Poznań (Q10 A):** the first day pzszerm.pl serves pages after the release, the capture stores its lists and Telegram names the ingest. No pages are saved by hand. The capture window for Poznań closes on 17 October (14 days after its start). After that, the CERT ingest's own capture, or saved pages, still store its lists.
