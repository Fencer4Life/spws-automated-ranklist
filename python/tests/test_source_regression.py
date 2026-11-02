"""SRC.REGR — the weekly re-read of every international source (ADR-119 G45 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G45 and the
push 2b build sheet (2b.7–2b.10).

On 1 Nov 2026 a hand re-read of the international events found four kinds of
drift no test or run had shown. G45 makes it a workflow: every international
event of the last 30 months is read and planned against CERT, nothing written,
and each tournament's planned rows are compared with CERT's, and CERT's result
fingerprint with PROD's:

  SRC.REGR.01  the events re-read: international, started in the last 30
               months, not cancelled;
  SRC.REGR.02  the upcoming events: international, starting within 14 days,
               each with whether it has a results link;
  SRC.REGR.03  a full re-read is due on demand, on Mondays, and the day
               before an international event starts;
  SRC.REGR.04  a tournament's planned rows and N against CERT's stored ones;
               the public difference names no fencer;
  SRC.REGR.05  an event's verdict: equal, different (rows, or CERT against
               PROD), refused, known (G51, G53), noted (G54);
  SRC.REGR.06  the one Telegram line;
  SRC.REGR.07  the named report, stored as regression/<stamp>.md.
"""

from __future__ import annotations

import datetime as dt

import pytest

from python.pipeline import source_regression as sr

TODAY = dt.date(2026, 11, 2)  # a Monday


def _row(code, start, *, status="COMPLETED", url_event=None, url_results=None):
    return {
        "txt_code": code,
        "dt_start": start,
        "enum_status": status,
        "url_event": url_event,
        "url_results": url_results,
    }


ROWS = [
    _row("PEW2efs-2026-2027", "2026-10-31", status="IN_PROGRESS"),
    _row("PEW7es-2024-2025", "2025-03-29"),
    _row("IMEW-2023-2024", "2024-06-01"),  # 29 months and a day before TODAY
    _row("PEW1-2023-2024", "2024-04-30"),  # older than 30 months
    _row("PPW4-2026-2027", "2026-10-20"),  # domestic
    _row("MSW-2025-2026", "2025-10-04", status="CANCELLED"),
    _row("PEW3ef-2026-2027", "2026-11-14", status="PLANNED"),
    _row("PEW4ef-2026-2027", "2026-11-15", status="PLANNED", url_event="https://x"),
    _row("PEW5efs-2026-2027", "2026-12-12", status="PLANNED"),
]


# --------------------------------------------------------------------------
# SRC.REGR.01–03 — which events, and when
# --------------------------------------------------------------------------


def test_SRC_REGR_01_the_events_re_read():
    assert sr.past_events(ROWS, TODAY) == [
        "IMEW-2023-2024",
        "PEW2efs-2026-2027",
        "PEW7es-2024-2025",
    ]


def test_SRC_REGR_02_the_upcoming_events_and_their_links():
    assert sr.upcoming(ROWS, TODAY) == [
        {"code": "PEW3ef-2026-2027", "start": "2026-11-14", "days": 12, "linked": False},
        {"code": "PEW4ef-2026-2027", "start": "2026-11-15", "days": 13, "linked": True},
    ]


@pytest.mark.parametrize(
    ("today", "manual", "due"),
    [
        (dt.date(2026, 11, 2), False, True),  # Monday
        (dt.date(2026, 11, 3), True, True),  # on demand
        (dt.date(2026, 11, 3), False, False),
        (dt.date(2026, 11, 13), False, True),  # PEW3ef starts tomorrow
        (dt.date(2026, 11, 14), False, True),  # PEW4ef starts tomorrow
        (dt.date(2026, 11, 12), False, False),
    ],
)
def test_SRC_REGR_03_when_a_full_re_read_is_due(today, manual, due):
    assert sr.full_due(ROWS, today, manual=manual) is due


# --------------------------------------------------------------------------
# SRC.REGR.04 — the comparison
# --------------------------------------------------------------------------


def test_SRC_REGR_04_equal_rows_and_n():
    planned = {7: ({(101, 1), (102, 2)}, 12)}
    assert sr.compare_rows(planned, {7: ({(102, 2), (101, 1)}, 12)}) == ([], [])


def test_SRC_REGR_04_a_difference_is_public_by_count_and_named_by_id():
    planned = {7: ({(101, 1), (102, 2)}, 12), 8: ({(103, 1)}, 5)}
    stored = {7: ({(101, 1), (104, 2)}, 13), 9: ({(105, 1)}, 4)}
    public, named = sr.compare_rows(planned, stored)
    assert public == [
        "tournament 7: N planned 12, stored 13; 1 row(s) only planned, 1 only stored",
        "tournament 8: N planned 5, stored none; 1 row(s) only planned, 0 only stored",
        "tournament 9: N planned none, stored 4; 0 row(s) only planned, 1 only stored",
    ]
    assert named == [
        "tournament 7: only planned [(102, 2)]; only stored [(104, 2)]",
        "tournament 8: only planned [(103, 1)]; only stored []",
        "tournament 9: only planned []; only stored [(105, 1)]",
    ]


# --------------------------------------------------------------------------
# SRC.REGR.05 — an event's verdict
# --------------------------------------------------------------------------


def test_SRC_REGR_05_equal_needs_rows_and_prod_alike():
    check = sr.verdict("PEW8f-2024-2025", [], "fp1", "fp1", disagreements=0)
    assert (check.status, check.public) == (sr.EQUAL, [])


def test_SRC_REGR_05_prod_holding_another_fingerprint_differs():
    check = sr.verdict("PEW8f-2024-2025", [], "fp1", "fp2", disagreements=0)
    assert check.status == sr.DIFFERENT
    assert check.public == ["CERT's result fingerprint fp1 is not PROD's fp2"]


def test_SRC_REGR_05_known_cases_say_why():
    known = sr.verdict("PEW7es-2024-2025", ["tournament 1: …"], "a", "a", disagreements=0)
    assert known.status == sr.KNOWN and "G53" in (known.known or "")
    refused = sr.refusal("PEW4ef-2024-2025", "the source has no single category")
    assert refused.status == sr.KNOWN and "G51" in (refused.known or "")
    other = sr.refusal("PEW9ef-2025-2026", "the source has no single category")
    assert other.status == sr.REFUSED and other.public == ["the source has no single category"]
    noted = sr.verdict("IMEW-2023-2024", [], "a", "a", disagreements=0)
    assert noted.status == sr.EQUAL and "G54" in (noted.known or "")


@pytest.mark.parametrize(
    "code",
    ["PEW4ef-2024-2025", "PEW6efs-2025-2026", "PEW62efs-2025-2026", "PEW9efs-2025-2026"],
)
def test_SRC_REGR_05_every_ftl_combined_bracket_is_known(code):
    """G68 A: the full re-read found two more FTL combined brackets than G51 A
    listed; all four say why, with G51's reason."""
    check = sr.refusal(code, "a combined bracket (no single category): 'X V3, V4'")
    assert check.status == sr.KNOWN and "G51" in (check.known or "")


def test_SRC_REGR_05_a_known_case_that_reads_equal_says_so():
    """A known difference that went away (G53 done) is reported as equal."""
    check = sr.verdict("PEW7es-2024-2025", [], "a", "a", disagreements=0)
    assert check.status == sr.EQUAL


# --------------------------------------------------------------------------
# SRC.REGR.06 — the line
# --------------------------------------------------------------------------


def test_SRC_REGR_06_one_line_for_the_whole_run():
    checks = [
        sr.verdict("PEW8f-2024-2025", [], "a", "a", disagreements=0),
        sr.verdict("PEW2efs-2026-2027", [], "a", "a", disagreements=2),
        sr.verdict("PEW1ef-2025-2026", ["tournament 3: …"], "a", "a", disagreements=0),
        sr.verdict("PEW7es-2024-2025", ["tournament 1: …"], "a", "a", disagreements=0),
        sr.refusal("PEW9ef-2025-2026", "x"),
    ]
    upcoming = [
        {"code": "PEW3ef-2026-2027", "start": "2026-11-14", "days": 12, "linked": False},
        {"code": "PEW4ef-2026-2027", "start": "2026-11-15", "days": 13, "linked": True},
    ]
    assert sr.line(checks, upcoming) == (
        "🔎 Source re-read: 5 event(s), 2 equal; different: PEW1ef-2025-2026; "
        "refused: PEW9ef-2025-2026; known: PEW7es-2024-2025; "
        "source disagreements: 2 in PEW2efs-2026-2027. "
        "Upcoming: PEW3ef-2026-2027 in 12 days, no results link; "
        "PEW4ef-2026-2027 in 13 days, dry-read"
    )


def test_SRC_REGR_06_a_quiet_day_names_the_upcoming_events_only():
    assert sr.line([], []) == "🔎 Source re-read: no event re-read today. Upcoming: none"


# --------------------------------------------------------------------------
# SRC.REGR.07 — the named report
# --------------------------------------------------------------------------


def test_SRC_REGR_07_the_report_holds_the_named_detail():
    check = sr.verdict(
        "PEW1ef-2025-2026",
        ["tournament 3: N planned 5, stored 5; 1 row(s) only planned, 1 only stored"],
        "a",
        "a",
        disagreements=0,
        named=["tournament 3: only planned [(101, 4)]; only stored [(101, 5)]"],
        exceptions=['Men\'s Epee V2, place 4: "KOWALSKI KOWALSKI Jan"'],
    )
    md = sr.report_md([check], [], stamp="20261102-051700Z")
    assert md.startswith("# Source re-read — 20261102-051700Z")
    assert "only planned [(101, 4)]" in md and "KOWALSKI KOWALSKI Jan" in md
    assert sr.report_path("20261102-051700Z") == "regression/20261102-051700Z.md"


def test_SRC_REGR_07_the_report_goes_to_cert_storage_once():
    from unittest.mock import MagicMock

    from python.pipeline.storage_md import StorageMdHandler

    sb = MagicMock()
    path = StorageMdHandler(sb).upload_regression(b"# x", "20261102-051700Z")
    assert path == "regression/20261102-051700Z.md"
    sb.storage.from_.assert_called_with("staging-reports")
    sb.storage.from_.return_value.upload.assert_called_once_with(
        path, b"# x", file_options={"content-type": "text/markdown", "upsert": "false"}
    )
    with pytest.raises(ValueError, match="timestamp"):
        StorageMdHandler(sb).upload_regression(b"# x", "today")


def test_SRC_REGR_08_a_monday_run_reads_stores_and_says_one_line(capsys):
    """SRC.REGR.08 (written after `run`, never seen failing: recorded in the plan)."""
    sent, stored, out = [], [], {}

    def check(code):
        if code == "IMEW-2023-2024":
            raise ValueError("KOWALSKI Jan has no single source category")
        return sr.verdict(code, [], "a", "a", disagreements=0)

    rc = sr.run(
        ROWS,
        TODAY,
        manual=False,
        check=check,
        send=sent.append,
        store=lambda md, stamp: stored.append((md, stamp)) or sr.report_path(stamp),
        output=lambda **kw: out.update(kw),
        stamp="20261102-051700Z",
    )
    log = capsys.readouterr().out
    assert rc == 0
    assert out == {"dry_read": '["PEW4ef-2026-2027"]'}
    assert "IMEW-2023-2024: known" not in log and "IMEW-2023-2024: refused" in log
    assert "KOWALSKI" not in log  # the refusal's text stays in the stored report
    ((md, stamp),) = stored
    assert stamp == "20261102-051700Z" and b"KOWALSKI Jan" in md
    assert sent == [
        "🔎 Source re-read: 3 event(s), 2 equal; refused: IMEW-2023-2024. Upcoming: "
        "PEW3ef-2026-2027 in 12 days, no results link; PEW4ef-2026-2027 in 13 days, dry-read"
    ]


def test_SRC_REGR_08_another_day_names_the_upcoming_events_only():
    sent, stored = [], []
    sr.run(
        ROWS,
        dt.date(2026, 11, 4),
        manual=False,
        check=lambda code: pytest.fail(f"{code} read on a day without a full re-read"),
        send=sent.append,
        store=lambda md, stamp: stored.append(md) or "x",
        output=lambda **kw: None,
        stamp="20261104-051700Z",
    )
    assert stored == []
    assert sent == [
        "🔎 Source re-read: no event re-read today. Upcoming: "
        "PEW3ef-2026-2027 in 10 days, no results link; PEW4ef-2026-2027 in 11 days, dry-read"
    ]


def test_SRC_REGR_08_a_roster_that_is_not_prod_s_is_said():
    assert "CERT's roster is not PROD's" in sr.line([], [], roster_alike=False)


def test_SRC_REGR_08_the_plan_and_the_store_read_alike():
    ops = [
        {
            "op": "ingest_results",
            "tournament": 7,
            "participant_count": 12,
            "rows": [{"id_fencer": 101, "place": 1}, {"id_fencer": 102, "int_place": 2}],
        },
        {"op": "upsert_tournament", "tournament": 7},
    ]
    assert sr.planned_rows(ops) == {7: ({(101, 1), (102, 2)}, 12)}
    assert sr.stored_rows([{"t": 7, "n": 12, "rows": [[101, 1], [102, 2]]}]) == {
        7: ({(101, 1), (102, 2)}, 12)
    }
    assert sr.stored_rows(None) == {}


def test_SRC_REGR_08_an_sql_code_is_a_code():
    with pytest.raises(ValueError, match="^not an event code: "):
        sr.check_event("X'; DROP TABLE tbl_event; --", cert_db=None, cert=None, prod=None)


def _workflow() -> dict:
    from pathlib import Path

    import yaml

    path = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "source-regression.yml"
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_SRC_REGR_09_the_workflow_runs_daily_and_by_hand():
    wf = _workflow()
    on = wf[True]  # PyYAML reads the bare key `on` as True
    assert [c["cron"] for c in on["schedule"]] == ["17 5 * * *"]
    assert "workflow_dispatch" in on
    assert wf["permissions"] == {"contents": "read", "actions": "write"}


def test_SRC_REGR_09_a_manual_run_always_re_reads():
    steps = _workflow()["jobs"]["reread"]["steps"]
    (step,) = [s for s in steps if s.get("id") == "reread"]
    assert step["run"].strip().startswith("python -m python.pipeline.source_regression")
    assert "--manual" in step["run"]
    assert step["env"]["MANUAL"] == "${{ github.event_name == 'workflow_dispatch' }}"
    for name in ("SUPABASE_ACCESS_TOKEN", "SUPABASE_URL", "SUPABASE_KEY", "FTL_USERNAME"):
        assert name in step["env"]
    assert step["env"]["SUPABASE_URL"] == "${{ secrets.SUPABASE_CERT_URL }}"


def test_SRC_REGR_09_each_linked_upcoming_event_is_dry_read_by_the_sync():
    steps = _workflow()["jobs"]["reread"]["steps"]
    (step,) = [s for s in steps if s.get("name") == "Dry-read the upcoming events"]
    assert step["env"]["CODES"] == "${{ steps.reread.outputs.dry_read }}"
    assert step["env"]["GH_TOKEN"] == "${{ github.token }}"
    assert "gh workflow run results-sync.yml" in step["run"]
    assert "-f event_code=" in step["run"] and "-f dry_run=true" in step["run"]


def test_SRC_REGR_07_the_log_lines_name_no_one():
    check = sr.verdict(
        "PEW1ef-2025-2026",
        ["tournament 3: N planned 5, stored 5; 1 row(s) only planned, 1 only stored"],
        "a",
        "a",
        disagreements=1,
        named=["tournament 3: only planned [(101, 4)]; only stored [(101, 5)]"],
        exceptions=['Men\'s Epee V2, place 4: "KOWALSKI KOWALSKI Jan"'],
    )
    text = "\n".join(sr.log_lines(check))
    assert "PEW1ef-2025-2026: different" in text
    assert "KOWALSKI" not in text and "(101" not in text
