# ADR-004: Single Admin Account for POC

**Status:** Accepted
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
