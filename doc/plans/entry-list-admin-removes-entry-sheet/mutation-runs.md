# FR-166 — mutation runs for guards that held before the change

Plan: `doc/plans/entry-list-admin-removes-entry-tdd-plan-2026-11-17.html` §05. A test marked ◆ guards something
already true, so it cannot be seen red first; each is proven by breaking the guarded thing on purpose,
seeing the test fail, and restoring.

## REGDEL.01–02 (`supabase/tests/129_registration_admin_delete.sql`), LOCAL Docker stack, 2026-11-17

Unmutated: `ok 1..4`.

Each mutation was added right after `SELECT plan(4);` in a scratch copy, inside the test's own
transaction, which rolls back.

| Mutation | 1 visitor refused | 2 row remains | 3 admin removes one | 4 only that row |
|---|---|---|---|---|
| A · `DROP POLICY "Admin all registrations"` | ok | ok | **not ok** | **not ok** |
| B · visitors granted DELETE + a DELETE policy | **not ok** | ok | ok | ok |
| C · as B, plus a SELECT policy for visitors | **not ok** | **not ok** | ok | **not ok** |

B leaves assertion 2 green because row security also applies the read policies to a DELETE's WHERE
clause: a visitor with delete rights but no read policy deletes nothing. C removes that second barrier
and every visitor assertion fails.

After the runs: `tbl_registration` carries one policy, and `anon` holds no DELETE privilege (nothing
persisted).

The test's first form built a temp table from a deleting `WITH` clause, which postgrestools cannot
typecheck; it was reshaped to a `DO` block carrying the row count out through a transaction-local
setting, and the three mutations were re-run on the reshaped test with the results above.

## ELREM.01, ELREM.13, CV.16 (Vitest), 2026-11-17

Each mutation was applied to the finished code, the tests run, and the file restored from a copy
(`cmp` identical; `frontend/src/ce/EntryListElement.svelte` shows no diff against `main`).

| Mutation | ELREM.01 no button without the setting | ELREM.13 never on the public page | CV.16 a visitor never gets „Usuń” |
|---|---|---|---|
| D · `EntryList` defaults `canRemove` to true | **fail** | **fail** | pass (the calendar passes its value explicitly) |
| E · `CalendarView` passes `canRemove={true}` | — | — | **fail** (CV.15 fails too) |
| F · `EntryListElement` passes `canRemove={true}` | — | **fail** | — |

## Found by the tests

CV.15 failed after the first implementation for a reason not foreseen in the plan: signing out removed
the buttons but left an open confirmation on screen. The confirmation now renders only while removal is
allowed.
