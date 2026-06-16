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
        "id_event": 1, "txt_code": "PPW4-2025-2026",
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

        with patch("python.scrapers.fencingtime_xml.parse") as mock_parse, \
             patch("python.pipeline.run.run_flow", side_effect=fake_run_flow):
            mock_parse.return_value = MagicMock(is_pool_only_qualifier=False)
            ingest_cli.ingest_via_flow(
                path=[str(FIXTURES / "single_category.xml")],
                event_code="PPW4-2025-2026", season_end_year=2026,
                db=_event_db(), notifier=_silent_notifier())

        assert mock_parse.call_count == 1
        assert len(seen) == 1
        params, svc = seen[0]
        assert svc.config["parsed"] is mock_parse.return_value
        assert svc.config["event_code"] == "PPW4-2025-2026"
        assert svc.config["season_end_year"] == 2026

    def test_uses_ingest_domestic_flow(self):
        """N8.2 the CLI drives the INGEST_DOMESTIC flow specifically."""
        from python.pipeline import ingest_cli
        from python.pipeline.engine.flows import Flow

        seen = []
        with patch("python.scrapers.fencingtime_xml.parse") as mock_parse, \
             patch("python.pipeline.run.run_flow",
                   side_effect=lambda p, svc=None, **k: seen.append(p) or MagicMock()):
            mock_parse.return_value = MagicMock(is_pool_only_qualifier=False)
            ingest_cli.ingest_via_flow(
                path=str(FIXTURES / "single_category.xml"),
                event_code="PPW4-2025-2026", season_end_year=2026,
                db=_event_db(), notifier=_silent_notifier())
        assert seen[0].flow == Flow.INGEST_DOMESTIC

    def test_per_file_source_url_fragment(self):
        """N8.3 each file's source_url = event url_event + '#'+filename, so the
        IR carries per-file provenance (matches the legacy unified path)."""
        from python.pipeline import ingest_cli

        captured = {}

        def fake_parse(file_bytes, source_url=None):
            captured["source_url"] = source_url
            return MagicMock(is_pool_only_qualifier=False)

        with patch("python.scrapers.fencingtime_xml.parse", side_effect=fake_parse), \
             patch("python.pipeline.run.run_flow", return_value=MagicMock()):
            ingest_cli.ingest_via_flow(
                path=str(FIXTURES / "single_category.xml"),
                event_code="PPW4-2025-2026", season_end_year=2026,
                db=_event_db(), notifier=_silent_notifier())
        assert captured["source_url"].startswith(
            "https://fencingtimelive.com/events/results/TESTUUID#")
        assert captured["source_url"].endswith(".xml")

    def test_pool_only_qualifier_skipped(self):
        """N8.4 a pool-only qualifier (no DE bracket) is skipped — no run_flow."""
        from python.pipeline import ingest_cli

        calls = []
        with patch("python.scrapers.fencingtime_xml.parse") as mock_parse, \
             patch("python.pipeline.run.run_flow",
                   side_effect=lambda *a, **k: calls.append(1) or MagicMock()):
            mock_parse.return_value = MagicMock(is_pool_only_qualifier=True)
            ingest_cli.ingest_via_flow(
                path=str(FIXTURES / "single_category.xml"),
                event_code="PPW4-2025-2026", season_end_year=2026,
                db=_event_db(), notifier=_silent_notifier())
        assert calls == []

    def test_unknown_event_raises(self):
        """N8.5 an unknown event_code is a hard error (cannot ingest nowhere)."""
        from python.pipeline import ingest_cli
        db = MagicMock()
        db.find_event_by_code.return_value = None
        with patch("python.scrapers.fencingtime_xml.parse"):
            with pytest.raises(ValueError):
                ingest_cli.ingest_via_flow(
                    path="x.xml", event_code="NOPE-2025-2026",
                    season_end_year=2026, db=db, notifier=_silent_notifier())


class TestCliRouting:
    def test_flag_routes_to_ingest_via_flow(self):
        """N8.6 `--flow ingest_domestic <path> --event-code X` dispatches to
        ingest_via_flow (not the legacy draft path)."""
        from python.pipeline import ingest_cli

        called = {}
        argv = ["prog", str(FIXTURES / "single_category.xml"),
                "--flow", "ingest_domestic", "--event-code", "PPW4-2025-2026",
                "--season-end-year", "2026"]
        with patch("sys.argv", argv), \
             patch("python.pipeline.ingest_cli.ingest_via_flow") as mock_flow, \
             patch("python.pipeline.ingest_cli.TelegramNotifier",
                   return_value=_silent_notifier()):
            mock_flow.return_value = []
            ingest_cli.main()
            called["args"] = mock_flow.call_args
        assert called["args"].kwargs["event_code"] == "PPW4-2025-2026"
        assert called["args"].kwargs["season_end_year"] == 2026
