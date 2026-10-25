# ADR-117: Results Links Are Set in Admin Only; Calendar Automation Writes Only the Organizer's Letter

**Status:** Accepted (signed off by the user in chat on 2026-10-25 as S1 A, "ADR-117 as drafted", from `doc/plans/pzsz-results-url-rca-2026-10-25.html` §09). Implemented test-first and verified on LOCAL; released with migration `20261025000001`.
**Date:** 2026-10-25
**Supersedes:** [ADR-039](039-stale-event-gate.md) rev 4 (the `url_event` date gate and `url_event_if_concluded`) and rev 2's step 2 "populate `url_event` with the resolved URL" (the self-heal now rewrites the dates only)
**Amends:** [ADR-028](028-evf-calendar-results-import.md) (Refresh Semantics: `url_event` is no longer a refreshed column; the detail page is still fetched for the letter), [ADR-040](040-multi-slot-event-urls.md) (`fn_refresh_evf_event_urls` writes no slot; compact-on-save holds for the Admin saves), [ADR-043](043-evf-event-allocator.md) (a `CURRENT_SLOT_REUSE` write carries no results slot), [ADR-081](081-cert-prod-event-reconciler.md) (§3: the mirror carries no results slot, in CREATE or UPDATE), [ADR-087](087-pzsz-senior-calendar-source.md) (§7: the PZSz create writes no results slot), [ADR-116](116-pzsz-calendar-browser-read-and-letter-passes.md) (§8: the "send the ingest" notice fires when an administrator has set the link)
**Relates to:** [ADR-108](108-promote-replays-verified-cert-ingestion.md) (§9: promote fills an empty PROD slot from the CERT run, unchanged), [ADR-113](113-ingest-and-promote-carry-every-organizer.md) (an EVF or FIE event with no link is ingested from EVF's own results, unchanged), [ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md) (the fill-blank tier of `url_event`), [ADR-025](025-event-centric-ingestion-telegram.md) (`ingest <code>` reads the stored link), [ADR-029](029-tournament-url-auto-population.md) (`populate-urls.yml` reads `url_event`), [ADR-112](112-pzsz-start-lists-are-stored-inputs.md) (§5, the notice ADR-116 moved), [ADR-053](053-evf-parity-gate.md) (the parity sweep's source), [ADR-111](111-pzsz-results-admitted-by-surname-name-birth-year.md) (the PZSz ingest that reads the link)
**Source:** `doc/plans/pzsz-results-url-rca-2026-10-25.html`, `supabase/migrations/20261025000001_calendar_never_writes_results_link.sql`

## Context

`tbl_event.url_event` … `url_event_5`, shown in Admin as **URL wyników**, serve three purposes:

- the calendar card's "Wyniki" link;
- the domestic and PZSz ingest's FencingTimeLive schedule (`ingest_cli._ingest_event_rounds`);
- the EVF and FIE ingest's list of sources, read in slot order; EVF's own results are read only when every slot is empty (`international_sources.event_sources`).

The organizer's letter has its own field, `url_invitation`, shown as **URL komunikatu**.

Calendar automation wrote calendar pages into URL wyników three times:

1. **EVF before the event, until 26 July 2026.** The sync stored the EVF event page for every event. ADR-039 rev 4 added a date gate (`url_event_if_concluded`) and a one-time clean-up.
2. **EVF again, the same morning.** The clean-up ran on CERT and PROD at 07:37 and 07:44 UTC. The scheduled `evf-sync.yml` at 08:30 still ran the old code: the fix was committed at 18:36 (`260b4c36`). It wrote the pages back on CERT, and its reconcile filled PROD's now-empty slots with them: 14 events, "trigger: schedule" (`doc/staging/reconcile/SPWS-2026-2027.20260726-083331Z.md`). An administrator moved them to URL komunikatu on CERT on 9 August; the mirror never carries a clear, so PROD kept them. Even with the gate deployed, the gate still wrote the page once the event had ended.
3. **PZSz from creation, since 3 September.** The listing parser built `pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=<id>` for every row, and `pzsz_sync.build_insert_sql` put it into `url_event`. It has done so since the first PZSz commit, `034f41fa`. No ADR or plan decided it.

On 25 October 2026 the effect reached a results run: a LOCAL ingest of PPS1f read the pzszerm.pl page as its FTL schedule and finished green with nothing read. On the same morning the user had set the real FTL link in PROD's Admin; CERT and LOCAL still held the page. On PROD, 14 EVF events of 2026/27 carried the EVF page as their results link, 12 of them the same link as URL komunikatu. A calendar page there also replaces EVF's own results as the source of an EVF ingest.

The user's rule, 25 October 2026: *"there are two separate fields for event URLs, URL komunikatu and URL wyników: exclude the second one from the calendar updates. Fix all calendar scrapers and redirect them to write only to URL komunikatu. URL wyników stays empty until the Admin UI populates it."*

## Decision

### 1 · No calendar automation writes a results slot

No calendar automation writes `url_event` … `url_event_5`, before or after the event. In the Python payloads and in the SQL functions alike, that covers:

- the EVF sync: create, reuse, refresh and the date self-heal;
- the PZSz sync's create;
- the CERT→PROD calendar mirror, in CREATE and UPDATE.

| Writer | Before | Now |
| --- | --- | --- |
| PZSz create (`pzsz_sync.build_insert_sql`) | the pzszerm.pl event page | no results slot; the parser's key is renamed `url_page` |
| EVF create and reuse payloads (`evf_sync`) | the EVF page once the event had ended | no results slot; `url_event_if_concluded` is removed |
| `fn_refresh_evf_event_urls` | filled empty slots 1–5 | writes no results slot |
| EVF date self-heal (`_heal_future_completed`) | stored the matched calendar link | uses it for the date only |
| `fn_mirror_events_to_prod` and `promote.py --mode calendar` | CREATE copied slots 1–5; UPDATE filled empty ones | neither carries a results slot |
| `fn_ingest_evf_calendar(JSONB, INT)` | wrote the page | writes no results slot |

### 2 · Calendar automation writes only the organizer's letter

The calendar writes the organizer's letter to `url_invitation`, under the existing fill rules, and never a calendar page. The calendar page is not a placeholder there either: the PZSz letter passes read `url_invitation` as the letter to download, and the EVF refresh and the mirror fill it only while it is empty, so a page would block the real letter. The PZSz page can always be rebuilt from `id_pzsz_event`.

### 3 · Results slots are filled in Admin

A results link reaches the database only from a person:

- Admin (`fn_create_event`, `fn_update_event`);
- the `url_event` input of `ingest-event.yml`, which saves it before the run;
- promote, which fills an empty PROD slot from the CERT run it replays (ADR-108 §9, ADR-113).

The last two carry a link an operator supplied. Both are unchanged.

### 4 · A one-time clean-up ships with the fix

`fn_clear_calendar_results_links()` removes a calendar page from the results slots and closes the gaps (`fn_compact_urls`). It acts on a slot only when all three hold:

- the event's season has not ended;
- the value is a pzszerm.pl or veteransfencing.eu event page;
- no administrator save ever changed that slot to that value. An admin save that repeats an unchanged link while editing another field does not count.

It ships in the same migration as the function changes, so it cannot run before the fix. `seed_post_backfill.sql` runs it after a fresh bootstrap, where the seed loads after the migrations. It is `SECURITY DEFINER` and granted to `service_role` only.

### 5 · The PZSz "send the ingest" notice waits for the administrator's link

The notice of ADR-116 §8 (R5) names the `ingest` command for a past PZSz event when an administrator has set `url_event`, a start list is stored, and no CERT run has finished. Before, it fired when the link "no longer pointed at pzszerm.pl".

## Alternatives considered

1. **A date gate (ADR-039 rev 4).** Rejected: a calendar page never holds results, and the gate refilled the data its clean-up had just cleared.
2. **The calendar page as a URL komunikatu placeholder.** Rejected: the letter passes would read it as the letter, and the fill-blank rules would then block the real letter.
3. **A database `CHECK` on the page patterns.** Not now: the seed loads after the migrations, and a pattern cannot express "Admin only". The functions and the tests are the guard.

## Consequences

- An EVF event without an Admin link is ingested from EVF's own results (ADR-113).
- The calendar card shows no "Wyniki" link until an administrator fills one.
- A CERT ingest needs the link on CERT: the `url_event` input of `ingest-event.yml`, or the administrator's value.
- The release clears 7 calendar pages on CERT (PEW0efs, PEW1f, PPS1e, PPS1f, PPS2e, PPS2f, PPS2s) and 17 on PROD (14 EVF events of 2026/27 and PPS2e, PPS2f, PPS2s). The administrator's FTL links on PROD's PPS1e and PPS1f are not calendar pages and stay. Closed seasons are untouched.
- The ingest refuses a link that is not an FTL schedule, before it is saved or anything is wiped, and a schedule that lists nothing. Both close the run FAILED (issue #3 of the plan, CALURL.16–17). `--dry-run` with `--flow` is refused, because the flow writes live (D3 A, CALURL.18), and the `--url-event` help says the link is saved (CALURL.19).
- **New:** migration `20261025000001_calendar_never_writes_results_link.sql`; `python/tests/test_calendar_results_link.py` (CALURL.01–07); `supabase/tests/114_calendar_never_writes_results_link.sql` (CALURL.10–15).
- **Changed:** `pzsz_calendar.py` and `pzsz_sources.py` (`url_page`), `pzsz_sync.py`, `evf_sync.py`, `evf_calendar.py` (`url_event_if_concluded` removed), `promote.py`, `ingest_cli.py`. Five earlier assertions now pin the new rule: `prom.8`, `evf.47`, pgTAP `12.5`, `15.6` and `EVF.URL.02`; `evf.63` is removed with its helper.
- **Tests:** CALURL.01–08 and CALURL.10–19 (09 is not used; `python/tests/test_calendar_results_link.py`, `test_pzsz_calendar.py`, `test_ingest_run.py`, `test_pzsz_routing.py`; pgTAP `114`).
