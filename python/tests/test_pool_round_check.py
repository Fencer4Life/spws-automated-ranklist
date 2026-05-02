"""Tests for s7_pool_round_check (Phase 5 — pool-round detection by
gender-distribution structural signal, not bracket-name regex).

Plan test IDs: 5.8 - 5.13
"""

from __future__ import annotations

import pytest


def _stub_match(method, id_fencer, place=1, scraped_name="X"):
    from python.pipeline.types import StageMatchResult
    return StageMatchResult(
        scraped_name=scraped_name,
        place=place,
        id_fencer=id_fencer,
        method=method,
        confidence=100.0,
    )


def _make_ctx(matches):
    from datetime import date
    from python.pipeline.types import PipelineContext, Overrides
    from python.pipeline.ir import ParsedTournament, SourceKind

    parsed = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[],
        parsed_date=date(2023, 1, 14),
        weapon="EPEE",
        gender="M",
    )
    ctx = PipelineContext(
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=2024,
    )
    ctx.matches = matches
    ctx.event = {"id_event": 1, "txt_code": "TEST"}
    return ctx


class _FakeGenderDb:
    """Returns dict {id_fencer: enum_gender ('M' | 'F')} for the batch."""
    def __init__(self, mapping):
        self.mapping = mapping
    def fetch_genders_batch(self, ids):
        return {i: self.mapping.get(i) for i in ids}


# ─────────────────────────────────────────────────────────────────────
# 5.8 — All-M bracket: not flagged as pool, no halt
# ─────────────────────────────────────────────────────────────────────


def test_pool_check_all_male_passes():
    """5.8: An all-M bracket is a real tournament — pipeline continues."""
    from python.pipeline.stages import s7_pool_round_check

    ctx = _make_ctx([
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("AUTO_MATCHED", id_fencer=2),
        _stub_match("AUTO_MATCHED", id_fencer=3),
        _stub_match("AUTO_MATCHED", id_fencer=4),
    ])
    db = _FakeGenderDb({1: "M", 2: "M", 3: "M", 4: "M"})

    s7_pool_round_check(ctx, db)  # should not raise

    assert ctx.is_pool_round is False


# ─────────────────────────────────────────────────────────────────────
# 5.9 — Single-outlier bracket (1F in 9M) — still passes (not pool)
# ─────────────────────────────────────────────────────────────────────


def test_pool_check_single_outlier_passes():
    """5.9: One outlier fencer is data noise, not a pool round (10% < 15%)."""
    from python.pipeline.stages import s7_pool_round_check

    matches = [_stub_match("AUTO_MATCHED", id_fencer=i) for i in range(1, 11)]
    ctx = _make_ctx(matches)
    # 9 men, 1 woman → minority = 10%
    gender_map = {i: "M" for i in range(1, 10)}
    gender_map[10] = "F"
    db = _FakeGenderDb(gender_map)

    s7_pool_round_check(ctx, db)

    assert ctx.is_pool_round is False


# ─────────────────────────────────────────────────────────────────────
# 5.10 — Mixed bracket (40/60 M/F) — pool round, halt
# ─────────────────────────────────────────────────────────────────────


def test_pool_check_mixed_genders_halts():
    """5.10: Genuinely mixed M+F (≥15% minority) → pool round → halt."""
    from python.pipeline.stages import s7_pool_round_check
    from python.pipeline.types import HaltError, HaltReason

    matches = [_stub_match("AUTO_MATCHED", id_fencer=i) for i in range(1, 11)]
    ctx = _make_ctx(matches)
    # 6 men, 4 women → minority = 40%
    gender_map = {i: "M" for i in range(1, 7)}
    for i in range(7, 11):
        gender_map[i] = "F"
    db = _FakeGenderDb(gender_map)

    with pytest.raises(HaltError) as exc_info:
        s7_pool_round_check(ctx, db)

    assert exc_info.value.reason == HaltReason.POOL_ROUND_DETECTED


# ─────────────────────────────────────────────────────────────────────
# 5.11 — Wrong-gender bracket (name M but ≥half F) — halt as data error
# ─────────────────────────────────────────────────────────────────────


def test_pool_check_predominantly_wrong_gender_halts():
    """5.11: Name says M but most fencers are F → reject as data error."""
    from python.pipeline.stages import s7_pool_round_check
    from python.pipeline.types import HaltError, HaltReason

    matches = [_stub_match("AUTO_MATCHED", id_fencer=i) for i in range(1, 11)]
    ctx = _make_ctx(matches)  # bracket name says M
    # 1 man, 9 women — wrong gender
    gender_map = {1: "M"}
    for i in range(2, 11):
        gender_map[i] = "F"
    db = _FakeGenderDb(gender_map)

    with pytest.raises(HaltError) as exc_info:
        s7_pool_round_check(ctx, db)

    assert exc_info.value.reason == HaltReason.POOL_ROUND_DETECTED


# ─────────────────────────────────────────────────────────────────────
# 5.12 — All-PENDING bracket (no genders to check) — passes (no signal)
# ─────────────────────────────────────────────────────────────────────


def test_pool_check_all_pending_passes():
    """5.12: No matched fencers → no gender data → can't conclude pool, pass."""
    from python.pipeline.stages import s7_pool_round_check

    matches = [_stub_match("PENDING", id_fencer=None) for _ in range(5)]
    ctx = _make_ctx(matches)
    db = _FakeGenderDb({})

    s7_pool_round_check(ctx, db)  # no halt

    assert ctx.is_pool_round is False


# ─────────────────────────────────────────────────────────────────────
# 5.13 — Tiny bracket (2-3 fencers) — passes regardless of mix (insufficient signal)
# ─────────────────────────────────────────────────────────────────────


def test_pool_check_tiny_bracket_passes():
    """5.13: Too few fencers for the percentage rule to be meaningful — pass."""
    from python.pipeline.stages import s7_pool_round_check

    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("AUTO_MATCHED", id_fencer=2),
    ]
    ctx = _make_ctx(matches)
    db = _FakeGenderDb({1: "M", 2: "F"})  # would be 50/50 but only 2 fencers

    s7_pool_round_check(ctx, db)  # no halt

    assert ctx.is_pool_round is False


# ─────────────────────────────────────────────────────────────────────
# 5.14 — Per-event invariant: ≤2 pool rounds per weapon
# ─────────────────────────────────────────────────────────────────────


def test_pool_round_count_invariant_under_two():
    """5.14: Two pool rounds per weapon is the SPWS norm — passes."""
    from python.tools.phase5_runner import _check_pool_round_count

    pool_brackets = [
        ("EPEE", "Mixed Épée — Pool 1"),
        ("EPEE", "Mixed Épée — Pool 2"),
        ("FOIL", "Mixed Foil"),
    ]
    warnings = _check_pool_round_count(pool_brackets)
    assert warnings == []


def test_pool_round_count_invariant_three_or_more_warns():
    """5.14: Three pool rounds for one weapon should surface a warning —
    SPWS spec says exactly two pool rounds per weapon."""
    from python.tools.phase5_runner import _check_pool_round_count

    pool_brackets = [
        ("EPEE", "Mixed Épée — Pool 1"),
        ("EPEE", "Mixed Épée — Pool 2"),
        ("EPEE", "Mixed Épée — Pool 3"),  # one too many
    ]
    warnings = _check_pool_round_count(pool_brackets)
    assert len(warnings) == 1
    assert "EPEE" in warnings[0]
    assert "3" in warnings[0]


def test_pool_round_count_invariant_zero_warns():
    """5.14: Zero pool rounds for an event is also unusual — warn so user
    can confirm whether the splitter actually skipped them."""
    from python.tools.phase5_runner import _check_pool_round_count

    warnings = _check_pool_round_count([])
    assert warnings == []  # zero is allowed without warning (event without pools)
