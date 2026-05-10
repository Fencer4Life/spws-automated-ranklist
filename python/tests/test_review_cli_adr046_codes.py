"""
Plan-test-ID 5.M2: review_cli._draft_row_skeleton emits ADR-046-compliant
tournament codes.

Per ADR-046 (doc/adr/046-pew-weapon-suffix.md), the canonical child code is:

    {parent_kind}-V{age}-{gender}-{weapon}-{season}

where parent_kind is the event_code with the trailing -YYYY-YYYY stripped.

Bug (2026-05-10): the orchestrator emitted `{event_code}-V{age}-{weapon}-{gender}`,
which (a) put the season suffix mid-string instead of the end and (b) swapped
weapon/gender order. Combined with the seed file already holding old-shape
children for active-season PPW1-5, the new shape created duplicate child
tournaments under the same event_id (each with a different txt_code), which
surfaced as doubled fencer entries in the active-season drilldown.
"""

from __future__ import annotations

from datetime import date


def _session_with_event(event_code: str):
    from python.pipeline.review_cli import ReviewSession
    from unittest.mock import MagicMock

    return ReviewSession(
        event_code=event_code,
        db=MagicMock(),
        draft_store=MagicMock(),
        prompt=lambda _msg: "q",
        fetcher=MagicMock(),
        season_end_year=int(event_code[-4:]),
    )


def _ctx(event_id: int, weapon: str, gender: str):
    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.types import Overrides, PipelineContext

    parsed = ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=[],
        parsed_date=date(2025, 10, 25),
        weapon=weapon,
        gender=gender,
        season_end_year=2026,
        source_url="https://example.test/x",
        category_hint=None,
    )
    ctx = PipelineContext(
        parsed=parsed, overrides=Overrides(), season_end_year=2026,
    )
    ctx.event = {"id_event": event_id, "txt_code": "ignored"}
    return ctx


def test_5_M2_1_ppw_domestic_code_is_adr046_shape():
    """5.M2.1 — domestic PPW event_code='PPW2-2025-2026' with V1 EPEE F
    must emit txt_code='PPW2-V1-F-EPEE-2025-2026' (ADR-046 canonical)."""
    sess = _session_with_event("PPW2-2025-2026")
    ctx = _ctx(event_id=42, weapon="EPEE", gender="F")
    row = sess._draft_row_skeleton(ctx, 42, "V1")
    assert row["txt_code"] == "PPW2-V1-F-EPEE-2025-2026", (
        f"expected ADR-046 shape PPW2-V1-F-EPEE-2025-2026, got {row['txt_code']!r}"
    )


def test_5_M2_2_pew_letter_suffix_preserved_in_code():
    """5.M2.2 — PEW event_code with letter suffix 'PEW3fs-2024-2025'
    + V2 SABRE M must emit 'PEW3fs-V2-M-SABRE-2024-2025'. Confirms the
    parent-kind regex preserves the [efs]+ suffix per ADR-046."""
    sess = _session_with_event("PEW3fs-2024-2025")
    ctx = _ctx(event_id=11, weapon="SABRE", gender="M")
    row = sess._draft_row_skeleton(ctx, 11, "V2")
    assert row["txt_code"] == "PEW3fs-V2-M-SABRE-2024-2025", (
        f"expected PEW3fs-V2-M-SABRE-2024-2025, got {row['txt_code']!r}"
    )


def test_5_M2_3_mpw_no_suffix_handled():
    """5.M2.3 — MPW event_code without numeric suffix 'MPW-2024-2025'
    + V0 FOIL F must emit 'MPW-V0-F-FOIL-2024-2025'."""
    sess = _session_with_event("MPW-2024-2025")
    ctx = _ctx(event_id=7, weapon="FOIL", gender="F")
    row = sess._draft_row_skeleton(ctx, 7, "V0")
    assert row["txt_code"] == "MPW-V0-F-FOIL-2024-2025", (
        f"expected MPW-V0-F-FOIL-2024-2025, got {row['txt_code']!r}"
    )
