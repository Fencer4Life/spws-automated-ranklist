# ADR-111: PZSz Results Are Admitted Only on Surname, First Name and Birth Year; Ingest for CERT, Promote for PROD, for Every Organizer

**Status:** Accepted (decided by the user in chat on 2026-10-06: the admission rule, the copy of the EVF admission, Q1 "ingest for CERT, promote for PROD — the same thing", Q2 A, Q3 A, Q4 A). Implemented and rehearsed on LOCAL on 2026-10-06 (`doc/plans/pzsz-results-plugin-2026-10-06.html` §5a), and released to CERT and PROD the same day (main `2bc34500`). The first CERT ingest, of `PPS1s-2026-2027`, met pzszerm.pl's JavaScript check and wrote nothing; under D1 A it is sent again later. Amended 2026-10-07 by [ADR-112](112-pzsz-start-lists-are-stored-inputs.md): the start list is a stored input. The CERT ingest reads the newest stored version on a gated day, and promote reads the lists CERT used from CERT by their hashes and never contacts pzszerm.pl (§6). D1's "send it again later" applies only while no list of the event has ever been stored. Amended 2026-10-17 by [ADR-113](113-ingest-and-promote-carry-every-organizer.md): EVF and FIE are on the route (§6), and the daily close covers PZSz, EVF and FIE events. Amended 2026-10-25 (K1 A, signed off in chat): a user-confirmed alias counts when no fencer of ours carries the name, with the start list's birth year read under our canonical name; see the amendment at the end.
**Date:** 2026-10-06
**Amends:** [ADR-100](100-pzsz-senior-result-ingestion.md) (the matching rule for a PZSz bracket, the review queue no longer written, the source of the birth year), [ADR-108](108-promote-replays-verified-cert-ingestion.md) (promote replays a PZSz run too; one route to PROD for every organizer)
**Relates to:** [ADR-106](106-international-intake-by-identity-nationality-per-season.md) (the EVF admission that is copied, left unchanged), [ADR-105](105-international-results-keep-source-bracket.md) (the whole field's N and the original place), [ADR-110](110-ranking-entry-by-roster.md) (the fencer table is the ranking entry), [ADR-087](087-pzsz-senior-calendar-source.md) (the PZSz calendar and `id_pzsz_event`), [ADR-103](103-spws-place-medal-engine-per-type.md) and [ADR-104](104-spws-evf-joined-engine-replaces-place-medal.md) (PPS and MPS stay on EVF classic, unchanged), [ADR-025](025-event-centric-ingestion-telegram.md) (the `ingest` and `promote` commands, unchanged)
**Source:** `doc/plans/pzsz-results-plugin-2026-10-06.html`

## Context

On 2026-10-06 `ingest PPS1s-2026-2027` (Poznań, the first PZSz Polish Cup of 2026/27, men's and women's sabre) ran the PPW flow. That flow is the only one the URL ingest knows: `ingest-event.yml` passes `--flow ingest_domestic`, and `ingest_cli.py` hard-codes `organizer_hint="SPWS"` for every listing. The PPW flow read the FencingTimeLive bracket name "Senior" as V0. It then matched place 18, "KROCHMALSKI Jakub", by name to our fencer id 156, born 1976, and refused the listing because 1976 is two categories away from V0 (run 37475365271). Nothing was written.

The PZSz start list shows another person of the same name, a junior from another club. The women's list holds a second namesake, also a junior, 31st, against our NOWAK Marta, born 1979. Neither of the 99 starters matches a fencer of ours on surname, first name and birth year.

ADR-100 built a PZSz flow (`Flow.INGEST_PZSZ_SENIOR`, `ingest_pzsz_senior_bracket_from_url`), but nothing calls it. Its matcher, `ResolveFencers` with the `PZSZ_SENIOR` intake, checks no birth year. It links a single same-named fencer whatever the year, links a confident fuzzy match, and queues the rest in `tbl_pzsz_match_review`. FencingTimeLive results carry no birth year at all (`ftl.parse_json` fills name, place, country and club only). Promote (ADR-108) refuses anything but the PPW flow.

## Decision

### 1 · PPS and MPS are not PPW; they are imported similarly to EVF, not exactly like it

A PZSz field is a senior competition, open to every age. It is not a veterans' event, and PZSz is not a veterans' organizer. A PZSz event never goes through the PPW flow.

### 2 · A result is kept only on surname, first name and birth year

A row is stored only when **exactly one fencer in the fencer table** matches on all three:

- the surname;
- the first name;
- the birth year.

Polish letters are folded and case is ignored. **Everything else is skipped:** a name missing from the start list, a name twice on the start list, no fencer of ours, a fencer of ours with the same name and another birth year, or two fencers of ours matching. Nothing creates a fencer, writes an alias, changes a birth year or queues a review.

Three further rules, decided in chat:

- **No PPW or MPW start is required** (unlike EVF, ADR-106). Being in the fencer table is enough.
- **An estimated birth year of ours is still compared exactly (Q3 A).** A mismatch is skipped and shown first in the report; the administrator confirms the year in Admin and ingests again.
- **Only our canonical surname and first name count (Q4 A).** Approved aliases are not used.

*Amended 2026-10-25 (K1 A):* a user-confirmed, unrevoked alias counts when no fencer of ours carries the source's name; the birth year is still the start list's, read under our canonical name. A plain matcher alias still does not count. See the amendment at the end.

### 3 · The birth year comes from the PZSz start list

FencingTimeLive gives the places. The PZSz tournament page (`pzszerm.pl/zawody/kalendarium-zawodow/turniej/?id=N`, column *Data urodzenia*) gives each starter's birth date, and its year is the birth year. The event's stored `id_pzsz_event` leads to the event page, which lists its tournaments. A row is paired with its start-list entry by the folded name.

*Amended 2026-10-07 by [ADR-112](112-pzsz-start-lists-are-stored-inputs.md):* the list is captured on a day pzszerm.pl serves it and stored on CERT as printed name and birth year; the ingest reads the newest stored version.

### 4 · A PZSz plugin, started as a copy of the EVF admission

`AdmitPzszRoster` (`python/pipeline/plugins/pzsz_admission.py`) is first committed as a plain copy of `python/pipeline/international_admission.py`, the EVF admission, and is then changed for PZSz:

- the exact birth year instead of the category band;
- no starter gate;
- no PENDING outcome, so a row is either stored or skipped with its reason;
- a plugin step instead of a called module.

Nothing is shared with the EVF module, so a later change on either side cannot alter the other. The plugin replaces `ResolveFencers` in `Flow.INGEST_PZSZ_SENIOR`. `CommitPzszSenior` keeps writing one `SENIOR` tournament per weapon and gender, with the whole field's N and each fencer's original place (ADR-100, ADR-105).

### 5 · Nobody matched: the event is closed, and that is all (Q2 A)

When no starter matches, nothing is written, no empty tournament is created, and the event is set to `COMPLETED`. The run report lists every skipped starter with the reason, namesakes first.

### 6 · Ingest for CERT, promote for PROD — the same thing — for every organizer (Q1)

`ingest <code>` runs the ingestion on CERT. `promote <code>` runs the **same** ingestion on PROD — the same flow, the same plugins — and applies it only when the result equals the verified CERT run (ADR-108). This holds for every organizer:

- PPW works this way today;
- PZSz does from this ADR on;
- EVF moves onto it in the next plan.

`ingest <code> prod` stays refused for every event. For PZSz, promote's `plan_event` picks the flow from the event's organizer, as `ingest_cli` does; the replay reads the start lists too, and the run record keeps their hash beside the FTL schedule's. With nobody matched, nothing is written, so promote's apply needs no new step.

*Amended 2026-10-07 by [ADR-112](112-pzsz-start-lists-are-stored-inputs.md):* the replay no longer reads pzszerm.pl. It reads the lists the CERT run used from CERT's store, by the run record's hashes, and refuses when one is missing or does not match its hash.

*Amended 2026-10-17 by [ADR-113](113-ingest-and-promote-carry-every-organizer.md):* EVF is on the route, and FIE with it, through `ingest_cli._ingest_international_event_rounds`, which `ingest` and promote's plan both call.

## Alternatives considered

1. **Run PZSz through the PPW flow with a senior category.** Rejected: PPS and MPS are not PPW. The PPW flow decodes age categories from bracket names and creates fencers, and it refused Poznań on a junior namesake.
2. **Keep ADR-100's matcher (exact name or alias, then fuzzy, then review).** Rejected: it never checks the birth year, so it would link the junior of the same name to our Krochmalski Jakub (1976).
3. **Share one admission module between EVF and PZSz, customized by a profile.** Rejected by the user: PZSz is a different, non-veteran organizer. A copy keeps each free to change without touching the other.
4. **Take the birth year from FencingTimeLive.** Impossible: FencingTimeLive results carry none.
5. **Ingest PZSz directly on PROD (`ingest <code> prod`).** Rejected: one route to PROD for every organizer — ingest for CERT, promote for PROD.
6. **Create empty SENIOR tournaments when nobody matched (Q2 B).** Rejected: two empty result lists on the card, for no gain.

## Consequences

**New:**

- `python/pipeline/plugins/pzsz_admission.py`, first committed as a copy of `international_admission.py`, then changed (`AdmitPzszRoster`, `admit`, `start_list_years`);
- `python/scrapers/pzsz_start_list.py`, a pure reader of a PZSz event page and its tournament pages, which refuses the JavaScript check page (`read_event_start_lists` is given the fetch);
- test fixtures with the markup of Poznań's pages and synthetic people, because the repository is public and the real start lists are of young fencers; the event page's tournament table is verbatim.

**Changed:**

- `engine/rulebook.py`: the PZSz flow uses the new plugin in place of `ResolveFencers`;
- `ingest_cli._ingest_event_rounds`, which `ingest` and promote's plan both call, sends a PZSz event to `_ingest_pzsz_event_rounds`. The listing name gives weapon and gender only, never an age category. Every page is read before anything is written. The keep-rule is the domestic one, with one category, `SENIOR`;
- the run record keeps each PZSz listing's start-list hash and the PZSz event it read; promote refuses a changed start list, and reads the CERT run's PZSz event when PROD's row has none (the calendar promotion does not carry `id_pzsz_event`; PPS1s-2026-2027 has none on PROD);
- `CommitPzszSenior` writes nothing when nobody matched, never queues a review row, and sends N with the rows only (`ingest_results`), the one write promote's recorder replays;
- `DbConnector.find_event_by_code` returns `id_pzsz_event`;
- the automation report lists a PZSz field's stored rows and every skipped starter with the start-list birth year, the reason and our namesake, namesakes first.

**Removed:** `ingest_cli.ingest_pzsz_senior_bracket_from_url` (ADR-100), which nothing called and which had no start list.

**Unchanged:**

- the PPW flow;
- the EVF admission and the EVF sync;
- `CommitPzszSenior`'s storage (one `SENIOR` tournament per weapon and gender, the whole field's N, the original place);
- PPS and MPS scoring;
- the bot and `ingest-event.yml`.

**Left in place, unused:** `tbl_pzsz_match_review` and its approve and reject functions, and the `PZSZ_SENIOR` intake of `ResolveFencers`. Nothing writes the review queue any more.

**Risk:** `pzszerm.pl` answers some requests with a JavaScript check: this Mac on 2026-10-06, and GitHub Actions on 30 September and 3–6 October, when the calendar sync read no event. If a start list cannot be read, the run fails and writes nothing; the run never tries to get past the check.

## Open items

Both arose from the LOCAL rehearsal of PPS1s-2026-2027 on 2026-10-06. The user decided both in chat the same day: D1 A and D2 A, as recommended.

1. **D1 · the JavaScript check — decided A.** Send `ingest <code>` again later when Telegram reports the check. Plan an Admin upload of a saved page only if the check holds for a week. *Superseded 2026-10-07 by [ADR-112](112-pzsz-start-lists-are-stored-inputs.md):* a list stored on an open day carries the ingest through a gated day; the saved-page `store` command covers a gate that lasts the whole capture window.
2. **D2 · an end date shorter than the listings — decided A.** The calendar sync sets the end date from pzszerm.pl's listing. The event page shows only a start date, but the listing prints an end date as well, and for Poznań that date is wrong: 3–3 October, while one of its FencingTimeLive listings is dated the 4th. With that end date the event stays `IN_PROGRESS` under ADR-108 §7. The end date is corrected in Admin before the CERT ingest. Since 2026-10-07 the sync no longer sets it back: it leaves the dates of an event that has started as they are ([ADR-087](087-pzsz-senior-calendar-source.md), amendment of 2026-10-07, plan §7 Q6 A).

**Out of scope:**

- EVF on ingest and promote (the next plan);
- an automatic daily close for PZSz and EVF events;
- team results.

*Amended 2026-10-17 by [ADR-113](113-ingest-and-promote-carry-every-organizer.md):* the first two are done. Team results remain out of scope.

## Amendment (2026-10-25) — a confirmed alias, read under our canonical name (K1 A)

In PPS1e-2026-2027 (men's épée, Szczecin) FencingTimeLive printed `KORONA-TRZEBSKI Przemysław` at place 37. The PZSz start list printed our canonical `Korona Przemysław`, 1976, on every stored version. Our fencer has `KORONA-TRZEBSKI Przemysław` as a **user-confirmed** alias, unrevoked, on LOCAL, CERT and PROD. §2 looked the FTL name up on the start list, found nothing, and skipped the row as "not on the start list". The user signed off K1 A on 25 October 2026 (`doc/plans/pzsz-results-url-rca-2026-10-25.html` §08).

**Rule.** When no fencer of ours carries the source row's surname and first name, the name may be **exactly one** fencer's user-confirmed, unrevoked alias (`json_user_confirmed_aliases` minus `json_revoked_aliases`), matched as FIE does (ADR-106): whole words, Polish letters folded, a further given name in the source dropped. Then:

- the start list's birth year is read under **our canonical surname and first name**, and it must equal ours exactly, so §2's protection against a junior namesake holds;
- the row is skipped when another FTL row of the listing prints that canonical name, because the start-list entry would then belong to that row;
- the row is skipped when two of our fencers share the alias, when our canonical name is missing from the start list or printed there twice, or when the years differ. A different year is reported as a namesake, as in §2.

**Once per listing.** A fencer is stored at most once per listing: when two rows resolve to one fencer, by any route, both are skipped and reported with the fencer's id.

**Unchanged.** A fencer of ours who carries the name canonically decides the row as before, and no alias is consulted. A plain matcher alias that nobody confirmed (`json_name_aliases`) never counts (PZSZ.ADM.05, rewritten). The plugin still imports nothing from the EVF admission (PZSZ.ADM.08): the alias reader is a copy. Nothing creates a fencer, writes an alias, changes a birth year or queues a review.

**Effect.** PPS1e-2026-2027 men's épée stores one more row: place 37, our #139, born 1976. Both events were re-ingested on LOCAL under the rule: PPS1e gains only this row, and PPS1f is unchanged (2 rows).

**Tests.** pytest PZSZ.ADM.09–11 (`python/tests/test_pzsz_admission.py`): stored through a confirmed alias; a revoked alias, a wrong year under our name, our name missing from the start list and an alias shared by two fencers are skipped; a canonical namesake is not overridden; our name printed by another FTL row is skipped; two rows resolving to one fencer are both skipped.
