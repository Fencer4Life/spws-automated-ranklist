# ADR-110: From 2026/2027 the Fencer Table Is the Ranking Entry; Everyone in It with Points in the Window Is Ranked

**Status:** Accepted (signed off 2026-10-04 with D1 A, D2 A, D3 A, D4 A and the audit reason as proposed); implemented 2026-10-04: the audited revision ran on CERT (revision 8) and PROD (revision 10)
**Date:** 2026-10-04
**Supersedes:** [ADR-103](103-spws-place-medal-engine-per-type.md) §6 (ranking entry through PPW or MPW in the ranking's window; FR-141). The gate mechanism stays, unused.
**Relates to:** [ADR-020](020-seed-generator-domestic-auto-create.md) and [ADR-106](106-international-intake-by-identity-nationality-per-season.md) (who enters the fencer table), [ADR-100](100-pzsz-senior-result-ingestion.md) (PZSz results never create a fencer), [ADR-097](097-scoring-governance-lock-and-privileged-revision.md) (the audited revision of a locked season), [ADR-091](091-no-season-skeletons-for-scraped-events.md) and [ADR-108](108-promote-replays-verified-cert-ingestion.md) (carry-over and the CERT/PROD result fingerprint)
**Source:** `doc/plans/ranking-entry-by-roster-2026-10-04.html`; the trigger question in `doc/plans/konczylo-ranking-entry-2026-10-04.html`

## Context

ADR-103 §6 made a 2026/2027 fencer rankable only with a PPW or MPW result in the ranking's window: the ranked season, plus the previous season when the ranking is rolling. The Season Scoring Rules carried it as `entry_types: ["PPW", "MPW"]`, read by both bodies of `fn_ranking_full`.

On 4 October 2026 this left KOŃCZYŁO Tomasz (#136) out of the ranking. His last PPW and MPW starts were in 2024/2025, two seasons back; in 2025/2026 he fenced only PEW events, and in 2026/2027 he has no start yet. His EVF results were stored (ADR-106 admits a fencer with a PPW/MPW start in any season), yet no ranking listed them.

The user set the rule: from 2026/2027 a fencer enters the fencer table only through a PPW or MPW start, and everyone in it with points in the rolling window appears in the ranking, EVF+ points included.

Evidence, 4 October 2026:

- **Fencer creation already follows the rule.** Only domestic ingestion creates a fencer, from a PPW/MPW result (ADR-020). International intake stores a row only for an existing fencer with a PPW/MPW start (ADR-106), PZSz intake links exact names or approved aliases only (ADR-100), and a registration creates no fencer. No fencer created since 1 September 2026 lacks a PPW/MPW start.
- **Legacy rows.** 54 of PROD's 373 fencers have no PPW/MPW start in any season, all created in June–July 2026, before ADR-106. 46 hold no result, 5 only 2023/2024 results, and 3 hold results inside the 2026/2027 window: GOLA Maciej, KOSZYK Agnieszka and SZUMIELEWICZ Paweł.
- **The gate is driven by data.** With no `entry_types` in a season's rules, `fn_ranking_full` ranks every fencer with points in its window; seasons up to 2025/2026 already work so.
- **Measured.** On LOCAL, holding PROD's data of 3 October, in a rolled-back transaction: dropping `entry_types` grows the rolling 2026/2027 ranking from 227 to 250 rows (188 to 207 fencers). Nobody drops out, no total changes, and the season-only view is unchanged.

## Decision

### 1 · The fencer table is the entry

A fencer enters the fencer table only through a PPW or MPW result (ADR-020). International results (ADR-106) and PZSz results (ADR-100) never create one, and neither does a registration. This is unchanged, and recorded here as the rule the ranking now relies on.

### 2 · Everyone in it with points in the window is ranked

The 2026/2027 ranking ranks every fencer in the fencer table with points in its window: the Season Scoring Rules of `SPWS-2026-2027` carry no `entry_types`. The window and the buckets are unchanged — the ranked season, plus the previous season's carried results when rolling; SPWS counts the best 2 PPW and every MPW, EVF+ the best 5 of PEW, MEW, MSW, PSW, PPS and MPS.

### 3 · Legacy rows are ranked like everyone else

Fencers created before ADR-106 without a PPW/MPW start are ranked when they have points in the window, because they are in the fencer table (decision D2 A).

### 4 · The gate stays, unused

`fn_ranking_full` still honours `entry_types`, the Admin validator still accepts it, and the public season-rules window shows its "who enters" line only while it is set. No season uses it from 2026/2027, and no new public text is added (D3 A, D4 A).

### 5 · Through the audited revision

The season is locked (ADR-097), so the change ran through `fn_revise_and_rescore_season` on CERT and PROD, with the reason "ADR-110: ranking entry by roster (decision of 4 Oct 2026)" and no board reference. A checked script compared every 2026/2027 score, PPW1's result fingerprint and all 30 sub-rankings before and after, and would have aborted on any difference beyond the added fencers. Scores do not change, because the multipliers do not; the result fingerprint ignores revision ids and timestamps, so promote's CERT/PROD comparison holds.

### 6 · The rebuild no longer re-applies the gate

`supabase/seed_post_backfill.sql` no longer calls `fn_backfill_ranking_entry_types`, and its ADM27 block skips a locked 2026/2027: the season's rules arrive with the seed.

## Alternatives considered

1. **Keep ADR-103 §6.** Rejected: it leaves SPWS fencers with EVF+ points out of the ranking, as it did KOŃCZYŁO.
2. **Gate international intake by the window (D1 B).** Rejected: it refuses the EVF results of a fencer whose last PPW start is two seasons back, the results the rule wants counted.
3. **Rank only fencers with a PPW/MPW start in any season (D2 B).** Rejected: it needs a migration of both ranking bodies, and the user chose to rank the fencer table as it stands.
4. **Remove the gate (D3 B).** Rejected for now: a larger change across SQL, the validator, the rules window and their tests; kept, a future season can use it again.
5. **A direct UPDATE of the rules as the database owner.** Rejected: it bypasses the audit trail ADR-097 requires for a locked season.

## Consequences

- **Ranking.** The rolling 2026/2027 ranking adds 19 fencers in 23 places, all with 0 SPWS points; KOŃCZYŁO is second in men's V2 foil, and GINZERY Tomas leads men's V1 foil. Carried 2025/2026 results drop out as each event's next edition is held, as before.
- **Data.** One revision row per environment: CERT revision 8, PROD revision 10, LOCAL rehearsed. The seed exported from PROD carries the new rules.
- **Tests.** `85_spws_evf_joined_engine.sql`: SE27.RANK.01–05 set `entry_types` themselves and keep testing the gate; ROSTER.01–04 pin this decision. `84_admin_ranking_rules_validation.sql`: ADM27.RULES.14 pins the new 2026/2027 rules.
- **Requirements.** FR-141 is superseded by FR-152.
- **Not changed.** The engines, the buckets, the carry-over rule, international intake, and every season up to 2025/2026.
