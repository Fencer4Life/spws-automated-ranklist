"""PROMO.RUN.01–09 — the record of one CERT ingestion (ADR-108 §4, build step 6).

`ingest-event.yml` with target cert records its run in tbl_ingest_run. Promote
replays that run on PROD, so the record holds what the replay must repeat:

  - the commit that ran, the event URL it ingested, the season end year;
  - a hash of the event schedule and of every source listing as parsed, which
    promote recomputes with the same functions before it replays;
  - each listing's keep-rule status and what its commit did (categories, N,
    faults), which the gate (build step 7) reads;
  - the input fingerprint and the master-data changes, computed in SQL by
    fn_ingest_run_open / fn_ingest_run_finish (pgTAP 100_ingest_run).

The run opens before the ingestion writes anything and closes FINISHED, or
FAILED with the error.
"""

from __future__ import annotations

import re
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import yaml

from python.pipeline.ir import ParsedResult
from python.pipeline.promotion import run_record as rr

ROOT = Path(__file__).resolve().parents[2]
EVENT = "PPW1-2026-2027"
SCHEDULE_URL = "https://www.fencingtimelive.com/tournaments/eventSchedule/ABC"


def _rows(*places: int) -> list[ParsedResult]:
    return [
        ParsedResult(source_row_id=f"r{p}", fencer_name=f"FENCER{p} Jan", place=p) for p in places
    ]


class TestListingHash:
    def test_a_listing_hashes_the_same_every_time(self):
        """PROMO.RUN.01"""
        a = rr.listing_sha256("Szpada M kat. 2", "U1", True, _rows(1, 2, 3))
        assert a == rr.listing_sha256("Szpada M kat. 2", "U1", True, _rows(1, 2, 3))
        assert re.fullmatch(r"[0-9a-f]{64}", a)

    def test_anything_the_keep_rule_or_the_matcher_reads_changes_it(self):
        """PROMO.RUN.01 — a place, a name, the tableau flag, the listing's own id."""
        base = rr.listing_sha256("Szpada M kat. 2", "U1", True, _rows(1, 2, 3))
        moved = _rows(1, 2, 3)
        moved[2].place = 4
        renamed = _rows(1, 2, 3)
        renamed[0].fencer_name = "FENCER1 Janusz"
        assert base != rr.listing_sha256("Szpada M kat. 2", "U1", True, moved)
        assert base != rr.listing_sha256("Szpada M kat. 2", "U1", True, renamed)
        assert base != rr.listing_sha256("Szpada M kat. 2", "U1", False, _rows(1, 2, 3))
        assert base != rr.listing_sha256("Szpada M kat. 2", "U2", True, _rows(1, 2, 3))

    def test_the_schedule_hash_moves_with_a_new_or_skipped_round(self):
        """PROMO.RUN.02"""
        kept = [{"uuid": "U1", "name": "Szpada M kat. 2"}]
        base = rr.schedule_sha256(kept, [])
        assert base == rr.schedule_sha256([dict(kept[0])], [])
        assert base != rr.schedule_sha256(kept + [{"uuid": "U2", "name": "Floret K kat. 1"}], [])
        assert base != rr.schedule_sha256(
            kept, [{"uuid": "U3", "name": "ELIMINACJE", "reason": "pools round"}]
        )


class _Resp:
    def __init__(self, text="", js=None):
        self.text = text
        self._js = js or []

    def raise_for_status(self):
        pass

    def json(self):
        return self._js


class _Client:
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def get(self, url):
        if "eventSchedule" in url:
            return _Resp(text="<schedule/>")
        if "/results/data/" in url:
            return _Resp(js=[{"id": "f1", "name": "KOWALSKI Jan", "place": "1", "country": "POL"}])
        return _Resp(text="<li>Tableau</li>")  # results page → has DE


def _db() -> MagicMock:
    db = MagicMock()
    db.get_type_engine.return_value = "SPWS_EVF_JOINED_V1_2026_2027"
    db.find_event_by_code.return_value = {
        "id_event": 7,
        "txt_code": EVENT,
        "url_event": None,
        "dt_start": "2026-10-03",
    }
    db.open_ingest_run.return_value = 41
    db.finish_ingest_run.return_value = {
        "created": [{"id_fencer": 368}],
        "deleted": [],
        "birth_year_moved": [],
        "aliases_added": [],
        "other": [],
    }
    return db


def _committed_ctx(*a, **k):
    ctx = MagicMock(faults=[], report=[])
    ctx.get = lambda key, default=None: (
        {"tournaments": [{"vcat": "V2", "id_tournament": 900, "n": 1}]}
        if key == "committed"
        else default
    )
    return ctx


def _ingest(db, *, record_run, run_flow=_committed_ctx, env=None):
    from python.pipeline import ingest_cli

    environ = {
        "GITHUB_SHA": "a" * 40,
        "GITHUB_SERVER_URL": "https://github.com",
        "GITHUB_REPOSITORY": "spws/ranklist",
        "GITHUB_RUN_ID": "123",
    }
    with (
        patch.dict("os.environ", env if env is not None else environ, clear=False),
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=_Client()),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch(
            "python.tools.scrape_ftl_event_urls.parse_event_schedule",
            return_value=(
                [{"uuid": "U1", "name": "Szpada Mężczyzn kat. 2", "finished": True, "day": None}],
                [{"uuid": "U9", "name": "ELIMINACJE", "reason": "pools round"}],
            ),
        ),
        patch("python.pipeline.ingest_cli._run_parsed_through_flow", side_effect=run_flow),
        patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None),
        patch("python.pipeline.ingest_cli._after_event_run"),
    ):
        return ingest_cli.ingest_event_from_url(
            event_code=EVENT,
            season_end_year=2027,
            db=db,
            replace=True,
            url_event_override=SCHEDULE_URL,
            record_run=record_run,
        )


class TestRecordedRun:
    def test_the_run_opens_before_the_ingestion_writes(self):
        """PROMO.RUN.03 — before the URL write and before the wipe."""
        db = _db()
        _ingest(db, record_run="cert")
        names = [c[0] for c in db.method_calls]
        assert names.index("open_ingest_run") < names.index("set_event_url_event")
        params = db.open_ingest_run.call_args.args[0]
        assert params == {
            "p_event_code": EVENT,
            "p_environment": "cert",
            "p_git_commit": "a" * 40,
            "p_season_end_year": 2027,
            "p_url_event": SCHEDULE_URL,
            "p_run_url": "https://github.com/spws/ranklist/actions/runs/123",
            "p_override_sha256": rr.override_sha256(EVENT),
        }

    def test_the_run_finishes_with_every_listing_hashed_and_its_outcome(self):
        """PROMO.RUN.03"""
        db = _db()
        _ingest(db, record_run="cert")
        run_id, listings = db.finish_ingest_run.call_args.args
        assert run_id == 41
        assert listings["schedule"]["sha256"] == rr.schedule_sha256(
            [{"uuid": "U1", "name": "Szpada Mężczyzn kat. 2", "finished": True, "day": None}],
            [{"uuid": "U9", "name": "ELIMINACJE", "reason": "pools round"}],
        )
        (round_,) = listings["rounds"]
        assert round_["uuid"] == "U1" and round_["status"] == "committed"
        assert round_["has_de"] is True and round_["count"] == 1
        assert re.fullmatch(r"[0-9a-f]{64}", round_["sha256"])
        assert round_["outcome"] == {
            "skipped": False,
            "tournaments": [{"category": "V2", "n": 1}],
            "faults": [],
        }
        db.fail_ingest_run.assert_not_called()

    def test_a_failure_closes_the_run_failed_and_still_raises(self):
        """PROMO.RUN.04"""
        db = _db()

        def boom(*a, **k):
            raise RuntimeError("commit refused")

        with pytest.raises(RuntimeError, match="commit refused"):
            _ingest(db, record_run="cert", run_flow=boom)
        run_id, error, listings = db.fail_ingest_run.call_args.args
        assert run_id == 41 and "commit refused" in error
        assert listings["schedule"] is not None
        db.finish_ingest_run.assert_not_called()

    def test_without_a_record_nothing_is_recorded(self):
        """PROMO.RUN.05 — LOCAL runs and target prod are unchanged."""
        db = _db()
        _ingest(db, record_run=None)
        db.open_ingest_run.assert_not_called()
        db.finish_ingest_run.assert_not_called()

    def test_an_unknown_environment_is_refused_before_anything_is_written(self):
        """PROMO.RUN.09"""
        db = _db()
        with pytest.raises(ValueError, match="prod"):
            _ingest(db, record_run="prod")
        db.open_ingest_run.assert_not_called()
        db.set_event_url_event.assert_not_called()


class TestProvenance:
    def test_the_commit_and_the_run_come_from_github_actions(self):
        """PROMO.RUN.06"""
        env = {
            "GITHUB_SHA": "b" * 40,
            "GITHUB_SERVER_URL": "https://github.com",
            "GITHUB_REPOSITORY": "o/r",
            "GITHUB_RUN_ID": "9",
        }
        assert rr.git_commit(env) == "b" * 40
        assert rr.run_url(env) == "https://github.com/o/r/actions/runs/9"
        assert rr.run_url({}) is None

    def test_outside_actions_the_commit_is_the_checkouts_head(self):
        """PROMO.RUN.06"""
        assert re.fullmatch(r"[0-9a-f]{40}", rr.git_commit({}))

    def test_the_override_file_is_hashed_when_there_is_one(self, tmp_path: Path):
        """PROMO.RUN.06"""
        (tmp_path / f"{EVENT}.yaml").write_text("identity: []\n")
        assert re.fullmatch(r"[0-9a-f]{64}", rr.override_sha256(EVENT, tmp_path) or "")
        assert rr.override_sha256("PPW9-2026-2027", tmp_path) is None


def _sql(text: str) -> str:
    text = re.sub(r"--[^\n]*", "", text)
    return re.sub(r"\s+", " ", text).strip().rstrip(";").strip()


class TestSchemaFingerprint:
    def test_the_function_runs_the_release_scripts_query(self):
        """PROMO.RUN.07 — CERT's and PROD's fingerprints are the release's."""
        script = (ROOT / "scripts/schema-fingerprint.sh").read_text()
        query = re.search(
            r"^(WITH func_hash.*?^FROM func_hash f, col_hash c;)", script, re.S | re.M
        )
        assert query
        migration = (ROOT / "supabase/migrations/20261003000014_ingest_run.sql").read_text()
        body = re.search(r"FUNCTION fn_schema_fingerprint\(\).*?AS \$\$(.*?)\$\$;", migration, re.S)
        assert body
        assert _sql(body.group(1)) == _sql(query.group(1))


class TestWiring:
    def test_the_cert_target_records_its_run(self):
        """PROMO.RUN.08"""
        wf = yaml.safe_load((ROOT / ".github/workflows/ingest-event.yml").read_text())
        (job,) = wf["jobs"].values()
        run = next(s["run"] for s in job["steps"] if "ingest_cli" in s.get("run", ""))
        # ADR-108 §9: the only target is cert (prod is refused), so every run is recorded.
        assert "--record-run cert)" in run

    def test_the_cli_refuses_a_record_without_a_url_ingestion(self, monkeypatch):
        """PROMO.RUN.08"""
        from python.pipeline import ingest_cli

        monkeypatch.setattr(
            "sys.argv",
            [
                "ingest_cli",
                "--season-end-year",
                "2027",
                "--event-code",
                EVENT,
                "--record-run",
                "cert",
                "x.xml",
            ],
        )
        with pytest.raises(SystemExit):
            ingest_cli.main()


class TestWhatTheGateReads:
    """PROMO.RUN.10–12 — build step 7 reads each listing's source rows and
    identity details, and why a refused listing ended the run."""

    def test_a_committed_listing_carries_its_rows_and_identity(self):
        """PROMO.RUN.10"""
        from python.pipeline.core.contract import ReportFragment

        identity = {
            "matches": [
                {"scraped_name": "KOWALSKI Jan", "place": 1, "method": "AUTO_MATCH", "notes": None},
                {
                    "scraped_name": "NOWAK Ewa",
                    "place": 2,
                    "method": "PENDING",
                    "notes": "namesakes",
                },
            ],
            "created": [
                {"scraped_name": "NOWY Adam", "near_miss": {"name": "NOWAK Adam", "confidence": 72}}
            ],
            "reconciled": [
                {
                    "id_fencer": 7,
                    "old_birth_year": 1990,
                    "new_birth_year": 1987,
                    "was_confirmed": True,
                    "anchor": "lower edge",
                }
            ],
            "conflicts": [
                {"id_fencer": 8, "reason": "declared_vs_bracket", "declared_birth_year": 1990}
            ],
            "alias_writebacks": [],
        }

        def with_identity(*a, **k):
            ctx = _committed_ctx()
            ctx.report = [ReportFragment("ResolveFencers", None, "IDENTITY", identity)]
            return ctx

        db = _db()
        _ingest(db, record_run="cert", run_flow=with_identity)
        (round_,) = db.finish_ingest_run.call_args.args[1]["rounds"]
        assert round_["rows"] == [[1, "KOWALSKI Jan"]]
        assert round_["identity"] == {
            "created": identity["created"],
            "reconciled": identity["reconciled"],
            "conflicts": identity["conflicts"],
            "pending": [{"scraped_name": "NOWAK Ewa", "place": 2, "notes": "namesakes"}],
        }

    def test_a_refused_listing_is_named_with_its_kind(self):
        """PROMO.RUN.11"""
        from python.pipeline.core.contract import ListingRefused

        def refused(*a, **k):
            raise ListingRefused("identity", "SABRE M listing not written: X (place 3): namesakes")

        db = _db()
        with pytest.raises(ValueError):
            _ingest(db, record_run="cert", run_flow=refused)
        listings = db.fail_ingest_run.call_args.args[2]
        assert listings["refusal"] == {
            "listing": "Szpada Mężczyzn kat. 2",
            "kind": "identity",
            "message": "SABRE M listing not written: X (place 3): namesakes",
        }

    def test_the_refusals_carry_their_kind_and_stay_value_errors(self):
        """PROMO.RUN.12"""
        from types import SimpleNamespace

        from python.pipeline.core.contract import ListingRefused
        from python.pipeline.joined_brackets import listing_order
        from python.pipeline.plugins.ingest import Commit

        with pytest.raises(ListingRefused) as repeated:
            listing_order([(1, "V1"), (1, "V0")], [1, 1])
        assert repeated.value.kind == "joined_bracket" and isinstance(repeated.value, ValueError)
        with pytest.raises(ListingRefused) as missing:
            listing_order([(1, "V1")], [1, 2])
        assert missing.value.kind == "joined_bracket"

        held = SimpleNamespace(
            method="PENDING", scraped_name="NOWAK Ewa", place=2, notes="namesakes", alternatives=[]
        )
        ctx = MagicMock()
        ctx.get = lambda key, default=None: [held] if key == "matches" else default
        with pytest.raises(ListingRefused) as pending:
            Commit._refuse_domestic_pending(ctx, None, {"V1": [held]}, {"V1"}, "SABRE", "M")
        assert pending.value.kind == "identity"
