"""
Test that local DB is a faithful mirror of PROD.

Compares row counts for all data tables between PROD (via Management API)
and local DB (via docker exec). Fails if any table has a count mismatch.

Skipped in CI (requires SUPABASE_ACCESS_TOKEN).
Run locally: python -m pytest python/tests/test_prod_mirror.py -v
"""

import os
import subprocess

import pytest

# Skip entire module if no access token (CI environment)
pytestmark = pytest.mark.skipif(
    not os.environ.get("SUPABASE_ACCESS_TOKEN"),
    reason="SUPABASE_ACCESS_TOKEN not set (skipped in CI)"
)

from python.tools.audit_results import query_db

PROD_REF = "ywgymtgcyturldazcpmw"

TABLES = [
    "tbl_fencer",
    "tbl_season",
    "tbl_organizer",
    "tbl_scoring_config",
    "tbl_event",
    "tbl_tournament",
    "tbl_result",
]


def _local_count(table: str) -> int:
    """Query local DB count via docker exec."""
    result = subprocess.run(
        ["docker", "exec", "supabase_db_SPWSranklist",
         "psql", "-U", "postgres", "-t", "-A", "-c",
         f"SELECT COUNT(*) FROM {table}"],
        capture_output=True, text=True, timeout=10,
    )
    return int(result.stdout.strip())


def _prod_count(table: str) -> int:
    """Query PROD count via Management API."""
    rows = query_db(PROD_REF, f"SELECT COUNT(*) FROM {table}")
    return int(rows[0][0])


@pytest.fixture(scope="module")
def prod_counts() -> dict[str, int]:
    """Fetch all PROD counts once per test session."""
    return {table: _prod_count(table) for table in TABLES}


@pytest.mark.parametrize("table", TABLES)
def test_table_count_matches_prod(table: str, prod_counts: dict[str, int]):
    """Local DB row count must match PROD for {table}."""
    local = _local_count(table)
    prod = prod_counts[table]
    assert local == prod, (
        f"{table}: local={local}, PROD={prod} (diff={local - prod:+d})"
    )
