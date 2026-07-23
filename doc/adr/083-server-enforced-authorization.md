# ADR-083: Server-Enforced Authorization — Deny-by-Default Grants and a Standing Posture Gate

**Status:** Accepted
**Date:** 2026-07-23
**Amends:** [ADR-016](016-supabase-auth-totp-mfa.md) (Supabase Auth with TOTP MFA for Admin Access) — extends its server-side enforcement; does not supersede it.
**Relates to:** [ADR-004](004-single-admin-account.md), [ADR-041](041-edge-function-dispatch.md) (edge-function dispatch), [ADR-071](071-mdm-dedup-sweep.md) / [ADR-072](072-cdc-recompute-debounce.md) (the recompute queue), [ADR-078](078-gdpr-data-handling.md) (GDPR), [ADR-079](079-event-self-registration-identity.md) (public self-registration)
**Source:** `supabase/migrations/20260723000001_adr083_deny_by_default_grants.sql`, `supabase/tests/52_security_posture.sql`, `scripts/check-security-posture.sh`, `supabase/functions/dispatch-workflow/{index,authorize}.ts`, `.github/workflows/release.yml`

## Context

ADR-016 §Context already recorded this bug class, in March 2026:

> All `SECURITY DEFINER` write functions … are callable by the `anon` role because PostgreSQL defaults to `GRANT EXECUTE TO PUBLIC` and no `REVOKE` was applied.

Migration `20260327000001_revoke_write_functions.sql` fixed it for the two functions that existed at the time. **The fix did not hold, and the reason is the whole point of this ADR.**

`ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public` grants `anon` and `authenticated` every privilege on every **new** table, function and sequence. Migrations run as `postgres`, so from March onward every object the project created arrived world-writable, one object at a time, silently. Nobody made a mistake. No convention or code review could have caught it, because there was no moment of carelessness to catch — the schema re-opened the hole on its own each time it grew.

Verified live against **both CERT and PROD** on 2026-07-23:

| Finding | Evidence |
| --- | --- |
| 6 `public` tables with RLS disabled, `anon` holding full DML + `TRUNCATE` | An anon `INSERT` reached the not-null constraint — SQLSTATE `23502`, a **data** error — not `42501` permission denied. The write was permitted. |
| `anon` held INSERT/UPDATE/DELETE/TRUNCATE on **all 16** tables | On the 10 RLS-enabled tables, RLS was the *only* control. `TRUNCATE` is not filtered by RLS at all, so that grant defeated row level security outright. |
| `vw_fencer_aliases` is owner-rights, serving **365 fencer identities** to `anon` on PROD | `owner=postgres`, `reloptions=NONE`. RLS beneath an owner-rights view does nothing; grants are the only control. An ADR-078 (GDPR) surface. |
| **13** write-capable RPCs `anon`-EXECUTEable, 3 of them `SECURITY DEFINER` | Includes `fn_merge_fencers` (deletes a fencer, re-points its results — ADR-071) and `fn_refresh_active_season` (`DEFINER`, moves the system's active season). |
| `dispatch-workflow` never checked its caller | `verify_jwt = true` reads like an authorization control and is not one: the public anon key is a valid signed JWT that ships in the frontend bundle. It returned `400 invalid_workflow` — i.e. it reached the allowlist — where it should have been rejected at the door. |
| The release gate is bypassable | `if: github.event_name == 'workflow_dispatch' \|\| …` — the first clause is unconditional, so a hand-triggered release skips CI and therefore skips pgTAP. |

Two aggravating factors are worth recording, because they explain the four-month duration rather than the cause:

- **LOCAL lies about this problem.** The staging tables are empty on LOCAL, which makes the finding look trivial. CERT is the populated staging environment; PROD's `tbl_recompute_queue` held real rows. Severity must never be reasoned about from LOCAL.
- **Detection existed; delivery failed.** The Supabase advisory fired weekly from 6 May. Every message but the last went unread.

## Decision

### 1. Pipeline and staging objects are `service_role` only

The six pipeline/staging tables (`tbl_result_draft`, `tbl_tournament_draft`, `tbl_event_ingest_history`, `tbl_tournament_ingest_history`, `tbl_recompute_queue`, `tbl_recompute_watermark`) get RLS enabled with **no policy**, and all grants revoked from `anon` and `authenticated`.

RLS with zero policies denies everyone except roles that bypass it, and `service_role` bypasses RLS inherently — which is how the entire Python pipeline reaches these tables. No policy is the correct amount of policy here.

### 2. `anon` holds no write privilege on any table

On the other ten tables, `anon` retains `SELECT` (the public ranklist and calendar read six of them directly) and loses `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES` and `TRIGGER`. Defence in depth: the RLS policy becomes the second line rather than the only one.

### 3. New objects are ungranted by default

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL     ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL     ON SEQUENCES FROM anon, authenticated;
```

All three object types are required — `anon` was granted on tables, functions **and** sequences. `FOR ROLE postgres` is what makes it bite; without the qualifier it targets the executing role's own defaults and silently achieves nothing.

Blast radius on existing objects is **zero**: `ALTER DEFAULT PRIVILEGES` affects only objects created after it runs. That is why this ships safely alongside the rest.

**Consequence, by design:** a new table is unreachable from the frontend until someone writes an explicit `GRANT SELECT … TO anon`. That is the point. A migration author must now state their intent.

### 4. The anon-executable surface is an explicit allowlist

Nineteen functions remain `anon`-EXECUTEable, pinned by pgTAP 52.7 as a set **equality**. A deny-list was rejected: it would have caught none of these findings, because every offending object postdates any list that could have been written.

The allowlist deliberately retains `fn_create_registration` and `fn_match_registration_fencer`. `register.html` is served to anonymous visitors and those two are the entire server surface of the ADR-079 / FR-122 self-registration flow; `fn_create_registration` is `SECURITY DEFINER` precisely so `anon` can register without holding INSERT on `tbl_registration`, asserted from the other side by pgTAP 49.13/49.14.

### 5. The dispatcher authenticates its caller and requires `aal2`

`dispatch-workflow` now rejects any caller that is not a signed-in admin whose session has completed TOTP. The decision logic lives in `authorize.ts` — free of Deno and network dependencies, so it is unit-tested (FR-132.1–132.9) rather than only reachable through a deployed function. Order is deliberate: the role check precedes the network round-trip, so the common hostile case (the public anon key) costs nothing; the `aal2` check comes last so a genuine admin who has not finished TOTP gets `403 mfa_required`, clearly distinct from `401`.

### 6. The posture is verified against the real environment, in the deploy job

`scripts/check-security-posture.sh <ref>` asserts the posture against a **remote** database via the Management API and runs inside `deploy-cert` and `deploy-prod`. Two reasons it is not left to CI's pgTAP:

- The build job is skippable by a manual `workflow_dispatch`, which makes any CI-only guard optional in practice.
- pgTAP proves what LOCAL looks like after replaying migrations. This proves what CERT and PROD actually look like — the thing that drifted for four months while LOCAL looked fine.

Failure alerts to **Telegram**, the channel this project reacts to. Not e-mail: e-mail is what failed for eleven weeks.

## Alternatives Considered

- **Option C — move pipeline tables to a separate `pipeline` schema.** *Rejected for now.* The pipeline is a PostgREST client (`db_connector.py:683` uses `create_client`; `draft_store.py:13` forbids psycopg at runtime), so the schema would have to be exposed to PostgREST anyway and security would fall back to grants — the same place this decision already puts it, for a fraction of the risk and churn. Revisit if the pipeline ever gains a direct Postgres connection.

- **`aal2` on the RLS write policies.** *Rejected.* All eight admin fencer-mutation RPCs are `SECURITY DEFINER` and bypass RLS entirely, so an `aal2` policy predicate would protect only three direct-write call sites (`api.ts:279`, `:296`, `:528` — season and event status) while adding real lockout surface. **Follow-up:** `aal2` checks inside the `DEFINER` RPCs, where they would actually bite.

- **An explicit `tbl_admin` allowlist replacing bare `authenticated`.** *Deferred.* Strictly better — `authenticated` currently means "anyone who holds an account" — but it rewrites all 17 policies and belongs in its own change, not an incident response. Closing signup (done 2026-07-23) bounds the risk in the meantime.

- **Recreating `vw_fencer_aliases` with `security_invoker = true`.** *Deferred.* Correct in principle, but it couples the admin UI to the draft tables' RLS and would force an otherwise unnecessary `authenticated` read policy onto all six pipeline tables. Grants achieve the same outcome here with less blast radius.

- **A deny-list instead of an allowlist** in the pgTAP guard. *Rejected* — see §4.

- **Revoking `anon`'s `SELECT` as well as its writes.** *Rejected.* The public ranklist reads six tables directly. Removing read access is a separate, larger change with real breakage risk and no bearing on the findings, all of which concern writes and one view.

- **Also revoking `supabase_admin`'s default privileges.** *Rejected as unreachable.* `pg_default_acl` carries an identical set of `anon` defaults for `supabase_admin`. It is not reachable from the migration path — nothing in this project creates objects as `supabase_admin` — and on hosted Supabase the `postgres` role cannot alter another role's defaults, so attempting it would fail at deploy time. Recorded as a residual rather than attempted-and-failed.

## Consequences

**Positive**

- Every proven exposure is closed, and the generator that produced them is removed.
- The posture is machine-verified on every release against the real environments, and a regression pages a human on a channel they read.
- `fn_merge_fencers` and twelve other write RPCs are no longer reachable by an anonymous browser.

**Negative / accepted**

- A new public-facing table needs an explicit `GRANT SELECT … TO anon`. Intended friction; documented in `doc/handbook/reference/security-posture.html`.
- The allowlist in `check-security-posture.sh` duplicates pgTAP 52.7 and must be kept in sync. The test file is the source of truth; the script carries a pointer to it.
- **Local development cannot dispatch workflows through the Edge Function.** `admin-auth.svelte.ts:51` skips MFA on localhost, so a LOCAL session stays `aal1` and the dispatcher answers `403 mfa_required`. Accepted: dispatch targets real GitHub Actions, so it is not a LOCAL-appropriate operation anyway.
- Any admin holding a live `aal1` session must re-authenticate before dispatch buttons work.
- `GH_DISPATCH_PAT` must be treated as exposed for as long as the function was deployed, and rotated after the caller check ships.

**Residual risk**

- `authenticated` still means "any account". Bounded by closed signup; the `tbl_admin` follow-up above is the durable fix.
- `supabase_admin`'s default privileges remain, as explained above.
