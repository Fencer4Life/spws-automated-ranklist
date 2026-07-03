# Testing

## Commands

```bash
# Local Supabase (LOCAL only — never run bare `supabase db reset`)
./scripts/reset-dev.sh                  # resets DB + recreates admin@spws.local
supabase start
supabase test db                        # pgTAP suite

# Python (PEP 668 — must use venv, not system pip)
source .venv/bin/activate
python -m pytest python/tests/ -v       # all pytest
python -m pytest python/tests/test_X.py::test_Y -v   # single test
python -m pytest -m "not integration"   # skip live-API tests

# Frontend
cd frontend && npm install
npm run dev                             # vite dev server (admin: http://localhost:5173/?admin=1)
npm test                                # vitest (full)
npm test -- path/to/file.test.ts        # single vitest file
npm run test:watch
npm run test:e2e                        # Playwright

# Coherence gates (same as CI)
bash scripts/check-coherence.sh
bash scripts/check-spec-sync.sh                            # Phase 0.5 layout invariants

# Rebuild-period commands (REBUILD-ACTIVE through Phase 6)
bash scripts/load-cert-ref.sh                              # populate cert_ref schema from PROD seed
python -m pipeline.ingest_cli review-event <code>          # interactive per-event review
python -m pipeline.ingest_cli list-drafts                  # list pending review drafts
python -m pipeline.ingest_cli resume --run-id <UUID>       # resume interrupted draft
python -m pipeline.ingest_cli commit-draft --run-id <UUID>
make -C doc/rules                                          # build doc/rules/*.html from markdown
```

## Linting & type-checking (LSP)

Python uses an LSP/static-analysis stack (installed 2026-06-24, enforced 2026-06-24):
**ruff** (lint + format) and **basedpyright** (type-checker). Both are `dev` optional-deps
in `pyproject.toml`; config lives in `[tool.ruff]`/`[tool.ruff.lint]` and `[tool.basedpyright]`.
Editor wiring is in `.vscode/settings.json` (ruff = formatter, format-on-save + organize-imports;
basedpyright in `standard` mode) and `.vscode/extensions.json`.

```bash
source .venv/bin/activate
ruff check python/            # lint  (BLOCKS CI)
ruff format python/           # auto-format
ruff format --check python/   # format gate (BLOCKS CI)
basedpyright python/          # type-check (non-blocking report for now)
```

- **ruff is clean and ENFORCED in CI** — the `ruff check` and `ruff format --check` steps in
  `.github/workflows/ci.yml` block the build. Keep `ruff check python/` at zero findings.
- **Line length** is owned by the formatter (E501 is disabled in lint); `ruff format` wraps to
  `line-length = 100` and `format --check` enforces it. Don't hand-wrap strings to satisfy E501.
- **basedpyright** is still a non-blocking report. **Baseline as of 2026-07-02 (post-sweep):**
  245 → 1 finding. The 1 remaining (`apply_birth_years.py:18`, `reportMissingImports` on
  `infer_birth_years`) is a confirmed false positive — the module exists, basedpyright's resolver
  just can't see it. The sweep fixed all genuine None-safety/argument-type/redeclaration errors
  (real assert-guards, widened callee types, or `# pyright: ignore[...]` with a reason comment for
  odfpy's stub-less types, dynamic-dispatch `DataclassInstance` code, and deliberately-invalid test
  literals) and found two pre-existing production bugs along the way: `review_cli.py`/
  `evf_parity_sweep.py`'s EVF_API fetch paths were missing `json.loads()` before `parse_results()`
  (silently always failed), and `ftl.py`'s `parse_csv` didn't apply ADR-066 DNS/DNF/walkover
  handling like `parse_json` does. Still non-blocking in CI (`continue-on-error` not yet removed —
  separate decision from this sweep).
- Protect deliberate re-exports (`# noqa: F401` or `__all__`) and order-dependent imports
  (`# noqa: E402`) — `ruff --fix` will otherwise strip them.

## SQL/PL-pgSQL linting & type-checking (postgrestools)

SQL uses **postgrestools** (Supabase's own Postgres Language Server, `@postgrestools/postgrestools`
on npm, installed globally — not a project devDependency, matching how `basedpyright` is installed
via `uv tool`). Config: `postgres-language-server.jsonc` at repo root, pointing at the local
Supabase Postgres instance (`127.0.0.1:54322`, matching `supabase/config.toml` `[db].port`).
Requires `supabase start` to be running — it type-checks against the real schema, not just syntax.

```bash
postgrestools check supabase/migrations/<file>.sql   # single file — run after every PL/pgSQL edit
postgrestools check supabase/migrations/             # full baseline
```

- **Mandatory after every PL/pgSQL write** — any new/edited migration, `CREATE [OR REPLACE]
  FUNCTION`, trigger, or RPC. Enforced by the `.claude/skills/plpgsql-check/SKILL.md` project
  skill so it isn't optional. Fix genuine findings (schema-referencing bugs, unsafe migration lock
  patterns); note explicitly if a warning is an accepted tradeoff rather than silently ignoring it.
- **Not yet wired into CI** — unlike ruff, there is no CI gate for this yet (OPEN item).
- **Baseline as of 2026-07-02 (post-sweep):** still 20 warnings across 167 migration/test files,
  but the composition changed. Added a single `SET LOCAL lock_timeout = '2s';` at the top of the
  affected transaction in each of the 3 flagged files (`20250301000002_rls_policies.sql`,
  `20250302000001_nullable_fencer_on_result.sql`, `20250303000001_intake_rules.sql`) — this
  eliminates the `lockTimeoutWarning` category entirely (9→0; a migration now fails fast on lock
  contention instead of hanging indefinitely). It does **not** reduce the total count: postgrestools
  re-flags every later statement in the same transaction as `runningStatementWhileHoldingAccessExclusive`/
  `avoidWideLockWindow` instead, once the first ACCESS-EXCLUSIVE lock in the transaction is taken.
  **Verified empirically** — adding `SET LOCAL` before *every* flagged statement (not just the
  first) does not help either; it just recategorizes the same way. The only way to actually reduce
  the 20 is what's explicitly declined below (split into separate transactions, or combine ALTER
  statements) — legacy debt, don't fix retroactively unless touching those files for another reason.
  Remaining composition: 6 `avoidWideLockWindow`, 1 `banDropNotNull`, 2 `multipleAlterTable`,
  11 `runningStatementWhileHoldingAccessExclusive`.
- Semantic checking inside PL/pgSQL function bodies (`plpgsqlCheck`) is enabled but the upstream
  tool is newer/less mature than ruff/basedpyright — treat findings as a strong signal, not
  infallible.

## Frontend linting & type-checking (svelte-check + typescript-language-server)

Frontend uses **svelte-check** (official Svelte-team tool, covers `.svelte` + `.ts` together) as
a `dev` devDependency in `frontend/package.json`, plus **typescript-language-server** (installed
globally via `npm install -g typescript-language-server typescript`, matching how `basedpyright`
is installed) for interactive `.ts`/`.js` code intelligence. `frontend/tsconfig.json` already
declares `"strict": true`.

```bash
cd frontend
npm run check              # svelte-check --tsconfig ./tsconfig.json — run after every .svelte/.ts edit
```

- **Mandatory after every `.svelte`/`.ts` write.** Enforced by the
  `.claude/skills/svelte-check/SKILL.md` project skill. Fix genuine type errors and real bugs
  (e.g. use-before-assign, comparisons between disjoint literal types); a11y warnings
  (`a11y_no_static_element_interactions`, `a11y_label_has_associated_control`, etc.) and Svelte 5
  runes-migration warnings (`state_referenced_locally`) are lower priority but should be tracked,
  not silently ignored.
- **Not yet wired into CI** — `.github/workflows/ci.yml` type-checks Python but not the frontend
  (OPEN item).
- **Baseline as of 2026-07-02 (post-sweep):** `npm run check` → 425 files, **0 errors, 2 warnings**
  (`options_missing_custom_element` on `RanklistElement.svelte`/`CalendarElement.svelte` — confirmed
  false positive, `customElement: true` is set at the CE-bundle vite-plugin-svelte config, which the
  standalone `svelte-check` invocation doesn't see). Fixed for real: the `bestJ`-used-before-assignment
  bug in `DrilldownModal.svelte`, the `App.svelte` CERT/PROD literal-narrowing gap, missing type
  imports/fixture drift across ~15 files, all 55 a11y warnings (real `role`/`tabindex`/keydown
  fixes, not suppressions — `<!-- svelte-ignore -->` HTML comments do NOT suppress a11y warnings
  under svelte-check 4.7.1, verified empirically), and all 9 `state_referenced_locally` warnings.
- The harness's own `LSP` tool has `.ts`/`.js` routing (works once `typescript-language-server`
  is installed) but **no `.svelte` routing at all** — same limitation as `.sql`. Use `svelte-check`
  via Bash for `.svelte` files, the `LSP` tool only for plain `.ts`/`.js`.

## TDD Workflow (mandatory)

Every implementation task follows this strict order:

1. **Define acceptance tests FIRST** — write test assertions in the milestone plan table before any code
2. **Write test code** — implement the tests (pgTAP/pytest/vitest) with plan test ID comments
3. **Run tests → confirm RED** — all new tests must fail (proves they test something real)
4. **Write implementation code** — minimum code to make tests pass
5. **Run tests → confirm GREEN** — all tests pass
6. **Refactor** — clean up while keeping tests green

**Never skip the RED phase.** If a test passes before implementation, it's testing nothing.

## After-change rule

After **any** code change, run the affected suite. Before marking a task complete, run **all three** suites (pgTAP, pytest, vitest) to catch regressions. Never skip test runs.

## Coherence rule (mandatory before commit)

When the **count** of pgTAP assertions changes (test added, removed, plan(N) updated), you **must** update the documented totals in two places — CI Gate 3 reads them and will fail otherwise:

1. **`doc/Project Specification. SPWS Automated Ranklist System.md` Appendix D** — the line `- pgTAP total: N assertions (...)`. Adjust both the headline N and the matching breakdown component (e.g. `25 Phase 3a wizard backend` → `23 Phase 3a wizard backend`).
2. **`bash scripts/check-coherence.sh`** — run locally before commit. Gate 3 compares actual `plan(N)` sum against the documented total.

If you change `plan(N)` in any test file, the actual sum changes — update the spec same commit.

## Test ID traceability

Every test carries a plan test ID comment to keep the chain `FR/NFR ↔ RTM ↔ plan test ID ↔ test code` enforceable:

- pgTAP: `-- 2.19`
- pytest: docstring `4.25`
- vitest: `// 6.5`
