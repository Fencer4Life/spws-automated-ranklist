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
