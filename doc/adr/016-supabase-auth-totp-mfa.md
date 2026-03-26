# ADR-016: Supabase Auth with TOTP MFA for Admin Access

**Status:** Accepted
**Date:** 2026-03-26 (M9)
**Supersedes:** [ADR-004](004-single-admin-account.md) (Single Admin Account for POC)

## Context

ADR-004 established a client-side password gate for admin access during POC and M8. The password is passed as an HTML attribute on the `<spws-ranklist>` web component and compared in JavaScript — no server-side verification occurs.

**Security audit (2026-03-26) revealed a critical vulnerability:**

1. The `admin-password` attribute is visible in the DOM via browser DevTools.
2. All `SECURITY DEFINER` write functions (`fn_import_scoring_config`, `fn_calc_tournament_scores`, etc.) are callable by the `anon` role because PostgreSQL defaults to `GRANT EXECUTE TO PUBLIC` and no `REVOKE` was applied.
3. The Supabase anon API key is public (embedded in the JS bundle by design).
4. **Result:** Any user can call write RPCs directly from the browser console, bypassing the client-side gate entirely. This allows corruption of scoring configuration, which would obliterate the ranking calculation.

The M8 admin UI (scoring config editor, future CRUD screens) makes this a live risk — the write surface is now exposed in production.

## Decision

Replace the client-side password gate with **Supabase Auth (email + password) plus TOTP MFA (two-factor authentication)**. This is a built-in, free-tier feature of Supabase GoTrue.

### Authentication Flow

1. **Admin visits `?admin=1`** → sign-in modal appears (email + password)
2. **First login only:** MFA enrollment screen (scan QR code with authenticator app, confirm with 6-digit code)
3. **Every login:** After email+password, TOTP challenge screen (enter 6-digit code from authenticator app)
4. **Success:** Supabase issues a full `authenticated` JWT → admin UI unlocks

### Session Management

- **JWT expiry:** 1 hour (Supabase dashboard setting: `JWT_EXP = 3600`)
- **Client-side inactivity timer:** 59 minutes — fires `signOut()` before JWT expires
- **No refresh token logic** — the 59-min timeout always fires first, keeping implementation simple
- **"Wyloguj" button:** calls `supabase.auth.signOut()` → JWT destroyed → sign-in modal reappears

### Multi-Admin Support

- Each admin has their own Supabase Auth account (email + password + independent TOTP enrollment)
- Created via Supabase Dashboard → Auth → Users
- All `authenticated` users have admin privileges (no role table needed — only admins ever sign in; public visitors use the `anon` key)
- Supabase free tier: 50,000 monthly active users — effectively unlimited

### Server-Side Enforcement (SQL Migration)

```sql
-- Revoke write functions from anon and PUBLIC
REVOKE EXECUTE ON FUNCTION fn_import_scoring_config(JSONB) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_calc_tournament_scores(INT) FROM anon, PUBLIC;
-- (same for all other write functions)

-- Grant only to authenticated role
GRANT EXECUTE ON FUNCTION fn_import_scoring_config(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_calc_tournament_scores(INT) TO authenticated;
```

PostgREST checks the JWT on every request. Without a valid `authenticated` JWT, write RPCs return `permission denied`.

### Admin Account Setup (Step-by-Step)

**Prerequisites:** Access to the Supabase project dashboard (CERT and PROD).

1. **Open Supabase Dashboard** → select the target project (CERT or PROD)
2. **Auth → Settings → General:** Verify JWT expiry is 3600 seconds (1 hour)
3. **Auth → Settings → MFA:** Enable TOTP as a factor type
4. **Auth → Users → Add User:**
   - Email: the admin's real email (e.g., `jan.kowalski@spws.pl`)
   - Password: strong, unique password (admin chooses their own)
   - Auto-confirm: Yes (skip email verification — the admin list is curated manually)
5. **Repeat step 4** for each additional admin
6. **Run the SQL migration** to REVOKE write functions from `anon`/`PUBLIC` and GRANT to `authenticated`
7. **First admin login:** Admin visits `?admin=1` → enters email + password → sees MFA enrollment screen → scans QR code with authenticator app (Google Authenticator, Authy, 1Password, etc.) → enters 6-digit confirmation code → MFA activated
8. **Subsequent logins:** Email + password → 6-digit TOTP code → admin session active

**The email used for login is the email entered in step 4.** Each admin uses their own email address. There is no shared account.

### Supabase JS SDK Calls

```typescript
// Step 1: Sign in
const { data, error } = await supabase.auth.signInWithPassword({ email, password })

// Step 2: Check MFA enrollment
const factors = await supabase.auth.mfa.listFactors()
if (factors.data.totp.length === 0) {
  // First time: enroll
  const { data: enroll } = await supabase.auth.mfa.enroll({ factorType: 'totp' })
  // enroll.totp.qr_code → display QR, enroll.totp.secret → manual entry fallback
  // After user enters confirmation code:
  await supabase.auth.mfa.challengeAndVerify({ factorId: enroll.id, code: userCode })
} else {
  // Returning user: challenge
  const factor = factors.data.totp[0]
  const { data: challenge } = await supabase.auth.mfa.challenge({ factorId: factor.id })
  await supabase.auth.mfa.verify({ factorId: factor.id, challengeId: challenge.id, code: userCode })
}

// Step 3: Sign out (on inactivity or manual logout)
await supabase.auth.signOut()
```

## Alternatives Considered

| Option | Pros | Cons | Why rejected |
|--------|------|------|--------------|
| **Keep ADR-004 + REVOKE only** | Minimal code change (1 SQL migration) | Still single shared password, no 2FA, password in DOM | Doesn't fix the root authentication problem |
| **Supabase Auth without MFA** | Simpler than full MFA | Single factor (password only) vulnerable to credential theft | MFA is free and adds significant security for minimal complexity |
| **External auth provider (Auth0, Clerk)** | Feature-rich | Additional vendor dependency, cost, integration complexity | Supabase Auth is already running (GoTrue container), free, and sufficient |
| **Custom JWT + bcrypt** | Full control | Significant implementation effort, security responsibility shifts to us | Supabase Auth is battle-tested; no reason to build custom |

## Consequences

### Positive

- **Write functions are server-enforced** — `anon` role cannot call them regardless of client-side state
- **Two-factor authentication** — even if password is compromised, attacker needs the authenticator app
- **Multi-admin support** — each admin has independent credentials and MFA enrollment
- **No secrets in client bundle** — `admin-password` attribute removed from web component
- **Free tier** — Supabase Auth + TOTP MFA is included in the free plan (50k MAU)
- **Simple session model** — 59-min timeout, no refresh logic, single-use JWT

### Negative

- **Dashboard dependency** — admin users must be created in Supabase Dashboard (no self-registration)
- **MFA enrollment UX** — first login requires authenticator app setup (one-time cost)
- **Existing tests (8.48–8.54) must be rewritten** — `AdminPasswordModal` replaced by sign-in + MFA modals

### Migration from ADR-004

1. Delete `AdminPasswordModal.svelte`
2. Remove `admin-password` prop from `<spws-ranklist>` web component
3. Add `AdminSignInModal.svelte`, `AdminMfaEnrollModal.svelte`, `AdminMfaChallengeModal.svelte`
4. Add `src/lib/admin-auth.svelte.ts` (auth state + MFA flow logic)
5. SQL migration: REVOKE write functions from `anon`/`PUBLIC`, GRANT to `authenticated`
6. Update ADR-004 status to "Superseded by ADR-016"
7. Rewrite tests 8.48–8.54 for new auth flow

### Mockup

See [doc/mockups/m9_auth_mfa_flow.html](../mockups/m9_auth_mfa_flow.html) for the visual design of all 4 screens (sign-in, MFA enrollment, TOTP challenge, authenticated admin session).
