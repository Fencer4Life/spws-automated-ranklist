# ADR-061: LOCAL operator workflow preserved verbatim; Telegram-driven CERT command surface

**Status:** Proposed
**Date:** 2026-05-03
**Amends:** ADR-025 (Event-Centric Ingestion + Telegram Admin), ADR-041 (Edge function dispatch), ADR-050 (Unified Ingestion Pipeline).

## Context

Two requirements collided during Phase 5.5 planning:

1. **LOCAL parity** — the operator is mid-rebuild on LOCAL (GP5/GP6 of 2023-2024 of the rebuild). All new infrastructure (Storage bucket, Telegram delivery, edge-function regen, GH workflow dispatch) must NOT change the LOCAL operator workflow they have today.

2. **CERT operability without LOCAL** — for season-current ingestion (June 2026 onwards), the operator works against CERT only. They have no local checkout of the repo, no Python venv, no shell access. They need to drive ingestion + triage + verdict re-fetch entirely from a phone (Telegram) and an admin UI.

The first requirement says: keep LOCAL filesystem-based, no Telegram, no Storage. The second says: build a rich CERT-side command surface.

## Decision

### LOCAL workflow guarantee (unchanged from today)

After this plan ships, LOCAL operators continue to:

- Run `python -m python.tools.phase5_runner --event-code <X>` from shell against LOCAL DB.
- Get `.md` written to `doc/staging/<X>.md` via `Path.write_text()` (existing line 492 behaviour).
- No Telegram fired (no `TELEGRAM_BOT_TOKEN` env var on LOCAL by default).
- No Storage upload (`config.toml` keeps storage disabled).
- Open admin UI on `localhost:5173` against LOCAL Supabase. Aliases tab gets the additive UI improvements (unreviewed-first sort, modal, cascade banner) — these are pure frontend + RPC changes and work against any DB.
- Manually rerun `python -m python.tools.phase5_report --event-code <X>` from shell to refresh the `.md` after a triage session — exactly the habit they have today.

**No vite shell-spawn middleware** is built. Reasons: (a) it's not how the operator works today, (b) shell-spawning Python from a Node dev server has PYTHONPATH/venv-activation traps, (c) if LOCAL admin-UI parity is later wanted, it can be added in a focused follow-up without changing this plan.

`--md-target` CLI flag defaults to `local` (preserving today's filesystem behaviour). CI workflows pass `--md-target=storage` explicitly.

### CERT command surface — Telegram-driven

The GAS at `scripts/gas_email_ingestion.js` already polls Telegram for admin commands (per ADR-025). This ADR extends the command set with **4 new operator commands** that drive the CERT-side automation without admin-UI navigation:

| Command | Action |
|---|---|
| `/regen <event_code>` | Triggers `regen-report.yml` workflow → re-renders `full.md` from current DB state, uploads to Storage, sends Telegram document. Useful when operator wants a fresh verdict without doing an alias mutation. |
| `/stage <event_code>` | Triggers `phase5-event-runner.yml` workflow → runs the Phase-5 pipeline against the URL on `tbl_event.url_results`. Equivalent to the admin-UI "Stage event" button. |
| `/parity <event_code>` | Triggers a one-off EVF parity check for that single event (extends existing `evf-parity-sweep.yml` to accept optional `event_code` input). Sends delta `.md` if drift; replies "no drift" otherwise. |
| `/verdict <event_code>` | Fetches `staging-reports/{event_code}/full.md` from Storage and re-sends as a Telegram document. Useful if operator deleted the original message or wants to re-import to Obsidian. |

**`/help` extension** — the help text is rewritten to list all commands (existing + new) plus describes the auto-delivered documents the operator should expect (full.md after ingest/regen, delta.md after EVF sweeps).

### dispatch-workflow allowlist extension

`supabase/functions/dispatch-workflow/index.ts` ALLOWED_WORKFLOWS gains:
- `phase5-event-runner.yml`
- `regen-report.yml`

(Existing entries: `populate-urls.yml`, `scrape-tournament.yml`.)

The same edge function is invoked by both the admin UI ("Stage event" button on event detail panel) and the GAS Telegram dispatcher (via the existing `triggerGitHubWorkflow` GAS helper). Single allowlist enforcement point.

## Alternatives considered

### A. Build LOCAL parity via vite shell-spawn middleware

Rejected for this ADR. Brittle pattern, not how operator works today, can be added later. Captured as future ADR-062 (deferred).

### B. Lift LOCAL to use Storage too

Rejected: requires enabling storage in `config.toml`, disrupts in-flight rebuild, increases LOCAL setup complexity for negligible benefit (operator reads `doc/staging/<X>.md` directly today).

### C. Skip Telegram commands; require admin-UI for all CERT operations

Rejected: forces operator to context-switch to laptop/browser for routine ops (re-fetch verdict, re-stage). Telegram commands keep the phone-only workflow viable.

### D. Hardcode workflow names in GAS (no edge fn dispatch)

Rejected: GAS already uses the existing `triggerGitHubWorkflow` helper which calls GitHub directly with the GAS-owned PAT. Edge function dispatch is the admin-UI path; GAS already has the PAT and bypasses. Both paths supported (different auth surfaces).

## Consequences

**Positive:**
- LOCAL rebuild loop stays untouched — operator keeps using `phase5_runner` / `phase5_report` from shell, no surprises.
- CERT operator has full control from phone via Telegram commands — no laptop required for routine ops.
- `dispatch-workflow` allowlist remains the single point of truth for which workflows are CI-triggerable.
- New commands documented in `/help` so operator can discover without reading the GAS source.

**Negative:**
- Two parallel command surfaces (admin UI buttons + Telegram commands) for `/stage` and `/regen`. Acceptable: they call the same backend and are documented together.
- LOCAL admin-UI does NOT have a "Stage event" button or a UI-triggered regen (no vite middleware). Operator must shell out. This matches today's behaviour exactly.
- GAS code grows; testing remains mostly manual (ADR-025 already documented this trade-off).

## Status — deliverables (proposed, not yet shipped)

- `supabase/functions/dispatch-workflow/index.ts` ALLOWED_WORKFLOWS extension
- `scripts/gas_email_ingestion.js` — 4 new command cases + `downloadFromSupabaseStorage` helper + extended `/help` text
- `doc/archive/legacy-2026-07/cicd-operations-manual.md` updates: command cheat-sheet, runbook for fresh CERT/PROD setup, disaster recovery section
- CERT smoke test C16: end-to-end Telegram command verification
