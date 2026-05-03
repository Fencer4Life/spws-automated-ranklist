"""
Plan-test-ID 5.18: review_cli._build_result_draft_rows populates
enum_source_age_category from parsed.category_hint.

Bug history (2026-05-03 — caught during GP3 triage):
The "Create new fencer from alias" modal pre-filled the BY field using
`latest_category_hint` from vw_fencer_aliases, which exposes the V-cat of
the *destination* tournament a row was placed in. For wrong-match rows,
stage 7 misroutes them to the wrong V-cat — the modal then suggested
the wrong year. The fix: persist the *source* V-cat (parsed.category_hint
at ingestion time) per row so the modal can pre-fill from the source,
not the misroute destination.

Joint-pool source brackets emit category_hint=None (V-cat unknown until
stage 7), so for those rows enum_source_age_category=None and the modal
falls back to "no hint" — operator must check the FTL page.
"""

from __future__ import annotations

from datetime import date


def _make_ctx(vcat_groups: dict, *, category_hint: str | None = "V2"):
    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.types import Overrides, PipelineContext

    parsed = ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=[], parsed_date=date(2024, 1, 14),
        weapon="EPEE", gender="F", season_end_year=2024,
        source_url="https://example.test/x", category_hint=category_hint,
    )
    ctx = PipelineContext(
        parsed=parsed, overrides=Overrides(), season_end_year=2024,
    )
    ctx.event = {"id_event": 5, "txt_code": "GP1-2023-2024"}
    ctx.vcat_groups = vcat_groups
    ctx.is_joint_pool = len(vcat_groups) >= 2
    return ctx


def _make_session():
    from python.pipeline.review_cli import ReviewSession
    from unittest.mock import MagicMock
    return ReviewSession(
        event_code="GP1-2023-2024",
        db=MagicMock(), draft_store=MagicMock(),
        prompt=lambda _msg: "q", fetcher=MagicMock(),
        season_end_year=2024,
    )


def test_5_18_1_single_vcat_source_persists_v2_on_every_row():
    """5.18.1 — Source bracket has category_hint=V2 → every row written
    must carry enum_source_age_category=V2, regardless of which V-cat
    bucket stage 7 placed the row in (matcher misroute scenario)."""
    from python.pipeline.types import StageMatchResult
    auto = StageMatchResult(
        scraped_name="GANSZCZYK Anna", place=1, id_fencer=70,
        confidence=99.0, method="AUTO_MATCHED",
    )
    pending_misroute = StageMatchResult(
        # Wrong-match: matcher gave V0 fencer, stage 7 placed in V0
        scraped_name="POJMAŃSKA Katarzyna", place=3,
        id_fencer=278, confidence=72.5, method="PENDING",
    )
    ctx = _make_ctx(
        vcat_groups={"V2": [auto], "V0": [pending_misroute]},
        category_hint="V2",  # source bracket was V2 (joint-pool wouldn't be)
    )
    session = _make_session()
    rows = session._build_result_draft_rows(
        ctx, vcat_to_tournament_id={"V2": 10, "V0": 11},
    )
    assert len(rows) == 2
    for r in rows:
        assert r["enum_source_age_category"] == "V2", (
            f"Source V-cat must be V2 from parsed.category_hint, "
            f"not {r['enum_source_age_category']} (the destination)"
        )


def test_5_18_2_joint_pool_source_persists_null():
    """5.18.2 — Joint-pool source bracket has category_hint=None
    (parser couldn't tell V-cat from FTL bracket name). Every row must
    carry enum_source_age_category=None — modal then shows no hint."""
    from python.pipeline.types import StageMatchResult
    a = StageMatchResult(
        scraped_name="A", place=1, id_fencer=1, confidence=99.0,
        method="AUTO_MATCHED",
    )
    b = StageMatchResult(
        scraped_name="B", place=2, id_fencer=2, confidence=99.0,
        method="AUTO_MATCHED",
    )
    ctx = _make_ctx(
        vcat_groups={"V2": [a], "V3": [b]},
        category_hint=None,  # joint-pool source: V-cat unknown
    )
    session = _make_session()
    rows = session._build_result_draft_rows(
        ctx, vcat_to_tournament_id={"V2": 10, "V3": 11},
    )
    assert len(rows) == 2
    for r in rows:
        assert r["enum_source_age_category"] is None, (
            "Joint-pool source must NOT leak destination V-cat into the "
            "source column"
        )


def test_5_18_3_pending_excluded_partition_unchanged():
    """5.18.3 — Adding source-V-cat capture must not regress 5.16's
    EXCLUDED-dropped / PENDING-included behaviour."""
    from python.pipeline.types import StageMatchResult
    auto = StageMatchResult(
        scraped_name="A", place=1, id_fencer=1, confidence=99.0,
        method="AUTO_MATCHED",
    )
    pending = StageMatchResult(
        scraped_name="B", place=2, id_fencer=2, confidence=70.0,
        method="PENDING",
    )
    excluded = StageMatchResult(
        scraped_name="C", place=3, id_fencer=None, confidence=0.0,
        method="EXCLUDED",
    )
    ctx = _make_ctx(
        vcat_groups={"V2": [auto, pending, excluded]},
        category_hint="V2",
    )
    session = _make_session()
    rows = session._build_result_draft_rows(
        ctx, vcat_to_tournament_id={"V2": 10},
    )
    # EXCLUDED still dropped, AUTO + PENDING still included
    assert len(rows) == 2
    methods = {r["enum_match_method"] for r in rows}
    assert methods == {"AUTO_MATCH", None}
    # All kept rows carry the source V-cat
    for r in rows:
        assert r["enum_source_age_category"] == "V2"
