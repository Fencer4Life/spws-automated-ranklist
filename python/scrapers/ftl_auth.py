"""FencingTimeLive (FTL) authentication helper.

Since 2026-04, fencingtimelive.com requires an authenticated session for
/events/results/{id} and /events/results/data/{id}. Unauthenticated requests
302-redirect to /account/login. This helper performs the login flow and
returns an httpx.Client with the authed connect.sid cookie set.

Login flow (verified 2026-05-31 against the live login page + /js/login.*.js):
  1. GET /account/login → fetch HTML, extract <meta name="csrf_token"> + cookies
  2. POST /login with form body {username, password} and x-csrf-token header
     (form-encoded, exactly as the browser's $.post does; `username` = email)
  3. Response 200 (body = returnUrl) sets the authed connect.sid cookie

Two properties of the FTL session, established empirically (2026-05-31):

* The `connect.sid` cookie is **host-only to www.fencingtimelive.com** (no
  Domain attribute). Event/result URLs stored in the DB use the apex host
  `fencingtimelive.com`; httpx will not send a www-scoped cookie to the apex,
  so the fetch silently 302s back to /account/login and the scraper sees an
  empty page. `normalize_ftl_url` / the request hook rewrite apex → www so the
  cookie always applies. This was the root cause of "Discovered 0 URLs".

* The session is **not rolling**: `Expires` is a fixed login + 10 days and is
  NOT refreshed by authenticated requests. So we log in once, cache the cookie
  jar + its expiry, and reuse it until shortly before expiry — re-logging in
  only when expired or when a fetch bounces to the login page.

Credentials come from FTL_USERNAME (the account email) and FTL_PASSWORD.
"""

from __future__ import annotations

import datetime as dt
import os
import re
from contextlib import contextmanager
from typing import Iterator

import httpx


FTL_HOST = "www.fencingtimelive.com"
FTL_APEX_HOST = "fencingtimelive.com"
FTL_BASE = f"https://{FTL_HOST}"
FTL_LOGIN_PAGE = f"{FTL_BASE}/account/login"
FTL_LOGIN_POST = f"{FTL_BASE}/login"

_CSRF_RE = re.compile(r'<meta\s+name="csrf_token"\s+content="([^"]+)"')

# Re-login this far before the cookie's advertised expiry, so a long-running
# job never has a session lapse mid-run.
_SESSION_MARGIN = dt.timedelta(hours=12)

# Paths that ARE the login flow — a redirect to /account/login from one of
# these is handled explicitly below, not by the generic resource-fetch guard.
_LOGIN_FLOW_PATHS = ("/account/login", "/login", "/logout")

# Process-global session cache: (cookies, expiry). Populated on first login,
# reused by later get_authed_ftl_client() calls in the same process.
_cached_cookies: httpx.Cookies | None = None
_cached_expiry: dt.datetime | None = None


class FtlAuthError(RuntimeError):
    """Raised when the FTL login flow fails for any reason."""


def reset_session_cache() -> None:
    """Drop any cached session (forces the next call to log in). Used by tests
    and available to callers that want to force a fresh login."""
    global _cached_cookies, _cached_expiry
    _cached_cookies = None
    _cached_expiry = None


def normalize_ftl_url(url: str) -> str:
    """Rewrite the apex host ``fencingtimelive.com`` → ``www.fencingtimelive.com``.

    The session cookie is host-only on www; without this rewrite an apex URL is
    fetched without the cookie and 302s to the login page. Non-FTL and
    already-www URLs are returned unchanged.
    """
    u = httpx.URL(url)
    if u.host == FTL_APEX_HOST:
        return str(u.copy_with(host=FTL_HOST))
    return url


def _extract_csrf_token(html: str) -> str:
    m = _CSRF_RE.search(html)
    if not m:
        raise FtlAuthError("Could not find csrf_token meta tag in /account/login HTML")
    return m.group(1)


def _normalize_request_host(request: httpx.Request) -> None:
    """httpx request hook: rewrite apex → www before the request is sent so the
    host-only session cookie is attached and no login redirect occurs."""
    if request.url.host == FTL_APEX_HOST:
        request.url = request.url.copy_with(host=FTL_HOST)
        request.headers["host"] = FTL_HOST


def _raise_on_login_redirect(response: httpx.Response) -> None:
    """httpx response hook: if a *resource* request is redirected to the login
    page, the session is no longer valid — raise instead of letting the caller
    silently parse a login page (the old silent 'Discovered 0' failure)."""
    if response.status_code in (301, 302, 303, 307, 308):
        location = response.headers.get("location", "")
        if "/account/login" in location and response.request.url.path not in _LOGIN_FLOW_PATHS:
            raise FtlAuthError(
                f"FTL session not authenticated — request to {response.request.url} "
                "was redirected to the login page. The session likely expired; "
                "a fresh login is required."
            )


def _connect_sid_expiry(client: httpx.Client) -> dt.datetime | None:
    for ck in client.cookies.jar:
        if ck.name == "connect.sid" and ck.expires:
            return dt.datetime.fromtimestamp(ck.expires, dt.timezone.utc)
    return None


def _perform_login(client: httpx.Client, username: str, password: str) -> None:
    """Run GET /account/login → POST /login and verify a session was established."""
    login_page = client.get(FTL_LOGIN_PAGE)
    if login_page.status_code != 200:
        raise FtlAuthError(
            f"GET {FTL_LOGIN_PAGE} returned {login_page.status_code}: "
            f"{login_page.text[:200]}"
        )
    csrf = _extract_csrf_token(login_page.text)

    # Form-encoded body + x-csrf-token header, mirroring the browser's $.post.
    # `username` carries the account email (the live #loginEmail field).
    login_resp = client.post(
        FTL_LOGIN_POST,
        data={"username": username, "password": password},
        headers={"x-csrf-token": csrf},
    )
    if login_resp.status_code != 200:
        raise FtlAuthError(
            f"POST {FTL_LOGIN_POST} returned {login_resp.status_code}: "
            f"{login_resp.text[:200]}"
        )
    # A successful login redirects away from /account/login. If the final URL
    # after following redirects is /account/login, the credentials were rejected
    # (wrong password, account locked, or account suspended by FTL).
    if "/account/login" in str(login_resp.url).lower():
        raise FtlAuthError(
            "FTL credentials rejected — wrong password, account locked, or "
            "account suspended. Update FTL_USERNAME / FTL_PASSWORD in .env "
            "and in GitHub repository secrets."
        )


@contextmanager
def get_authed_ftl_client(
    timeout: float = 15.0, *, force_login: bool = False
) -> Iterator[httpx.Client]:
    """Yield an httpx.Client authenticated to fencingtimelive.com.

    Reads FTL_USERNAME (email) and FTL_PASSWORD from environment. On the first
    call (or once the cached session is within ``_SESSION_MARGIN`` of expiry, or
    ``force_login=True``) it performs the GET /account/login → POST /login
    handshake and caches the cookie jar + expiry. Subsequent calls reuse the
    cached session and skip login. The yielded client:

    * rewrites apex → www on every request (so the host-only cookie applies), and
    * raises ``FtlAuthError`` if any resource fetch is redirected to the login
      page (so an expired session fails loudly rather than silently).
    """
    global _cached_cookies, _cached_expiry

    username = os.environ.get("FTL_USERNAME")
    password = os.environ.get("FTL_PASSWORD")
    if not username or not password:
        raise FtlAuthError(
            "FTL_USERNAME and FTL_PASSWORD must be set in environment "
            "(see .env for LOCAL, GitHub Secrets for CI)"
        )
    username = username.strip()

    client = httpx.Client(
        timeout=timeout,
        follow_redirects=True,
        event_hooks={
            "request": [_normalize_request_host],
            "response": [_raise_on_login_redirect],
        },
    )
    try:
        now = dt.datetime.now(dt.timezone.utc)
        cache_valid = (
            not force_login
            and _cached_cookies is not None
            and _cached_expiry is not None
            and now < _cached_expiry - _SESSION_MARGIN
        )
        if cache_valid:
            client.cookies.update(_cached_cookies)
        else:
            _perform_login(client, username, password)
            # Cache a copy of the jar + the session's hard expiry. If the server
            # didn't advertise an expiry, don't cache (treat as login-only).
            expiry = _connect_sid_expiry(client)
            if expiry is not None:
                _cached_cookies = httpx.Cookies(client.cookies)
                _cached_expiry = expiry
            else:
                reset_session_cache()

        yield client
    finally:
        client.close()
