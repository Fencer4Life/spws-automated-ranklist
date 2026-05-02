"""ADR-056 — V-cat from birth year (post-match split).

Tests for python.pipeline.stages.s7_split_by_vcat and supporting helpers.

Phase 5 plan test IDs: 5.1 - 5.7
"""

from __future__ import annotations

import pytest


# ─────────────────────────────────────────────────────────────────────
# 5.1 vcat_for_age helper — boundary & bucket assignment
# ─────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("age,expected", [
    (0, "V0"),
    (39, "V0"),
    (40, "V1"),
    (49, "V1"),
    (50, "V2"),
    (59, "V2"),
    (60, "V3"),
    (69, "V3"),
    (70, "V4"),
    (99, "V4"),
])
def test_vcat_for_age_buckets(age, expected):
    """5.1: vcat_for_age maps each age to the correct V-cat bucket."""
    from python.pipeline.stages import vcat_for_age
    assert vcat_for_age(age) == expected


# ─────────────────────────────────────────────────────────────────────
# 5.2 vcat_for_age — None / negative ages
# ─────────────────────────────────────────────────────────────────────


def test_vcat_for_age_none_returns_none():
    """5.2: vcat_for_age(None) → None (cannot derive)."""
    from python.pipeline.stages import vcat_for_age
    assert vcat_for_age(None) is None


def test_vcat_for_age_negative_returns_none():
    """5.2: vcat_for_age(<0) → None (impossible age)."""
    from python.pipeline.stages import vcat_for_age
    assert vcat_for_age(-3) is None


# ─────────────────────────────────────────────────────────────────────
# 5.3 db.fetch_birth_years_batch returns mapping
# ─────────────────────────────────────────────────────────────────────


def test_fetch_birth_years_batch_returns_dict():
    """5.3: fetch_birth_years_batch([1,2,3]) → dict mapping id_fencer to int."""
    from python.pipeline.db_connector import DbConnector

    class FakeSb:
        class _Tbl:
            def select(self, _cols):
                return self
            def in_(self, _col, _ids):
                return self
            def execute(self):
                class _Resp:
                    data = [
                        {"id_fencer": 1, "int_birth_year": 1980},
                        {"id_fencer": 2, "int_birth_year": 1970},
                        {"id_fencer": 3, "int_birth_year": None},
                    ]
                return _Resp()
        def table(self, _name):
            return self._Tbl()

    db = DbConnector(FakeSb())
    out = db.fetch_birth_years_batch([1, 2, 3, 99])
    assert out == {1: 1980, 2: 1970, 3: None}


def test_fetch_birth_years_batch_empty_input():
    """5.3: fetch_birth_years_batch([]) → {} (no DB call needed)."""
    from python.pipeline.db_connector import DbConnector

    class FakeSb:
        def table(self, _):
            raise AssertionError("must not call DB on empty input")

    db = DbConnector(FakeSb())
    assert db.fetch_birth_years_batch([]) == {}


# ─────────────────────────────────────────────────────────────────────
# 5.4 s7_split_by_vcat — single V-cat → 1 group, joint=False
# ─────────────────────────────────────────────────────────────────────


def _stub_match(method, id_fencer, place=1, scraped_name="X"):
    from python.pipeline.types import StageMatchResult
    return StageMatchResult(
        scraped_name=scraped_name,
        place=place,
        id_fencer=id_fencer,
        method=method,
        confidence=100.0,
    )


def _make_ctx_with_matches(matches, *, season_end_year=2024):
    """Build a minimal PipelineContext with matches + season_end_year set.

    ADR-056: V-cat reference is season_end_year (age at end of season),
    matching fn_assert_result_vcat trigger convention.
    """
    from datetime import date
    from python.pipeline.types import PipelineContext, Overrides
    from python.pipeline.ir import ParsedTournament, SourceKind

    parsed = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[],
        parsed_date=date(season_end_year - 1, 1, 14),
        weapon="EPEE",
        gender="M",
    )
    ctx = PipelineContext(
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=season_end_year,
    )
    ctx.matches = matches
    ctx.event = {"id_event": 1, "txt_code": "TEST"}
    return ctx


class _FakeBirthYearDb:
    def __init__(self, mapping):
        self.mapping = mapping
    def fetch_birth_years_batch(self, ids):
        return {i: self.mapping.get(i) for i in ids}


def test_s7_split_single_vcat():
    """5.4: All matched fencers in one V-cat → single group, joint=False."""
    from python.pipeline.stages import s7_split_by_vcat

    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("AUTO_MATCHED", id_fencer=2),
        _stub_match("AUTO_MATCHED", id_fencer=3),
    ]
    ctx = _make_ctx_with_matches(matches)
    db = _FakeBirthYearDb({1: 1972, 2: 1971, 3: 1973})  # all V2 (50-59 in 2024)

    s7_split_by_vcat(ctx, db)

    assert set(ctx.vcat_groups.keys()) == {"V2"}
    assert ctx.is_joint_pool is False
    assert len(ctx.vcat_groups["V2"]) == 3


# ─────────────────────────────────────────────────────────────────────
# 5.5 s7_split_by_vcat — joint pool → multiple groups, joint=True
# ─────────────────────────────────────────────────────────────────────


def test_s7_split_joint_pool():
    """5.5: Matched fencers span ≥2 V-cats → multiple groups, joint=True."""
    from python.pipeline.stages import s7_split_by_vcat

    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("AUTO_MATCHED", id_fencer=2),
        _stub_match("AUTO_MATCHED", id_fencer=3),
    ]
    ctx = _make_ctx_with_matches(matches)
    db = _FakeBirthYearDb({
        1: 1972,  # 52y → V2
        2: 1962,  # 62y → V3
        3: 1958,  # 66y → V3
    })

    s7_split_by_vcat(ctx, db)

    assert set(ctx.vcat_groups.keys()) == {"V2", "V3"}
    assert ctx.is_joint_pool is True
    assert len(ctx.vcat_groups["V2"]) == 1
    assert len(ctx.vcat_groups["V3"]) == 2


# ─────────────────────────────────────────────────────────────────────
# 5.6 s7_split_by_vcat — unmatched rows carved out
# ─────────────────────────────────────────────────────────────────────


def test_s7_split_skips_unmatched_and_pending():
    """5.6: PENDING / UNMATCHED rows skipped — no V-cat assignment."""
    from python.pipeline.stages import s7_split_by_vcat

    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("PENDING", id_fencer=None),
        _stub_match("UNMATCHED", id_fencer=None),
    ]
    ctx = _make_ctx_with_matches(matches)
    db = _FakeBirthYearDb({1: 1972})  # V2

    s7_split_by_vcat(ctx, db)

    assert set(ctx.vcat_groups.keys()) == {"V2"}
    assert len(ctx.vcat_groups["V2"]) == 1
    assert ctx.is_joint_pool is False
    # The PENDING/UNMATCHED rows live on ctx.unassigned_matches for review
    assert len(ctx.unassigned_matches) == 2


# ─────────────────────────────────────────────────────────────────────
# 5.7 s7_split_by_vcat — null birth year carved out
# ─────────────────────────────────────────────────────────────────────


def test_s7_split_skips_null_birth_year():
    """5.7: Matched fencer with NULL int_birth_year → carved out."""
    from python.pipeline.stages import s7_split_by_vcat

    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("AUTO_MATCHED", id_fencer=2),
    ]
    ctx = _make_ctx_with_matches(matches)
    db = _FakeBirthYearDb({1: 1972, 2: None})  # one matched, one BY-unknown

    s7_split_by_vcat(ctx, db)

    assert set(ctx.vcat_groups.keys()) == {"V2"}
    assert len(ctx.vcat_groups["V2"]) == 1
    assert len(ctx.unassigned_matches) == 1
    assert ctx.unassigned_matches[0].id_fencer == 2
