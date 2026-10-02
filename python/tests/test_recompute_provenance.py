"""RECOMP.PROV — a recompute writes every result's stored provenance back as it was.

RECOMPUTE_DOMESTIC (ADR-072) rewrites an event's results through
``fn_ingest_tournament_results``, which deletes and re-inserts each row. It
used to rebuild the rows from the fencer id alone, so every recompute stored
the id as ``txt_scraped_name`` and reset ``enum_match_method`` to AUTO_MATCH
and the confidence to 100. Found on LOCAL on 1 October 2026 (GP3-2023-2024
after a birth-year edit); 2,610 of 2,811 LOCAL results already carried a
number as their scraped name, exported from CERT.

A recompute re-derives V-categories and scores. It has no source and no
re-match, so it has nothing new to say about who a row is or how it was
matched; it writes the stored name, confidence and method back verbatim,
NULLs included. The SQL side is pinned by
supabase/tests/87_recompute_provenance.sql.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

from python.pipeline import run as run_module
from python.pipeline.core.contract import Context, Services
from python.pipeline.db_connector import DbConnector
from python.pipeline.engine.flows import Flow, FlowParams
from python.pipeline.plugins.recompute import LoadCommitted

KOWALSKI = {
    "id_fencer": 1,
    "place": 1,
    "int_birth_year": 1980,
    "scraped_name": "KOWALSKI Jan",
    "confidence": 87.5,
    "match_method": "USER_CONFIRMED",
}
NOWAK = {
    "id_fencer": 2,
    "place": 2,
    "int_birth_year": 1981,
    "scraped_name": "NOWAK Adam",
    "confidence": 100,
    "match_method": "AUTO_CREATED",
}
# A row an early EVF import wrote with no scraped name, confidence or method.
UNNAMED = {
    "id_fencer": 3,
    "place": 3,
    "int_birth_year": 1979,
    "scraped_name": None,
    "confidence": None,
    "match_method": None,
}


def _db(rows, engine="EVF_CLASSIC_V1_2025_2026"):
    db = MagicMock()
    db.get_type_engine.return_value = engine
    db.fetch_event_results.return_value = rows
    db.fetch_birth_years_batch.return_value = {r["id_fencer"]: r["int_birth_year"] for r in rows}
    db.find_or_create_tournament.return_value = 501
    db.fetch_event_tournaments.return_value = []
    db.ingest_results.return_value = {"ok": True}
    return db


def _recompute(db, code="PPW4-2025-2026"):
    cfg = {"id_event": 7, "season_end_year": 2026, "event": {"id_event": 7, "txt_code": code}}
    return run_module.run_flow(
        FlowParams(Flow.RECOMPUTE_DOMESTIC, id_event=7), svc=Services(db=db, config=cfg)
    )


def _written_rows(db):
    return [row for call in db.ingest_results.call_args_list for row in call.args[1]]


def _provenance(row):
    return (row["txt_scraped_name"], row["num_confidence"], row["enum_match_method"])


class TestFetch:
    def test_the_fetch_returns_the_stored_provenance(self):
        """RECOMP.PROV.01 fetch_event_results selects and returns each row's
        scraped name, confidence and match method."""
        sb = MagicMock()
        tournaments = MagicMock()
        tournaments.data = [
            {
                "id_tournament": 1,
                "enum_weapon": "EPEE",
                "enum_gender": "M",
                "enum_age_category": "V1",
                "dt_tournament": "2025-11-12",
                "int_participant_count": 10,
                "url_results": None,
                "txt_joined_order": None,
            }
        ]
        results = MagicMock()
        results.data = [
            {
                "id_fencer": 5,
                "int_place": 3,
                "id_tournament": 1,
                "txt_scraped_name": "KOWALSKI Jan",
                "num_match_confidence": 87.5,
                "enum_match_method": "USER_CONFIRMED",
            }
        ]
        sb.table.return_value.select.return_value.eq.return_value.execute.return_value = tournaments
        sb.table.return_value.select.return_value.in_.return_value.execute.return_value = results
        db = DbConnector(sb)
        db.fetch_birth_years_batch = MagicMock(return_value={5: 1980})
        (row,) = db.fetch_event_results(9)
        selected = " ".join(str(c.args[0]) for c in sb.table.return_value.select.call_args_list)
        for column in ("txt_scraped_name", "num_match_confidence", "enum_match_method"):
            assert column in selected
        assert (row["scraped_name"], row["confidence"], row["match_method"]) == (
            "KOWALSKI Jan",
            87.5,
            "USER_CONFIRMED",
        )


class TestLoad:
    def test_the_matches_carry_the_stored_provenance(self):
        """RECOMP.PROV.02 LoadCommitted puts the stored name, confidence and
        method on each match, not the fencer id."""
        ctx = Context()
        plugin = LoadCommitted()
        ctx._begin(plugin)
        plugin.run(
            ctx,
            Services(
                db=_db([KOWALSKI]),
                config={"id_event": 7, "season_end_year": 2026, "event": {"id_event": 7}},
            ),
        )
        ctx._end()
        (m,) = ctx.get("matches")
        assert m.scraped_name == "KOWALSKI Jan"
        assert (m.stored_scraped_name, m.stored_confidence, m.stored_match_method) == (
            "KOWALSKI Jan",
            87.5,
            "USER_CONFIRMED",
        )


class TestWrite:
    def test_a_domestic_recompute_writes_the_provenance_back(self):
        """RECOMP.PROV.03 a domestic recompute writes the stored name,
        confidence and method verbatim, and sends no forced match status."""
        db = _db([KOWALSKI, NOWAK])
        _recompute(db)
        rows = _written_rows(db)
        assert sorted(_provenance(r) for r in rows) == [
            ("KOWALSKI Jan", 87.5, "USER_CONFIRMED"),
            ("NOWAK Adam", 100, "AUTO_CREATED"),
        ]
        assert all("enum_match_status" not in r for r in rows)

    def test_missing_provenance_stays_missing(self):
        """RECOMP.PROV.04 a row stored without a name, confidence or method is
        written with all three as null, keys present, so the RPC keeps NULL
        rather than inventing a name or a confidence of 100."""
        db = _db([UNNAMED])
        _recompute(db)
        (row,) = _written_rows(db)
        assert _provenance(row) == (None, None, None)

    def test_an_international_recompute_writes_the_provenance_back(self):
        """RECOMP.PROV.05 the international path (ADR-105) writes the stored
        provenance back as well."""
        stored = {
            "weapon": "EPEE",
            "gender": "M",
            "date": date(2025, 11, 12),
            "participant_count": 60,
            "enum_age_category": "V1",
        }
        db = _db([KOWALSKI | stored, UNNAMED | stored])
        _recompute(db, code="PEW1-2025-2026")
        rows = _written_rows(db)
        assert sorted(_provenance(r) for r in rows if r["txt_scraped_name"]) == [
            ("KOWALSKI Jan", 87.5, "USER_CONFIRMED")
        ]
        assert [_provenance(r) for r in rows if not r["txt_scraped_name"]] == [(None, None, None)]
