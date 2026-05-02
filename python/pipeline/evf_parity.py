"""
Phase 4 (ADR-053) — EVF parity gate logic.

Compares engine output (tbl_result rows) to EVF API published values for an
EVF-organized event. Three sub-checks:

    1. POL count match    — count(local) == count(evf)
    2. Placements match   — for each fencer, local int_place == evf Pos
    3. Score within ±0.5  — for each fencer, local num_final_score within
                            ±0.5 of EVF Points

On overall PASS the orchestrator promotes the event to EVF_PUBLISHED and
overwrites engine scores with EVF values. On FAIL the event stays
ENGINE_COMPUTED with txt_parity_notes populated.

Fencer matching is by case + diacritic-folded name. Per ADR-053 the score
tolerance is ±0.5 — half a displayable point — to absorb engine vs EVF
arithmetic rounding without false-failing.

Tests: python/tests/test_evf_parity.py.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass, field
from typing import Any, Iterable, Literal


SCORE_TOLERANCE = 0.5  # ADR-053: ±0.5 displayable half-point


# ---------------------------------------------------------------------------
# Public types
# ---------------------------------------------------------------------------


SubCheck = Literal["count", "placement", "score"]


@dataclass
class ParityFailDetail:
    """One per-fencer (or per-event) failure."""
    fencer_name: str
    sub_check: SubCheck
    expected: Any  # EVF value
    actual: Any    # local engine value
    message: str


@dataclass
class ParityResult:
    """Aggregate result of check_parity().

    Three booleans for the three sub-checks; overall_pass is the AND of all.
    fail_details lists every fencer-level failure (ADR-053 verbosity rule:
    no truncation in Telegram message).
    """
    pol_count_pass: bool = True
    placements_pass: bool = True
    score_pass: bool = True
    fail_details: list[ParityFailDetail] = field(default_factory=list)

    @property
    def overall_pass(self) -> bool:
        return self.pol_count_pass and self.placements_pass and self.score_pass


# ---------------------------------------------------------------------------
# Name normalization for cross-source matching
# ---------------------------------------------------------------------------


_POLISH_FOLD = str.maketrans({
    # Stroke / cedilla characters that NFKD doesn't decompose
    "Ą": "A", "Ć": "C", "Ę": "E", "Ł": "L", "Ń": "N",
    "Ó": "O", "Ś": "S", "Ź": "Z", "Ż": "Z",
    "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
    "ó": "o", "ś": "s", "ź": "z", "ż": "z",
})


def _fold(s: str | None) -> str:
    """Lower + ASCII-fold (incl. Polish strokes) + trim."""
    if not s:
        return ""
    s = s.translate(_POLISH_FOLD)
    nfkd = unicodedata.normalize("NFKD", s)
    no_marks = "".join(c for c in nfkd if not unicodedata.combining(c))
    return no_marks.strip().lower()


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def check_parity(
    local_results: Iterable[dict],
    evf_results: Iterable[dict],
) -> ParityResult:
    """Compare local engine output to EVF API published per-category values.

    Args:
        local_results: rows from `tbl_result` (POL only). Each must have:
            - `fencer_name` (str): for cross-source matching
            - `int_place`   (int): engine-output absolute place
            - `num_final_score` (float): engine-output score
        evf_results: rows from EVF API per-category page (POL only after R005
            POL filter). Each must have:
            - `name`  (str): fencer name
            - `pos`   (int): absolute placement in EVF field
            - `points` (float): EVF authoritative score

    Returns:
        ParityResult — three sub-check booleans + per-fencer failure detail.
    """
    local_list = list(local_results)
    evf_list = list(evf_results)
    result = ParityResult()

    # -------------------------------------------------------------------
    # Sub-check 1 — POL count
    # -------------------------------------------------------------------
    n_local = len(local_list)
    n_evf = len(evf_list)
    if n_local != n_evf:
        result.pol_count_pass = False
        result.fail_details.append(ParityFailDetail(
            fencer_name="<count>",
            sub_check="count",
            expected=n_evf,
            actual=n_local,
            message=f"POL count mismatch: local={n_local}, EVF={n_evf}",
        ))
        # Continue with sub-checks 2 & 3 against the intersection so operator
        # gets full diagnostic.

    # -------------------------------------------------------------------
    # Sub-checks 2 & 3 — per-fencer placements + scores (matched by name)
    # -------------------------------------------------------------------
    evf_by_name: dict[str, dict] = {_fold(r.get("name")): r for r in evf_list}

    for local in local_list:
        local_name = local.get("fencer_name", "")
        evf = evf_by_name.get(_fold(local_name))
        if evf is None:
            # Local fencer absent from EVF — counts as count failure already;
            # also flag at the placement layer for operator visibility.
            result.placements_pass = False
            result.fail_details.append(ParityFailDetail(
                fencer_name=local_name,
                sub_check="placement",
                expected="<missing from EVF>",
                actual=local.get("int_place"),
                message=f"Fencer {local_name!r} present locally but not in EVF response",
            ))
            continue

        # Placement
        local_place = local.get("int_place")
        evf_pos = evf.get("pos")
        if local_place != evf_pos:
            result.placements_pass = False
            result.fail_details.append(ParityFailDetail(
                fencer_name=local_name,
                sub_check="placement",
                expected=evf_pos,
                actual=local_place,
                message=f"{local_name}: local place={local_place} vs EVF Pos={evf_pos}",
            ))

        # Score (±0.5 tolerance)
        local_score = float(local.get("num_final_score", 0) or 0)
        evf_points = float(evf.get("points", 0) or 0)
        if abs(local_score - evf_points) > SCORE_TOLERANCE:
            result.score_pass = False
            result.fail_details.append(ParityFailDetail(
                fencer_name=local_name,
                sub_check="score",
                expected=evf_points,
                actual=local_score,
                message=(
                    f"{local_name}: engine={local_score:.3f} vs EVF={evf_points:.3f} "
                    f"(Δ {local_score - evf_points:+.3f}; tolerance ±{SCORE_TOLERANCE})"
                ),
            ))

    return result
