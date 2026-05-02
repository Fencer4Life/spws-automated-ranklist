"""
Phase 4 (ADR-050) — cert_ref parser, 9th source kind.

Tests for python/scrapers/cert_ref.py. Plan IDs P4.CR.1 - P4.CR.8.

Reads pre-fetched rows from cert_ref schema and produces a ParsedTournament
IR. Used when an event has no live source URL — operator picks `[5]` in the
review CLI; orchestrator queries cert_ref and hands rows to this parser.
"""

from __future__ import annotations

from datetime import date

import pytest

from python.pipeline.ir import ParsedTournament, SourceKind
from python.scrapers.cert_ref import parse


def _row(**overrides):
    base = {
        "id_result": 1,
        "int_place": 1,
        "txt_first_name": "Halina",
        "txt_surname": "BORKOWSKA",
        "txt_nationality": "POL",
        "int_birth_year": 1968,
        "enum_age_category": "V4",
    }
    base.update(overrides)
    return base


def _content(rows=None, **tournament_overrides):
    base_t = {
        "dt_tournament": date(2026, 3, 29),
        "enum_weapon": "FOIL",
        "enum_gender": "F",
        "enum_age_category": "V4",
        "int_participant_count": 14,
    }
    base_t.update(tournament_overrides)
    return {"tournament": base_t, "results": rows if rows is not None else []}


def test_parse_returns_parsed_tournament_with_cert_ref_source_kind():
    """P4.CR.1: parse returns ParsedTournament; source_kind = CERT_REF."""
    pt = parse(_content())
    assert isinstance(pt, ParsedTournament)
    assert pt.source_kind == SourceKind.CERT_REF


def test_parse_empty_results_returns_empty_list():
    """P4.CR.2: empty rows → empty results list."""
    pt = parse(_content(rows=[]))
    assert pt.results == []


def test_parse_single_result_maps_fields():
    """P4.CR.3: single row maps id/name/place/country/birth_year correctly."""
    pt = parse(_content(rows=[_row()]))
    assert len(pt.results) == 1
    r = pt.results[0]
    assert r.fencer_name == "BORKOWSKA Halina"
    assert r.place == 1
    assert r.fencer_country == "POL"
    assert r.birth_year == 1968
    assert r.source_row_id == "cert_ref:1"


def test_parse_multiple_results_preserves_order():
    """P4.CR.4: multiple rows preserve their incoming order (caller orders by place)."""
    rows = [
        _row(id_result=10, int_place=1, txt_surname="A"),
        _row(id_result=11, int_place=2, txt_surname="B"),
        _row(id_result=12, int_place=3, txt_surname="C"),
    ]
    pt = parse(_content(rows=rows))
    assert [r.place for r in pt.results] == [1, 2, 3]


def test_parse_tournament_metadata_mapped():
    """P4.CR.5: tournament-level fields (date, weapon, gender, category, count) flow through."""
    pt = parse(_content(rows=[_row()]))
    assert pt.parsed_date == date(2026, 3, 29)
    assert pt.weapon == "FOIL"
    assert pt.gender == "F"
    assert pt.category_hint == "V4"
    assert pt.raw_pool_size == 14


def test_parse_falls_back_to_len_when_participant_count_missing():
    """P4.CR.6: raw_pool_size falls back to len(results) if int_participant_count is None."""
    pt = parse(_content(
        rows=[_row(id_result=1), _row(id_result=2)],
        int_participant_count=None,
    ))
    assert pt.raw_pool_size == 2


def test_parse_source_url_is_none():
    """P4.CR.7: source_url is None — cert_ref has no URL."""
    pt = parse(_content(rows=[_row()]))
    assert pt.source_url is None


def test_parse_synthesizes_id_when_id_result_missing():
    """P4.CR.8: rows without id_result get a synthesized stable source_row_id (lowercased prefix)."""
    pt = parse(_content(rows=[_row(id_result=None, int_place=2, txt_surname="ANON", txt_first_name="X")]))
    sid = pt.results[0].source_row_id
    # Synthetic format: cert_ref:row{idx}:place{place}:{slug}
    assert sid.startswith("cert_ref:row")
    assert ":place2:" in sid
    assert sid != "cert_ref:None"
