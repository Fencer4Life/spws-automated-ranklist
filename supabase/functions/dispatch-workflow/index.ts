// ADR-041: Server-side workflow dispatch — no PAT in browser.
//
// Authenticated callers POST { workflow, inputs } and the function dispatches
// the named workflow on GitHub Actions using a PAT stored as a Supabase env
// secret (GH_DISPATCH_PAT). The browser never sees the PAT.
//
// Allowed workflows are hard-coded; anything else returns 400.
//
// Required env secrets (set via `supabase secrets set --project-ref <ref>`):
//   GH_DISPATCH_PAT  — fine-grained PAT, this repo only, Actions: read+write
//   GH_REPO          — "<owner>/<repo>", e.g. "Fencer4Life/spws-automated-ranklist"

import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

const ALLOWED_WORKFLOWS = new Set(["populate-urls.yml", "scrape-tournament.yml"])

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders })
  }
  if (req.method !== "POST") {
    return jsonError(405, "method_not_allowed", `Use POST, got ${req.method}`)
  }

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
