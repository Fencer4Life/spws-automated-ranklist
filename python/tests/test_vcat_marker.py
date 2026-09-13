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

import pytest

from python.pipeline.vcat_marker import (
    extract_marker,
    format_marker,
    split_name_marker,
    strip_marker,
)

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

    assert _extract_vcat_marker("PRZYKŁADOWSKA   1 Anna") == 1
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
    assert _extract_vcat_marker(None) is None  # pyright: ignore[reportArgumentType] — intentionally invalid, proves None-handling
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

    parsed = _FakeParsed(results=[_FakeResult("PRZYKŁADOWSKA  1 Anna")])
    has_conflict, summary = _bracket_marker_conflict(parsed, None)
    assert has_conflict is False
    assert summary == "joint"


def test_bracket_marker_conflict_no_markers():
    """5.M1.7 — clean per-V-cat bracket with no embedded markers → trust label."""
    from python.pipeline.review_cli import _bracket_marker_conflict

    parsed = _FakeParsed(
        results=[
            _FakeResult("PRZYKŁADOWSKA Anna"),
            _FakeResult("WASILCZUK Beata"),
        ]
    )
    has_conflict, summary = _bracket_marker_conflict(parsed, "V2")
    assert has_conflict is False
    assert summary == "no markers"


def test_bracket_marker_conflict_consistent_markers():
    """5.M1.8 — markers all match bracket V-cat → consistent, trust."""
    from python.pipeline.review_cli import _bracket_marker_conflict

    parsed = _FakeParsed(
        results=[
            _FakeResult("FENCER A (1) Maria"),
            _FakeResult("FENCER B  1 Anna"),
            _FakeResult("FENCER C Jolanta"),  # no marker — defaults to bracket V1
        ]
    )
    has_conflict, summary = _bracket_marker_conflict(parsed, "V1")
    assert has_conflict is False
    assert summary == "V1=2"


def test_bracket_marker_conflict_misregistered_bracket():
    """5.M1.9 — bracket says V2 but markers span V0/V1/V2 → conflict, downgrade."""
    from python.pipeline.review_cli import _bracket_marker_conflict

    parsed = _FakeParsed(
        results=[
            _FakeResult("PRZYKŁADOWSKA   1 Anna"),  # V1
            _FakeResult("WASILCZUK (2) Beata"),  # V2
            _FakeResult("KRUJALSKIENE  0 Julia"),  # V0
            _FakeResult("WALECKA  2 Wanda"),  # V2
        ]
    )
    has_conflict, summary = _bracket_marker_conflict(parsed, "V2")
    assert has_conflict is True
    assert "V0=" in summary and "V1=" in summary and "V2=" in summary


def test_bracket_marker_conflict_single_outlier():
    """5.M1.10 — even a single mismatched marker triggers conflict."""
    from python.pipeline.review_cli import _bracket_marker_conflict

    parsed = _FakeParsed(
        results=[
            _FakeResult("FENCER A (2) Anna"),
            _FakeResult("FENCER B (2) Beata"),
            _FakeResult("FENCER C  3 Catarina"),  # the outlier
        ]
    )
    has_conflict, summary = _bracket_marker_conflict(parsed, "V2")
    assert has_conflict is True


def test_bracket_marker_conflict_empty_results():
    """5.M1.11 — bracket with zero fencers → no conflict, no info."""
    from python.pipeline.review_cli import _bracket_marker_conflict

    parsed = _FakeParsed(results=[])
    has_conflict, summary = _bracket_marker_conflict(parsed, "V1")
    assert has_conflict is False
    assert summary == "no results"


# ===========================================================================
# The single owner — python/pipeline/vcat_marker.py (ADR-080 §1, amended
# 2026-09-12). The convention above lived in four places that had drifted: the
# SCRAPER read the digit from BETWEEN surname and given name, while the
# EXPORTER appended it to the given name, so our own seed files did not
# round-trip through our own scraper. Only organizer-typed files did, which is
# why MPW 2026 ingested cleanly and nothing raised the alarm.
#
# The tests above are the regression guard for that consolidation: they call
# review_cli's helpers, which now delegate here, and must stay green unchanged.
#
# Plan IDs V.1-V.11.
# ===========================================================================


# ---------------------------------------------------------------------------
# Writing the marker
# ---------------------------------------------------------------------------
def test_format_marker_puts_the_digit_after_the_surname():
    """V.1 — mid-name, which is what the scraper reads and what FTL shows.

    All 20 MPW 2026 events use this form in the wild, including per-category
    brackets where the digit is redundant.
    """
    assert format_marker("PRZYKŁADOWSKA", "1") == "PRZYKŁADOWSKA (1)"


def test_format_marker_accepts_an_int():
    """V.2 — callers hold the V-cat as a digit or an int; both are the same."""
    assert format_marker("NOWAK", 3) == "NOWAK (3)"


def test_format_marker_rejects_a_gendered_marker():
    """V.3 — the decision is the AGE DIGIT ONLY.

    Gender travels as the FIE `Sexe` attribute. Widening this to carry it would
    put the same fact in two places that can disagree, and the scraper would
    then have to guess which one is authoritative.
    """
    with pytest.raises(ValueError):
        format_marker("NOWAK", "MV3")


def test_format_marker_rejects_an_out_of_range_category():
    """V.4 — V0-V4 is the whole domain (ADR-010)."""
    with pytest.raises(ValueError):
        format_marker("NOWAK", "7")


# ---------------------------------------------------------------------------
# Reading it back
# ---------------------------------------------------------------------------
def test_split_name_marker_round_trips_what_format_marker_wrote():
    """V.5 — the property that actually matters. If this fails, a seed file we
    generated cannot be ingested by the pipeline that generated it."""
    nom = format_marker("PRZYKŁADOWSKA", "1")
    result = split_name_marker(f"{nom} Anna")
    assert result is not None
    assert result == ("PRZYKŁADOWSKA", "1", "Anna")


def test_split_name_marker_accepts_a_bare_digit():
    """V.6 — organizers type it both ways; both are seen in the wild."""
    assert split_name_marker("KOWALSKI 2 Jan") == ("KOWALSKI", "2", "Jan")


def test_split_name_marker_handles_a_compound_given_name():
    """V.7 — everything after the digit is the given name, spaces included."""
    result = split_name_marker("DE LA CRUZ (0) Maria Jose")
    assert result is not None
    assert result[2] == "Maria Jose"


def test_split_name_marker_returns_none_when_there_is_no_marker():
    """V.8 — most scraped names carry no marker at all, and that is not an
    error. Returning None keeps the caller's branch explicit."""
    assert split_name_marker("KOWALSKI Jan") is None


def test_extract_marker_finds_the_digit_without_splitting():
    """V.9 — the splitter only needs the V-cat, not the name parts."""
    assert extract_marker("PRZYKŁADOWSKA (1) Anna") == "1"
    assert extract_marker("KOWALSKI Jan") is None


# ---------------------------------------------------------------------------
# Removing it
# ---------------------------------------------------------------------------
def test_strip_marker_removes_every_form():
    """V.10 — matching must never see a marker.

    tbl_fencer holds 367 rows and not one contains a digit or a parenthesis;
    that invariant is this function's job.
    """
    assert strip_marker("PRZYKŁADOWSKA (1) Anna") == "PRZYKŁADOWSKA Anna"
    assert strip_marker("KOWALSKI 2 Jan") == "KOWALSKI Jan"
    assert strip_marker("NOWAK (kat V3) Adam") == "NOWAK Adam"


def test_strip_marker_leaves_a_clean_name_untouched():
    """V.11 — and it must not eat a name that merely contains a number, which
    is the failure mode that would silently corrupt the master list."""
    assert strip_marker("KOWALSKI Jan") == "KOWALSKI Jan"
    assert strip_marker("O'NEILL-SMITH Anna") == "O'NEILL-SMITH Anna"
