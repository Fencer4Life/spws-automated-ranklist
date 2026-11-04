"""CLOSE.WIN.01–02, CLOSE.SEED.01–02, LIFE.SEASON.01–07 — when the daily close
looks at past seasons, and why an event of an ended season never stays open.

The user's decision of 4 Nov 2026 ("All A" on
doc/plans/past-season-close-when-2026-11-04.html):

- S1 A: the past-season pass looks only at seasons that ended one to three days
  ago, so it runs on the three mornings after a season ends and finds nothing
  to read on any other day.
- S2 A: a run of an event whose season has ended leaves it COMPLETED; what
  would have kept it open becomes a warning in the run record and on Telegram
  (IMSW-2025-2026 sat IN_PROGRESS for a year by that path).
- S3 A: when the pass completes anything on PROD, the close exports PROD's seed,
  so pgTAP 128 in CI reads the same state as PROD.
"""

from __future__ import annotations

import datetime as dt
from pathlib import Path
from unittest.mock import MagicMock, patch

import yaml

from python.pipeline import ingest_cli
from python.pipeline.promotion import close, lifecycle
from python.pipeline.promotion.run_record import ListingLog

D = dt.date
ROOT = Path(__file__).resolve().parents[2]


def _listings(*, unread: int = 0, committed: bool = True) -> dict:
    """What a run read: two listings kept, `unread` of them not read."""
    rounds = [
        {"name": f"R{i}", "status": "committed" if committed else "skipped"}
        for i in range(2 - unread)
    ]
    return {"schedule": {"kept": 2, "skipped": [], "last_day": None}, "rounds": rounds}


class _Seasons:
    """A database that knows its seasons' end dates."""

    def __init__(self, ends: dict[int, str]):
        self.ends = ends
        self.status_writes: list[tuple[int, str]] = []

    def find_season_by_id(self, id_season):
        end = self.ends.get(id_season)
        return None if end is None else {"id_season": id_season, "dt_end": end}

    def set_event_status(self, id_event, status):
        self.status_writes.append((id_event, status))


class _DatedEnv:
    """An environment whose open events each belong to a season with an end date."""

    def __init__(self, name: str, events: dict[str, tuple[str, dt.date]]):
        self.name = name
        self.events = dict(events)  # code → (status, season end)
        self.asked: list[tuple[dt.date, dt.date]] = []
        self.writes: list[str] = []

    def past_season_open(self, ended_from, ended_to):
        self.asked.append((ended_from, ended_to))
        return [
            {"code": code, "status": status}
            for code, (status, end) in sorted(self.events.items())
            if ended_from <= end <= ended_to
        ]

    def set_status(self, code, status):
        self.writes.append(f"{code}:{status}")
        self.events[code] = (status, self.events[code][1])


SEASON_END = D(2027, 7, 15)  # SPWS-2026-2027


# ---------------------------------------------------------------------------
# S1 — the pass looks only at seasons that ended one to three days ago
# ---------------------------------------------------------------------------


def test_CLOSE_WIN_01_the_window_is_the_three_days_after_a_season_ends():
    """CLOSE.WIN.01"""
    assert lifecycle.past_season_window(D(2027, 7, 16)) == (D(2027, 7, 13), D(2027, 7, 15))
    inside = [
        day
        for day in (D(2027, 7, d) for d in range(14, 21))
        if lifecycle.past_season_window(day)[0]
        <= SEASON_END
        <= lifecycle.past_season_window(day)[1]
    ]
    assert inside == [D(2027, 7, 16), D(2027, 7, 17), D(2027, 7, 18)]


def test_CLOSE_WIN_02_the_pass_completes_only_seasons_that_just_ended(capsys):
    """CLOSE.WIN.02 — on 16 Jul 2027 the season that ended the day before is
    completed; a season that ended a year earlier is not looked at, and on
    19 Jul nothing is asked for, written or said."""
    events = {
        "PPW5-2026-2027": ("PLANNED", SEASON_END),
        "PEW9f-2025-2026": ("IN_PROGRESS", D(2026, 7, 11)),
    }
    cert, prod = _DatedEnv("cert", events), _DatedEnv("prod", events)
    notifier = MagicMock()
    closed = close.close_past_season_events(cert, prod, notifier=notifier, today=D(2027, 7, 16))
    assert closed == {
        "PPW5-2026-2027": [
            "cert:IN_PROGRESS",
            "cert:COMPLETED",
            "prod:IN_PROGRESS",
            "prod:COMPLETED",
        ]
    }
    assert cert.asked == [(D(2027, 7, 13), D(2027, 7, 15))]
    assert prod.events["PEW9f-2025-2026"] == ("IN_PROGRESS", D(2026, 7, 11))
    capsys.readouterr()

    later = _DatedEnv("cert", {"PPW5-2026-2027": ("PLANNED", SEASON_END)})
    quiet = MagicMock()
    assert (
        close.close_past_season_events(
            later, _DatedEnv("prod", {}), notifier=quiet, today=D(2027, 7, 19)
        )
        == {}
    )
    assert later.writes == [] and quiet.method_calls == []
    assert capsys.readouterr().out == ""


# ---------------------------------------------------------------------------
# S3 — a PROD write by the pass exports PROD's seed
# ---------------------------------------------------------------------------


def test_CLOSE_SEED_01_the_close_tells_the_workflow_when_it_wrote_prod(monkeypatch, tmp_path):
    """CLOSE.SEED.01 — `prod_completed=true` only when the pass wrote PROD."""
    from python.pipeline import notifications
    from python.pipeline.promotion import refresh

    monkeypatch.setattr(close, "supabase_access_token", lambda: "token")
    monkeypatch.setattr(refresh, "ManagementTransport", lambda *a, **k: object())
    monkeypatch.setattr(notifications, "TelegramNotifier", lambda *a, **k: MagicMock())
    monkeypatch.setattr(close, "close_events", lambda *a, **k: [])
    cases = [
        ({"PPW5-2026-2027": ["cert:COMPLETED", "prod:COMPLETED"]}, [], "true"),
        ({"PPW5-2026-2027": ["cert:COMPLETED"]}, [], "false"),
        ({}, [], "false"),
        ({"PPW5-2026-2027": ["prod:COMPLETED"]}, ["--dry-run"], "false"),
    ]
    for i, (past, args, expected) in enumerate(cases):
        out = tmp_path / f"out{i}"
        monkeypatch.setenv("GITHUB_OUTPUT", str(out))
        monkeypatch.setattr(close, "close_past_season_events", lambda *a, _p=past, **k: _p)
        assert close.main(["--today", "2027-07-16", *args]) == 0
        assert f"prod_completed={expected}" in out.read_text().splitlines(), (past, args)

    # One event written on PROD, another failed: the run is red, and the seed
    # is still exported for what was written.
    def _half(*_a, **_k):
        raise close.CloseFailed("Daily close failed", closed={"PPW5-2026-2027": ["prod:COMPLETED"]})

    out = tmp_path / "failed"
    monkeypatch.setenv("GITHUB_OUTPUT", str(out))
    monkeypatch.setattr(close, "close_past_season_events", _half)
    assert close.main(["--today", "2027-07-16"]) == 1
    assert "prod_completed=true" in out.read_text().splitlines()


def test_CLOSE_SEED_02_event_close_exports_prods_seed_after_a_prod_write():
    """CLOSE.SEED.02 — the seed job runs when the close wrote PROD (even if the
    morning's close then failed), exports PROD, and commits with a retried push;
    only that job may write to the repository."""
    wf = yaml.safe_load((ROOT / ".github/workflows/event-close.yml").read_text(encoding="utf-8"))
    assert wf["permissions"] == {"contents": "read"}
    job = wf["jobs"]["close"]
    step = next(s for s in job["steps"] if s.get("name") == "Close events")
    assert step.get("id") == "close"
    assert job["outputs"]["prod_completed"] == "${{ steps.close.outputs.prod_completed }}"

    seed = wf["jobs"]["seed"]
    assert seed["needs"] == "close"
    assert seed["if"] == "always() && needs.close.outputs.prod_completed == 'true'"
    assert seed["permissions"] == {"contents": "write"}
    runs = "\n".join(str(s.get("run", "")) for s in seed["steps"])
    assert 'python -m python.pipeline.export_seed --ref "${{ secrets.SUPABASE_PROD_REF }}"' in runs
    assert "git add supabase/seed_prod_*.sql supabase/seed_prod_latest.sql" in runs
    assert "[skip ci]" in runs and "for attempt in 1 2 3" in runs


# ---------------------------------------------------------------------------
# S2 — a run of an event whose season has ended leaves it COMPLETED
# ---------------------------------------------------------------------------

END = D(2026, 3, 1)


def test_LIFE_SEASON_01_an_ended_season_completes_the_event_with_warnings():
    """LIFE.SEASON.01"""
    v = lifecycle.event_status(
        _listings(unread=1), dt_end=END, today=D(2026, 11, 4), season_end=D(2026, 7, 11)
    )
    assert v.status == lifecycle.COMPLETED
    assert v.reasons == []
    assert v.warnings == [
        "its season ended 2026-07-11, so it is COMPLETED although: 1 listing(s) not read"
    ]


def test_LIFE_SEASON_02_a_season_not_ended_keeps_the_rule_as_it_was():
    """LIFE.SEASON.02 — the season's last day itself, and no season known."""
    for season_end in (D(2026, 11, 4), D(2027, 7, 15), None):
        v = lifecycle.event_status(
            _listings(unread=1), dt_end=END, today=D(2026, 11, 4), season_end=season_end
        )
        assert v.status == lifecycle.IN_PROGRESS, season_end
        assert v.reasons == ["1 listing(s) not read"] and v.warnings == []
    clean = lifecycle.event_status(
        _listings(), dt_end=END, today=D(2026, 11, 4), season_end=D(2026, 7, 11)
    )
    assert clean.status == lifecycle.COMPLETED and clean.warnings == []


def test_LIFE_SEASON_03_no_result_still_moves_nothing():
    """LIFE.SEASON.03 — ADR-037 holds in an ended season too."""
    assert (
        lifecycle.target_status(
            _listings(unread=1, committed=False),
            dt_end=END,
            today=D(2026, 11, 4),
            season_end=D(2026, 7, 11),
        )
        is None
    )
    assert (
        lifecycle.target_status(
            _listings(unread=1), dt_end=END, today=D(2026, 11, 4), season_end=D(2026, 7, 11)
        )
        == lifecycle.COMPLETED
    )


def test_LIFE_SEASON_04_the_season_end_is_read_from_the_events_season():
    """LIFE.SEASON.04 — unknown when the database cannot say."""
    db = _Seasons({3: "2026-07-11"})
    assert lifecycle.season_end(db, {"id_season": 3}) == D(2026, 7, 11)
    assert lifecycle.season_end(db, {"id_season": 9}) is None
    assert lifecycle.season_end(db, {}) is None
    assert lifecycle.season_end(object(), {"id_season": 3}) is None


def test_LIFE_SEASON_05_a_direct_run_completes_an_ended_seasons_event(capsys):
    """LIFE.SEASON.05 — `lifecycle.apply`, the live ingest's rule."""
    db = _Seasons({3: "2026-07-11"})
    event = {
        "id_event": 7,
        "txt_code": "IMSW-2025-2026",
        "id_season": 3,
        "dt_end": "2026-03-01",
        "enum_status": "IN_PROGRESS",
    }
    assert lifecycle.apply(db, event, _listings(unread=1), D(2026, 11, 4)) == lifecycle.COMPLETED
    assert db.status_writes == [(7, lifecycle.COMPLETED)]
    out = capsys.readouterr().out
    assert "IMSW-2025-2026 IN_PROGRESS -> COMPLETED" in out
    assert "its season ended 2026-07-11" in out


def test_LIFE_SEASON_06_the_run_record_keeps_the_warnings():
    """LIFE.SEASON.06 — present only when there are any."""
    log = ListingLog()
    assert "lifecycle_warnings" not in log.listings()
    log.lifecycle_warnings = ["its season ended 2026-07-11, so it is COMPLETED although: x"]
    assert log.listings()["lifecycle_warnings"] == log.lifecycle_warnings


def test_LIFE_SEASON_07_a_recorded_run_says_it_on_telegram():
    """LIFE.SEASON.07 — the CERT run of an event whose season ended: COMPLETED,
    the warning in the run record and in one Telegram warning."""
    from python.tests.cert_apply_fakes import CertMemoryDb
    from python.tests.test_cert_apply import _event8, _fencers, _record, _run

    class _EndedSeasonDb(CertMemoryDb):
        def find_season_by_id(self, id_season):
            return {"id_season": id_season, "dt_end": "2027-01-31"}

    db = _EndedSeasonDb(_fencers(), [_event8()])
    notifier = MagicMock()
    # 14 Feb 2027 is the event's own last day: without S2 the run stays open.
    with patch.object(lifecycle, "warsaw_today", return_value=D(2027, 2, 14)):
        _record(db, notifier=notifier)
    run = _run(db)
    assert run["status"] == "FINISHED"
    warnings = run["listings"]["lifecycle_warnings"]
    assert warnings and warnings[0].startswith("its season ended 2027-01-31")
    said = [c.args[0] for c in notifier.warning.call_args_list]
    assert any("season ended 2027-01-31" in m and "COMPLETED" in m for m in said), said
    assert ingest_cli is not None
