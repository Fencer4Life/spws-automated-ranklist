"""
T8.3: Multi-Category Seed Data — pytest tests for generate_season_seed.py.
Tests 8.25–8.26 from doc/m8_implementation_plan.md §T8.3.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).parent.parent / "tools" / "generate_season_seed.py"
EPEE_M_V1_XLSX = (
    Path(__file__).parent.parent.parent
    / "doc/external_files/Sezon 2024 - 2025/Szpada 2024-2025"
    / "Ranking Mezczyzn - szpada/SZPADA-1-2024-2025.xlsx"
)


# 8.25 — generate_season_seed.py exits 0 for a valid combination
def test_generator_exits_zero():
    """8.25: generate_season_seed.py exits 0 for a valid combination."""
    with tempfile.TemporaryDirectory() as tmpdir:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--xlsx", str(EPEE_M_V1_XLSX),
                "--season", "SPWS-2024-2025",
                "--weapon", "EPEE",
                "--gender", "M",
                "--age-cat", "V1",
            ],
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        assert result.returncode == 0, f"Script failed:\n{result.stderr}"


# 8.26 — generate_season_seed.py produces valid SQL (no syntax errors)
def test_generator_produces_valid_sql():
    """8.26: generate_season_seed.py produces valid SQL."""
    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--xlsx", str(EPEE_M_V1_XLSX),
                "--season", "SPWS-2024-2025",
                "--weapon", "EPEE",
                "--gender", "M",
                "--age-cat", "V1",
            ],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            check=True,
        )
        # The script writes to supabase/data/2024_25/v1_m_epee.sql relative to cwd
        out_file = Path(tmpdir) / "supabase" / "data" / "2024_25" / "v1_m_epee.sql"
        assert out_file.exists(), f"Expected output file not found: {out_file}"
        sql = out_file.read_text(encoding="utf-8")
        # Basic SQL validity checks
        assert "INSERT INTO tbl_event" in sql, "Missing tbl_event INSERT"
        assert "INSERT INTO tbl_tournament" in sql, "Missing tbl_tournament INSERT"
        assert "INSERT INTO tbl_result" in sql, "Missing tbl_result INSERT"
        assert "fn_calc_tournament_scores" in sql, "Missing scoring function call"
        # No Python tracebacks or error markers
        assert "Traceback" not in sql, "SQL contains Python traceback"
        assert "ERROR" not in sql, "SQL contains ERROR marker"
