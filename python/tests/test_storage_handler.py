"""
Tests for the Supabase Storage handler.

Plan test IDs 9.169–9.172, 9.191–9.192:
  9.169  list_staging_files() returns list of .zip paths from staging/
  9.170  download_file(path) returns file bytes
  9.171  archive_zip() moves .zip to archive/{season}/{event}.zip
  9.172  archive_zip() deletes the staging file after move
  9.191  unzip_in_memory() returns dict of {filename: xml_bytes}, skips non-XML
  9.192  compress_previous_event() removes unzipped XMLs from current/
"""

from __future__ import annotations

import zipfile
from io import BytesIO
from unittest.mock import MagicMock, call


class TestStorageHandler:
    """Tests 9.169–9.172: StorageHandler wrapping Supabase Storage."""

    def test_list_staging_files(self):
        """9.169 list_staging_files() returns list of .zip paths from staging/."""
        from python.pipeline.storage_handler import StorageHandler

        mock_sb = MagicMock()
        mock_sb.storage.from_.return_value.list.return_value = [
            {"name": "20260221_wyniki_gdansk.zip"},
            {"name": "20260305_wyniki_warszawa.zip"},
        ]
        handler = StorageHandler(mock_sb)
        files = handler.list_staging_files()
        assert isinstance(files, list)
        assert len(files) == 2
        assert "20260221_wyniki_gdansk.zip" in files[0]

    def test_download_file(self):
        """9.170 download_file(path) returns file bytes."""
        from python.pipeline.storage_handler import StorageHandler

        mock_sb = MagicMock()
        mock_sb.storage.from_.return_value.download.return_value = b"<xml>test</xml>"
        handler = StorageHandler(mock_sb)
        data = handler.download_file("staging/test.zip")
        assert data == b"<xml>test</xml>"

    def test_archive_zip_moves_file(self):
        """9.171 archive_zip() moves .zip to archive/{season}/{event}.zip."""
        from python.pipeline.storage_handler import StorageHandler

        mock_sb = MagicMock()
        mock_sb.storage.from_.return_value.move.return_value = None
        handler = StorageHandler(mock_sb)
        result_path = handler.archive_zip(
            staging_path="staging/20260221_wyniki_gdansk.zip",
            season="SPWS-2025-2026",
            event="PPW4-Gdansk",
        )
        assert "archive/SPWS-2025-2026/PPW4-Gdansk.zip" in result_path
        mock_sb.storage.from_.return_value.move.assert_called_once()

    def test_archive_zip_deletes_staging(self):
        """9.172 archive_zip() deletes the staging file after move."""
        from python.pipeline.storage_handler import StorageHandler

        mock_sb = MagicMock()
        # move raises → fall back to copy+delete pattern
        mock_sb.storage.from_.return_value.move.side_effect = Exception("move not supported")
        mock_sb.storage.from_.return_value.download.return_value = b"zipdata"
        mock_sb.storage.from_.return_value.upload.return_value = None
        mock_sb.storage.from_.return_value.remove.return_value = None
        handler = StorageHandler(mock_sb)
        handler.archive_zip(
            staging_path="staging/20260221_wyniki_gdansk.zip",
            season="SPWS-2025-2026",
            event="PPW4-Gdansk",
        )
        # Should have called remove on the staging file
        mock_sb.storage.from_.return_value.remove.assert_called()


class TestUnzipInMemory:
    """Test 9.191: unzip_in_memory extracts XML files, skips non-XML."""

    def test_unzip_extracts_xml_skips_non_xml(self):
        """9.191 unzip_in_memory() returns dict of {filename: xml_bytes}, skips non-XML."""
        from python.pipeline.storage_handler import unzip_in_memory

        # Create a zip with 2 XMLs and 1 non-XML
        buf = BytesIO()
        with zipfile.ZipFile(buf, "w") as zf:
            zf.writestr("RESULTS_V50ME.xml", "<xml>epee</xml>")
            zf.writestr("RESULTS_V50WE.xml", "<xml>foil</xml>")
            zf.writestr("readme.txt", "not xml")
            zf.writestr("data.csv", "a,b,c")

        result = unzip_in_memory(buf.getvalue())
        assert isinstance(result, dict)
        assert len(result) == 2
        assert "RESULTS_V50ME.xml" in result
        assert "RESULTS_V50WE.xml" in result
        assert "readme.txt" not in result
        assert result["RESULTS_V50ME.xml"] == b"<xml>epee</xml>"


class TestCompressPreviousEvent:
    """Test 9.192: compress_previous_event removes unzipped XMLs from current/."""

    def test_compress_previous_removes_current(self):
        """9.192 compress_previous_event() removes unzipped XMLs from current/."""
        from python.pipeline.storage_handler import StorageHandler

        mock_sb = MagicMock()
        mock_sb.storage.from_.return_value.list.return_value = [
            {"name": "RESULTS_V50ME.xml"},
            {"name": "RESULTS_V50WE.xml"},
        ]
        mock_sb.storage.from_.return_value.remove.return_value = None
        handler = StorageHandler(mock_sb)
        handler.compress_previous_event(
            season="SPWS-2025-2026",
            previous_event="PPW3-Wroclaw",
        )
        # Should have called remove to clean up current/ files
        mock_sb.storage.from_.return_value.remove.assert_called()
