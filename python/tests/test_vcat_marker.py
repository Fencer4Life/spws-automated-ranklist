"""
Tests for the per-fencer V-cat marker check (ADR-065, drafted 2026-05-08, renumbered from 063 on 2026-05-10).

When a Polish FTL operator stuffs multiple V-cats into a bracket whose name
declares a single V-cat (e.g. "SZPADA KOBIET 2 WETERANI" but with V0/V1/V2
fencers inside, marked as "(0)" / "1" / "(2)" in their names), the splitter
must detect this and downgrade the bracket to joint-pool so that
ADR-056's BY-derivation path can route each fencer to her actual V-cat.

Plan IDs P5.M1.* (FTL splitter marker check).
"""

from __future__ import annotations

from dataclasses import dataclass


# ---------------------------------------------------------------------------
# extract_vcat_marker — pure regex helper
# ---------------------------------------------------------------------------

def test_extract_vcat_marker_parenthesized():
    """5.M1.1 — `(N)` pattern between surname and first name."""
    from python.pipeline.review_cli import _extract_vcat_marker
    assert _extract_vcat_marker("PĘCZEK (0) Sandra") == 0
    assert _extract_vcat_marker("WASILCZUK (2) Beata") == 2
    assert _extract_vcat_marker("KLIMECKA (1) Dorota") == 1


def test_extract_vcat_marker_bare_digit():
    """5.M1.2 — bare digit between whitespace runs."""
    from python.pipeline.review_cli import _extract_vcat_marker
    assert _extract_vcat_marker("KAMIŃSKA   1 Gabriela") == 1
    assert _extract_vcat_marker("KRUJALSKIENE  0 Julia") == 0
    assert _extract_vcat_marker("WALECKA  2 Wanda") == 2


def test_extract_vcat_marker_no_marker():
    """5.M1.3 — clean fencer name returns None."""
    from python.pipeline.review_cli import _extract_vcat_marker
    assert _extract_vcat_marker("MITSKEVICH Dziyana") is None
    assert _extract_vcat_marker("PĘCZEK Sandra") is None
    assert _extract_vcat_marker("RIVERA CASTRO Tatiana") is None


def test_extract_vcat_marker_edge_cases():
    """5.M1.4 — empty / None / out-of-range digits."""
    from python.pipeline.review_cli import _extract_vcat_marker
    assert _extract_vcat_marker("") is None
    assert _extract_vcat_marker(None) is None
    # 5+ are not valid V-cats; regex matches only 0-4
    assert _extract_vcat_marker("FOOBAR 5 Smith") is None
    assert _extract_vcat_marker("BAZQUX 9 Jones") is None


def test_extract_vcat_marker_hyphenated_surname():
    """5.M1.5 — hyphenated surnames don't break marker detection."""
    from python.pipeline.review_cli import _extract_vcat_marker
    assert _extract_vcat_marker("SAMECKA - NACZYŃSKA 1 Martyna") == 1


# ---------------------------------------------------------------------------
# _bracket_marker_conflict — detection logic
# ---------------------------------------------------------------------------

@dataclass
class _FakeResult:
    fencer_name: str


@dataclass
class _FakeParsed:
    results: list


def test_bracket_marker_conflict_joint_pool_passthrough():
    """5.M1.6 — bracket already joint-pool (None) → no conflict signal."""
    from python.pipeline.review_cli import _bracket_marker_conflict
    parsed = _FakeParsed(results=[_FakeResult("KAMIŃSKA  1 Gabriela")])
    has_conflict, summary = _bracket_marker_conflict(parsed, None)
    assert has_conflict is False
    assert summary == "joint"


def test_bracket_marker_conflict_no_markers():
    """5.M1.7 — clean per-V-cat bracket with no embedded markers → trust label."""
    from python.pipeline.review_cli import _bracket_marker_conflict
    parsed = _FakeParsed(results=[
        _FakeResult("KAMIŃSKA Gabriela"),
        _FakeResult("WASILCZUK Beata"),
    ])
    has_conflict, summary = _bracket_marker_conflict(parsed, "V2")
    assert has_conflict is False
    assert summary == "no markers"


def test_bracket_marker_conflict_consistent_markers():
    """5.M1.8 — markers all match bracket V-cat → consistent, trust."""
    from python.pipeline.review_cli import _bracket_marker_conflict
    parsed = _FakeParsed(results=[
        _FakeResult("FENCER A (1) Maria"),
        _FakeResult("FENCER B  1 Anna"),
        _FakeResult("FENCER C Jolanta"),  # no marker — defaults to bracket V1
    ])
    has_conflict, summary = _bracket_marker_conflict(parsed, "V1")
    assert has_conflict is False
    assert summary == "V1=2"


def test_bracket_marker_conflict_misregistered_bracket():
    """5.M1.9 — bracket says V2 but markers span V0/V1/V2 → conflict, downgrade."""
    from python.pipeline.review_cli import _bracket_marker_conflict
    parsed = _FakeParsed(results=[
        _FakeResult("KAMIŃSKA   1 Gabriela"),       # V1
        _FakeResult("WASILCZUK (2) Beata"),         # V2
        _FakeResult("KRUJALSKIENE  0 Julia"),       # V0
        _FakeResult("WALECKA  2 Wanda"),            # V2
    ])
    has_conflict, summary = _bracket_marker_conflict(parsed, "V2")
    assert has_conflict is True
    assert "V0=" in summary and "V1=" in summary and "V2=" in summary


def test_bracket_marker_conflict_single_outlier():
    """5.M1.10 — even a single mismatched marker triggers conflict."""
    from python.pipeline.review_cli import _bracket_marker_conflict
    parsed = _FakeParsed(results=[
        _FakeResult("FENCER A (2) Anna"),
        _FakeResult("FENCER B (2) Beata"),
        _FakeResult("FENCER C  3 Catarina"),  # the outlier
    ])
    has_conflict, summary = _bracket_marker_conflict(parsed, "V2")
    assert has_conflict is True


def test_bracket_marker_conflict_empty_results():
    """5.M1.11 — bracket with zero fencers → no conflict, no info."""
    from python.pipeline.review_cli import _bracket_marker_conflict
    parsed = _FakeParsed(results=[])
    has_conflict, summary = _bracket_marker_conflict(parsed, "V1")
    assert has_conflict is False
    assert summary == "no results"
