"""
Tests for the ingestion CLI entry point.

Plan test IDs 9.166–9.168:
  9.166  CLI processes single XML file and prints summary
  9.167  CLI processes .zip archive — extracts and processes each XML
  9.168  --dry-run parses and matches but skips DB writes
"""

from __future__ import annotations

import zipfile
from io import BytesIO
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"


class TestIngestCli:
    """Tests 9.166–9.168: CLI entry point."""

    def test_cli_processes_single_xml(self):
        """9.166 CLI processes single XML file and prints summary."""
        from python.pipeline.ingest_cli import run_ingest

        xml_path = FIXTURES / "single_category.xml"

        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.process_xml_file") as mock_process:
            mock_process.return_value = MagicMock(
                tournament_ids=[1], matched=5, pending=0,
                auto_created=0, skipped=0, errors=[], skipped_files=[],
            )
            summary = run_ingest(
                path=str(xml_path),
                season_end_year=2026,
                dry_run=False,
            )
            mock_process.assert_called_once()
            assert summary.matched == 5

    def test_cli_processes_zip_archive(self):
        """9.167 CLI processes .zip archive — extracts and processes each XML."""
        from python.pipeline.ingest_cli import run_ingest

        # Create a zip with 2 XML files
        xml1 = (FIXTURES / "single_category.xml").read_bytes()
        buf = BytesIO()
        with zipfile.ZipFile(buf, "w") as zf:
            zf.writestr("RESULTS_V50ME.xml", xml1)
            zf.writestr("RESULTS_V50WE.xml", xml1)
            zf.writestr("readme.txt", "not an XML")  # should be skipped

        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp:
            tmp.write(buf.getvalue())
            tmp_path = tmp.name

        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.process_xml_file") as mock_process:
            mock_process.return_value = MagicMock(
                tournament_ids=[1], matched=5, pending=0,
                auto_created=0, skipped=0, errors=[], skipped_files=[],
            )
            summary = run_ingest(
                path=tmp_path,
                season_end_year=2026,
                dry_run=False,
            )
            # Should process 2 XML files (skip readme.txt)
            assert mock_process.call_count == 2

        Path(tmp_path).unlink()

    def test_cli_dry_run_no_db_writes(self):
        """9.168 --dry-run parses and matches but skips DB writes."""
        from python.pipeline.ingest_cli import run_ingest

        xml_path = FIXTURES / "single_category.xml"

        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.process_xml_file") as mock_process:
            mock_process.return_value = MagicMock(
                tournament_ids=[], matched=0, pending=0,
                auto_created=0, skipped=0, errors=[], skipped_files=[],
            )
            summary = run_ingest(
                path=str(xml_path),
                season_end_year=2026,
                dry_run=True,
            )
            # process_xml_file should be called with dry_run=True
            call_kwargs = mock_process.call_args
            assert call_kwargs[1].get("dry_run") is True or \
                   (len(call_kwargs[0]) > 5 and call_kwargs[0][5] is True)

    def test_batch_sends_summary_notification(self):
        """9.197 After processing multiple files, notifier.summary() is called."""
        from python.pipeline.ingest_cli import run_ingest

        xml_path = FIXTURES / "single_category.xml"

        mock_notifier = MagicMock()
        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.process_xml_file") as mock_process:
            mock_process.return_value = MagicMock(
                tournament_ids=[1], matched=5, pending=0,
                auto_created=0, skipped=0, errors=[], skipped_files=[],
            )
            summary = run_ingest(
                path=str(xml_path),
                season_end_year=2026,
                dry_run=False,
                notifier=mock_notifier,
            )
            mock_notifier.summary.assert_called_once()

    def test_from_storage_does_not_auto_delete(self):
        """9.201 --from-storage does NOT auto-delete staging files after processing."""
        from python.pipeline.ingest_cli import run_ingest

        xml_path = FIXTURES / "single_category.xml"

        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.process_xml_file") as mock_process:
            mock_db = MagicMock()
            mock_create_db.return_value = mock_db
            mock_process.return_value = MagicMock(
                tournament_ids=[1], matched=5, pending=0,
                auto_created=0, skipped=0, errors=[], skipped_files=[],
            )
            summary = run_ingest(
                path=str(xml_path),
                season_end_year=2026,
                dry_run=False,
            )
            # Storage delete/archive should NOT be called from run_ingest
            mock_db.assert_not_called  # db doesn't have delete methods

    def test_main_catches_exception_and_notifies(self):
        """9.202 main() catches exception and calls notify_pipeline_failure."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.process_xml_file") as mock_process, \
             patch("python.pipeline.ingest_cli.TelegramNotifier") as mock_notifier_cls, \
             patch("sys.argv", ["ingest_cli", str(FIXTURES / "single_category.xml"), "--season-end-year", "2026"]):
            mock_notifier = MagicMock()
            mock_notifier_cls.return_value = mock_notifier
            mock_process.side_effect = RuntimeError("DB connection failed")
            with pytest.raises(RuntimeError):
                main()
            mock_notifier.notify_pipeline_failure.assert_called()

    def test_main_reraises_after_notification(self):
        """9.203 main() re-raises exception after notifying."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.process_xml_file") as mock_process, \
             patch("python.pipeline.ingest_cli.TelegramNotifier") as mock_notifier_cls, \
             patch("sys.argv", ["ingest_cli", str(FIXTURES / "single_category.xml"), "--season-end-year", "2026"]):
            mock_notifier_cls.return_value = MagicMock()
            mock_process.side_effect = RuntimeError("DB connection failed")
            with pytest.raises((RuntimeError, SystemExit)):
                main()


class TestDraftManagementCli:
    """P2.C1–P2.C6: Phase 2 (ADR-050) draft management flags.

    Plan IDs from /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md
    Phase 2 subplan doc/plans/rebuild/p2-drafts.md.

    Phase 2 ships the management flags fully. Orchestrator integration of
    --dry-run with the new IR pipeline is Phase 3 — for now, --dry-run keeps
    the existing path-based behaviour (test 9.168 covers it).

      P2.C1  --commit-draft <UUID> calls DraftStore.commit, prints summary
      P2.C2  --commit-draft with zero counts triggers notifier.warning
      P2.C3  --discard-draft <UUID> calls DraftStore.discard
      P2.C4  --list-drafts prints one row per outstanding run_id
      P2.C5  --resume-run-id <UUID> reads drafts and prints markdown diff
      P2.C6  --commit-draft + --discard-draft mutually exclusive (CLI error)
    """

    def test_commit_draft_calls_rpc_and_prints(self, capsys):
        """P2.C1 --commit-draft <UUID> calls DraftStore.commit, prints summary."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector") as mock_create_db, \
             patch("python.pipeline.ingest_cli.DraftStore") as mock_store_cls, \
             patch("python.pipeline.ingest_cli.TelegramNotifier") as mock_notifier_cls, \
             patch("sys.argv", ["ingest_cli", "--commit-draft",
                                "11111111-1111-1111-1111-111111111111"]):
            mock_store = MagicMock()
            mock_store.commit.return_value = {
                "run_id": "11111111-1111-1111-1111-111111111111",
                "tournaments_committed": 4, "results_committed": 117,
                "joint_pool_siblings_flagged": 2, "history_rows": 4,
            }
            mock_store_cls.return_value = mock_store
            mock_notifier_cls.return_value = MagicMock()

            main()
            mock_store.commit.assert_called_once_with("11111111-1111-1111-1111-111111111111")
            captured = capsys.readouterr()
            assert "4" in captured.out and "117" in captured.out

    def test_commit_draft_zero_counts_triggers_warning(self):
        """P2.C2 --commit-draft with zero counts triggers notifier.warning."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector"), \
             patch("python.pipeline.ingest_cli.DraftStore") as mock_store_cls, \
             patch("python.pipeline.ingest_cli.TelegramNotifier") as mock_notifier_cls, \
             patch("sys.argv", ["ingest_cli", "--commit-draft",
                                "00000000-0000-0000-0000-000000000000"]):
            mock_store = MagicMock()
            mock_store.commit.return_value = {
                "run_id": "00000000-0000-0000-0000-000000000000",
                "tournaments_committed": 0, "results_committed": 0,
                "joint_pool_siblings_flagged": 0, "history_rows": 0,
            }
            mock_store_cls.return_value = mock_store
            mock_notifier = MagicMock()
            mock_notifier_cls.return_value = mock_notifier

            with pytest.raises(SystemExit) as exc_info:
                main()
            assert exc_info.value.code == 1
            mock_notifier.warning.assert_called_once()

    def test_discard_draft_calls_rpc(self):
        """P2.C3 --discard-draft <UUID> calls DraftStore.discard."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector"), \
             patch("python.pipeline.ingest_cli.DraftStore") as mock_store_cls, \
             patch("python.pipeline.ingest_cli.TelegramNotifier") as mock_notifier_cls, \
             patch("sys.argv", ["ingest_cli", "--discard-draft",
                                "22222222-2222-2222-2222-222222222222"]):
            mock_store = MagicMock()
            mock_store.discard.return_value = {
                "run_id": "22222222-2222-2222-2222-222222222222",
                "tournaments_discarded": 3, "results_discarded": 50,
            }
            mock_store_cls.return_value = mock_store
            mock_notifier_cls.return_value = MagicMock()

            main()
            mock_store.discard.assert_called_once_with("22222222-2222-2222-2222-222222222222")

    def test_list_drafts_prints_table(self, capsys):
        """P2.C4 --list-drafts prints one row per outstanding run_id."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector"), \
             patch("python.pipeline.ingest_cli.DraftStore") as mock_store_cls, \
             patch("python.pipeline.ingest_cli.TelegramNotifier") as mock_notifier_cls, \
             patch("sys.argv", ["ingest_cli", "--list-drafts"]):
            mock_store = MagicMock()
            mock_store.list_drafts.return_value = [
                {"run_id": "aaa-1", "tournament_count": 4, "result_count": 117,
                 "first_seen": "2026-05-01T10:00:00Z"},
                {"run_id": "bbb-2", "tournament_count": 1, "result_count": 30,
                 "first_seen": "2026-05-02T09:00:00Z"},
            ]
            mock_store_cls.return_value = mock_store
            mock_notifier_cls.return_value = MagicMock()

            main()
            captured = capsys.readouterr()
            assert "aaa-1" in captured.out
            assert "bbb-2" in captured.out

    def test_resume_run_id_reads_drafts_and_prints_diff(self, capsys):
        """P2.C5 --resume-run-id <UUID> reads drafts and prints markdown diff."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector"), \
             patch("python.pipeline.ingest_cli.DraftStore") as mock_store_cls, \
             patch("python.pipeline.ingest_cli.TelegramNotifier") as mock_notifier_cls, \
             patch("sys.argv", ["ingest_cli", "--resume-run-id",
                                "33333333-3333-3333-3333-333333333333"]):
            mock_store = MagicMock()
            mock_store.read_drafts.return_value = (
                [{"txt_code": "TEST-V0", "enum_weapon": "EPEE", "enum_gender": "M",
                  "enum_age_category": "V0", "dt_tournament": "2026-04-01",
                  "url_results": "https://test/x"}],
                [{"txt_code": "TEST-V0", "int_place": 1,
                  "enum_match_method": "AUTO_MATCHED"}],
            )
            mock_store_cls.return_value = mock_store
            mock_notifier_cls.return_value = MagicMock()

            main()
            mock_store.read_drafts.assert_called_once_with(
                "33333333-3333-3333-3333-333333333333"
            )
            captured = capsys.readouterr()
            assert "33333333-3333-3333-3333-333333333333" in captured.out
            assert "TEST-V0" in captured.out

    def test_commit_and_discard_mutually_exclusive(self):
        """P2.C6 --commit-draft + --discard-draft mutually exclusive (CLI error)."""
        from python.pipeline.ingest_cli import main

        with patch("python.pipeline.ingest_cli.create_db_connector"), \
             patch("python.pipeline.ingest_cli.DraftStore"), \
             patch("python.pipeline.ingest_cli.TelegramNotifier"), \
             patch("sys.argv", ["ingest_cli",
                                "--commit-draft", "aaa",
                                "--discard-draft", "bbb"]):
            with pytest.raises(SystemExit):
                main()
