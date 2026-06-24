"""Step B — wire `run_flow` into the CLI (`--flow ingest_domestic`).

Plan IDs N8.1–N8.6. Maps to FR-112 (the NEW pipeline reachable from an operator
entry point). Until now `run_flow` was referenced only by `run.py`, `worker.py`,
and tests; `ingest_cli` drove the OLD draft pipeline. `ingest_via_flow` parses each
source via the `fencingtime_xml` parser (PARSERS registry), injects the IR into
`svc.config["parsed"]`, and runs `INGEST_DOMESTIC` through `run_flow` — Commit
writes live atomically per V-cat bracket (Step A), no draft/review gate (ADR-074).

DB + run_flow are mocked here (CLI orchestration contract); a real LOCAL ingest +
parity-vs-legacy diff is the live Step B acceptance.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"


def _silent_notifier():
    from python.pipeline.notifications import TelegramNotifier

    return TelegramNotifier(None, None)


def _event_db():
    db = MagicMock()
    db.find_event_by_code.return_value = {
        "id_event": 1,
        "txt_code": "PPW4-2025-2026",
        "url_event": "https://fencingtimelive.com/events/results/TESTUUID",
    }
    return db


class TestIngestViaFlow:
    def test_parses_and_calls_run_flow_per_file(self):
        """N8.1 each file is parsed via fencingtime_xml.parse and handed to
        run_flow with the IR + event_code + season_end_year in svc.config."""
        from python.pipeline import ingest_cli

        seen = []

        def fake_run_flow(params, svc=None, **kw):
            seen.append((params, svc))
            ctx = MagicMock()
            ctx.get.return_value = {"skipped": False, "persisted": True, "tournaments": []}
            return ctx

        with (
            patch("python.scrapers.fencingtime_xml.parse") as mock_parse,
            patch("python.pipeline.run.run_flow", side_effect=fake_run_flow),
        ):
            mock_parse.return_value = MagicMock(is_pool_only_qualifier=False)
            ingest_cli.ingest_via_flow(
                path=[str(FIXTURES / "single_category.xml")],
                event_code="PPW4-2025-2026",
                season_end_year=2026,
                db=_event_db(),
                notifier=_silent_notifier(),
            )

        assert mock_parse.call_count == 1
        # One INGEST_DOMESTIC per file; the event-scoped POST_COMMIT (ADR-075
        # StagingFormatter fire) is a separate run_flow and is filtered out here.
        from python.pipeline.engine.flows import Flow

        ingest_calls = [(p, s) for (p, s) in seen if p.flow == Flow.INGEST_DOMESTIC]
        assert len(ingest_calls) == 1
        params, svc = ingest_calls[0]
        assert svc.config["parsed"] is mock_parse.return_value
        assert svc.config["event_code"] == "PPW4-2025-2026"
        assert svc.config["season_end_year"] == 2026

    def test_uses_ingest_domestic_flow(self):
        """N8.2 the CLI drives the INGEST_DOMESTIC flow specifically."""
        from python.pipeline import ingest_cli
        from python.pipeline.engine.flows import Flow

        seen = []
        with (
            patch("python.scrapers.fencingtime_xml.parse") as mock_parse,
            patch(
                "python.pipeline.run.run_flow",
                side_effect=lambda p, svc=None, **k: seen.append(p) or MagicMock(),
            ),
        ):
            mock_parse.return_value = MagicMock(is_pool_only_qualifier=False)
            ingest_cli.ingest_via_flow(
                path=str(FIXTURES / "single_category.xml"),
                event_code="PPW4-2025-2026",
                season_end_year=2026,
                db=_event_db(),
                notifier=_silent_notifier(),
            )
        assert seen[0].flow == Flow.INGEST_DOMESTIC

    def test_per_file_source_url_fragment(self):
        """N8.3 each file's source_url = event url_event + '#'+filename, so the
        IR carries per-file provenance (matches the legacy unified path)."""
        from python.pipeline import ingest_cli

        captured = {}

        def fake_parse(file_bytes, source_url=None):
            captured["source_url"] = source_url
            return MagicMock(is_pool_only_qualifier=False)

        with (
            patch("python.scrapers.fencingtime_xml.parse", side_effect=fake_parse),
            patch("python.pipeline.run.run_flow", return_value=MagicMock()),
        ):
            ingest_cli.ingest_via_flow(
                path=str(FIXTURES / "single_category.xml"),
                event_code="PPW4-2025-2026",
                season_end_year=2026,
                db=_event_db(),
                notifier=_silent_notifier(),
            )
        assert captured["source_url"].startswith(
            "https://fencingtimelive.com/events/results/TESTUUID#"
        )
        assert captured["source_url"].endswith(".xml")

    def test_pool_only_qualifier_skipped(self):
        """N8.4 a pool-only qualifier (no DE bracket) is skipped — no run_flow."""
        from python.pipeline import ingest_cli

        calls = []
        with (
            patch("python.scrapers.fencingtime_xml.parse") as mock_parse,
            patch(
                "python.pipeline.run.run_flow",
                side_effect=lambda *a, **k: calls.append(1) or MagicMock(),
            ),
        ):
            mock_parse.return_value = MagicMock(is_pool_only_qualifier=True)
            ingest_cli.ingest_via_flow(
                path=str(FIXTURES / "single_category.xml"),
                event_code="PPW4-2025-2026",
                season_end_year=2026,
                db=_event_db(),
                notifier=_silent_notifier(),
            )
        assert calls == []

    def test_unknown_event_raises(self):
        """N8.5 an unknown event_code is a hard error (cannot ingest nowhere)."""
        from python.pipeline import ingest_cli

        db = MagicMock()
        db.find_event_by_code.return_value = None
        with patch("python.scrapers.fencingtime_xml.parse"):
            with pytest.raises(ValueError):
                ingest_cli.ingest_via_flow(
                    path="x.xml",
                    event_code="NOPE-2025-2026",
                    season_end_year=2026,
                    db=db,
                    notifier=_silent_notifier(),
                )


class TestCliRouting:
    def test_flag_routes_to_ingest_via_flow(self):
        """N8.6 `--flow ingest_domestic <path> --event-code X` dispatches to
        ingest_via_flow (not the legacy draft path)."""
        from python.pipeline import ingest_cli

        called = {}
        argv = [
            "prog",
            str(FIXTURES / "single_category.xml"),
            "--flow",
            "ingest_domestic",
            "--event-code",
            "PPW4-2025-2026",
            "--season-end-year",
            "2026",
        ]
        with (
            patch("sys.argv", argv),
            patch("python.pipeline.ingest_cli.ingest_via_flow") as mock_flow,
            patch("python.pipeline.ingest_cli.TelegramNotifier", return_value=_silent_notifier()),
        ):
            mock_flow.return_value = []
            ingest_cli.main()
            called["args"] = mock_flow.call_args
        assert called["args"].kwargs["event_code"] == "PPW4-2025-2026"
        assert called["args"].kwargs["season_end_year"] == 2026


class TestIngestEventFromUrl:
    """Step B URL path — ingest a whole event from its url_event, reusing the
    FTL scrapers (parse_event_schedule / parse_tournament_name / ftl.parse_json)."""

    def test_discovers_brackets_and_runs_flow_per_bracket(self):
        """N8.7 fetch eventSchedule -> discover brackets -> run_flow per bracket,
        with weapon/gender/V-cat from the bracket name and results from FTL data."""
        from python.pipeline import ingest_cli

        db = MagicMock()
        db.find_event_by_code.return_value = {
            "id_event": 1,
            "txt_code": "PPW3-2025-2026",
            "url_event": "https://fencingtimelive.com/tournaments/eventSchedule/ABC",
            "dt_start": "2025-12-13",
        }

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
                if "/results/data/" in url:  # FTL data endpoint → standings JSON
                    return _Resp(
                        js=[{"id": "f1", "name": "KOWALSKI Jan", "place": "1", "country": "POL"}]
                    )
                return _Resp(text="<li>Tableau</li>")  # results page → has DE (not pools-only)

        seen = []

        def fake_run_flow(p, svc=None, **k):
            seen.append((p, svc))
            return MagicMock(get=lambda *a: {}, faults=[], report=[])

        with (
            patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=_Client()),
            patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
            patch(
                "python.tools.scrape_ftl_event_urls.parse_event_schedule",
                return_value=([{"uuid": "U1", "name": "Szpada Mężczyzn kat. 2"}], []),
            ),
            patch("python.pipeline.run.run_flow", side_effect=fake_run_flow),
        ):
            ingest_cli.ingest_event_from_url(
                event_code="PPW3-2025-2026",
                season_end_year=2026,
                db=db,
                notifier=_silent_notifier(),
            )

        # One INGEST_DOMESTIC per discovered bracket; the event-scoped POST_COMMIT
        # (ADR-075 staging fire) is filtered out here.
        from python.pipeline.engine.flows import Flow

        ingest_calls = [s for (p, s) in seen if p.flow == Flow.INGEST_DOMESTIC]
        assert len(ingest_calls) == 1
        parsed = ingest_calls[0].config["parsed"]
        assert (parsed.weapon, parsed.gender, parsed.category_hint) == ("EPEE", "M", "V2")
        assert len(parsed.results) == 1 and parsed.results[0].fencer_name == "KOWALSKI Jan"

    def test_replace_wipes_event_first(self):
        """N8.8 --replace deletes existing results+tournaments before re-ingest."""
        from python.pipeline import ingest_cli

        db = MagicMock()
        db.find_event_by_code.return_value = {
            "id_event": 9,
            "txt_code": "PPW3-2025-2026",
            "url_event": "https://x/eventSchedule/ABC",
            "dt_start": "2025-12-13",
        }
        wiped = {}
        with (
            patch("python.scrapers.ftl_auth.get_authed_ftl_client") as gc,
            patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
            patch("python.tools.scrape_ftl_event_urls.parse_event_schedule", return_value=([], [])),
            patch(
                "python.pipeline.ingest_cli._wipe_event_live",
                side_effect=lambda d, ide: (wiped.__setitem__("id", ide), (5, 3))[1],
            ),
        ):
            client = MagicMock()
            client.__enter__.return_value = client
            client.get.return_value = MagicMock(raise_for_status=lambda: None, text="")
            gc.return_value = client
            ingest_cli.ingest_event_from_url(
                event_code="PPW3-2025-2026",
                season_end_year=2026,
                db=db,
                notifier=_silent_notifier(),
                replace=True,
            )
        assert wiped["id"] == 9


class TestFtlDirectElimination:
    """N13.1 — pools-only detection on the from-URL path (ADR-067 analog)."""

    def test_detects_tableau(self):
        from python.pipeline import ingest_cli

        class _Client:
            def __init__(self, html):
                self._html = html

            def get(self, url):
                r = MagicMock()
                r.text = self._html
                r.raise_for_status = lambda: None
                return r

        assert ingest_cli._ftl_has_direct_elimination(_Client("<li>Tableau</li>"), "U1") is True
        assert ingest_cli._ftl_has_direct_elimination(_Client("<li>Pools only</li>"), "U2") is False


class TestResolveSources:
    """N13.3 — the keep-rule: pools-only dropped; one source per category
    (single beats BRACKET; else smaller BRACKET); overrides win; rest set aside."""

    @staticmethod
    def _round(name, uuid, weapon, gender, cats, count, has_de=True):
        return dict(
            name=name,
            uuid=uuid,
            url=f"https://r/{uuid}",
            weapon=weapon,
            gender=gender,
            cats=list(cats),
            count=count,
            has_de=has_de,
        )

    def _by_uuid(self, sources):
        return {s["uuid"]: s for s in sources}

    def test_pools_only_dropped_singles_win_bracket_set_aside(self):
        from python.pipeline.ingest_cli import _resolve_sources

        R = self._round
        rounds = [
            R("kat.0", "k0", "EPEE", "M", ["V0"], 12),
            R("kat.1", "k1", "EPEE", "M", ["V1"], 11),
            R("kat.2", "k2", "EPEE", "M", ["V2"], 19),
            R("kat.3", "k3", "EPEE", "M", ["V3"], 8),
            R("kat.4", "k4", "EPEE", "M", ["V4"], 6),
            R("kat. Veteran", "vet", "EPEE", "M", ["V0", "V1", "V2", "V3", "V4"], 76, has_de=False),
            R("Men's Épée", "men", "EPEE", "M", ["V0", "V1", "V2"], 18),
        ]
        s = self._by_uuid(_resolve_sources(rounds))
        assert s["vet"]["status"] == "dropped"  # pools-only (no DE)
        for k, v in [("k0", "V0"), ("k1", "V1"), ("k2", "V2"), ("k3", "V3"), ("k4", "V4")]:
            assert s[k]["status"] == "committed" and s[k]["commit_cats"] == [v]
        assert s["men"]["status"] == "skipped"  # owns nothing → set aside
        assert s["men"]["commit_cats"] == []
        # the set-aside is flagged as a duplicate of the kept singles
        assert s["men"].get("duplicate_of")  # non-empty

    def test_rule_2b_smaller_bracket_wins_when_no_single(self):
        from python.pipeline.ingest_cli import _resolve_sources

        R = self._round
        rounds = [
            R("A 0-1", "a", "FOIL", "M", ["V0", "V1"], 3),
            R("B 0-1", "b", "FOIL", "M", ["V0", "V1"], 8),
        ]
        s = self._by_uuid(_resolve_sources(rounds))
        assert s["a"]["status"] == "committed" and set(s["a"]["commit_cats"]) == {"V0", "V1"}
        assert s["b"]["status"] == "skipped"  # larger BRACKET set aside

    def test_admin_override_process_wins(self):
        from python.pipeline.ingest_cli import _resolve_sources

        R = self._round
        rounds = [
            R("kat.0", "k0", "EPEE", "M", ["V0"], 12),
            R("Men's Épée", "men", "EPEE", "M", ["V0"], 18),
        ]
        # admin says: process the Men's round for this event (skip the default single)
        ov = {"process": ["https://r/men"], "skip": ["https://r/k0"]}
        s = self._by_uuid(_resolve_sources(rounds, overrides=ov))
        assert s["men"]["status"] == "committed" and s["men"]["commit_cats"] == ["V0"]
        assert s["k0"]["status"] == "skipped"
