# ADR-105: International Results Keep the Whole Source Bracket and Their Own Place

**Status:** Draft (proposed 2026-10-01; the rule and its plan were signed off on 2026-10-01 with D1 A, D2 A and D3 A, and D4 A on 2026-10-02; this text awaits sign-off). §§2–5 are implemented, in `supabase/migrations/20261001000002_international_field_size.sql` and the pipeline, and ship as one release (D4 = A).
**Date:** 2026-10-01
**Amends:** [ADR-038](038-evf-intake-polish-only.md) (the POL-only intake gains the rule for N and place, on every path, with the organiser's results as the primary source), [ADR-049](049-joint-pool-split-flag.md) (the 2026-06-04 per-category count and the 2026-06-27 bracket-relative place are domestic only; the 2026-06-27 claim that international results never reach `Commit` is corrected), [ADR-072](072-cdc-recompute-debounce.md) (a recompute keeps an international result in its stored tournament, with its N and place), [ADR-103](103-spws-place-medal-engine-per-type.md) §4 and [ADR-104](104-spws-evf-joined-engine-replaces-place-medal.md) (a third joined-bracket module, selected by tournament type rather than by engine)
**Relates to:** [ADR-056](056-vcat-from-birthyear.md) (the bracket label wins, and a season's category is frozen; §3 writes the stored bracket as the label), [ADR-050](050-unified-ingestion-pipeline.md) (EVF is a backup source, not the primary one), [ADR-022](022-ingestion-db-transaction.md) (the atomic ingest RPC gains the guard), [ADR-100](100-pzsz-senior-result-ingestion.md) (PZSz senior results already keep the full field), [ADR-069](069-participant-count-url-validator.md) (international counts stay outside the URL count check, unchanged), [ADR-066](066-min-participants-ingestion-gate.md) (the EVF minimum-field gate reads the whole bracket, which is what §1 stores), [ADR-008](008-psw-msw-international-pool.md) (PSW is reserved for a future FIE tournament; none has been announced or stored, and the rule covers it in advance), [ADR-083](083-server-enforced-authorization.md) (grants unchanged). The ADR-072 amendment of the same day, on recompute provenance, was found during this work and is recorded there. Checked and clean: [ADR-096](096-no-bracket-stubs-before-results.md).
**Source:** `doc/plans/international-field-size-root-cause-fix-2026-10-01.html`; source-URL sheet `doc/plans/evf-source-urls-2026-10-01.html`
Amended by [ADR-106](106-international-intake-by-identity-nationality-per-season.md) (accepted 2026-10-02): §1.1 and §5.1 — an international row is admitted by identity and an SPWS start, not by its printed country. N and the place are unchanged.

## Context

SPWS writes only its Polish fencers for an international tournament (PEW, MEW, MSW, PSW; ADR-038). The rows a tournament holds are therefore never its bracket. Five code paths counted those rows anyway and stored the Polish head-count as N, and one renumbered the Poles' places among themselves. A Polish fencer who was 31st of 60 became 2nd of 3.

**Measured on 2026-10-01, read-only.** A bracket is counted when its stored N equals its number of Polish results:

| Season | Type | Brackets | LOCAL | CERT | PROD |
| --- | --- | --- | --- | --- | --- |
| 2023/24 | PEW | 77 | 34 | 34 | 34 |
| 2023/24 | MEW | 16 | 16 | 16 | 16 |
| 2024/25 | PEW | 73 | 44 | 44 | 44 |
| 2024/25 | MEW | 16 | 16 | 16 | 16 |
| 2025/26 | PEW | 98 | 55 | 55 | 73 |
| 2025/26 | MSW | 10 | 10 | 10 | 10 |
| | | **290** | **175** | **175** | **193** |

PROD is worse than CERT because its recompute drain kept re-damaging events after fencer edits. MSW Manama 2025, checked against FTL: STAŃCZYK Agnieszka was stored as 2nd of 3 and was 31st of 60; GANSZCZYK Anna 3rd of 3 and 48th of 60; ZIELIŃSKI Dariusz 2nd of 3 and 7th of 76; BAZAK Jacek 1st of 1 and 25th of 47. KUZMICHOVA Svitlana holds a result although she is not a Polish entry on FTL.

**The shared mistake is counting the rows kept instead of the bracket fenced.** For a domestic event the two are the same, because everyone is kept. The paths:

- **RC1 · N recounted from kept rows.**
  - `python/pipeline/review_cli.py:899` sets the draft N to `len(ctx.vcat_groups[vcat])`.
  - `fn_commit_event_draft` sets every joint-pool sibling to `COUNT(tbl_result)`, the ADR-049 2026-06-04 rule.
  - `fn_ingest_tournament_results` falls back to `jsonb_array_length(p_results)` when no count is passed (`supabase/migrations/20260930000003_spws_evf_joined_engine.sql:591`).
  - `PerCategoryRenumber` writes `participant_count=len(kept)` (`python/pipeline/joined_brackets/__init__.py:219`).
  - `python/tools/scrape_tournament.py:386` passes `p_count = len(bucket_rows)`.
- **RC2 · Places renumbered among kept rows.** `PerCategoryRenumber` dense-ranks the kept places, at ingest and in recompute.
- **RC3 · The recompute re-applies RC1 and RC2.** `RECOMPUTE_DOMESTIC` loads every result of an event, with no type filter, and commits it through the EVF classic module. `trg_fencer_change_enqueue` fires it; `recompute-drain.yml` (CERT) and `recompute-drain-prod.yml` drain it. ADR-049's 2026-06-27 amendment says international results "never reach" `Commit`. That was true of ingestion, not of the recompute.
- **RC4 · Foreign rows reach the matcher.** `s6_resolve_identity` (`python/pipeline/stages.py:805`) and `ResolveFencers` (`python/pipeline/plugins/resolve_fencers.py:44`) match every row and exclude only the unmatched ones. Only the deprecated legacy path still drops non-POL rows first (`python/matcher/pipeline.py:204`), as ADR-038 requires.

Every parser records `raw_pool_size` as the whole bracket: the fencers the source places. A fencer listed without a place, DNS (did not start), DNF (did not finish) or DNQ (did not qualify), is not in N. The legacy orchestrator, the PZSz senior commit (`full_n`, ADR-100) and the parsers themselves are correct. Promotion to PROD and `cert_ref` copy whatever is stored.

## Decision

### 1 · The rule

For every international result, on every path:

1. **Only Polish fencers are ingested** (ADR-038). Non-POL rows are dismissed before matching, so no foreign name can be matched to a Polish fencer.
2. **N is the whole source bracket**: every fencer who fenced it, Polish or not.
3. **The place is the fencer's own place in that bracket**, as published. It is never renumbered among the Poles.
4. **Neither is ever recounted afterwards**: not at commit, not in recompute, not on promotion.
5. **The source is the organiser's results** (FTL, Engarde, 4fence, d'Artagnan, Ophardt, FencingWorldwide). EVF results are a secondary source, used only when nothing else exists.

A place above N is corrupt input and is refused, never clamped.

### 2 · A source-field module, selected by type

`python/pipeline/joined_brackets/` gains `SOURCE_FIELD_PLACE` (`SourceFieldPlace`, line 255). It plans every category of a bracket with `participant_count = field.size` and the fencer's own place. At ingest, `field.size` is `BracketField.source(places, parsed.raw_pool_size)`: the size the parser recorded, never less than the highest place listed. At recompute, it is the stored N.

`module_for` (line 290) selects it for every type in `INTERNATIONAL_TYPES` (PEW, MEW, MSW, PSW), whatever engine the type is assigned. A joined engine on an international type is still refused (`JoinedBracketNotAllowed`), and an unknown engine still raises. Domestic selection is unchanged: EVF classic keeps `PER_CATEGORY_RENUMBER`, and the 2026/27 engine keeps `JOINED_BRACKET_CATEGORY_PLACE`.

### 3 · A recompute keeps an international result where it is stored

`RECOMPUTE_DOMESTIC` never moves an international result to the category re-derived from a corrected birth year:

- The stored tournament is the bracket the fencer fenced, and a correction in our roster does not change which bracket that was.
- One tournament holds one source bracket's N. A moved result would carry its place in one bracket under another bracket's N.
- This also follows ADR-056's revision: the bracket label wins, and a season's category is frozen at ingestion.

The recompute therefore:

- groups an international result by its stored category (`StageMatchResult.stored_vcat`);
- writes back the stored N and place (`Commit._plan_source_recompute`). It refuses a tournament whose rows do not share one stored N, and tells the operator to re-ingest;
- writes the stored bracket's category as `enum_source_age_category` (`python/pipeline/plugins/ingest.py:528`). `fn_assert_result_vcat` trusts a bracket label (ADR-056), so a result whose fencer's corrected birth year points elsewhere stays in its bracket. Without the label, the guard rejects the write and halts the drain. No international row carried a label before this; it was found that way on LOCAL, at PEW7es-2024-2025.

### 4 · Two database guards

Migration `20261001000002_international_field_size.sql`:

- **`fn_commit_event_draft`** recounts a joint-pool sibling only when its type is PPW or MPW. International siblings keep the N the draft carried. PZSz PPS/MPS keep theirs too, because their stored veterans are a subset of a senior field.
- **`fn_ingest_tournament_results`** checks two things for PEW, MEW, MSW and PSW, before anything is deleted. It raises when `p_participant_count` is NULL, and when the highest place written is above it. A refused call leaves the stored result untouched. Domestic writes keep the fallback.

### 5 · Every ingestion path files an international bracket whole

1. **Only POL rows reach the matcher.** `s6_resolve_identity` and `ResolveFencers` call `stages._keep_pol_rows`. For an international event, a row whose country does not fold to POL, or has none, is dismissed before anything else looks at it, the V0 check included. It is recorded in `PipelineContext.dismissed_non_pol`. S7's count check adds the dismissed rows to the matches, so a filtered parse still accounts for the whole source bracket.
2. **International is decided by tournament type.** `stages._is_international_intake` tests the event's type against PEW, MEW, MSW and PSW. `_organizer_for_event` reads a code prefix and reports the IMEW and IMSW alternation codes as UNKNOWN. The POL filter, the V0 check and the Stage 0 skip all use the type, so Stage 0 never creates or recalibrates a fencer for an international event. Keyed on the prefix, it had created every participant of MSW Manama, foreign ones included.
3. **The Phase 5 draft writer files one tournament per source bracket** (`review_cli.ReviewSession._build_tournament_draft_rows`). It uses the bracket's own category (`category_hint`), with `N = BracketField.source(places, raw_pool_size).size` and every Pole at their source place, a Pole without a birth year included. A bracket without a single V0–V4 source category is refused: no category is invented from a birth year.
4. **Two source brackets never share one tournament.** `phase5_runner._consolidate_duplicate_codes` refuses to merge duplicate codes for an international event and names both URLs. For a domestic event it merges as before, recounting N to the merged rows (ADR-056 revision).
5. **Team brackets are skipped when an FTL schedule is read** (`scrape_ftl_event_urls._TEAM_RE`, also part of `SKIP_PATTERNS`). They list teams, not individual places. MSW Manama's "Vet Team …" brackets had been parsed as Vet-40 and merged with it.
6. **The new pipeline's event URL path** (`ingest_cli.ingest_event_from_url`) refuses an international event before anything is written or fetched, and names the Phase 5 runner. This holds until the international flow (design §12) exists (D2 = A).
7. **`scrape_tournament`** ingests an international tournament whole (`international_bucket`): no birth-year split, no re-rank, N = the scraped bracket. A results URL shared with a sibling is refused.
8. **A standing check.**
   - pgTAP `INTL.INV.01` checks that no international result has a place above its tournament's N.
   - The Phase 5 staging summary lists each international bracket's source N, highest place, Polish rows, linked rows and dismissed rows.
   - It flags an N equal to the Polish rows, which is the shape of the old damage, and a bracket whose rows all lacked a country.

A parser that records no country (4fence) has every row of an international bracket dismissed. ADR-038 point 4 makes that fail-closed on purpose. Napoli 2026 is repaired by teaching the 4fence parser to read nationality (repair plan R4 = A).

Replayed on LOCAL against MSW Manama 2025, the path drafts 30 Polish results in 14 brackets, exactly the FTL figures, and creates no fencer (`doc/plans/msw-manama-replay-review-2026-10-01.html`).

### 6 · No stored row is repaired here

The damaged brackets are re-ingested from their organisers' results under a separate plan. The plan starts once the source-URL sheet is complete. Each event gets its own staging summary and sign-off, and CERT and PROD each get their own go.

## Alternatives considered

1. **Let a recompute move an international result to the re-derived category, keeping its place and taking the destination's N.** This was the plan's first wording. Rejected: the destination tournament is a different source bracket, so the moved place would be compared with the wrong N (31st of 60 in Vet-50 filed under a Vet-60 bracket of 74). The fencer did not fence there.
2. **Keep the Polish count in N and add a separate "field size" column.** Rejected: N is the field. Every scoring engine, the rolling functions and the public pages read `int_participant_count` as the bracket size. A second column would leave the wrong value where every reader looks.
3. **Exclude international events from `RECOMPUTE_DOMESTIC` altogether.** Safe today, because an international score depends on nothing the trigger watches. Not chosen, for two reasons. One recompute path for every event keeps a later fencer-dependent rule effective on international results. And the label write gives stored international rows the source category ADR-056 expects.
4. **Clamp a place above N to N.** Rejected: such a place means the N or the place is wrong, and a clamped value hides which. The RPC refuses it, so the operator re-ingests from the source.
5. **Keep `PER_CATEGORY_RENUMBER` for international brackets and fix only its count.** Rejected: its dense rank is the defect for international results (RC2). A module whose purpose is to renumber cannot also keep source places.

## Consequences

- **New or changed files.**
  - Source: `python/pipeline/joined_brackets/__init__.py` (the module and its selection) and `python/pipeline/plugins/ingest.py` (ingest field size, recompute grouping, `_plan_source_recompute`, the label write).
  - Types and loading: `python/pipeline/types.py` (`stored_vcat`, `PipelineContext.dismissed_non_pol`) and `python/pipeline/plugins/recompute.py`.
  - Intake: `python/pipeline/stages.py`, `python/pipeline/plugins/resolve_fencers.py`, `python/pipeline/review_cli.py`, `python/pipeline/ingest_cli.py`, `python/tools/phase5_runner.py`, `python/tools/scrape_tournament.py` and `python/tools/scrape_ftl_event_urls.py`.
  - The migration `20261001000002_international_field_size.sql`.
- **Tests.**
  - pytest `python/tests/test_international_field.py`: INTL.MOD.01–06 and INTL.RECOMP.01–04.
  - pgTAP `supabase/tests/86_international_field.sql`: INTL.RPC.01–06.
  - SE27.ING.09 in `test_joined_brackets.py` is amended: under EVF classic an international type now selects `SOURCE_FIELD_PLACE`, not `PER_CATEGORY_RENUMBER`.
  - pytest `python/tests/test_international_intake.py`: INTL.POL.01–06, INTL.DRAFT.01–04, INTL.URL.01, INTL.SCRAPE.01, INTL.SCHED.01, INTL.S0.01 and INTL.INV.02.
  - pgTAP `supabase/tests/88_international_invariant.sql`: INTL.INV.01.
- **Callers that pass no count now fail closed** for international types. `python/scrapers/evf_sync.py` omits the count when EVF gives no total. Its write is then refused and logged, instead of storing the Polish count. EVF is a secondary source (§1.5).
- **The release stops the live damage.** Once it is deployed, a fencer edit no longer changes any international N or place on CERT or PROD. The 193 damaged PROD brackets stay as they are until the repair plan runs.
- **Defects found and deliberately not fixed here:**
  - **Domestic place drift in recompute (D3 = A, planned separately).** Under EVF classic a domestic category stores places renumbered within it. A fencer moved out and back by two birth-year edits returns with a place that ties another fencer (LOCAL, GP3-2023-2024 V4: 325's 4th place became a tie at 3rd).
  - **Foreign names stored in PEW events** (for example PEW9efs-2025-2026). This is RC4 evidence. The re-ingest removes them; §5.1 stops new ones.
  - **ADR-066 lists PSW as a domestic type** in its threshold routing table, while ADR-008 reserves PSW for a future FIE tournament. No PSW tournament exists, so nothing is affected today. The routing is corrected when the first PSW event is announced.
- **Memory correction.** The "two denominators" project memory said both placings were correct. Only the whole-bracket one is a stored fact. The SPWS-category placing of an international result is derived, never stored.

## Amendment (2026-10-02) — the repair path

§6 left the repair to a separate plan: `doc/plans/international-data-repair-batch-1-2026-10-01.html`, extended by `doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html`. Running it on LOCAL needed the following. It is recorded here because each item changes how an international event is ingested from now on, not only during the repair.

- **Replace by exact code.** `fn_rollback_event` resolves a code prefix in the active season only. `fn_rollback_event_by_code` takes the exact code in any season. `fn_replace_event_from_draft` rolls the event back and commits a draft run in one transaction, and refuses a run of another event or one with an unresolved PENDING row (REPAIR.RB.01–09, migrations `20261002000001` and `20261002000002`). `phase5_runner --replace-event` uses it, and sign-off refuses unresolved PENDING rows for every event (REPAIR.RUN.01–02).
- **CERT and PROD receive a repaired event through the runner (decision P A).** `promote.yml` finds events in the active season only, so it cannot carry a past-season event. `phase5-event-runner.yml` stages on its target and, given `commit_run_id`, commits that run through the same replace path (WF.P5.01). Each environment is compared with LOCAL and with EVF before its commit.
- **A tournament's type follows its code.** The draft writer typed every Phase 5 draft tournament PPW, so re-ingested international tournaments were listed as domestic. Drafts are now typed from the event code (5.M2.4–5). A trigger refuses a tournament whose type disagrees with its code family (TT.CODE.01–09, `20261002000003`); DMEW, the team championship, is never scraped for the ranking ([ADR-021](021-imew-biennial-carry-over.md)) and is left unmapped. The cached multiplier follows a retype (TT.MULT.01–04, `20261002000004`).
- **Source identity before a URL is written.** `set_event_source_urls` writes an event's result URLs only when each source's date, name and weapons match the event (REPAIR.URL.01). An Engarde tournament is read through the competition list its page loads (REPAIR.URL.02).
- **Matching an international row.** An automatic link needs the same surname, the same first given name and a confirmed birth year that fits the bracket's category (MATCH.ID.01–08). A source word written without Polish letters matches once folded (MATCH.FOLD.01–06). The alias checker compares the first given name and allows one letter of typo in a surname of up to six letters, two in a longer one (NAME.CLS.01–04). For an international event the stage-time alias flush writes pairs of automatically linked rows only, never a ❌ pair (INTL.ALIAS.01–02).
- **Schedules.** A category-first bracket name is a bracket (INTL.SCHED.02). A joint pool round beside its category brackets is not a result (INTL.SCHED.03), and a bracket listed for two days is read once (INTL.SCHED.04). A bracket whose weapon is not the event's is skipped (INTL.WPN.01). An FTL name's lettered category tag, “(V2)”, is stripped (FTL.NAME.01).
- **Engarde.** An Engarde tournament URL expands through Engarde's competition list into its single-category finals. Pool rounds, team events and competitions without one category are skipped and listed. N counts the placed fencers. The classification header ("Classement général (33 tireurs)") also counts a fencer listed without a place, DNS (did not start), DNF (did not finish) or DNQ (did not qualify); such a fencer is not in N (ENG.EVT.05, the user's rule of 2 October 2026, which withdraws the header count adopted that morning to match EVF's 33 at the Criterium 2026: EVF itself counted the unplaced fencer at the Criterium 2026 and left him out at the Criterium 2025).
- **A page without a nationality (decision C A).** The Engarde parsers find the nationality column by its heading: Country, Nation, Nación and their equivalents. The Budapest Cup 2025 prints “Club” there on three brackets. The parser had read the club as the country, so the POL-only rule dismissed BOBUSIA Jarosław, 5th of 33. A page with no nationality column now leaves the nationality blank (ENG.NAT.01–02), and the staging summary flags the bracket (INTL.INV.02). Which rows of such a page are stored is decided by [ADR-106](106-international-intake-by-identity-nationality-per-season.md) §1: an identity match to a fencer with an SPWS start, whatever is printed. The override file's `nationality` section built for this case on 2 October was removed before release (ADR-106, decision O1 A).
- **4fence.** A 4fence event URL expands into one bracket per weapon, gender and category, each read from its final classification and its last-four tableau (FOURFENCE.EVT.01). The place is the column CLASS, the final classification, never “Cla Gir”, the pool ranking, which the parser had read (FOURFENCE.PLACE.01). The country is the federation a fencer enters under: “EE” plus the IOC code in the club column (EEPOL), an Italian club being Italy (FOURFENCE.NAT.01). 4fence prints the second bronze medallist without a place and skips place 4: the tableau names both semi-final losers, and the one without a place is 3rd and in N (FOURFENCE.BRONZE.01). Any other fencer without a place left during the direct elimination; he is not in N, and the places the page numbers below him close up, a place being 1 plus the number of placed fencers ahead (FOURFENCE.CLOSE.01; decisions B A and W A of 2 October 2026). Without the tableau the bronze still counts in N, unnamed (FOURFENCE.NOTAB.01).
- **EVF events follow EVF's category rule.** The EVF minimum is 1 ([ADR-066](066-min-participants-ingestion-gate.md) amendment of the same day). `compare_evf_points` checks every committed Polish result of an EVF event against EVF's N and points (EVF.PTS.01). On LOCAL, every repaired EVF event matches.
- **A missing event.** EVF scored the Criterium Mondial Vétérans 2026 (Paris, 4–6 July 2026) and no environment had an event for it. It is added as `PEW10efs-2025-2026` on every environment. `evf_event_completeness` lists the EVF events of a season with results at EVF and no event row (EVF.CAL.01): for 2024/25 and 2025/26 these were this one and EVF Circuit Chania 2025, whose only Polish result belongs to a fencer who is not a member and which is left out.
