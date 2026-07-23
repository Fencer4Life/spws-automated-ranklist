// ADR-041: Server-side workflow dispatch — no PAT in browser.
// ADR-083: the caller is now authenticated and MFA-gated (FR-132).
//
// A signed-in admin whose session has completed TOTP (aal2) POSTs
// { workflow, inputs }; the function verifies the caller, then dispatches the
// named workflow on GitHub Actions using a PAT stored as a Supabase env secret
// (GH_DISPATCH_PAT). The browser never sees the PAT.
//
// Allowed workflows are hard-coded; anything else returns 400.
//
// HISTORY — read before weakening any of this. Until 2026-07-23 the header of
// this file claimed "Authenticated callers POST…" while the code checked
// nothing at all. `verify_jwt = true` in config.toml reads like an
// authorization control and is not one: the public anon key is a valid,
// correctly-signed JWT that ships in the frontend bundle, so it satisfied
// verify_jwt and reached the dispatch path. Verified live against CERT and
// PROD: the anon key returned 400 invalid_workflow — i.e. it got as far as the
// allowlist — where it should have been rejected at the door. That stale
// comment is part of how the gap survived review; keep this one honest.
//
// Required env secrets (set via `supabase secrets set --project-ref <ref>`):
//   GH_DISPATCH_PAT  — fine-grained PAT, this repo only, Actions: read+write
//   GH_REPO          — "<owner>/<repo>", e.g. "Fencer4Life/spws-automated-ranklist"
//   ALLOWED_ORIGIN   — optional; the admin UI origin for this environment, so
//                      CERT and PROD differ without a code change.

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "jsr:@supabase/supabase-js@2"
import { authorizeCaller } from "./authorize.ts"

// Falls back to "*" when unset so that deploying this function before setting
// the secret cannot take the admin UI offline. CORS is a browser-side control
// and was never what protected this endpoint — authorizeCaller is. Set
// ALLOWED_ORIGIN per environment anyway; defence in depth is the point.
const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") ?? "*"

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
}

// Phase 5.5 (ADR-061): added phase5-event-runner.yml + regen-report.yml so
// the admin UI's "Stage event" button and the alias-mutation regen cascade
// can dispatch via this same allowlist. GAS dispatches directly with its own
// PAT and bypasses this allowlist (different auth surface).
const ALLOWED_WORKFLOWS = new Set([
  "populate-urls.yml",
  "scrape-tournament.yml",
  "phase5-event-runner.yml",
  "regen-report.yml",
  // N13.6: NEW-pipeline from-URL re-ingest (keep-rule + source overrides) — the
  // "Re-ingest event" button in the event accordion dispatches this.
  "ingest-event.yml",
  // ADR-077: SeasonManager "⬆ Promote to PROD" / "Remove from PROD" — promote a
  // childless season skeleton CERT→PROD (or delete it), server-side, no PROD PAT.
  "promote-season.yml",
  // ADR-080 §5: EventManager organizer delivery button.
  "ftl-seed.yml",
])

Deno.serve(async (req) => {
  // Preflight carries no credentials by design — it must not be authorized.
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders })
  }
  if (req.method !== "POST") {
    return jsonError(405, "method_not_allowed", `Use POST, got ${req.method}`)
  }

  // ---- ADR-083 / FR-132: authorize the caller BEFORE anything else --------
  // Before any env read, any body parse and any allowlist lookup, so that an
  // unauthorized caller cannot even distinguish a misconfigured deployment
  // from a healthy one.
  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonError(500, "config_missing", "SUPABASE_URL or SUPABASE_ANON_KEY not set")
  }

  const authz = await authorizeCaller(
    req.headers.get("Authorization"),
    async (token) => {
      const supabase = createClient(supabaseUrl, supabaseAnonKey)
      const { data, error } = await supabase.auth.getUser(token)
      if (error || !data?.user) return null
      return { id: data.user.id }
    },
  )
  if (!authz.ok) {
    return jsonError(authz.status, authz.code, authz.message)
  }
  // ------------------------------------------------------------------------

  const pat = Deno.env.get("GH_DISPATCH_PAT")
  const repo = Deno.env.get("GH_REPO")
  if (!pat || !repo) {
    return jsonError(500, "config_missing", "GH_DISPATCH_PAT or GH_REPO env secret not set")
  }

  let body: unknown
  try {
    body = await req.json()
  } catch {
    return jsonError(400, "invalid_json", "request body must be JSON")
  }

  const { workflow, inputs } = (body ?? {}) as { workflow?: string; inputs?: Record<string, string> }
  if (typeof workflow !== "string" || !ALLOWED_WORKFLOWS.has(workflow)) {
    return jsonError(
      400,
      "invalid_workflow",
      `workflow must be one of: ${[...ALLOWED_WORKFLOWS].join(", ")}`,
    )
  }
  if (inputs !== undefined && (typeof inputs !== "object" || inputs === null || Array.isArray(inputs))) {
    return jsonError(400, "invalid_inputs", "inputs must be an object of strings")
  }

  // Attributable dispatch: the run history is the cheapest tamper signal this
  // system has, and it is only useful if each dispatch names who caused it.
  console.log(`dispatch-workflow: user=${authz.userId} workflow=${workflow}`)

  const ghResp = await fetch(
    `https://api.github.com/repos/${repo}/actions/workflows/${workflow}/dispatches`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${pat}`,
        Accept: "application/vnd.github.v3+json",
        "Content-Type": "application/json",
        "User-Agent": "spws-ranklist-dispatch/1.0",
      },
      body: JSON.stringify({ ref: "main", inputs: inputs ?? {} }),
    },
  )

  if (!ghResp.ok) {
    const text = await ghResp.text()
    return jsonError(
      502,
      "gh_dispatch_failed",
      `GitHub returned ${ghResp.status}: ${text.slice(0, 500)}`,
    )
  }

  return jsonOk({
    workflow,
    inputs: inputs ?? {},
    runs_url: `https://github.com/${repo}/actions/workflows/${workflow}`,
  })
})

function jsonOk(data: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ ok: true, ...data }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function jsonError(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ ok: false, code, message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}
