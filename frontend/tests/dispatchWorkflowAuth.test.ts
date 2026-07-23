// ADR-083 / FR-132 — dispatch-workflow caller authorization.
//
// The Edge Function shipped with `verify_jwt = true` and a hard-coded workflow
// allowlist, but never inspected WHO was calling. verify_jwt is satisfied by
// the public anon key — which ships in the frontend bundle — so anyone could
// dispatch promote-season.yml or ftl-seed.yml against PROD. Verified live on
// CERT and PROD 2026-07-23: the anon key reached handler logic and returned
// 400 invalid_workflow, not 401.
//
// FR-132.4 is the assertion that closes that hole: the anon key carries
// role "anon", and only role "authenticated" may dispatch.
//
// The decision logic lives in a pure module (authorize.ts) with no Deno or
// network dependencies, so it is testable here under vitest rather than only
// reachable through a deployed function.

import { describe, it, expect, vi } from 'vitest'
import { authorizeCaller } from '../../supabase/functions/dispatch-workflow/authorize'

// Build an unsigned JWT-shaped token. The signature is irrelevant to these
// tests: authorizeCaller never trusts the payload on its own — it requires the
// injected resolver (the real one calls supabase.auth.getUser, which verifies
// the token against the auth server) to succeed first.
function token(payload: Record<string, unknown>): string {
  const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url')
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64(payload)}.signature`
}

const resolvesUser = vi.fn().mockResolvedValue({ id: 'user-uuid-1' })
const resolvesNobody = vi.fn().mockResolvedValue(null)

describe('authorizeCaller (ADR-083 / FR-132)', () => {
  // FR-132.1 — no Authorization header at all
  it('rejects a request with no Authorization header (401)', async () => {
    const r = await authorizeCaller(null, resolvesUser)
    expect(r.ok).toBe(false)
    if (!r.ok) {
      expect(r.status).toBe(401)
      expect(r.code).toBe('missing_authorization')
    }
  })

  // FR-132.2 — header present but not a bearer token
  it('rejects a malformed Authorization header (401)', async () => {
    const r = await authorizeCaller('Basic dXNlcjpwYXNz', resolvesUser)
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.status).toBe(401)
  })

  // FR-132.3 — bearer token that is not a decodable JWT
  it('rejects an undecodable bearer token (401)', async () => {
    const r = await authorizeCaller('Bearer not-a-jwt', resolvesUser)
    expect(r.ok).toBe(false)
    if (!r.ok) {
      expect(r.status).toBe(401)
      expect(r.code).toBe('invalid_token')
    }
  })

  // FR-132.4 — THE finding. The public anon key is a valid, correctly-signed
  // JWT carrying role "anon". Before this change it sailed through verify_jwt
  // and reached the dispatch path.
  it('rejects the public anon key because its role is anon, not authenticated (401)', async () => {
    const anonKey = token({ iss: 'supabase', role: 'anon' })
    const r = await authorizeCaller(`Bearer ${anonKey}`, resolvesUser)
    expect(r.ok).toBe(false)
    if (!r.ok) {
      expect(r.status).toBe(401)
      expect(r.code).toBe('not_authenticated')
    }
  })

  // FR-132.5 — service_role is a server-side secret and must never be the
  // caller identity for a browser-originated dispatch either.
  it('rejects a service_role token (401)', async () => {
    const svc = token({ iss: 'supabase', role: 'service_role' })
    const r = await authorizeCaller(`Bearer ${svc}`, resolvesUser)
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.code).toBe('not_authenticated')
  })

  // FR-132.6 — role claim says authenticated, but the token does not resolve
  // to a real user (expired, revoked, or forged). The payload is never trusted
  // without the resolver agreeing.
  it('rejects an authenticated-role token that resolves to no user (401)', async () => {
    const forged = token({ iss: 'supabase', role: 'authenticated', aal: 'aal2', sub: 'nope' })
    const r = await authorizeCaller(`Bearer ${forged}`, resolvesNobody)
    expect(r.ok).toBe(false)
    if (!r.ok) {
      expect(r.status).toBe(401)
      expect(r.code).toBe('invalid_token')
    }
  })

  // FR-132.7 — a genuine admin session that has not completed TOTP. Both
  // admins hold verified TOTP factors (auth.mfa_factors), so requiring aal2
  // locks nobody out.
  it('rejects a genuine aal1 session (403 — MFA not completed)', async () => {
    const aal1 = token({ iss: 'supabase', role: 'authenticated', aal: 'aal1', sub: 'user-uuid-1' })
    const r = await authorizeCaller(`Bearer ${aal1}`, resolvesUser)
    expect(r.ok).toBe(false)
    if (!r.ok) {
      expect(r.status).toBe(403)
      expect(r.code).toBe('mfa_required')
    }
  })

  // FR-132.8 — the only accepted caller.
  it('accepts a genuine aal2 admin session', async () => {
    const aal2 = token({ iss: 'supabase', role: 'authenticated', aal: 'aal2', sub: 'user-uuid-1' })
    const r = await authorizeCaller(`Bearer ${aal2}`, resolvesUser)
    expect(r.ok).toBe(true)
    if (r.ok) expect(r.userId).toBe('user-uuid-1')
  })

  // FR-132.9 — a missing aal claim is treated as not-aal2, never as a pass.
  it('rejects a token with no aal claim at all (403)', async () => {
    const noAal = token({ iss: 'supabase', role: 'authenticated', sub: 'user-uuid-1' })
    const r = await authorizeCaller(`Bearer ${noAal}`, resolvesUser)
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.code).toBe('mfa_required')
  })
})
