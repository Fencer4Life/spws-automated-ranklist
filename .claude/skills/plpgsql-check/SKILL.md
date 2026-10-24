---
name: plpgsql-check
description: "MANDATORY after writing or editing ANY SQL in this repo (SPWS Automated Ranklist System) — migrations, CREATE/CREATE OR REPLACE FUNCTION, triggers, RPCs, pgTAP test SQL. Runs postgrestools (Supabase's Postgres Language Server) against the changed file before the task counts as done — the SQL equivalent of running ruff/basedpyright after a Python edit. Triggers on: writing, editing, or creating .sql files, PL/pgSQL functions, migrations, triggers, RPCs."
---

# PL/pgSQL check — postgrestools after every SQL write

This repo is fully committed to Supabase, and its real logic lives inside
PL/pgSQL function bodies (scoring engine, triggers, RPCs), not just table
DDL. Writing SQL without checking it against the real schema is not
acceptable here — same bar as Python, where ruff/basedpyright run after
every edit.

## What to do

Immediately after creating or editing a `.sql` file (a migration under
`supabase/migrations/`, a pgTAP test under `supabase/tests/`, or any inline
SQL containing `CREATE FUNCTION`, `CREATE OR REPLACE FUNCTION`, `CREATE
TRIGGER`, or an RPC body), run:

```bash
postgrestools check <path/to/file.sql>
```

Requires the local Supabase stack running (`supabase status` — if it's down,
`./scripts/reset-dev.sh` per [[feedback_db_reset]], never a bare `supabase
start` on a stale/uninitialized DB). Config is `postgres-language-server.jsonc`
at repo root, already pointed at `127.0.0.1:54322`.

## Before the task counts as done

- **Zero new findings** on the file(s) you touched. Fix genuine issues:
  schema-referencing bugs (columns/tables that don't exist), unsafe migration
  lock patterns (`lint/safety/*`), PL/pgSQL syntax/semantic errors
  (`plpgsqlCheck`).
- **The baseline is zero, and it is a hard gate.** `scripts/check-postgrestools.sh`
  runs `postgrestools check --error-on-warnings --max-diagnostics=none
  supabase/migrations supabase/tests`, so any finding anywhere, warnings
  included, fails. There is no "pre-existing" excuse. The script runs in
  `scripts/preflight.sh` (never skipped, not even by `--fast`) and in CI's
  test-db job. Before the real run it checks three canary files: a
  missing column must give a type-check finding, a broken function body a
  `plpgsql_check` finding, and a plain pgTAP call none. That matters because
  postgrestools exits 0 and silently skips both database checks when it
  cannot reach the database. It also fails if the installed version differs
  from the `$schema` pin or the checked file count is not what the
  configuration implies. Pinned by `python/tests/test_static_check_gates.py`.
- A finding the checker **cannot** avoid gets an inline suppression with a
  reason, never a config switch. Wrap only the statements concerned, never an
  unflagged one:
  - Objects the test file creates itself (`pg_temp` helpers, temp tables or
    views) are invisible to the checker, which sees only the live schema:
    `-- pgt-ignore-start typecheck: <reason>` / `-- pgt-ignore-end typecheck`
    (and the same pair with `plpgsql_check` for a helper's body).
  - A psql `\gset` line: `-- pgt-ignore syntax: <reason>` on the line before.
  - Migration lock rules in a pgTAP file that does DDL: line 1 of the file is
    `-- pgt-ignore-all lint/safety: <reason>`. It only works on line 1, and
    `linter.ignore` in the config has no effect in 0.25.5.
  An unused suppression is itself a warning, so a stale one fails preflight.
  Before suppressing, prove the finding is the checker's limit and not a
  defect: a misspelled column in a test is a real finding.
- Migrations up to the `migrations.after` cut-off in
  `postgres-language-server.jsonc` are applied history on CERT and PROD and
  are not checked; never edit them. Every newer migration is checked in full.
- LOCAL needs pgTAP and `plpgsql_check` in the `extensions` schema
  (`supabase/seed_dev_tooling.sql`, loaded by `./scripts/reset-dev.sh`), and
  `typecheck.searchPath` includes `extensions`. If pgTAP calls such as
  `plan()` or `is()` report 42883, LOCAL lacks them: reset it. Without
  `plpgsql_check` the `plpgsqlCheck` feature silently does nothing.
- This runs **in addition to**, not instead of, pgTAP (`supabase test db`)
  and the mandatory TDD workflow in `doc/claude/testing.md` — postgrestools
  catches schema/lock/type issues pgTAP assertions don't, and vice versa.
- If the SQL changes behavior, data ownership, RPC contracts or operations, update the owning current HTML page from `doc/handbook/documentation-map.html` and complete the documentation coherence gate.

## If the check itself is broken

`postgrestools` is installed globally (`npm install -g
@postgrestools/postgrestools`), not as a project dependency — if the binary
is missing or the DB connection fails, that's an environment problem to fix
(see the `postgrestools-setup` memory), not a reason to skip the check and
fall back to eyeballing the SQL.

## Why this exists

User is fully committed to Supabase end-to-end (CERT/PROD/LOCAL) and asked
(2026-07-02) for postgrestools to be used automatically on every PL/pgSQL
write, the same way ruff/basedpyright already are for Python — not something
they should have to remind Claude to do. See `[[feedback_postgrestools_after_plpgsql_write]]`
in memory.
