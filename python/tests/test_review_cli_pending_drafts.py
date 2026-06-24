"""
Plan-test-ID 5.16: review_cli._build_result_draft_rows includes PENDING method.

Bug history (2026-05-03 — caught during GP1 rescrape):
PENDING result rows were silently dropped from tbl_result_draft writes,
taking the result row with them. Operator had nothing to triage in the UI.

Symptom: GP1-2023-2024 verdict listed 6 ❌ wrong-match alias proposals
(POJMAŃSKA Katarzyna → SZMAJDZIŃSKA #278, BURLIKOWSKI Bartosz → KOWALSKI #147,
NIKOŁAJCZUK Aleksander × 2 → NIKALAICHUK #197, WOJTAS Bogdan × 2 → WOJTAS
Bogusław #312). All 6 result rows were absent from tbl_result_draft. Search
returned count=0 for every wrong-scraped name.

Root cause: review_cli.py:819-820:
    if m.method not in method_map:
        continue  # PENDING / EXCLUDED — not finalized, skip

method_map only contained AUTO_MATCHED / USER_CONFIRMED / AUTO_CREATED /
BY_ESTIMATED — so PENDING was filtered out, the result row never reached the
draft, the operator never saw it in the UI, and the data was permanently lost.

Fix: include PENDING with enum_match_method=NULL (the column is nullable),
preserving the matcher's best-guess id_fencer so the FencerAliasManager
cascade RPC has a fencer to split-from. EXCLUDED (international non-POL,
ADR-038) remains intentionally dropped — those aren't part of SPWS scoring.
"""

from __future__ import annotations

from datetime import date


def _make_ctx(vcat_groups: dict):
    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.types import Overrides, PipelineContext

    parsed = ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=[],
        parsed_date=date(2024, 1, 14),
        weapon="EPEE",
        gender="F",
        season_end_year=2024,
        source_url="https://example.test/x",
        category_hint="V2",
    )
    ctx = PipelineContext(
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=2024,
    )
    ctx.event = {"id_event": 5, "txt_code": "GP1-2023-2024"}
    ctx.vcat_groups = vcat_groups
    ctx.is_joint_pool = len(vcat_groups) >= 2
    return ctx


def _make_session():
    from unittest.mock import MagicMock

    from python.pipeline.review_cli import ReviewSession

    return ReviewSession(
        event_code="GP1-2023-2024",
        db=MagicMock(),
        draft_store=MagicMock(),
        prompt=lambda _msg: "q",
        fetcher=MagicMock(),
        season_end_year=2024,
    )


def test_5_16_1_pending_match_with_id_fencer_is_included_in_drafts():
    """5.16.1 — PENDING with id_fencer set lands in tbl_result_draft with
    enum_match_method=NULL. The matcher's best-guess id_fencer is preserved
    so the operator's split-from-alias cascade RPC has a target."""
    from python.pipeline.types import StageMatchResult

    pending = StageMatchResult(
        scraped_name="POJMAŃSKA Katarzyna",
        place=3,
        id_fencer=278,  # matcher's wrong guess (SZMAJDZIŃSKA)
        confidence=72.5,
        method="PENDING",
    )
    ctx = _make_ctx(vcat_groups={"V0": [pending]})
    session = _make_session()
    rows = session._build_result_draft_rows(
        ctx,
        vcat_to_tournament_id={"V0": 10},
    )
    assert len(rows) == 1, "PENDING row must NOT be dropped"
    r = rows[0]
    assert r["id_fencer"] == 278, "matcher's best-guess id_fencer preserved"
    assert r["txt_scraped_name"] == "POJMAŃSKA Katarzyna"
    assert r["int_place"] == 3
    assert r["num_match_confidence"] == 72.5
    assert r["enum_match_method"] is None, (
        "PENDING serialises to NULL so UI can filter on 'needs review'"
    )
    assert r["id_tournament_draft"] == 10


def test_5_16_2_excluded_remains_dropped():
    """5.16.2 — EXCLUDED (ADR-038 international non-POL row) is intentionally
    skipped — those rows are not part of SPWS scoring and should not appear
    in any draft."""
    from python.pipeline.types import StageMatchResult

    excluded = StageMatchResult(
        scraped_name="SMITH John",
        place=5,
        id_fencer=None,
        confidence=0.0,
        method="EXCLUDED",
    )
    ctx = _make_ctx(vcat_groups={"V2": [excluded]})
    session = _make_session()
    rows = session._build_result_draft_rows(
        ctx,
        vcat_to_tournament_id={"V2": 99},
    )
    assert rows == [], "EXCLUDED must remain dropped (ADR-038)"


def test_5_16_3_auto_matched_still_serialises_to_proper_enum():
    """5.16.3 — regression check: AUTO_MATCHED still maps to AUTO_MATCH
    (the migration's enum value), not None or PENDING."""
    from python.pipeline.types import StageMatchResult

    matched = StageMatchResult(
        scraped_name="GANSZCZYK Anna",
        place=1,
        id_fencer=70,
        confidence=99.0,
        method="AUTO_MATCHED",
    )
    ctx = _make_ctx(vcat_groups={"V2": [matched]})
    session = _make_session()
    rows = session._build_result_draft_rows(
        ctx,
        vcat_to_tournament_id={"V2": 10},
    )
    assert len(rows) == 1
    assert rows[0]["enum_match_method"] == "AUTO_MATCH"


def test_5_16_4_mixed_methods_in_one_group_all_kept_except_excluded():
    """5.16.4 — joint group containing AUTO_MATCHED + PENDING + EXCLUDED:
    AUTO_MATCHED + PENDING land in drafts (PENDING with method=NULL),
    EXCLUDED is dropped."""
    from python.pipeline.types import StageMatchResult

    matched = StageMatchResult(
        scraped_name="A",
        place=1,
        id_fencer=1,
        confidence=99.0,
        method="AUTO_MATCHED",
    )
    pending = StageMatchResult(
        scraped_name="B",
        place=2,
        id_fencer=2,
        confidence=70.0,
        method="PENDING",
    )
    excluded = StageMatchResult(
        scraped_name="C",
        place=3,
        id_fencer=None,
        confidence=0.0,
        method="EXCLUDED",
    )
    ctx = _make_ctx(vcat_groups={"V2": [matched, pending, excluded]})
    session = _make_session()
    rows = session._build_result_draft_rows(
        ctx,
        vcat_to_tournament_id={"V2": 10},
    )
    assert len(rows) == 2, "AUTO_MATCHED + PENDING kept, EXCLUDED dropped"
    methods = {r["enum_match_method"] for r in rows}
    assert methods == {"AUTO_MATCH", None}
    scraped = {r["txt_scraped_name"] for r in rows}
    assert scraped == {"A", "B"}
