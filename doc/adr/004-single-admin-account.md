# ADR-004: Single Admin Account for POC

**Status:** Superseded by [ADR-016](016-supabase-auth-totp-mfa.md)
**Date:** 2025-03-01 (M1)

## Context

The system needs an admin role for season setup, fencer management, match candidate review, and result corrections. The question was whether to implement multi-user admin with role-based access control.

## Decision

During POC (Phase 1), use a **single admin account** via Supabase Auth. The Supabase Dashboard serves as the admin UI for season/config management.

RLS policies define three roles:
- `anon` — public SELECT on public tables and ranking views
- `authenticated` — full CRUD on all tables
- `service_role` — bypasses RLS (GitHub Actions pipeline)

## Consequences

- Simple: no custom claims, no role hierarchy, no permission matrix
- The Supabase Dashboard is the admin UI — no custom admin frontend needed for POC
- `tbl_match_candidate` and `tbl_audit_log` are not publicly readable (admin-only)
- If multi-admin support is needed later, Supabase supports custom claims and role-based policies — the RLS foundation is already in place
- ~~**Extended to MVP (ADR-013):** The client-side password gate pattern (no server-side auth for admin actions) continues for M8-M9. Admin CRUD UI uses the same single-account model. Full Supabase Auth with multi-user support deferred to Phase 3~~
- **Superseded (2026-03-26):** Security audit revealed `anon` role can call SECURITY DEFINER write functions (no REVOKE applied). Client-side password gate provides no real protection. Replaced by [ADR-016](016-supabase-auth-totp-mfa.md): Supabase Auth + TOTP MFA with server-enforced REVOKE on write RPCs.
