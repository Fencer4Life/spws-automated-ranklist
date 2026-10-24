# Testing

This file defines Claude's test procedure. The canonical human overview and traceability model live in [Test and traceability](../handbook/reference/test-and-traceability.html).

## Commands

```bash
# LOCAL database — never run a bare supabase db reset
./scripts/reset-dev.sh
bash scripts/check-postgrestools.sh    # hard gate: zero findings, canaries prove it ran live
supabase test db

# Python
source .venv/bin/activate
python -m pytest python/tests/ -v
python -m pytest -m integration        # opt-in: live EVF/Dartagnan sites; a plain run deselects them
ruff check python/ scripts/ tools/
ruff format --check python/ scripts/ tools/
basedpyright python/ scripts/ tools/

# Frontend
cd frontend
npm test
npm run check -- --fail-on-warnings
npm run test:e2e

# Repository and documentation coherence
bash scripts/check-coherence.sh
bash scripts/check-spec-sync.sh
python scripts/check_docs.py
python scripts/render_adrs.py --check
python scripts/render_docs.py --check
python scripts/render_handbook_frame.py --check
```

Run narrow affected tests first. Before completing a code change, run the applicable full suites and repository gates. Do not claim a command passed unless it completed successfully in the current work.

## Language-specific checks

- Python: Ruff lint/format and BasedPyright over `python/ scripts/ tools/` are CI-enforced with zero findings. A `DeprecationWarning` raised from project code fails pytest (`filterwarnings` in `pyproject.toml`); a test that exercises a deprecated path on purpose ignores that one message by name. Preserve intentional re-exports and order-dependent imports with justified annotations.
- PL/pgSQL: run `postgrestools check <changed.sql>` with LOCAL Supabase running, then affected pgTAP. `scripts/check-postgrestools.sh` then checks all migrations after the configured cut-off and all pgTAP files with warnings as errors: zero findings, and an unavoidable one carries an inline `-- pgt-ignore…: <reason>`. It first proves type checking and `plpgsql_check` are live with canary files, because postgrestools silently skips both when the database is unreachable. It is a hard gate in `scripts/preflight.sh` (also under `--fast`) and in CI's test-db job. Follow `.claude/skills/plpgsql-check/SKILL.md`.
- Svelte/TypeScript: run `npm run check -- --fail-on-warnings` after every frontend source edit (preflight fails on any warning), plus affected Vitest/Playwright coverage. Follow `.claude/skills/svelte-check/SKILL.md`.
- Documentation tooling: run Ruff and BasedPyright on changed Python scripts, then all documentation render/check commands above.

Do not preserve numeric baseline prose here. CI configuration, test files, RTM and coherence scripts are the evidence; volatile counts belong only in generated or explicitly validated governance records.

## TDD workflow

1. Define acceptance assertions and stable plan-test IDs.
2. Write the test code.
3. Run it and confirm RED; rewrite a test that passes before implementation.
4. Implement the minimum change.
5. Run the affected checks and confirm GREEN.
6. Refactor while keeping tests green.

Every test keeps the traceability chain `FR/NFR ↔ RTM ↔ plan test ID ↔ test code`:

- pgTAP: `-- 2.19`
- pytest: docstring `4.25`
- Vitest: `// 6.5`

When requirements, test IDs or pgTAP `plan(N)` totals change, update the RTM and the validated specification totals in the same change, then run both coherence scripts.

## Documentation after tests

Testing a changed behavior is not sufficient documentation. Use the ownership map to identify affected current pages, update them in present tense, and complete the documentation coherence gate before handoff.
