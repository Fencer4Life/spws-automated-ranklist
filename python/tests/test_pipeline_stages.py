"""
Tests for python/pipeline/stages.py — Phase 3 (ADR-050) pipeline stages S1-S7.

Each stage tested in isolation with a hand-built PipelineContext + mock db.
Plus dispatcher tests for run_pipeline() in orchestrator.py.

Plan IDs P3.S1.x through P3.S7.x + P3.RP.x for run_pipeline.

Stage roster (from master plan):
  S1  IR validate
  S2  Resolve event by date+weapon+gender
  S3  Detect combined-pool from raw_age_marker
  S4  Split via fn_age_categories_batch
  S5  Detect joint-pool siblings by url_results
  S6  Resolve identity + alias writeback + V0/EVF check
  S7  Validate count + URL→data
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# Sentinel so explicit None can be distinguished from "use default" in fixture helper.
_DEFAULT = object()


def _make_parsed(
    results=None,
    parsed_date=_DEFAULT,
    weapon=_DEFAULT,
    gender=_DEFAULT,
    organizer_hint="SPWS",
    raw_pool_size=None,
    source_url="https://example.com/results",
    category_hint="V1",
):
    """Build a ParsedTournament for stage tests.

    Use _DEFAULT sentinel for parsed_date/weapon/gender so tests can pass
    None explicitly (to exercise S1's halt paths) without the helper
    silently substituting a default.
    """
    from python.pipeline.ir import ParsedTournament, SourceKind
    return ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=results or [],
        parsed_date=date(2026, 4, 1) if parsed_date is _DEFAULT else parsed_date,
        weapon="EPEE" if weapon is _DEFAULT else weapon,
        gender="M" if gender is _DEFAULT else gender,
        organizer_hint=organizer_hint,
        raw_pool_size=raw_pool_size,
        source_url=source_url,
        category_hint=category_hint,
        season_end_year=2026,
    )


def _make_result(name, place, birth_year=None, raw_age_marker=None, fencer_country="POL"):
    """Build a ParsedResult."""
    from python.pipeline.ir import ParsedResult
    return ParsedResult(
        source_row_id=f"test:{name}:{place}",
        fencer_name=name,
        place=place,
        birth_year=birth_year,
        fencer_country=fencer_country,
        raw_age_marker=raw_age_marker,
    )


def _make_ctx(parsed=None, overrides=None):
    """Build a PipelineContext for stage tests."""
    from python.pipeline.types import Overrides, PipelineContext
    return PipelineContext(
        parsed=parsed or _make_parsed(results=[_make_result("X", 1, birth_year=1970)]),
        overrides=overrides or Overrides(),
        season_end_year=2026,
    )


def _mock_db_with_event(event_dict):
    """Build a MagicMock db that returns event_dict from find_event_by_date."""
    db = MagicMock()
    db.find_event_by_date.return_value = event_dict
    return db


# ===========================================================================
# Dispatcher tests (run_pipeline)
# ===========================================================================

class TestRunPipeline:
    def test_calls_seven_stages_in_order(self, monkeypatch):
        """P3.RP.1 run_pipeline invokes S1→S7 in declared order."""
        from python.pipeline import stages
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import Overrides

        call_log = []
        for name in ["s1_validate_ir", "s2_resolve_event", "s3_detect_combined_pool",
                     "s4_split_via_batch", "s5_detect_joint_pool",
                     "s6_resolve_identity", "s7_validate"]:
            def make(n):
                def fn(ctx, db):
                    call_log.append(n)
                return fn
            monkeypatch.setattr(stages, name, make(name))

        run_pipeline(
            parsed=_make_parsed(results=[_make_result("X", 1, birth_year=1970)]),
            overrides=Overrides(),
            db=MagicMock(),
            season_end_year=2026,
        )
        assert call_log == ["s1_validate_ir", "s2_resolve_event", "s3_detect_combined_pool",
                            "s4_split_via_batch", "s5_detect_joint_pool",
                            "s6_resolve_identity", "s7_validate"]

    def test_halts_on_halterror(self, monkeypatch):
        """P3.RP.2 run_pipeline catches HaltError, populates halt fields, breaks loop."""
        from python.pipeline import stages
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import HaltError, HaltReason, Overrides

        call_log = []
        for name in ["s1_validate_ir", "s2_resolve_event", "s3_detect_combined_pool"]:
            def make(n):
                def fn(ctx, db):
                    call_log.append(n)
                return fn
            monkeypatch.setattr(stages, name, make(name))

        def boom(ctx, db):
            call_log.append("s4_boom")
            raise HaltError(HaltReason.SPLITTER_UNRESOLVED, "test halt")
        monkeypatch.setattr(stages, "s4_split_via_batch", boom)

        for name in ["s5_detect_joint_pool", "s6_resolve_identity", "s7_validate"]:
            def make(n):
                def fn(ctx, db):
                    call_log.append(n)
                return fn
            monkeypatch.setattr(stages, name, make(name))

        ctx = run_pipeline(
            parsed=_make_parsed(results=[_make_result("X", 1, birth_year=1970)]),
            overrides=Overrides(),
            db=MagicMock(),
            season_end_year=2026,
        )
        # S5/S6/S7 not called after halt
        assert call_log == ["s1_validate_ir", "s2_resolve_event", "s3_detect_combined_pool",
                            "s4_boom"]
        assert ctx.halted is True
        assert ctx.halted_at_stage == "s4_split_via_batch"
        assert ctx.halt_reason == HaltReason.SPLITTER_UNRESOLVED
        assert "test halt" in ctx.halt_detail

    def test_returns_ctx_unchanged_on_unexpected_exception(self, monkeypatch):
        """P3.RP.3 unexpected exception (not HaltError) propagates — bug, not halt."""
        from python.pipeline import stages
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import Overrides

        def crash(ctx, db):
            raise RuntimeError("oops")
        monkeypatch.setattr(stages, "s1_validate_ir", crash)

        with pytest.raises(RuntimeError, match="oops"):
            run_pipeline(
                parsed=_make_parsed(results=[_make_result("X", 1, birth_year=1970)]),
                overrides=Overrides(),
                db=MagicMock(),
                season_end_year=2026,
            )


# ===========================================================================
# S1 — IR validate
# ===========================================================================

class TestS1ValidateIR:
    def test_happy_path(self):
        """P3.S1.1 valid IR passes (no halt)."""
        from python.pipeline.stages import s1_validate_ir
        ctx = _make_ctx()
        s1_validate_ir(ctx, MagicMock())
        assert not ctx.halted

    def test_empty_results_halts(self):
        """P3.S1.2 empty results raises HaltError(IR_INVALID)."""
        from python.pipeline.stages import s1_validate_ir
        from python.pipeline.types import HaltError, HaltReason
        ctx = _make_ctx(parsed=_make_parsed(results=[]))
        with pytest.raises(HaltError) as exc:
            s1_validate_ir(ctx, MagicMock())
        assert exc.value.reason == HaltReason.IR_INVALID

    def test_missing_parsed_date_halts(self):
        """P3.S1.3 missing parsed_date raises HaltError(IR_INVALID)."""
        from python.pipeline.stages import s1_validate_ir
        from python.pipeline.types import HaltError, HaltReason
        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970)],
            parsed_date=None,
        ))
        with pytest.raises(HaltError) as exc:
            s1_validate_ir(ctx, MagicMock())
        assert exc.value.reason == HaltReason.IR_INVALID
        assert "parsed_date" in exc.value.detail

    def test_missing_weapon_halts(self):
        """P3.S1.4 missing weapon raises HaltError(IR_INVALID)."""
        from python.pipeline.stages import s1_validate_ir
        from python.pipeline.types import HaltError, HaltReason
        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970)],
            weapon=None,
        ))
        with pytest.raises(HaltError) as exc:
            s1_validate_ir(ctx, MagicMock())
        assert exc.value.reason == HaltReason.IR_INVALID
        assert "weapon" in exc.value.detail


# ===========================================================================
# S2 — Resolve event by date
# ===========================================================================

class TestS2ResolveEvent:
    def test_happy_path(self):
        """P3.S2.1 finds event for the parsed_date, populates ctx.event."""
        from python.pipeline.stages import s2_resolve_event
        ctx = _make_ctx()
        db = _mock_db_with_event({"id_event": 42, "txt_code": "PPW3-2025-2026", "txt_name": "..."})
        s2_resolve_event(ctx, db)
        assert ctx.event["id_event"] == 42
        db.find_event_by_date.assert_called_once_with("2026-04-01")

    def test_no_event_match_halts(self):
        """P3.S2.2 no event for date raises HaltError(EVENT_NOT_RESOLVED)."""
        from python.pipeline.stages import s2_resolve_event
        from python.pipeline.types import HaltError, HaltReason
        ctx = _make_ctx()
        db = _mock_db_with_event(None)
        with pytest.raises(HaltError) as exc:
            s2_resolve_event(ctx, db)
        assert exc.value.reason == HaltReason.EVENT_NOT_RESOLVED


# ===========================================================================
# S3 — Detect combined-pool
# ===========================================================================

class TestS3DetectCombinedPool:
    def test_combined_pool_detected_from_v0v1(self):
        """P3.S3.1 raw_age_marker 'v0v1' → ctx.is_combined_pool = True."""
        from python.pipeline.stages import s3_detect_combined_pool
        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970, raw_age_marker="v0v1")],
        ))
        s3_detect_combined_pool(ctx, MagicMock())
        assert ctx.is_combined_pool is True

    def test_single_cat_marker_not_combined(self):
        """P3.S3.2 single-cat marker ('v1') → ctx.is_combined_pool = False."""
        from python.pipeline.stages import s3_detect_combined_pool
        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970, raw_age_marker="v1")],
        ))
        s3_detect_combined_pool(ctx, MagicMock())
        assert ctx.is_combined_pool is False

    def test_no_markers_not_combined(self):
        """P3.S3.3 no raw_age_marker on any row → ctx.is_combined_pool = False."""
        from python.pipeline.stages import s3_detect_combined_pool
        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970)],  # no raw_age_marker
        ))
        s3_detect_combined_pool(ctx, MagicMock())
        assert ctx.is_combined_pool is False


# ===========================================================================
# S4 — Split via fn_age_categories_batch
# ===========================================================================

class TestS4SplitViaBatch:
    def test_no_op_when_not_combined(self):
        """P3.S4.1 single-cat (is_combined_pool=False) skips batch call."""
        from python.pipeline.stages import s4_split_via_batch
        ctx = _make_ctx()
        ctx.is_combined_pool = False
        db = MagicMock()
        s4_split_via_batch(ctx, db)
        db.call_age_categories_batch.assert_not_called()
        assert ctx.splits is None

    def test_batch_call_groups_by_vcat(self):
        """P3.S4.2 combined pool → ONE batch call → groups results by V-cat."""
        from python.pipeline.stages import s4_split_via_batch
        results = [
            _make_result("A", 1, birth_year=1965, raw_age_marker="v0v1"),
            _make_result("B", 2, birth_year=1985, raw_age_marker="v0v1"),
            _make_result("C", 3, birth_year=1965, raw_age_marker="v0v1"),
        ]
        ctx = _make_ctx(parsed=_make_parsed(results=results))
        ctx.is_combined_pool = True
        db = MagicMock()
        # 1965 = age 61 in 2026 = V3; 1985 = age 41 = V1
        db.call_age_categories_batch.return_value = {1965: "V3", 1985: "V1"}

        s4_split_via_batch(ctx, db)

        db.call_age_categories_batch.assert_called_once()
        assert sorted(ctx.splits.keys()) == ["V1", "V3"]
        assert len(ctx.splits["V3"]) == 2  # A and C
        assert len(ctx.splits["V1"]) == 1  # B

    def test_vcat_override_bypasses_batch(self):
        """P3.S4.3 vcat override skips batch lookup for that fencer."""
        from python.pipeline.stages import s4_split_via_batch
        from python.pipeline.types import Overrides, SplitterOverrides

        results = [
            _make_result("OVERRIDDEN", 1, birth_year=1985, raw_age_marker="v0v1"),
            _make_result("REGULAR", 2, birth_year=1965, raw_age_marker="v0v1"),
        ]
        ovr = Overrides(splitter=SplitterOverrides(vcat_overrides={"OVERRIDDEN": "V0"}))
        ctx = _make_ctx(parsed=_make_parsed(results=results), overrides=ovr)
        ctx.is_combined_pool = True
        db = MagicMock()
        db.call_age_categories_batch.return_value = {1965: "V3"}  # only REGULAR sent

        s4_split_via_batch(ctx, db)

        # Batch call only includes REGULAR's birth_year, not OVERRIDDEN's
        called_with = db.call_age_categories_batch.call_args[0][0]
        assert called_with == [1965]
        assert ctx.splits["V0"][0].fencer_name == "OVERRIDDEN"
        assert ctx.splits["V3"][0].fencer_name == "REGULAR"

    def test_birth_year_override_replaces_value(self):
        """P3.S4.4 birth_year override replaces the year before batch call."""
        from python.pipeline.stages import s4_split_via_batch
        from python.pipeline.types import Overrides, SplitterOverrides

        results = [_make_result("X", 1, birth_year=2050, raw_age_marker="v0v1")]
        ovr = Overrides(splitter=SplitterOverrides(birth_year_overrides={"X": 1965}))
        ctx = _make_ctx(parsed=_make_parsed(results=results), overrides=ovr)
        ctx.is_combined_pool = True
        db = MagicMock()
        db.call_age_categories_batch.return_value = {1965: "V3"}

        s4_split_via_batch(ctx, db)

        # Override value (1965) sent, not the row's value (2050)
        called_with = db.call_age_categories_batch.call_args[0][0]
        assert 1965 in called_with
        assert 2050 not in called_with

    def test_unresolved_birth_year_halts(self):
        """P3.S4.5 fencer with no birth_year and no override raises HaltError."""
        from python.pipeline.stages import s4_split_via_batch
        from python.pipeline.types import HaltError, HaltReason

        results = [_make_result("X", 1, birth_year=None, raw_age_marker="v0v1")]
        ctx = _make_ctx(parsed=_make_parsed(results=results))
        ctx.is_combined_pool = True
        db = MagicMock()

        with pytest.raises(HaltError) as exc:
            s4_split_via_batch(ctx, db)
        assert exc.value.reason == HaltReason.SPLITTER_UNRESOLVED


# ===========================================================================
# S5 — Detect joint-pool siblings (override-driven for Phase 3)
# ===========================================================================

class TestS5DetectJointPool:
    def test_no_overrides_empty_siblings(self):
        """P3.S5.1 no joint_pool overrides → empty siblings list."""
        from python.pipeline.stages import s5_detect_joint_pool
        ctx = _make_ctx()
        s5_detect_joint_pool(ctx, MagicMock())
        assert ctx.joint_pool_siblings == []

    def test_override_populates_siblings(self):
        """P3.S5.2 joint_pool override force-flag populates siblings + tournament_codes."""
        from python.pipeline.stages import s5_detect_joint_pool
        from python.pipeline.types import JointPoolOverride, Overrides

        ovr = Overrides(joint_pool=[
            JointPoolOverride(tournament_code="A-V0", siblings=["A-V1", "A-V2"]),
        ])
        ctx = _make_ctx(overrides=ovr)
        s5_detect_joint_pool(ctx, MagicMock())
        assert sorted(ctx.joint_pool_siblings) == ["A-V0", "A-V1", "A-V2"]


# ===========================================================================
# S6 — Resolve identity + V0/EVF check
# ===========================================================================

class TestS6ResolveIdentity:
    def test_v0_in_evf_event_halts(self):
        """P3.S6.1 V0 result in EVF event → HaltError(V0_PROHIBITED_ON_INTERNATIONAL)."""
        from python.pipeline.stages import s6_resolve_identity
        from python.pipeline.types import HaltError, HaltReason

        # Combined-pool with V0 split
        results = [_make_result("YOUNG", 1, birth_year=1990, raw_age_marker="v0v1")]
        ctx = _make_ctx(parsed=_make_parsed(results=results))
        ctx.event = {"id_event": 1, "txt_code": "PEW3-2025-2026"}  # PEW = EVF
        ctx.is_combined_pool = True
        ctx.splits = {"V0": [results[0]]}
        db = MagicMock()
        db.fetch_fencer_db.return_value = []

        with pytest.raises(HaltError) as exc:
            s6_resolve_identity(ctx, db)
        assert exc.value.reason == HaltReason.V0_PROHIBITED_ON_INTERNATIONAL

    def test_v0_in_domestic_event_does_not_halt(self):
        """P3.S6.2 V0 result in PPW (domestic) event proceeds (no halt)."""
        from python.pipeline.stages import s6_resolve_identity

        results = [_make_result("YOUNG", 1, birth_year=1990, raw_age_marker="v0v1")]
        ctx = _make_ctx(parsed=_make_parsed(results=results))
        ctx.event = {"id_event": 1, "txt_code": "PPW3-2025-2026"}  # PPW = SPWS domestic
        ctx.is_combined_pool = True
        ctx.splits = {"V0": [results[0]]}
        db = MagicMock()
        db.fetch_fencer_db.return_value = []

        s6_resolve_identity(ctx, db)
        # No halt, matches populated
        assert not ctx.halted
        assert len(ctx.matches) == 1

    def test_high_confidence_match_classified_auto_matched(self):
        """P3.S6.3 ≥95 confidence → AUTO_MATCHED."""
        from python.pipeline.stages import s6_resolve_identity

        results = [_make_result("KOWALSKI Jan", 1, birth_year=1970)]
        ctx = _make_ctx(parsed=_make_parsed(results=results))
        ctx.event = {"id_event": 1, "txt_code": "PPW3-2025-2026"}
        db = MagicMock()
        db.fetch_fencer_db.return_value = [
            {"id_fencer": 42, "txt_surname": "KOWALSKI", "txt_first_name": "Jan",
             "int_birth_year": 1970, "json_name_aliases": None},
        ]

        s6_resolve_identity(ctx, db)
        assert len(ctx.matches) == 1
        assert ctx.matches[0].method == "AUTO_MATCHED"
        assert ctx.matches[0].id_fencer == 42

    def test_identity_override_id_fencer_link(self):
        """P3.S6.4 identity override with id_fencer → AUTO_MATCHED, override id used."""
        from python.pipeline.stages import s6_resolve_identity
        from python.pipeline.types import IdentityOverride, Overrides

        results = [_make_result("AMBIGUOUS", 1, birth_year=1970)]
        ovr = Overrides(identity=[IdentityOverride(scraped_name="AMBIGUOUS", id_fencer=999)])
        ctx = _make_ctx(parsed=_make_parsed(results=results), overrides=ovr)
        ctx.event = {"id_event": 1, "txt_code": "PPW3-2025-2026"}
        db = MagicMock()
        db.fetch_fencer_db.return_value = []

        s6_resolve_identity(ctx, db)
        assert ctx.matches[0].id_fencer == 999
        assert ctx.matches[0].method == "AUTO_MATCHED"
        assert "override" in ctx.matches[0].notes.lower()

    def test_match_method_override_forces_classification(self):
        """P3.S6.5 match_method override forces method regardless of score."""
        from python.pipeline.stages import s6_resolve_identity
        from python.pipeline.types import MatchMethodOverride, Overrides

        results = [_make_result("KOWALSKI Jan", 1, birth_year=1970)]
        ovr = Overrides(match_method=[
            MatchMethodOverride(scraped_name="KOWALSKI Jan", force_method="PENDING",
                                note="manual review"),
        ])
        ctx = _make_ctx(parsed=_make_parsed(results=results), overrides=ovr)
        ctx.event = {"id_event": 1, "txt_code": "PPW3-2025-2026"}
        db = MagicMock()
        db.fetch_fencer_db.return_value = [
            {"id_fencer": 42, "txt_surname": "KOWALSKI", "txt_first_name": "Jan",
             "int_birth_year": 1970, "json_name_aliases": None},
        ]

        s6_resolve_identity(ctx, db)
        # Even though matcher would score ≥95, override forces PENDING
        assert ctx.matches[0].method == "PENDING"

    def test_unmatched_domestic_becomes_auto_created(self):
        """P3.S6.6 low-confidence + domestic event → AUTO_CREATED."""
        from python.pipeline.stages import s6_resolve_identity

        results = [_make_result("UNKNOWN PERSON XYZ", 1, birth_year=1970)]
        ctx = _make_ctx(parsed=_make_parsed(results=results))
        ctx.event = {"id_event": 1, "txt_code": "PPW3-2025-2026"}
        db = MagicMock()
        db.fetch_fencer_db.return_value = []  # nothing to match

        s6_resolve_identity(ctx, db)
        assert ctx.matches[0].method == "AUTO_CREATED"

    def test_unmatched_international_becomes_excluded(self):
        """P3.S6.7 low-confidence + international event → EXCLUDED."""
        from python.pipeline.stages import s6_resolve_identity

        # V1 fencer (40+) so no V0+EVF halt
        results = [_make_result("UNKNOWN PERSON XYZ", 1, birth_year=1970)]
        ctx = _make_ctx(parsed=_make_parsed(results=results, category_hint="V1"))
        ctx.event = {"id_event": 1, "txt_code": "PEW3-2025-2026"}  # PEW = EVF
        db = MagicMock()
        db.fetch_fencer_db.return_value = []

        s6_resolve_identity(ctx, db)
        assert ctx.matches[0].method == "EXCLUDED"


# ===========================================================================
# S7 — Validate count + URL
# ===========================================================================

class TestS7Validate:
    def test_count_match_passes(self):
        """P3.S7.1 raw_pool_size matches actual matches count → ok."""
        from python.pipeline.stages import s7_validate
        from python.pipeline.types import StageMatchResult

        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970)],
            raw_pool_size=1,
        ))
        ctx.matches = [
            StageMatchResult(scraped_name="X", place=1, id_fencer=1,
                             confidence=99.0, method="AUTO_MATCHED"),
        ]
        s7_validate(ctx, MagicMock())
        assert ctx.count_validation["ok"] is True

    def test_count_mismatch_halts(self):
        """P3.S7.2 large count mismatch → HaltError(COUNT_MISMATCH)."""
        from python.pipeline.stages import s7_validate
        from python.pipeline.types import HaltError, HaltReason, StageMatchResult

        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970)],
            raw_pool_size=10,  # claims 10
        ))
        ctx.matches = [  # but only 1 actual
            StageMatchResult(scraped_name="X", place=1, id_fencer=1,
                             confidence=99.0, method="AUTO_MATCHED"),
        ]
        with pytest.raises(HaltError) as exc:
            s7_validate(ctx, MagicMock())
        assert exc.value.reason == HaltReason.COUNT_MISMATCH

    def test_count_off_by_one_warns_not_halts(self):
        """P3.S7.3 off-by-one count diff → warning only, not halt."""
        from python.pipeline.stages import s7_validate
        from python.pipeline.types import StageMatchResult

        ctx = _make_ctx(parsed=_make_parsed(
            results=[_make_result("X", 1, birth_year=1970)],
            raw_pool_size=2,  # claims 2
        ))
        ctx.matches = [  # actual 1 (off by one)
            StageMatchResult(scraped_name="X", place=1, id_fencer=1,
                             confidence=99.0, method="AUTO_MATCHED"),
        ]
        s7_validate(ctx, MagicMock())
        assert ctx.count_validation["ok"] is True
        assert any("Count diff" in w for w in ctx.warnings)
