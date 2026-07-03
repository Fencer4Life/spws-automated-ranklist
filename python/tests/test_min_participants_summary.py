"""
Plan-test-ID 5.M7 (ADR-066): staging summary lists below-threshold brackets
in a dedicated 'Skipped — below min-participants threshold' section.

Operator-facing requirement: every bracket dropped by the gate must appear
in the per-event .md summary with bracket name, weapon, gender, V-cat, n,
threshold (in the reason string), and source URL — so the operator can
verify the threshold setting before sign-off.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class _FakeParsed:
    weapon: str = "FOIL"
    gender: str = "F"
    age_category: str | None = "V0"
    category_hint: str | None = "V0"
    source_url: str = "https://www.fencingtimelive.com/events/results/AAA"
    _ftl_source_name: str = "FLORET WETERANI kobiety 0"
    results: list | None = None
    tournament_name: str = ""

    def __post_init__(self):
        if self.results is None:
            self.results = []


def _minimal_event_meta() -> dict:
    return {
        "id_event": 99,
        "txt_code": "PPW2-2025-2026",
        "dt_start": "2025-10-25",
        "dt_end": "2025-10-26",
        "organizer_code": "SPWS",
        "txt_location": "Poznań",
        "urls": [],
        "_full_row": {"id_season": 3},
    }


def test_5_M7_1_below_min_section_rendered_when_brackets_skipped():
    """5.M7.1 — when ctxs contains a BELOW_MIN_PARTICIPANTS skip, the
    summary must include a dedicated section with the bracket details."""
    from python.tools.phase5_runner import _multi_summary_md

    parsed = _FakeParsed()
    ctxs = [
        (1, parsed, None, "BELOW_MIN_PARTICIPANTS (n=0, min=1)"),
    ]
    md = _multi_summary_md(
        event_code="PPW2-2025-2026",
        event_meta=_minimal_event_meta(),
        ctxs=ctxs,
        db=None,
    )
    assert "Skipped — below min-participants threshold" in md
    assert "FLORET WETERANI kobiety 0" in md
    assert "BELOW_MIN_PARTICIPANTS" in md
    assert "https://www.fencingtimelive.com/events/results/AAA" in md


def test_5_M7_2_section_omitted_when_no_brackets_skipped():
    """5.M7.2 — clean run produces no skipped-section header."""
    from python.tools.phase5_runner import _multi_summary_md

    md = _multi_summary_md(
        event_code="PPW2-2025-2026",
        event_meta=_minimal_event_meta(),
        ctxs=[],
        db=None,
    )
    assert "Skipped — below min-participants threshold" not in md


def test_5_M7_3_below_min_count_included_in_empty_tally():
    """5.M7.3 — Bracket parse status `⊘ empty` count includes BELOW_MIN
    skips (back-compat — they're still 'no fencers landed in the DB')."""
    from python.tools.phase5_runner import _multi_summary_md

    parsed = _FakeParsed()
    ctxs = [
        (1, parsed, None, "BELOW_MIN_PARTICIPANTS (n=0, min=1)"),
        (1, _FakeParsed(weapon="EPEE", _ftl_source_name="other"), None, "0 results"),
    ]
    md = _multi_summary_md(
        event_code="PPW2-2025-2026",
        event_meta=_minimal_event_meta(),
        ctxs=ctxs,
        db=None,
    )
    # Both should be tallied as 'empty'
    assert "⊘ empty: **2**" in md
