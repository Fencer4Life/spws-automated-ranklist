"""
Tests for result importer (reads ODS Tournaments tab, generates SQL).

Plan test IDs 9.129–9.141:
  9.129  read_tournaments_from_ods returns 5 rows from mock ODS
  9.130  Season filter returns only matching rows
  9.131  TournamentSpec has all required fields
  9.132  extract_results from XML source → correct result list
  9.133  extract_results from XLSX source → correct result list
  9.134  extract_results skips LOST → returns None
  9.135  extract_results skips EMPTY → returns None
  9.136  generate_tournament_sql has INSERT + fn_calc_tournament_scores
  9.137  generate_tournament_sql: each result row has fencer subquery
  9.138  generate_tournament_sql: tournament identified by txt_code
  9.139  write_category_sql creates correct output file path
  9.140  --dry-run prints summary but writes nothing
  9.141  CLI exits 0 on success with --dry-run
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "tools" / "import_results.py"
STAGING_SCRIPT = Path(__file__).resolve().parent.parent / "tools" / "staging_spreadsheet.py"
XML_FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"


@pytest.fixture(scope="module")
def mock_ods_path(tmp_path_factory):
    """Generate mock ODS once for all tests in this module."""
    tmpdir = tmp_path_factory.mktemp("import_results")
    out_path = tmpdir / "staging_data_mock.ods"
    result = subprocess.run(
        [sys.executable, str(STAGING_SCRIPT), "mock", "--output", str(out_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Mock generation failed:\n{result.stderr}"
    return out_path


class TestReadTournaments:
    def test_read_tournaments_from_ods(self, mock_ods_path):
        """9.129 Reads 5 tournament rows from mock ODS."""
        from tools.import_results import read_tournaments_from_ods

        specs = read_tournaments_from_ods(mock_ods_path)
        assert len(specs) == 5

    def test_read_tournaments_season_filter(self, mock_ods_path):
        """9.130 Season filter returns only matching rows."""
        from tools.import_results import read_tournaments_from_ods

        specs = read_tournaments_from_ods(
            mock_ods_path, season_filter="SPWS-2024-2025"
        )
        assert len(specs) == 4  # 4 of 5 mock tournaments are 2024-2025
        assert all(s.season_code == "SPWS-2024-2025" for s in specs)

    def test_tournament_spec_fields(self, mock_ods_path):
        """9.131 TournamentSpec has all required fields."""
        from tools.import_results import read_tournaments_from_ods

        specs = read_tournaments_from_ods(mock_ods_path)
        spec = specs[0]
        # Check all fields exist
        assert hasattr(spec, "tournament_code")
        assert hasattr(spec, "event_code")
        assert hasattr(spec, "event_prefix")
        assert hasattr(spec, "season_code")
        assert hasattr(spec, "weapon")
        assert hasattr(spec, "gender")
        assert hasattr(spec, "age_cat")
        assert hasattr(spec, "tournament_type")
        assert hasattr(spec, "source_file")
        assert hasattr(spec, "result_url")
        assert hasattr(spec, "import_status")


class TestExtractResults:
    def test_extract_results_from_xml(self, mock_ods_path):
        """9.132 XML source → correct result list."""
        from tools.import_results import TournamentSpec, extract_results

        spec = TournamentSpec(
            tournament_code="PP4-V2-M-EPEE-SPWS-2025-2026",
            event_code="PP4-SPWS-2025-2026",
            event_prefix="PP4",
            season_code="SPWS-2025-2026",
            weapon="EPEE",
            gender="M",
            age_cat="V2",
            tournament_type="PPW",
            source_file="single_category.xml",
            result_url="",
            import_status="SCORED",
        )
        results = extract_results(spec, base_dir=XML_FIXTURES)
        assert results is not None
        assert len(results) == 5
        assert all("fencer_name" in r for r in results)

    def test_extract_results_from_xlsx(self, tmp_path):
        """9.133 Excel source → correct result list."""
        from tools.import_results import TournamentSpec, extract_results

        # Create a minimal XLSX fixture
        import openpyxl

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(["Place", "Name", "Country"])
        ws.append([1, "NOWAK Piotr", "POL"])
        ws.append([2, "KOWALSKI Jan", "POL"])
        xlsx_path = tmp_path / "test.xlsx"
        wb.save(str(xlsx_path))

        spec = TournamentSpec(
            tournament_code="PP1-V2-M-EPEE-SPWS-2024-2025",
            event_code="PP1-SPWS-2024-2025",
            event_prefix="PP1",
            season_code="SPWS-2024-2025",
            weapon="EPEE",
            gender="M",
            age_cat="V2",
            tournament_type="PPW",
            source_file="test.xlsx",
            result_url="",
            import_status="SCORED",
        )
        results = extract_results(spec, base_dir=tmp_path)
        assert results is not None
        assert len(results) == 2

    def test_extract_skips_lost(self):
        """9.134 import_status=LOST → returns None."""
        from tools.import_results import TournamentSpec, extract_results

        spec = TournamentSpec(
            tournament_code="PP3-V2-M-EPEE-SPWS-2025-2026",
            event_code="PP3-SPWS-2025-2026",
            event_prefix="PP3",
            season_code="SPWS-2025-2026",
            weapon="EPEE",
            gender="M",
            age_cat="V2",
            tournament_type="PPW",
            source_file="",
            result_url="",
            import_status="LOST",
        )
        results = extract_results(spec, base_dir=Path("/nonexistent"))
        assert results is None

    def test_extract_skips_empty(self):
        """9.135 import_status=EMPTY → returns None."""
        from tools.import_results import TournamentSpec, extract_results

        spec = TournamentSpec(
            tournament_code="PP3-V4-F-FOIL-SPWS-2025-2026",
            event_code="PP3-SPWS-2025-2026",
            event_prefix="PP3",
            season_code="SPWS-2025-2026",
            weapon="FOIL",
            gender="F",
            age_cat="V4",
            tournament_type="PPW",
            source_file="",
            result_url="",
            import_status="EMPTY",
        )
        results = extract_results(spec, base_dir=Path("/nonexistent"))
        assert results is None


class TestGenerateSQL:
    def test_generate_sql_basic(self):
        """9.136 SQL has INSERT INTO tbl_result + fn_calc_tournament_scores."""
        from tools.import_results import TournamentSpec, generate_tournament_sql

        spec = TournamentSpec(
            tournament_code="PP1-V2-M-EPEE-SPWS-2024-2025",
            event_code="PP1-SPWS-2024-2025",
            event_prefix="PP1",
            season_code="SPWS-2024-2025",
            weapon="EPEE",
            gender="M",
            age_cat="V2",
            tournament_type="PPW",
            source_file="test.xlsx",
            result_url="",
            import_status="SCORED",
        )
        results = [
            {"fencer_name": "NOWAK Piotr", "place": 1, "country": "POL"},
            {"fencer_name": "KOWALSKI Jan", "place": 2, "country": "POL"},
        ]
        sql = generate_tournament_sql(spec, results)
        assert "INSERT INTO tbl_result" in sql
        assert "fn_calc_tournament_scores" in sql

    def test_generate_sql_fencer_lookup(self):
        """9.137 Each result row has fencer subquery by surname + first_name."""
        from tools.import_results import TournamentSpec, generate_tournament_sql

        spec = TournamentSpec(
            tournament_code="PP1-V2-M-EPEE-SPWS-2024-2025",
            event_code="PP1-SPWS-2024-2025",
            event_prefix="PP1",
            season_code="SPWS-2024-2025",
            weapon="EPEE",
            gender="M",
            age_cat="V2",
            tournament_type="PPW",
            source_file="test.xlsx",
            result_url="",
            import_status="SCORED",
        )
        results = [
            {"fencer_name": "NOWAK Piotr", "place": 1, "country": "POL"},
        ]
        sql = generate_tournament_sql(spec, results)
        assert "txt_surname" in sql
        assert "NOWAK" in sql
        assert "Piotr" in sql

    def test_generate_sql_tournament_lookup(self):
        """9.138 Tournament identified by txt_code subquery."""
        from tools.import_results import TournamentSpec, generate_tournament_sql

        spec = TournamentSpec(
            tournament_code="PP1-V2-M-EPEE-SPWS-2024-2025",
            event_code="PP1-SPWS-2024-2025",
            event_prefix="PP1",
            season_code="SPWS-2024-2025",
            weapon="EPEE",
            gender="M",
            age_cat="V2",
            tournament_type="PPW",
            source_file="test.xlsx",
            result_url="",
            import_status="SCORED",
        )
        results = [
            {"fencer_name": "NOWAK Piotr", "place": 1, "country": "POL"},
        ]
        sql = generate_tournament_sql(spec, results)
        assert "txt_code" in sql
        assert "PP1-V2-M-EPEE-SPWS-2024-2025" in sql


class TestWriteSQL:
    def test_write_category_sql_file(self, tmp_path):
        """9.139 Creates correct output file path."""
        from tools.import_results import TournamentSpec, write_category_sql

        spec = TournamentSpec(
            tournament_code="PP1-V2-M-EPEE-SPWS-2024-2025",
            event_code="PP1-SPWS-2024-2025",
            event_prefix="PP1",
            season_code="SPWS-2024-2025",
            weapon="EPEE",
            gender="M",
            age_cat="V2",
            tournament_type="PPW",
            source_file="test.xlsx",
            result_url="",
            import_status="SCORED",
        )
        results = [
            {"fencer_name": "NOWAK Piotr", "place": 1, "country": "POL"},
        ]
        write_category_sql([(spec, results)], output_dir=tmp_path)
        # Expected path: {output_dir}/SPWS-2024-2025/EPEE_M_V2.sql
        expected = tmp_path / "SPWS-2024-2025" / "EPEE_M_V2.sql"
        assert expected.exists()
        content = expected.read_text()
        assert "INSERT INTO tbl_result" in content


class TestCLI:
    def test_dry_run_no_files(self, mock_ods_path, tmp_path):
        """9.140 --dry-run prints summary but writes nothing."""
        output_dir = tmp_path / "sql_output"
        result = subprocess.run(
            [
                sys.executable, str(SCRIPT),
                "--ods", str(mock_ods_path),
                "--dry-run",
                "--output-dir", str(output_dir),
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        # Output dir should not be created in dry-run
        assert not output_dir.exists() or len(list(output_dir.rglob("*.sql"))) == 0

    def test_cli_exit_code(self, mock_ods_path, tmp_path):
        """9.141 CLI exits 0 on success with --dry-run."""
        result = subprocess.run(
            [
                sys.executable, str(SCRIPT),
                "--ods", str(mock_ods_path),
                "--dry-run",
                "--output-dir", str(tmp_path / "out"),
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        # Should print some summary
        assert len(result.stdout) > 0
