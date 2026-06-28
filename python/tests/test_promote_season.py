"""ADR-077 — CERT → PROD season-skeleton promotion orchestrator.

Plan test IDs S77.1–S77.5:
  S77.1  promote_season reads CERT season + events and calls the PROD RPC
  S77.2  id_prior_event is re-resolved to the TARGET (PROD) id by txt_code
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
            return [{"j": {"id_season": 4, "txt_code": "SPWS-2026-2027", "dt_start": "2026-08-01",
                           "dt_end": "2027-07-15", "bool_active": False}}]
        if "FROM tbl_tournament t" in sql:
            return [{"n": 0 if childless else 3}]
        if "FROM tbl_scoring_config sc" in sql:
            return [{"j": {"id_config": 99, "id_season": 4, "int_ppw_best_count": 4}}]
        if "FROM tbl_event e" in sql:
            # Two events; MPW carries a prior link to the previous season.
            return [
                {"j": {"id_event": 85, "id_season": 4, "id_organizer": 3,
                       "txt_code": "PPW1-2026-2027", "txt_name": "PPW1", "enum_status": "CREATED",
                       "id_prior_event": 61},
                 "prior_code": "PPW1-2025-2026", "org_code": "SPWS"},
                {"j": {"id_event": 90, "id_season": 4, "id_organizer": 3,
                       "txt_code": "MPW-2026-2027", "txt_name": "MPW", "enum_status": "CREATED",
                       "id_prior_event": 81},
                 "prior_code": "MPW-2025-2026", "org_code": "SPWS"},
            ]
        raise AssertionError(f"unexpected CERT query: {sql}")
    return q


def _prod_query(captured: dict, *, season_present: bool = False):
    """Fake PROD query; records the payload sent to fn_promote_season_skeleton."""
    def q(sql: str):
        if "FROM tbl_season WHERE txt_code" in sql:
            return [{"x": 1}] if season_present else []
        if "FROM tbl_event WHERE txt_code IN" in sql:
            # PROD ids DIVERGE from CERT: PPW1-2025-2026=61 here too, MPW-2025-2026=84 (CERT had 81).
            return [{"txt_code": "PPW1-2025-2026", "id": 61},
                    {"txt_code": "MPW-2025-2026", "id": 84}]
        if "FROM tbl_organizer WHERE txt_code IN" in sql:
            return [{"txt_code": "SPWS", "id": 3}]
        if "fn_promote_season_skeleton" in sql:
            # Extract the JSONB payload literal for assertions.
            start = sql.index("'") + 1
            end = sql.rindex("'::JSONB")
            captured["payload"] = json.loads(sql[start:end].replace("''", "'"))
            return [{"r": {"season_code": "SPWS-2026-2027", "id_season": 4, "events_created": 2}}]
        raise AssertionError(f"unexpected PROD query: {sql}")
    return q


def test_promote_reads_cert_and_calls_prod_rpc():
    """S77.1"""
    captured: dict = {}
    out = promote_season("SPWS-2026-2027", cert_query_fn=_cert_query(),
                         prod_query_fn=_prod_query(captured))
    assert out["events"] == 2
    assert out["rpc"]["events_created"] == 2
    assert captured["payload"]["source_childless"] is True
    assert captured["payload"]["season"]["txt_code"] == "SPWS-2026-2027"
    assert len(captured["payload"]["events"]) == 2


def test_id_prior_event_resolved_to_target_id():
    """S77.2 — the MPW event's prior link must point at PROD's id (84), not CERT's raw 81."""
    captured: dict = {}
    promote_season("SPWS-2026-2027", cert_query_fn=_cert_query(),
                   prod_query_fn=_prod_query(captured))
    events = {e["txt_code"]: e for e in captured["payload"]["events"]}
    assert events["MPW-2026-2027"]["id_prior_event"] == 84  # PROD id, NOT 81
    assert events["PPW1-2026-2027"]["id_prior_event"] == 61


def test_childless_guard_refuses():
    """S77.3"""
    with pytest.raises(RuntimeError, match="childless"):
        promote_season("SPWS-2026-2027", cert_query_fn=_cert_query(childless=False),
                       prod_query_fn=_prod_query({}))


def test_idempotency_refuses_when_present_on_prod():
    """S77.4"""
    with pytest.raises(RuntimeError, match="already exists on PROD"):
        promote_season("SPWS-2026-2027", cert_query_fn=_cert_query(),
                       prod_query_fn=_prod_query({}, season_present=True))


def test_dry_run_does_not_write_prod():
    """S77.5"""
    captured: dict = {}
    out = promote_season("SPWS-2026-2027", cert_query_fn=_cert_query(),
                         prod_query_fn=_prod_query(captured), dry_run=True)
    assert out["dry_run"] is True
    assert "payload" not in captured  # the RPC was never called
