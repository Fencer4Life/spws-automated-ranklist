---
name: cloud-db-ops
description: "MANDATORY before any read or write against the CERT or PROD Supabase database in this repo (SPWS Automated Ranklist System) — inspecting a row, counting registrations, deleting test data, checking what an environment actually contains. Use scripts/cloud-sql.sh; never improvise curl against the Management API. Also governs writing test data to a live environment at all. Triggers on: query PROD, check CERT, what's in the database, delete a row, clean up a test entry, verify something landed, inspect tbl_*, 'is it on PROD or CERT', registration count, before creating any test record on a cloud environment."
---

# Cloud DB operations — CERT and PROD

LOCAL is reachable with `psql` and is disposable. CERT and PROD are neither.
Every query against them goes through the Supabase Management API, which needs
a credential this session does not hold in a usable form by default. That
combination produced a 40-minute failure on 2026-08-17 that this skill exists
to prevent recurring.

## The one rule that matters most

**Never write test data to CERT or PROD until you have already proven, in the
same session, that you can delete it.**

Run the delete path against a throwaway row *before* you need it, or don't
create the row. On 2026-08-17 a test registration was written to PROD to verify
the environment routing — a genuinely necessary check — and then could not be
removed for the rest of the session. It sat on the public entry list of a live
event while the user was trying to share the registration link. Verifying a
write is the right instinct; verifying it without a proven exit is not.

If you cannot establish a delete path, say so **before** writing, and let the
user decide whether to create the row themselves.

## How to run SQL

```bash
scripts/cloud-sql.sh <cert|prod> "SELECT ..."
scripts/cloud-sql.sh prod < query.sql
```

Non-SELECT statements refuse to run without `CLOUD_SQL_CONFIRM=yes`. That gate
is deliberate — keep it, and read the statement it echoes before re-running.

Do **not** hand-roll `curl https://api.supabase.com/...` with an inline
`export TOKEN=$(grep ... .env)`. Apart from being unreviewable, the permission
classifier blocks that command shape every time, and reshaping it until
something slips through is not an acceptable response to a denial. The script
exists so the credential handling lives in a reviewed file instead of in an
ad-hoc command.

## The phantom 401

`HTTP 401 Unauthorized` from the Management API does **not** mean the token is
expired. It means the token being sent is wrong — which is usually not the one
you think you are sending.

`cloud-sql.sh` reads `.env` **in preference to** the shell environment,
inverting the usual convention on purpose. A stale `SUPABASE_ACCESS_TOKEN`
exported from a shell profile shadows the good value in `.env` and produces a
bare 401, indistinguishable from expiry. That misdiagnosis cost the entire
detour on 2026-08-17: the user was told their token was dead and asked to mint
a replacement they did not need. They were right; the script was wrong.

Before concluding a credential is dead:

- Re-run with `env -u SUPABASE_ACCESS_TOKEN` to force the `.env` value.
- Check whether the shell profile exports one:
  `grep -rn SUPABASE_ACCESS_TOKEN ~/.zshrc ~/.zprofile ~/.bashrc`.
- Remember `apply-migrations.sh` and `schema-fingerprint.sh` read that variable
  from the environment **only**, with no `.env` fallback — so a stale export
  breaks them locally while CI, which injects the secret, stays green.

Never tell the user a credential is expired on the strength of one 401.

## What cannot be recovered

- **GitHub Secrets are write-only.** The CI token cannot be read back by
  anyone, including the repo owner. Do not suggest copying it out.
- **Supabase reveals a personal access token once, at creation.** The dashboard
  list shows a masked form (`sbp_2f1c••••848c`) forever after; that string is
  not usable.
- **Never ask the user to paste a token into the conversation.** It goes into
  `.env` (gitignored), and the script reads it from there.

## Scope — data, not schema

This path is for **inspection and data maintenance**. Schema changes belong in
`supabase/migrations/` and must flow through CI so CERT and PROD converge and
the fingerprint gate stays meaningful. Applying DDL by hand desynchronises the
environments and silently invalidates the release pipeline's central check.

If you find yourself reaching for `ALTER TABLE` here, stop and write a
migration.

## Writes: scope them, prove them

- `SELECT` the rows the predicate matches **before** the `DELETE`/`UPDATE`, and
  show the user that result. Live data may have changed since you last looked —
  on 2026-08-17 a real registration appeared between the test write and the
  cleanup, and an unscoped `DELETE FROM tbl_registration` would have destroyed
  it.
- Use `RETURNING` so the response proves exactly what changed.
- Re-verify afterwards through the public projection (for registrations,
  `vw_registration_entry_list`) rather than trusting the write's own output —
  that is what the user actually sees.

## What the anon key can and cannot do

The published anon key on the deployed page is fine for **reading** public
views (`vw_calendar`, `vw_registration_entry_list`) and is the fastest way to
confirm what an environment holds, including from a plain `curl`. It cannot
write: ADR-083's deny-by-default grants mean a `DELETE` returns
`42501 permission denied`. That is correct behaviour, not an obstacle to route
around.

## Which environment am I on?

Deployed pages carry their own credentials, and CERT and PROD are one letter
apart in a subdomain. Confirm the target before acting, and quote it back to
the user in the same message as the result. `RegistrationElement` resolves
`(certUrl || prodUrl)`, so a page with both populated silently talks to CERT —
the exact defect fixed on 2026-08-17.
