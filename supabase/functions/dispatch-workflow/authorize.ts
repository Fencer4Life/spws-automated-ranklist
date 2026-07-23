// ADR-083 / FR-132 — caller authorization for dispatch-workflow.
//
// Split out of index.ts deliberately: this is the logic that closes the
// finding, and keeping it free of Deno and network dependencies means it can
// be unit-tested (frontend/tests/dispatchWorkflowAuth.test.ts) rather than
// only being exercisable against a deployed function.
//
// Background. The function shipped with `verify_jwt = true`, which sounds like
// an authorization check and is not one: the public anon key is a valid,
// correctly-signed JWT, and it ships in the frontend bundle. Every caller
// passed. The role check below is what actually closes it.

export type AuthzResult =
  | { ok: true; userId: string }
  | { ok: false; status: number; code: string; message: string }

/**
 * Resolves a bearer token to a user, or null. The real implementation calls
 * `supabase.auth.getUser(token)`, which verifies the token against the auth
 * server — this module never trusts decoded claims on their own.
 */
export type UserResolver = (token: string) => Promise<{ id: string } | null>

function deny(status: number, code: string, message: string): AuthzResult {
  return { ok: false, status, code, message }
}

/**
 * Decode a JWT payload WITHOUT verifying it.
 *
 * Safe only because of how it is used below: the decoded claims are never
 * acted on until `resolveUser` has independently confirmed the token with the
 * auth server. Decoding first lets us reject the anon key cheaply, before
 * spending a network round-trip on it.
 */
function decodeJwtPayload(token: string): Record<string, unknown> | null {
  const parts = token.split(".")
  if (parts.length !== 3) return null
  try {
    const segment = parts[1]
    const pad = segment.length % 4 === 0 ? "" : "=".repeat(4 - (segment.length % 4))
    const b64 = segment.replace(/-/g, "+").replace(/_/g, "/") + pad
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
    const claims: unknown = JSON.parse(new TextDecoder().decode(bytes))
    if (typeof claims !== "object" || claims === null || Array.isArray(claims)) return null
    return claims as Record<string, unknown>
  } catch {
    return null
  }
}

/**
 * Decide whether the caller behind `authHeader` may dispatch a workflow.
 *
 * Order is deliberate:
 *   1. header present and a bearer token          -> else 401
 *   2. token is a decodable JWT                   -> else 401
 *   3. role claim is exactly "authenticated"      -> else 401  (anon key dies here)
 *   4. token resolves to a real user              -> else 401
 *   5. session has completed MFA (aal2)           -> else 403
 *
 * 3 before 4 so the common hostile case (the public anon key) is rejected
 * without a network call. 5 last so a genuine admin who simply has not
 * finished TOTP gets 403 "finish MFA", clearly distinct from 401 "you are not
 * who you claim to be".
 */
export async function authorizeCaller(
  authHeader: string | null,
  resolveUser: UserResolver,
): Promise<AuthzResult> {
  if (!authHeader) {
    return deny(401, "missing_authorization", "Authorization header is required")
  }

  const bearer = /^Bearer\s+(.+)$/i.exec(authHeader.trim())
  if (!bearer) {
    return deny(401, "missing_authorization", "Authorization header must be a Bearer token")
  }

  const token = bearer[1].trim()
  const claims = decodeJwtPayload(token)
  if (!claims) {
    return deny(401, "invalid_token", "Bearer token is not a decodable JWT")
  }

  // THE line that closes the finding. The public anon key carries
  // role "anon"; service_role is a server-side secret and is not a caller
  // identity for a browser-originated dispatch either.
  if (claims.role !== "authenticated") {
    return deny(
      401,
      "not_authenticated",
      "Workflow dispatch requires a signed-in admin session",
    )
  }

  let user: { id: string } | null = null
  try {
    user = await resolveUser(token)
  } catch {
    user = null
  }
  if (!user) {
    return deny(401, "invalid_token", "Bearer token does not resolve to a user")
  }

  // Both admins hold verified TOTP factors (auth.mfa_factors), so this locks
  // nobody out. A missing aal claim is treated as not-aal2 — never as a pass.
  if (claims.aal !== "aal2") {
    return deny(
      403,
      "mfa_required",
      "Workflow dispatch requires a session that has completed MFA (aal2)",
    )
  }

  return { ok: true, userId: user.id }
}
