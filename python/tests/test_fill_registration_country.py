"""EVFCTRY.06–08 (FR-171): an event's entries without a country, filled from the EVF ranking.

Plan doc/plans/evf-ranking-country-lomianki-2026-11-21.html (rev 1, D1–D6 A). An
entry takes a country only from exactly one ranked fencer of its name, of the
same gender, whose EVF category agrees with the declared year; a code that is
not a fencing code is never written and a stored country never overwritten. The
tool shows what it would do first and writes only with --apply.
"""

from __future__ import annotations

import json
from typing import Any

import pytest

from python.tools import fill_registration_country as tool

CODES = {"GER", "POL", "GBR", "HUN"}


def _entry(
    rid: int,
    surname: str,
    first: str,
    gender: str = "M",
    year: int = 1970,
    country: str | None = None,
) -> dict[str, Any]:
    return {
        "id": rid,
        "surname": surname,
        "first_name": first,
        "gender": gender,
        "birth_year": year,
        "country": country,
    }


def _fencer(
    fid: str, surname: str, first: str, country: str, gender: str = "M", category: int = 2
) -> dict[str, Any]:
    return {
        "id": fid,
        "surname": surname,
        "first_name": first,
        "gender": gender,
        "category": category,
        "country": country,
    }


def _decide(
    entries: list[dict[str, Any]], fencers: list[dict[str, Any]], season_end: int = 2027
) -> dict[int, tool.Decision]:
    return {d.id: d for d in tool.decide(entries, fencers, CODES, season_end)}


# ---------------------------------------------------------------------------
# EVFCTRY.06 — when an entry takes a country, and when not.
# ---------------------------------------------------------------------------
def test_evfctry_06_one_ranked_fencer_of_the_name_same_gender_agreeing_category_sets_it() -> None:
    # 1970 in season 2026/27 is V2 (aged 57): EVF category 2.
    d = _decide(
        [_entry(1, "MULLER", "hans")],
        [_fencer("00000000-0000-4000-8000-000000000007", "MÜLLER", "Hans", "GER")],
    )
    assert d[1].country == "GER"
    assert d[1].evf_id == "00000000-0000-4000-8000-000000000007"


def test_evfctry_06_the_category_of_the_season_before_also_agrees() -> None:
    # 1967: V2 for season end 2026 (aged 59), V3 for 2027 (aged 60); EVF still says 2.
    d = _decide(
        [_entry(1, "NOWAK", "Jan", year=1967)],
        [_fencer("00000000-0000-4000-8000-000000000007", "NOWAK", "Jan", "POL", category=2)],
    )
    assert d[1].country == "POL"


def test_evfctry_06_several_ranked_fencers_of_the_name_give_nothing() -> None:
    d = _decide(
        [_entry(1, "SMITH", "John")],
        [
            _fencer("00000000-0000-4000-8000-000000000007", "SMITH", "John", "GBR"),
            _fencer("00000000-0000-4000-8000-000000000008", "SMITH", "John", "GER"),
        ],
    )
    assert d[1].country is None
    assert "several" in d[1].why


def test_evfctry_06_a_gender_or_category_disagreement_gives_nothing() -> None:
    d = _decide(
        [_entry(1, "KOVACS", "Eva", gender="F"), _entry(2, "NAGY", "Peter", year=1990)],
        [
            _fencer("00000000-0000-4000-8000-000000000007", "KOVÁCS", "Eva", "HUN", gender="M"),
            _fencer("00000000-0000-4000-8000-000000000008", "NAGY", "Péter", "HUN", category=3),
        ],
    )
    assert d[1].country is None and "gender" in d[1].why
    assert d[2].country is None and "category" in d[2].why


def test_evfctry_06_a_code_that_is_not_a_fencing_code_is_never_written() -> None:
    d = _decide(
        [_entry(1, "ROSSI", "Marco")],
        [_fencer("00000000-0000-4000-8000-000000000007", "ROSSI", "Marco", "OTH")],
    )
    assert d[1].country is None
    assert "OTH" in d[1].why


def test_evfctry_06_a_stored_country_is_kept_even_when_evf_differs() -> None:
    d = _decide(
        [_entry(1, "MULLER", "Hans", country="POL")],
        [_fencer("00000000-0000-4000-8000-000000000007", "MULLER", "Hans", "GER")],
    )
    assert d[1].country is None
    assert "keeps POL" in d[1].why


def test_evfctry_06_an_entry_not_on_the_ranking_gets_nothing() -> None:
    d = _decide(
        [_entry(1, "ZZNOBODY", "Ann")],
        [_fencer("00000000-0000-4000-8000-000000000007", "MULLER", "Hans", "GER")],
    )
    assert d[1].country is None
    assert "not on the EVF ranking" in d[1].why


# ---------------------------------------------------------------------------
# EVFCTRY.07 — the read, the exact event code, nothing written without --apply.
# ---------------------------------------------------------------------------
def test_evfctry_07_the_event_must_be_named_by_its_exact_code() -> None:
    with pytest.raises(ValueError):
        _ = tool.read_sql("PEW5efs-2026-2027'; DROP TABLE x; --")
    assert "e.txt_code = 'PEW5efs-2026-2027'" in tool.read_sql("PEW5efs-2026-2027")


def _payload() -> str:
    return json.dumps(
        {
            "season_end": 2027,
            "entries": [_entry(1, "MULLER", "Hans"), _entry(2, "ROSSI", "Marco")],
            "fencers": [
                _fencer("00000000-0000-4000-8000-000000000007", "MÜLLER", "Hans", "GER"),
                _fencer("00000000-0000-4000-8000-000000000008", "ROSSI", "Marco", "OTH"),
            ],
            "codes": sorted(CODES),
        }
    )


def test_evfctry_07_without_apply_only_the_read_is_sent_and_each_entry_is_printed(
    capsys: pytest.CaptureFixture[str],
) -> None:
    sent: list[str] = []

    def query(sql: str) -> str:
        sent.append(sql)
        return _payload()

    tool.run("PEW5efs-2026-2027", query, apply=False)
    assert len(sent) == 1 and sent[0].startswith("SELECT")
    out = capsys.readouterr().out
    assert "1 MULLER Hans: set GER" in out
    assert "2 ROSSI Marco: nothing" in out
    assert "would set 1" in out


def test_evfctry_07_an_unknown_event_fails() -> None:
    with pytest.raises(SystemExit):
        tool.run(
            "PEW9-2099-2100",
            lambda _sql: json.dumps(
                {"season_end": None, "entries": [], "fencers": [], "codes": []}
            ),
            apply=False,
        )


# ---------------------------------------------------------------------------
# EVFCTRY.08 — --apply: one statement, only entries still without a country.
# ---------------------------------------------------------------------------
def test_evfctry_08_the_statement_sets_only_entries_still_without_a_country() -> None:
    decisions = tool.decide(
        [_entry(1, "MULLER", "Hans"), _entry(2, "NOWAK", "Jan")],
        [
            _fencer("00000000-0000-4000-8000-000000000007", "MULLER", "Hans", "GER"),
            _fencer("00000000-0000-4000-8000-000000000008", "NOWAK", "Jan", "POL"),
        ],
        CODES,
        2027,
    )
    sql = tool.apply_sql(decisions)
    assert sql is not None
    assert "UPDATE tbl_registration r SET txt_country = v.c" in sql
    assert "(1, 'GER'), (2, 'POL')" in sql
    assert "r.txt_country IS NULL" in sql
    assert "RETURNING" in sql


def test_evfctry_08_nothing_to_set_sends_no_statement() -> None:
    assert tool.apply_sql(tool.decide([_entry(1, "X", "Y")], [], CODES, 2027)) is None


def test_evfctry_08_apply_sends_the_read_then_the_update(
    capsys: pytest.CaptureFixture[str],
) -> None:
    sent: list[str] = []

    def query(sql: str) -> str:
        sent.append(sql)
        return (
            _payload()
            if sql.startswith("SELECT")
            else json.dumps([{"id_registration": 1, "txt_country": "GER"}])
        )

    tool.run("PEW5efs-2026-2027", query, apply=True)
    assert len(sent) == 2 and sent[1].startswith("WITH u AS (UPDATE tbl_registration")
    assert "set 1" in capsys.readouterr().out
