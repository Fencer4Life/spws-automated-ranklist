"""Tests for FTL authentication helper (python/scrapers/ftl_auth.py).

Plan test IDs 3.20a–f: FTL login flow that bypasses the post-2026-04 auth wall.

FTL change: every /events/results/{id} and /events/results/data/{id} now
302-redirects to /account/login when called without an authed session cookie.
The helper performs login-and-return-client so callers can run authed GETs.
"""

from __future__ import annotations

import httpx
import pytest
import respx

_LOGIN_HTML = """<!doctype html>
<html><head>
  <meta name="csrf_token" content="ZnXUWtG6-JC90o7zR0EMV8iKxS96uTyo9TwI">
</head><body><form id="loginForm"></form></body></html>
"""


@pytest.fixture
def ftl_creds(monkeypatch):
    # Dummy credentials — real ones live in .env (gitignored) and GitHub Secrets.
    monkeypatch.setenv("FTL_USERNAME", "test@example.com")
    monkeypatch.setenv("FTL_PASSWORD", "test-password")


@pytest.fixture
def no_ftl_creds(monkeypatch):
    monkeypatch.delenv("FTL_USERNAME", raising=False)
    monkeypatch.delenv("FTL_PASSWORD", raising=False)


# ===========================================================================
# 3.20a — CSRF extraction from login page meta tag
# ===========================================================================
def test_extracts_csrf_from_meta_tag():
    """3.20a Login HTML → regex pulls the csrf_token meta value."""
    from python.scrapers.ftl_auth import _extract_csrf_token

    token = _extract_csrf_token(_LOGIN_HTML)
    assert token == "ZnXUWtG6-JC90o7zR0EMV8iKxS96uTyo9TwI"


def test_extracts_csrf_raises_on_missing_meta():
    """3.20a (defensive) Missing meta tag → FtlAuthError, not silent None."""
    from python.scrapers.ftl_auth import FtlAuthError, _extract_csrf_token

    with pytest.raises(FtlAuthError, match="csrf"):
        _extract_csrf_token("<html><body>no meta here</body></html>")


# ===========================================================================
# 3.20b — POST /login body contains username + password
# ===========================================================================
@respx.mock
def test_post_body_contains_username_password(ftl_creds):
    """3.20b Login POST sends form-encoded {username, password}."""
    from python.scrapers.ftl_auth import get_authed_ftl_client

    respx.get("https://www.fencingtimelive.com/account/login").mock(
        return_value=httpx.Response(
            200,
            html=_LOGIN_HTML,
            headers={"set-cookie": "connect.sid=anon-sid; Path=/"},
        )
    )
    login_route = respx.post("https://www.fencingtimelive.com/login").mock(
        return_value=httpx.Response(
            200,
            text="/",
            headers={"set-cookie": "connect.sid=AUTHED-SID; Path=/"},
        )
    )

    with get_authed_ftl_client():
        pass

    assert login_route.called
    posted = login_route.calls.last.request
    body = posted.content.decode()
    assert "username=test%40example.com" in body
    assert "password=test-password" in body


# ===========================================================================
# 3.20c — POST sends x-csrf-token header matching meta value
# ===========================================================================
@respx.mock
def test_post_sends_x_csrf_token_header(ftl_creds):
    """3.20c x-csrf-token header carries the meta-tag value."""
    from python.scrapers.ftl_auth import get_authed_ftl_client

    respx.get("https://www.fencingtimelive.com/account/login").mock(
        return_value=httpx.Response(200, html=_LOGIN_HTML)
    )
    login_route = respx.post("https://www.fencingtimelive.com/login").mock(
        return_value=httpx.Response(200, text="/")
    )

    with get_authed_ftl_client():
        pass

    headers = login_route.calls.last.request.headers
    assert headers.get("x-csrf-token") == "ZnXUWtG6-JC90o7zR0EMV8iKxS96uTyo9TwI"


# ===========================================================================
# 3.20d — Returned client carries authed connect.sid cookie
# ===========================================================================
@respx.mock
def test_returns_client_with_authed_cookies(ftl_creds):
    """3.20d After login, client.cookies has connect.sid set to authed value."""
    from python.scrapers.ftl_auth import get_authed_ftl_client

    respx.get("https://www.fencingtimelive.com/account/login").mock(
        return_value=httpx.Response(
            200,
            html=_LOGIN_HTML,
            headers=[("set-cookie", "connect.sid=anon-sid; Path=/; HttpOnly")],
        )
    )
    respx.post("https://www.fencingtimelive.com/login").mock(
        return_value=httpx.Response(
            200,
            text="/",
            headers=[("set-cookie", "connect.sid=AUTHED-SID; Path=/; HttpOnly")],
        )
    )

    with get_authed_ftl_client() as client:
        sid = client.cookies.get("connect.sid")
        assert sid == "AUTHED-SID"


# ===========================================================================
# 3.20e — Missing creds → FtlAuthError
# ===========================================================================
def test_raises_on_missing_creds(no_ftl_creds):
    """3.20e Env vars absent → FtlAuthError before any HTTP call."""
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client

    with pytest.raises(FtlAuthError, match="FTL_USERNAME"):
        with get_authed_ftl_client():
            pass


# ===========================================================================
# 3.20f — Login POST failure → FtlAuthError with body excerpt
# ===========================================================================
@respx.mock
def test_raises_on_login_post_failure(ftl_creds):
    """3.20f POST /login returns 401 → FtlAuthError raised, response body included."""
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client

    respx.get("https://www.fencingtimelive.com/account/login").mock(
        return_value=httpx.Response(200, html=_LOGIN_HTML)
    )
    respx.post("https://www.fencingtimelive.com/login").mock(
        return_value=httpx.Response(401, text="Invalid email or password")
    )

    with pytest.raises(FtlAuthError, match="Invalid email"):
        with get_authed_ftl_client():
            pass


# ===========================================================================
# 3.20g — Credentials rejected (200 but redirected back to login) → FtlAuthError
# ===========================================================================
@respx.mock
def test_raises_when_redirected_back_to_login(ftl_creds):
    """3.20g POST /login → 302 back to /account/login → FtlAuthError "credentials rejected".

    FTL redirects failed logins back to /account/login via 302. After httpx
    follows the redirect, login_resp.url is /account/login which the helper
    treats as a rejected-credential signal. The error must tell the operator
    to update credentials in .env and GitHub Secrets.
    """
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client

    respx.get("https://www.fencingtimelive.com/account/login").mock(
        return_value=httpx.Response(200, html=_LOGIN_HTML)
    )
    # FTL responds to bad credentials with 302 → /account/login
    respx.post("https://www.fencingtimelive.com/login").mock(
        return_value=httpx.Response(
            302,
            headers={"location": "https://www.fencingtimelive.com/account/login?error=invalid"},
        )
    )

    with pytest.raises(FtlAuthError, match="credentials rejected"):
        with get_authed_ftl_client():
            pass
