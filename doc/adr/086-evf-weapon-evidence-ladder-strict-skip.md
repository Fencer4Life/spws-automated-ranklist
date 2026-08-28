# ADR-086: EVF weapon evidence ladder, strict skip for unannounced stubs, and anchored-code renumbering

**Status:** Accepted (2026-08-28)
**Date:** 2026-08-28
**Resolved:** Both open items closed on sign-off, 2026-08-28.
**Amends:** [ADR-043](043-evf-event-allocator.md) §Amendment (2026-08-07) — "missing/unsupported weapon sets … are hard errors" and "A later cancellation keeps its positive code"; [ADR-046](046-pew-weapon-suffix.md) §Amendment (2026-08-07) — "If no authoritative weapon set can be established, the entire calendar write fails before mutation" and "An event cancelled later keeps its previously assigned positive code"
**Relates to:** [ADR-028](028-evf-calendar-results-import.md) (EVF calendar/results import), [ADR-039](039-stale-event-gate.md) (stale-event gate), [ADR-081](081-cert-prod-event-reconciler.md) (CERT→PROD reconciler carries the renames), [ADR-036](036-prod-export-local-mirror.md) (monolithic seed dump loaded by `db reset`, after migrations)
**Source:** `python/scrapers/evf_calendar.py`, `supabase/migrations/20260828000004_evf_event_weapons_lifecycle_gate.sql`

## Context

On 2026-08-19 the `EVF Calendar + Results Sync` workflow began failing, and failed every scheduled run for nine days (last green 2026-08-18).

EVF published `EVF Circuit – Tampere (FIN)` (calendar id `5379`, 23 Jan 2027) as a stub post carrying **no weapon category tags**. The list-page parser derives weapons solely from the `cat_epee` / `cat_foil` / `cat_sabre` taxonomy classes on the Tribe Events article, so the entry reached validation with an empty weapon set and hit ADR-043's hard error at [`evf_calendar.py:1179`](../../python/scrapers/evf_calendar.py).

Two consequences, both more damaging than the missing datum:

1. **One untagged post in January 2027 aborted the entire season scrape** — all 18 other events included.
2. `sync_calendar` re-raised, so `main()` never reached `sync_results`. **Nine days of results ingestion were lost** to an event five months in the future.

The only recovery ADR-046 provided was "a linked official organizer programme may supply the set" — realised as `_KNOWN_WEAPON_OVERRIDES` at [`evf_calendar.py:93`](../../python/scrapers/evf_calendar.py), a hand-maintained map holding exactly one entry (Toronto `5070`). Every future occurrence required a code change and a deploy.

Evidence gathered against the live site on 2026-08-28:

- Tampere's **detail page** states `EPEE + SABRE` in its description while carrying no category meta at all.
- Four other events (Madrid, Lausanne, Łomianki, Guildford) carry category meta on the detail page that agrees with the list page by construction — it is the same taxonomy.
- `Critérium de Paris 2026` (4–6 Jul 2026, past) states no weapon anywhere: its description reads "Two genders, three weapons, four days", naming none.
- Toronto's detail page likewise states none, so its override still does real work.

Two further facts constrain the fix:

- **`arr_weapons` cannot express "unknown".** Its `DEFAULT` is `'{EPEE,FOIL,SABRE}'`, so omitting the column silently asserts all three. Measured on CERT: **zero** rows are `NULL`, and 86 of 96 sit on that default — including **60 COMPLETED events**, among them epee-only and sabre-only ones. This is why `weaponLetters()` in [`frontend/src/lib/calendarQuarters.ts`](../../frontend/src/lib/calendarQuarters.ts) reads weapons from the code suffix and returns `[]` for an unsuffixed code, "rather than a guess".
- **The seed inserts 32+ unsuffixed `PEW` events already in `COMPLETED`** (`PEW11-2024-2025` Guildford, `PEW13-2023-2024`, `PEW68-2026-2027`, …). Migrations run *before* the ADR-036 seed dump, so any `CHECK` constraint on this shape would reject the seed on every `reset-dev.sh` and every CI run.

Finally, fixing the weapons failure exposed the next domino. Admitting Tampere between Guildford (`PEW6`, 9 Jan) and Levi Open (`PEW7`, 30 Jan) shifts ten events down one, while Stockholm — cancelled by EVF in the **same** scrape — was pinned at `PEW11` by ADR-043's "a later cancellation keeps its positive code". The two rules cannot both hold:

```
CalendarIntegrityError: later cancellation 'EVF Circuit – Stockholm (SWE) – Cancelled'
must retain PEW11, but chronological position is PEW12
```

ADR-043 already contains the resolution in its own text — "Unscored rows may be reflowed transactionally if EVF inserts or reschedules an earlier entry. If a reflow would rename a results-bearing row, ingestion aborts" — but the cancellation pin was written as unconditional and contradicts it. This ADR resolves that internal inconsistency rather than reversing a decision.

## Decision

### 1 · Weapons are established by an evidence ladder, never by a guess

Weapons for a calendar entry are derived from the first source that names one, in descending authority:

1. the list page's `cat_*` taxonomy (unchanged, ADR-028);
2. the detail page's `.tribe-events-event-categories` meta — the same taxonomy, so it agrees with (1) by construction;
3. the detail page's description line, which organizers open with (`EPEE + SABRE`). This is the only source for a post carrying no categories at all;
4. the linked **invitation letter (PDF)**, for a post whose description names no weapon;
5. `_KNOWN_WEAPON_OVERRIDES` — approved manual evidence, deliberately **last**, so that real EVF data always wins over a hand-entered fact that may have gone stale.

Matching is whole-word only, so `EPEE +FOIL +SABRE` written without spaces reads correctly while prose such as "three weapons" cannot invent one. Silence returns an empty set; no rung ever guesses.

Only weaponless entries are fetched, so a fully tagged calendar costs no additional requests. See `repair_missing_weapons` ([`evf_calendar.py:786`](../../python/scrapers/evf_calendar.py)), `_weapons_from_text` ([`:732`](../../python/scrapers/evf_calendar.py)) and `_weapons_from_pdf_bytes` ([`:741`](../../python/scrapers/evf_calendar.py)), which mirrors the tolerant extraction already used for Engarde result PDFs.

### 2 · An entry with unknown weapons is skipped, not fatal

**This amends ADR-043 and ADR-046: an unestablished weapon set is no longer a hard error.**

An event whose weapons cannot be established is one EVF has not finished announcing. To a fencer that is indistinguishable from an event EVF has not posted at all, so it is held back rather than imported with invented data, and picked up automatically on a later run once EVF tags it. The run stays green: this is normal operation, not a failure.

The skip is implemented as a **partition before validation** (`partition_unweaponed`, [`evf_calendar.py:891`](../../python/scrapers/evf_calendar.py)), not as a softened guard. `validate_season_calendar` keeps its contract exactly as ADR-043 states it — missing or unparseable dates, missing or duplicate calendar IDs, boundary-spanning entries and a non-exact `{1..N}` positive plan all remain hard errors. It simply never sees an unannounced stub.

**An event already imported is never held back.** If EVF edits a live post and its categories vanish, that is a regression, not a stub, and the existing row keeps the weapons it has. The roster's calendar IDs are read before the scrape for this purpose (`_known_calendar_ids`, [`evf_sync.py:284`](../../python/scrapers/evf_sync.py)).

ADR-046's rule that **an empty suffix is not valid for a calendar-owned PEW row is preserved, not weakened** — such a row is never written at all.

### 3 · Unknown weapons bar an EVF event from leaving PLANNED

The database enforces the same rule independently of the scraper: an EVF event whose code carries no weapon letters may not transition out of `PLANNED`, so tournaments and results can never attach to an event whose weapons were never established.

Keyed on the `txt_code` suffix, **not** `arr_weapons`, for the reason given in Context: a guard written against `arr_weapons` would pass for every row including the wrong ones — a guard that always passes, which is worse than none.

Implemented as a `BEFORE UPDATE` trigger, **not** a `CHECK` constraint, because the rule is about the *transition* and because a `CHECK` would reject the ADR-036 seed dump. Historical rows are inserted already-`COMPLETED` and never transition, so they load untouched. Scoped to `^PEW[0-9]+-`; `PPW` and `MSW` codes legitimately carry no weapon letters.

Accepted residual gap: a direct `INSERT` of a non-`PLANNED` unsuffixed PEW event is not blocked, because blocking it is precisely what breaks the seed. The scraper always creates `PLANNED`, so this reaches hand-written SQL only.

### 4 · A pinned cancellation yields to the reflow rule when nothing is anchored to its code

**This amends ADR-043 and ADR-046: "a later cancellation keeps its positive code" becomes conditional.**

A later cancellation may shift with the sequence when — and only when — the event is still in the future, has **zero registrations** and **zero results**. Otherwise the hard error stands.

The part of the rule that carries the meaning is untouched: a later cancellation still never collapses to `PEW0` and never frees its slot. Only its position within the sequence may move, and only while nothing is anchored to the old code.

This extends ADR-043's existing anchor set from *results* to *results and registrations*. Registration did not exist when ADR-043 was written; it is now the sharper anchor, because a fencer who has entered holds a code that must not move under them. Results remain anchored through the child tournament codes the ingest RPC rebuilds from the event code.

A roster row that does not carry the counts is refused: **unknown is not zero**. See `_is_safe_to_renumber` ([`evf_calendar.py:126`](../../python/scrapers/evf_calendar.py)).

**The guard exists in two places and both must agree.** ADR-043 describes the RPC's own guards as the backstop for when the planner is bypassed, so `fn_ingest_evf_calendar_identity_v1` enforces the cancellation pin independently of the Python planner. Relaxing only the planner produced a plan the backstop then rejected — observed live on 2026-08-28 (run 33187122201), after the first fix had already cleared the weapons failure:

```
fn_ingest_evf_calendar: later cancellation 3444 cannot move PEW11 to PEW12
```

**Clearing the pin then exposed an ordering defect, not a rule.** Codes are chronological position, so one mid-season insertion shifts the whole tail — and the assignment loop walks in date order, so each shifted event momentarily wants a code its successor has not vacated, while the newly inserted event wants one held by the event it displaces. Both surfaced in run 33188636456 and locally:

```
fn_ingest_evf_calendar: unsafe occupied code PEW16efs-2026-2027
duplicate key value violates unique constraint "idx_event_code"
```

ADR-043 already promises this reflow — "unscored rows may be reflowed transactionally if EVF inserts or reschedules an earlier entry" — but it had never been exercised, because no event had previously been inserted ahead of an existing one. Migration `20260828000006` lifts the staging the function already performs per-event for tournament codes (`__evfcal_<id>`) to a batch pre-pass over events: every calendar-owned event whose code this payload changes is parked on a placeholder first, so the loop only ever assigns into free codes. Scored events are excluded, so they keep their code and still trip the existing "refusing to renumber scored event" guard rather than being quietly parked.

Staging then had to be made non-destructive: the cancellation rules read an event's prior PEW number out of its own `txt_code`, so parking that code reclassified a *later* cancellation as a *first-import* one and demanded `PEW0` (run 33190231601). Migration `20260828000007` snapshots every code in the season before the pre-pass parks anything and derives the prior number from that snapshot; the rename decision still reads the live code, because that is what must differ for the rename to happen.

Migration `20260828000005` relaxes the server-side half through
`fn_evf_event_code_is_movable(id_event)`, which encodes the same three conditions in SQL. It is reproduced from the **live** `pg_get_functiondef` output rather than from `20260807000001`, so the prior-link amendments in `20260808000001`/`2` are carried forward instead of reverted; only the cancellation guard differs.

### 4b · CERT→PROD carries a rename as a rename

Renumbering has to reach PROD, and the reconciler could not express it. It diffed purely on `txt_code`, so an event whose PEW number shifted read as "delete the old row, create a new one" — and the create collided with the row PROD still held (run 33191199882):

```
duplicate key value violates unique constraint "idx_tbl_event_evf_slug"
Key (id_season, txt_evf_slug)=(4, levi-open-fin) already exists
```

ADR-043 already states the durable calendar identity carries across to PROD; the reconciler simply never used it. `promote_calendar` now matches on `id_evf_calendar_event` when the code has moved, so a renamed event is an UPDATE and is never proposed for deletion. Migration `20260828000008` supplies the SQL half: `fn_mirror_events_to_prod`'s UPDATE branch carries `txt_code` (it never did), and a staging pre-pass parks codes that are about to change, because cascading renames collide with each other on PROD for the same reason they did on CERT.

The match is **identity first, code only as fallback** for rows that have no calendar identity (domestic `PPW`/`MSW` events). Code-first is actively wrong mid-reflow: after renumbering, CERT's Dublin carries the code PROD still has on Toronto, so matching on the code wrote Dublin's fields — slug included — onto Toronto's row and tripped the same unique index from the other direction (run 33192281240).

**Known limitation, not fixed here.** The mirror does not touch tournaments — they are owned by `promote_event` — so a renamed PROD event temporarily carries child tournament codes built from its previous code, until its results are promoted.

### 4c · PROD receives every event-level field, not only the ones it was created with

An audit of `tbl_event`'s 41 columns against `fn_mirror_events_to_prod` found sixteen that never reached PROD on update. Three were CREATEd and then silently frozen — `txt_venue_address`, `id_prior_event`, `enum_status` — and five were carried by neither branch: `num_entry_fee_2w`, `num_entry_fee_3w`, `url_entry_list`, `txt_organizer_email`, `bool_use_spws_registration`.

The visible symptom was `PPW1-2026-2027` holding `ITAKA ARENA, ul. Olejnika1, Opole` on CERT and `NULL` on PROD, reported as an unsynced divergence in every daily reconcile log; `num_entry_fee_2w` appeared there as an "UNMAPPED new column".

Each field follows the policy of its siblings: `txt_venue_address` and `id_prior_event` overwrite when CERT states a value, as `txt_location` does; the fee tiers, entry list and organizer contact are fill-blank, as `num_entry_fee` and the `url_*` fields are, so an admin edit made on PROD stands; `bool_use_spws_registration` overwrites, being configuration CERT owns.

**Three things stay excluded, because pushing CERT's value would destroy or falsify a PROD-owned fact:**

- `enum_status` — `promote_event` advances it on PROD (`PLANNED → IN_PROGRESS → COMPLETED`, [promote.py:292](../../python/pipeline/promote.py)), so syncing CERT's value could regress a scored event.
- `ts_ftl_sent` — stamped per environment by `ftl_feed_seed_send.py` (`--target cert|prod`); overwriting would falsify the record of a seed actually sent from PROD.
- The ingestion provenance block (`txt_source_status`, `enum_parser_kind`, `dt_last_scraped`, `txt_source_url_used`, `txt_parity_notes`, `json_ingest_sources`, `json_source_overrides`) — CERT-side scrape diagnostics describing how CERT obtained the row, not facts about the event.

### 5 · A calendar failure no longer blocks results ingestion

Calendar sync enters *future* events into the calendar. Results sync is the last-resort path for attaching results to events that have already happened; the normal path is manual ingestion from the admin UI, and this pass scrapes only EVF-organised results.

The two share no data dependency, so `sync_results` now runs even when `sync_calendar` fails ([`evf_sync.py:1235`](../../python/scrapers/evf_sync.py)). The Telegram alert and the `FAILED` scrape-ledger row are unchanged, and the process still exits non-zero so CI stays red. The coupling was incidental — a shared `main()` — never a decision.

## Alternatives considered

1. **Presume a weapon (e.g. sabre) until EVF publishes the real set.** Rejected. Weapon letters are welded into `txt_code`, the natural key the CERT→PROD reconciler diffs on (ADR-081) and the parent of every child tournament code. A guessed `PEW8s` corrected later to `PEW8es` makes `fn_ingest_evf_calendar` rename the event and rewrite its tournament codes, and can shunt an occupant into `EVFLEGACY` quarantine — debris already visible on PROD as `EVFLEGACY104-2026-2027`. Worse, it publishes a weapon list to fencers that we invented, and nothing inside the system distinguishes it from established fact.
2. **Admit the event with an unsuffixed provisional code (`PEW8-2026-2027`) and no weapons.** Rejected by the user in favour of the stricter skip. It would have held the chronological slot, but it puts a row in front of fencers for an event EVF has not finished announcing, and it requires the lifecycle gate (§3) to do load-bearing work rather than act as a backstop.
3. **A `CHECK` constraint for §3 instead of a trigger.** Rejected on evidence: the ADR-036 seed dump inserts 32+ unsuffixed `PEW` events already `COMPLETED`, and migrations run before it. `NOT VALID` does not help — it skips validation of pre-existing rows but still binds subsequent inserts.
4. **A guard on `arr_weapons` for §3.** Rejected: the column's default makes it unable to express "unknown", so the guard would pass for all 96 CERT rows including the 60 COMPLETED ones whose weapon sets are wrong.
5. **Allocate newly-inserted events the next free number instead of their chronological position.** Rejected: it preserves every existing code but abandons the chronological ordering ADR-043's 2026-08-07 amendment was specifically written to establish.
6. **Keep the pin and hold Tampere back indefinitely.** Rejected: it makes an unrelated event's cancellation permanently block a legitimate new entry, and the events involved are all future, unregistered and result-less.

## Consequences

- **New files.** `supabase/migrations/20260828000005_evf_cancellation_sequence_shift.sql` (`fn_evf_event_code_is_movable` + the relaxed ingest RPC) and `supabase/tests/61_evf_cancellation_sequence_shift.sql` (7 assertions, pinning each arm of "anchored" separately — past, undated, registered, results-bearing and unknown are each refused on their own). `supabase/migrations/20260828000004_evf_event_weapons_lifecycle_gate.sql` (`fn_guard_evf_event_weapons_known` + `trg_guard_evf_event_weapons_known`); `supabase/tests/60_evf_event_weapons_lifecycle_gate.sql` (7 assertions, including 60.6 pinning that a historical unsuffixed `COMPLETED` row remains updatable — the case a `CHECK` would have broken).
- **Test impact.** `python/tests/test_evf_calendar.py` gains plan-test IDs evf.13–evf.19 (30 assertions). No existing ADR-pinned test is deleted; three test stubs were widened to accept `scrape_full_season_calendar`'s new keyword arguments.
- **Contract change.** `scrape_full_season_calendar` gains `known_calendar_ids` and `pending_weapons`; the roster query in `sync_calendar` gains `num_registrations` and `num_results`. `parse_event_detail_html` returns an additional `weapons` key.
- **Operational surface.** The Telegram digest gains `pending_weapons=<n>`, and the scrape ledger records the held-back names, calendar IDs and URLs. No new alert channel: a held-back entry is not an error.
- **First live effect.** `EVF Circuit – Tampere (FIN)` enters as `PEW7es-2026-2027`, shifting Levi Open through Toronto down one, including Stockholm `PEW11ef` → `PEW12ef` under §4. All are future, unregistered and result-less. The CERT→PROD reconciler carries the renames (ADR-081).
- **ADR-083 interaction.** `fn_evf_event_code_is_movable` is an internal helper for a `SECURITY DEFINER` RPC, so it is `REVOKE`d from `PUBLIC` and `anon`. Postgres grants `EXECUTE` to `PUBLIC` on creation, which put it on the anon-executable surface until revoked — caught by `52_security_posture.sql` test 52.7, which is what that gate is for.
- **`Critérium de Paris 2026` remains held back** — it states no weapons on any rung. It is outside the active season window, so it has no present effect.

## Defects found and deliberately not fixed

- **`arr_weapons` is untrustworthy system-wide.** 60 COMPLETED events claim all three weapons because of the column default, including epee-only and sabre-only events. Anything built on `arr_weapons` is building on sand. Fixing it (backfill from code suffixes, drop the default, or retire the column) needs its own decision and is out of scope here.
- **Tampere's `dt_end` is wrong on the list page** (23 Jan; the detail page says 23–24 Jan) — the same stub-post shape that caused the weapons gap.
- **`supabase/tests/19_phase3_wizard.sql` plans 25 assertions but runs 5.** Pre-existing and unrelated: verified to fail identically with this ADR's trigger dropped.

## Open items

Both items below were resolved on sign-off, 2026-08-28. They are retained because each records a decision, not a pending question.

1. **The anchor set in §4 is accepted as written** — future *and* zero registrations *and* zero results. The stated rule was "you can renumber any future event … if registration has not started, there is nothing to be afraid of"; results are retained in the set because they remain anchored to the code through the child tournament codes the ingest RPC rebuilds.
2. **`PEW9-2024-2025` on PROD is deleted.** Executed 2026-08-28 after re-verifying every dependency live: `id_event = 54`, COMPLETED, 3 May 2025, with zero tournaments, registrations, ingest-history rows, recompute-queue rows, and nothing referencing it as a prior event — the emptiness that matters, because three of those foreign keys cascade. PROD went from 114 to 113 events with the active-season count unchanged at 42, and **both CERT and PROD now hold zero unsuffixed `PEW` rows**.

   This does **not** unlock tightening §3 from a trigger to a `CHECK` constraint. The blocker was never the PROD row: it is the ADR-036 seed dump, which inserts 32+ unsuffixed `PEW` events already `COMPLETED` and loads *after* migrations. The trigger remains the correct mechanism.
