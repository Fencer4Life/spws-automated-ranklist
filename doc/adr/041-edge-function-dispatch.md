# ADR-041: Server-Side Workflow Dispatch via Supabase Edge Function

**Status:** Accepted
**Date:** 2026-04-25
**Relates to:** ADR-029 (Tournament URL Auto-Population), ADR-025 (Event-Centric Ingestion + Telegram), ADR-026 (CERT→PROD Promotion).

## Context

The admin UI's ⬇ buttons (event-level "populate-urls" and tournament-level "scrape-tournament") currently dispatch GitHub Actions workflows by reading a Personal Access Token from a `github-pat` HTML attribute on the `<spws-ranklist>` web component and calling the GitHub `workflow_dispatch` API directly from the browser. The deployed `index.html` is served by GitHub Pages at a public URL — embedding a PAT in that HTML means anyone visiting the page can read it via View Source and use it to trigger workflows or otherwise abuse the token's scopes.

The existing `release.yml` deploy pipeline knows this is a problem: the four `sed` lines fill `supabase-cert-*` and `supabase-prod-*` attributes from secrets, but **deliberately do not fill `github-pat` / `github-repo`**. Those attributes are left empty on the deployed page, the early-return `import_no_github` error fires, and admins are pushed to use the secure Telegram path instead.

The Telegram path (`populate-urls <event>`, `scrape-tournament <code>`) routes through Google Apps Script which holds a PAT in script properties — server-side, never exposed to the browser. That works but is split across two surfaces (Telegram for cloud, button for local dev only). Admins want the in-page button to work too — securely, without leaking a PAT.

## Decision

The browser dispatches workflows by invoking a **Supabase Edge Function** (`dispatch-workflow`) that holds the PAT as a Supabase env secret and forwards the dispatch to GitHub on the caller's behalf. The PAT lives only inside the Edge Function's runtime — never in HTML, JavaScript bundles, or browser memory.

### Function contract

`POST /functions/v1/dispatch-workflow`

Request body:
```json
{ "workflow": "populate-urls.yml", "inputs": { "event_code": "PEW1-2025-2026" } }
```

Response (200 on dispatch success):
```json
{ "ok": true, "workflow": "populate-urls.yml", "runs_url": "https://github.com/.../actions/workflows/populate-urls.yml" }
```

Response (4xx/5xx on failure):
```json
{ "ok": false, "code": "invalid_workflow|config_missing|gh_dispatch_failed|...", "message": "..." }
```

### Allowed workflows (allowlist)

Hard-coded set in the function body: `populate-urls.yml`, `scrape-tournament.yml`. Any other value returns 400 `invalid_workflow`. This narrows the function's blast radius even if the caller's JWT is compromised — only those two workflows are ever dispatchable through it.

### Auth

Supabase Edge Functions verify the caller's JWT by default (`verify_jwt = true` in `config.toml`). The browser invokes via `supabase.functions.invoke()` which auto-attaches the admin's session JWT. Anonymous callers are rejected before reaching the handler.

### Secrets

Two env secrets, set once per environment (CERT + PROD) via `supabase secrets set --project-ref <ref> GH_DISPATCH_PAT=… GH_REPO=Fencer4Life/spws-automated-ranklist`:

- `GH_DISPATCH_PAT` — fine-grained PAT scoped to **this repo only** with `Actions: Read and write` permission. Nothing else.
- `GH_REPO` — `<owner>/<repo>` string. Read by the function so the repo coordinate is server-side, not embedded in the function source.

### Synchronous response

The function calls GitHub's `workflow_dispatch` endpoint inline and returns the result on the same HTTP round-trip. Latency is ~200-500 ms (one GH API call). No queue, no polling, no `tbl_dispatch_request` table — the simpler architecture won out over the previously-considered cron-poller queue.

### Inline UI status

The browser displays per-event-row status below the event-card (between the row and the tournament-list expansion). Three states:

- 🟦 `⏳ Triggering populate-urls for PEW1-2025-2026…` (during the network call)
- 🟩 `✓ Triggered: PEW1-2025-2026 — view run on GitHub Actions ↗` (auto-clears after 5 minutes)
- 🟥 `✗ Dispatch failed: <reason>` (auto-clears after 5 minutes)

Status is per-event so multiple in-flight dispatches across different events render independently. The global top-right toast banner from the previous round is preserved for non-dispatch errors (auth, RPC failures, etc.).

### Removed

- `github-pat` and `github-repo` attributes on `<spws-ranklist>` web component (App.svelte props).
- `triggerGitHubWorkflow` calls in `App.svelte` for `handleImportEvent` / `handleImportTournament` (replaced by Edge Function invocation moved into `EventManager.svelte`).
- Unused `import_no_github` locale key (the configuration error is now a 500 from the function, not a frontend gate).

## Alternatives considered

1. **Browser-direct dispatch with PAT in HTML** (status quo). Rejected: leaks PAT publicly. Existing release.yml already declines to populate this attribute for the same reason — the design was admittedly broken from the start.

2. **Request queue + GitHub Actions cron poller** (drafted earlier). Rejected after re-evaluation:
   - 60s worst-case latency vs sub-second for Edge Function
   - 1440 cron runs/day even when idle (wasteful)
   - Significantly more code (`tbl_dispatch_request` + RLS + 2 RPCs + workflow YAML + frontend polling logic) for no security advantage
   - The framing "uses zero PATs" was rhetorical — the Edge Function's PAT in Supabase env secrets is not meaningfully less secure than `secrets.GITHUB_TOKEN` inside a GH runner; both are server-side secrets the platform manages.

3. **Database webhook + pg_net + PAT in Supabase Vault**. Rejected for higher implementation complexity (Vault setup, async response handling via `pg_net.http_response` callback table) at no UX or security advantage over an Edge Function.

4. **Telegram-only on cloud, button local-dev-only**. The simplest "do nothing" option. Rejected because the user explicitly wants the button to work on CERT/PROD without relying on Telegram for every operation.

## Consequences

### Positive

- **No PAT in browser, ever.** PAT lives only in Supabase env secrets, accessible only to the function runtime.
- **Sub-second click-to-dispatch latency.** No queue, no polling.
- **Allowlisted dispatch surface.** Even if the function's auth check is bypassed, only two workflows are reachable.
- **Inline per-event status.** Each row shows its own dispatch progress; admin can scan the calendar and see which events are in-flight without scrolling to a global banner.
- **Telegram path untouched.** GAS still holds its own PAT server-side; both paths coexist.

### Negative

- **One-time setup per env:** admin runs `supabase secrets set` for CERT and PROD on first deploy. Documented in `doc/cicd-operations-manual.md` (to be updated).
- **Edge Function deploy added to release pipeline.** `release.yml` adds a `supabase functions deploy dispatch-workflow` step in `deploy-cert` and `deploy-prod` jobs.
- **Local testing of the function** uses `supabase functions serve` (separate process, runs Deno locally) rather than the Docker `edge_runtime` container which is disabled in this project's local config. Frontend dev server invokes against the local function port. Documented in CLAUDE.md / operations manual.

### Outbound surface (none new)

No new Telegram messages, no new GitHub Actions workflows beyond the existing `populate-urls.yml` and `scrape-tournament.yml` (which the function dispatches).

## Test plan

| ID | Assertion |
|---|---|
| `9.45a` | `handleDispatchEvent` calls `functions.invoke('dispatch-workflow', { workflow: 'populate-urls.yml', inputs: { event_code: ... } })` |
| `9.45b` | While the invoke promise is in-flight, status `⏳ Triggering…` renders inline below the event-row |
| `9.45c` | On `{ ok: true, runs_url }` response, status flips to `✓ Triggered…` with the run URL as a clickable link |
| `9.45d` | On `{ ok: false, message }` response (or thrown error), status flips to `✗ Dispatch failed: …` inline (not in the global toast) |
| `9.45e` | When `event.url_event` is empty, button is hidden so handler never runs (existing behaviour, regression guard) |
| `9.45f` | Multiple concurrent dispatches across different events render their own statuses independently |

## References

- Function: [`supabase/functions/dispatch-workflow/index.ts`](../../supabase/functions/dispatch-workflow/index.ts)
- Frontend caller: [`frontend/src/lib/api.ts`](../../frontend/src/lib/api.ts) — `requestDispatch()`
- Frontend handler + UI: [`frontend/src/components/EventManager.svelte`](../../frontend/src/components/EventManager.svelte)
- Deploy step: [`.github/workflows/release.yml`](../../.github/workflows/release.yml)
- Setup docs: `doc/cicd-operations-manual.md` §X (Edge Function secrets) — to be added.
