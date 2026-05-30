"""
Unified-pipeline XML ingest path (post-Phase 6 / ADR-050).

Background
----------
Two ingestion pipelines existed before this fix:

  1. URL/EVF (review_cli) — runs S1-S7, writes tbl_*_draft, commits via
     fn_commit_event_draft. Commit-time joint-pool detector (ADR-049) sets
     bool_joint_pool_split=TRUE and re-sums int_participant_count across
     siblings sharing url_results.

  2. Local XML (ingest_cli → orchestrator.process_xml_file) — legacy direct
     write to tbl_tournament + tbl_result. Bypasses fn_commit_event_draft
     entirely, so url_results stays NULL and joint-pool never fires. PPW4 +
     PPW5 2025-26 epee V1 rows in PROD ended up with 35 / 36 participants
     instead of the full combined-pool size for that reason.

These tests pin the contract for the **new** unified XML path: ingest_cli
must route through run_pipeline + the draft commit RPC, so every committed
tournament carries non-NULL url_results and the joint-pool detector runs.

Test IDs are reserved for the per-event RTM update; final IDs land in the
milestone test table once the ADR is signed off.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"


def _silent_notifier():
    from python.pipeline.notifications import TelegramNotifier
    return TelegramNotifier(None, None)


class TestUnifiedXmlIngest:
    """The new ingest_cli unified XML path must populate url_results.

    Symptom these tests pin: PPW4-V1-M-EPEE-2025-2026 and
    PPW5-V1-M-EPEE-2025-2026 ended up with url_results=NULL and
    int_participant_count=35 / 36 (V-cat slice instead of full combined
    pool) because process_xml_file never reached the unified pipeline.
    """

    def test_unified_ingest_function_exists(self):
        """The new entry point must exist and accept url_event + event_code.

        Before fix: ImportError — the function does not exist.
        After fix: importable, callable, accepts the required parameters.
        """
        from python.pipeline.ingest_cli import ingest_xml_unified  # noqa: F401

    def test_unified_ingest_passes_url_to_parser_as_source_url(self):
        """The url_event must flow into ParsedTournament.source_url so the
        downstream draft writer's _to_human_results_url() picks it up.

        Before fix: legacy process_xml_file ignores the URL entirely.
        After fix: fencingtime_xml.parse is called with source_url=<url_event>.
        """
        from python.pipeline import ingest_cli

        captured = {}

        def fake_parse(file_bytes, source_url=None):
            captured["source_url"] = source_url
            # Return a minimal ParsedTournament-shaped object so run_pipeline
            # can be exercised by the patched run_pipeline below.
            from python.pipeline.ir import ParsedTournament, SourceKind
            return ParsedTournament(
                source_kind=SourceKind.FENCINGTIME_XML,
                results=[],
                source_url=source_url,
            )

        with patch("python.pipeline.ingest_cli.create_db_connector"), \
             patch("python.scrapers.fencingtime_xml.parse", side_effect=fake_parse) as mock_parse, \
             patch("python.pipeline.orchestrator.run_pipeline") as mock_run, \
             patch("python.pipeline.ingest_cli.DraftStore"):
            mock_run.return_value = MagicMock(
                halted=False, halted_at_stage=None,
                vcat_groups={}, matches=[], event={"id_event": 1},
            )
            # url_event_override is the explicit-injection path; the default
            # path reads tbl_event.url_event off the event row in DB.
            mock_db = MagicMock()
            mock_db.find_event_by_code.return_value = {
                "id_event": 1, "txt_code": "PPW4-SPWS-2025-2026",
                "url_event": None,  # force the override path
            }
            ingest_cli.ingest_xml_unified(
                path=str(FIXTURES / "combined_v0v1.xml"),
                url_event_override="https://fencingtimelive.com/events/results/TESTUUID",
                event_code="PPW4-SPWS-2025-2026",
                season_end_year=2026,
                db=mock_db,
                notifier=_silent_notifier(),
            )
        assert captured.get("source_url") == \
            "https://fencingtimelive.com/events/results/TESTUUID", (
                "url_event must be threaded to fencingtime_xml.parse as "
                "source_url so the draft writer can compute url_results from it"
            )

    def test_unified_ingest_writes_drafts_via_draftstore(self):
        """ingest_xml_unified must route through DraftStore (so commit goes
        through fn_commit_event_draft, which runs the joint-pool detector),
        rather than writing directly to live tables like the legacy path.

        Before fix: legacy process_xml_file calls db.ingest_results() directly.
        After fix: drafts land in tbl_tournament_draft via DraftStore — the
        only path that gets joint-pool semantics at commit time (ADR-049).
        """
        from python.pipeline import ingest_cli

        captured: dict = {"tournament_drafts_calls": 0, "result_drafts_calls": 0}

        class _CaptureDraftStore:
            def __init__(self, db):
                self.db = db
            def write_tournament_drafts(self, tournaments, run_id):
                captured["tournament_drafts_calls"] += 1
                captured["last_tournaments"] = tournaments
                captured["last_run_id"] = run_id
                return list(range(1, len(tournaments) + 1))
            def write_result_drafts(self, results, run_id):
                captured["result_drafts_calls"] += 1
                return len(results)

        # Short-circuit run_pipeline so the test doesn't depend on real
        # matcher / DB state. The unit under test is the orchestration in
        # ingest_xml_unified, not the pipeline itself (covered elsewhere).
        from python.pipeline.types import PipelineContext
        fake_event = {
            "id_event": 99, "txt_code": "PPW4-SPWS-2025-2026",
            "url_event": "https://fencingtimelive.com/events/results/TESTUUID",
        }
        mock_db = MagicMock()
        mock_db.find_event_by_code.return_value = fake_event

        def fake_run_iteration(self, parsed, staging_dir=None):
            # Simulate the well-tested ReviewSession path writing drafts.
            if self.run_id is None:
                import uuid as _uuid
                self.run_id = str(_uuid.uuid4())
            self.draft_store.write_tournament_drafts(
                tournaments=[{
                    "id_event": 99,
                    "txt_code": "PPW4-V1-M-EPEE-2025-2026",
                    "url_results": parsed.source_url,
                    "enum_age_category": "V1",
                }],
                run_id=self.run_id,
            )
            return MagicMock(halted=False, matches=[]), None

        with patch("python.pipeline.ingest_cli.create_db_connector", return_value=mock_db), \
             patch("python.pipeline.ingest_cli.DraftStore", _CaptureDraftStore), \
             patch(
                 "python.pipeline.review_cli.ReviewSession.run_iteration",
                 fake_run_iteration,
             ):
            ingest_cli.ingest_xml_unified(
                path=str(FIXTURES / "combined_v0v1.xml"),
                event_code="PPW4-SPWS-2025-2026",
                season_end_year=2026,
                notifier=_silent_notifier(),
            )

        assert captured["tournament_drafts_calls"] >= 1, (
            "ingest_xml_unified must write to DraftStore.write_tournament_drafts — "
            "that's what routes the data through fn_commit_event_draft on commit "
            "(where the joint-pool detector runs)"
        )
        # Sanity: the URL on the event flowed all the way to url_results.
        rows = captured.get("last_tournaments", [])
        assert rows and rows[0].get("url_results"), (
            "url_event must flow into url_results on each draft row"
        )

    def test_legacy_process_xml_file_emits_deprecation_warning(self):
        """process_xml_file is retired (kept only as a thin compat shim).

        Before fix: no warning — silently writes to live tables with the
        bugs documented above.
        After fix: DeprecationWarning fires, pointing callers to
        ingest_xml_unified.
        """
        import warnings
        from python.pipeline.orchestrator import process_xml_file

        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            try:
                process_xml_file(
                    file_bytes=b"<CompetitionIndividuelle/>",
                    filename="empty.xml",
                    db=MagicMock(),
                    notifier=_silent_notifier(),
                    season_end_year=2026,
                )
            except Exception:
                pass  # we only care about the warning, not the outcome
        assert any(
            issubclass(w.category, DeprecationWarning)
            and "ingest_xml_unified" in str(w.message)
            for w in caught
        ), (
            "process_xml_file must emit a DeprecationWarning pointing to "
            "ingest_xml_unified so any remaining caller is forced to migrate"
        )
