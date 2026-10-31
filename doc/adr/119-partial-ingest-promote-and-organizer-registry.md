# ADR-119: Partial Ingest and Promote — Only Final Brackets, One Organizer Registry, One Engine Contract

**Status:** Proposed (decisions D1–D14 signed by the user in chat on 2026-10-31: D1–D12 "All as recommended", then D13 A and D14 A, on `doc/plans/partial-ingest-promote-results-sync-2026-10-31.html`; the same day R1 A, "R1 A, release it": the end-date clause of §1's 60-minute rule, plan §03b). Built in three releases. Release 1 (§1, §2 and §5) is built test-first; §3 follows in release 2 and §4 in release 3. Accepted on the user's sign-off after release 3 has carried its first event.
**Date:** 2026-10-31
**Amends:** [ADR-108](108-promote-replays-verified-cert-ingestion.md) (§7: what counts as final is the engine's answer, and a bracket from an engine that gives none waits for the sightings rule), [ADR-113](113-ingest-and-promote-carry-every-organizer.md) (§1: the driver is chosen by the registry's route class; §2: a bracket from an engine other than FTL is no longer final once published; §6: the daily close selects by the registry), [ADR-105](105-international-results-keep-source-bracket.md) (§5.2: an event is international by its organizer's route class, and IMEW and IMSW get their true organizer), [ADR-077](077-event-lifecycle-season-skeletons.md) (the 2026-10-03 amendment's "final": the engine's answer, not FTL's row alone), [ADR-106](106-international-intake-by-identity-nationality-per-season.md) (the FIE amendment's types are the registry's FIE-like organizers' types; still MSW and PSW)
**Relates to:** [ADR-117](117-results-links-admin-only.md) (a person sets the results link; §4's sync waits for it), [ADR-118](118-event-details-cert-to-prod-scraper-contract.md) (a new organizer's calendar scraper writes under its contract), [ADR-087](087-pzsz-senior-calendar-source.md) §8 and [ADR-089](089-event-weapons-and-card-header.md) §5 (the calendar card's `panelType` stays a code-prefix heuristic for the tile colour), [ADR-066](066-min-participants-ingestion-gate.md) (the minimum-participant routing is not a registry fact), [ADR-028](028-evf-calendar-results-import.md) (the types EVF's results API scores are not either), [ADR-008](008-psw-msw-international-pool.md) (MSW and PSW are the FIE's; the old "PS" sheet was the EVF Criterium, stored as PEW10), [ADR-046](046-pew-weapon-suffix.md) (the weapon-rename exception asks the registry for the PEW family), [ADR-053](053-evf-parity-gate.md) (the post-commit parity report reaches IMEW and DMEW events), [ADR-019](019-domestic-only-fencer-seed.md) and [ADR-020](020-seed-generator-domestic-auto-create.md) (the seed tools read the registry's domestic types), [ADR-083](083-server-enforced-authorization.md) (the sighting table is deny-by-default), [ADR-111](111-pzsz-results-admitted-by-surname-name-birth-year.md) and [ADR-112](112-pzsz-start-lists-are-stored-inputs.md) (the roster route, unchanged), [ADR-072](072-cdc-recompute-debounce.md) (§3's CERT drain, release 2)
**Source:** `doc/plans/partial-ingest-promote-results-sync-2026-10-31.html`, `python/pipeline/organizers.py`, `python/pipeline/international_sources.py`, `supabase/migrations/20261031000003_listing_sighting.sql`, `doc/handbook/reference/organizers-and-engines.html`

## Context

The user wants a multi-day event ingested several times while it runs: each run takes the tournaments that have finished, and the next run takes the rest. Promote follows each ingest. A failed ingest must not reach PROD, and the end state is a GitHub Actions workflow that ingests and promotes by itself. New organizers are coming: USA Fencing and the French veterans federation were named.

Part of this already worked on 31 Oct 2026. A domestic or PZSz ingest kept only the listings whose FTL schedule row said Finished ([ADR-108](108-promote-replays-verified-cert-ingestion.md) §7). PPS1e-2026-2027 had been ingested and promoted twice: run 7 with one listing final, run 8 with both, and CERT and PROD both hold run 8's fingerprint `fecaf3f0174b`. The plan found nine gaps; release 1 closes four of them, and the audit during the build found four more.

- **G3. A running Engarde final completed its event.** The Engarde reader skips a competition that is not completed (`python/scrapers/engarde.py`), a signal as good as FTL's. The lifecycle treated a listing as not final only when its skip reason was FTL's exact text, so the day after the end date an event with a final still running was COMPLETED. Error 7 of `doc/plans/ingestion-source-errors-findings-2026-10-31.html` shows it.
- **G5. Four engines say nothing.** 4fence, Ophardt, d'Artagnan and EVF's results API were read as final once published. Ophardt transmits live, so a provisional ranking would have reached PROD.
- **G6. Every run had the same title.** Neither `ingest-event.yml` nor `promote.yml` set a run name; the Actions list read "Ingest event (NEW pipeline, from URL)" twenty times.
- **G9. Five places guessed the organizer from the code.** `stages._organizer_for_event`, the twelve-prefix type table, `FIE_TYPES`, the daily close's `ROUTE_CODES` and `_is_international_intake` each matched prefixes. The organizer they guessed disagreed with the stored one for IMEW, IMSW, PSW and DMEW, and an event of a new federation was refused before its first read.
- **G10–G13, found during the build.** The post-commit hooks read IMEW, DMEW, IMSW, PSW and the PZSz families as UNKNOWN, so the EVF parity report skipped IMEW and DMEW events (`commit_lifecycle._organizer_code`). The PEW weapon-rename exception matched any code starting with PEW (`url_validation._is_pew`). Five historical seed tools wrote organizers by hand: MSW and PSW under EVF, PSW under SPWS, IMEW and the PZSz families under SPWS. The domestic fencer scan of [ADR-019](019-domestic-only-fencer-seed.md) looked for a GPW code that no file holds, and missed every 2023/24 Grand Prix.
- **Also found.** The daily close re-read an event of several sources in a different order from the ingest, so its schedule hash could differ (FINAL.07). The matcher's international set lacked PSW.

## Decision

### 1 · A run takes only final brackets, and every engine answers when a bracket is final (D1 A, D2 B, D14 A)

- **Partial in what it reads, whole in what it writes.** A run reads every listing and takes the final ones; the event is written as one replace. The next run holds everything the last one held plus what has finished since. §3 makes that write one transaction on CERT, as it already is on PROD.
- **The engine contract.** `ENGINES` in `python/pipeline/international_sources.py` lists every results engine and whether it says when a bracket is final. FTL does: its schedule row says Finished. Engarde does: the competition's state is completed. 4fence, Ophardt, d'Artagnan, EVF's results API and a single results page do not.
- **Not final is one reason.** A bracket that is not final is skipped with a reason starting "not final": FTL's unchanged text, "not final (Engarde shows it <state>)", or "not final (no finished signal; its content is not yet 60 minutes old)". `lifecycle.is_not_final` reads the prefix, so any such skip keeps the event IN_PROGRESS and the daily close leaves it open.
- **For an engine that says nothing, the reader that asks decides:**

| Who reads | A bracket is final when | Implementation |
| --- | --- | --- |
| The live ingest on CERT | its exact content was first seen at least 60 minutes ago, or today in Warsaw is past the event's end date | `Sightings`, `sightings_for` |
| Promote's plan on PROD | the CERT run took exactly this content of it | `TakenByRun`, from the run's recorded rounds |
| The daily close | it is published (the close runs after the end date) | `SETTLED` |

- **The sightings store.** `tbl_listing_sighting` holds one row per event code, listing key and content hash, with the first and last time it was seen; a new hash is a new row, so a changed bracket starts its hour again. `fn_listing_sighting_record` inserts or touches the row and returns the first time. RLS is on, nothing is granted to `anon` or `authenticated`, `service_role` may select, insert and update, and nothing deletes a sighting (migration `20261031000003_listing_sighting.sql`). Only the live ingest writes sightings, so they live on CERT (and LOCAL); promote's plan never writes one, and the PROD seed export never carries the table (FINAL.08).
- **One hash everywhere.** Ingest, promote's plan and the daily close read an event's sources in the same order and classify them source by source, so its schedule hashes the same in all three. FTL's not-final text is unchanged, because recorded runs hash it (FINAL.06).

### 2 · One organizer registry (D13 A)

`python/pipeline/organizers.py` holds every organizer on the results route, its route class and the code families of its events. No other module matches an event-code prefix.

- **Route classes.** `domestic` (SPWS: every row, the keep-rule and the birth-year split), `roster` (PZSz: a row only when a stored start list confirms it, [ADR-111](111-pzsz-results-admitted-by-surname-name-birth-year.md)) and `international` (EVF, FIE and every federation to come: one tournament per source bracket, our fencers admitted by identity). `fie_like` marks the organizers admitted under [ADR-106](106-international-intake-by-identity-nationality-per-season.md)'s FIE amendment.
- **Families.** A family is the code's first segment, matched whole, with its tournament type and organizer: PPW, MPW (SPWS); PPS, MPS (PZSz); PEW, MEW, IMEW (EVF); MSW, IMSW, PSW (FIE). Two families are registered and never ingested: DMEW, EVF's team championship, and GP, the 2023/24 Grand Prix rounds, which PROD stores under SPWS and the historical seed tools still read.
- **Unregistered.** `VFC-2023-2024` is the one stored code of no family: an event row with no bracket, whose type nothing stored records. The registry names nothing for it, so code that asks gets UNKNOWN. The old spreadsheets' "PS" sheet is unregistered too; [ADR-008](008-psw-msw-international-pool.md) records it as the EVF Criterium, stored as PEW10.
- **Readers.** The organizer, the tournament type, the international check, the FIE flag, the daily close's selection (`route_code_regex`), the matcher's domestic and international sets, the post-commit hooks, the PEW rename exception and the historical tools all ask the registry. `require_route` refuses an event of no family, or of a family not ingested, by name before anything is read or recorded.
- **A new organizer** is one `Organizer`, its `Family` entries, its `tbl_organizer` row, its tournament type with its scoring configuration (an ADR of its own), and its calendar scraper (its own plan, under [ADR-118](118-event-details-cert-to-prod-scraper-contract.md)). A results reader is needed only for an engine not yet in `ENGINES`. The drivers, promote, the daily close and the run record do not change. `doc/handbook/reference/organizers-and-engines.html` carries both registries and the checklist.
- **Not registry facts.** [ADR-066](066-min-participants-ingestion-gate.md)'s minimum routing sends PSW to the domestic minimum while the route calls PSW international; the database holds it per type (pgTAP SS26.TYPE.02) and `scrapers/base.check_min_participants` agrees with it. The types EVF's results API scores (PEW, MEW, MSW) are EVF's calendar, not the route ([ADR-028](028-evf-calendar-results-import.md)). ROUTE.ORG.06 names both as the only sets of their kind outside the registry.
- **The calendar card** keeps `panelType`, a code-prefix heuristic for the tile colour ([ADR-089](089-event-weapons-and-card-header.md) §5). It shows an unknown code in the PPW style, so a new organizer's card colour is decided with that organizer's calendar plan.

### 3 · One apply on both sides (D3 A, D4 A, D10 A; release 2)

An ingest on CERT becomes the plan with the recording connector followed by `fn_promote_event_apply` on CERT, the function promote uses on PROD, so a failed ingest writes nothing. The apply deletes the event's tournaments the plan does not name before the fingerprint check (replace semantics, G1). Promote records its outcome on the CERT run row (`jsonb_promote`): applied, skipped or refused, the reason, the fingerprint, the Actions run and the time. Built in release 2.

### 4 · The results sync (D5–D9 A, D12 A; release 3)

A scheduled `results-sync.yml` runs hourly from 09:13 to 22:13 in Warsaw. It takes each active-season event on the route from its first day to the day after its end date, one at a time, but only an event with a results link on CERT or PROD (or an EVF id): the link is the switch. For each event it reads, compares with the last run, and when something changed it refreshes CERT, ingests, gates and promotes. Telegram gets one line per event only when something changed or failed. A failure pauses the event until a person resumes it with `sync <code>` or a manual ingest. `RESULTS_SYNC=off` stops the schedule. No public log line names a fencer or a birth year. Built in release 3.

### 5 · Every run says what it is (G6)

`ingest-event.yml` runs as "Ingest · <code>" and `promote.yml` as "Promote · <code>", with " · dry run" for a dry run. This follows the rule set for CI and the Release on the same day (NAMING.01–07, `doc/plans/branch-names-and-merge-messages-2026-10-31.html`): a run's title says what it is.

## Alternatives considered

1. **Tournament-level incremental writes (D1 B).** Rejected: a run record and a promote per tournament would double the comparison paths; one atomic replace per event keeps one invariant.
2. **Final once published for engines without a signal (D2 A).** Rejected: Ophardt transmits live, so a provisional ranking would reach PROD for an hour before being replaced.
3. **The 60-minute rule for every engine (D2 C).** Rejected: FTL and Engarde say when a bracket is final, and waiting an hour on them delays every Saturday final for nothing.
4. **The registry as a database table, editable in Admin (D13 B).** Rejected: a new organizer needs a release for its calendar scraper anyway; a module is tested like code, and a table adds schema and a cache for no operational gain.
5. **Leave the prefixes and add each organizer by hand (D13 C).** Rejected: five places disagreed already, and a new federation was refused before its first read.
6. **Keep FTL's flag and Engarde's skip text as two special cases (D14 B).** Rejected: that is how G3 arose, a signal that existed and was ignored.
7. **A type-to-organizer map for the historical tools.** Rejected during the build: a federation added later may reuse an existing type (ROUTE.ORG.04's fixture does), so a type cannot name its organizer. The tools ask the registry with the event code.

## Consequences

- **New files.** `python/pipeline/organizers.py`; `supabase/migrations/20261031000003_listing_sighting.sql`; `doc/handbook/reference/organizers-and-engines.html`.
- **Changed code.** `international_sources.py` (the engine contract, the three finality rules, source-by-source classification); `promotion/lifecycle.py` (`is_not_final`, `not_final_at`, `SEEN_ONCE`); `promotion/close.py`, `run_record.py`, `plan.py`, `replay.py`; `ingest_cli.py` (`require_route` first, the driver by route class, the live sightings); `stages.py`, `db_connector.py` (`record_listing_sighting`), `international_admission.py`, `joined_brackets/__init__.py`, `commit_lifecycle.py`, `url_validation.py`, `review_cli.py`, `scrapers/engarde.py`, `matcher/pipeline.py`; nine tools under `python/tools/` read the registry; both workflows set a run name.
- **Tests.** pytest FINAL.01–04, 04b–04e, 06–08 (`test_results_finality.py`, `test_promotion_replay.py`); ENGINE.01–03; ROUTE.ORG.01–13 (`test_organizer_registry.py`); RUNNAME.01–02 (`test_workflow_run_names.py`); pgTAP `119_listing_sighting.sql` (FINAL.05, the sightings store). Fifteen earlier tests that pinned the old contract were updated (SRC.05–07, SRC.10, CLOSE.01, REPLAY.09).
- **Behaviour.** An Engarde event with a running final stays IN_PROGRESS. A 4fence, Ophardt, d'Artagnan, EVF-API or single-page bracket reaches a live CERT ingest an hour after its content stops changing, or at once after the end date. The EVF parity report reaches IMEW and DMEW events. A historical tool re-run would file MSW, IMSW, PSW and IMEW events under their true organizers and skip a sheet the registry does not know with a warning; closed seasons are never re-ingested, so no stored data changes.
- **Not changed.** `panelType` in the frontend (§2); the PZSz start-list capture; FTL's not-final text.
- **Releases 2 and 3** carry §3 and §4, with their amendments to ADR-108 §4, §6 and §9, ADR-113 §7, ADR-077 §1 and ADR-072.

## Open items

- §3 and §4 are decided and not yet built. Release 2 is next; it is rehearsed on LOCAL before release.
- The calendar card's colour for a new organizer: decided with that organizer's calendar plan, with a before-and-after sheet for the user.
