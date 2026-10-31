# ADR-113: Ingest and Promote Carry Every Organizer's Event

**Status:** Accepted (decided by the user in chat on 2026-10-17: the plan `doc/plans/ingest-and-promote-every-organizer-2026-10-17.html` and Q1–Q5, all A). Implemented test-first and rehearsed on LOCAL on 2026-10-17 with MSW-2026-2027 (Tbilisi): the CERT-equivalent ingest and a promote with LOCAL standing in for PROD both stored 65 results in 21 tournaments, 2,175.53 points, and the apply ended on the run's fingerprint. Released to CERT and PROD on 2026-10-17 (Release run 39038074124); the same day MSW-2026-2027 was ingested on CERT and promoted to PROD, 65 results and 2,175.53 points, with fingerprint `1718b9410d7f` on both.
**Date:** 2026-10-17
**Amends:** [ADR-108](108-promote-replays-verified-cert-ingestion.md) (§2: `ingest` runs the refresh from PROD itself; §9 and the amendment of 2026-10-06: EVF and FIE events are on the route, nothing refuses them), [ADR-111](111-pzsz-results-admitted-by-surname-name-birth-year.md) (§6: "EVF moves onto it in the next plan" is done, and FIE with it; Open items, out of scope: the daily close now covers PZSz, EVF and FIE events), [ADR-105](105-international-results-keep-source-bracket.md) (§5.6: the international flow exists and the URL path ingests an international event; §5.3 and §5.4 hold on the new path), [ADR-106](106-international-intake-by-identity-nationality-per-season.md) (the paths that store an international row: the EVF sync no longer stores one), [ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md) (§5: the EVF results pass compares and reports, it writes no result), [ADR-028](028-evf-calendar-results-import.md) (Results Scraping and `evf-results-import`: EVF's results are read by `ingest` when an event has no result URL; the sync imports none)
**Relates to:** [ADR-025](025-event-centric-ingestion-telegram.md) (the `ingest` and `promote` commands, whose texts now name every organizer), [ADR-066](066-min-participants-ingestion-gate.md) (the minimum of 1 that marks a bracket with no fencer of ours), [ADR-072](072-cdc-recompute-debounce.md) (the refresh and the ingest share `cert-write`), [ADR-077](077-event-lifecycle-season-skeletons.md) (the lifecycle the daily close applies), [ADR-112](112-pzsz-start-lists-are-stored-inputs.md) (the stored PZSz inputs, unchanged), [ADR-008](008-psw-msw-international-pool.md) (MSW and PSW are the FIE's)
**Source:** `doc/plans/ingest-and-promote-every-organizer-2026-10-17.html`
**Amended by:** [ADR-117](117-results-links-admin-only.md) (§7, D2 A: the refresh `ingest` runs first also copies the event's results links from PROD's Admin).

## Context

On 2026-10-06 the user decided one route to PROD for every organizer: `ingest <code>` runs the ingestion on CERT, and `promote <code>` runs the same ingestion on PROD and applies it only when it equals the verified CERT run (ADR-111 §6, recorded in ADR-108's amendment of that day). PZSz moved onto the route then. EVF was written down as "moves onto it in the next plan", that plan was never written, and FIE was never named.

On 2026-10-17, with the Tbilisi World Championships (MSW-2026-2027) to load, the route still refused every international event:

- `ingest_cli.ingest_event_from_url` refused it before fetching anything (ADR-105 §5.6), and named the Phase 5 runner;
- `promotion.plan.plan_event` refused it by name, so `promote` could not carry it;
- the daily close (`promotion/close.py`) matched only PPW and MPW codes;
- the daily EVF sync (`evf-sync.yml`) wrote EVF results into CERT with no run record, so promote had nothing to replay, and the next sync could overwrite what an ingest wrote;
- `scrape-tournament.yml` accepted `target=prod` and wrote PROD directly, a way round promote;
- the refresh of CERT's master data from PROD (ADR-108 §2) was a manual runbook step, and Telegram `ingest` did not run it, so promote could refuse a CERT run that started from older master data.

Most of the international logic already ran inside the pipeline that ingest and promote share: `ResolveFencers` admits a row by ADR-106 identity with its FIE amendment, and `Commit` keeps the source bracket's N and each fencer's source place (`SOURCE_FIELD_PLACE`) and refuses a PENDING row. What was missing was the event driver that reads the brackets, the flow rule, and the writers around the route.

## Decision

### 1 · One route, for SPWS, PZSz, EVF and FIE

`ingest <code>` (Telegram, `ingest-event.yml`, target CERT) and `promote <code>` (`promote.yml`, PROD) carry every organizer's event:

| Organizer | Types | Driver in `ingest_cli._ingest_event_rounds` |
| --- | --- | --- |
| SPWS | PPW, MPW | the domestic keep-rule (unchanged) |
| PZSz | PPS, MPS | `_ingest_pzsz_event_rounds` (ADR-111, ADR-112, unchanged) |
| EVF | PEW, MEW, the IMEW code | `_ingest_international_event_rounds` (new) |
| FIE | MSW, PSW, the IMSW code | `_ingest_international_event_rounds` (new) |

The international driver is chosen by `stages._is_international_intake`, in the place the PZSz driver is chosen. Ingest on CERT and promote's `plan_event` on PROD both call `_ingest_event_rounds`, so both run it (ADR-111 §6). `ingest <code> prod` stays refused for every event.

### 2 · Where an international event's results come from (Q3 A)

`python/pipeline/international_sources.py` reads every result URL slot the event holds, `url_event` to `url_event_5`, in slot order. When none is set and the event has an EVF id, it reads EVF's own results, recorded as the source `evf:<id>` (ADR-105 §1.5: the organiser's results first, EVF's only when nothing else exists). An event with neither refuses, naming Admin.

- An FTL schedule is read with each listing's Finished flag (`lifecycle.split_final`): a listing not finished is skipped and keeps the event IN_PROGRESS (ADR-108 §7). A finished listing whose name is not understood is recorded as not read.
- Any other URL (Engarde, 4fence, Ophardt, d'Artagnan, one results page) goes through `Fetcher.fetch_event_url_with_skips`, the reader the Phase 5 runner uses. Its brackets are final once published.
- Team brackets are skipped (ADR-105 §5.5). A bracket without one V0–V4 category, or two sources for one bracket, refuses the event before anything is written (ADR-105 §5.3, §5.4).

Every bracket is read and checked before anything is written.

### 3 · The international flow

`Flow.INGEST_INTERNATIONAL` (`engine/flows.py`, `engine/rulebook.py`) runs ParseSource, ValidateIR, ResolveEvent, ResolveFencers (intake INTERNATIONAL), ValidateCounts, AssignSourceVcat and Commit. It has none of the domestic split, combined-pool or joint-pool steps, which recount and renumber. `AssignSourceVcat` files the bracket under its own source category and refuses a bracket without one. The bracket is one tournament with the source N and each fencer's source place (ADR-105), and the rows are decided by identity (ADR-106). The organizer is FIE for MSW and PSW, EVF otherwise.

A bracket in which no row resolves to one of our fencers stores nothing (ADR-105: only our fencers' rows are stored). The run records it as `dropped`, reason "no fencer of ours", not as a failed commit, so promote's gate does not refuse it. A PENDING row still counts as a row, and Commit refuses it (ADR-106 §1).

### 4 · Promote replays an international run

- The run record keeps the slots and URLs it read (`ListingLog.sources`). `replay` passes them to `plan_event`, which reads exactly those on PROD.
- A PROD slot that is blank takes the CERT run's URL: the plan records the write, and `fn_promote_event_apply` applies it in the same transaction (migration `20261017000003_promote_apply_source_slots.sql`, `url_event_2` to `url_event_5`; `url_event` keeps its existing rule). A PROD slot that holds a different URL refuses, naming the slot. This extends ADR-086's fill-blank tier from `url_event` to every result slot.
- Listings are compared by hash, whatever their source, as for FTL listings.

### 5 · The staging report

The international section the Phase 5 runner printed is moved into `python/pipeline/international_report.py`, and the staging report that `ingest` sends to Telegram carries it: each bracket's source N, the stored rows, the foreign rows, PENDING rows with their candidates, and the FIE flag for more than 4 rows of one federation (ADR-106, amendment of 2026-10-17). The runner calls the same function.

### 6 · The daily close covers every organizer

`event-close.yml` (`promotion/close.py`) takes every IN_PROGRESS event of the active season whose code is PPW, MPW, PPS, MPS, PEW, MEW, IMEW, MSW, PSW or IMSW (it took PPW and MPW only). An international run is checked against its own recorded sources, read again by `international_sources.read_schedule`.

### 7 · `ingest` starts with the refresh from PROD (Q4 A)

`ingest-event.yml` runs `python -m python.pipeline.promotion.refresh --target cert --mode apply --event <code> --auto` before the ingestion, in the same `cert-write` group. `--auto` applies a refresh that renumbers nobody and leaves nobody unpaired. A refresh that would renumber a fencer stops before its first write (status `stopped_renumbering`, exit 3), and an unpaired one stops as before (exit 2). Telegram then reports that the refresh needs the administrator, with the report's counts, and nothing is written. ADR-108 §2's rule, that a renumbering waits for the administrator's sign-off, is unchanged.

### 8 · No other writer of results (Q1 A, Q2 A)

- **The daily EVF sync keeps the calendar and writes no result.** When EVF has results for an event of ours, it sends Telegram "send `ingest <code>` (CERT), then `promote <code>` (PROD)". The writer `evf_sync._ingest_evf_results` is removed. `evf-results-import <code>` compares that event's EVF results with CERT and writes nothing.
- **`scrape-tournament.yml` writes CERT only.** It holds no PROD secret and refuses any other target, naming `ingest` and `promote`.

### 9 · The Phase 5 runner (Q5 A)

The runner stays, for LOCAL work and for repairing a past-season event at the user's explicit request (ADR-105, amendment of 2026-10-02, decision P A). A new event of any organizer reaches CERT and PROD through `ingest` and `promote` only.

## Alternatives considered

1. **Load Tbilisi through the Phase 5 runner on each environment.** Rejected by the user: it is a second route to PROD, which ADR-111 §6 ruled out on 2026-10-06.
2. **Keep the EVF sync writing CERT (Q1 B).** Rejected: a write outside a run record leaves promote nothing to replay, and the next sync could overwrite an ingest.
3. **Keep `scrape-tournament` able to write PROD (Q2 B).** Rejected: a way round promote's verification.
4. **Refuse an EVF event until a result URL is set (Q3 B).** Rejected: EVF's results are the documented fallback (ADR-105 §1.5), and many EVF events publish nowhere else.
5. **Keep the refresh manual (Q4 B).** Rejected: promote refuses a CERT run that started from older master data than PROD's (ADR-108 §5), so a manual step forgotten once stops the event at promote.
6. **Apply every refresh automatically.** Rejected: ADR-108 §2 keeps a renumbering for the administrator's sign-off.
7. **Remove the Phase 5 runner (Q5 B).** Rejected: a past-season repair cannot use `promote`, which finds events of the active season only.
8. **Treat a bracket with no fencer of ours as a fault, or accept it in the gate.** Rejected: storing nothing is the correct outcome under ADR-105. Recording it as `dropped` at the source keeps the gate's rule, that a committed listing must have committed, unchanged for every organizer.

## Consequences

**New:**

- `python/pipeline/international_sources.py` (`event_sources`, `read_brackets`, `read_schedule`) and `python/pipeline/international_report.py` (`section_lines`);
- `ingest_cli._ingest_international_event_rounds` and `_no_fencer_of_ours`;
- `Flow.INGEST_INTERNATIONAL` and the plugin `AssignSourceVcat`;
- `DbConnector.set_event_source_url` and `RecordingConnector.set_event_source_url`;
- migration `20261017000003_promote_apply_source_slots.sql`;
- the refresh's `refuse_renumbering` and `--auto`.

**Changed:**

- `ingest_cli`: the international refusal is removed, and `url_event` is required only for a domestic event; the staging report carries the international section;
- `promotion/plan.py`: the international refusal is removed; `plan_event` takes `sources` and fills blank slots;
- `promotion/replay.py`, `promotion/run_record.py`, `promotion/close.py`;
- `plugins/ingest.py`: Commit writes the source category for `SOURCE_FIELD_PLACE`;
- `plugins/staging_formatter.py`: extra sections before the footer;
- `scrapers/evf_sync.py`: no result write; the Telegram notices;
- `.github/workflows/ingest-event.yml` (the refresh step and its Telegram notice) and `scrape-tournament.yml` (CERT only);
- `scripts/gas_telegram_bot.js`: the `ingest`, `promote`, `evf-results-import` and `t-scrape` texts and `/help`. The commands and the workflows they dispatch are unchanged, so the live bot keeps working until the file is pasted over the Apps Script project.

**Tests, written RED first:**

- `python/tests/test_route_international.py`: ROUTE.FLOW.01–04, ROUTE.SRC.01–10, ROUTE.INTL.01–04, ROUTE.PLAN.01–05, ROUTE.LIFE.01, ROUTE.CLOSE.01–02, ROUTE.REPORT.01–03, ROUTE.WRITERS.01–04 and ROUTE.REFRESH.04;
- `python/tests/test_promotion_refresh.py`: ROUTE.REFRESH.01–03; `python/tests/test_promotion_replay.py`: ROUTE.PLAN.06; `python/tests/test_gas_bot.py`: ROUTE.BOT.01;
- pgTAP `supabase/tests/110_promote_apply_source_slot.sql`: ROUTE.APPLY.01–05;
- flipped: INTL.URL.01 now expects an international event to be read before any write, not refused; PROMO.PLAN.12 keeps only the unknown-event refusal; GAS.SRC.02 expects the PROD refusal for every event.

**Verified on LOCAL, 2026-10-17:**

- the refresh `--mode plan` on CERT, read only: 373 of 373 fencers paired, none renumbered, none unpaired, 5 alias values to copy, so `ingest MSW-2026-2027` passes the automatic refresh;
- LOCAL refreshed from PROD with `--auto` and verified equal to PROD id for id; MSW-2026-2027 ingested with the workflow's arguments (run 150): 21 brackets committed, 3 dropped with no fencer of ours, 65 results, 2,175.53 points;
- the event rolled back to PROD's state and run 150 replayed through `replay()` with the real gate, plan and apply: 43 writes, status IN_PROGRESS, the apply ended on the run's fingerprint, and the stored rows equal the ingested rows.

**Found by that rehearsal and fixed here:** the first run recorded the three brackets with no fencer of ours as committed listings that had not committed, and the gate refused the promote. §3's `dropped` status is the fix (ROUTE.INTL.04).

**Not changed:** team results; past-season events (never re-ingested); the domestic and PZSz drivers; ADR-106's admission rule; scoring.

**Not proved live before the first event of each kind:** Engarde, 4fence, Ophardt, d'Artagnan and the EVF fallback are proved by fixtures only, because no closed season is re-ingested, LOCAL included. The first 2026/27 EVF event is their first live run.

## Amendment (2026-10-25, [ADR-117](117-results-links-admin-only.md) D2 A) — the refresh also copies the event's results links

The refresh of §7 now copies, in an apply with an event and after the registrations, the event's five results slots from PROD to CERT through `fn_copy_event_result_links`: PROD's links replace CERT's, compacted, and a PROD without a link leaves CERT's alone. A plain `ingest <code>` therefore reads the link an administrator set in PROD's Admin. The refresh report gains a `results links:` line. Tests: CALURL.20, pgTAP CALURL.22.
