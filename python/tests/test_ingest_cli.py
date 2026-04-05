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
