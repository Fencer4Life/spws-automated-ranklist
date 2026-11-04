"""CERT's FTL ledger and session store (ADR-120 §1, §2).

`get_authed_ftl_client` builds these on its first read in a process: every
FTL request and sign-in of CI and LOCAL alike is drawn from one CERT row per
Warsaw day (`fn_ftl_ledger_take`, `fn_ftl_ledger_give_back`), and the session
cookie of the latest sign-in is kept in one CERT row (`fn_ftl_session_get`,
`_put`, `_drop`), so one sign-in serves every run for its 10 days. Both go
through the Management API with the access token every FTL step already
holds; without the token there is no ledger, and nothing reads FTL.

The cookie is a credential: it is passed as a jsonb literal and never repeated
in an error (a failed store raises with the error's kind only).
"""

from __future__ import annotations

import datetime as dt
from collections.abc import Callable
from typing import Any
from zoneinfo import ZoneInfo

from python.scrapers.ftl_auth import (
    DAILY_REQUESTS,
    DAILY_SIGN_INS,
    FtlAuthError,
    Grant,
    StoredSession,
)

WARSAW = ZoneInfo("Europe/Warsaw")


def _warsaw_today() -> dt.date:
    return dt.datetime.now(WARSAW).date()


class CertLedger:
    """The day's allowance on CERT (tbl_ftl_read_ledger)."""

    def __init__(self, transport: Any, *, today: Callable[[], dt.date] = _warsaw_today):
        self.transport = transport
        self.today = today

    def take(self, requests: int, sign_ins: int) -> Grant:
        j = self.transport.fetch_json(
            f"SELECT fn_ftl_ledger_take('{self.today().isoformat()}'::date, {int(requests)}, "
            f"{int(sign_ins)}, {DAILY_REQUESTS}, {DAILY_SIGN_INS}) AS j"
        )
        return Grant(
            int(j["requests"]),
            int(j["sign_ins"]),
            int(j["used_requests"]),
            int(j["used_sign_ins"]),
            int(j["cap_requests"]),
            int(j["cap_sign_ins"]),
        )

    def give_back(self, requests: int) -> int:
        j = self.transport.fetch_json(
            f"SELECT fn_ftl_ledger_give_back('{self.today().isoformat()}'::date, "
            f"{int(requests)}) AS j"
        )
        return int(j["used_requests"])


class CertSessionStore:
    """The one stored FTL session on CERT (tbl_ftl_session)."""

    def __init__(self, transport: Any):
        self.transport = transport

    def get(self) -> StoredSession | None:
        j = self.transport.fetch_json("SELECT fn_ftl_session_get() AS j")
        if not j:
            return None
        return StoredSession(str(j["cookie"]), dt.datetime.fromisoformat(str(j["expires_at"])))

    def _call(self, sql: str, what: str, **params: Any) -> None:
        from python.pipeline.promotion.refresh import _literal as literal

        try:
            self.transport.fetch_json(sql.replace("{p}", f"(SELECT {literal(params)} AS p) a"))
        except Exception as e:  # the message could repeat the statement, cookie and all
            raise FtlAuthError(
                f"the FTL session could not be {what} on CERT ({type(e).__name__})"
            ) from None

    def put(self, cookie: str, expires_at: dt.datetime) -> None:
        self._call(
            "SELECT fn_ftl_session_put(p->>'cookie', (p->>'expires_at')::timestamptz) AS j FROM {p}",
            "stored",
            cookie=cookie,
            expires_at=expires_at.isoformat(),
        )

    def drop(self, cookie: str) -> None:
        self._call(
            "SELECT fn_ftl_session_drop(p->>'cookie') AS j FROM {p}", "dropped", cookie=cookie
        )


def cert_stores() -> tuple[CertLedger, CertSessionStore]:
    """CERT's ledger and session store, through the Management API."""
    from python.pipeline.promotion.refresh import CERT_REF, ManagementTransport
    from python.supabase_token import supabase_access_token

    token = supabase_access_token()
    if not token:
        raise FtlAuthError(
            "FTL is read only with a ledger (ADR-120): SUPABASE_ACCESS_TOKEN is not set, "
            "so CERT's ledger cannot be reached"
        )
    transport = ManagementTransport(CERT_REF, token, read_only=False)
    return CertLedger(transport), CertSessionStore(transport)
