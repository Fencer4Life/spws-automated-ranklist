# ADR-091: A season is bootstrapped only with skeletons nobody discovers for us

**Status:** Draft (proposed 2026-09-06; awaiting sign-off)
**Date:** 2026-09-06
**Amends:** [ADR-077](077-event-lifecycle-season-skeletons.md) §3 (season-skeleton provisioning narrows from "the expected events" to "the expected events nobody else publishes for us" — PEW, IMEW and DMEW leave the set; PPW, MPW and MSW stay), [ADR-044](044-phase3-wizard.md) §3 (the wizard's step-3 inventory no longer counts the EVF circuit or the European singleton: "5 PPW + 9 PEW + 1 MPW + 1 MSW + 1 IMEW = 17" becomes "5 PPW + 1 MPW + 1 MSW = 7")
**Relates to:** [ADR-039](039-stale-event-gate.md) (the dedup ladder a skeleton carries no key for), [ADR-043](043-evf-event-allocator.md) (the allocator's Step A and its `EVFLEGACY` quarantine — both retained, both reached far less often), [ADR-088](088-calendar-location-contract.md) (whose timing is the proximate cause), [ADR-036](036-prod-export-local-mirror.md) as amended 2026-07-14 (migrations run before the seed dump, which is why the prune is called twice), [ADR-081](081-cert-prod-event-reconciler.md) (CERT→PROD mirroring of the rows this stops creating)
**Source:** `supabase/migrations/20260906000001_no_evf_season_skeletons.sql`

## Context

Eight events in season 2026-2027 existed twice on PROD: once as a dateless
`CREATED` skeleton, once as the real `PLANNED` event. Fifteen more were due to
duplicate the same way as EVF published the rest of its calendar. The pairs were
invisible to fencers — `calendarMonths.ts:258` drops rows with no `dt_start` and
`visibleEvents` at `:545` filters `enum_status !== 'CREATED'` — so the cost fell
on administrators and on the season's event count.

**The first diagnosis was wrong, and the way it was wrong matters.** A report on
2026-09-05 blamed `_find_existing_match` (`python/scrapers/evf_calendar.py:1260`),
the ADR-039 dedup ladder: a skeleton carries no calendar id, no results id and no
slug, and the date gate `continue`s past it before the country and location rungs
are reached, so it is structurally unmatchable. All of that is true. None of it
is what creates the row.

The insert happens in SQL. `fn_ingest_evf_calendar`
(`20260711000001_prod_event_reconciler.sql:215`) asks `fn_allocate_evf_event_code`
(`20260429000001_phase4_pew_split.sql:55`) whether a scraped event should reuse an
existing slot or mint a new code, and **that function already has an
adopt-the-skeleton rung**. Step A matches a current-season `CREATED` PEW row and
hands back its code. The recommended fix on 2026-09-05 — "add a rung that adopts
the skeleton" — proposed building something the codebase had had since April.

Step A matches on **city**:

```sql
IF v_loc_key <> '' THEN
  SELECT COUNT(*)::INT, MAX(e.txt_code), MAX(e.id_prior_event)
    FROM tbl_event e,
         LATERAL fn_normalize_city_key(e.txt_location, e.txt_country) n
   WHERE e.id_season = p_id_season
     AND e.enum_status = 'CREATED'
     AND e.txt_code ~ '^PEW\d+[efs]*-'
     AND n.loc_key     = v_loc_key
     AND n.country_key = v_ctry_key;
```

`fn_init_season` copies the prior season's city onto each PEW skeleton, so the
rung has something to match. Measured on PROD 2026-09-05: **all 23 skeletons had
an empty `txt_location`**, and `fn_normalize_city_key` returned `''` for every one
of them. An empty key never equals a scraped event's non-empty key, so Step A
could not fire, and the allocator fell through to Step C — next-free
`PEW{N+1}` — minting a fresh row beside the skeleton on every run.

The cities were empty because of a two-month gap. The season was bootstrapped on
**2026-06-28**. ADR-088, the work that made `txt_location` reliably hold a city
rather than a venue title or nothing, was accepted on **2026-09-04**. There were
no cities to inherit.

That gap has closed, so a season bootstrapped today would inherit real cities and
Step A would mostly work. **Mostly is the problem.** Step A needs an exact city
match and EVF moves its circuit between seasons; every event that moves is a
skeleton that cannot be adopted, and a duplicate. The corpus has already paid for
this twice: ADR-043 carries an `EVFLEGACY` quarantine code that exists precisely
because "empty inherited skeletons collide with an identified calendar
occurrence", and an amendment of 2026-08-08 to stop a colliding skeleton donating
its `id_prior_event` to the wrong event.

## Decision

### 1 · The rule is discovery, not organiser

A season skeleton exists to hold a slot for an event the association knows will
happen but has not yet scheduled. That is worth doing when **nothing else will
create the row**. It is worth nothing when an automated source publishes the
event within the same season, because the skeleton is then a prediction competing
with the truth.

| Skeleton | Organizer | Created independently? | Provisioned |
| --- | --- | --- | --- |
| PPW1–n | SPWS | no — SPWS schedules these | **kept** |
| MPW | SPWS | no | **kept** |
| MSW | FIE | no — there is no FIE scraper in `python/scrapers/` | **kept** |
| PEW1–n | EVF | yes — `evf_calendar.py` / `evf_sync.py` | dropped |
| IMEW | EVF | yes — same scraper | dropped |
| DMEW | EVF | yes — same scraper | dropped |

**MSW is the case that decides the wording.** FIE organises it, so an
organiser-based rule ("keep only SPWS skeletons") would delete it. Nothing
discovers it for us, so it cannot duplicate, and its skeleton is the only thing
holding that slot in the season. The rule is therefore stated in terms of
discovery. If an FIE scraper is ever added, MSW leaves the set by the same rule
rather than by a new decision.

### 2 · `by_kind` keeps its keys and reports zero

`fn_init_season` returns `by_kind`, and callers read it **by key** — the season
wizard renders its step-3 inventory from it. The `PEW` key and the European key
are retained, reporting `0`, rather than disappearing. A caller asking for a key
that is no longer there is a silent `undefined`; a caller asking for one that
reports zero is correct.

### 3 · The prune runs twice, from one function

The skeletons already provisioned are removed by
`fn_prune_unclaimed_evf_skeletons()`, called from two places that cannot share a
statement:

- the migration, for CERT and PROD, where it runs against live data;
- `supabase/seed_post_backfill.sql`, for a fresh bootstrap.

The second is not belt-and-braces. On CI and `scripts/reset-dev.sh`, migrations
run **before** the seed dump loads — the ordering governed by the ADR-036
amendment of 2026-07-14 — so the migration's prune matches nothing and the dump
then reinstates all eighteen skeletons. This was reproduced on a real reset before
the seed call existed: 18 EVF rows came back and test 74.9 failed. One function
rather than two copies of the predicate, so the paths cannot drift.

The predicate is deliberately narrow, and every clause earns its place:
`CREATED` and dateless is the definition of an unclaimed skeleton; EVF is the
organiser whose events arrive by scrape; no tournament children means nothing has
been ingested against it; and nothing may reference it as `id_prior_event`, or a
carry-over chain would lose a link. A row failing any one clause is a real event
and is left alone.

### 4 · The allocator is not touched

Step A stays exactly as it is, as does ADR-043's `EVFLEGACY` quarantine. Both are
correct for what remains — an administrator who creates a skeleton and types a
city should have it adopted rather than duplicated, and a hand-made skeleton can
still collide. What changes is that nothing reaches either one with a *guessed*
city any more. Removing a working mechanism because it failed on inputs that will
no longer exist would be the wrong lesson.

### 5 · The wizard stops promising rows it will not create

`SeasonManagerWizard.svelte` listed the prior season's PEW count and the European
singleton in its step-3 inventory and added them to the total on the commit
button. On the 2026-2027 prior data it promised **17** skeletons where
`fn_init_season` now creates **7**. The PEW and IMEW/DMEW rows are removed and
the total counts PPW + MPW + MSW.

## Alternatives considered

1. **Fix the Python matcher's date gate.** Rejected on evidence: `_find_existing_match`
   does not create the row. The allocator does, and it would still mint a new code.
2. **Add a new adopt-the-skeleton rung below the ladder** (the 2026-09-05
   recommendation). Rejected: Step A already is that rung. A second one beside it
   would duplicate the mechanism and inherit the same dependency on a guessed city.
3. **Backfill the skeletons' cities and leave everything else alone.** Rejected as
   incomplete. It fixes the 2026-2027 generation, which ADR-088 has since made
   unlikely to recur, but leaves every event EVF relocates between seasons
   unadoptable — and there is no signal at bootstrap time for which those will be.
4. **Give skeletons an identity at creation** — carry the prior season's EVF
   calendar id or slug so Step 0 or Step 2 of the ladder matches. Rejected on the
   data: EVF issues a new calendar post id per season, so last season's id cannot
   match this season's event. Cheapest fix if it had worked; it does not.
5. **Reconcile after the fact** — pair orphan skeletons with real events nightly
   and retire the skeleton. Rejected as a mechanism: it does not prevent the
   duplicate, only cleans up behind it, and leaves a window where both rows exist.
   It was recommended on 2026-09-05 as a one-off for the eight pairs then live;
   those pairs were removed before this change, so it is moot.
6. **Delete every non-SPWS skeleton** — the organiser-based reading. Rejected
   because it removes MSW, which cannot duplicate and which nothing else creates.
   See §1.

## Consequences

**New files**

- `supabase/migrations/20260906000001_no_evf_season_skeletons.sql` — redefines
  `fn_init_season`, adds `fn_prune_unclaimed_evf_skeletons()`, prunes live data.
- `supabase/tests/74_no_evf_season_skeletons.sql` — plan-test-IDs 74.1–74.9.

**Changed**

- `supabase/seed_post_backfill.sql` — calls the prune after the dump loads.
- `frontend/src/components/SeasonManagerWizard.svelte` — step-3 inventory and total.
- `frontend/src/App.svelte` — `handleWizardLoadPrior` reports `PEW: 0`.
- `supabase/tests/19_phase3_wizard.sql` — ph3.3, ph3.7 and ph3.8 reversed in
  place rather than deleted, each carrying the reason at the assertion; the
  cascade-rename fixture (ph3.15–17) now creates its own PEW event instead of
  depending on the bootstrap for one.
- `frontend/tests/SeasonManagerWizard.test.ts` — ph3.27 and ph3.34 reversed,
  ph3.27b added for the corrected total.

**Test impact.** pgTAP 912 → 921 assertions, all passing, verified on a database
rebuilt from scratch so the migration/seed ordering is exercised rather than
assumed. Frontend 768 → 769, `svelte-check` 0 errors. Five assertions were
reversed and none deleted; every reversal is an ADR-077 or ADR-044 consequence and
is why both are amended here.

**A latent trap was found and not fixed.** `ph3.27b` initially passed against the
*old* code because the previous total was 17 and `toContain('7')` matches "17".
The assertion was tightened before the implementation landed. Substring assertions
on numbers are unsafe throughout this suite; the others were not audited.

**Not fixed, and worth knowing.** The superseded `fn_init_season` at
`20260428000003` carries a `^PEW\d+-` regex that matches no real event code —
every PEW code has a weapon suffix (ADR-046). It is dead in a superseded
migration, but it cost time during this investigation: it reads as the live
definition and implies PEW skeletons were never created at all.

## Open items

1. **The eight pairs already on PROD were removed by someone before this change.**
   Both environments read zero duplicate pairs on 2026-09-06 and no commit or
   scheduled workflow accounts for it; the likely explanation is manual admin
   deletion. If something automated did it, that is a separate finding worth
   chasing. *Recommendation:* confirm it was manual, and let it rest if so.
2. **`EVFLEGACY` rows already in the data.** ADR-043's quarantine has been used;
   those rows remain. They are outside this decision — they are quarantined
   collisions, not unclaimed skeletons, and the prune deliberately does not match
   them. *Recommendation:* audit them separately before the next season roll.
