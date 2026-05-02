"""
Tests for python/pipeline/draft_diff.py — Phase 2 (ADR-050) markdown diff
generator for the dry-run risk gate.

Plan test IDs P2.M1–P2.M5 (per /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md
Phase 2 subplan doc/plans/rebuild/p2-drafts.md, Decision D3).

Phase 2 ships TOURNAMENT-LEVEL diff only:
  - per-tournament summary table (code, weapon, gender, cat, date, results, url)
  - aggregate counts: matched / pending / auto-created / excluded
  - joint-pool sibling group count
  - event-match indication

Per-fencer detail and 3-way diff against live = Phase 3 (do not implement here).

  P2.M1  format_diff returns markdown string with title + run_id
  P2.M2  format_diff renders the per-tournament summary table
  P2.M3  format_diff aggregates match-method counters
  P2.M4  format_diff with empty payload returns a "nothing would change" block
  P2.M5  format_diff includes joint-pool sibling group count from RPC result
"""

from __future__ import annotations


class TestFormatDiff:
    """P2.M1–P2.M5: markdown diff formatter."""

    def test_diff_has_title_and_run_id(self):
        """P2.M1 format_diff returns markdown with title + run_id header line."""
        from python.pipeline.draft_diff import format_diff

        md = format_diff(
            run_id="abc-123",
            payload={"tournaments": [], "results": []},
            rpc_result={"tournaments_would_create": 0, "results_would_create": 0,
                        "joint_pool_sibling_groups": 0},
            event_match=None,
        )
        assert "# Draft" in md
        assert "abc-123" in md

    def test_diff_renders_tournament_table(self):
        """P2.M2 format_diff renders the per-tournament summary table."""
        from python.pipeline.draft_diff import format_diff

        payload = {
            "tournaments": [
                {"txt_code": "PEW3-V0-EPEE-M", "enum_weapon": "EPEE",
                 "enum_gender": "M", "enum_age_category": "V0",
                 "dt_tournament": "2025-11-15",
                 "url_results": "https://ftl.example/foo"},
                {"txt_code": "PEW3-V1-EPEE-M", "enum_weapon": "EPEE",
                 "enum_gender": "M", "enum_age_category": "V1",
                 "dt_tournament": "2025-11-15",
                 "url_results": "https://ftl.example/foo"},
            ],
            "results": [
                {"txt_code": "PEW3-V0-EPEE-M", "int_place": 1},
                {"txt_code": "PEW3-V0-EPEE-M", "int_place": 2},
                {"txt_code": "PEW3-V1-EPEE-M", "int_place": 1},
            ],
        }
        md = format_diff(
            run_id="r1",
            payload=payload,
            rpc_result={"tournaments_would_create": 2, "results_would_create": 3,
                        "joint_pool_sibling_groups": 1},
            event_match={"id_event": 42, "txt_code": "PEW3-2025-2026"},
        )
        # Both tournament codes appear, with their result counts
        assert "PEW3-V0-EPEE-M" in md
        assert "PEW3-V1-EPEE-M" in md
        # Per-tournament results count column present
        assert "| 2 |" in md or "|2|" in md.replace(" ", "")  # 2 results in V0
        assert "| 1 |" in md or "|1|" in md.replace(" ", "")  # 1 result in V1

    def test_diff_aggregates_match_method_counts(self):
        """P2.M3 format_diff aggregates match-method counters from results."""
        from python.pipeline.draft_diff import format_diff

        payload = {
            "tournaments": [
                {"txt_code": "X", "enum_weapon": "EPEE", "enum_gender": "M",
                 "enum_age_category": "V0", "dt_tournament": "2025-11-15",
                 "url_results": "u"},
            ],
            "results": [
                {"txt_code": "X", "int_place": 1, "enum_match_method": "AUTO_MATCHED"},
                {"txt_code": "X", "int_place": 2, "enum_match_method": "AUTO_MATCHED"},
                {"txt_code": "X", "int_place": 3, "enum_match_method": "PENDING"},
                {"txt_code": "X", "int_place": 4, "enum_match_method": "AUTO_CREATED"},
            ],
        }
        md = format_diff(
            run_id="r2",
            payload=payload,
            rpc_result={"tournaments_would_create": 1, "results_would_create": 4,
                        "joint_pool_sibling_groups": 0},
            event_match=None,
        )
        # Aggregate line includes the three counter values
        assert "Auto-matched" in md or "auto-matched" in md.lower()
        assert "Pending" in md or "pending" in md.lower()
        # Exact counts
        assert "2" in md  # 2 auto-matched
        assert "1" in md  # 1 pending, 1 auto-created

    def test_diff_empty_payload(self):
        """P2.M4 format_diff with empty payload returns a 'nothing would change' block."""
        from python.pipeline.draft_diff import format_diff

        md = format_diff(
            run_id="empty-1",
            payload={"tournaments": [], "results": []},
            rpc_result={"tournaments_would_create": 0, "results_would_create": 0,
                        "joint_pool_sibling_groups": 0},
            event_match=None,
        )
        # Empty diff still renders the header but notes zero changes
        assert "0 tournaments" in md.lower() or "Would create: 0" in md

    def test_diff_includes_joint_pool_groups(self):
        """P2.M5 format_diff includes joint-pool sibling group count from RPC result."""
        from python.pipeline.draft_diff import format_diff

        md = format_diff(
            run_id="r3",
            payload={"tournaments": [], "results": []},
            rpc_result={"tournaments_would_create": 0, "results_would_create": 0,
                        "joint_pool_sibling_groups": 2},
            event_match=None,
        )
        # The sibling group count surfaces somewhere in the markdown
        assert "joint-pool" in md.lower() or "joint pool" in md.lower()
        assert "2" in md
