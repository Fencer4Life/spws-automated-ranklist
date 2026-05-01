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
```

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
