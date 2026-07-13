# SPWS repository guidance

## Coordination

- Claude Code may work in this repository concurrently. Treat unfamiliar changes as user-owned.
- Check `git status` before editing, before staging, and before committing.
- Never revert, overwrite, stage, or commit unrelated changes.
- Read active plans in `/Users/aleks/.claude/plans` when coordinating work; never edit them.
- Work sequentially. Diagnose and propose before materially expanding scope.

## Plans and documentation

- **FOR ANY PLAN USE THE HTML TEMPLATE.**
- Create every new plan and human-facing document as an `.html` file.
- Use `doc/plans/plan-template.html` as the visual template.
- Store persistent repository plans under `doc/plans/`.
- Required framework files with fixed names, including `AGENTS.md` and `SKILL.md`, are exceptions.
- Consult `CLAUDE.md` and its linked `doc/claude/` modules.
- Treat `doc/handbook/` as the canonical description of the current system; use ADRs for rationale, governance for requirements, evidence for run artifacts, and archive for superseded narratives.
- Before completing a change, apply the documentation coherence gate in `doc/handbook/reference/documentation-standard.html` and run `python scripts/check_docs.py --changed-from <base>`.

## Safety and integrity

- Never expose, store, or commit credentials. Use OAuth, keychains, or secret inputs.
- Never read spreadsheet files without explicit per-file authorization.
- Never run a bare `supabase db reset`; use `./scripts/reset-dev.sh` for LOCAL.
- Preserve the data-integrity constraints documented in `doc/claude/conventions.md`.
- Do not mutate CERT or PROD unless the current user request explicitly authorizes it.

## Development workflow

- Follow mandatory TDD: acceptance assertions, test code, RED, implementation, GREEN, refactor.
- After code changes, run the narrowest affected tests first.
- Before completing a code task, run the applicable full suites and coherence gates.
- Run `scripts/refresh-graph.sh` before every commit.
- Do not claim a check passed unless it was actually run successfully.

## Validation commands

- Python: `source .venv/bin/activate && python -m pytest python/tests/ -v`
- Ruff: `source .venv/bin/activate && ruff check python/ && ruff format --check python/`
- Python types: `source .venv/bin/activate && basedpyright python/`
- Frontend: `cd frontend && npm test && npm run check`
- Browser tests: `cd frontend && npm run test:e2e`
- Database: `supabase test db`
- Coherence: `bash scripts/check-coherence.sh && bash scripts/check-spec-sync.sh`
- PL/pgSQL: `postgrestools check <changed SQL path>` with local Supabase running

## Git and release

- Stage explicit paths only; never use broad staging when concurrent work exists.
- Review the staged diff before committing and recheck the worktree before pushing.
- Use the repository release skill for CI, release, workflow, push, or deployment tasks.
- Report modified files, validation performed, workflow results, and remaining risks.
