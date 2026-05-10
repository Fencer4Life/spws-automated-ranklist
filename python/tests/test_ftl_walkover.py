"""
Plan-test-ID 5.M3 (ADR-066): FTL JSON parser handles single-competitor
walkover brackets.

Bug history (2026-05-10): SPWS rolling-score awards points for 1-competitor
brackets (config: `tbl_scoring_config.int_min_participants_ppw = 1`). FTL
emits the bracket JSON for a 1-competitor "Finished" pool with `place: null`
(or empty string) — no actual fencing happened, so FTL doesn't compute a
ranking. The parser at python/scrapers/ftl.py:73 dropped every entry with
unparseable place, returning n=0 → orchestrator skipped the bracket → 8
PPW2-2025-2026 brackets vanished from the active-season ranklist.

Walkover rule: when there is exactly ONE non-`excluded` entry and its
`place` does not parse, assign place=1 (the lone competitor wins by
default). Multi-entry-with-all-null-places stays as today (truly unranked
data, drop them all — it's not our domain).
"""

from __future__ import annotations


def test_5_M3_1_single_entry_null_place_becomes_walkover():
    """5.M3.1 — 1-entry bracket with place=null gets place=1 (walkover)."""
    from python.scrapers.ftl import parse_ftl_json
    data = [{"name": "KOWALSKI Jan", "place": None, "country": "POL"}]
    results = parse_ftl_json(data)
    assert len(results) == 1, f"expected 1 walkover result, got {len(results)}"
    assert results[0]["place"] == 1
    assert results[0]["fencer_name"] == "KOWALSKI Jan"
    assert results[0]["country"] == "POL"


def test_5_M3_2_single_entry_empty_place_string_becomes_walkover():
    """5.M3.2 — same as M3.1 but place is empty string instead of null."""
    from python.scrapers.ftl import parse_ftl_json
    data = [{"name": "NOWAK Anna", "place": "", "country": "POL"}]
    results = parse_ftl_json(data)
    assert len(results) == 1
    assert results[0]["place"] == 1


def test_5_M3_3_single_entry_with_valid_place_stays_unchanged():
    """5.M3.3 — 1-entry bracket with place=1 already → no-op (no double-assign)."""
    from python.scrapers.ftl import parse_ftl_json
    data = [{"name": "WIŚNIEWSKI Piotr", "place": 1, "country": "POL"}]
    results = parse_ftl_json(data)
    assert len(results) == 1
    assert results[0]["place"] == 1


def test_5_M3_4_two_entries_all_null_places_drops_both():
    """5.M3.4 — 2+ entries all with null places stays at current behaviour:
    drop both. Walkover rule is strictly for n=1 brackets."""
    from python.scrapers.ftl import parse_ftl_json
    data = [
        {"name": "A", "place": None, "country": "POL"},
        {"name": "B", "place": None, "country": "POL"},
    ]
    results = parse_ftl_json(data)
    assert results == [], f"expected drop-both, got {results}"


def test_5_M3_5_single_entry_excluded_yields_zero_results():
    """5.M3.5 — 1 entry but excluded=True → still no result (excluded
    takes precedence over walkover)."""
    from python.scrapers.ftl import parse_ftl_json
    data = [{"name": "X", "place": None, "country": "POL", "excluded": True}]
    results = parse_ftl_json(data)
    assert results == []


def test_5_M3_6_marker_parser_walkover_keeps_marker_field():
    """5.M3.6 — parse_ftl_with_marker also gets walkover semantics; the
    `marker` field stays None when not encoded in the name."""
    from python.scrapers.ftl import parse_ftl_with_marker
    data = [{"name": "KOWALSKI 2 Jan", "place": None, "country": "POL"}]
    results = parse_ftl_with_marker(data)
    assert len(results) == 1
    assert results[0]["place"] == 1
    assert results[0]["marker"] == 2
    assert results[0]["fencer_name"] == "KOWALSKI Jan"


def test_5_M3_7_two_entries_one_with_place_keeps_only_the_one_with_place():
    """5.M3.7 — Mixed: one entry has place, the other doesn't. The
    walkover rule does NOT activate (n_non_excluded=2). The entry with
    place stays; the one without is dropped."""
    from python.scrapers.ftl import parse_ftl_json
    data = [
        {"name": "A", "place": 1, "country": "POL"},
        {"name": "B", "place": None, "country": "POL"},
    ]
    results = parse_ftl_json(data)
    assert len(results) == 1
    assert results[0]["fencer_name"] == "A"
    assert results[0]["place"] == 1


# ---------------------------------------------------------------------------
# 5.M3.8+ — IR-aware parse_json (used by the orchestrator's Fetcher path)
# ---------------------------------------------------------------------------

def test_5_M3_8_ir_parse_json_single_entry_null_place_walkover():
    """5.M3.8 — IR-aware parser also has walkover. This is the entry
    point Fetcher.fetch_url uses → critical for the orchestrator path."""
    from python.scrapers.ftl import parse_json
    data = [{"name": "KOWALSKI Jan", "place": None, "country": "POL",
             "id": "ABCDEF0123456789ABCDEF0123456789"}]
    parsed = parse_json(data, source_url="https://example.test/x")
    assert len(parsed.results) == 1
    assert parsed.results[0].place == 1
    assert parsed.results[0].fencer_name == "KOWALSKI Jan"


def test_5_M3_9_ir_parse_json_empty_data_yields_no_results():
    """5.M3.9 — empty JSON (FTL emits []) → no walkover, zero results.
    Threshold gate then decides; default threshold=1 skips."""
    from python.scrapers.ftl import parse_json
    parsed = parse_json([], source_url="https://example.test/x")
    assert len(parsed.results) == 0


def test_5_M3_10_ir_parse_json_two_entries_one_null_place_drops_null():
    """5.M3.10 — n≥2 with one null place: drop the null, keep the placed.
    Walkover does not activate."""
    from python.scrapers.ftl import parse_json
    data = [
        {"name": "A", "place": 1, "country": "POL"},
        {"name": "B", "place": None, "country": "POL"},
    ]
    parsed = parse_json(data)
    assert len(parsed.results) == 1
    assert parsed.results[0].fencer_name == "A"
