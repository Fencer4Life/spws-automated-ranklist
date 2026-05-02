"""
Tests for python/pipeline/draft_store.py — Phase 2 (ADR-050) draft scratch state.

Plan test IDs P2.D1–P2.D8 (per /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md
Phase 2 subplan doc/plans/rebuild/p2-drafts.md).

  P2.D1  write_tournament_drafts inserts rows; returns id_tournament_draft list
  P2.D2  write_result_drafts bulk-inserts; returns count
  P2.D3  read_drafts(run_id) returns (tournaments, results) tuple
  P2.D4  list_drafts() returns one entry per run_id with counts + first_seen
  P2.D5  discard(run_id) calls fn_discard_event_draft, returns JSONB-as-dict
  P2.D6  commit(run_id) calls fn_commit_event_draft, returns JSONB-as-dict
  P2.D7  read_drafts works across separate DraftStore instances (resumability)
  P2.D8  empty read_drafts(unknown_run_id) returns ([], []), no exception

DbConnector extension tests (P2.B*) live alongside in test_db_connector.py
for cohesion with existing patterns.
"""

from __future__ import annotations

from unittest.mock import MagicMock
from uuid import uuid4


def _mk_db_with_supabase():
    """Build a DbConnector wrapped around a fully-mocked supabase client."""
    from python.pipeline.db_connector import DbConnector
    sb = MagicMock()
    return DbConnector(sb), sb


class TestDraftStore:
    """P2.D1–P2.D8: DraftStore (Phase 2 ADR-050)."""

    def test_write_tournament_drafts_returns_id_list(self):
        """P2.D1 write_tournament_drafts inserts rows; returns id_tournament_draft list."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        run_id = str(uuid4())
        sb.table.return_value.insert.return_value.execute.return_value.data = [
            {"id_tournament_draft": 1, "txt_code": "TEST-V0", "txt_run_id": run_id},
            {"id_tournament_draft": 2, "txt_code": "TEST-V1", "txt_run_id": run_id},
        ]

        store = DraftStore(db)
        ids = store.write_tournament_drafts(
            tournaments=[
                {"id_event": 10, "txt_code": "TEST-V0", "enum_type": "PPW",
                 "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V0",
                 "enum_parser_kind": "FENCINGTIME_XML"},
                {"id_event": 10, "txt_code": "TEST-V1", "enum_type": "PPW",
                 "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V1",
                 "enum_parser_kind": "FENCINGTIME_XML"},
            ],
            run_id=run_id,
        )
        assert ids == [1, 2]
        # Each inserted row carries the run_id
        called_with = sb.table.return_value.insert.call_args[0][0]
        assert all(row["txt_run_id"] == run_id for row in called_with)

    def test_write_result_drafts_returns_count(self):
        """P2.D2 write_result_drafts bulk-inserts; returns count inserted."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        run_id = str(uuid4())
        sb.table.return_value.insert.return_value.execute.return_value.data = [
            {"id_result_draft": i} for i in range(1, 8)
        ]

        store = DraftStore(db)
        n = store.write_result_drafts(
            results=[
                {"id_fencer": 100 + i, "id_tournament_draft": 1, "int_place": i}
                for i in range(1, 8)
            ],
            run_id=run_id,
        )
        assert n == 7
        called_with = sb.table.return_value.insert.call_args[0][0]
        assert all(row["txt_run_id"] == run_id for row in called_with)

    def test_read_drafts_returns_tuple(self):
        """P2.D3 read_drafts(run_id) returns (tournaments, results) tuple."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        run_id = str(uuid4())

        # Two .table() calls happen in read_drafts: tournaments first, then results
        tour_select = MagicMock()
        tour_select.select.return_value.eq.return_value.execute.return_value.data = [
            {"id_tournament_draft": 1, "txt_code": "X-V0", "txt_run_id": run_id},
        ]
        res_select = MagicMock()
        res_select.select.return_value.eq.return_value.execute.return_value.data = [
            {"id_result_draft": 1, "id_fencer": 100, "id_tournament_draft": 1,
             "int_place": 1, "txt_run_id": run_id},
            {"id_result_draft": 2, "id_fencer": 101, "id_tournament_draft": 1,
             "int_place": 2, "txt_run_id": run_id},
        ]
        sb.table.side_effect = lambda name: (
            tour_select if name == "tbl_tournament_draft" else res_select
        )

        store = DraftStore(db)
        tournaments, results = store.read_drafts(run_id)
        assert len(tournaments) == 1
        assert len(results) == 2
        assert tournaments[0]["txt_code"] == "X-V0"

    def test_list_drafts_groups_by_run_id(self):
        """P2.D4 list_drafts() returns one entry per run_id with counts + first_seen."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        run_a = str(uuid4())
        run_b = str(uuid4())

        # Mock table-then-select-then-execute returning rows for tournaments + results
        tour_chain = MagicMock()
        tour_chain.select.return_value.execute.return_value.data = [
            {"txt_run_id": run_a, "ts_created": "2026-05-01T10:00:00Z"},
            {"txt_run_id": run_a, "ts_created": "2026-05-01T10:00:01Z"},
            {"txt_run_id": run_b, "ts_created": "2026-05-02T11:00:00Z"},
        ]
        res_chain = MagicMock()
        res_chain.select.return_value.execute.return_value.data = [
            {"txt_run_id": run_a},
            {"txt_run_id": run_a},
            {"txt_run_id": run_a},
        ]
        sb.table.side_effect = lambda name: (
            tour_chain if name == "tbl_tournament_draft" else res_chain
        )

        store = DraftStore(db)
        drafts = store.list_drafts()
        # Two distinct run_ids, sorted by first_seen ascending
        assert len(drafts) == 2
        a_entry = next(d for d in drafts if d["run_id"] == run_a)
        b_entry = next(d for d in drafts if d["run_id"] == run_b)
        assert a_entry["tournament_count"] == 2
        assert a_entry["result_count"] == 3
        assert b_entry["tournament_count"] == 1
        assert b_entry["result_count"] == 0

    def test_discard_calls_rpc_and_returns_dict(self):
        """P2.D5 discard(run_id) calls fn_discard_event_draft, returns dict."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        run_id = str(uuid4())
        sb.rpc.return_value.execute.return_value.data = {
            "run_id": run_id,
            "tournaments_discarded": 3,
            "results_discarded": 117,
        }

        store = DraftStore(db)
        result = store.discard(run_id)
        sb.rpc.assert_called_once_with("fn_discard_event_draft", {"p_run_id": run_id})
        assert result["tournaments_discarded"] == 3
        assert result["results_discarded"] == 117

    def test_commit_calls_rpc_and_returns_dict(self):
        """P2.D6 commit(run_id) calls fn_commit_event_draft, returns dict."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        run_id = str(uuid4())
        sb.rpc.return_value.execute.return_value.data = {
            "run_id": run_id,
            "tournaments_committed": 4,
            "results_committed": 117,
            "joint_pool_siblings_flagged": 2,
            "history_rows": 4,
        }

        store = DraftStore(db)
        result = store.commit(run_id)
        sb.rpc.assert_called_once_with("fn_commit_event_draft", {"p_run_id": run_id})
        assert result["tournaments_committed"] == 4
        assert result["joint_pool_siblings_flagged"] == 2

    def test_read_drafts_resumable_across_instances(self):
        """P2.D7 read_drafts works across separate DraftStore instances."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        run_id = str(uuid4())

        tour_chain = MagicMock()
        tour_chain.select.return_value.eq.return_value.execute.return_value.data = [
            {"id_tournament_draft": 1, "txt_run_id": run_id},
        ]
        res_chain = MagicMock()
        res_chain.select.return_value.eq.return_value.execute.return_value.data = []
        sb.table.side_effect = lambda name: (
            tour_chain if name == "tbl_tournament_draft" else res_chain
        )

        # Instance 1 reads
        store1 = DraftStore(db)
        t1, r1 = store1.read_drafts(run_id)

        # Instance 2 (fresh) reads — same run_id, no shared in-memory state required
        store2 = DraftStore(db)
        t2, r2 = store2.read_drafts(run_id)

        assert t1 == t2
        assert r1 == r2

    def test_read_drafts_unknown_run_id_returns_empty_tuple(self):
        """P2.D8 read_drafts(unknown_run_id) returns ([], []), no exception."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        empty = MagicMock()
        empty.select.return_value.eq.return_value.execute.return_value.data = []
        sb.table.return_value = empty

        store = DraftStore(db)
        tournaments, results = store.read_drafts("00000000-0000-0000-0000-000000000000")
        assert tournaments == []
        assert results == []

    def test_dry_run_calls_rpc_and_returns_dict(self):
        """P2.D9 dry_run(payload) calls fn_dry_run_event_draft, returns dict."""
        from python.pipeline.draft_store import DraftStore

        db, sb = _mk_db_with_supabase()
        sb.rpc.return_value.execute.return_value.data = {
            "tournaments_would_create": 4,
            "results_would_create": 117,
            "joint_pool_sibling_groups": 1,
        }

        store = DraftStore(db)
        payload = {"tournaments": [], "results": []}
        result = store.dry_run(payload)
        sb.rpc.assert_called_once_with("fn_dry_run_event_draft", {"p_drafts": payload})
        assert result["tournaments_would_create"] == 4
