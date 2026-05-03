"""ADR-056 revision (2026-05-03) — consolidator participant_count fix.

Tests for python.tools.phase5_runner._consolidate_duplicate_codes recomputing
int_participant_count on merge.

Plan test IDs: 5.19.3
"""
from __future__ import annotations

from unittest.mock import MagicMock


def _build_chain_returns(rows):
    """Build a mock where .select().eq().execute().data == rows (single eq)."""
    chain = MagicMock()
    chain.select.return_value.eq.return_value.execute.return_value.data = rows
    return chain


def test_consolidator_recomputes_participant_count_5_19_3():
    """5.19.3: After merging duplicate tournament_drafts, the keeper's
    int_participant_count is recomputed to reflect total merged result_drafts.

    Pre-revision behaviour: consolidator merged result_drafts but left the
    keeper's int_participant_count untouched (= source-URL count, drifting
    from row count). This is the data-integrity bug surfaced by GP1-V2-SABRE-M
    showing int_participant_count=8 with 10 actual rows after merge.

    Post-revision: consolidator updates int_participant_count to the sum of
    merged result_drafts in a single update call alongside the joint flag."""
    from python.tools.phase5_runner import _consolidate_duplicate_codes

    db = MagicMock()
    sb = db._sb
    run_id = "fake-run-id"

    # 1) tbl_tournament_draft.select(...).eq(run_id).execute() → 2 dups
    # 2) tbl_result_draft.select(...).eq(td_id=10).execute() → 8 results
    # 3) tbl_result_draft.select(...).eq(td_id=11).execute() → 2 results
    # 4) tbl_result_draft.update({td_id: 10}).eq(td_id=11).execute()  (reassign)
    # 5) tbl_tournament_draft.delete().eq(td_id=11).execute()
    # 6) tbl_tournament_draft.update({...}).eq(td_id=10).execute()  (joint flag + count)
    call_log: list[tuple] = []

    def fake_table(name):
        tbl = MagicMock()

        # .select(...).eq(...).execute() returns canned data
        def make_select(_cols):
            sel = MagicMock()

            def make_eq(col, val):
                eq = MagicMock()

                def execute():
                    res = MagicMock()
                    if name == "tbl_tournament_draft" and col == "txt_run_id":
                        res.data = [
                            {"id_tournament_draft": 10, "txt_code": "TEST-V2",
                             "bool_joint_pool_split": False},
                            {"id_tournament_draft": 11, "txt_code": "TEST-V2",
                             "bool_joint_pool_split": False},
                        ]
                    elif name == "tbl_result_draft" and col == "id_tournament_draft":
                        res.data = (
                            [{"id_result_draft": i} for i in range(1, 9)]
                            if val == 10
                            else [{"id_result_draft": i} for i in range(9, 11)]
                        )
                    else:
                        res.data = []
                    return res

                eq.execute = execute
                return eq

            sel.eq = make_eq
            return sel

        tbl.select = make_select

        def make_update(payload):
            upd = MagicMock()

            def upd_eq(col, val):
                eq = MagicMock()

                def execute():
                    call_log.append((name, "update", payload, col, val))
                    return MagicMock()

                eq.execute = execute
                return eq

            upd.eq = upd_eq
            return upd

        tbl.update = make_update

        def make_delete():
            d = MagicMock()

            def del_eq(col, val):
                eq = MagicMock()

                def execute():
                    call_log.append((name, "delete", None, col, val))
                    return MagicMock()

                eq.execute = execute
                return eq

            d.eq = del_eq
            return d

        tbl.delete = make_delete
        return tbl

    sb.table.side_effect = fake_table

    removed = _consolidate_duplicate_codes(db, run_id)
    assert removed == 1, f"expected 1 dup removed, got {removed}"

    # Verify the keeper's tournament_draft got an update with
    # int_participant_count = 10 (8 + 2 merged)
    keeper_updates = [
        c for c in call_log
        if c[0] == "tbl_tournament_draft" and c[1] == "update"
        and c[3] == "id_tournament_draft" and c[4] == 10
    ]
    assert keeper_updates, \
        f"expected an update on keeper td_id=10, got call_log={call_log}"

    # The participant-count update should be present in (at least) one update payload
    # to the keeper. Could be combined with the joint flag in one call, or separate.
    payloads_with_count = [
        c[2] for c in keeper_updates if "int_participant_count" in c[2]
    ]
    assert payloads_with_count, \
        ("expected keeper to receive an update setting int_participant_count "
         f"after merge; got payloads={[c[2] for c in keeper_updates]}")
    actual_count = payloads_with_count[0]["int_participant_count"]
    assert actual_count == 10, \
        f"expected int_participant_count=10 after merging 8+2 results, got {actual_count}"
