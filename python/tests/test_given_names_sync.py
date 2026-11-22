"""RFNAME.24–27 (FR-167), EVFCTRY.02–05 (FR-171) and EVFSEED.17–22 (FR-174): the read of the EVF ranking.

The job reads the 24 EVF ranking lists (6 weapon-and-gender lists × 4
categories). It inserts the given names not yet held into tbl_common_given_name
(never deleting or updating one), and since FR-171 keeps each ranked fencer's
EVF id, names, gender, category and country in tbl_evf_ranking_fencer, on CERT
and PROD. Since FR-174 it also keeps each fencer's place and points per weapon
in tbl_evf_ranking_place, and a scheduled run reads only when a read is due.
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


def _kind(sql: str) -> str:
    """The statement's opening words, to tell the statements apart."""
    if sql.startswith("SELECT fn_replace_evf_ranking_places"):
        return "SELECT fn_replace_evf_ranking_places"
    return sql.split(" (")[0]


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
    roster rule reads (and writes only when a fencer changes, RNAT.14).
    Amended by FR-174 (EVFSEED.19): the places come after the ranked fencers and
    before the roster rule, and the report names how many were kept."""
    sent: list[tuple[str, str]] = []

    def query(ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        sent.append((ref, sql))
        if sql.startswith("SELECT jsonb_build_object"):
            return _ROSTER
        if sql.startswith("SELECT fn_replace_evf_ranking_places"):
            return [{"n": 24}]
        return [{"txt_name": "Péter"}] if "tbl_common_given_name" in sql else [{"id_evf": 1}]

    client = FakeClient([_row(1, "KOVÁCS", "Péter")])
    report = job.run(
        client,
        query,
        token="t",
        refs={"CERT": "cert-ref", "PROD": "prod-ref"},
        notify=lambda _m: None,
    )
    assert [r for r, _ in sent] == ["cert-ref"] * 4 + ["prod-ref"] * 4
    assert [_kind(s) for _, s in sent] == [
        "INSERT INTO tbl_common_given_name",
        "INSERT INTO tbl_evf_ranking_fencer",
        "SELECT fn_replace_evf_ranking_places",
        "SELECT jsonb_build_object('season_end',",
    ] * 2
    assert report == {
        "CERT": {"names": 1, "fencers": 1, "places": 24, "roster": 0},
        "PROD": {"names": 1, "fencers": 1, "places": 24, "roster": 0},
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
    assert "places kept" in messages[0]  # FR-174 (EVFSEED.19)


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
# RFNAME.27 / EVFSEED.22 — the workflow: daily check, off the hour, both
# environments, CERT before PROD.
# ---------------------------------------------------------------------------
def test_rfname_27_the_workflow_runs_off_the_hour_on_both_environments() -> None:
    """Amended by FR-171 (EVFCTRY.05): renamed evf-ranking-sync.yml for what it reads.
    Amended by FR-174 (EVFSEED.22): it wakes every day and a scheduled run reads
    only when a read is due (--if-due); a run started by hand always reads."""
    assert not (REPO / ".github/workflows/given-names-sync.yml").exists()
    wf = yaml.safe_load(
        (REPO / ".github/workflows/evf-ranking-sync.yml").read_text(encoding="utf-8")
    )
    triggers = wf.get("on") or wf.get(True)
    crons = [s["cron"] for s in triggers["schedule"]]
    assert len(crons) == 1
    minute, hour, dom, month, dow = crons[0].split()
    assert minute.isdigit() and minute != "0" and hour.isdigit()
    assert (dom, month, dow) == ("*", "*", "*")
    assert "workflow_dispatch" in triggers
    text = (REPO / ".github/workflows/evf-ranking-sync.yml").read_text(encoding="utf-8")
    assert "SUPABASE_CERT_REF" in text and "SUPABASE_PROD_REF" in text
    assert "python -m python.tools.extract_evf_given_names" in text


def test_evfseed_22_a_scheduled_run_asks_if_due_and_keeps_its_lanes() -> None:
    wf = yaml.safe_load(
        (REPO / ".github/workflows/evf-ranking-sync.yml").read_text(encoding="utf-8")
    )
    jobs = wf["jobs"]
    assert set(jobs) == {"cert", "prod"}
    assert jobs["prod"]["needs"] == "cert"
    assert jobs["cert"]["concurrency"]["group"] == "cert-write"
    assert jobs["prod"]["concurrency"]["group"] == "prod-write"
    for name, env in (("cert", "cert"), ("prod", "prod")):
        sync = next(s for s in jobs[name]["steps"] if s.get("id") == "sync")
        assert sync["env"]["IF_DUE"] == "${{ github.event_name == 'schedule' && '--if-due' || '' }}"
        assert "${{" not in sync["run"]
        assert f"--env {env}" in sync["run"] and "$IF_DUE" in sync["run"]


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
    """Amended by FR-172 (N5 A): LOCAL's roster rule runs too. Amended by FR-174
    (EVFSEED.19): the places too, before the roster rule."""
    sent: list[str] = []

    def query(sql: str) -> list[dict[str, Any]]:
        sent.append(sql)
        return _ROSTER if sql.startswith("SELECT jsonb_build_object") else []

    report = job.run_local(FakeClient([_row(1, "KOVÁCS", "Péter")]), query)
    assert [_kind(s) for s in sent] == [
        "INSERT INTO tbl_common_given_name",
        "INSERT INTO tbl_evf_ranking_fencer",
        "SELECT fn_replace_evf_ranking_places",
        "SELECT jsonb_build_object('season_end',",
    ]
    assert report == {"LOCAL": {"names": 0, "fencers": 0, "places": 0, "roster": 0}}


def _listed(
    fid: str, weapon_id: int, cat: int, pos: int = 1, points: float = 10.0
) -> dict[str, Any]:
    """A row as read_ranking hands it on: tagged with its list."""
    return {
        **_row(fid, "NOWAK", "Anna"),
        "weapon": weapon_id,
        "gender": "M" if weapon_id <= 3 else "F",
        "cat": cat,
        "pos": pos,
        "points": points,
    }


def _all_lists() -> list[dict[str, Any]]:
    return [
        _listed(f"00000000-0000-4000-8000-0000000000{w}{c}", w, c)
        for w in range(1, 7)
        for c in range(1, 5)
    ]


# ---------------------------------------------------------------------------
# EVFSEED.17–18 — the places per weapon (FR-174).
# ---------------------------------------------------------------------------
def test_evfseed_17_one_row_per_fencer_and_weapon_with_its_place_and_points() -> None:
    rows = _all_lists()
    rows[0] = _listed("00000000-0000-4000-8000-000000000011", 1, 1, pos=3, points=77.5)
    rows.append(_listed("00000000-0000-4000-8000-000000000011", 2, 1, pos=17, points=12))
    places = job.ranking_places(rows)
    mine = [p for p in places if p["id"] == "00000000-0000-4000-8000-000000000011"]
    assert mine == [
        {
            "id": "00000000-0000-4000-8000-000000000011",
            "weapon": "FOIL",
            "gender": "M",
            "category": 1,
            "place": 3,
            "points": 77.5,
        },
        {
            "id": "00000000-0000-4000-8000-000000000011",
            "weapon": "EPEE",
            "gender": "M",
            "category": 1,
            "place": 17,
            "points": 12.0,
        },
    ]
    assert {(p["weapon"], p["gender"]) for p in places} == {
        (w, g) for w in ("FOIL", "EPEE", "SABRE") for g in ("M", "F")
    }
    sql = job.build_places_sql(places)
    assert sql.startswith("SELECT fn_replace_evf_ranking_places('[")
    assert sql.endswith("]'::jsonb) AS n")
    assert "1961" not in sql and "dob" not in sql


def test_evfseed_18_an_incomplete_read_is_refused_before_anything_is_written() -> None:
    with pytest.raises(ValueError, match="23 of 24 lists"):
        _ = job.ranking_places(_all_lists()[1:])
    bad = _all_lists()
    bad[5] = {**bad[5], "pos": 0}
    with pytest.raises(ValueError, match="place 0"):
        _ = job.ranking_places(bad)

    class TwoListsClient(FakeClient):
        def get_ranking_list(self, weapon_id: int, category_id: int) -> list[dict[str, Any]]:
            self.calls.append((weapon_id, category_id))
            return [_row(1, "KOVÁCS", "Péter")] if (weapon_id, category_id) == (1, 1) else []

    sent: list[str] = []
    messages: list[str] = []
    with pytest.raises(SystemExit) as exc:
        _ = job.run(
            TwoListsClient(),
            lambda _r, _t, sql: sent.append(sql) or [],
            token="t",
            refs={"CERT": "c", "PROD": "p"},
            notify=messages.append,
        )
    assert exc.value.code != 0
    assert sent == []
    assert messages and "FAILED" in messages[0] and "incomplete" in messages[0]


# ---------------------------------------------------------------------------
# EVFSEED.20–21 — read only when a read is due (FR-174).
# ---------------------------------------------------------------------------
def test_evfseed_20_not_due_means_no_evf_request_no_statement_no_message() -> None:
    sent: list[str] = []
    messages: list[str] = []

    def query(_ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        sent.append(sql)
        return [{"due": None}]

    def no_client() -> job.RankingClient:
        raise AssertionError("EVF must not be asked")

    report = job.run_if_due(no_client, query, token="t", refs={"CERT": "c"}, notify=messages.append)
    assert report is None
    assert sent == [job.DUE_SQL]
    assert messages == []


def test_evfseed_21_due_means_the_read_runs_and_says_why() -> None:
    messages: list[str] = []

    def query(_ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        if sql == job.DUE_SQL:
            return [{"due": "7 days after PEW4fs-2026-2027"}]
        if sql.startswith("SELECT jsonb_build_object"):
            return _ROSTER
        if sql.startswith("SELECT fn_replace_evf_ranking_places"):
            return [{"n": 24}]
        return []

    report = job.run_if_due(
        lambda: FakeClient([_row(1, "KOVÁCS", "Péter")]),
        query,
        token="t",
        refs={"CERT": "c"},
        notify=messages.append,
    )
    assert report is not None and report["CERT"]["places"] == 24
    assert len(messages) == 1
    assert messages[0].startswith("EVF ranking read (7 days after PEW4fs-2026-2027):")


def test_evfseed_21_if_due_needs_one_environment(capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit) as exc:
        job.main(["--if-due"])
    assert exc.value.code == 2
    assert "--if-due needs --env" in capsys.readouterr().err


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
