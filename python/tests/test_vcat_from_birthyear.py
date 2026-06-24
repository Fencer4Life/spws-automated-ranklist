"""ADR-056 — V-cat from birth year (post-match split).

Tests for python.pipeline.stages.s7_split_by_vcat and supporting helpers.

Phase 5 plan test IDs: 5.1 - 5.7
"""

from __future__ import annotations

import pytest

# ─────────────────────────────────────────────────────────────────────
# 5.1 vcat_for_age helper — boundary & bucket assignment
# ─────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "age,expected",
    [
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
    ],
)
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

    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.types import Overrides, PipelineContext

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
    db = _FakeBirthYearDb(
        {
            1: 1972,  # 52y → V2
            2: 1962,  # 62y → V3
            3: 1958,  # 66y → V3
        }
    )

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


# ─────────────────────────────────────────────────────────────────────
# 5.19 — ADR-056 revision: bracket-label V-cat overrides BY derivation
# ─────────────────────────────────────────────────────────────────────


def _make_ctx_with_category_hint(matches, *, category_hint, season_end_year=2024):
    """Build a PipelineContext where parsed.category_hint is set."""
    from datetime import date

    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.types import Overrides, PipelineContext

    parsed = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[],
        parsed_date=date(season_end_year - 1, 1, 14),
        weapon="SABRE",
        gender="M",
        category_hint=category_hint,
    )
    ctx = PipelineContext(
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=season_end_year,
    )
    ctx.matches = matches
    ctx.event = {"id_event": 1, "txt_code": "TEST"}
    return ctx


def test_s7_split_uses_category_hint_when_set_5_19_1():
    """5.19.1: Single-V-cat bracket label wins. ZAWROTNIAK (BY=1974, canonical V2
    in 2024) physically in V1 bracket → routed to V1, NOT V2.

    Per ADR-056 revision: when parsed.category_hint is a single V-cat string,
    every matched fencer goes to that V-cat regardless of BY-derived canonical."""
    from python.pipeline.stages import s7_split_by_vcat

    # Three V1-bracket fencers, two of whom are canonically V2 by BY+season_end
    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=322, scraped_name="ZAWROTNIAK"),
        _stub_match("AUTO_MATCHED", id_fencer=71, scraped_name="GANSZCZYK"),
        _stub_match("AUTO_MATCHED", id_fencer=152, scraped_name="KROCHMALSKI"),
    ]
    ctx = _make_ctx_with_category_hint(matches, category_hint="V1", season_end_year=2024)
    db = _FakeBirthYearDb(
        {
            322: 1974,  # canonical V2 (age 50 in 2024)
            71: 1974,  # canonical V2
            152: 1980,  # canonical V1
        }
    )

    s7_split_by_vcat(ctx, db)

    # All three stay in V1 — bracket label wins over canonical BY
    assert set(ctx.vcat_groups.keys()) == {"V1"}, (
        f"expected only V1 group, got {set(ctx.vcat_groups.keys())}"
    )
    assert len(ctx.vcat_groups["V1"]) == 3, (
        "all three V1-bracket fencers must stay in V1, no canonical override"
    )
    assert ctx.is_joint_pool is False


def test_s7_split_falls_back_to_by_when_category_hint_none_5_19_2():
    """5.19.2: Joint-pool bracket (category_hint=None) → BY-derivation per fencer."""
    from python.pipeline.stages import s7_split_by_vcat

    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("AUTO_MATCHED", id_fencer=2),
        _stub_match("AUTO_MATCHED", id_fencer=3),
    ]
    ctx = _make_ctx_with_category_hint(matches, category_hint=None, season_end_year=2024)
    db = _FakeBirthYearDb(
        {
            1: 1972,  # 52y → V2
            2: 1962,  # 62y → V3
            3: 1958,  # 66y → V3
        }
    )

    s7_split_by_vcat(ctx, db)

    # Joint-pool → BY-derived split into V2 + V3
    assert set(ctx.vcat_groups.keys()) == {"V2", "V3"}
    assert ctx.is_joint_pool is True


def test_s7_split_category_hint_with_unknown_by_5_19_2_b():
    """5.19.2b: Single-V-cat bracket + matched fencer with NULL BY → still routed
    to bracket V-cat (organizer placed them; we trust that)."""
    from python.pipeline.stages import s7_split_by_vcat

    matches = [
        _stub_match("AUTO_MATCHED", id_fencer=1),
        _stub_match("AUTO_MATCHED", id_fencer=2),
    ]
    ctx = _make_ctx_with_category_hint(matches, category_hint="V2", season_end_year=2024)
    db = _FakeBirthYearDb({1: 1972, 2: None})  # one BY-known, one BY-unknown

    s7_split_by_vcat(ctx, db)

    # BY-unknown still placed in V2 because bracket says so
    assert set(ctx.vcat_groups.keys()) == {"V2"}
    assert len(ctx.vcat_groups["V2"]) == 2
    assert len(ctx.unassigned_matches) == 0


def test_gp1_v2_sabre_m_regression_5_19_6():
    """5.19.6: Regression for GP1-2023-2024-V2-SABRE-M bug.

    Pre-revision behaviour: ZAWROTNIAK + GANSZCZYK (BY=1974, canonical V2 in
    2024) physically in V1-SABRE-M bracket got routed to V2-SABRE-M tournament,
    causing 10 rows in V2 (FTL URL has 8) and 6 rows in V1 (FTL URL has 7).

    Post-revision: V1 bracket label wins. All 7 V1 fencers stay in V1, V2
    bracket has its own 8 fencers, no cross-URL leakage."""
    from python.pipeline.stages import s7_split_by_vcat

    # Simulate the V1-SABRE-M bracket parse
    v1_matches = [
        _stub_match("AUTO_MATCHED", id_fencer=152, scraped_name="KROCHMALSKI"),
        _stub_match("AUTO_MATCHED", id_fencer=139, scraped_name="KOSIŃSKI"),
        _stub_match("AUTO_MATCHED", id_fencer=322, scraped_name="ZAWROTNIAK"),
        _stub_match("AUTO_MATCHED", id_fencer=71, scraped_name="GANSZCZYK"),
        _stub_match("AUTO_MATCHED", id_fencer=62, scraped_name="FRYDRYCH"),
        _stub_match("AUTO_MATCHED", id_fencer=283, scraped_name="SZYMAŃSKI"),
        _stub_match("AUTO_MATCHED", id_fencer=177, scraped_name="MARASEK"),
    ]
    ctx_v1 = _make_ctx_with_category_hint(v1_matches, category_hint="V1", season_end_year=2024)
    db_v1 = _FakeBirthYearDb(
        {
            152: 1980,
            139: 1981,  # canonical V1
            322: 1974,
            71: 1974,  # canonical V2 (BY=1974, age 50 in 2024)
            62: 1980,
            283: 1979,
            177: 1978,  # canonical V1
        }
    )

    s7_split_by_vcat(ctx_v1, db_v1)

    # All 7 V1-bracket fencers must stay in V1
    assert set(ctx_v1.vcat_groups.keys()) == {"V1"}, (
        "V1-bracket fencers must NOT cross-route to V2 by canonical BY"
    )
    assert len(ctx_v1.vcat_groups["V1"]) == 7
    assert ctx_v1.is_joint_pool is False

    # Simulate the V2-SABRE-M bracket parse (8 fencers, all canonical V2)
    v2_matches = [
        _stub_match("AUTO_MATCHED", id_fencer=68, scraped_name="GAJDA Leszek"),
        _stub_match("AUTO_MATCHED", id_fencer=113, scraped_name="KACZMAREK"),
        _stub_match("AUTO_MATCHED", id_fencer=201, scraped_name="NOWICKI"),
        _stub_match("AUTO_MATCHED", id_fencer=179, scraped_name="MAZIK"),
        _stub_match("AUTO_MATCHED", id_fencer=69, scraped_name="GAJDA Zbigniew"),
        _stub_match("AUTO_MATCHED", id_fencer=306, scraped_name="WINGROWICZ"),
        _stub_match("AUTO_MATCHED", id_fencer=106, scraped_name="JAROSZEK"),
        _stub_match("AUTO_MATCHED", id_fencer=305, scraped_name="WIERZBICKI"),
    ]
    ctx_v2 = _make_ctx_with_category_hint(v2_matches, category_hint="V2", season_end_year=2024)
    db_v2 = _FakeBirthYearDb(
        {
            68: 1965,
            113: 1970,
            201: 1974,
            179: 1970,
            69: 1967,
            306: 1973,
            106: 1972,
            305: 1970,
        }
    )

    s7_split_by_vcat(ctx_v2, db_v2)

    # All 8 V2-bracket fencers in V2 — no cross-URL leak
    assert set(ctx_v2.vcat_groups.keys()) == {"V2"}
    assert len(ctx_v2.vcat_groups["V2"]) == 8
    assert ctx_v2.is_joint_pool is False
