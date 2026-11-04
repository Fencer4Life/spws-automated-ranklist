"""CERT's FTL ledger and session store (python/scrapers/ftl_ledger.py, ADR-120).

FTL.STORE.01  a draw names the Warsaw day and the caps, and reads the grant
FTL.STORE.02  a give-back returns the day's count
FTL.STORE.03  the stored session is read with its expiry; none is None
FTL.STORE.04  a failed store or drop never repeats the cookie
FTL.STORE.05  without the access token there is no ledger, so no read
FTL.SEED.01   the PROD seed export never names the two tables
"""

from __future__ import annotations

import datetime as dt
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parents[2]


class _Transport:
    """Management-API transport: records each statement, answers in turn."""

    def __init__(self, *answers: Any, fail: str | None = None):
        self.answers = list(answers)
        self.sql: list[str] = []
        self.fail = fail

    def fetch_json(self, sql: str) -> Any:
        self.sql.append(sql)
        if self.fail is not None:
            from python.pipeline.promotion.refresh import SqlError

            raise SqlError(f"{self.fail}: {sql}")
        return self.answers.pop(0) if self.answers else None


def test_FTL_STORE_01_a_draw_names_the_day_and_the_caps():
    from python.scrapers.ftl_auth import DAILY_REQUESTS, DAILY_SIGN_INS, Grant
    from python.scrapers.ftl_ledger import CertLedger

    t = _Transport(
        {
            "requests": 10,
            "sign_ins": 0,
            "used_requests": 40,
            "used_sign_ins": 1,
            "cap_requests": 120,
            "cap_sign_ins": 2,
        }
    )
    grant = CertLedger(t, today=lambda: dt.date(2026, 11, 14)).take(10, 0)
    assert grant == Grant(10, 0, 40, 1, 120, 2)
    assert t.sql == [
        "SELECT fn_ftl_ledger_take('2026-11-14'::date, 10, 0, "
        f"{DAILY_REQUESTS}, {DAILY_SIGN_INS}) AS j"
    ]


def test_FTL_STORE_02_a_give_back_returns_the_days_count():
    from python.scrapers.ftl_ledger import CertLedger

    t = _Transport({"used_requests": 33})
    assert CertLedger(t, today=lambda: dt.date(2026, 11, 14)).give_back(7) == 33
    assert t.sql == ["SELECT fn_ftl_ledger_give_back('2026-11-14'::date, 7) AS j"]


def test_FTL_STORE_03_the_stored_session_is_read_with_its_expiry():
    from python.scrapers.ftl_auth import StoredSession
    from python.scrapers.ftl_ledger import CertSessionStore

    stored = CertSessionStore(
        _Transport({"cookie": "s%3Aabc", "expires_at": "2026-11-14T00:08:06+00:00"})
    )
    assert stored.get() == StoredSession(
        "s%3Aabc", dt.datetime(2026, 11, 14, 0, 8, 6, tzinfo=dt.UTC)
    )
    assert CertSessionStore(_Transport(None)).get() is None


def test_FTL_STORE_04_a_failed_store_never_repeats_the_cookie():
    from python.scrapers.ftl_auth import FtlAuthError
    from python.scrapers.ftl_ledger import CertSessionStore

    store = CertSessionStore(_Transport(fail="ERROR"))
    expires = dt.datetime(2026, 11, 14, tzinfo=dt.UTC)
    for act in (lambda: store.put("SECRET-SID", expires), lambda: store.drop("SECRET-SID")):
        with pytest.raises(FtlAuthError) as failed:
            act()
        assert "SECRET-SID" not in str(failed.value)
        assert failed.value.__cause__ is None and failed.value.__context__ is not None
        assert failed.value.__suppress_context__


def test_FTL_STORE_05_without_the_token_there_is_no_ledger():
    from python.scrapers.ftl_auth import FtlAuthError
    from python.scrapers.ftl_ledger import cert_stores

    with pytest.raises(FtlAuthError, match="only with a ledger"):
        cert_stores()


def test_FTL_WF_01_every_step_that_holds_the_ftl_login_holds_the_ledgers_token():
    """A step with FTL_USERNAME and no SUPABASE_ACCESS_TOKEN cannot reach CERT's
    ledger, so it cannot read FTL at all (ADR-120 §1)."""
    import yaml

    missing = []
    for path in sorted((ROOT / ".github/workflows").glob("*.yml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        for job_name, job in (doc.get("jobs") or {}).items():
            outer = {**(doc.get("env") or {}), **(job.get("env") or {})}
            for step in job.get("steps") or []:
                env = {**outer, **(step.get("env") or {})}
                if "FTL_USERNAME" in env and "SUPABASE_ACCESS_TOKEN" not in env:
                    missing.append(f"{path.name} :: {job_name} :: {step.get('name')}")
    assert missing == []


def test_FTL_SEED_01_the_ledger_and_the_session_never_enter_the_prod_seed():
    """ADR-120: both tables are CERT's; the export names its tables one by one."""
    source = (ROOT / "python/pipeline/export_seed.py").read_text(encoding="utf-8")
    assert "ftl_read_ledger" not in source
    assert "ftl_session" not in source


def test_FTL_WF_02_every_step_that_holds_the_ftl_login_honours_the_switch():
    """K2 (closing plan rev 5): FTL_READS comes from the repository variable in
    every step that can read FTL, so one variable keeps the account idle."""
    import yaml

    missing = []
    for path in sorted((ROOT / ".github/workflows").glob("*.yml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        for job_name, job in (doc.get("jobs") or {}).items():
            outer = {**(doc.get("env") or {}), **(job.get("env") or {})}
            for step in job.get("steps") or []:
                env = {**outer, **(step.get("env") or {})}
                if "FTL_USERNAME" in env and env.get("FTL_READS") != "${{ vars.FTL_READS }}":
                    missing.append(f"{path.name} :: {job_name} :: {step.get('name')}")
    assert missing == []
