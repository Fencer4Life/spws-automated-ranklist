"""
T8.3: Multi-Category Seed Data — pytest tests for generate_season_seed.py.
Tests 8.25–8.26 from doc/archive/m8_implementation_plan.md §T8.3.
Tests 9.142–9.148 from ADR-020: domestic auto-create for unmatched fencers.
"""

import socket
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent.parent / "tools" / "generate_season_seed.py"

# Import seed generator functions for unit tests (9.142–9.148)
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from python.tools.generate_season_seed import (
    fuzzy_match,
    normalize_name,
    sq,
    MATCH_THRESHOLD,
)

EPEE_M_V1_XLSX = (
    Path(__file__).parent.parent.parent
    / "doc/external_files/Sezon 2024 - 2025/Szpada 2024-2025"
    / "Ranking Mezczyzn - szpada/SZPADA-1-2024-2025.xlsx"
)


def _local_db_reachable() -> bool:
    """Check if local Supabase PostgreSQL is listening on port 54322."""
    try:
        with socket.create_connection(("127.0.0.1", 54322), timeout=1):
            return True
    except OSError:
        return False


skip_no_db = pytest.mark.skipif(
    not _local_db_reachable(),
    reason="Local Supabase DB not running (port 54322)",
)


# 8.25 — generate_season_seed.py exits 0 for a valid combination
@skip_no_db
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
@skip_no_db
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


# =========================================================================
# 9.142–9.148: ADR-020 — Domestic auto-create for unmatched fencers
# =========================================================================
# Unit tests — no DB required.  They test functions in generate_season_seed.py
# that handle domestic vs international unmatched fencers differently.
# =========================================================================

# Fake fencer list for unit tests (matches seed_tbl_fencer format)
_FENCERS = [
    (183, "ODOLAK", "Jarosław", []),
    (6,   "ATANASSOW", "Aleksander", []),
    (46,  "DUDEK", "Mariusz", []),
]


# 9.142 — fuzzy_match regression: ODOLAK Jarosław matches existing fencer
def test_fuzzy_match_odolak_matches():
    """9.142: ODOLAK Jarosław must match existing fencer at score ≥70."""
    result = fuzzy_match("ODOLAK Jarosław", _FENCERS)
    assert result is not None, "ODOLAK Jarosław should match existing fencer"
    fid, name, score = result
    assert fid == 183, f"Expected fencer id 183, got {fid}"
    assert score >= MATCH_THRESHOLD, f"Score {score} below threshold {MATCH_THRESHOLD}"


# 9.143 — parse_season_end_year helper
def test_parse_season_end_year():
    """9.143: parse_season_end_year extracts end year from season code."""
    from python.tools.generate_season_seed import parse_season_end_year
    assert parse_season_end_year("SPWS-2025-2026") == 2026
    assert parse_season_end_year("SPWS-2024-2025") == 2025


# 9.144 — Domestic PPW unmatched → auto-create SQL (fencer INSERT + result INSERT)
def test_domestic_unmatched_generates_auto_create_sql():
    """9.144: Domestic PPW unmatched fencer produces INSERT INTO tbl_fencer + tbl_result."""
    from python.tools.generate_season_seed import generate_auto_create_sql, build_result_sql_for_unmatched
    fencer_sql = generate_auto_create_sql("LEAHEY John", "V2", 2026)
    assert "INSERT INTO tbl_fencer" in fencer_sql
    assert "'LEAHEY'" in fencer_sql
    assert "'John'" in fencer_sql

    result_sql = build_result_sql_for_unmatched(
        "LEAHEY John", 4, "PPW", "PPW3-V2-M-EPEE-2025-2026"
    )
    assert "INSERT INTO tbl_result" in result_sql
    assert "SELECT id_fencer FROM tbl_fencer" in result_sql


# 9.145 — International PEW unmatched → SKIPPED comment, no INSERT
def test_international_unmatched_generates_skip_comment():
    """9.145: International PEW unmatched fencer produces SKIPPED comment, not INSERT."""
    from python.tools.generate_season_seed import build_result_sql_for_unmatched
    result_sql = build_result_sql_for_unmatched(
        "SCHMIDT Hans", 7, "PEW", "PEW1-V2-M-EPEE-2025-2026"
    )
    assert "-- SKIPPED" in result_sql
    assert "international" in result_sql.lower()
    assert "INSERT INTO tbl_result" not in result_sql


# 9.146 — Auto-created fencer INSERT uses WHERE NOT EXISTS (idempotent)
def test_auto_create_sql_is_idempotent():
    """9.146: Auto-create fencer INSERT uses WHERE NOT EXISTS to prevent duplicates."""
    from python.tools.generate_season_seed import generate_auto_create_sql
    sql = generate_auto_create_sql("GOLD Oleg", "V2", 2026)
    assert "WHERE NOT EXISTS" in sql


# 9.147 — Same fencer unmatched in PPW1 + PPW3 → only 1 fencer INSERT
def test_auto_create_deduplication():
    """9.147: Same fencer appearing in multiple domestic tournaments gets only 1 fencer INSERT."""
    from python.tools.generate_season_seed import generate_auto_create_sql
    auto_created = set()
    sql1 = generate_auto_create_sql("LEAHEY John", "V2", 2026, auto_created)
    sql2 = generate_auto_create_sql("LEAHEY John", "V2", 2026, auto_created)
    assert "INSERT INTO tbl_fencer" in sql1
    # Second call for same fencer should return empty (already tracked)
    assert sql2 == "" or sql2 is None


# 9.148 — Auto-created fencer has estimated birth year + bool_birth_year_estimated = TRUE
def test_auto_create_has_estimated_birth_year():
    """9.148: Auto-created fencer SQL includes estimated birth year and bool_birth_year_estimated = TRUE."""
    from python.tools.generate_season_seed import generate_auto_create_sql
    sql = generate_auto_create_sql("MCQUEEN Andy", "V2", 2026)
    # V2 in season ending 2026 → estimated birth year = 2026 - 50 = 1976
    assert "1976" in sql
    assert "bool_birth_year_estimated" in sql
    assert "TRUE" in sql
