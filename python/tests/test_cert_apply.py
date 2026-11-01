"""CERTAPPLY.01–12 — the CERT ingest is plan + apply (ADR-119 §3: D3, R2.1, B1–B10).

A recorded run (`--record-run cert`, or `local` for the rehearsal) reads every
final listing first, without a write; saves a link given with the command;
reads the event's result fingerprint (the prior); opens the run; plans the
ingestion against CERT with reserved fencer ids; writes it with one
fn_promote_event_apply call (no expected fingerprint: compute and return);
closes the run FINISHED with the fingerprint the apply reached; then drains
CERT's recompute queue, runs the gate (its outcome on the run row), sends the
staging report and runs the joining check. Any refusal before the apply
writes nothing. A run with nothing final writes nothing (R2.1 C).

The LOCAL acceptance against FTL is `python -m python.pipeline.promotion.plan_check`
(CERTAPPLY.10, plan §07); here it runs on the in-memory database.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import yaml

from python.pipeline import ingest_cli
from python.pipeline.promotion import cert_apply
from python.pipeline.promotion import plan as pl
from python.pipeline.promotion.run_record import ListingLog, listing_sha256, schedule_sha256
from python.tests.cert_apply_fakes import (
    CertMemoryDb,
    MemoryApplier,
    blocked,
    cert_state,
    recorded,
)
from python.tests.test_promotion_plan import (
    SCHEDULE,
    MemoryDb,
    _event,
    _fencer,
    _Ftl,
    _ReadOnly,
)

ROOT = Path(__file__).resolve().parents[2]
CODE = "PPW4-2026-2027"

FTL = _Ftl(
    {
        "U1": (
            "Szpada Mężczyzn kat. 2",
            [("KOWALSKI Jan", 1), ("ZIELIŃSKI Marek", 2), ("NOWAK Adam", 3)],
        ),
        "U2": ("Szabla Mężczyzn kat. 2", [("NOWAK Adam", 1), ("KOWALSKI Jan", 2)]),
    }
)


def _fencers():
    return [
        _fencer(101, "KOWALSKI", "Jan", 1972),
        _fencer(102, "NOWAK", "Adam", 1970),
    ]


def _event8() -> dict:
    event = _event(8, CODE, "2027-02-13", 2)
    event["dt_end"] = "2027-02-14"
    return event


def _cert(order: list[str] | None = None) -> CertMemoryDb:
    """CERT for a recorded run."""
    return CertMemoryDb(_fencers(), [_event8()], order=order)


def _plain() -> MemoryDb:
    """A database for the live path, which records nothing."""
    return MemoryDb(_fencers(), [_event8()])


class _OrderedFtl(_Ftl):
    """FTL that notes each read in the run's order."""

    def __init__(self, listings, order):
        super().__init__(listings)
        self.order = order

    def get(self, url):
        self.order.append("read")
        return super().get(url)


def _drive(ftl, fn, *args, finished=True, **kwargs):
    kept = [
        {"uuid": u, "name": name, "finished": finished, "day": None}
        for u, (name, _) in ftl.listings.items()
    ]
    with (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=ftl),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch("python.tools.scrape_ftl_event_urls.parse_event_schedule", return_value=(kept, [])),
        patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None),
        patch("python.pipeline.ingest_cli._after_event_run"),
    ):
        return fn(*args, **kwargs)


def _record(db, ftl=FTL, *, applier=None, gate=None, finished=True, **kwargs):
    """A recorded CERT run of the fixture event, with the apply on `db`."""
    applier = applier or MemoryApplier(db)
    with recorded(applier=applier, order=db.order, **({"gate": gate} if gate else {})) as calls:
        out = _drive(
            ftl,
            ingest_cli.ingest_event_from_url,
            finished=finished,
            event_code=CODE,
            season_end_year=2027,
            db=db,
            record_run="cert",
            **kwargs,
        )
    return out, calls


def _run(db):
    (run,) = db.runs.values()
    return run


# ---------------------------------------------------------------------------
# CERTAPPLY.01 — the reader reads and writes nothing else
# ---------------------------------------------------------------------------


class TestReader:
    def test_the_domestic_reader_writes_nothing_and_hashes_every_listing(self):
        """CERTAPPLY.01"""
        db = _plain()
        event = db.find_event_by_code(CODE)
        read = _drive(FTL, ingest_cli.read_event, event, CODE, 2027, SCHEDULE, db=_ReadOnly(db))
        assert read.route == "domestic"
        assert [r["uuid"] for r in read.listings] == ["U1", "U2"]
        assert [d["status"] for d in read.decisions] == ["committed", "committed"]
        log = ListingLog()
        log.add_read(read)
        listings = log.listings()
        kept = [{"uuid": u, "name": n} for u, (n, _) in FTL.listings.items()]
        assert listings["schedule"]["sha256"] == schedule_sha256(kept, [])
        for entry, rec in zip(listings["rounds"], read.listings, strict=True):
            assert entry["sha256"] == listing_sha256(
                rec["name"], rec["uuid"], True, rec["_base"].results
            )
            assert "outcome" not in entry

    def test_the_read_listings_are_the_ones_a_plan_records(self):
        """CERTAPPLY.01 — the run log the reader fills equals the plan's, but
        for each listing's outcome, which only the commit knows."""
        db = _cert()
        event = db.find_event_by_code(CODE)
        read = _drive(FTL, ingest_cli.read_event, event, CODE, 2027, SCHEDULE, db=_ReadOnly(db))
        log = ListingLog()
        log.add_read(read)
        plan = _drive(
            FTL, pl.plan_event, CODE, 2027, _ReadOnly(db), url_event=SCHEDULE, created=None
        )
        strip = [
            {k: v for k, v in r.items() if k not in ("outcome", "identity")}
            for r in plan.listings["rounds"]
        ]
        assert log.listings()["rounds"] == strip
        assert log.listings()["schedule"] == plan.listings["schedule"]

    def test_the_pzsz_reader_only_stores_the_start_lists_it_captured(self):
        """CERTAPPLY.01 — a PZSz event: the capture is the reader's input store."""
        from python.tests import test_pzsz_routing as pz

        db = pz._pzsz_db()

        class Guard:
            def __getattr__(self, name):
                if name in MemoryDb.WRITES:
                    raise AssertionError(f"the reader wrote {name}")
                return getattr(db, name)

        event = db.find_event_by_code(pz.CODE)
        read, _, _ = pz._with_pages(
            pz._pages(), ingest_cli.read_event, event, pz.CODE, 2027, SCHEDULE, db=Guard()
        )
        assert read.route == "roster" and read.pzsz_event == 4588
        assert set(read.start_lists) == {("SABRE", "M"), ("SABRE", "F")}
        assert db.start_lists.rows, "the capture stored the lists it read"
        assert all(r.get("start_list_sha256") for r in read.listings)

    def test_the_international_reader_records_sightings_and_nothing_else(self):
        """CERTAPPLY.01 — an international event: sightings are its input store."""
        from python.tests.test_route_international import _intl_db, _recs

        db = _intl_db()
        event = db.find_event_by_code("MSW-2026-2027")
        kept = [{"uuid": "A1", "name": "x"}, {"uuid": "A2", "name": "y"}]
        with patch(
            "python.pipeline.international_sources.read_brackets", return_value=(_recs(), kept, [])
        ):
            read = ingest_cli.read_event(event, "MSW-2026-2027", 2027, SCHEDULE, db=db)
        assert read.route == "international"
        assert [r["uuid"] for r in read.listings] == ["A1", "A2"]
        assert read.sources == [{"slot": "url_event", "url": event["url_event"]}]
        writes = {
            name
            for name, *_ in db.method_calls
            if name.split(".")[0] in MemoryDb.WRITES or name.startswith(("insert", "ingest"))
        }
        assert writes == set()


# ---------------------------------------------------------------------------
# CERTAPPLY.02–08 — the recorded run
# ---------------------------------------------------------------------------


class TestRecordedRun:
    def test_it_reads_saves_the_given_link_then_opens(self):
        """CERTAPPLY.02 (B1, B2)"""
        order: list[str] = []
        db = _cert(order)
        db.events[8]["url_event"] = None
        link = "https://www.fencingtimelive.com/tournaments/eventSchedule/NEW"
        original = db.set_event_url_event

        def saved(id_event, url_event):
            order.append("link")
            original(id_event, url_event)

        db.set_event_url_event = saved
        _record(db, _OrderedFtl(FTL.listings, order), url_event_override=link)
        first = order.index("open")
        assert "read" in order[:first] and "link" in order[:first]
        assert max(i for i, s in enumerate(order) if s == "read") < order.index("link")
        assert db.events[8]["url_event"] == link
        assert _run(db)["params"]["p_url_event"] == link

    def test_a_read_failure_opens_no_run_and_writes_nothing(self):
        """CERTAPPLY.02"""
        db = _cert()
        before = db.state()
        with (
            recorded(applier=MemoryApplier(db)),
            patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=FTL),
            patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
            patch("python.tools.scrape_ftl_event_urls.parse_event_schedule", return_value=([], [])),
            pytest.raises(ValueError, match="lists no events"),
        ):
            ingest_cli.ingest_event_from_url(CODE, 2027, db=db, record_run="cert")
        assert db.runs == {}
        assert db.state() == before

    def test_the_plan_takes_reserved_ids(self):
        """CERTAPPLY.03 (B6)"""
        db = _cert()
        _, calls = _record(db)
        assert len(db.reserved) == 1, "the fixture creates exactly one fencer"
        (new,) = db.reserved
        (params,) = calls["applier"].calls
        inserts = [o for o in params["p_plan"]["ops"] if o["op"] == "insert_fencer"]
        assert [o["id_fencer"] for o in inserts] == [new]
        assert db.fencers[new]["txt_surname"] == "ZIELIŃSKI"
        assert _run(db)["status"] == "FINISHED"

    def test_one_apply_with_no_expected_fingerprint_and_the_prior(self):
        """CERTAPPLY.04 (B3) — first run: no prior; second run: CERT's own."""
        db = _cert()
        _, calls = _record(db)
        (first,) = calls["applier"].calls
        assert first["p_expected_fingerprint"] is None
        assert first["p_prior_fingerprint"] is None
        assert first["p_dry_run"] is False
        assert first["p_expected_inputs"] == db.ingest_run_input_parts(41)
        assert first["p_status"] == "IN_PROGRESS"
        held = db.fingerprint(CODE)
        _, calls = _record(db)
        (second,) = calls["applier"].calls
        assert second["p_prior_fingerprint"] == held

    def test_the_run_records_the_prior_it_started_from(self):
        """CERTAPPLY.13 (G17) — the run opens with the prior it read (B3): none on
        the first run, CERT's own fingerprint on the next, the same prior the
        apply is called with. Promote accepts PROD holding exactly it."""
        db = _cert()
        _record(db)
        assert db.runs[41]["params"]["p_prior_fingerprint"] is None
        held = db.fingerprint(CODE)
        _, calls = _record(db)
        (second,) = calls["applier"].calls
        assert db.runs[42]["params"]["p_prior_fingerprint"] == held == second["p_prior_fingerprint"]

    def test_after_the_apply_drain_gate_report_joining(self):
        """CERTAPPLY.05 (B7)"""
        order: list[str] = []
        db = _cert(order)
        with (
            recorded(applier=MemoryApplier(db), order=order) as calls,
            patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=FTL),
            patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
            patch(
                "python.tools.scrape_ftl_event_urls.parse_event_schedule",
                return_value=(
                    [
                        {"uuid": u, "name": n, "finished": True, "day": None}
                        for u, (n, _) in FTL.listings.items()
                    ],
                    [],
                ),
            ),
            patch(
                "python.pipeline.ingest_cli._fire_staging_report",
                side_effect=lambda *a, **k: order.append("report"),
            ),
            patch(
                "python.pipeline.ingest_cli._after_event_run",
                side_effect=lambda *a, **k: order.append("joining"),
            ),
        ):
            ingest_cli.ingest_event_from_url(CODE, 2027, db=db, record_run="cert")
        tail = [
            s for s in order if s in ("apply", "finished", "drain", "gate", "report", "joining")
        ]
        assert tail == ["apply", "finished", "drain", "gate", "report", "joining"]
        assert calls["gate"] == [(CODE, "cert")]
        assert calls["drain"] == [db]

    def test_the_run_closes_finished_with_the_fingerprint_the_apply_reached(self):
        """CERTAPPLY.06"""
        db = _cert()
        _, calls = _record(db)
        run = _run(db)
        (reached,) = calls["applier"].results
        assert run["status"] == "FINISHED"
        assert run["fingerprint"] == reached["fingerprint"] == db.fingerprint(CODE)
        assert db.events[8]["enum_status"] == reached["status"] == "IN_PROGRESS"

    def test_a_refused_listing_fails_the_run_and_writes_nothing(self):
        """CERTAPPLY.07 — every listing read is on the run, and CERT is unchanged."""
        from python.pipeline.core.contract import ListingRefused

        db = _cert()
        before = db.state()
        real = ingest_cli._run_parsed_through_flow

        def second_refused(parsed, *a, **k):
            if parsed.weapon == "SABRE":
                raise ListingRefused("identity", "SABRE M listing not written: namesakes")
            return real(parsed, *a, **k)

        applier = MemoryApplier(db)
        with (
            patch(
                "python.pipeline.ingest_cli._run_parsed_through_flow", side_effect=second_refused
            ),
            pytest.raises(ValueError, match="namesakes"),
        ):
            _record(db, applier=applier)
        assert applier.calls == []
        run = _run(db)
        assert run["status"] == "FAILED"
        assert run["listings"]["refusal"]["kind"] == "identity"
        assert [r["uuid"] for r in run["listings"]["rounds"]] == ["U1", "U2"]
        assert db.state() == before

    def test_an_answerless_apply_that_committed_finishes(self):
        """CERTAPPLY.08 (B5) — CERT moved from the prior: the apply committed."""
        db = _cert()
        _record(db, applier=MemoryApplier(db, uncertain=True, committed=True))
        run = _run(db)
        assert run["status"] == "FINISHED"
        assert run["fingerprint"] == db.fingerprint(CODE)
        assert db.results, "the apply had committed before its answer was lost"

    def test_an_answerless_apply_that_did_not_commit_fails(self):
        """CERTAPPLY.08 (B5) — CERT holds what it held: the run fails, nothing written."""
        db = _cert()
        before = db.state()
        with pytest.raises(cert_apply.ApplyUnanswered, match="holds what it held before"):
            _record(db, applier=MemoryApplier(db, uncertain=True, committed=False))
        assert _run(db)["status"] == "FAILED"
        assert db.state() == before

    def test_a_certain_apply_refusal_fails_the_run(self):
        """CERTAPPLY.08 — the database refused, so it rolled back."""
        db = _cert()
        before = db.state()
        with pytest.raises(cert_apply.ApplyRefused, match="PROMOTE_INPUT_CHANGED"):
            _record(db, applier=MemoryApplier(db, fail="PROMOTE_INPUT_CHANGED: roster"))
        run = _run(db)
        assert run["status"] == "FAILED" and "PROMOTE_INPUT_CHANGED" in run["error"]
        assert db.state() == before


# ---------------------------------------------------------------------------
# CERTAPPLY.09 — --replace and --record-run, and the workflow
# ---------------------------------------------------------------------------


class TestReplaceAndWorkflow:
    def test_replace_with_a_recorded_run_is_refused_before_anything_is_read(self):
        """CERTAPPLY.09 (B10)"""
        db = _cert()
        with (
            patch("python.scrapers.ftl_auth.get_authed_ftl_client") as ftl,
            pytest.raises(ValueError, match="--replace"),
        ):
            ingest_cli.ingest_event_from_url(CODE, 2027, db=db, replace=True, record_run="cert")
        ftl.assert_not_called()
        assert db.runs == {}

    def test_the_cli_refuses_the_combination(self, monkeypatch):
        """CERTAPPLY.09"""
        argv = [
            "ingest_cli",
            "--flow",
            "ingest_domestic",
            "--event-code",
            CODE,
            "--season-end-year",
            "2027",
            "--from-url",
            "--replace",
            "--record-run",
            "cert",
        ]
        monkeypatch.setattr("sys.argv", argv)
        with pytest.raises(SystemExit):
            ingest_cli.main()

    def test_the_workflow_records_without_replace_and_says_one_thing(self):
        """CERTAPPLY.09 (B7, B10)"""
        wf = yaml.safe_load((ROOT / ".github/workflows/ingest-event.yml").read_text())
        steps = wf["jobs"]["ingest-event"]["steps"]
        (ingest,) = [s for s in steps if s.get("id") == "ingest"]
        command = "\n".join(
            line for line in ingest["run"].splitlines() if not line.lstrip().startswith("#")
        )
        assert "--record-run cert" in command
        assert "--replace" not in command
        assert "SUPABASE_ACCESS_TOKEN" in ingest["env"]
        (notify,) = [s for s in steps if s.get("name") == "Notify failure"]
        # Release 3: in sync mode the outcome job sends the cycle's one line instead.
        assert notify["if"] == (
            "failure() && inputs.mode != 'sync' && steps.ingest.outputs.reported != 'true'"
        )


# ---------------------------------------------------------------------------
# CERTAPPLY.10 — the recorded path equals the live run
# ---------------------------------------------------------------------------


class TestRecordedEqualsLive:
    def test_domestic(self):
        """CERTAPPLY.10 — fingerprint for fingerprint, fencer id for fencer id."""
        live = _plain()
        _drive(
            FTL, ingest_cli.ingest_event_from_url, event_code=CODE, season_end_year=2027, db=live
        )
        cert = _cert()
        _record(cert)
        assert cert.state() == live.state()

    def test_pzsz(self):
        """CERTAPPLY.10 — a PZSz event, with its captured start lists."""
        from python.tests import test_pzsz_routing as pz

        live = pz._pzsz_db()
        pz._live(live)

        class CertPzsz(CertMemoryDb, pz.PzszMemoryDb):
            pass

        event = _event(9, pz.CODE, "2026-10-04", 2)
        event["dt_end"] = "2026-10-05"
        event["id_pzsz_event"] = 4588
        roster = [
            _fencer(301, "PRZYKŁADOWY", "Jan", 1971),
            _fencer(302, "WZORCOWY", "Jakub", 1976),
            _fencer(303, "PRZYKŁADOWA", "Anna", 1969, gender="F"),
        ]
        cert = CertPzsz(roster, [event])
        with recorded(applier=MemoryApplier(cert), order=cert.order):
            pz._with_pages(
                pz._pages(),
                ingest_cli.ingest_event_from_url,
                event_code=pz.CODE,
                season_end_year=2027,
                db=cert,
                record_run="cert",
            )
        assert cert.state() == live.state()


# ---------------------------------------------------------------------------
# CERTAPPLY.11 — R2.1 C: nothing final
# ---------------------------------------------------------------------------


class TestNothingFinal:
    def test_cert_empty_finishes_and_writes_nothing(self):
        """CERTAPPLY.11"""
        db = _cert()
        before = db.state()
        _, calls = _record(db, finished=False)
        assert calls["applier"].calls == []
        assert _run(db)["status"] == "FINISHED"
        assert db.state() == before

    def test_cert_holding_results_fails_and_deletes_nothing(self):
        """CERTAPPLY.11"""
        db = _cert()
        _record(db)
        held = db.state()
        db.runs.clear()
        with pytest.raises(cert_apply.NothingFinal, match="nothing was deleted"):
            _record(db, finished=False)
        run = _run(db)
        assert run["status"] == "FAILED"
        assert run["listings"]["refusal"]["kind"] == "nothing_final"
        assert db.state() == held


# ---------------------------------------------------------------------------
# CERTAPPLY.12 — the gate's findings go to Telegram, not to the log
# ---------------------------------------------------------------------------


class TestGateFindings:
    BLOCK = blocked(
        ("identity.estimated", "identity", "KOWALSKI Jan (#101): the birth year 1972 is estimated"),
        ("scoring.points", "scoring", "Szpada V2: NOWAK Adam (#102) scores differ"),
    )

    def test_a_blocked_gate_tells_telegram_and_names_nobody_in_the_log(self, capsys):
        """CERTAPPLY.12"""
        db = _cert()
        notifier = MagicMock()
        with pytest.raises(cert_apply.GateBlocked) as blocked_:
            _record(db, gate=self.BLOCK, notifier=notifier, send_telegram=True)
        assert blocked_.value.reported is True
        out = capsys.readouterr()
        assert "KOWALSKI" not in out.out + out.err and "NOWAK" not in out.out + out.err
        assert "1 identity, 1 scoring" in out.out
        told = json.dumps([c.args for c in notifier.method_calls], ensure_ascii=False)
        assert "KOWALSKI Jan (#101)" in told
        assert _run(db)["status"] == "FINISHED", "CERT is written; the gate blocks promote only"

    def test_main_does_not_repeat_a_reported_failure(self, monkeypatch, tmp_path):
        """CERTAPPLY.12 (B7) — one message, and the workflow is told. Since
        release 3 (S9) a recorded run's stop exits 1 without a traceback."""
        out = tmp_path / "out"
        monkeypatch.setenv("GITHUB_OUTPUT", str(out))
        argv = ["ingest_cli", "--flow", "ingest_domestic", "--event-code", CODE]
        argv += ["--season-end-year", "2027", "--from-url", "--record-run", "cert"]
        monkeypatch.setattr("sys.argv", argv)
        notifier = MagicMock()
        with (
            patch("python.pipeline.ingest_cli.TelegramNotifier", return_value=notifier),
            patch(
                "python.pipeline.ingest_cli.ingest_event_from_url",
                side_effect=cert_apply.GateBlocked("The gate blocks promote of X: 1 identity"),
            ),
            pytest.raises(SystemExit, match="1"),
        ):
            ingest_cli.main()
        notifier.notify_pipeline_failure.assert_not_called()
        assert "reported=true" in out.read_text()

    def test_main_reports_an_unreported_failure_once_and_tells_the_workflow(
        self, monkeypatch, tmp_path
    ):
        """CERTAPPLY.12 (B7). A recorded run exits 1 and logs the error's type
        and frames, never its message (G38 A, LOG.PRIV.05)."""
        out = tmp_path / "out"
        monkeypatch.setenv("GITHUB_OUTPUT", str(out))
        argv = ["ingest_cli", "--flow", "ingest_domestic", "--event-code", CODE]
        argv += ["--season-end-year", "2027", "--from-url", "--record-run", "cert"]
        monkeypatch.setattr("sys.argv", argv)
        notifier = MagicMock()
        with (
            patch("python.pipeline.ingest_cli.TelegramNotifier", return_value=notifier),
            patch(
                "python.pipeline.ingest_cli.ingest_event_from_url",
                side_effect=ValueError("lists no events"),
            ),
            pytest.raises(SystemExit) as stopped,
        ):
            ingest_cli.main()
        assert stopped.value.code == 1
        notifier.notify_pipeline_failure.assert_called_once()
        assert "reported=true" in out.read_text()


def test_a_mock_cert_answers_a_recorded_run():
    """The MagicMock CERT the driver tests use answers the recorded path."""
    db = cert_state(MagicMock())
    assert db.event_result_state(CODE) == {"fingerprint": "f" * 64, "has_results": False}


# --------------------------------------------------------------------------
# Release 3 (ADR-119 §4): the recorded run in the sync's cycle
# --------------------------------------------------------------------------

NAMED_REFUSAL = (
    "SABRE M listing not written: NOWAK Adam declared 1970, and the namesake "
    "ZIELIŃSKI Marek 1968 is two categories away"
)


def _international_pending() -> None:
    """The commit of an international bracket holding a PENDING row, as the
    real Commit plugin refuses it (G37 A)."""
    from python.pipeline.types import StageMatchResult
    from python.tests.test_international_field import _db, _ingest_ctx, _parsed
    from python.tests.test_international_field import _run as commit

    held = StageMatchResult(
        scraped_name="PRZYKŁADOWA Anna PRZYKŁADOWA Anna",
        place=11,
        id_fencer=None,
        confidence=0.0,
        method="PENDING",
        notes="no identity match",
    )
    commit(_ingest_ctx({"V2": [held]}, _parsed(20)), _db())


class TestSyncMode:
    """SYNC.CYCLE.06, SYNC.PAUSE.04, LOG.PRIV.01 and the ingest step's outputs,
    through `ingest_cli.main()` as the workflow runs it."""

    def _main(
        self,
        monkeypatch,
        tmp_path,
        *flags,
        refuse: bool | Callable[[], None] = False,
        db=None,
    ):
        db = db or _cert()
        notifier = MagicMock()
        outputs = tmp_path / "github_output"
        outputs.write_text("")
        monkeypatch.setenv("GITHUB_OUTPUT", str(outputs))
        argv = [
            "ingest_cli",
            "--flow",
            "ingest_domestic",
            "--event-code",
            CODE,
            "--season-end-year",
            "2027",
            "--from-url",
            "--md-target",
            "storage",
            "--record-run",
            "cert",
            *flags,
        ]
        monkeypatch.setattr("sys.argv", argv)
        real = ingest_cli._run_parsed_through_flow

        def flow(parsed, *a, **k):
            if refuse and parsed.weapon == "SABRE":
                from python.pipeline.core.contract import ListingRefused

                if callable(refuse):
                    refuse()
                raise ListingRefused("identity", NAMED_REFUSAL)
            return real(parsed, *a, **k)

        kept = [
            {"uuid": u, "name": name, "finished": True, "day": None}
            for u, (name, _) in FTL.listings.items()
        ]
        exit_code = 0
        with (
            recorded(applier=MemoryApplier(db), order=db.order),
            patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=FTL),
            patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
            patch(
                "python.tools.scrape_ftl_event_urls.parse_event_schedule", return_value=(kept, [])
            ),
            patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None),
            patch("python.pipeline.ingest_cli._after_event_run"),
            patch("python.pipeline.ingest_cli._run_parsed_through_flow", side_effect=flow),
            patch("python.pipeline.ingest_cli.create_db_connector", return_value=db),
            patch("python.pipeline.ingest_cli.TelegramNotifier", return_value=notifier),
        ):
            try:
                ingest_cli.main()
            except SystemExit as e:
                exit_code = e.code
        values = dict(
            line.split("=", 1) for line in outputs.read_text().splitlines() if "=" in line
        )
        return exit_code, notifier, values, db

    def test_LOG_PRIV_01_a_refusal_logs_its_kind_and_listing_and_no_name(
        self, monkeypatch, tmp_path, capsys
    ):
        """D12: the refusal names a fencer and two birth years; the log has
        its kind and its listing, Telegram and the run row the whole of it."""
        code, notifier, _, db = self._main(monkeypatch, tmp_path, refuse=True)
        log = capsys.readouterr()
        text = log.out + log.err
        assert code == 1
        assert (
            "ListingRefused [identity] Szabla Mężczyzn kat. 2: a row fits no single roster fencer"
            in text
        )  # REFUSAL.SAY (G60 A)
        for leak in ("NOWAK", "ZIELIŃSKI", "KOWALSKI", "1970", "1968", "Traceback"):
            assert leak not in text, leak
        (call,) = notifier.notify_pipeline_failure.call_args_list
        assert NAMED_REFUSAL in call.args[0]
        assert NAMED_REFUSAL in _run(db)["error"]

    def test_LOG_PRIV_04_an_international_pending_row_logs_its_kind_and_listing(
        self, monkeypatch, tmp_path, capsys
    ):
        """G37 A: the commit's own refusal of an international PENDING row,
        through the recorded run, as the workflow runs it: the log has its kind
        and listing and no traceback; the run row and Telegram name the row."""
        code, notifier, values, db = self._main(
            monkeypatch, tmp_path, refuse=_international_pending
        )
        log = capsys.readouterr()
        text = log.out + log.err
        assert code == 1
        summary = "1 row(s) fit no single roster fencer (no identity match: 1)"
        assert f"ListingRefused [identity] Szabla Mężczyzn kat. 2: {summary}" in text
        assert f"failed: ListingRefused [identity] Szabla Mężczyzn kat. 2: {summary}" in text
        for leak in ("PRZYKŁADOWA", "Traceback"):
            assert leak not in text, leak
        assert "PRZYKŁADOWA Anna" in notifier.notify_pipeline_failure.call_args.args[0]
        assert "PRZYKŁADOWA Anna" in _run(db)["error"]
        refusal = _run(db)["listings"]["refusal"]
        assert (refusal["kind"], refusal["listing"]) == ("identity", "Szabla Mężczyzn kat. 2")
        assert refusal["public"] == summary  # REFUSAL.SAY (G60 A): the sync pauses with it
        assert values["error"] == "ListingRefused"

    def test_LOG_PRIV_05_any_other_error_logs_its_type_and_frames(
        self, monkeypatch, tmp_path, capsys
    ):
        """G38 A: an error that is not a recorded refusal leaves the log with
        its type and where it was raised (file, line, function), never its
        message, which can name a fencer; the run row and Telegram keep it."""

        def broken():
            raise RuntimeError("PRZYKŁADOWA Anna, born 1972, broke the read")

        code, notifier, values, db = self._main(monkeypatch, tmp_path, refuse=broken)
        log = capsys.readouterr()
        text = log.out + log.err
        assert code == 1
        assert "RuntimeError" in text
        assert 'test_cert_apply.py", line' in text and "in broken" in text
        for leak in ("PRZYKŁADOWA", "1972", "broke the read"):
            assert leak not in text, leak
        assert "PRZYKŁADOWA Anna" in notifier.notify_pipeline_failure.call_args.args[0]
        assert "PRZYKŁADOWA Anna" in _run(db)["error"]
        assert values["error"] == "RuntimeError"

    def test_SYNC_CYCLE_06_quiet_sends_nothing_to_telegram(self, monkeypatch, tmp_path):
        """R3.2 A: in sync mode the outcome job speaks; the ingest step is quiet."""
        code, notifier, values, _ = self._main(monkeypatch, tmp_path, "--quiet", refuse=True)
        assert code == 1 and notifier.method_calls == []
        assert values["reported"] == "true"
        code, notifier, _, _ = self._main(monkeypatch, tmp_path, "--quiet")
        assert code == 0 and notifier.method_calls == []

    def test_SYNC_CYCLE_06_quiet_is_for_a_recorded_run_only(self, monkeypatch):
        argv = ["ingest_cli", "--flow", "ingest_domestic", "--event-code", CODE]
        monkeypatch.setattr(
            "sys.argv", [*argv, "--season-end-year", "2027", "--from-url", "--quiet"]
        )
        with pytest.raises(SystemExit):
            ingest_cli.main()

    def test_SYNC_CYCLE_07_the_ingest_step_outputs_its_run(self, monkeypatch, tmp_path):
        """S3: the promote job's condition reads them."""
        _, _, values, _ = self._main(monkeypatch, tmp_path, "--quiet")
        assert (values["run_id"], values["finished"], values["gate"]) == ("41", "true", "passed")
        _, _, values, _ = self._main(monkeypatch, tmp_path, "--quiet", refuse=True)
        assert (values["run_id"], values["finished"], values["gate"]) == ("41", "false", "")
        assert values["error"] == "ListingRefused"  # its type only: the message names fencers

    def test_SYNC_PAUSE_04_a_finished_run_lifts_the_events_pause(self, monkeypatch, tmp_path):
        """D8, S5: a manual ingest whose run finishes lifts the pause; a failed one does not."""
        _, _, _, db = self._main(monkeypatch, tmp_path)
        assert db.resumed == [CODE]
        assert db.order.index("resume") > db.order.index("finished")
        _, _, _, db = self._main(monkeypatch, tmp_path, refuse=True)
        assert db.resumed == []


def test_LOG_PRIV_02_a_pzsz_cycle_logs_no_starter(capsys):
    """D12, §04.9: the log of a recorded PZSz run carries counts and capture
    times, never a starter's name or birth year."""
    from python.tests import test_pzsz_routing as pz

    class CertPzsz(CertMemoryDb, pz.PzszMemoryDb):
        pass

    event = _event(9, pz.CODE, "2026-10-04", 2)
    event["dt_end"] = "2026-10-05"
    event["id_pzsz_event"] = 4588
    roster = [
        _fencer(301, "PRZYKŁADOWY", "Jan", 1971),
        _fencer(302, "WZORCOWY", "Jakub", 1976),
        _fencer(303, "PRZYKŁADOWA", "Anna", 1969, gender="F"),
    ]
    cert = CertPzsz(roster, [event])
    with recorded(applier=MemoryApplier(cert), order=cert.order):
        pz._with_pages(
            pz._pages(),
            ingest_cli.ingest_event_from_url,
            event_code=pz.CODE,
            season_end_year=2027,
            db=cert,
            record_run="cert",
        )
    log = capsys.readouterr()
    text = log.out + log.err
    assert "starters" in text or "start list" in text  # the capture is logged, by count
    for leak in ("PRZYKŁADOW", "WZORCOWY", "TESTOWSKA", "1971", "1976", "1969"):
        assert leak not in text, leak
