---
name: svelte-check
description: "MANDATORY after writing or editing ANY .svelte or frontend .ts file in this repo (SPWS Automated Ranklist System) — components, stores, custom elements, tests under frontend/. Runs svelte-check (the official Svelte-team type-checker, covers both .svelte and .ts together) against the changed file before the task counts as done — the frontend equivalent of running ruff/basedpyright after a Python edit or postgrestools after a SQL edit. Triggers on: writing, editing, or creating .svelte files, Svelte components, frontend .ts files, stores, custom elements."
---

# Svelte/TS check — svelte-check after every frontend write

`frontend/tsconfig.json` declares `"strict": true`, but nothing enforced it
until 2026-07-02 — no CI gate, no local script. This repo's frontend is
mostly `.svelte` (28 of 39 source files), which generic TypeScript tooling
doesn't understand at all (template bindings, runes, slots, props). Writing
frontend code without checking it is not acceptable here — same bar as
Python (ruff/basedpyright) and SQL (postgrestools).

## What to do

Immediately after creating or editing a `.svelte` or `frontend/**/*.ts` file:

```bash
cd frontend && npm run check -- --fail-on-warnings
```

(`svelte-check --tsconfig ./tsconfig.json` under the hood; without
`--fail-on-warnings` it exits 0 on warnings, which `scripts/preflight.sh` and
CI's test-frontend job both reject. It checks the whole project each run,
since svelte-check doesn't cleanly support true single-file mode.)

For quick interactive lookups on a specific `.ts`/`.js` symbol (hover,
go-to-definition, find-references) the harness's `LSP` tool works directly —
`typescript-language-server` is installed globally. **`.svelte` files have no
`LSP` tool routing at all** (same dead end as `.sql`) — always use
`npm run check` for those, never expect the interactive tool to cover them.

## Before the task counts as done

- **The baseline is zero errors and zero warnings, across the whole project.**
  Preflight and CI both run `npm run check -- --fail-on-warnings` (pinned by
  `python/tests/test_static_check_gates.py` GATE.05–06), so any finding fails,
  wherever it is. There is no "pre-existing" excuse. `tsconfig.json` includes
  both Vite configs, and `svelte.config.js` declares the `customElement`
  compiler option both builds use, so the checker sees what ships.
- Fix genuine type errors and real bugs the checker surfaces (e.g. use-before-assignment, comparisons
  between disjoint literal types that can never be true — both found in the
  2026-07-02 baseline and worth a second look wherever similar patterns
  appear).
- **New a11y warnings on markup you wrote** (`a11y_no_static_element_interactions`,
  `a11y_click_events_have_key_events`, `a11y_label_has_associated_control`,
  etc.) should be fixed, not just noted — they're cheap to fix at write time.
- Svelte 5 runes-migration warnings (`state_referenced_locally`) on code you
  wrote should be fixed; don't introduce new ones.
- A warning that marks deliberate code gets a `// svelte-ignore <code>`
  comment on the statement, with the reason next to it (for example a
  one-time read of an element attribute at mount), never a config switch.
- This runs **in addition to**, not instead of, vitest and the mandatory TDD
  workflow in `doc/claude/testing.md`.
- If the frontend change alters product behavior, navigation, authentication, embedding or operations, update the owning current HTML page from `doc/handbook/documentation-map.html` and complete the documentation coherence gate.

## If the check itself is broken

`svelte-check` is a `frontend/package.json` devDependency (`npm install` in
`frontend/` gets it) and `typescript-language-server` is installed globally
(`npm install -g typescript-language-server typescript`). If either is
missing, fix the environment — don't skip the check and eyeball the code
instead.

## Why this exists

User is fully committed to this frontend stack and asked (2026-07-02) for
svelte-check to be used automatically on every `.svelte`/`.ts` write, the
same way ruff/basedpyright and postgrestools already are — not something
they should have to ask for each time. See
`[[feedback_svelte_check_after_frontend_write]]` in memory.
