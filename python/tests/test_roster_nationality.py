"""RNAT.09–RNAT.16 (FR-172): the roster's nationality, one spelling, kept to the EVF ranking.

Plan doc/plans/roster-nationality-from-evf-2026-11-22.html (rev 3; N1–N9 signed
22 Nov). A fencer's `tbl_fencer.txt_nationality` is a three-letter code, POL for
Poland (never PL). Each month, after the EVF ranking is read, a roster fencer
who matches exactly one ranked fencer (folded name, same gender, an EVF
category that the fencer's birth year gives in the active season or the one
before) takes EVF's country; OTH and anything that is not a fencing code are
never written; a fencer without a birth year is never changed.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import yaml

from python.pipeline.international_admission import roster_nationality
from python.tools import unify_roster_nationality as rule

REPO = Path(__file__).resolve().parents[2]
CODES = {"POL", "HUN", "IRL", "USA", "GER", "SVK"}


def _f(
    fid: int, surname: str, first: str, by: int | None, nat: str, gender: str = "M"
) -> dict[str, Any]:
    return {
        "id": fid,
        "surname": surname,
        "first_name": first,
        "gender": gender,
        "birth_year": by,
        "nationality": nat,
    }


class FakeClient:
    """Answers each of the 24 EVF lists with the same rows."""

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows

    def connect(self) -> None:
        return None

    def get_ranking_list(self, weapon_id: int, category_id: int) -> list[dict[str, Any]]:
        del weapon_id, category_id  # every list answers the same rows
        return list(self.rows)


def _row(fid: str, name: str, first: str) -> dict[str, Any]:
    return {
        "id": fid,
        "name": name,
        "firstname": first,
        "country": "HUN",
        "dob": None,
        "points": 1.0,
        "pos": 1,
    }


def _e(
    eid: str, surname: str, first: str, category: int, country: str, gender: str = "M"
) -> dict[str, Any]:
    return {
        "id": eid,
        "surname": surname,
        "first_name": first,
        "gender": gender,
        "category": category,
        "country": country,
    }


# ---------------------------------------------------------------------------
# RNAT.09 — one spelling for a new fencer's nationality.
# ---------------------------------------------------------------------------
def test_rnat_09_a_new_fencers_nationality_is_three_letters_and_pol_by_default() -> None:
    assert roster_nationality("PL") == "POL"
    assert roster_nationality(" pol ") == "POL"
    assert roster_nationality("UKR") == "UKR"
    assert roster_nationality(None) == "POL"
    assert roster_nationality("") == "POL"
    assert roster_nationality("Poland") == "POL"  # not a code: the roster's default


# ---------------------------------------------------------------------------
# RNAT.10 — no code path creates a fencer as PL.
# ---------------------------------------------------------------------------
def test_rnat_10_no_fencer_creation_path_writes_pl() -> None:
    offenders: list[str] = []
    pattern = re.compile(
        r"""(txt_nationality|"nationality")[^\n]*["']PL["']|get\("country",\s*["']PL["']\)"""
    )
    for path in sorted((REPO / "python").rglob("*.py")):
        rel = path.relative_to(REPO).as_posix()
        if "/tests/" in rel or rel.endswith("staging_spreadsheet.py"):  # mock rows, never stored
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if pattern.search(line):
                offenders.append(f"{rel}:{n}: {line.strip()}")
    assert offenders == []


def test_rnat_10_promote_plans_a_new_fencer_with_the_tables_default() -> None:
    from python.pipeline.promotion import plan

    assert plan._FENCER_DEFAULTS["txt_nationality"] == "POL"  # pyright: ignore[reportPrivateUsage]


# ---------------------------------------------------------------------------
# RNAT.11 — a unique match takes EVF's country.
# ---------------------------------------------------------------------------
def test_rnat_11_a_unique_match_takes_evfs_country() -> None:
    roster = [_f(5, "ALCSÉR", "Norbert", 1985, "POL"), _f(7, "NOWAK", "Jan", 1970, "POL")]
    evf = [_e("u1", "ALCSER", "Norbert", 1, "HUN"), _e("u2", "NOWAK", "Jan", 3, "POL")]
    changes = rule.decide(roster, evf, CODES, season_end=2027)
    assert [(c.id, c.old, c.new) for c in changes] == [(5, "POL", "HUN")]


def test_rnat_11_the_season_before_counts_too() -> None:
    # 1967 is V3 in 2026/27 (aged 60) and V2 in 2025/26 (59): either EVF category matches.
    roster = [_f(1, "MURRAY", "Claire", 1967, "POL", gender="F")]
    for category in (2, 3):
        evf = [_e("u", "MURRAY", "Claire", category, "IRL", gender="F")]
        assert [c.new for c in rule.decide(roster, evf, CODES, season_end=2027)] == ["IRL"]


# ---------------------------------------------------------------------------
# RNAT.12 — everything uncertain is left alone (the five decided 22 Nov included).
# ---------------------------------------------------------------------------
def test_rnat_12_uncertain_rows_change_nothing() -> None:
    roster = [
        _f(143, "KOS", "Lukasz", 1983, "POL"),  # two ranked fencers of this name
        _f(354, "KRAW", "Pawel", 1989, "POL"),  # EVF's namesake is V4
        _f(320, "WHIT", "Gary", 1961, "USA"),  # EVF says OTH
        _f(9, "GOLD", "Oleg", None, "POL"),  # no birth year
        _f(10, "LEAH", "John", 1969, "POL", gender="M"),  # EVF's namesake is a woman
        _f(11, "SAME", "Anna", 1970, "HUN", gender="F"),  # already EVF's
        _f(12, "ODD", "Piotr", 1970, "POL"),  # EVF code that is no fencing code
    ]
    evf = [
        _e("a", "KOS", "Lukasz", 1, "POL"),
        _e("b", "KOS", "Lukasz", 1, "GER"),
        _e("c", "KRAW", "Pawel", 4, "SVK"),
        _e("d", "WHIT", "Gary", 3, "OTH"),
        _e("e", "GOLD", "Oleg", 2, "ISR"),
        _e("f", "LEAH", "John", 2, "GBR", gender="F"),
        _e("g", "SAME", "Anna", 2, "HUN", gender="F"),
        _e("h", "ODD", "Piotr", 2, "XYZ"),
    ]
    assert rule.decide(roster, evf, CODES | {"ISR", "GBR"}, season_end=2027) == []


def test_rnat_12_a_stored_pl_reads_as_pol() -> None:
    roster = [_f(1, "NOWAK", "Jan", 1970, "PL")]
    evf = [_e("u", "NOWAK", "Jan", 2, "POL")]
    assert rule.decide(roster, evf, CODES, season_end=2027) == []


# ---------------------------------------------------------------------------
# RNAT.13 — the write names each fencer's id and current value.
# ---------------------------------------------------------------------------
def test_rnat_13_the_update_is_guarded_by_id_and_current_value() -> None:
    sql = rule.apply_sql([rule.Change(5, "ALCSÉR Norbert", "POL", "HUN")])
    assert sql is not None
    assert "UPDATE tbl_fencer f SET txt_nationality = v.new" in sql
    assert "(5, 'POL', 'HUN')" in sql
    assert "f.id_fencer = v.id AND f.txt_nationality = v.old" in sql
    assert "RETURNING" in sql
    assert not re.search(r"\b(DELETE|INSERT|TRUNCATE|DROP)\b", sql)
    assert rule.apply_sql([]) is None


def test_rnat_13_the_read_takes_the_active_season_and_the_ranking() -> None:
    sql = rule.read_sql()
    assert "fn_active_season_id()" in sql
    assert "FROM tbl_fencer" in sql and "FROM tbl_evf_ranking_fencer" in sql
    assert "FROM tbl_fencing_country" in sql


# ---------------------------------------------------------------------------
# RNAT.14 — the monthly job keeps the roster unified and reports each change.
# ---------------------------------------------------------------------------
def test_rnat_14_run_unifies_each_environment_after_the_fencers_and_reports() -> None:
    """Amended by FR-174 (EVFSEED.19): the places are sent after the ranked
    fencers and before the roster rule."""
    import json

    from python.tools import extract_evf_given_names as job

    data = {
        "season_end": 2027,
        "fencers": [_f(5, "ALCSER", "Norbert", 1985, "POL")],
        "evf": [_e("u1", "ALCSER", "Norbert", 1, "HUN")],
        "codes": sorted(CODES),
    }
    sent: list[tuple[str, str]] = []
    messages: list[str] = []

    def query(ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        sent.append((ref, sql))
        if "tbl_common_given_name" in sql:
            return [{"txt_name": "Norbert"}]
        if sql.startswith("INSERT INTO tbl_evf_ranking_fencer"):
            return [{"id_evf": "u1"}]
        if sql.startswith("SELECT fn_replace_evf_ranking_places"):
            return [{"n": 24}]
        if sql.startswith("SELECT jsonb_build_object"):
            return [{"j": json.dumps(data)}]
        return [{"j": json.dumps([{"id_fencer": 5, "old": "POL", "txt_nationality": "HUN"}])}]

    report = job.run(
        FakeClient([_row("u1", "ALCSER", "Norbert")]),
        query,
        token="t",
        refs={"CERT": "cert-ref", "PROD": "prod-ref"},
        notify=messages.append,
    )
    kinds = [
        s.split(" ")[0] + " " + s.split(" ")[2]
        if s.startswith("INSERT")
        else s.split("(")[0]
        if s.startswith("SELECT fn_replace")
        else s.split(" ")[0]
        for _, s in sent
    ]
    assert (
        kinds
        == [
            "INSERT tbl_common_given_name",
            "INSERT tbl_evf_ranking_fencer",
            "SELECT fn_replace_evf_ranking_places",
            "SELECT",
            "WITH",
        ]
        * 2
    )
    assert [r for r, _ in sent] == ["cert-ref"] * 5 + ["prod-ref"] * 5
    assert report["PROD"] == {"names": 1, "fencers": 1, "places": 24, "roster": 1}
    assert len(messages) == 1
    assert "roster countries" in messages[0]
    assert "5 ALCSER Norbert POL→HUN" in messages[0]


def test_rnat_14_nothing_to_change_sends_no_update() -> None:
    import json

    from python.tools import extract_evf_given_names as job

    data = {"season_end": 2027, "fencers": [], "evf": [], "codes": []}
    sent: list[str] = []

    def query(_ref: str, _token: str, sql: str) -> list[dict[str, Any]]:
        sent.append(sql)
        return [{"j": json.dumps(data)}] if sql.startswith("SELECT") else [{"x": 1}]

    report = job.run(
        FakeClient([_row("u", "X", "Anna")]), query, "t", {"CERT": "c"}, lambda _m: None
    )
    assert not any(s.startswith("WITH") for s in sent)
    assert report["CERT"]["roster"] == 0


# ---------------------------------------------------------------------------
# RNAT.15 — one environment per job; each job holds its environment's write lane.
# ---------------------------------------------------------------------------
def test_rnat_15_env_picks_one_environment() -> None:
    from python.tools import extract_evf_given_names as job

    env = {"SUPABASE_CERT_REF": "c", "SUPABASE_PROD_REF": "p"}
    assert job.refs_for("cert", env) == {"CERT": "c"}
    assert job.refs_for("prod", env) == {"PROD": "p"}
    assert job.refs_for(None, env) == {"CERT": "c", "PROD": "p"}
    assert job.refs_for("prod", {"SUPABASE_CERT_REF": "c"}) == {"PROD": ""}


def test_rnat_15_the_workflow_runs_cert_then_prod_in_their_write_lanes() -> None:
    """Amended by FR-174 (EVFSEED.22): each run line also passes $IF_DUE, which
    is --if-due on a scheduled run and empty on a run started by hand."""
    wf = yaml.safe_load(
        (REPO / ".github/workflows/evf-ranking-sync.yml").read_text(encoding="utf-8")
    )
    jobs = wf["jobs"]
    assert set(jobs) == {"cert", "prod"}
    assert jobs["cert"]["concurrency"]["group"] == "cert-write"
    assert jobs["prod"]["concurrency"]["group"] == "prod-write"
    assert jobs["prod"]["needs"] == "cert"
    for name, ref in (("cert", "SUPABASE_CERT_REF"), ("prod", "SUPABASE_PROD_REF")):
        run_step = next(s for s in jobs[name]["steps"] if s.get("id") == "sync")
        assert (
            run_step["run"]
            == f"python -m python.tools.extract_evf_given_names --env {name} $IF_DUE"
        )
        assert ref in run_step["env"]
        install = next(s for s in jobs[name]["steps"] if s.get("name") == "Install dependencies")
        assert "rapidfuzz" in install["run"]  # the matcher's name folding


# ---------------------------------------------------------------------------
# RNAT.16 — the LOCAL seed keeps an administrator's season nationality.
# ---------------------------------------------------------------------------
def test_rnat_16_the_seed_export_writes_admin_season_rows_only() -> None:
    from python.pipeline import export_seed

    sql = export_seed.admin_nationality_lines(
        [{"id_fencer": 140, "season_code": "SPWS-2025-2026", "txt_country": "POL"}]
    )
    assert sql[0].startswith("-- tbl_fencer_nationality (1 administrator's row")
    assert (
        "(140, (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'), 'POL', 'ADMIN')"
        in sql[1]
    )
    assert "ON CONFLICT (id_fencer, id_season) DO UPDATE" in sql[1]
    assert export_seed.ADMIN_NATIONALITY_SQL.count("enum_source = 'ADMIN'") == 1


def test_rnat_16_the_current_seed_carries_the_decisions_of_22_nov() -> None:
    text = (REPO / "supabase/seed_prod_latest.sql").read_text(encoding="utf-8")
    assert '"txt_nationality": "PL"' not in text
    assert text.count("'ADMIN')") == 2
