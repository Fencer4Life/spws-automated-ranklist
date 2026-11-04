"""Tests for FTL authentication helper (python/scrapers/ftl_auth.py).

Plan test IDs 3.20a–f: FTL login flow that bypasses the post-2026-04 auth wall.

FTL change: every /events/results/{id} and /events/results/data/{id} now
302-redirects to /account/login when called without an authed session cookie.
The helper performs login-and-return-client so callers can run authed GETs.
"""

from __future__ import annotations

import datetime as dt

import httpx
import pytest
import respx

_LOGIN_HTML = """<!doctype html>
<html><head>
  <meta name="csrf_token" content="ZnXUWtG6-JC90o7zR0EMV8iKxS96uTyo9TwI">
</head><body><form id="loginForm"></form></body></html>
"""

FTL = "https://www.fencingtimelive.com"
DATA = f"{FTL}/events/results/data/ABC"


class _Ledger:
    """The day's allowance as fn_ftl_ledger_take / _give_back keep it (ADR-120 §1)."""

    def __init__(self, cap_requests=120, cap_sign_ins=2, used_requests=0, used_sign_ins=0):
        self.cap_requests, self.cap_sign_ins = cap_requests, cap_sign_ins
        self.used_requests, self.used_sign_ins = used_requests, used_sign_ins
        self.takes: list[tuple[int, int]] = []
        self.given: list[int] = []

    def take(self, requests, sign_ins):
        from python.scrapers.ftl_auth import Grant

        self.takes.append((requests, sign_ins))
        granted = min(requests, max(self.cap_requests - self.used_requests, 0))
        signs = sign_ins if self.used_sign_ins + sign_ins <= self.cap_sign_ins else 0
        self.used_requests += granted
        self.used_sign_ins += signs
        return Grant(
            granted,
            signs,
            self.used_requests,
            self.used_sign_ins,
            self.cap_requests,
            self.cap_sign_ins,
        )

    def give_back(self, requests):
        self.given.append(requests)
        self.used_requests = max(self.used_requests - requests, 0)
        return self.used_requests


class _Store:
    """The one stored session as fn_ftl_session_get / _put / _drop keep it (ADR-120 §2)."""

    def __init__(self, cookie: str | None = None, expires_at: dt.datetime | None = None):
        from python.scrapers.ftl_auth import StoredSession

        self.session = StoredSession(cookie, expires_at) if cookie and expires_at else None
        self.puts: list[tuple[str, dt.datetime]] = []
        self.drops: list[str] = []

    def get(self):
        return self.session

    def put(self, cookie, expires_at):
        from python.scrapers.ftl_auth import StoredSession

        self.puts.append((cookie, expires_at))
        self.session = StoredSession(cookie, expires_at)

    def drop(self, cookie):
        self.drops.append(cookie)
        if self.session and self.session.cookie == cookie:
            self.session = None


@pytest.fixture(autouse=True)
def ledger():
    """Every test here reads FTL through a ledger, as every run does (ADR-120 §1);
    FTL.BUDGET.01 takes it away."""
    from python.scrapers.ftl_auth import use_stores

    book = _Ledger()
    use_stores(book)
    return book


def _signs_in(expires_in=dt.timedelta(days=10), sid="AUTHED-SID"):
    """FTL's login page and a sign-in that sets a session cookie expiring in `expires_in`."""
    expires = (dt.datetime.now(dt.UTC) + expires_in).strftime("%a, %d %b %Y %H:%M:%S GMT")
    page = respx.get(f"{FTL}/account/login").mock(
        return_value=httpx.Response(200, html=_LOGIN_HTML)
    )
    login = respx.post(f"{FTL}/login").mock(
        return_value=httpx.Response(
            200, text="/", headers={"set-cookie": f"connect.sid={sid}; Path=/; Expires={expires}"}
        )
    )
    return page, login


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


# ===========================================================================
# FTL.REFUSED — a refused sign-in is tried once per process (ADR-119 G71 A)
#
# On 2 Nov 2026 FTL refused the pipeline account's sign-in, and the source
# re-read posted the login once for each of its ten FTL events in five
# minutes: the session is cached only after a sign-in succeeds. A refusal is
# now remembered for the rest of the process: every later FTL read fails at
# once with the same message and no new attempt; the next run tries once.
# ===========================================================================
_REFUSED = (
    "An error occurred when trying to log you in. Please contact customer support to resolve this."
)


def _refusing_ftl():
    page = respx.get("https://www.fencingtimelive.com/account/login").mock(
        return_value=httpx.Response(200, html=_LOGIN_HTML)
    )
    login = respx.post("https://www.fencingtimelive.com/login").mock(
        return_value=httpx.Response(400, text=_REFUSED)
    )
    return page, login


@respx.mock
def test_FTL_REFUSED_01_a_refused_sign_in_is_not_tried_again_in_the_process(ftl_creds):
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client

    page, login = _refusing_ftl()
    messages = []
    for _ in range(3):
        with pytest.raises(FtlAuthError) as refused:
            with get_authed_ftl_client():
                pass
        messages.append(str(refused.value))
    assert login.call_count == 1 and page.call_count == 1
    assert len(set(messages)) == 1 and "contact customer support" in messages[0]


@respx.mock
def test_FTL_REFUSED_02_forcing_a_login_makes_no_new_attempt_either(ftl_creds):
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client

    _page, login = _refusing_ftl()
    for force in (False, True):
        with pytest.raises(FtlAuthError, match="contact customer support"):
            with get_authed_ftl_client(force_login=force):
                pass
    assert login.call_count == 1


@respx.mock
def test_FTL_REFUSED_03_a_new_process_tries_once_again(ftl_creds, ledger):
    """reset_session_cache stands for the next run's new process, which reads
    through its ledger too (ADR-120)."""
    from python.scrapers.ftl_auth import (
        FtlAuthError,
        get_authed_ftl_client,
        reset_session_cache,
        use_stores,
    )

    _page, login = _refusing_ftl()
    with pytest.raises(FtlAuthError):
        with get_authed_ftl_client():
            pass
    reset_session_cache()
    use_stores(ledger)
    with pytest.raises(FtlAuthError):
        with get_authed_ftl_client():
            pass
    assert login.call_count == 2


@respx.mock
def test_FTL_REFUSED_04_a_login_page_that_fails_to_load_is_not_a_refusal(ftl_creds):
    """FTL down is not the account refused: the next read tries again."""
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client

    page = respx.get("https://www.fencingtimelive.com/account/login").mock(
        return_value=httpx.Response(503, text="Service Unavailable")
    )
    for _ in range(2):
        with pytest.raises(FtlAuthError, match="503"):
            with get_authed_ftl_client():
                pass
    assert page.call_count == 2


# ===========================================================================
# FTL.BUDGET — every FTL request and sign-in is drawn from the day's cap
# before it is sent (ADR-120 §1)
#
# On 1 Nov 2026 the pipeline sent FTL about 700 requests and 13 sign-ins,
# nothing counted them, and FTL blocked the account that night. The client now
# draws ten requests at a time from a ledger (one CERT row per Warsaw day, CI
# and LOCAL alike), a sign-in on its own, and gives back what it did not use.
# ===========================================================================
@respx.mock
def test_FTL_BUDGET_01_no_ledger_no_request(ftl_creds):
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client, reset_session_cache

    reset_session_cache()
    page, login = _signs_in()
    with pytest.raises(FtlAuthError, match="only with a ledger"):
        with get_authed_ftl_client():
            pass
    assert not page.called and not login.called


@respx.mock
def test_FTL_BUDGET_02_a_draw_comes_before_the_first_request(ftl_creds, ledger):
    from python.scrapers.ftl_auth import get_authed_ftl_client

    _signs_in()
    data = respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with get_authed_ftl_client() as client:
        client.get(DATA)
    assert ledger.takes == [
        (10, 0),
        (0, 1),
    ]  # requests first: no sign-in spent on a day with none left
    assert data.called


@respx.mock
def test_FTL_BUDGET_03_the_eleventh_request_draws_again(ftl_creds, ledger):
    from python.scrapers.ftl_auth import get_authed_ftl_client

    _signs_in()
    respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with get_authed_ftl_client() as client:
        for _ in range(9):  # 2 for the sign-in, 9 here: the 11th draws
            client.get(DATA)
    assert ledger.takes == [(10, 0), (0, 1), (10, 0)]


@respx.mock
def test_FTL_BUDGET_04_at_the_cap_nothing_is_sent(ftl_creds):
    from python.scrapers.ftl_auth import FtlBudgetSpent, get_authed_ftl_client, use_stores

    use_stores(_Ledger(used_requests=120))
    page, _login = _signs_in()
    with pytest.raises(FtlBudgetSpent, match=r"120/120 requests"):
        with get_authed_ftl_client():
            pass
    assert not page.called


@respx.mock
def test_FTL_BUDGET_05_what_a_run_did_not_use_is_given_back(ftl_creds, ledger):
    from python.scrapers.ftl_auth import get_authed_ftl_client

    _signs_in()
    respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with get_authed_ftl_client() as client:
        client.get(DATA)  # 3 of the 10 drawn: login page, sign-in, this
    assert ledger.given == [7]
    assert ledger.used_requests == 3


@respx.mock
def test_FTL_BUDGET_06_a_sign_in_is_drawn_on_its_own(ftl_creds, ledger):
    from python.scrapers.ftl_auth import get_authed_ftl_client

    _signs_in()
    with get_authed_ftl_client():
        pass
    assert ledger.used_sign_ins == 1


@respx.mock
def test_FTL_BUDGET_07_no_sign_in_left_no_sign_in_tried(ftl_creds):
    from python.scrapers.ftl_auth import FtlBudgetSpent, get_authed_ftl_client, use_stores

    use_stores(_Ledger(used_requests=30, used_sign_ins=2))
    page, login = _signs_in()
    with pytest.raises(FtlBudgetSpent, match=r"2/2 sign-ins"):
        with get_authed_ftl_client():
            pass
    assert not page.called and not login.called


@respx.mock
def test_FTL_BUDGET_08_the_audit_tool_reads_ftl_through_the_gate(ftl_creds, ledger):
    """B9: audit_results fetched FTL's data with a bare httpx.get, uncounted and
    under the library's name FTL refuses."""
    from python.tools import audit_results

    _signs_in()
    data = respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    audit_results.scrape_url(f"{FTL}/events/results/ABC")
    assert data.called
    assert ledger.takes == [(10, 0), (0, 1)]


@respx.mock
def test_FTL_BUDGET_09_the_run_can_say_the_days_count(ftl_creds):
    from python.scrapers.ftl_auth import ftl_today_line, get_authed_ftl_client, use_stores

    use_stores(_Ledger(used_requests=28))
    _signs_in()
    respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with get_authed_ftl_client() as client:
        client.get(DATA)
    assert ftl_today_line() == "FTL today: 31/120 requests, 1/2 sign-ins"


# ===========================================================================
# FTL.SESSION — one session, captured at the sign-in and reused for its life
# (ADR-120 §2)
#
# FTL's session cookie is valid a fixed 10 days from the sign-in. It is stored
# right after the sign-in, before any other request, and every later run, CI or
# LOCAL, loads it instead of signing in.
# ===========================================================================
@respx.mock
def test_FTL_SESSION_01_a_stored_session_is_used_without_a_sign_in(ftl_creds, ledger):
    from python.scrapers.ftl_auth import get_authed_ftl_client, use_stores

    use_stores(ledger, _Store("STORED-SID", dt.datetime.now(dt.UTC) + dt.timedelta(days=5)))
    page, login = _signs_in()
    data = respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with get_authed_ftl_client() as client:
        client.get(DATA)
    assert not page.called and not login.called
    assert "connect.sid=STORED-SID" in data.calls.last.request.headers["cookie"]
    assert ledger.used_sign_ins == 0


@respx.mock
def test_FTL_SESSION_02_a_session_near_its_end_is_renewed(ftl_creds, ledger):
    from python.scrapers.ftl_auth import get_authed_ftl_client, use_stores

    store = _Store("OLD-SID", dt.datetime.now(dt.UTC) + dt.timedelta(hours=11))
    use_stores(ledger, store)
    _page, login = _signs_in()
    with get_authed_ftl_client():
        pass
    assert login.called
    assert store.session is not None and store.session.cookie == "AUTHED-SID"


@respx.mock
def test_FTL_SESSION_03_a_sign_in_is_stored_before_any_other_request(ftl_creds, ledger):
    from python.scrapers.ftl_auth import get_authed_ftl_client, use_stores

    store = _Store()
    use_stores(ledger, store)
    _signs_in()
    with get_authed_ftl_client():
        assert [cookie for cookie, _ in store.puts] == ["AUTHED-SID"]
        expires = store.puts[0][1]
    left = expires - dt.datetime.now(dt.UTC)
    assert dt.timedelta(days=9, hours=23) < left <= dt.timedelta(days=10)


@respx.mock
def test_FTL_SESSION_04_a_bounced_session_is_dropped_and_the_next_read_signs_in(ftl_creds, ledger):
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client, use_stores

    store = _Store("STALE-SID", dt.datetime.now(dt.UTC) + dt.timedelta(days=5))
    use_stores(ledger, store)
    _page, login = _signs_in()
    respx.get(DATA).mock(
        return_value=httpx.Response(302, headers={"location": f"{FTL}/account/login"})
    )
    with pytest.raises(FtlAuthError, match="session"):
        with get_authed_ftl_client() as client:
            client.get(DATA)
    assert store.drops == ["STALE-SID"] and store.session is None
    with get_authed_ftl_client():
        pass
    assert login.call_count == 1


@respx.mock
def test_FTL_SESSION_05_a_refused_sign_in_stores_nothing(ftl_creds, ledger):
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client, use_stores

    store = _Store()
    use_stores(ledger, store)
    _refusing_ftl()
    with pytest.raises(FtlAuthError, match="contact customer support"):
        with get_authed_ftl_client():
            pass
    assert store.puts == []
    assert ledger.used_sign_ins == 1


# ===========================================================================
# FTL.NAME — the client says who it is (ADR-120 §4)
#
# FTL's edge answers 403 to the library's default name (python-httpx), the name
# of the traffic it blocked. The client names the association instead.
# ===========================================================================
@respx.mock
def test_FTL_NAME_01_every_request_carries_the_associations_name(ftl_creds):
    from python.scrapers.ftl_auth import USER_AGENT, get_authed_ftl_client

    page, login = _signs_in()
    data = respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with get_authed_ftl_client() as client:
        client.get(DATA)
    for route in (page, login, data):
        assert route.calls.last.request.headers["user-agent"] == USER_AGENT
    assert USER_AGENT.startswith("SPWS-ranklist/")


# ===========================================================================
# FTL.PACE — at least one second between two FTL requests (ADR-120 §3)
# ===========================================================================
@respx.mock
def test_FTL_PACE_01_a_request_waits_for_the_pause(ftl_creds, monkeypatch):
    from python.scrapers import ftl_auth

    clock = [100.0]
    slept: list[float] = []

    def sleep(seconds: float) -> None:
        slept.append(round(seconds, 3))
        clock[0] += seconds

    monkeypatch.setenv("FTL_PACE_SECONDS", "1")
    monkeypatch.setattr(ftl_auth, "_monotonic", lambda: clock[0])
    monkeypatch.setattr(ftl_auth, "_sleep", sleep)
    _signs_in()
    respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with ftl_auth.get_authed_ftl_client() as client:
        clock[0] += 0.25
        client.get(DATA)
    assert slept == [1.0, 0.75]  # the sign-in's POST after its page, then this read


# ===========================================================================
# FTL.OFF — the switch (closing plan rev 5, K2): FTL_READS=off keeps the account
# idle while FTL deliberates; one repository variable, reversible, no secret
# touched. FTL.403 — a refusal is recorded (4 Nov 2026: nothing kept the body
# of the 403 FTL answered the Liège schedule). FTL.BUDGET.10 — B12: the legacy
# fetcher read FTL with a plain client.
# ===========================================================================
@respx.mock
def test_FTL_OFF_01_with_ftl_reads_off_nothing_is_sent(ftl_creds, ledger, monkeypatch):
    from python.scrapers.ftl_auth import FtlAuthError, get_authed_ftl_client

    monkeypatch.setenv("FTL_READS", "off")
    page, login = _signs_in()
    data = respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with pytest.raises(FtlAuthError, match="FTL_READS=off"):
        with get_authed_ftl_client() as client:
            client.get(DATA)
    assert not page.called and not login.called and not data.called
    assert ledger.takes == []


@respx.mock
def test_FTL_OFF_02_any_other_value_reads_as_before(ftl_creds, ledger, monkeypatch):
    from python.scrapers.ftl_auth import get_authed_ftl_client

    monkeypatch.setenv("FTL_READS", "on")
    _signs_in()
    data = respx.get(DATA).mock(return_value=httpx.Response(200, json=[]))
    with get_authed_ftl_client() as client:
        client.get(DATA)
    assert data.called and ledger.takes == [(10, 0), (0, 1)]


@respx.mock
def test_FTL_403_01_a_refusal_is_recorded_without_the_cookie(ftl_creds, ledger, capsys):
    """The client prints the status, the URL and the body's first 300 characters;
    the caller's error is unchanged, and the cookie never appears."""
    from python.scrapers.ftl_auth import get_authed_ftl_client, use_stores

    use_stores(ledger, _Store("STORED-SID", dt.datetime.now(dt.UTC) + dt.timedelta(days=5)))
    body = "<html>Forbidden: " + "x" * 400
    respx.get(DATA).mock(return_value=httpx.Response(403, text=body))
    with get_authed_ftl_client() as client:
        resp = client.get(DATA)
    assert resp.status_code == 403
    out = capsys.readouterr().out
    assert f"FTL answered 403 to {DATA}: {body[:300]}" in out
    assert "x" * 301 not in out
    assert "STORED-SID" not in out


@respx.mock
def test_FTL_BUDGET_10_the_legacy_fetcher_reads_ftl_through_the_gate(ftl_creds, ledger):
    """B12: review_cli.Fetcher built without a client fetched an FTL results page
    with a plain httpx client, uncounted and under the library's name."""
    from python.pipeline.review_cli import Fetcher

    _signs_in()
    data = respx.get(DATA).mock(
        return_value=httpx.Response(
            200, json=[{"id": "f1", "name": "SURNAME Jan", "place": "1", "country": "POL"}]
        )
    )
    Fetcher().fetch_url(DATA)
    assert data.called
    assert ledger.takes == [(10, 0), (0, 1)]
    assert data.calls.last.request.headers["user-agent"].startswith("SPWS-ranklist/")
