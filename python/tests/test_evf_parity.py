"""
Phase 4 (ADR-053) — EVF parity gate logic.

Tests for python/pipeline/evf_parity.py. Plan IDs P4.PG.1 - P4.PG.12.

The parity gate runs post-commit for EVF-organized events. It compares our
engine output (tbl_result rows) to EVF API's published per-category results,
performing three sub-checks:
  1. POL count match
  2. Placements match (absolute Pos, including foreigner gaps)
  3. Score within ±0.5 per fencer

On PASS the orchestrator promotes the event to EVF_PUBLISHED. On FAIL the
event stays ENGINE_COMPUTED with txt_parity_notes populated.
"""

from __future__ import annotations

import pytest

from pipeline.evf_parity import (
    ParityFailDetail,
    ParityResult,
    check_parity,
)


# ---------------------------------------------------------------------------
# Helpers — minimal row shapes
# ---------------------------------------------------------------------------


def _local(name: str, place: int, score: float) -> dict:
    return {"fencer_name": name, "int_place": place, "num_final_score": score}


def _evf(name: str, pos: int, points: float) -> dict:
    return {"name": name, "pos": pos, "points": points}


# ===========================================================================
# Happy path
# ===========================================================================


def test_all_match_passes_all_subchecks():
    """P4.PG.1: identical local + EVF data → all three sub-checks pass."""
    local = [_local("BORKOWSKA Halina", 3, 5.327)]
    evf = [_evf("BORKOWSKA Halina", 3, 5.327)]
    r = check_parity(local, evf)
    assert r.pol_count_pass
    assert r.placements_pass
    assert r.score_pass
    assert r.overall_pass
    assert r.fail_details == []


# ===========================================================================
# POL count
# ===========================================================================


def test_pol_count_mismatch_more_local():
    """P4.PG.2: more local rows than EVF rows → count fails."""
    local = [
        _local("BORKOWSKA Halina", 3, 5.327),
        _local("KOWALSKA Anna", 7, 1.5),
    ]
    evf = [_evf("BORKOWSKA Halina", 3, 5.327)]
    r = check_parity(local, evf)
    assert not r.pol_count_pass
    assert not r.overall_pass
    assert any(d.sub_check == "count" for d in r.fail_details)


def test_pol_count_mismatch_more_evf():
    """P4.PG.3: more EVF rows than local rows → count fails."""
    local = [_local("BORKOWSKA Halina", 3, 5.327)]
    evf = [
        _evf("BORKOWSKA Halina", 3, 5.327),
        _evf("KOWALSKA Anna", 7, 1.5),
    ]
    r = check_parity(local, evf)
    assert not r.pol_count_pass


# ===========================================================================
# Placements
# ===========================================================================


def test_placement_mismatch_fails():
    """P4.PG.4: same fencer different place → placement check fails."""
    local = [_local("BORKOWSKA Halina", 3, 5.327)]
    evf = [_evf("BORKOWSKA Halina", 4, 5.327)]
    r = check_parity(local, evf)
    assert r.pol_count_pass
    assert not r.placements_pass
    assert any(d.sub_check == "placement" for d in r.fail_details)


def test_placement_match_with_foreigner_gaps():
    """P4.PG.5: BORKOWSKA at place 3 (HUN at 1, 2) — placement still matches."""
    local = [_local("BORKOWSKA Halina", 3, 5.327)]  # foreigners not stored
    evf = [_evf("BORKOWSKA Halina", 3, 5.327)]      # EVF reports absolute pos
    r = check_parity(local, evf)
    assert r.placements_pass


# ===========================================================================
# Score (±0.5 tolerance)
# ===========================================================================


def test_score_within_tolerance_passes():
    """P4.PG.6: score diff exactly 0.5 → pass."""
    local = [_local("BORKOWSKA Halina", 3, 5.300)]
    evf = [_evf("BORKOWSKA Halina", 3, 5.800)]  # diff = 0.5
    r = check_parity(local, evf)
    assert r.score_pass


def test_score_outside_tolerance_fails():
    """P4.PG.7: score diff > 0.5 → fail."""
    local = [_local("BORKOWSKA Halina", 3, 5.000)]
    evf = [_evf("BORKOWSKA Halina", 3, 5.600)]  # diff = 0.6
    r = check_parity(local, evf)
    assert r.pol_count_pass
    assert r.placements_pass
    assert not r.score_pass
    assert any(d.sub_check == "score" for d in r.fail_details)


def test_score_diff_reported_in_detail():
    """P4.PG.8: score-fail detail records both values."""
    local = [_local("BORKOWSKA Halina", 3, 5.000)]
    evf = [_evf("BORKOWSKA Halina", 3, 5.600)]
    r = check_parity(local, evf)
    detail = next(d for d in r.fail_details if d.sub_check == "score")
    assert detail.expected == 5.6
    assert detail.actual == 5.0


# ===========================================================================
# Name normalization (case + diacritic folding)
# ===========================================================================


def test_name_match_case_insensitive():
    """P4.PG.9: case-insensitive fencer name matching."""
    local = [_local("BORKOWSKA Halina", 3, 5.327)]
    evf = [_evf("borkowska halina", 3, 5.327)]
    r = check_parity(local, evf)
    assert r.overall_pass


def test_name_match_diacritic_folding():
    """P4.PG.10: 'Łukasz' matches 'Lukasz' after fold."""
    local = [_local("ŻELAZKO Łukasz", 5, 2.0)]
    evf = [_evf("Zelazko Lukasz", 5, 2.0)]
    r = check_parity(local, evf)
    assert r.overall_pass


# ===========================================================================
# Multiple failures
# ===========================================================================


def test_multiple_failures_all_reported():
    """P4.PG.11: placement and score both fail → both in fail_details."""
    local = [_local("BORKOWSKA Halina", 3, 5.000)]
    evf = [_evf("BORKOWSKA Halina", 4, 6.000)]
    r = check_parity(local, evf)
    assert not r.placements_pass
    assert not r.score_pass
    sub_checks = {d.sub_check for d in r.fail_details}
    assert {"placement", "score"}.issubset(sub_checks)


# ===========================================================================
# Empty inputs
# ===========================================================================


def test_empty_inputs_pass_count_no_per_fencer_checks():
    """P4.PG.12: empty local + empty EVF → counts match (both 0); per-fencer checks vacuously pass."""
    r = check_parity([], [])
    assert r.pol_count_pass
    assert r.placements_pass
    assert r.score_pass
    assert r.overall_pass
