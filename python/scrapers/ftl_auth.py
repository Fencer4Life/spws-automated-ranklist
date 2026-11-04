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
  NOT refreshed by authenticated requests.

ADR-120 (FTL blocked the account on 2 Nov 2026 after one day of ~700 requests
and 13 sign-ins, nothing counting them) adds four rules every read obeys:

* **A daily cap.** Every request and sign-in is drawn from a ledger before it
  is sent: ten requests at a draw, a sign-in on its own, what a client did not
  use given back when it closes. Spent: `FtlBudgetSpent`, nothing sent. With no
  ledger nothing is read at all. CERT holds the ledger for CI and LOCAL alike
  (`python/scrapers/ftl_ledger.py`); tests install their own (`use_stores`).
* **One session, reused for its life.** The session cookie is stored right
  after a sign-in, before any other request, and every later client, in this
  process or another run, loads it instead of signing in: one sign-in per 10
  days. A cookie that bounces to the login page is dropped, so the next read
  signs in.
* **A pause** of `FTL_PACE_SECONDS` (default 1) between two requests.
* **A name.** Every request says who reads (`USER_AGENT`); FTL's edge refuses
  the library's default name, the name of the traffic it blocked.

Credentials come from FTL_USERNAME (the account email) and FTL_PASSWORD, read
only when a sign-in is needed.
"""

from __future__ import annotations

import atexit
import datetime as dt
import os
import re
import time
from collections.abc import Callable, Generator
from contextlib import contextmanager
from dataclasses import dataclass, replace
from typing import Protocol

import httpx

FTL_HOST = "www.fencingtimelive.com"
FTL_APEX_HOST = "fencingtimelive.com"
FTL_BASE = f"https://{FTL_HOST}"
FTL_LOGIN_PAGE = f"{FTL_BASE}/account/login"
FTL_LOGIN_POST = f"{FTL_BASE}/login"

# ADR-120 §4: who reads. FTL's edge answers 403 to `python-httpx/…`.
USER_AGENT = "SPWS-ranklist/1.0 (Polish Veterans Fencing Association ranking; reads final results)"

# ADR-120 §1 (F1 A): the day's cap, and how many requests one draw takes.
DAILY_REQUESTS = 120
DAILY_SIGN_INS = 2
DRAW = 10

_CSRF_RE = re.compile(r'<meta\s+name="csrf_token"\s+content="([^"]+)"')

# Re-login this far before the cookie's advertised expiry, so a long-running
# job never has a session lapse mid-run.
_SESSION_MARGIN = dt.timedelta(hours=12)

# Paths that ARE the login flow — a redirect to /account/login from one of
# these is handled explicitly below, not by the generic resource-fetch guard.
_LOGIN_FLOW_PATHS = ("/account/login", "/login", "/logout")


class FtlAuthError(RuntimeError):
    """Raised when the FTL login flow fails for any reason."""


class _SignInRefused(FtlAuthError):
    """FTL answered the sign-in itself with a refusal (not a page that failed
    to load); the process does not try again."""


@dataclass(frozen=True)
class Grant:
    """What a draw on the day's ledger was granted, and the day's totals."""

    requests: int
    sign_ins: int
    used_requests: int
    used_sign_ins: int
    cap_requests: int
    cap_sign_ins: int


class FtlBudgetSpent(FtlAuthError):
    """The day's FTL cap is reached: nothing was sent (ADR-120 §1)."""

    def __init__(self, grant: Grant):
        super().__init__(
            f"FTL daily cap reached: {_count(grant)} today; nothing was sent "
            "(ADR-120: the next day reads it)"
        )
        self.grant = grant


@dataclass(frozen=True)
class StoredSession:
    """A session cookie and its fixed expiry."""

    cookie: str
    expires_at: dt.datetime


class Ledger(Protocol):
    def take(self, requests: int, sign_ins: int) -> Grant: ...

    def give_back(self, requests: int) -> int: ...


class SessionStore(Protocol):
    def get(self) -> StoredSession | None: ...

    def put(self, cookie: str, expires_at: dt.datetime) -> None: ...

    def drop(self, cookie: str) -> None: ...


# Process-global state: the session in use (a copy of the store's), a refused
# sign-in, the stores, the day's last known count and the last request's time.
_cached_session: StoredSession | None = None

# A sign-in FTL refused, remembered for the rest of the process (ADR-119 G71 A):
# every later call fails with the same message and makes no new attempt, so a
# run that reads ten FTL events posts the login once, not ten times.
_refused: str | None = None

_ledger: Ledger | None = None
_store: SessionStore | None = None
_today: Grant | None = None
_last_sent: float | None = None
_said_at_exit = False

# Replaced in tests (FTL.PACE.01).
_monotonic: Callable[[], float] = time.monotonic
_sleep: Callable[[float], None] = time.sleep


def reset_session_cache() -> None:
    """Drop the session in use, any remembered refusal, the stores and the
    day's count (the next call starts as a new process). Used by tests."""
    global _cached_session, _refused, _ledger, _store, _today, _last_sent
    _cached_session = None
    _refused = None
    _ledger = None
    _store = None
    _today = None
    _last_sent = None


def use_stores(ledger: Ledger, session_store: SessionStore | None = None) -> None:
    """Read FTL through this ledger and session store (tests; a tool with its
    own). Without a call, the first read builds CERT's (ADR-120)."""
    global _ledger, _store
    _ledger, _store = ledger, session_store


def _stores() -> tuple[Ledger, SessionStore | None]:
    global _ledger, _store
    if _ledger is not None:
        return _ledger, _store
    from python.scrapers.ftl_ledger import cert_stores

    ledger, store = cert_stores()
    _ledger, _store = ledger, store
    return ledger, store


def _count(grant: Grant) -> str:
    return (
        f"{grant.used_requests}/{grant.cap_requests} requests, "
        f"{grant.used_sign_ins}/{grant.cap_sign_ins} sign-ins"
    )


def ftl_today_line() -> str | None:
    """The day's count as the last draw of this process saw it, or None when
    the process read nothing from FTL."""
    return None if _today is None else f"FTL today: {_count(_today)}"


def _say_at_exit() -> None:
    line = ftl_today_line()
    if line:
        print(line)


def _noted(grant: Grant) -> Grant:
    global _today, _said_at_exit
    _today = grant
    if not _said_at_exit:
        _said_at_exit = True
        atexit.register(_say_at_exit)
    return grant


def _pace_seconds() -> float:
    try:
        return max(float(os.environ.get("FTL_PACE_SECONDS", "1")), 0.0)
    except ValueError:
        return 1.0


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


def _bounced_to_login(response: httpx.Response) -> bool:
    if response.status_code in (301, 302, 303, 307, 308):
        location = response.headers.get("location", "")
        return "/account/login" in location and response.request.url.path not in _LOGIN_FLOW_PATHS
    return False


def _connect_sid(client: httpx.Client) -> StoredSession | None:
    """The session cookie FTL set, with its expiry; None without an expiry."""
    found = None
    for ck in client.cookies.jar:
        if ck.name == "connect.sid" and ck.expires and ck.value:
            found = StoredSession(ck.value, dt.datetime.fromtimestamp(ck.expires, dt.UTC))
    return found


def _perform_login(client: httpx.Client, username: str, password: str) -> None:
    """Run GET /account/login → POST /login and verify a session was established."""
    login_page = client.get(FTL_LOGIN_PAGE)
    if login_page.status_code != 200:
        raise FtlAuthError(
            f"GET {FTL_LOGIN_PAGE} returned {login_page.status_code}: {login_page.text[:200]}"
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
        raise _SignInRefused(
            f"POST {FTL_LOGIN_POST} returned {login_resp.status_code}: {login_resp.text[:200]}"
        )
    # A successful login redirects away from /account/login. If the final URL
    # after following redirects is /account/login, the credentials were rejected
    # (wrong password, account locked, or account suspended by FTL).
    if "/account/login" in str(login_resp.url).lower():
        raise _SignInRefused(
            "FTL credentials rejected — wrong password, account locked, or "
            "account suspended. Update FTL_USERNAME / FTL_PASSWORD in .env "
            "and in GitHub repository secrets."
        )


def _usable(session: StoredSession | None, now: dt.datetime) -> bool:
    return session is not None and now < session.expires_at - _SESSION_MARGIN


@contextmanager
def get_authed_ftl_client(
    timeout: float = 15.0, *, force_login: bool = False
) -> Generator[httpx.Client]:
    """Yield an httpx.Client authenticated to fencingtimelive.com (ADR-120).

    The session is the one this process already holds, else the stored one,
    else a fresh sign-in (`force_login` skips the first two), which is stored
    before the client is yielded. Every request is drawn from the day's ledger
    and paced; the client names itself; apex URLs are rewritten to www; a
    resource redirected to the login page drops the session and raises
    ``FtlAuthError``. A sign-in FTL refused is remembered for the rest of the
    process: later calls, ``force_login`` included, raise the same message
    without a request. On close, the requests drawn and not used go back.
    """
    global _cached_session, _refused, _last_sent

    if os.environ.get("FTL_READS", "").strip().lower() == "off":
        # Closing plan rev 5, K2: one repository variable keeps the account idle
        # while FTL deliberates; nothing is drawn, nothing is sent.
        raise FtlAuthError("FTL reads are off (FTL_READS=off): nothing was sent")
    if _refused is not None:
        raise FtlAuthError(_refused)
    try:
        ledger, store = _stores()
    except FtlAuthError:
        raise
    except Exception as e:  # the ledger could not be reached: nothing is read
        raise FtlAuthError(
            f"FTL is read only with a ledger (ADR-120): {type(e).__name__}"
        ) from None

    allowance = 0
    in_use: list[str] = []
    pace = _pace_seconds()

    def draw_requests() -> None:
        nonlocal allowance
        grant = _noted(ledger.take(DRAW, 0))
        if grant.requests == 0:
            raise FtlBudgetSpent(grant)
        allowance = grant.requests

    def before_request(_request: httpx.Request) -> None:
        nonlocal allowance
        global _last_sent
        if allowance == 0:
            draw_requests()
        allowance -= 1
        if pace > 0 and _last_sent is not None:
            wait = pace - (_monotonic() - _last_sent)
            if wait > 0:
                _sleep(wait)
        _last_sent = _monotonic()

    def after_response(response: httpx.Response) -> None:
        global _cached_session
        if response.status_code == 403:
            # 4 Nov 2026: FTL answered 403 to a schedule and nothing kept the
            # body. The status, the URL and the body's first 300 characters go
            # to the run's log; never the cookie. The caller's error is unchanged.
            response.read()
            print(f"FTL answered 403 to {response.request.url}: {response.text[:300]}")
        if _bounced_to_login(response):
            if store is not None and in_use:
                store.drop(in_use[0])
            _cached_session = None
            raise FtlAuthError(
                f"FTL session no longer valid — {response.request.url} was redirected to "
                "the login page; the session is dropped and the next read signs in"
            )

    client = httpx.Client(
        timeout=timeout,
        follow_redirects=True,
        headers={"User-Agent": USER_AGENT},
        event_hooks={
            "request": [_normalize_request_host, before_request],
            "response": [after_response],
        },
    )
    try:
        now = dt.datetime.now(dt.UTC)
        session = None if force_login else _cached_session
        if not _usable(session, now) and not force_login and store is not None:
            session = store.get()
        if _usable(session, now):
            assert session is not None
            _cached_session = session
            client.cookies.set("connect.sid", session.cookie, domain=FTL_HOST, path="/")
            in_use.append(session.cookie)
        else:
            username = os.environ.get("FTL_USERNAME")
            password = os.environ.get("FTL_PASSWORD")
            if not username or not password:
                raise FtlAuthError(
                    "FTL_USERNAME and FTL_PASSWORD must be set in environment "
                    "(see .env for LOCAL, GitHub Secrets for CI)"
                )
            # Requests first: a day with none left spends no sign-in.
            draw_requests()
            grant = _noted(ledger.take(0, 1))
            if grant.sign_ins == 0:
                raise FtlBudgetSpent(grant)
            try:
                _perform_login(client, username.strip(), password)
            except _SignInRefused as e:
                _refused = str(e)
                raise FtlAuthError(_refused) from None
            signed_in = _connect_sid(client)
            if signed_in is not None:
                if store is not None:
                    store.put(signed_in.cookie, signed_in.expires_at)
                _cached_session = signed_in
                in_use.append(signed_in.cookie)
            else:
                _cached_session = None

        yield client
    finally:
        client.close()
        if allowance > 0:
            used = ledger.give_back(allowance)
            if _today is not None:
                _noted(replace(_today, used_requests=used))
