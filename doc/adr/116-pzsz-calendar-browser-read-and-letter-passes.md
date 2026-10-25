# ADR-116: The PZSz calendar reads past the gate with a browser engine, and reads the organizer letter in four abstaining passes

**Status:** Accepted (the plan `doc/plans/pzsz-calendar-robust-rewrite-2026-10-21.html` was signed off by the user in chat on 2026-10-21, D1–D8). Implemented test-first; the letter reader verified against a 29-letter corpus with zero wrong values. Released to CERT and PROD on 2026-10-22 (the feature commit is `c9bd4094` on `main`; that day's Release run succeeded). Amended 2026-10-25: a scheduled capture works on the Warsaw date it was due (§7; see the amendment).
**Date:** 2026-10-21
**Amends:** [ADR-087](087-pzsz-senior-calendar-source.md) (§4: a real browser engine now reads past pzszerm.pl's JavaScript check, superseding the 2026-10-06 amendment's "the check fails the run"; §7: the letter is read for the venue address, the fee and the dates by structured passes, not the single `Miejsce Zawodów` line; §9: the workflow is rewritten — the run processes each event and field independently and never stops part-way), [ADR-112](112-pzsz-start-lists-are-stored-inputs.md) (§2: the daily ±14-day capture becomes a D−4..D−1 window of five runs a day in its own CERT-only workflow; §5: the "send the ingest" notice moves into the calendar run)
**Relates to:** [ADR-088](088-calendar-location-contract.md) (the city stays the location contract's; the letter fills `txt_venue_address`), [ADR-081](081-cert-prod-event-reconciler.md) (compare-and-set is the reconciler's field-ownership split made explicit per field), [ADR-036](036-prod-export-local-mirror.md) (the PROD mirror, whose venue-address rule this changes for PZSz), [ADR-078](078-gdpr-data-handling.md) (no real letter enters the public repository; the golden set is PII-free), [ADR-108](108-promote-replays-verified-cert-ingestion.md) (PROD never scrapes; promote replays CERT-stored lists by hash), [ADR-083](083-server-enforced-authorization.md) (the new tables are `service_role` only), [ADR-100](100-pzsz-senior-result-ingestion.md) (the ingest the run's notice names)
**Source:** `doc/plans/pzsz-calendar-robust-rewrite-2026-10-21.html`, `doc/plans/pzsz-calendar-events-findings-2026-10-21.html`, `supabase/migrations/20261021000001_pzsz_calendar_provenance.sql`, `supabase/migrations/20261021000002_pzsz_mirror_address_overwrite.sql`, `python/scrapers/pzsz_browser.py`, `python/scrapers/pzsz_sources.py`, `python/scrapers/pzsz_write_rules.py`, `python/scrapers/pzsz_letter.py`, `python/scrapers/pzsz_sync.py`, `python/scrapers/pzsz_start_list.py`, `python/scrapers/pzsz_start_list_store.py`, `.github/workflows/pzsz-sync.yml`, `.github/workflows/pzsz-start-lists.yml`

## Context

Since 3 October 2026 pzszerm.pl has served its `pzs-m` JavaScript cookie check on the listing and event pages. Our HTTP client runs no JavaScript, so `refuse_js_check()` (ADR-087's 2026-10-06 amendment) recognised the check page and stopped the run with nothing written. Every PZSz calendar sync since has gone red, and the start lists for the 24–25 October round-I events were never captured by the daily job. ADR-112 worked around this for start lists by storing them while the gate is open and reading from the store on gated days; the calendar sync itself had no such path and simply failed.

Two things the earlier design did not do made the failure total rather than partial:

- **The run stopped at the first refusal.** One gated page, or one event that could not be read, ended the whole run — so a transient problem on one event lost the others.
- **The letter was barely read.** ADR-087 §7 filled `url_invitation` when the section stopped being empty and ADR-088 took a venue title from the komunikat's `Miejsce Zawodów` line, but the fee, the street address, and the start and end dates — all of which the letter states and the listing often does not — were left to an admin. The 31-letter sample measured against the then-current reader: **10 right, 4 wrong (all the Poznań payee/letterhead address), 16 missed or partial.**

The user's binding decisions (21 Oct, recorded in the plan): work from our own CERT list of events; read a PZSz page only while the event is in the future; read every gated page with a real browser engine that runs the page's own JavaScript — not a forged cookie, not a driven login, not a solved CAPTCHA; read the letter in independent passes that abstain rather than guess; let one event or field never stop another; one Telegram digest a run; the exit status red only for a genuine fatal.

Getting past the gate by forgery was declined twice before and stays declined. A headless Chromium that loads the page and runs its own check script is the site answering its own challenge in a real engine — the same thing a person's browser does — and it was proven on 21 October against the live gate (Gdańsk men's foil, 58 fencers).

## Decision

### 1 · Every gated pzszerm.pl page is read with a headless browser engine

`python/scrapers/pzsz_browser.py` launches headless Chromium through Python Playwright (`playwright>=1.47`, Chromium installed in CI) and loads the listing, event and tournament pages, letting the page run its own `pzs-m` script until the real content renders. `GatedFetcher.fetch(url, params)` reloads past the check up to a small number of attempts with a backoff; `browser_fetch()` is a context manager that launches one browser for the whole run. The `render` seam is injectable, so unit tests drive a fake and never start a browser.

The letter download (`/test/fileDownload.php`) and the home page are **not** gated and are fetched over plain HTTP as before. ADR-087 §4's truncation guard is unchanged: a listing response at or above the 70-row cap still raises, because the browser clears the gate but does not change the cap.

The local sandbox may block the browser; CI runs it. Reading the page with an engine is a read, not a write, and touches no account.

### 2 · The run works from our list, one event and one field at a time, future only

`run_calendar()` (`python/scrapers/pzsz_sync.py`) reads our CERT calendar, not PZSz's listing, as the set of events to maintain. For each event that is **in the future** (first day strictly after today in Warsaw) it fetches the listing row, the home-page row and — once the letter exists — the letter, and decides each of six fields on its own. An event whose first day has arrived is never read from pzszerm.pl again; from then on the operator supplies the FencingTimeLive link.

Each field and each event is independent: an exception reading one event, or one field that cannot be decided, is recorded and the run moves on. The run never aborts part-way.

Six fields are decided (`_DECIDED_FIELDS`): `url_invitation`, `txt_location`, `dt_start`, `dt_end`, `txt_venue_address`, `num_entry_fee`. `url_invitation` and `num_entry_fee` are **fill-blank-only** (written once while empty, never overwritten — ADR-087 §7, ADR-081); the city, the address and the two dates are read every run while the event is ahead, because an organizer moves a venue or a date after first publishing it.

### 3 · The letter is read in four passes that abstain rather than guess

`pzsz_letter.read_letter(bytes, LetterContext)` is **structure-agnostic**: PZSz letters share no layout, so the reader keys on content, not position. It extracts two pypdf text views (plain and layout), or the text of a DOCX or HTML letter; a letter with no extractable text (a scan) yields `has_text=False` and nothing else (the admin enters its fields — ADR-087's "fill-when-available" extended). It normalises both views (§8 below), segments each line into a region by the label that last opened one, and runs four passes:

- **Pass 1 — city (validate only).** The city is the location contract's (ADR-088) and is never rewritten by the letter. The pass reads the city of a postcode in the venue section and reports whether it agrees with the stored city; a declined or adjectival form still agrees (a folded-stem compare). It warns on a genuine disagreement and is silent when the letter carries no venue postcode.
- **Pass 2 — the venue address** (§4 below).
- **Pass 3 — the fee.** The individual entry fee in złoty, in the sanity range 1–500; a team amount, a euro prize, and a payment deadline are excluded. Fill-blank-only.
- **Pass 4 — the start and end dates.** Dates are scanned from both views in eleven shapes; a deadline, entry or payment date is excluded, the rest kept only if in season and within ten days of the stored start. The earliest is the start, the latest the end (at most four days apart). A note flags a letter that looks copied from last year (a date a year off) or whose event dates sit outside the window (a possible move). The letter wins over the listing for the dates.

A pass that is not sure writes nothing. When two values compete (two different individual fees, two addresses that score within three of each other) the pass abstains and the run reports both for the admin.

### 4 · Pass 2 scores every street-bearing line and takes the clear winner

The address is where the old reader went wrong — it published the payee's address from the bank-transfer block. The new pass scores every line that carries a street marker (`ul.`, `al.`, `pl.`, `os.`, `rondo`, …) by a weight table and takes the best **only when it scores at least 5 and leads the next different address by at least 3**; otherwise it reports two candidates or nothing. The weights (`_score_street`):

| Signal | Weight |
| --- | --- |
| line is in the venue section | +5 |
| a venue label is on this line or within two above | +2 |
| a house number is present (postcode removed first) | +2 |
| a hall word is present (`hala`, `AWF`, `AZS`, `OSiR`, `szkoła`, …) | +1 |
| the postcode's city is the event's city | +1 |
| the same street is found in both text views | +1 |
| in the fee/account section, or near `konto`/`przelew`/`tytułem` | −6 |
| in a lodging section, or near `hotel`/`nocleg` | −6 |
| after `wjazd od` / `wejście od` / `parking` / `dojazd` | −5 |
| in the letterhead or a contact line | −5 |
| in the organizer section with a postcode of another city | −3 |

The winning line is assembled into the full venue line: the hall name from a hall-word line just above (a hall split from its street across the line break, T6), the house number from the next line when the street wrapped (T7), the label prefix stripped, a parenthesised entrance clause dropped (T5). Across the 29-letter corpus this chooses the venue and never the payee, the organizer's other-city club, or a hotel.

### 5 · Every write is compare-and-set, recorded with its source and evidence

`fn_pzsz_apply_event(p_id_event int, p_payload jsonb)` (migration `20261021000001`, `SECURITY DEFINER`, `service_role` only) applies each field with `UPDATE … WHERE col IS NOT DISTINCT FROM $expected`: the run passes the value it last saw, and a row that no longer holds it (an admin changed it by hand) is left alone and recorded as `hand_changed`, never overwritten. Three insert-only provenance tables record what happened:

- `tbl_pzsz_field_state` — the value last written by the run for each `(event, field)`, with its source, evidence line, the letter's SHA-256 and the parser version, so the next run knows what it may replace;
- `tbl_pzsz_source_report` — what each source said for each field, so a lower-ranked source that disagrees is reported once and not every day;
- `tbl_pzsz_check` — one row per `(scope, check)` run-health state, so a condition (a gated source, a stored-list notice) is announced when it changes and not repeated.

Sources rank letter (3) > listing (2) > home page (1). The eight write rules live in one pure function, `pzsz_write_rules.decide()`: a blank field takes the best candidate; an equal-or-higher-ranked source replaces; a lower-ranked disagreement is reported once; a value an admin changed is never overwritten.

### 6 · The PROD mirror overwrites the PZSz venue address

Migration `20261021000002` rebuilds `fn_mirror_events_to_prod` from the live definition with one line changed: for a PZSz event (the payload carries `id_pzsz_event`, or the PROD row already has one) the mirror **overwrites** `txt_venue_address` from CERT, rather than filling it only when blank. The calendar run owns the PZSz address on CERT (§5), so CERT is its source of truth and must win on PROD; every other organizer keeps the existing fill-blank-when-empty behaviour. No other line of the function changes.

### 7 · Start lists are captured only in the D−4..D−1 window, in their own CERT workflow

ADR-112's daily capture (every PZSz event within 14 days of today, as a step of `pzsz-sync.yml`) is replaced by a dedicated CERT-only workflow, `pzsz-start-lists.yml`, that runs five times a day (06:00–21:00 Warsaw, both DST; since 2026-10-24 eleven minutes past each hour, off the start of the hour where GitHub delays scheduled runs (WFCRON.01)) and captures only the events whose first day is **one to four days away**. A PZSz start list exists only in that window — published four days before and taken down when the event starts — so capturing outside it is wasted, and a missed window stops the result ingest (the birth year, ADR-111). Two independent checks compute the window (`select_window_events` and `read_event_start_lists_for_capture`'s own guard) so a single bug cannot widen it. The 25 October DST change is covered by the cron choice. PROD never scrapes: promote replays the CERT-stored lists by hash (ADR-108, ADR-112 §4). The capture step is removed from `pzsz-sync.yml`.

### 8 · One Telegram digest a run; the exit status is set last

The run collects plain lines, `⚠️` warnings (including a source that was gated on the first run of the day) and `❌` fatals into one `_Digest` and sends it once. The process exit status is computed **last**, from the digest: red only for a genuine fatal on a named event (a start-list window missed, a write rejected because CERT was unreachable), green otherwise — a gated source or an unreadable letter is a warning, not a failure, because the run did everything it could for every other event. The "send the ingest" Telegram notice of ADR-112 §5 moves here (R5): when a past PZSz event's `url_event` no longer points at pzszerm.pl and a start list is stored and no CERT run has finished, the digest names the `ingest` command; it is announced once, through `tbl_pzsz_check`.

### 9 · The letter reader is proved by a golden set and a mutation suite

Two gates protect the reader:

- **A golden set** (`python/tests/pzsz_golden_letters.py`, `test_pzsz_letter_golden.py`): twelve letters, each reproducing a documented shape or trap, read through `read_letter` with every field checked exactly. A wrong value fails; an abstention is asserted where the letter is genuinely ambiguous.
- **A mutation suite** (`test_pzsz_letter_mutations.py`): twenty-two operators — dash and space variants, tripled glyphs, letter-spacing, soft hyphens, a street split across the break, swapped label forms, and injected noise that competes for the answer (a payee account block, an other-city organizer, a hotel, a euro prize, a payment deadline, a copied last-year date, a duplicated letter) — applied in random chains to the golden bases, about 6,000 cases. The invariant is absolute: the address, the fee and the dates are the golden value or nothing, never a different one. The reader may abstain; it may never guess.

Two decisions departed from the plan's letter and are recorded here so they are not read as drift:

- **The venue-line length cap is 120 characters, not the plan's 80.** The real Oborniki venue is 91 characters with its full hall name (*Hala Sportowa Ośrodka Sportu i Rekreacji w Obornikach Śląskich, ul. Józefa Poniatowskiego 22*). The plan's worked example abbreviated it to *OSiR*; abbreviating is guessing a name the letter did not write, so the reader emits the hall verbatim and the cap is widened to admit it. The cap is a sanity bound against a whole paragraph, not a style limit.
- **The committed golden set is PII-free shapes, not the 31 real letters "masked".** ADR-078 forbids a real organizer letter in this public repository — the files carry fencer names, bank-account numbers and organizers' private telephone and e-mail. The golden letters are invented clubs, streets and people on the real shapes; the evidence that the reader is right on the real letters is the **29-letter corpus sweep (zero wrong values)**, run from a throwaway scratchpad that is never committed. Verified end to end: Poznań, Konin and the others' postcodes confirm the city; Gdańsk, Szczecin and Oborniki find the hall and street and abstain on an absent postcode; the Szczecin 24–25 October range reads as a range; the Oborniki three-line split assembles exactly; the one scanned letter returns `has_text=False`.

The normaliser (§8, `_normalise`) that both passes build on: Unicode NFKC; invisible characters and no-break spaces removed; every dash and curly quote mapped to its plain form; bullets to spaces; tripled glyphs collapsed (*PPPUUUCCCHHHAAARRR* → *PUCHAR*, T12); letter-spaced words rejoined with their word breaks kept (*M i e j s c e   z a w o d ó w* → *Miejsce zawodów*, T11); end-of-line hyphenation rejoined; a footnote digit glued to a label word stripped (*Startowe3* → *Startowe*, T13).

## Alternatives considered

1. **Forge the gate — set the `pzs-m` cookie, replay the pixel, or drive a login.** Declined, twice, before this ADR and again here. A real engine answering the site's own challenge is a read a person could make; forging the token is not, and it is brittle the day the check changes.
2. **Keep the HTTP client and wait for the gate to open.** Rejected: gated stretches have lasted up to six days (ADR-112), and the round-I events needed their dates and venues now, not whenever the gate next lifts.
3. **Position-based letter parsing (read the line under the `Miejsce Zawodów` label).** Rejected: the 31-letter sample has no shared layout — the venue is one line, three lines, or label-less; the street number wraps; the hall name splits from its street. A position rule gets 10 of 31 and publishes the payee address for 4. A content scorer that abstains is the only shape that never publishes a wrong address.
4. **Let the run stop on the first gated or unreadable page**, as before. Rejected: it makes one event's transient problem lose every other event's good data. Independence per event and per field, with a digest and a last-computed exit status, is the opposite failure mode.
5. **Commit the real letters, masked.** Rejected under ADR-078: redacting 29 large view files by hand is error-prone for a public repository, and a leak is irreversible. PII-free shapes plus the throwaway-corpus sweep give the same regression protection without the risk.

## Consequences

**New:**

- `python/scrapers/pzsz_browser.py` — the headless-browser fetcher with an injectable render seam.
- `python/scrapers/pzsz_sources.py` — listing rows, the newest letter link, the home-page "Najbliższe zawody" table.
- `python/scrapers/pzsz_write_rules.py` — the eight write rules as one pure `decide()`.
- `python/scrapers/pzsz_letter.py` — the structure-agnostic reader (normalise, segment, passes 1–4).
- `supabase/migrations/20261021000001_pzsz_calendar_provenance.sql` — three provenance tables and `fn_pzsz_apply_event`; `supabase/tests/112_pzsz_calendar_provenance.sql`.
- `supabase/migrations/20261021000002_pzsz_mirror_address_overwrite.sql` — the PZSz venue-address overwrite in `fn_mirror_events_to_prod`; `supabase/tests/113_pzsz_mirror_address_overwrite.sql`.
- `.github/workflows/pzsz-start-lists.yml` — the CERT-only five-a-day capture in the D−4..D−1 window.
- `python/tests/pzsz_golden_letters.py`, `test_pzsz_letter_golden.py`, `test_pzsz_letter_mutations.py`.

**Changed:**

- `python/scrapers/pzsz_sync.py` — `run_calendar` rewritten: browser fetch, per-event/per-field independence, compare-and-set via `fn_pzsz_apply_event`, one digest, exit status last, the ingest notice.
- `python/scrapers/pzsz_start_list.py`, `pzsz_start_list_store.py` — the D−4..D−1 window, two independent checks, the capture run.
- `.github/workflows/pzsz-sync.yml` — the capture step removed; the sync job installs Playwright and Chromium.

**Not changed:** ADR-088's city path and the location contract; ADR-111's admission rule; ADR-112's stored-list store, its hash, its `service_role` grant and the PROD-never-scrapes promote; the bot.

**Tests:** pgTAP 112.1–112.8 (20 assertions, `112_pzsz_calendar_provenance.sql`) and 113.0–113.4 (5 assertions, `113_pzsz_mirror_address_overwrite.sql`); pytest the PZSz suite (255 cases), including the golden set (12) and the mutation suite (~6,000). Letter reader verified on a 29-letter corpus, zero wrong values.

**Deferred, not fixed:** the venue-line cap is a sanity bound, not a style rule; a legitimately long venue publishes verbatim. The golden set is PII-free shapes; a real-letter regression would be caught by re-running the throwaway corpus sweep, not by CI.

## Open items

None. D1–D8 are decided in the plan; D9 and D10 were dropped there.

## Amendment (2026-10-25) — a scheduled capture works on the day it was due

§7 had every capture take "today" from the Warsaw clock when it started. GitHub starts scheduled runs late: 0.2–3.5 hours, measured on 22–24 October 2026 while the crons were on the hour. The final run's cron is 19:11 UTC, which is 21:11 in Warsaw in summer and 20:11 in winter, so a final run 2 h 49 min late in summer, or 3 h 49 min late in winter, started on the next Warsaw day. D−1's final run then saw day D, outside the window: it captured nothing and raised no alarm for a list still missing. D−2's final run saw D−1, the window's last day, and called an event fatal a day early. The user answered P6 on the W2 sign-off sheet (`doc/plans/github-actions-w2-sign-off-2026-10-25.html`) with A on 25 October 2026.

- **The day.** `pzsz-start-lists.yml` passes the cron that fired (`--cron`). `scheduled_day` takes the latest moment at or before the start that matches the cron's UTC minute and hour, and reads its Warsaw date. That date is "today" for both checks of the window and for the first-run and final-run messages. A manual run, with no cron, keeps the Warsaw clock date. A cron that is not one daily time is refused, and the refusal reaches Telegram.
- **Unchanged.** The window (D−4..D−1), its two independent checks, the five crons and the first-run and final-run flags.
- **Tests.** pytest PZSZ.SL.10–12 (`python/tests/test_pzsz_start_list_capture.py`): the due date of a late run after Warsaw midnight and of one after UTC midnight; D−1's late final run still raises the alarm and D−2's raises none; the capture command uses the due date, and a manual run the clock date; the workflow passes the cron.
