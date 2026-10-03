# ADR-108: Promote Replays a Verified CERT Ingestion on PROD; CERT Starts From PROD's Master Data With Identical Fencer Ids

**Status:** Accepted (2026-10-03; signed off with the plan, and decision P6 taken the same day)
**Date:** 2026-10-03
**Supersedes:** [ADR-026](026-cert-prod-promotion.md) — the per-event mode (`promote.py --mode event`): the row copy, the per-tournament "continue on failure", the forced `COMPLETED` and the seed export inside the promote job. The calendar mode (amendment 2026-04-20) is untouched.
**Amends:** [ADR-025](025-event-centric-ingestion-telegram.md) (N15: `ingest … prod` is refused for a domestic event; `promote` and `complete` take an exact event code), [ADR-036](036-prod-export-local-mirror.md) (the seed carries PROD's fencer ids; CERT's master data is refreshed from PROD), [ADR-042](042-carryover-engine-dispatcher.md) and [ADR-018](018-rolling-score.md) (the FK engine stops a carry on results, per weapon and gender), [ADR-072](072-cdc-recompute-debounce.md) (the CERT drain joins the new `cert-write` group), [ADR-077](077-event-lifecycle-season-skeletons.md) (§1: who sets IN_PROGRESS and COMPLETED, and when; §5: results are replayed, not copied, and fencer ids are identical)
**Relates to:** [ADR-037](037-derived-display-status-awaiting-results.md) (a new edition replaces the carry only once it has data), [ADR-047](047-vcat-invariant-trigger-and-splitter-consolidation.md) (the V-category trigger the renumbering keeps satisfied), [ADR-055](055-ingest-traceability.md) (ingest history, which the run record does not replace), [ADR-056](056-vcat-from-birthyear.md) and [ADR-093](093-registration-as-birth-year-source.md) (the identity rules the gate enforces), [ADR-074](074-no-halt-fault-resolution.md) and [ADR-075](075-staging-report-fragment-channel.md) (CERT still commits automatically, and the staging report stays informational), [ADR-083](083-server-enforced-authorization.md) (grants for the new table and functions), [ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md) (field tiers: `url_event` is fill-blank), [ADR-097](097-scoring-governance-lock-and-privileged-revision.md) (the season lock rolls back with a failed apply), [ADR-104](104-spws-evf-joined-engine-replaces-place-medal.md) (joined-bracket order is replayed and checked), [ADR-105](105-international-results-keep-source-bracket.md) (international events keep the Phase 5 runner on each environment)
**Source:** `doc/plans/promote-verified-replay-2026-10-03.html`

## Context

PPW1 2026/27 was the first domestic event of the season to reach the promote step, and promote could not carry it safely. `python/pipeline/promote.py` copies CERT's rows to PROD, and it has five defects:

1. **It sends CERT's fencer ids.** `read_cert_event` (line 71) selects `r.id_fencer` (line 123), and `write_prod_results` passes it to PROD's `fn_ingest_tournament_results`. On 3 October 2026, **344 of the 367 fencers had different ids on CERT and PROD**; only 19 matched. The same fencer is 37 on CERT and 38 on PROD.
2. **It creates no fencers.** A fencer the CERT ingestion created does not exist on PROD.
3. **It drops the joined-bracket order.** It never passes `p_joined_order`, which ADR-104 §3 needs.
4. **It continues after a failure.** A failing tournament is appended to `errors` (line 287) and the loop carries on. Nothing is rolled back.
5. **It always sets COMPLETED** (lines 289–303), whether or not the fencing is over. It finds the event with `LIKE '<prefix>%'` in the active season only (line 91).

Three further facts shaped the decision:

- **Birth years are corrected on PROD.** Registrations on PROD declare birth years (ADR-093), so after any registration period CERT's roster is stale. On 3 October, 10 birth years differed between CERT and PROD, all on unique names and each by four years or less.
- **LOCAL numbers fencers its own way.** The seed export drops `id_fencer` (`python/pipeline/export_seed.py` lines 29 and 82) and points each result at its fencer through a name and birth-year lookup (`fencer_lookup`, line 161). LOCAL held 373 fencers with ids up to 971.
- **Nothing serialises CERT's writers.** `ingest-event.yml` belongs to no concurrency group and accepts `target: prod`, so a direct PROD ingest can overlap the PROD drain and a promote, both of which are in `prod-write`.

Build step 1 of the plan (3 October) added four findings:

- **FTL marks each listing as finished.** The organiser's schedule shows a green check and "Finished at …" per listing; the results data JSON carries no status.
- **The renumbering cannot be a plain update.** All six foreign keys to `tbl_fencer` are `ON UPDATE NO ACTION` and not deferrable. Two of them (`tbl_fencer_nationality`, `tbl_registration_identity_override`) cascade on delete. `tbl_result_draft.id_fencer` has no foreign key, and `tbl_audit_log` holds fencer ids in `id_row` and in JSON (on CERT: 1,408 fencer rows and 40,526 result rows).
- **The FK carry-over engine counts two editions at once.** Season 2026/27 runs `EVENT_FK_MATCHING` on all three environments. `vw_eligible_event` counts the new edition from IN_PROGRESS on, and keeps carrying the previous edition until the new one is SCORED or COMPLETED. So while an event is IN_PROGRESS, a fencer who fenced both editions has both results counted. Today's promote jumps straight to COMPLETED, which hid this on PROD. On PROD, 13 of the 14 dated 2026/27 events start inside their previous edition's 366-day window. ADR-018's amendment of 2026-06-26 had already moved the older engine to a results-based stop, "regardless of lifecycle status", and recorded the FK engine as "a known boundary divergence if ever activated".
- **No automated test reads CERT data.** Playwright runs against a LOCAL build; the Release CERT job checks schema and security only. CERT's only data of its own is 8 test registrations on PPW1-2026-2027.

## Decision

### 1 · Promote copies nothing

Promote checks two things: that CERT and PROD started from the same inputs, and that CERT's committed result holds no open issue. It then **runs the same ingestion on PROD** and writes the result **in one transaction that rolls itself back** if the result differs from CERT's. A domestic event's results reach PROD only this way.

The sequence for every domestic event is:

| Step | Where | What |
|---|---|---|
| 0 · Refresh | PROD → CERT | Master data and the event's registrations; identical fencer ids (§2, §3) |
| 1 · Ingest | CERT | `ingest-event.yml` target `cert`, plus a run record (§4) |
| 2 · Gate | CERT | Blocking issues and preconditions (§5) |
| 3 · Promote | PROD | Plan, compare, apply in one transaction (§6) |
| 4 · Lifecycle | CERT and PROD | IN_PROGRESS or COMPLETED by one rule (§7) |

### 2 · Every CERT ingestion starts with a master-data refresh from PROD

The refresh reads PROD over a read-only connection (`default_transaction_read_only`) and writes CERT only. It covers the **whole roster**: surname, first name, birth year and its estimated flag, gender, nationality and aliases.

For the event being ingested, PROD's registrations replace CERT's. Copied: surname, first name, gender, declared birth year, weapons, FTL name, club and `id_fencer`. **Not copied:** e-mail hash, edit token and consent stamp, which the ingestion does not read (data minimisation). CERT's copy follows PROD's retention, and any future registration purge runs only after the event is COMPLETED on PROD.

CERT's recompute queue then drains to empty, and only then may the CERT ingestion start.

The refresh also compares, without copying:

- the schema fingerprints;
- the season's scoring settings, engines and lock state;
- the event row as the ingestion reads it;
- the commit of the override file.

Any difference refuses. An **input fingerprint**, a hash of these inputs normalised by identity and never by id, is recorded for both environments.

Every refresh first runs dry and lists every change. The first refresh, and any later refresh that renumbers a fencer, waits for the administrator's sign-off.

### 3 · Fencer ids are identical on LOCAL, CERT and PROD

The administrator's rule: **the fencer id is the same everywhere, and nothing is guessed.**

**Matching**, per folded surname and first name:

| Case | Result |
|---|---|
| One fencer of that name on each side | The same person; PROD's values win |
| Namesakes on either side | Paired only by an equal confirmed birth year |
| Only on PROD | Created on CERT with PROD's id |
| Only on CERT | Deleted when nothing refers to it |
| Anything left unpaired | The refresh stops before writing and lists it; the administrator decides in `doc/overrides/fencer-alignment.yaml` |

**Renumbering** is done by `fn_align_fencers_to(pairs, prod_roster)` in one transaction, in two phases, with plain statements and no trigger switched off:

1. Each moving fencer is copied to a temporary negative id, without aliases, because the alias-uniqueness trigger would refuse a second holder.
2. Every reference moves to the copy: the six foreign keys found from the catalogue, plus the listed soft references (`tbl_result_draft.id_fencer`; `tbl_audit_log.id_row` of fencer rows and `id_fencer` in result rows' values).
3. The old row is deleted. References always move first, because two of them cascade on delete.
4. The same steps repeat from the temporary id to PROD's id.

During the move each row keeps CERT's own birth year, so the V-category trigger (ADR-047) is satisfied as before. The function checks that trigger's condition before writing and lists any result that would fail it: on 3 October none on CERT or PROD, and 3 on LOCAL.

After the move, PROD's values are copied onto each pair with ordinary updates, so a moved birth year queues recomputes through `trg_fencer_change_enqueue`, exactly as a correction on PROD does. The id sequence is set to PROD's.

**Before commit,** CERT's roster (id, names, birth year, confirmed flag, gender) must equal PROD's exactly, and each person must hold the same number of results as before. Any difference raises. One audit row records the whole old-to-new map.

A test fails when a column whose name contains `fencer` appears that is on neither the foreign-key list nor the soft-reference list.

**New fencers.** CERT stays the sole allocator of new ids (ADR-077 §5). A fencer the CERT ingestion creates keeps that id on PROD, and the promote apply refuses if the id is taken there.

**LOCAL.** The seed export keeps PROD's `id_fencer` and writes every reference with the id itself. The seed load renumbers the fencers that data migrations created during a fresh bootstrap, using the same `fn_align_fencers_to`, and then sets the sequence. `scripts/mirror-prod-local.sh` and the CI bootstrap compare LOCAL's roster with PROD's, id for id, and fail on any difference.

### 4 · The CERT run record

`ingest-event.yml` with target `cert` writes a row to a new `tbl_ingest_run` (service role only, ADR-083). The row holds:

- the event code, the environment and the git commit that ran;
- the schema fingerprint and the input fingerprint;
- a hash of each source listing as parsed;
- the result fingerprint from `fn_event_result_fingerprint`;
- the master-data changes (fencers created, birth years moved, aliases added);
- the gate outcome.

The fingerprint is computed by one canonical SQL function and never by Python, so formatting cannot differ between the two sides.

**Implemented 2026-10-03 (build step 6).** Migration `20261003000014_ingest_run.sql`; `python/pipeline/promotion/run_record.py`; `ingest_cli --record-run`, which `ingest-event.yml` passes for target `cert`.

- `fn_ingest_run_open` writes the row before the ingestion writes anything. It holds the input fingerprint and the roster as the run found it (`fn_roster_snapshot`), plus the event URL the run ingests and the season end year. A run of the same event and environment still `RUNNING` becomes `ABANDONED`.
- `fn_ingest_run_finish` closes the row `FINISHED` with its listings. `fn_ingest_run_fail` closes it `FAILED` with the error. Both record the master-data changes since the row opened.
- `fn_event_input_fingerprint` returns one hash, plus one part per input:
  - `schema`: `fn_schema_fingerprint`, the query of `scripts/schema-fingerprint.sh`;
  - `roster`: every column the refresh copies, by person, never by id;
  - `registrations`: the columns the refresh copies, with the fencer link as that fencer's name and birth year;
  - `season`: dates, engines by code, and the scoring and per-type settings. The EVF toggles and the default ranking mode are display switches, not scoring settings.
  - `lock`;
  - `event`: code, dates, season, previous edition, and the admin's skip/process choices. Not the URL, which promote writes.
- `fn_roster_changes` lists the fencers created (with the id each got), the fencers deleted, the birth years moved, the aliases added, and any other column that changed.
- The listing hashes are the one part computed in Python, because the listings are parsed there (`listing_sha256`, `schedule_sha256`). Promote recomputes them with the same functions.
- `txt_result_fingerprint` and `jsonb_gate` stay empty until build steps 9 and 7.

### 5 · The CERT gate

Three kinds of issue block promote. Each one is fixed at its source, CERT is re-ingested, and the gate runs again; there is no acknowledge step.

| Kind | Blocking checks |
|---|---|
| **Identity** | A listing refused for namesakes the birth year does not decide, or for a two-category gap; any PENDING row; a 2026/27 domestic participant whose birth year is still an estimate; a declared year that contradicts the bracket fenced (`declared_vs_bracket`); a confirmed year moved by the bracket alone; a new fencer the alias checker's typo rule (NAME.CLS) would call an existing one |
| **Scoring** | A result without a score or its components; not exactly one active scoring revision, or a 2026/27 result not stamped with it; a stored score the engine's preview does not reproduce (the SS26.PARITY contract, for every result of the event); a tournament whose type does not match its code (TT.CODE.06) |
| **Joined bracket** | A listing refused for a repeated place or a place without a category; N or a place different from the source; siblings of one joined listing that disagree on N or on the category order; an order whose length is not N, or whose digit does not match the stored fencer's category |

**Preconditions** are always required:

- the run finished and every kept listing committed;
- CERT's queue drained for every event the run touched;
- PROD's input fingerprint still equals the one recorded. Every part is compared except the season lock, which refuses only when PROD is locked and CERT was not: the season's first scored result locks it, so CERT locked with PROD unlocked is the expected state for a season's first event (G1 A, 2026-10-03);
- the schemas are equal;
- every fencer the run created has an id that is still free on PROD.

**Information only:** a loose name similarity; a one-category move that follows a declaration; and the ADR-104 §7 joining check, because the results are correct as fenced.

ADR-074 is unchanged: CERT commits automatically. The gate blocks only the PROD write.

**Implemented 2026-10-03 (build step 7).** `python/pipeline/promotion/gate.py` (`evaluate`, `run_gate`, a CLI); migration `20261003000016_promote_gate.sql`.

- `fn_promote_gate_checks(event, fencer ids)` reads the target's committed state:
  - estimated birth years;
  - PENDING match candidates;
  - results without a score or a component;
  - the active revision and its stamp;
  - the SS26.PARITY preview for every scored result;
  - TT.CODE.06;
  - sibling N and order, and order digits;
  - the queue for the event and for every event where a fencer the run touched has a result;
  - the birth years each named fencer's results allow (`fn_fencer_fitting_birth_years`);
  - the joining check;
  - the stored tournaments.
- An order whose length is not N cannot be stored (`chk_tournament_joined_order`), so the gate does not look for one.
- The run record carries what the gate reads from the run. Each listing keeps its source rows and its identity report: fencers created with their nearest existing name, reconciled years with their anchor, conflicts, and PENDING rows. A refused listing ends the run with a `ListingRefused` naming its kind, `identity` or `joined_bracket`. It is still a `ValueError`.
- The gate reads PROD through a read-only transport only. It writes nothing but its outcome, on the run row (`fn_ingest_run_gate`).
- **The duplicate check applies the birth year.** A new fencer the typo rule calls an existing one blocks unless two different confirmed birth years tell them apart, which is then information. On PPW1, PERKOWSKI Maciej (declared 1984) and SĘKOWSKI Maciej (#263, 1981) are such a pair.
- **G2 A (decided 2026-10-03).** A declaration that overwrites a confirmed year stands only when the fencer's results allow no other year (`fn_fencer_fitting_birth_years`), which is information. Any other such overwrite blocks as an identity issue, and the year is decided by name on PROD. There is no second rule to switch to.
- On LOCAL, after a refresh from PROD and a recorded PPW1 run, the gate against PROD found no identity, scoring or joined-bracket issue. The only findings were the schema and registrations parts, both waiting on PROD's deploy of the same migrations.

### 6 · Promote on PROD

1. **Trigger.** `promote <exact code>` from Telegram, or `gh workflow run promote.yml -f event_code=…`, dispatches `promote.yml` in `prod-write`. The event is found by its exact code; a prefix is answered with the matching exact codes.
2. **Exact code.** The job checks out the commit the CERT run recorded, not `main`.
3. **Re-check.** Every gate check and precondition runs again. PROD's event must be one of:
   - PLANNED;
   - IN_PROGRESS holding exactly the previous promoted run (day 2 of a multi-day event);
   - COMPLETED, for a CERT run newer than the last promote (a correction).
4. **Source unchanged.** Each listing is fetched and hashed; a hash different from the CERT run's refuses before anything is written.
5. **Plan.** The `INGEST_DOMESTIC` flow runs against PROD with a recording connector. It reads PROD and records every write; reads of its own writes are answered from the record.
6. **Compare.** With identical ids, the plan must equal CERT's result fingerprint and master-data changes, id for id. A difference refuses with a diff table, and nothing has been written.
7. **Dry apply.** `fn_promote_event_apply(plan, expected_fingerprint, p_dry_run => true)` makes every write, scores, computes PROD's fingerprint and always raises at the end.
8. **Apply.** The same function with `p_dry_run => false` runs in one transaction. It locks the participants' fencer rows and the event row, and recomputes the input fingerprint inside the transaction. Any difference from CERT raises, and PostgreSQL undoes everything: new fencers, birth years, aliases, results, scores, the season's first scoring revision and its lock (ADR-097, with no privileged unlock), and the queued recomputes.
9. **URL.** Inside the apply, PROD's `url_event` takes CERT's value when it is blank and is left alone when equal. A different non-blank value refuses, following ADR-086's fill-blank tier.
10. **Status.** The status follows §7, inside the same transaction.
11. **After commit.** The joining check runs and the report goes to Storage and Telegram, labelled PROD. Promote waits for the PROD drain and compares the affected events with CERT. A difference here cannot be rolled back, so it is reported loudly.
12. **Idempotent.** When PROD already equals CERT's fingerprint, the apply is skipped and only the remaining steps run.
13. **Seed export** is its own job after promote, with a rebase and retry. Its failure alerts but does not mark the promote failed.

The apply runs over a direct database connection with its own `statement_timeout`, not through the Management API.

**Plan mode implemented 2026-10-03 (build step 8).** `python/pipeline/promotion/plan.py`:

- The `RecordingConnector` gives the domestic driver (`_ingest_event_rounds`, INGEST_DOMESTIC per listing) the connector's surface. Reads go to PROD; every write is recorded as an operation: `insert_fencer`, `update_fencer_birth_year`, `find_or_create_tournament`, `ingest_results`, `set_event_url_event`, `set_event_ingest_sources`.
- A read of the run's own writes is answered from the record: the roster with created fencers and moved birth years, the batch reads, the event's URL and sources. A tournament PROD has keeps its id; a new one gets a negative placeholder the apply replaces.
- A new fencer takes the CERT run's id for the same surname and first name. `PlanRefused` stops the plan, with nothing written, for a fencer the CERT run did not create, a CERT id PROD already uses, a different non-blank PROD URL (ADR-086's fill-blank tier), an international event, or a write a domestic ingestion never makes (merge, clear, participant count, joining check).
- `plan_event` runs the driver with `post_run=False`: the staging report, the joining check and Telegram run after the apply. The plan carries every listing's hash (`ListingLog`) for the source check.
- `apply_plan` is the reference apply through the ordinary connector. It is not atomic and runs in tests and on LOCAL only; `fn_promote_event_apply` (build step 9) applies the same operations in one transaction.
- Acceptance, 2026-10-03, on LOCAL refreshed from PROD (`promotion/plan_check.py`, one event per reset): **PPW1 2026/27 planned and applied equals its live run** (25 tournaments, 102 results, 373 fencers, the 6 new fencers with identical ids, one birth-year move). Past scored events of a closed season are never re-ingested, so they are not acceptance input: in the next season the year categories are computed from has shifted (the season's later year), and an ingestion run in the active season on a previous season's event would have to be aware of that change.

**Apply implemented 2026-10-03 (build step 9).** Migration `20261003000017_promote_apply.sql`:

- `fn_event_result_document(event)` is what an ingestion left for an event: the event's URL, every tournament, every result with its score, and the participants' roster rows, by codes and fencer ids, without generated ids or timestamps. `fn_event_result_fingerprint(event)` is its SHA-256. `fn_ingest_run_close` records it on a FINISHED run.
- `fn_promote_event_apply(event, plan, expected fingerprint, expected inputs, prior fingerprint, status, dry run)`:
  - skips the writes when PROD already holds the expected fingerprint;
  - otherwise requires PROD to hold no result for the event (no prior named) or exactly the prior fingerprint;
  - locks the event row and the participants' rows, then compares the input parts with the CERT run's (the lock refuses only when PROD is locked and CERT was not);
  - steps a COMPLETED event to IN_PROGRESS, applies the operations in order (a CERT id PROD uses, a tournament that moved, a different non-blank URL or an unknown operation refuses), and compares the result fingerprint;
  - sets the requested status, IN_PROGRESS or COMPLETED, through the transition validator, never writing an unchanged status;
  - on a dry run raises `PROMOTE_DRY_RUN_OK <fingerprint>`; after a real apply with new fencers moves the fencer sequence past their ids.
- Every refusal is an exception, so nothing the apply wrote survives it. pgTAP APPLY.01–11 (`103_promote_apply.sql`).
- Acceptance, 2026-10-03, on LOCAL refreshed from PROD (`plan_check plan --apply sql`): **PPW1 2026/27 planned, dry-run and applied through `fn_promote_event_apply` equals its live run**, fingerprint for fingerprint and row for row (58 writes; 25 tournaments, 102 results, 373 fencers).

### 7 · Event lifecycle: COMPLETED once everything is final and the end date has passed

| State of the event | Status on CERT and PROD |
|---|---|
| Some scheduled individual listings final and committed, others not | IN_PROGRESS |
| Every listing final and committed, but the end date has not passed (the last day included) | IN_PROGRESS |
| Every listing final and committed, and today in Warsaw is later than the end date | COMPLETED |
| Promote refused or rolled back | unchanged |

- **What counts as final.** A listing is final only when its schedule row says Finished. Pools-only rounds and team rounds are excluded. A listing that is not final is skipped, listed, and keeps the event IN_PROGRESS.
- **Why the end date matters.** Organisers sometimes add a tournament the next day, so every listing being in does not prove the fencing is over.
- **Who sets the status.** The same rule runs on CERT and PROD. SCORED is never set by automation.
- **The daily close.** `event-close.yml` runs in `prod-write`. For each domestic event still IN_PROGRESS whose end date has passed, it re-reads the schedule:
  - If everything is committed on both environments and nothing new was published, it sets COMPLETED on CERT and then on PROD.
  - If not, it changes nothing and sends a Telegram message.
  - It is idempotent, and a failure alerts.
- **The manual close.** The Telegram `complete` command stays as a manual close, takes an exact code, and does not check the end date.

**Implemented 2026-10-03 (build step 11).**

- **Finished.** `parse_event_schedule` gives every listing `finished` (its schedule row says Finished; a listing shown on two days needs both rows) and `day` (the date heading above it). The domestic ingestion moves a listing that is not final to the schedule's skips, with the reason "not final"; the run record, promote's source check and the admin accordion all show it, and the run record keeps the latest listing day.
- **The rule.** `python/pipeline/promotion/lifecycle.py`: COMPLETED when every listing is final and read, none is dated after the end date, and today in Warsaw is later than the end date; otherwise IN_PROGRESS. A run that committed nothing leaves the status alone (ADR-037). Writes go through the validator's pairs: PLANNED steps through IN_PROGRESS, and an unchanged status is not written.
- **Who applies it.** Every domestic ingestion through `ingest_event_from_url` (CERT and LOCAL) ends by applying it. `plan_event` carries it as the plan's status, which promote passes to `fn_promote_event_apply` and `apply_plan` sets.
- **The daily close.** `python/pipeline/promotion/close.py`, run by `.github/workflows/event-close.yml` at 04:00 UTC in `prod-write`: each domestic event of the active season IN_PROGRESS on CERT or PROD with its end date passed is completed on CERT and then PROD when every listing is final and none is dated after the end date, the schedule hashes as the latest finished CERT run read it, that run read every listing, and both environments hold its result fingerprint. Otherwise it writes nothing and sends one Telegram message per event saying what to do. An environment already COMPLETED is not written again; a failure raises and the workflow alerts. A manual run is a dry run unless unticked.
- **The manual close.** `fn_complete_event` takes an exact code and refuses a prefix or an unknown code, listing the active season's codes that start with it (migration `20261003000019`; the parameter keeps the name `p_prefix` for the deployed GAS).
- **The calendar card** shows results links for an IN_PROGRESS event as well as a COMPLETED one.
- **Tests.** pytest `test_promotion_lifecycle.py` (PROMO.LIFE.01–17); pgTAP `105_complete_event_exact_code.sql` (COMPLETE.01–06); Vitest EC.65.

### 8 · A carry stops on results, per weapon and gender (decision P6 A)

The `EVENT_FK_MATCHING` ranking functions stop carrying the previous edition for a weapon and gender as soon as the linked current edition has a scored result for that weapon and gender and itself counts (any status `vw_eligible_event` counts: IN_PROGRESS, SCORED or COMPLETED). A COMPLETED or SCORED current edition stops every carry from its previous edition, as today. The stop applies to every linked event, whatever its type (decided 3 October 2026): the link means the new edition replaces the old one ([ADR-018](018-rolling-score.md) §3, §7). Implemented in `supabase/migrations/20261003000018_carry_stop_results.sql`; tests `supabase/tests/104_carry_stop_results.sql`, CARRY.RS.01–11.

This is the rule ADR-018 set for the older engine on 2026-06-26, and it closes the divergence that ADR-018 recorded. There is no double count while an event is IN_PROGRESS, and no empty slot for a weapon fenced on a later day. The view alone cannot see weapons, so the change covers the four FK functions, which read the view together.

### 9 · Who may write, and when

- **`cert-write`:** the refresh, the CERT ingest and the CERT recompute drain. The drain leaves `cert-recompute`.
- **`prod-write`:** promote, the PROD drain, the daily close and the existing calendar and season promotions.
- **`ingest-event.yml`** refuses `target: prod` for a domestic event. International events keep the Phase 5 runner on each environment (ADR-105), and promote refuses them by name.

## Alternatives considered

1. **Keep copying rows and translate ids by name at promote time.** Rejected. CERT's identity decisions would still be copied without being re-derived on PROD, master-data drift between the environments would land silently, and nothing would prove that PROD's inputs equal CERT's.
2. **A live ingestion on PROD with a write journal and an undo step (plan option P3 B).** Rejected. PROD would show a partial event while the job runs, and undoing the season lock would need the privileged unlock that ADR-097 forbids.
3. **Stage into the draft tables and commit in one transaction (P3 C).** Rejected. That covers results only; new fencers and birth years would still be written live, before any comparison.
4. **Match CERT to PROD at each refresh but leave the ids different.** Rejected by the administrator's rule. Every consumer of an id would need a translation, and LOCAL tests would keep running against a differently numbered roster.
5. **Make the foreign keys `ON UPDATE CASCADE` and renumber with plain updates.** Rejected. It changes PROD's schema to serve CERT's maintenance, and an accidental id update on PROD would then cascade silently instead of failing. The copy-and-move renumbering needs no schema change.
6. **Refresh only the event's participants.** Rejected. Admin edits and merges made on PROD elsewhere in the roster would be missed. The whole roster is about 370 rows.
7. **COMPLETED as soon as every listing is in.** Rejected, because organisers add tournaments the next day (§7).
8. **Stop the carry at event level (P6 B), or set SCORED while partial (P6 C).** Rejected. Both leave an empty slot overnight for a weapon fenced on a later day, and C would have automation set SCORED.

## Open items

1. **Decided 2026-10-03 (G1 A), recorded in §5.** How §5 compares the season lock. The season's first scored result locks it (`fn_ensure_active_scoring_revision`). So the ingestion of a season's first event changes the lock on CERT, and any later CERT re-run of that event starts locked while PROD is not. On 3 October 2026 the 2026/27 season was locked on CERT and unlocked on PROD. Compared literally, "lock state equal" refuses every re-ingested first event of a season. The run record therefore keeps the lock as a part of its own. **Recommendation:** compare the scoring settings and engines value by value, and refuse on the lock only when PROD is locked and CERT is not. That case means PROD scored results CERT never had.

2. **Decided 2026-10-03 (G2 A), recorded in §5.** A declaration against a confirmed birth year. D5 moves a confirmed year to a declared one whenever the declaration fits the bracket. **A (chosen):** that overwrite stands only when the fencer's results allow no other year; any other case blocks promote as an identity issue, and the year is decided by name. B, not chosen: the declaration wins and the gate reports it.

## Consequences

**New code:**

- `python/pipeline/promotion/` with `identity.py`, `refresh.py`, `gate.py`, `lifecycle.py` and the recording connector;
- migrations for `fn_align_fencers_to`, `tbl_ingest_run`, `fn_event_result_fingerprint`, `fn_promote_event_apply` and the results-based carry stop;
- `.github/workflows/event-close.yml` and the `cert-write` group.

**Rewritten:**

- `promote.py --mode event`;
- `promote.yml`, which takes an exact code and moves the seed export to its own job;
- `ingest-event.yml`, which refuses a domestic PROD target;
- `export_seed.py`, which keeps fencer ids;
- the GAS `promote` and `complete` commands and `/help`.

**Behaviour change on the calendar.** `EventCard.svelte:330` shows result links only for COMPLETED. Because promote no longer sets COMPLETED at once, the card also shows them for IN_PROGRESS when a results URL exists. This keeps today's visible behaviour on the evening of an event.

**Tests, written RED first:**

- `PROMO.ID.*`, `PROMO.REFRESH.*`, `PROMO.SEED.*`, `PROMO.RUN.*`, `PROMO.GATE.*`, `PROMO.PLAN.*` (including "plan, then apply, equals a live run" on PPW1 2026/27 on LOCAL; past scored events of a closed season are never re-ingested), `PROMO.APPLY.*` (atomicity, lock and queue rollback, dry run persists nothing, URL rule, status pairs, idempotence) and `PROMO.LIFE.*`;
- pgTAP for the renumbering and for the carry stop, whose first test reproduces the double count. The existing `94_carryover_without_successor.sql` (CARRY.NS.01–07) must stay green.

**Operations:**

- The first CERT alignment renumbers about 344 fencers. It is rehearsed on LOCAL, preceded by a backup artifact with a tested restore, run dry, and applied only after sign-off.
- After it, a full CERT-against-PROD results comparison by id, across all seasons, resolves every difference before the first promote.
- The end-to-end rehearsal is `promote --prod-target local`.

**PPW1 2026/27** reaches PROD only through this promote, after that rehearsal.

**Audit history is re-pointed** to the new ids. Nothing reads the audit log back: nine functions write it and none reads it. The one alignment audit row keeps the map.

**Not changed:**

- the calendar mode of `promote.py`;
- international ingestion;
- the staging report's informational role;
- `EVENT_CODE_MATCHING` seasons.

**Found and deliberately not fixed here:**

- `evf_sync._heal_future_completed` carries a stale comment claiming the validator forbids leaving COMPLETED; it is corrected in the lifecycle build step.
- LOCAL's 3 results that fail the V-category condition are LOCAL data, and they disappear with the seed reload that keeps PROD's ids.
