"""
Tests for full-season seed export from CERT.

Plan test IDs 9.209–9.213:
  9.209  export_fencer_seed returns valid SQL with all fencers
  9.210  export_full_season returns per-category SQL files
  9.211  Generated SQL contains idempotent event INSERTs (WHERE NOT EXISTS)
  9.212  Generated SQL uses fencer name lookups, not hardcoded IDs
  9.213  write_seed_files overwrites existing files (not append)
"""

from __future__ import annotations

import os
import tempfile
from unittest.mock import MagicMock

import pytest


def _mock_fencer_rows():
    return [
        {"txt_surname": "KOWALSKI", "txt_first_name": "Jan", "int_birth_year": 1970, "bool_birth_year_estimated": False},
        {"txt_surname": "NOWAK", "txt_first_name": "Piotr", "int_birth_year": 1982, "bool_birth_year_estimated": True},
    ]


def _mock_season_data():
    """Returns mock query function that simulates CERT data."""
    call_count = [0]

    def mock_query(sql):
        call_count[0] += 1
        sql_lower = sql.lower()

        if "tbl_fencer" in sql_lower and "select" in sql_lower and "txt_surname" in sql_lower and "int_birth_year" in sql_lower:
            return _mock_fencer_rows()

        if "tbl_event" in sql_lower and "id_season" in sql_lower:
            return [
                {"id_event": 10, "txt_code": "PPW1-2025-2026", "txt_name": "I Puchar Polski",
                 "txt_location": "Opole", "txt_country": "Polska",
                 "dt_start": "2025-09-27", "dt_end": "2025-09-28",
                 "url_event": None, "url_invitation": None,
                 "num_entry_fee": 250, "txt_entry_fee_currency": "PLN",
                 "enum_status": "COMPLETED"},
            ]

        if "tbl_tournament" in sql_lower and "id_event" in sql_lower:
            return [
                {"id_tournament": 100, "txt_code": "PPW1-V2-M-EPEE-2025-2026",
                 "txt_name": "I Puchar Polski", "enum_type": "PPW",
                 "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V2",
                 "dt_tournament": "2025-09-27", "int_participant_count": 3,
                 "url_results": None, "enum_import_status": "SCORED"},
            ]

        if "tbl_result" in sql_lower:
            return [
                {"int_place": 1, "txt_surname": "KOWALSKI", "txt_first_name": "Jan"},
                {"int_place": 2, "txt_surname": "NOWAK", "txt_first_name": "Piotr"},
            ]

        return []

    return mock_query


class TestExportSeed:
    """Tests 9.209–9.213: Full-season seed export."""

    def test_export_fencer_seed(self):
        """9.209 export_fencer_seed returns valid SQL with all fencers."""
        from python.pipeline.export_seed import export_fencer_seed

        sql = export_fencer_seed(query_fn=lambda sql: _mock_fencer_rows())
        assert "INSERT INTO tbl_fencer" in sql
        assert "KOWALSKI" in sql
        assert "NOWAK" in sql
        assert "1970" in sql

    def test_export_full_season(self):
        """9.210 export_full_season returns per-category SQL files."""
        from python.pipeline.export_seed import export_full_season

        files = export_full_season(
            season_code="SPWS-2025-2026",
            query_fn=_mock_season_data(),
        )
        assert len(files) > 0
        # Should have a v2_m_epee.sql key
        assert any("v2_m_epee" in k for k in files)

    def test_idempotent_event_inserts(self):
        """9.211 Generated SQL contains idempotent event INSERTs (WHERE NOT EXISTS)."""
        from python.pipeline.export_seed import export_full_season

        files = export_full_season(
            season_code="SPWS-2025-2026",
            query_fn=_mock_season_data(),
        )
        sql = list(files.values())[0]
        assert "WHERE NOT EXISTS" in sql

    def test_fencer_name_lookups(self):
        """9.212 Generated SQL uses fencer name lookups, not hardcoded IDs."""
        from python.pipeline.export_seed import export_full_season

        files = export_full_season(
            season_code="SPWS-2025-2026",
            query_fn=_mock_season_data(),
        )
        sql = list(files.values())[0]
        assert "SELECT id_fencer FROM tbl_fencer WHERE txt_surname" in sql
        # Should NOT have hardcoded integer fencer IDs in result INSERTs
        # (the pattern "VALUES (\n    123," would indicate hardcoded IDs)

    def test_write_seed_files_overwrites(self):
        """9.213 write_seed_files overwrites existing files (not append)."""
        from python.pipeline.export_seed import write_seed_files

        with tempfile.TemporaryDirectory() as tmpdir:
            # Write initial content
            filepath = os.path.join(tmpdir, "test.sql")
            with open(filepath, "w") as f:
                f.write("OLD CONTENT\n")

            # Overwrite via write_seed_files
            write_seed_files({"test.sql": "NEW CONTENT\n"}, tmpdir)

            with open(filepath) as f:
                content = f.read()

            assert content == "NEW CONTENT\n"
            assert "OLD CONTENT" not in content
