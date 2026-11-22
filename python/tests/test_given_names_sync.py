"""RFNAME.24–27 (FR-167) and EVFCTRY.02–05 (FR-171): the monthly read of the EVF ranking.

The job reads the 24 EVF ranking lists (6 weapon-and-gender lists × 4
categories). It inserts the given names not yet held into tbl_common_given_name
(never deleting or updating one), and since FR-171 keeps each ranked fencer's
EVF id, names, gender, category and country in tbl_evf_ranking_fencer, on CERT
and PROD.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import pytest
import yaml

from python.tools import extract_evf_given_names as job

REPO = Path(__file__).resolve().parents[2]

# The roster rule's read (FR-172), answered with nothing to change.
_ROSTER = [{"j": '{"season_end": 2027, "fencers": [], "evf": [], "codes": []}'}]


def _row(
    fid: int | str,
    name: str,
    first: str,
    country: str = "HUN",
    dob: str | None = "1970-01-01",
    gender: str = "M",
    cat: int = 2,
) -> dict[str, Any]:
    return {
        "id": fid,
        "name": name,
        "firstname": first,
        "country": country,
        "dob": dob,
        "points": 10.0,
        "pos": 1,
        "gender": gender,
        "cat": cat,
        "weapon": 2,
    }


class FakeClient:
    """Answers each of the 24 lists with the rows a test gives it."""

    def __init__(self, rows: list[dict[str, Any]] | None = None, fail: bool = False) -> None:
        self.rows = rows or []
        self.fail = fail
        self.calls: list[tuple[int, int]] = []

    def connect(self) -> None:
        if self.fail:
            raise RuntimeError("EVF refused")

    def get_ranking_list(self, weapon_id: int, category_id: int) -> list[dict[str, Any]]:
        self.calls.append((weapon_id, category_id))
        return list(self.rows)


# ---------------------------------------------------------------------------
# RFNAME.25 — given names only.
# ---------------------------------------------------------------------------
def test_rfname_25_keeps_given_names_only() -> None:
    rows = [
        _row(1, "KOVÁCS", "Péter"),
        _row(2, "NAGY", "Péter"),  # the same name twice is one name
        _row(3, "SMITH", "J."),  # initials
        _row(4, "BROWN", "J P"),  # initials
        _row(5, "MARTIN", "Pierre"),
        _row(6, "THOMAS", "Martin"),  # „Martin” is a surname twice here, a given name once
        _row(7, "MARTIN", "Paul"),
        _row(8, "VITÀLYOS", "eszter zsuzsanna"),
    ]
    names = job.given_names(rows)
    assert names == ["Eszter Zsuzsanna", "Paul", "Péter", "Pierre"]
    assert all(isinstance(n, str) for n in names)


def test_rfname_25_nothing_but_the_name_leaves_the_tool() -> None:
    sql = job.build_insert_sql(
        job.given_names([_row(1, "KOVÁCS", "Péter", country="HUN", dob="1971-02-03")])
    )
    assert "KOVÁCS" not in sql
    assert "HUN" not in sql
    assert "1971" not in sql
    assert "'Péter'" in sql


# ---------------------------------------------------------------------------
# RFNAME.24 — insert-only.
# ---------------------------------------------------------------------------
def test_rfname_24_the_statement_only_inserts_unseen_names() -> None:
    sql = job.build_insert_sql(["Péter", "O'Neil"])
    assert sql.startswith("INSERT INTO tbl_common_given_name (txt_name, txt_source) VALUES")
    assert "('O''Neil', 'EVF')" in sql
    assert "ON CONFLICT (txt_name_key) DO NOTHING" in sql
    assert not re.search(r"\b(DELETE|UPDATE|TRUNCATE|DROP)\b", sql, re.IGNORECASE)


def test_rfname_24_run_sends_the_names_then_the_fencers_to_each_environment() -> None:
    """Amended by FR-171 (plan evf-ranking-country-lomianki rev 1, D1 A): each
    environment gets the insert-only given names, then the ranked fencers.
    Amended by FR-172 (plan roster-nationality-from-evf rev 3, N5 A): then the
    roster rule reads (and writes only when a fencer changes, RNAT.14)."""
    sent: list[tuple[str, str]] = []

    def query(ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        sent.append((ref, sql))
        if sql.startswith("SELECT jsonb_build_object"):
            return _ROSTER
        return [{"txt_name": "Péter"}] if "tbl_common_given_name" in sql else [{"id_evf": 1}]

    client = FakeClient([_row(1, "KOVÁCS", "Péter")])
    report = job.run(
        client,
        query,
        token="t",
        refs={"CERT": "cert-ref", "PROD": "prod-ref"},
        notify=lambda _m: None,
    )
    assert [r for r, _ in sent] == ["cert-ref"] * 3 + ["prod-ref"] * 3
    assert [s.split(" (")[0] for _, s in sent] == [
        "INSERT INTO tbl_common_given_name",
        "INSERT INTO tbl_evf_ranking_fencer",
        "SELECT jsonb_build_object('season_end',",
    ] * 2
    assert report == {
        "CERT": {"names": 1, "fencers": 1, "roster": 0},
        "PROD": {"names": 1, "fencers": 1, "roster": 0},
    }
    assert sorted(set(client.calls)) == [(w, c) for w in range(1, 7) for c in range(1, 5)]


# ---------------------------------------------------------------------------
# RFNAME.26 — reports its count; fails loudly.
# ---------------------------------------------------------------------------
def test_rfname_26_reports_the_number_added_per_environment() -> None:
    messages: list[str] = []

    def query(ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        if sql.startswith("SELECT jsonb_build_object"):
            return _ROSTER  # FR-172: the roster rule's read
        return [{"txt_name": "A"}, {"txt_name": "B"}] if ref == "cert-ref" else []

    _ = job.run(
        FakeClient([_row(1, "X", "Anna")]),
        query,
        token="t",
        refs={"CERT": "cert-ref", "PROD": "prod-ref"},
        notify=messages.append,
    )
    assert len(messages) == 1
    assert "CERT: 2" in messages[0]
    assert "PROD: 0" in messages[0]
    assert "fencers" in messages[0]


def test_rfname_26_a_refusal_alerts_and_exits_non_zero() -> None:
    messages: list[str] = []
    with pytest.raises(SystemExit) as exc:
        _ = job.run(
            FakeClient(fail=True),
            lambda *_a: [],
            token="t",
            refs={"CERT": "c", "PROD": "p"},
            notify=messages.append,
        )
    assert exc.value.code != 0
    assert messages and "FAILED" in messages[0]


def test_rfname_26_empty_lists_are_a_failure_not_zero_names() -> None:
    messages: list[str] = []
    with pytest.raises(SystemExit) as exc:
        _ = job.run(
            FakeClient([]),
            lambda *_a: [],
            token="t",
            refs={"CERT": "c", "PROD": "p"},
            notify=messages.append,
        )
    assert exc.value.code != 0
    assert messages and "FAILED" in messages[0]


# ---------------------------------------------------------------------------
# RFNAME.27 — the workflow: monthly, off the hour, both environments.
# ---------------------------------------------------------------------------
def test_rfname_27_the_workflow_runs_monthly_off_the_hour_on_both_environments() -> None:
    """Amended by FR-171 (EVFCTRY.05): renamed evf-ranking-sync.yml for what it reads."""
    assert not (REPO / ".github/workflows/given-names-sync.yml").exists()
    wf = yaml.safe_load(
        (REPO / ".github/workflows/evf-ranking-sync.yml").read_text(encoding="utf-8")
    )
    triggers = wf.get("on") or wf.get(True)
    crons = [s["cron"] for s in triggers["schedule"]]
    assert len(crons) == 1
    minute, _hour, dom, month, dow = crons[0].split()
    assert minute not in ("0", "*") and dom.isdigit() and month == "*" and dow == "*"
    text = (REPO / ".github/workflows/evf-ranking-sync.yml").read_text(encoding="utf-8")
    assert "SUPABASE_CERT_REF" in text and "SUPABASE_PROD_REF" in text
    assert "python -m python.tools.extract_evf_given_names" in text


# ---------------------------------------------------------------------------
# EVFCTRY.02 — what is kept of each ranked fencer (FR-171).
# ---------------------------------------------------------------------------
def test_evfctry_02_keeps_id_names_gender_category_and_country_only() -> None:
    fencers = job.ranking_fencers(
        [
            _row(
                "00000000-0000-4000-8000-000000000007",
                "MÜLLER",
                "Hans",
                country="GER",
                gender="M",
                cat=3,
            ),
            _row(
                "00000000-0000-4000-8000-000000000007",
                "MÜLLER",
                "Hans",
                country="GER",
                gender="M",
                cat=3,
            ),  # a second weapon list
            _row(
                "00000000-0000-4000-8000-000000000009",
                "ROSSI",
                "Anna",
                country="OTH",
                gender="F",
                cat=1,
            ),
        ]
    )
    assert fencers == [
        {
            "id": "00000000-0000-4000-8000-000000000007",
            "surname": "MÜLLER",
            "first_name": "Hans",
            "gender": "M",
            "category": 3,
            "country": "GER",
        },
        {
            "id": "00000000-0000-4000-8000-000000000009",
            "surname": "ROSSI",
            "first_name": "Anna",
            "gender": "F",
            "category": 1,
            "country": "OTH",
        },
    ]


def test_evfctry_02_no_points_place_or_birth_date_reach_the_statement() -> None:
    sql = job.build_fencer_upsert_sql(
        job.ranking_fencers(
            [_row("00000000-0000-4000-8000-000000000007", "MÜLLER", "Hans", dob="1961-04-05")]
        )
    )
    assert "1961" not in sql
    assert "10.0" not in sql
    assert "('00000000-0000-4000-8000-000000000007', 'MÜLLER', 'Hans', 'M', 2, 'HUN')" in sql


# ---------------------------------------------------------------------------
# EVFCTRY.03 — insert or update by EVF id; never delete.
# ---------------------------------------------------------------------------
def test_evfctry_03_the_statement_upserts_by_evf_id_and_never_deletes() -> None:
    sql = job.build_fencer_upsert_sql(
        job.ranking_fencers(
            [_row("00000000-0000-4000-8000-000000000007", "O'NEIL", "Seán", country="IRL")]
        )
    )
    assert sql.startswith(
        "INSERT INTO tbl_evf_ranking_fencer (id_evf, txt_surname, txt_first_name, enum_gender, int_category, txt_country) VALUES"
    )
    assert "'O''NEIL'" in sql
    assert "ON CONFLICT (id_evf) DO UPDATE SET" in sql
    assert "ts_read = now()" in sql
    assert "RETURNING id_evf" in sql
    assert not re.search(r"\b(DELETE|TRUNCATE|DROP)\b", sql, re.IGNORECASE)


# ---------------------------------------------------------------------------
# EVFCTRY.04 — both counts reported per environment; a refusal alerts; --local.
# ---------------------------------------------------------------------------
def test_evfctry_04_a_refused_fencer_write_alerts_and_exits_non_zero() -> None:
    messages: list[str] = []

    def query(_ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        if "tbl_evf_ranking_fencer" in sql:
            raise RuntimeError("permission denied")
        return []

    with pytest.raises(SystemExit) as exc:
        _ = job.run(
            FakeClient([_row(1, "X", "Anna")]),
            query,
            token="t",
            refs={"CERT": "c"},
            notify=messages.append,
        )
    assert exc.value.code != 0
    assert messages and "FAILED" in messages[0] and "CERT" in messages[0]


def test_evfctry_04_local_writes_both_statements_to_local_only() -> None:
    """Amended by FR-172 (N5 A): LOCAL's roster rule runs too."""
    sent: list[str] = []

    def query(sql: str) -> list[dict[str, Any]]:
        sent.append(sql)
        return _ROSTER if sql.startswith("SELECT jsonb_build_object") else []

    report = job.run_local(FakeClient([_row(1, "KOVÁCS", "Péter")]), query)
    assert [s.split(" (")[0] for s in sent] == [
        "INSERT INTO tbl_common_given_name",
        "INSERT INTO tbl_evf_ranking_fencer",
        "SELECT jsonb_build_object('season_end',",
    ]
    assert report == {"LOCAL": {"names": 0, "fencers": 0, "roster": 0}}


def test_evfctry_02_each_row_takes_its_lists_gender_and_category() -> None:
    """Live EVF rows carry no gender or category (seen 22 Nov: id, name,
    firstname, country, dob, points, pos); both are the list's own."""
    bare = {
        "id": "00000000-0000-4000-8000-000000000007",
        "name": "KOVÁCS",
        "firstname": "Eva",
        "country": "HUN",
        "dob": None,
        "points": 1.0,
        "pos": 1,
    }
    rows = job.read_ranking(FakeClient([bare]))
    tags = sorted({(r["gender"], r["cat"]) for r in rows})
    assert tags == [(g, c) for g in ("F", "M") for c in range(1, 5)]
    assert all(r["gender"] == ("M" if r["weapon"] <= 3 else "F") for r in rows)
    assert "gender" not in bare and "cat" not in bare  # the client's rows are not changed in place
