# ADR-068: FTL `www`-host normalization + cached non-rolling session

**Status:** Accepted (2026-05-31)

## Context

The "Populate Tournament URLs" workflow silently produced "Discovered 0 /
Updated 0" for FTL events (e.g. `PPW4-2025-2026`) while reporting a GitHub
Actions **success**. Investigation (2026-05-31) established:

1. FTL requires an authenticated session for `eventSchedule`/`results` pages
   (unauthenticated requests `302` to `/account/login`).
2. Login itself works: `POST www/login`, **form-encoded** body
   `{username:<email>, password}`, header `x-csrf-token` read from
   `<meta name="csrf_token">`; success = `200` with the returnUrl as body, sets
   the `connect.sid` cookie. (Confirmed against the live page and
   `/js/login.*.js` — the browser uses jQuery `$.post`, i.e. form-encoded.)
3. **Root cause:** `connect.sid` is **host-only to `www.fencingtimelive.com`**
   (no `Domain` attribute). The DB stores event/result URLs on the **apex**
   host `fencingtimelive.com`, so httpx never sends the cookie → the fetch
   `302`s to the login page → `parse_event_schedule` finds 0 `/events/view/`
   links → "Discovered 0". Credentials, login mechanism, and parser were all
   correct.
4. The failure was **silent**: login succeeds, so neither the status check nor
   the post-login redirect check tripped; only the later *resource* fetch was
   redirected, and the parser treated the login page as "an event with no
   brackets".
5. The `connect.sid` cookie is **non-rolling**: `Expires = login + 10 days`,
   and is **not** refreshed by authenticated requests (verified empirically —
   the token value and expiry were byte-identical before/after authed GETs, and
   no `Set-Cookie` was re-issued on resource fetches).

## Decision

1. **Normalize host apex → `www`** before every FTL fetch, via
   `normalize_ftl_url()` applied at the discovery call sites
   (`populate_tournament_urls.discover_tournament_urls`,
   `scrape_ftl_event_urls.scrape_all`) **and** a request event-hook on the
   client yielded by `get_authed_ftl_client()` (belt-and-suspenders, so any
   future caller is covered automatically).
2. **Cache the session** (cookie jar + `connect.sid` expiry) process-globally.
   Reuse it across `get_authed_ftl_client()` calls and re-login only when
   within 12 h of expiry or when `force_login=True`. ("Log once, reuse the
   token" — matches FTL's session model.)
3. **Fail loudly:** a response event-hook raises `FtlAuthError` if a *resource*
   request is redirected to `/account/login` (login-flow paths excluded), so an
   expired/invalid session no longer masquerades as "0 results / success".

## Alternatives considered

- **Rotate FTL credentials** — rejected; the credentials were valid. Would not
  have fixed the host mismatch.
- **Send the cookie to both apex and `www`** — rejected; relies on apex
  behaviour and may still redirect. Host normalization is deterministic.
- **Switch login to a JSON body** — rejected; the browser uses form-encoded
  `$.post` (confirmed in `login.*.js`). The current format is already correct.
- **Persist the session cookie to disk/secret across processes** — deferred.
  The in-process cache covers multi-fetch runs (`scrape_all`, the ingest
  pipeline). Cross-dispatch reuse (one login per ~10 days across separate
  workflow runs) is a possible follow-up.

## Consequences

- Populate/scrape now discover URLs reliably; verified live against PPW4
  (28 brackets discovered vs 0 before the fix).
- Silent "success with 0 results" becomes a loud `FtlAuthError` (workflow fails
  + Telegram alert), surfacing genuine session expiry instead of hiding it.
- The session is reused within a run → fewer logins, lower lockout risk.
- New tests in `python/tests/test_ftl_auth.py` (3.20h–k): URL normalization,
  client host-rewrite, cached-session reuse, loud login-redirect. The file goes
  from 8 → 12 tests.
- Supersedes the earlier uncommitted partial fix (a post-login redirect check),
  which did not catch the resource-fetch redirect case.
- The DB continues to store apex URLs (admin-entered, ADR — URLs are
  admin-managed); normalization happens only at fetch time, so no data
  migration is required.
