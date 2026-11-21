"""RFNAME.24–27 (FR-167): the monthly read of the EVF ranking's given names.

The job reads the 24 EVF ranking lists (6 weapon-and-gender lists × 4
categories), keeps the given names only, and inserts the ones not yet held into
tbl_common_given_name on CERT and PROD. It never deletes or updates a name.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import pytest
import yaml

from python.tools import extract_evf_given_names as job

REPO = Path(__file__).resolve().parents[2]


def _row(
    fid: int, name: str, first: str, country: str = "HUN", dob: str | None = "1970-01-01"
) -> dict[str, Any]:
    return {
        "id": fid,
        "name": name,
        "firstname": first,
        "country": country,
        "dob": dob,
        "points": 10.0,
        "pos": 1,
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


def test_rfname_24_run_sends_one_insert_per_environment_and_nothing_else() -> None:
    sent: list[tuple[str, str]] = []

    def query(ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        sent.append((ref, sql))
        return [{"txt_name": "Péter"}]

    client = FakeClient([_row(1, "KOVÁCS", "Péter")])
    report = job.run(
        client,
        query,
        token="t",
        refs={"CERT": "cert-ref", "PROD": "prod-ref"},
        notify=lambda _m: None,
    )
    assert [r for r, _ in sent] == ["cert-ref", "prod-ref"]
    assert all(s.startswith("INSERT INTO tbl_common_given_name") for _, s in sent)
    assert report == {"CERT": 1, "PROD": 1}
    assert sorted(set(client.calls)) == [(w, c) for w in range(1, 7) for c in range(1, 5)]


# ---------------------------------------------------------------------------
# RFNAME.26 — reports its count; fails loudly.
# ---------------------------------------------------------------------------
def test_rfname_26_reports_the_number_added_per_environment() -> None:
    messages: list[str] = []

    def query(ref: str, _token: str, _sql: str) -> list[dict[str, Any]]:
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
    wf = yaml.safe_load(
        (REPO / ".github/workflows/given-names-sync.yml").read_text(encoding="utf-8")
    )
    triggers = wf.get("on") or wf.get(True)
    crons = [s["cron"] for s in triggers["schedule"]]
    assert len(crons) == 1
    minute, _hour, dom, month, dow = crons[0].split()
    assert minute not in ("0", "*") and dom.isdigit() and month == "*" and dow == "*"
    text = (REPO / ".github/workflows/given-names-sync.yml").read_text(encoding="utf-8")
    assert "SUPABASE_CERT_REF" in text and "SUPABASE_PROD_REF" in text
    assert "python -m python.tools.extract_evf_given_names" in text
