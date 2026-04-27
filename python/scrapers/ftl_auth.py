"""FencingTimeLive (FTL) authentication helper.

Since 2026-04, fencingtimelive.com requires an authenticated session for
/events/results/{id} and /events/results/data/{id}. Unauthenticated requests
302-redirect to /account/login. This helper performs the login flow and
returns an httpx.Client with the authed connect.sid cookie set.

Login flow:
  1. GET /account/login → fetch HTML, extract <meta name="csrf_token"> + cookies
  2. POST /login with form body {username, password} and x-csrf-token header
  3. Response 200 sets the authed connect.sid; subsequent GETs are authorized

Credentials come from FTL_USERNAME and FTL_PASSWORD env vars.
"""

from __future__ import annotations

import os
import re
from contextlib import contextmanager
from typing import Iterator

import httpx


FTL_BASE = "https://www.fencingtimelive.com"
FTL_LOGIN_PAGE = f"{FTL_BASE}/account/login"
FTL_LOGIN_POST = f"{FTL_BASE}/login"

_CSRF_RE = re.compile(r'<meta\s+name="csrf_token"\s+content="([^"]+)"')


class FtlAuthError(RuntimeError):
    """Raised when the FTL login flow fails for any reason."""


def _extract_csrf_token(html: str) -> str:
    m = _CSRF_RE.search(html)
    if not m:
        raise FtlAuthError("Could not find csrf_token meta tag in /account/login HTML")
    return m.group(1)


@contextmanager
def get_authed_ftl_client(timeout: float = 15.0) -> Iterator[httpx.Client]:
    """Yield an httpx.Client logged in to fencingtimelive.com.

    Reads FTL_USERNAME and FTL_PASSWORD from environment. Performs the
    GET /account/login → POST /login dance, then yields the client with
    the authed connect.sid cookie attached. The client follows redirects
    by default so callers can fetch result pages directly.
    """
    username = os.environ.get("FTL_USERNAME")
    password = os.environ.get("FTL_PASSWORD")
    if not username or not password:
        raise FtlAuthError(
            "FTL_USERNAME and FTL_PASSWORD must be set in environment "
            "(see .env for LOCAL, GitHub Secrets for CI)"
        )

    client = httpx.Client(timeout=timeout, follow_redirects=True)
    try:
        login_page = client.get(FTL_LOGIN_PAGE)
        if login_page.status_code != 200:
            raise FtlAuthError(
                f"GET {FTL_LOGIN_PAGE} returned {login_page.status_code}: "
                f"{login_page.text[:200]}"
            )
        csrf = _extract_csrf_token(login_page.text)

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

        yield client
    finally:
        client.close()
