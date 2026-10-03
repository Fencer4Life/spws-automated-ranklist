"""PROMO.SEED.01–05 — the seed keeps PROD's fencer ids (ADR-036 §1, ADR-108).

The fencer id is the same on LOCAL, CERT and PROD. The monolithic seed used to
drop `tbl_fencer.id_fencer` (it has a sequence default) and to find every
result's fencer again by name and birth year, so a fresh LOCAL got new ids and
needed a refresh before it matched PROD. Now:

  - the seed hands PROD's whole roster and id sequence to fn_seed_load_fencers,
    which gives the fencers that data migrations created their PROD ids, creates
    the rest at PROD's ids, and fails on any difference with that roster;
  - every result names its fencer by id;
  - `refresh --mode verify` compares a database's roster with PROD's, id for id,
    for scripts/mirror-prod-local.sh.
"""

from __future__ import annotations

import json
import re
from typing import Any

import pytest

from python.pipeline import export_seed
from python.pipeline.promotion import refresh as rf

ROSTER = [
    {
        "id_fencer": 30,
        "txt_surname": "BUJKO",
        "txt_first_name": "Paulina",
        "int_birth_year": 1982,
        "bool_birth_year_estimated": False,
        "enum_gender": "F",
        "txt_nationality": "PL",
        "txt_club": None,
        "json_name_aliases": [],
        "json_revoked_aliases": [],
        "json_user_confirmed_aliases": [],
        "ts_created": "2026-01-01T00:00:00+00:00",
        "ts_updated": "2026-10-03T10:00:00+00:00",
    },
    {
        "id_fencer": 124,
        "txt_surname": "KIEROŃSKI",
        "txt_first_name": "Tomasz",
        "int_birth_year": 1986,
        "bool_birth_year_estimated": False,
        "enum_gender": "M",
        "txt_nationality": "PL",
        "txt_club": "O'Klub",
        "json_name_aliases": ["KIERONSKI Tomasz"],
        "json_revoked_aliases": [],
        "json_user_confirmed_aliases": [],
        "ts_created": "2026-01-01T00:00:00+00:00",
        "ts_updated": "2026-10-03T10:00:00+00:00",
    },
]


def _cols(*spec: tuple[str, str]) -> list[dict]:
    """information_schema rows; the first column is the table's own sequence id."""
    return [
        {
            "column_name": name,
            "data_type": dtype,
            "column_default": "nextval('seq')" if i == 0 else None,
            "udt_name": "enum_age_category" if dtype == "USER-DEFINED" else dtype,
        }
        for i, (name, dtype) in enumerate(spec)
    ]


COLUMNS = {
    "tbl_fencer": _cols(("id_fencer", "integer"), ("txt_surname", "text")),
    "tbl_tournament": _cols(
        ("id_tournament", "integer"), ("id_event", "integer"), ("txt_code", "text")
    ),
    "tbl_result": _cols(
        ("id_result", "integer"),
        ("id_fencer", "integer"),
        ("id_tournament", "integer"),
        ("int_place", "integer"),
        ("enum_source_age_category", "USER-DEFINED"),
    ),
}


def _fake_query(roster: list[dict]) -> Any:
    def query(_ref: str, _token: str, sql: str) -> list[dict]:
        if "information_schema.columns" in sql:
            table = re.search(r"table_name = '(\w+)'", sql)
            return COLUMNS.get(table.group(1), []) if table else []
        if "to_jsonb(f)" in sql:
            return [{"j": json.dumps(roster, ensure_ascii=False)}]
        if "tbl_fencer_id_fencer_seq" in sql:
            return [{"j": 367}]
        if "FROM tbl_tournament t" in sql:
            return [
                {
                    "id_tournament": 9,
                    "event_code": "PPW1-2025-2026",
                    "txt_code": "PPW1-V2-F-SABRE-2025-2026",
                }
            ]
        if "FROM tbl_result r" in sql:
            return [
                {
                    "tourn_code": "PPW1-V2-F-SABRE-2025-2026",
                    "id_fencer": 30,
                    "int_place": 1,
                    "num_final_score": 50,
                    "enum_source_age_category": None,
                }
            ]
        return []

    return query


@pytest.fixture
def dump(monkeypatch: pytest.MonkeyPatch) -> str:
    monkeypatch.setattr(export_seed, "mgmt_query", _fake_query(ROSTER))
    return export_seed.export_monolithic("prod", "token")


def _load_call(sql: str) -> tuple[list[dict], int]:
    m = re.search(r"SELECT fn_seed_load_fencers\((\$\w*\$)(.*?)\1::jsonb, (\d+)\);", sql, re.S)
    assert m, "the seed loads its fencers through fn_seed_load_fencers"
    return json.loads(m.group(2)), int(m.group(3))


class TestFencers:
    def test_the_seed_loads_prods_roster_at_prods_ids_with_prods_sequence(self, dump: str):
        """PROMO.SEED.01"""
        roster, sequence = _load_call(dump)
        assert [r["id_fencer"] for r in roster] == [30, 124]
        assert roster == ROSTER
        assert sequence == 367
        assert "INSERT INTO tbl_fencer" not in dump

    def test_the_roster_literal_survives_any_content(self, monkeypatch: pytest.MonkeyPatch):
        """PROMO.SEED.03 — a dollar-quote tag the content contains is never used."""
        odd = [dict(ROSTER[0], txt_club="$roster$ and $r1$")]
        monkeypatch.setattr(export_seed, "mgmt_query", _fake_query(odd))
        roster, _ = _load_call(export_seed.export_monolithic("prod", "token"))
        assert roster == odd


class TestResults:
    def test_every_result_names_its_fencer_by_id(self, dump: str):
        """PROMO.SEED.02 — the name-and-birth-year lookup is retired for fencers."""
        result = next(
            line for line in dump.splitlines() if line.startswith("INSERT INTO tbl_result")
        )
        assert result.startswith("INSERT INTO tbl_result (id_fencer, id_tournament, int_place")
        assert "SELECT 30, (SELECT id_tournament FROM tbl_tournament" in result
        assert "WHERE id_fencer = 30 AND id_tournament" in result
        assert "FROM tbl_fencer" not in result
        assert not hasattr(export_seed, "fencer_lookup")


class _Rosters:
    def __init__(self, rows: list[dict]):
        self.rows = rows

    def roster(self) -> list[dict]:
        return self.rows


class TestVerify:
    def test_equal_rosters_verify(self):
        """PROMO.SEED.04"""
        diff = rf.run_verify(_Rosters(ROSTER), _Rosters([dict(r) for r in ROSTER]))
        assert diff.equal

    def test_any_difference_by_id_is_named(self):
        """PROMO.SEED.05 — the same two people at swapped ids are a difference."""
        moved = [dict(ROSTER[0], id_fencer=124), dict(ROSTER[1], id_fencer=30)]
        diff = rf.run_verify(_Rosters(ROSTER), _Rosters(moved))
        assert not diff.equal
        text = "\n".join(diff.lines("target", "PROD"))
        assert "30" in text and "124" in text
