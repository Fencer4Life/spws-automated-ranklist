"""Tests for joint-pool ingestion behaviour in scrape_tournament.py (ADR-049).

Tests 26.1-26.3: plan_joint_pool_actions() pure helper.
Test 26.4: full main() integration — joint pool with empty sibling triggers
DELETE, PATCH on remaining siblings, and POST p_participant_count =
len(parsed_rows).
"""

from __future__ import annotations

import json
import sys
from unittest.mock import MagicMock, patch

import pytest


# ===========================================================================
# 26.1 - 26.3 - plan_joint_pool_actions() pure helper
# ===========================================================================


class TestPlanJointPoolActions:
    """26.1-26.3: pure-logic helper that decides which siblings to DELETE
    (empty buckets in a joint pool) and which to flag with
    bool_joint_pool_split=TRUE."""

    def _siblings(self, *cats):
        # Synthesize sibling rows; id_tournament numbered by V-cat order.
        return [
            {
                "id_tournament": 1240 + i,
                "txt_code": f"PPW4-{c}-F-EPEE-2025-2026",
                "enum_age_category": c,
            }
            for i, c in enumerate(cats)
        ]

    def test_joint_all_buckets_nonempty(self):
        """26.1: joint pool, every sibling has fencers - flag every sibling,
        delete none."""
        from python.tools.scrape_tournament import plan_joint_pool_actions

        siblings = self._siblings("V0", "V1")
        buckets = {"V0": [{"place": 1}, {"place": 2}], "V1": [{"place": 3}]}

        plan = plan_joint_pool_actions(siblings, buckets)

        assert plan["is_joint"] is True
        assert plan["to_delete"] == []
        assert {s["enum_age_category"] for s in plan["to_flag"]} == {"V0", "V1"}

    def test_joint_with_empty_bucket(self):
        """26.2: joint pool with one empty sibling bucket - that sibling lands
        in to_delete; non-empty siblings land in to_flag."""
        from python.tools.scrape_tournament import plan_joint_pool_actions

        siblings = self._siblings("V0", "V1", "V2")
        buckets = {"V0": [{"place": 1}], "V1": [{"place": 2}], "V2": []}

        plan = plan_joint_pool_actions(siblings, buckets)

        assert plan["is_joint"] is True
        assert [s["enum_age_category"] for s in plan["to_delete"]] == ["V2"]
        assert {s["enum_age_category"] for s in plan["to_flag"]} == {"V0", "V1"}

    def test_solo_tournament(self):
        """26.3: only one sibling under (event, weapon, gender) - is_joint=False,
        no actions returned."""
        from python.tools.scrape_tournament import plan_joint_pool_actions

        siblings = self._siblings("V0")
        buckets = {"V0": [{"place": 1}, {"place": 2}]}

        plan = plan_joint_pool_actions(siblings, buckets)

        assert plan["is_joint"] is False
        assert plan["to_delete"] == []
        assert plan["to_flag"] == []


# ===========================================================================
# 26.4 - main() integration: joint pool with empty sibling
# ===========================================================================


def _resp(status=200, *, headers=None, json_body=None, text=""):
    r = MagicMock()
    r.status_code = status
    r.headers = headers or {}
    r.json.return_value = json_body if json_body is not None else []
    r.text = text
    r.raise_for_status = MagicMock()
    return r


class TestMainJointPoolIntegration:
    """26.4: end-to-end main() flow on a joint pool with one empty sibling.

    Asserts the new contract:
      - DELETE /rest/v1/tbl_tournament for the empty sibling
      - PATCH bool_joint_pool_split=TRUE on every non-empty sibling
      - POST fn_ingest_tournament_results with p_participant_count =
        len(parsed_rows) (full physical pool size, not per-V-cat slice)
    """

    def test_joint_pool_with_empty_sibling(self, monkeypatch):
        from python.tools import scrape_tournament as st

        # ----- Synthetic state -----
        anchor = {
            "id_tournament": 1240,
            "id_event": 17,
            "txt_code": "PPW4-V0-F-EPEE-2025-2026",
            "url_results": "https://www.fencingtimelive.com/events/results/JOINT26",
            "enum_weapon": "EPEE",
            "enum_gender": "F",
            "enum_age_category": "V0",
            "enum_type": "PPW",
        }
        siblings = [
            {**anchor},
            {"id_tournament": 1241, "txt_code": "PPW4-V1-F-EPEE-2025-2026",
             "enum_age_category": "V1", "enum_type": "PPW"},
            {"id_tournament": 1242, "txt_code": "PPW4-V2-F-EPEE-2025-2026",
             "enum_age_category": "V2", "enum_type": "PPW"},
        ]
        # 7 fencers in physical pool (will split 4/3/0 across V0/V1/V2)
        parsed_rows = [
            {"fencer_name": f"FENCER{i}", "place": i, "country": "POL"}
            for i in range(1, 8)
        ]

        # ----- Patch fetch_tournament_with_siblings -----
        monkeypatch.setattr(
            st, "fetch_tournament_with_siblings",
            lambda *a, **k: (anchor, siblings, 2026),
        )

        # ----- Patch scrape_and_parse to skip live fetch -----
        monkeypatch.setattr(st, "scrape_and_parse", lambda url: list(parsed_rows))

        # ----- Patch existing_result_counts: nothing occupied -----
        monkeypatch.setattr(
            st, "existing_result_counts",
            lambda *a, **k: {tid: 0 for tid in [1240, 1241, 1242]},
        )

        # ----- Patch DbConnector to return empty fencer_db -----
        fake_db = MagicMock()
        fake_db.fetch_fencer_db.return_value = []
        monkeypatch.setattr(
            "python.pipeline.db_connector.DbConnector",
            lambda *a, **k: fake_db,
        )

        # ----- Patch the splitter to a deterministic 4/3/0 partition -----
        def fake_split(rows, sib_cats, fencer_db, season_end_year):
            from python.pipeline.age_split import SplitResult
            return SplitResult(
                buckets={
                    "V0": rows[0:4],
                    "V1": rows[4:7],
                    "V2": [],
                },
                unresolved=[],
            )
        monkeypatch.setattr(
            "python.pipeline.age_split.split_combined_results", fake_split
        )

        # ----- Patch fuzzy match: every scraped row matches a fake fencer id -----
        def fake_resolve(scraped_names, *a, **kw):
            res = MagicMock()
            res.matched = [
                MagicMock(scraped_name=n, id_fencer=900 + i,
                          confidence=1.0, status="AUTO_MATCHED")
                for i, n in enumerate(scraped_names)
            ]
            return res
        monkeypatch.setattr(
            "python.matcher.pipeline.resolve_tournament_results", fake_resolve
        )

        # ----- Capture every httpx call -----
        recorded = {"posts": [], "patches": [], "deletes": []}

        def httpx_post(url, **kwargs):
            recorded["posts"].append({"url": url, **kwargs})
            return _resp(status=200, json_body={})

        def httpx_patch(url, **kwargs):
            recorded["patches"].append({"url": url, **kwargs})
            return _resp(status=204)

        def httpx_delete(url, **kwargs):
            recorded["deletes"].append({"url": url, **kwargs})
            return _resp(status=200, json_body=[])

        mock_httpx = MagicMock()
        mock_httpx.post.side_effect = httpx_post
        mock_httpx.patch.side_effect = httpx_patch
        mock_httpx.delete.side_effect = httpx_delete
        monkeypatch.setattr(st, "httpx", mock_httpx)

        # ----- Patch sys.argv and run main() -----
        monkeypatch.setattr(
            sys, "argv",
            ["scrape_tournament", "--tournament-code", "PPW4-V0-F-EPEE-2025-2026",
             "--supabase-url", "http://x", "--supabase-key", "k"],
        )
        st.main()

        # ----- Assert: empty sibling V2 deleted -----
        delete_urls = [d["url"] for d in recorded["deletes"]]
        assert any("id_tournament=eq.1242" in u for u in delete_urls), (
            f"V2 sibling (id 1242) should have been DELETEd. "
            f"Actual delete URLs: {delete_urls}"
        )
        # And no other tournament rows deleted
        for d in recorded["deletes"]:
            if "tbl_tournament" in d["url"]:
                assert "id_tournament=eq.1242" in d["url"]

        # ----- Assert: PATCH set bool_joint_pool_split=TRUE on V0 and V1 -----
        flag_patches = [
            p for p in recorded["patches"]
            if "tbl_tournament" in p["url"]
            and p.get("json", {}).get("bool_joint_pool_split") is True
        ]
        patched_ids = sorted(
            int(p["url"].split("id_tournament=eq.")[1].split("&")[0])
            for p in flag_patches
        )
        assert patched_ids == [1240, 1241], (
            f"Expected PATCH bool_joint_pool_split=TRUE on V0(1240) and "
            f"V1(1241). Got: {patched_ids}"
        )

        # ----- Assert: POST p_participant_count = 7 (len(parsed_rows)) on each
        # joint-pool sibling -----
        ingest_posts = [
            p for p in recorded["posts"]
            if "fn_ingest_tournament_results" in p["url"]
        ]
        assert len(ingest_posts) == 2, (
            f"Expected 2 ingest POSTs (one per non-empty sibling). "
            f"Got {len(ingest_posts)}."
        )
        for post in ingest_posts:
            body = post.get("json", {})
            assert body.get("p_participant_count") == 7, (
                f"Joint-pool ingest must pass p_participant_count = "
                f"len(parsed_rows) = 7. Got {body.get('p_participant_count')}."
            )
