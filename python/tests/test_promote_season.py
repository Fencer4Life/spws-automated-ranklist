"""ADR-077 — CERT → PROD season-skeleton promotion orchestrator (slimmed,
reconciler amendment pending sign-off).

Plan test IDs S77.1, S77.3–S77.5:
  S77.1  promote_season reads CERT season + scoring_config ONLY (no events —
         event C/U/D moved to promote.py's promote_calendar reconciler) and
         calls the PROD RPC
  S77.2  RETIRED — id_prior_event target-resolution during event-copy is no
         longer this module's responsibility; coverage migrated to
         supabase/tests/51_prod_event_reconcile.sql (51.1c)
  S77.3  childless guard — refuse when CERT season has tournament children
  S77.4  idempotency — refuse when the season already exists on PROD
  S77.5  dry_run reads but never writes PROD
"""

from __future__ import annotations

import json

import pytest

from python.pipeline.promote_season import promote_season


def _cert_query(*, childless: bool = True):
    """Fake CERT Management-API query keyed on the SQL text."""

    def q(sql: str):
        if "FROM tbl_season s" in sql and "to_jsonb" in sql:
            return [
                {
                    "j": {
                        "id_season": 4,
                        "txt_code": "SPWS-2026-2027",
                        "dt_start": "2026-08-01",
                        "dt_end": "2027-07-15",
                        "bool_active": False,
                    }
                }
            ]
        if "FROM tbl_tournament t" in sql:
            return [{"n": 0 if childless else 3}]
        if "FROM tbl_scoring_config sc" in sql:
            return [{"j": {"id_config": 99, "id_season": 4, "int_ppw_best_count": 4}}]
        raise AssertionError(f"unexpected CERT query: {sql}")

    return q


def _prod_query(captured: dict, *, season_present: bool = False):
    """Fake PROD query; records the payload sent to fn_promote_season_skeleton."""

    def q(sql: str):
        if "FROM tbl_season WHERE txt_code" in sql:
            return [{"x": 1}] if season_present else []
        if "fn_promote_season_skeleton" in sql:
            # Extract the JSONB payload literal for assertions.
            start = sql.index("'") + 1
            end = sql.rindex("'::JSONB")
            captured["payload"] = json.loads(sql[start:end].replace("''", "'"))
            return [{"r": {"season_code": "SPWS-2026-2027", "id_season": 4}}]
        raise AssertionError(f"unexpected PROD query: {sql}")

    return q


def test_promote_reads_cert_and_calls_prod_rpc():
    """S77.1: promote_season reads season + scoring_config only — events are
    NOT read from CERT nor sent in the payload (owned by the reconciler)."""
    captured: dict = {}
    out = promote_season(
        "SPWS-2026-2027", cert_query_fn=_cert_query(), prod_query_fn=_prod_query(captured)
    )
    assert out["season_code"] == "SPWS-2026-2027"
    assert out["id_season"] == 4
    assert out["rpc"]["season_code"] == "SPWS-2026-2027"
    assert captured["payload"]["source_childless"] is True
    assert captured["payload"]["season"]["txt_code"] == "SPWS-2026-2027"
    assert captured["payload"]["scoring_config"]["int_ppw_best_count"] == 4
    assert "events" not in captured["payload"]


def test_childless_guard_refuses():
    """S77.3"""
    with pytest.raises(RuntimeError, match="childless"):
        promote_season(
            "SPWS-2026-2027",
            cert_query_fn=_cert_query(childless=False),
            prod_query_fn=_prod_query({}),
        )


def test_idempotency_refuses_when_present_on_prod():
    """S77.4"""
    with pytest.raises(RuntimeError, match="already exists on PROD"):
        promote_season(
            "SPWS-2026-2027",
            cert_query_fn=_cert_query(),
            prod_query_fn=_prod_query({}, season_present=True),
        )


def test_dry_run_does_not_write_prod():
    """S77.5"""
    captured: dict = {}
    out = promote_season(
        "SPWS-2026-2027",
        cert_query_fn=_cert_query(),
        prod_query_fn=_prod_query(captured),
        dry_run=True,
    )
    assert out["dry_run"] is True
    assert "payload" not in captured  # the RPC was never called
