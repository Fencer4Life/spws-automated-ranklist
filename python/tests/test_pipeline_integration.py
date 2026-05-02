"""
Phase 3 (ADR-050) end-to-end integration test.

Exercises the full Phase 3 stack against a live LOCAL Supabase instance:
  parsed IR → run_pipeline → DraftStore → 3-way diff → discard

Skips gracefully if local Supabase isn't reachable (same pattern as
test_ir.py:test_source_kind_matches_postgres_enum after the CI fix).

Plan IDs P3.INT.1 - P3.INT.4.
"""

from __future__ import annotations

import os
import subprocess
import uuid
from datetime import date

import pytest


def _local_supabase_reachable() -> bool:
    """True if the local Supabase container is up + reachable from this process."""
    try:
        result = subprocess.run(
            ["docker", "exec", "supabase_db_SPWSranklist",
             "psql", "-U", "postgres", "-c", "SELECT 1"],
            capture_output=True, text=True, timeout=5,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


pytestmark = pytest.mark.skipif(
    not _local_supabase_reachable(),
    reason="Local Supabase container not reachable (expected in CI's test-python job)."
)


@pytest.fixture(scope="module")
def db():
    """Real DbConnector against local Supabase. Skips at module level if env vars missing."""
    if not os.environ.get("SUPABASE_URL") or not os.environ.get("SUPABASE_KEY"):
        pytest.skip("SUPABASE_URL / SUPABASE_KEY not set; cannot connect.")
    from python.pipeline.db_connector import create_db_connector
    return create_db_connector()


@pytest.fixture
def fresh_run_id():
    """A unique run_id so successive integration runs don't collide."""
    return str(uuid.uuid4())


def _parsed_for_active_event(active_event_date, weapon="EPEE", gender="M"):
    """Build a synthetic ParsedTournament for a known active-season event date."""
    from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
    return ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=[
            ParsedResult(source_row_id="int:1", fencer_name="KOWALSKI Jan",
                         place=1, birth_year=1970, fencer_country="POL"),
            ParsedResult(source_row_id="int:2", fencer_name="NOWAK Adam",
                         place=2, birth_year=1968, fencer_country="POL"),
            ParsedResult(source_row_id="int:3", fencer_name="WISNIEWSKI Pawel",
                         place=3, birth_year=1975, fencer_country="POL"),
        ],
        parsed_date=active_event_date,
        weapon=weapon,
        gender=gender,
        organizer_hint="SPWS",
        season_end_year=2026,
        source_url="https://integration.test/results",
        category_hint="V1",
    )


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestEndToEnd:
    def test_run_pipeline_resolves_event_for_active_season_date(self, db):
        """P3.INT.1 run_pipeline against real DB resolves the event for a known date."""
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import Overrides

        # PPW1-2025-2026 is at 2025-09-27 (active-season fixture); see seed.
        parsed = _parsed_for_active_event(date(2025, 9, 27))

        ctx = run_pipeline(parsed=parsed, overrides=Overrides(),
                           db=db, season_end_year=2026)

        # Stage S1 passed (results non-empty, all required fields).
        # Stage S2 resolved an event for 2025-09-27.
        assert ctx.event is not None, (
            "S2 should resolve an event for date 2025-09-27 in active season; "
            f"halt={ctx.halt_detail!r}"
        )
        assert ctx.event["txt_code"].startswith("PPW1") or "PPW1" in ctx.event["txt_code"]

    def test_run_pipeline_completes_through_s7(self, db):
        """P3.INT.2 full S1-S7 chain runs to completion (no halt) on synthetic input."""
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import Overrides

        parsed = _parsed_for_active_event(date(2025, 9, 27))
        ctx = run_pipeline(parsed=parsed, overrides=Overrides(),
                           db=db, season_end_year=2026)

        assert not ctx.halted, (
            f"Expected full S1-S7 completion; halted at "
            f"{ctx.halted_at_stage} ({ctx.halt_reason}): {ctx.halt_detail}"
        )
        # S6 produced one match per input row
        assert len(ctx.matches) == 3
        # S7 recorded count validation
        assert ctx.count_validation is not None

    def test_draftstore_write_read_discard_round_trip(self, db, fresh_run_id):
        """P3.INT.3 DraftStore write + read_drafts + discard round-trip works end-to-end."""
        from python.pipeline.draft_store import DraftStore

        store = DraftStore(db)

        # Write one minimal tournament draft + one result draft.
        # Use the active PPW1 event id discovered via find_event_by_date.
        event = db.find_event_by_date("2025-09-27")
        assert event is not None, "test fixture assumes PPW1-2025-2026 in active season"

        store.write_tournament_drafts(
            tournaments=[{
                "id_event": event["id_event"],
                "txt_code": f"INT-{fresh_run_id[:8]}-V1-EPEE-M",
                "enum_type": "PPW",
                "enum_weapon": "EPEE",
                "enum_gender": "M",
                "enum_age_category": "V1",
                "dt_tournament": "2025-09-27",
                "url_results": "https://integration.test/x",
                "enum_parser_kind": "FENCINGTIME_XML",
            }],
            run_id=fresh_run_id,
        )
        store.write_result_drafts(
            results=[{
                "id_fencer": None,
                "id_tournament_draft": 0,  # placeholder; commit-path fills it
                "int_place": 1,
                "txt_scraped_name": "INTEGRATION TEST",
            }],
            run_id=fresh_run_id,
        )

        # Read back
        tournaments, results = store.read_drafts(fresh_run_id)
        assert len(tournaments) == 1
        assert len(results) == 1
        assert tournaments[0]["txt_run_id"] == fresh_run_id

        # Clean up via discard
        result = store.discard(fresh_run_id)
        assert result["tournaments_discarded"] == 1
        assert result["results_discarded"] == 1

        # Read after discard → empty
        tournaments_after, results_after = store.read_drafts(fresh_run_id)
        assert tournaments_after == []
        assert results_after == []

    def test_three_way_diff_renders_for_pipeline_output(self, db, tmp_path):
        """P3.INT.4 3-way diff renders markdown from a real PipelineContext."""
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.three_way_diff import (
            build_diff, confidence_histogram, render_markdown, write_diff,
        )
        from python.pipeline.types import Overrides

        parsed = _parsed_for_active_event(date(2025, 9, 27))
        ctx = run_pipeline(parsed=parsed, overrides=Overrides(),
                           db=db, season_end_year=2026)

        assert not ctx.halted, f"setup halt: {ctx.halt_detail}"

        source_rows = [
            {"fencer_name": r.fencer_name, "place": r.place, "id_fencer": None}
            for r in parsed.results
        ]
        new_rows = [
            {"fencer_name": m.scraped_name, "place": m.place, "id_fencer": m.id_fencer}
            for m in ctx.matches
        ]
        diff_rows = build_diff(source_rows, [], new_rows)
        hist = confidence_histogram(ctx.matches)
        md = render_markdown("INT-TEST", diff_rows, hist)
        path = write_diff("INT-TEST", md, staging_dir=tmp_path)

        assert path.exists()
        content = path.read_text()
        assert "INT-TEST" in content
        assert "Bucket summary" in content
        assert "Match confidence distribution" in content
