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
- If a finding is a deliberate, accepted tradeoff (e.g. matches the existing
  baseline noted in `doc/claude/testing.md` — 20 pre-existing `ACCESS
  EXCLUSIVE` lock warnings on early RLS migrations), say so explicitly rather
  than silently ignoring the output. Don't fix pre-existing findings in files
  you didn't touch as a drive-by.
- This runs **in addition to**, not instead of, pgTAP (`supabase test db`)
  and the mandatory TDD workflow in `doc/claude/testing.md` — postgrestools
  catches schema/lock/type issues pgTAP assertions don't, and vice versa.

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
