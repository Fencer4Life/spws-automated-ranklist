"""N14 — populate tbl_tournament.url_results during ingestion (ADR-073 amendment).

The Commit plugin persists each committed tournament's results-page URL from the
parsed WEB source (FTL/ENGARDE/FOURFENCE/DARTAGNAN/OPHARDT_HTML) via the new
`url_results` arg on `db.find_or_create_tournament`. XML / EVF-API / file sources
and non-http source_urls pass None → existing url_results is preserved.

  N14.4  db_connector.find_or_create_tournament forwards p_url_results to the RPC
  N14.5  Commit gate matrix — web kinds pass the URL; XML/EVF/file/non-http pass None
  N14.6  from-URL flow carries source_url=round-url + source_kind=FTL into the flow
  N14.8  StagingFormatter shows the persisted url_results link + populated summary

DB + run_flow are mocked here (contract); the live PPW3 re-ingest is the acceptance.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock, patch

import pytest

from python.pipeline.core.contract import Context, Services
from python.pipeline.ir import ParsedTournament, SourceKind
from python.pipeline.plugins.bridge import LEGACY
from python.pipeline.plugins.ingest import Commit
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult

# ---------------------------------------------------------------------------
# N14.4 — db_connector forwards p_url_results
# ---------------------------------------------------------------------------


class TestConnectorForwardsUrl:
    def test_find_or_create_forwards_p_url_results(self):
        """N14.4 a url_results arg reaches the RPC params as p_url_results."""
        from python.pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.rpc.return_value.execute.return_value.data = 501
        db = DbConnector(mock_sb)
        db.find_or_create_tournament(
            7, "EPEE", "M", "V2", "2026-04-01", "PPW", url_results="https://ftl/v2"
        )
        _, params = mock_sb.rpc.call_args.args
        assert params["p_url_results"] == "https://ftl/v2"

    def test_find_or_create_url_defaults_none(self):
        """N14.4 omitting url_results sends p_url_results=None (backwards-compatible)."""
        from python.pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.rpc.return_value.execute.return_value.data = 501
        db = DbConnector(mock_sb)
        db.find_or_create_tournament(7, "EPEE", "M", "V2", "2026-04-01", "PPW")
        _, params = mock_sb.rpc.call_args.args
        assert params["p_url_results"] is None


# ---------------------------------------------------------------------------
# N14.5 — Commit gate matrix
# ---------------------------------------------------------------------------


def _match(id_fencer, place, name):
    return StageMatchResult(
        scraped_name=name, place=place, id_fencer=id_fencer, confidence=100.0, method="AUTO_MATCHED"
    )


def _commit_with(source_kind, source_url):
    """Run Commit on a one-V-cat bracket whose parsed source has the given
    source_kind/source_url; return the url_results kwarg passed to find_or_create."""
    parsed = ParsedTournament(
        source_kind=source_kind,
        results=[],
        parsed_date=date(2026, 4, 1),
        weapon="EPEE",
        gender="M",
        category_hint="V2",
        season_end_year=2026,
        source_url=source_url,
    )
    pctx = PipelineContext(
        parsed=parsed, overrides=Overrides(), season_end_year=2026, event_code="PPW3-2025-2026"
    )
    pctx.event = {"id_event": 7, "txt_code": "PPW3-2025-2026", "enum_type": "PPW"}
    fv = {"V2": [_match(101, 1, "KOWALSKI Jan")]}
    pctx.vcat_groups = fv
    pctx.matches = fv["V2"]
    ctx = Context()
    ctx.data[LEGACY] = pctx
    ctx.data["event"] = pctx.event
    ctx.data["matches"] = fv["V2"]
    ctx.data["final_vcats"] = fv
    db = MagicMock()
    db.find_or_create_tournament.return_value = 201
    db.ingest_results.return_value = {"ok": True}
    plugin = Commit()
    ctx._begin(plugin)
    plugin.run(ctx, Services(db=db))
    return db.find_or_create_tournament.call_args.kwargs.get("url_results")


@pytest.mark.parametrize(
    "kind",
    [
        SourceKind.FTL,
        SourceKind.ENGARDE,
        SourceKind.FOURFENCE,
        SourceKind.DARTAGNAN,
        SourceKind.OPHARDT_HTML,
    ],
)
def test_web_source_writes_url(kind):
    """N14.5 every WEB source kind with an http source_url writes url_results."""
    assert _commit_with(kind, "https://host/results/U1") == "https://host/results/U1"


@pytest.mark.parametrize(
    "kind",
    [
        SourceKind.FENCINGTIME_XML,
        SourceKind.EVF_API,
        SourceKind.FILE_IMPORT,
    ],
)
def test_non_web_source_writes_none(kind):
    """N14.5 XML / EVF-API / file sources never write url_results (None → preserve)."""
    assert _commit_with(kind, "https://host/results/U1") is None


def test_non_http_source_url_writes_none():
    """N14.5 a non-http source_url (local file fragment) writes None."""
    assert _commit_with(SourceKind.FTL, "single_category.xml") is None


def test_missing_source_url_writes_none():
    """N14.5 a missing source_url writes None."""
    assert _commit_with(SourceKind.FTL, None) is None


# ---------------------------------------------------------------------------
# N14.6 — the from-URL flow carries the results URL into the flow
# ---------------------------------------------------------------------------


class TestFromUrlCarriesResultsUrl:
    def test_parsed_source_url_and_kind(self):
        """N14.6 the ParsedTournament handed to run_flow carries source_url = the
        round's FTL results page and source_kind = FTL (so Commit's gate writes it)."""
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
                if "/results/data/" in url:
                    return _Resp(
                        js=[{"id": "f1", "name": "KOWALSKI Jan", "place": "1", "country": "POL"}]
                    )
                return _Resp(text="<li>Tableau</li>")  # results page → has DE

        seen = []

        def fake_run_flow(p, svc=None, **k):
            seen.append((p, svc))
            return MagicMock(get=lambda *a: {}, faults=[], report=[])

        from python.pipeline.notifications import TelegramNotifier

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
                notifier=TelegramNotifier(None, None),
            )

        from python.pipeline.engine.flows import Flow

        ingest = [s for (p, s) in seen if p.flow == Flow.INGEST_DOMESTIC]
        assert len(ingest) == 1
        parsed = ingest[0].config["parsed"]
        assert parsed.source_kind == SourceKind.FTL
        assert parsed.source_url == "https://www.fencingtimelive.com/events/results/U1"


# ---------------------------------------------------------------------------
# N14.8 — staging report mentions the persisted url_results
# ---------------------------------------------------------------------------


class TestStagingMentionsUrl:
    def _run(self, tmp_path, live_rows, source_decisions):
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        ctx = Context()
        ctx.data["_bracket_reports"] = [[]]
        ctx.data["event"] = {"id_event": 7, "txt_code": "PPW3-2025-2026"}
        ctx.data["_source_decisions"] = source_decisions
        db = MagicMock()
        db.fetch_cert_rows_for_event.return_value = []
        db.fetch_fencer_db.return_value = []
        svc = Services(db=db, config={"staging_dir": str(tmp_path)})
        with (
            patch(
                "python.pipeline.plugins.staging_formatter._fetch_event_meta",
                return_value={"_full_row": {}, "urls": []},
            ),
            patch(
                "python.pipeline.plugins.staging_formatter._live_tournament_rows",
                return_value=live_rows,
            ),
        ):
            StagingFormatter().run(ctx, svc)
        return [p for p in tmp_path.glob("*.md") if not p.name.endswith(".diff.md")][0].read_text()

    def test_committed_shows_persisted_url_and_summary(self, tmp_path):
        """N14.8 the Committed section shows each persisted url_results link and a
        `Tournament URLs populated: N/M` summary; a non-keep-rule URL is preserved."""
        live = [
            {
                "id_tournament": 1,
                "txt_code": "PPW3-V2-M-EPEE-2025-2026",
                "enum_age_category": "V2",
                "enum_weapon": "EPEE",
                "enum_gender": "M",
                "dt_tournament": "2025-12-13",
                "url_results": "https://r/v2",
                "int_participant_count": 19,
            },
            {
                "id_tournament": 2,
                "txt_code": "PPW3-V3-M-EPEE-2025-2026",
                "enum_age_category": "V3",
                "enum_weapon": "EPEE",
                "enum_gender": "M",
                "dt_tournament": "2025-12-13",
                "url_results": "https://r/v3-preserved",
                "int_participant_count": 8,
            },
        ]
        # only V2 was (re)written by this run's keep-rule; V3's url is pre-existing
        decisions = [
            {
                "name": "kat. 2",
                "url": "https://r/v2",
                "weapon": "EPEE",
                "gender": "M",
                "status": "committed",
                "committed_categories": ["V2"],
                "categories": ["V2"],
            },
        ]
        md = self._run(tmp_path, live, decisions)
        assert "https://r/v2" in md and "https://r/v3-preserved" in md
        assert "Tournament URLs populated: 2/2" in md
        assert "preserved" in md.lower()
