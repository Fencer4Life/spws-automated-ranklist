"""
Tests for python/pipeline/alias_writeback.py — Phase 5 sign-off-driven alias
write-back to tbl_fencer.json_name_aliases.

Plan IDs P5.AW1-P5.AW10.
"""

from __future__ import annotations

from unittest.mock import MagicMock


# ---------------------------------------------------------------------------
# compute_pending_aliases — pure classification
# ---------------------------------------------------------------------------


# 5.AW1 — exact-match aliases ARE NOT in alias_new_needed (assumes upstream
# filter), but a different-spelling pair IS classified ✓ and surfaced
def test_compute_classifies_diacritic_variant_as_check():
    from python.pipeline.alias_writeback import compute_pending_aliases

    stats = {
        "alias_new_needed": [{
            "id_fencer": 61,
            "scraped_name": "FRAS Felix",        # ASCII transliteration
            "canonical": "FRAŚ Feliks",          # canonical with diacritic
        }],
    }
    out = compute_pending_aliases(stats)
    assert len(out) == 1
    assert out[0].icon == "✓"
    assert out[0].id_fencer == 61
    assert out[0].scraped_name == "FRAS Felix"


# 5.AW2 — surname disagreement → ❌ (block sign-off)
def test_compute_classifies_different_surname_as_block():
    from python.pipeline.alias_writeback import compute_pending_aliases

    stats = {
        "alias_new_needed": [{
            "id_fencer": 100,
            "scraped_name": "KOWALSKI Adam",
            "canonical": "NOWAK Adam",
        }],
    }
    out = compute_pending_aliases(stats)
    assert len(out) == 1
    assert out[0].icon == "❌"


# 5.AW3 — dedup by (id_fencer, scraped_name)
def test_compute_dedupes_repeat_pairs():
    from python.pipeline.alias_writeback import compute_pending_aliases

    stats = {
        "alias_new_needed": [
            {"id_fencer": 7, "scraped_name": "FRAS Felix",
             "canonical": "FRAŚ Feliks"},
            {"id_fencer": 7, "scraped_name": "FRAS Felix",
             "canonical": "FRAŚ Feliks"},
            {"id_fencer": 7, "scraped_name": "FRAS Felix",
             "canonical": "FRAŚ Feliks"},
        ],
    }
    out = compute_pending_aliases(stats)
    assert len(out) == 1


# 5.AW4 — empty input → empty list
def test_compute_handles_empty_input():
    from python.pipeline.alias_writeback import compute_pending_aliases

    assert compute_pending_aliases({}) == []
    assert compute_pending_aliases({"alias_new_needed": []}) == []


# 5.AW5 — sort order: ❌ first, then ❓, then ✓
def test_compute_sort_order_blocks_first():
    from python.pipeline.alias_writeback import compute_pending_aliases

    stats = {
        "alias_new_needed": [
            {"id_fencer": 1, "scraped_name": "FRAS Felix",
             "canonical": "FRAŚ Feliks"},                # ✓
            {"id_fencer": 2, "scraped_name": "KOWALSKI Adam",
             "canonical": "NOWAK Adam"},                 # ❌
        ],
    }
    out = compute_pending_aliases(stats)
    assert [p.icon for p in out] == ["❌", "✓"]


# 5.AW6 — has_blocking_pairs detects ❌
def test_has_blocking_pairs_true_when_red_x_present():
    from python.pipeline.alias_writeback import (
        compute_pending_aliases, has_blocking_pairs,
    )
    out = compute_pending_aliases({
        "alias_new_needed": [
            # Different multi-char surnames → ❌
            {"id_fencer": 2, "scraped_name": "KOWALSKI Adam",
             "canonical": "NOWAK Adam"},
        ],
    })
    assert has_blocking_pairs(out) is True


def test_has_blocking_pairs_false_when_only_check_marks():
    from python.pipeline.alias_writeback import (
        compute_pending_aliases, has_blocking_pairs,
    )
    out = compute_pending_aliases({
        "alias_new_needed": [
            # Diacritic variant → ✓
            {"id_fencer": 1, "scraped_name": "FRAS Felix",
             "canonical": "FRAŚ Feliks"},
        ],
    })
    assert has_blocking_pairs(out) is False


# ---------------------------------------------------------------------------
# flush_pending_aliases — RPC dispatch
# ---------------------------------------------------------------------------


# 5.AW7 — flush calls fn_update_fencer_aliases for every ✓ pair
def test_flush_calls_rpc_for_check_marks():
    from python.pipeline.alias_writeback import (
        flush_pending_aliases, PendingAlias,
    )

    db = MagicMock()
    pairs = [
        PendingAlias(id_fencer=1, scraped_name="DOE J",
                     canonical="DOE John", icon="✓", reason="case only"),
        PendingAlias(id_fencer=2, scraped_name="ROE Jan",
                     canonical="ROE Janet", icon="✓", reason="typo"),
    ]
    result = flush_pending_aliases(db, pairs)
    assert result["written"] == 2
    assert result["errors"] == []
    # Two RPC calls
    assert db._sb.rpc.call_count == 2
    db._sb.rpc.assert_any_call(
        "fn_update_fencer_aliases",
        {"p_id_fencer": 1, "p_alias": "DOE J"},
    )


# 5.AW7b — flush(include_all=True) writes EVERY pair regardless of icon
def test_flush_include_all_writes_every_pair():
    from python.pipeline.alias_writeback import (
        flush_pending_aliases, PendingAlias,
    )

    db = MagicMock()
    pairs = [
        PendingAlias(id_fencer=1, scraped_name="A", canonical="B",
                     icon="❌", reason="wrong"),
        PendingAlias(id_fencer=2, scraped_name="C", canonical="D",
                     icon="❓", reason="ambig"),
        PendingAlias(id_fencer=3, scraped_name="E", canonical="F",
                     icon="✓", reason="case only"),
    ]
    result = flush_pending_aliases(db, pairs, include_all=True)
    assert result["written"] == 3
    assert result["skipped_blocked"] == 0
    assert result["skipped_ambiguous"] == 0
    # All 3 RPCs dispatched
    assert db._sb.rpc.call_count == 3


# 5.AW8 — flush SKIPS ❌ and ❓ pairs (does NOT write)
def test_flush_skips_blocked_and_ambiguous():
    from python.pipeline.alias_writeback import (
        flush_pending_aliases, PendingAlias,
    )

    db = MagicMock()
    pairs = [
        PendingAlias(id_fencer=1, scraped_name="X", canonical="Y",
                     icon="❌", reason="wrong"),
        PendingAlias(id_fencer=2, scraped_name="A", canonical="B",
                     icon="❓", reason="ambig"),
        PendingAlias(id_fencer=3, scraped_name="C", canonical="D",
                     icon="✓", reason="case only"),
    ]
    result = flush_pending_aliases(db, pairs)
    assert result["written"] == 1
    assert result["skipped_blocked"] == 1
    assert result["skipped_ambiguous"] == 1
    # Only ONE RPC dispatched (for the ✓ pair)
    assert db._sb.rpc.call_count == 1


# 5.AW9 — flush captures RPC errors without aborting subsequent writes
def test_flush_captures_rpc_errors_and_continues():
    from python.pipeline.alias_writeback import (
        flush_pending_aliases, PendingAlias,
    )

    db = MagicMock()
    # First .rpc() call succeeds; second raises.
    call_count = {"n": 0}

    def fake_rpc(*args, **kwargs):
        call_count["n"] += 1
        if call_count["n"] == 2:
            raise RuntimeError("RLS denied")
        return MagicMock()

    db._sb.rpc.side_effect = fake_rpc

    pairs = [
        PendingAlias(id_fencer=1, scraped_name="A", canonical="B",
                     icon="✓", reason="ok"),
        PendingAlias(id_fencer=2, scraped_name="C", canonical="D",
                     icon="✓", reason="ok"),
        PendingAlias(id_fencer=3, scraped_name="E", canonical="F",
                     icon="✓", reason="ok"),
    ]
    result = flush_pending_aliases(db, pairs)
    assert result["written"] == 2  # call 1 + call 3 succeed
    assert len(result["errors"]) == 1
    fid, alias, msg = result["errors"][0]
    assert fid == 2 and alias == "C"
    assert "RuntimeError: RLS denied" in msg


# 5.AW10 — derive_pending_from_run_id reads drafts + filters PENDING/EXCLUDED
def test_derive_pending_from_run_id_filters_non_auto_methods():
    from python.pipeline.alias_writeback import derive_pending_from_run_id

    db = MagicMock()
    # Stub: 3 result_drafts. Only the AUTO_MATCH one is alias material; the
    # PENDING and EXCLUDED rows must be excluded entirely.
    db._sb.table().select().eq().execute.return_value = MagicMock(data=[
        {"id_fencer": 11, "txt_scraped_name": "DOE Janet",
         "enum_match_method": "AUTO_MATCH", "id_tournament_draft": 1},
        {"id_fencer": 12, "txt_scraped_name": "X Y",
         "enum_match_method": "PENDING", "id_tournament_draft": 1},
        {"id_fencer": 13, "txt_scraped_name": "P Q",
         "enum_match_method": "EXCLUDED", "id_tournament_draft": 1},
    ])
    db.fetch_fencer_basics_batch.return_value = {
        11: {
            "txt_surname": "DOE", "txt_first_name": "John",
            "json_name_aliases": [],
        },
    }
    out = derive_pending_from_run_id(db, run_id="run-x")
    # Only the AUTO_MATCH row produces a candidate.
    assert len(out) == 1
    assert out[0].id_fencer == 11
    assert out[0].scraped_name == "DOE Janet"


# 5.AW11 — derive_pending_from_run_id treats "alias-already-on-fencer" as
# user-confirmed (after Keep/Transfer/Create in FencerAliasManager UI),
# so the classifier ❌ does NOT block sign-off for cases the operator has
# already explicitly accepted. The classifier still gates FRESH alias
# candidates not yet on tbl_fencer.
def test_derive_pending_treats_existing_alias_as_user_confirmed():
    from python.pipeline.alias_writeback import derive_pending_from_run_id

    db = MagicMock()
    # Two draft rows pointing at the same fencer:
    #   1. NIKOŁAJCZUK Aleksander — already in id=197's aliases
    #      (user clicked Keep — this is a real transliteration alias).
    #      Classifier would say ❌ on names alone, but user-confirmed wins.
    #   2. SOMETHING NEW Aliaksandr — NOT in aliases yet (fresh candidate).
    db._sb.table().select().eq().execute.return_value = MagicMock(data=[
        {"id_fencer": 197, "txt_scraped_name": "NIKOŁAJCZUK Aleksander",
         "enum_match_method": "AUTO_MATCH", "id_tournament_draft": 1},
        {"id_fencer": 197, "txt_scraped_name": "BRANDNEW Aliaksandr",
         "enum_match_method": "AUTO_MATCH", "id_tournament_draft": 1},
    ])
    db.fetch_fencer_basics_batch.return_value = {
        197: {
            "txt_surname": "NIKALAICHUK", "txt_first_name": "Aliaksandr",
            "json_name_aliases": ["NIKOŁAJCZUK Aleksander"],
        },
    }
    out = derive_pending_from_run_id(db, run_id="run-x")
    # NIKOŁAJCZUK → user-confirmed, filtered. BRANDNEW → fresh, classified.
    assert len(out) == 1
    assert out[0].scraped_name == "BRANDNEW Aliaksandr"


# 5.AW12 — exact canonical match is still skipped (no false-positive ❌)
def test_derive_pending_skips_exact_canonical():
    from python.pipeline.alias_writeback import derive_pending_from_run_id

    db = MagicMock()
    db._sb.table().select().eq().execute.return_value = MagicMock(data=[
        {"id_fencer": 50, "txt_scraped_name": "DOE John",
         "enum_match_method": "AUTO_MATCH", "id_tournament_draft": 1},
    ])
    db.fetch_fencer_basics_batch.return_value = {
        50: {
            "txt_surname": "DOE", "txt_first_name": "John",
            "json_name_aliases": [],
        },
    }
    out = derive_pending_from_run_id(db, run_id="run-x")
    # "DOE John" == "DOE John" — exact canonical, no alias needed
    assert out == []


# 5.AW13 — compute_pending_from_matches: works with StageMatchResult-style objects
def test_compute_from_matches_accepts_stagematchresult_attrs():
    from python.pipeline.alias_writeback import compute_pending_from_matches

    class FakeMatch:
        def __init__(self, id_fencer, scraped_name):
            self.id_fencer = id_fencer
            self.scraped_name = scraped_name

    matches = [FakeMatch(61, "FRAS Felix")]
    basics = {
        61: {"txt_surname": "FRAŚ", "txt_first_name": "Feliks",
             "json_name_aliases": []},
    }
    out = compute_pending_from_matches(matches, basics)
    assert len(out) == 1
    assert out[0].icon == "✓"
    assert out[0].id_fencer == 61
