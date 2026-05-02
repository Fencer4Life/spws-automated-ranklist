"""
Tests for python/pipeline/ir.py — the unified ingestion intermediate representation.

Phase 1 / part 2 of the rebuild (ADR-050 + ADR-055).

Plan test IDs:
  ir.1   SourceKind has 8 declared source kinds
  ir.2   SourceKind values match Postgres enum_parser_kind exactly (cross-language sync)
  ir.3   ParsedTournament has the contract fields
  ir.4   ParsedResult has the contract fields
  ir.5   ParsedTournament can be constructed with only the required fields
  ir.6   make_synthetic_id is deterministic
  ir.7   make_synthetic_id distinguishes ties and folds non-ASCII names
"""

from __future__ import annotations

import subprocess
from dataclasses import fields

import pytest


def _local_pg_enum_values(enum_name: str) -> list[str]:
    """Read enum values from the local Postgres via docker exec, in declared order.

    Returns [] if the local Supabase container isn't reachable (CI's
    test-python job has no docker / no Supabase — only test-pgtap does).
    Caller is expected to pytest.skip() in that case.
    """
    try:
        result = subprocess.run(
            [
                "docker", "exec", "supabase_db_SPWSranklist",
                "psql", "-U", "postgres", "-t", "-A", "-c",
                (
                    "SELECT enumlabel FROM pg_enum "
                    f"WHERE enumtypid = '{enum_name}'::regtype "
                    "ORDER BY enumsortorder"
                ),
            ],
            capture_output=True, text=True, timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    if result.returncode != 0:
        return []
    return [v for v in result.stdout.strip().split("\n") if v]


def test_source_kind_has_eight_values():
    """ir.1: SourceKind enum has 8 declared source kinds."""
    from python.pipeline.ir import SourceKind
    assert len(list(SourceKind)) == 8


def test_source_kind_matches_postgres_enum():
    """ir.2: Python SourceKind values exactly match Postgres enum_parser_kind in declared order.

    Cross-language invariant. If this fails, either python/pipeline/ir.py
    or supabase/migrations/20260501000003_phase1_ingest_traceability.sql is
    out of sync with the other.

    Skipped in CI's test-python job (no docker / no Supabase). The pgTAP
    side verifies enum_parser_kind separately (test 26.2), so cross-language
    drift would still be caught: py-side existence in this test (when run
    locally) + db-side existence in pgTAP.
    """
    from python.pipeline.ir import SourceKind
    db_values = _local_pg_enum_values("enum_parser_kind")
    if not db_values:
        pytest.skip("Local Supabase container not reachable (expected in CI test-python job).")
    py_values = [e.value for e in SourceKind]
    assert py_values == db_values, f"DRIFT: py={py_values} db={db_values}"


def test_parsed_tournament_fields():
    """ir.3: ParsedTournament has the contract fields with correct names."""
    from python.pipeline.ir import ParsedTournament
    actual = {f.name for f in fields(ParsedTournament)}
    expected = {
        # Parser-required:
        "source_kind",
        "results",
        # Parser-optional (extractable from source if available):
        "raw_pool_size",
        "parsed_date",
        "weapon",
        "gender",
        "category_hint",
        "source_url",
        # Orchestrator-injected:
        "season_end_year",
        "organizer_hint",
        "source_artifact_path",
    }
    assert actual == expected, f"diff (actual ^ expected): {actual ^ expected}"


def test_parsed_result_fields():
    """ir.4: ParsedResult has the contract fields with correct names."""
    from python.pipeline.ir import ParsedResult
    actual = {f.name for f in fields(ParsedResult)}
    expected = {
        # Required:
        "source_row_id",
        "fencer_name",
        "place",
        # Optional:
        "fencer_country",
        "birth_year",
        "birth_date",
        "raw_age_marker",
        "source_vcat_hint",
        "bool_excluded",
    }
    assert actual == expected, f"diff (actual ^ expected): {actual ^ expected}"


def test_parsed_tournament_constructible_minimal():
    """ir.5: ParsedTournament constructs with only source_kind (results defaults to [])."""
    from python.pipeline.ir import ParsedTournament, SourceKind
    pt = ParsedTournament(source_kind=SourceKind.FTL)
    assert pt.results == []
    assert pt.parsed_date is None
    assert pt.weapon is None
    assert pt.gender is None
    assert pt.category_hint is None
    assert pt.season_end_year is None


def test_synthetic_row_id_deterministic():
    """ir.6: make_synthetic_id with same inputs returns the same output."""
    from python.pipeline.ir import make_synthetic_id, SourceKind
    a = make_synthetic_id(SourceKind.FTL, row_index=1, place=3, name="ATANASSOW Aleksander")
    b = make_synthetic_id(SourceKind.FTL, row_index=1, place=3, name="ATANASSOW Aleksander")
    assert a == b, "deterministic: same inputs must yield same ID"
    assert a.startswith("ftl:"), f"format: source prefix expected, got {a!r}"
    assert "row1" in a
    assert "place3" in a


def test_synthetic_row_id_handles_edge_cases():
    """ir.7: make_synthetic_id distinguishes ties and folds non-ASCII names to ASCII."""
    from python.pipeline.ir import make_synthetic_id, SourceKind

    # Two fencers tied at place 3 — different row_index → different IDs.
    tie_a = make_synthetic_id(SourceKind.ENGARDE, row_index=3, place=3, name="HAYAT Konstantin")
    tie_b = make_synthetic_id(SourceKind.ENGARDE, row_index=4, place=3, name="GEORGES Henry")
    assert tie_a != tie_b

    # Polish chars must be folded to ASCII.
    polish = make_synthetic_id(SourceKind.FTL, row_index=1, place=1, name="KAMIŃSKA Gabriela")
    assert polish.isascii(), f"non-ASCII leaked into synthetic id: {polish!r}"
    assert "KAMINSKA" in polish, f"Polish-fold expected in {polish!r}"
