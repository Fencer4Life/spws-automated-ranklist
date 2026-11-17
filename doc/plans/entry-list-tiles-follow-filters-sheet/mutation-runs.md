# Mutation runs for the guards (FR-165)

Plan: `doc/plans/entry-list-tiles-follow-filters-tdd-plan-2026-11-17.html` §04 and §08 step 6.
ELSEL.01 and ELSEL.07 hold before the change, so they cannot be seen red. Each was proven by
breaking `frontend/src/components/EntryList.svelte` on purpose, running the guard, and restoring.
Run on 2026-11-17 in the worktree of branch `claude/entry-list-tiles-follow-filters`.

| Guard | Mutation | Result |
|-------|----------|--------|
| ELSEL.07 (spaces do not narrow) | `isNarrowed` tests `search !== ''` instead of `search.trim() !== ''` | FAILED: `expected [ '8 z 8', '5 z 5', '3 z 3', '2 z 2' ] to deeply equal [ '8', '5', '3', '2' ]` |
| ELSEL.01 (nothing narrowing: plain totals, no marks) | `isNarrowed` forced to `true` | FAILED: `expected [ '8 z 8', '5 z 5', '3 z 3', '2 z 2' ] to deeply equal [ '8', '5', '3', '2' ]` |

After restoring the code: `tests/EntryList.test.ts` and `tests/foldName.test.ts`, 35 passed.
