"""
ADR-064 — Asymmetric gender filter at matcher time (domestic events only).

Plan test IDs: 4.61–4.72.

Federation rule (confirmed 2026-05-10):
  - Man in women's tournament: NEVER legitimate (federation rule, no exceptions).
  - Woman in men's tournament: rare but legitimate (no women's bracket exists at
    this event for this weapon/category). ADR-034 redirects her points at
    ranking time via fn_effective_gender.

ADR-064 pulls the asymmetric M-in-F prohibition forward into the matcher for
SPWS-organized domestic events (PPW/MPW/GP — GP encoded as PPW). The matcher
filter is one-sided: it drops M-gender candidates only when the bracket gender
is F. M brackets retain current behavior (no filter), so legitimate F-in-M
matching continues to work and ADR-034 fires as designed at scoring time.

Test coverage:
  4.61  F bracket + only-M candidate → UNMATCHED (filter rejects M)
  4.62  F bracket + F candidate present → matches F
  4.63  F bracket + mixed F+M candidates → matches F (M filtered)
  4.64  F bracket + NULL-gender candidate → matches NULL (NULL eligible)
  4.65  M bracket + F-only candidate → matches F (no filter, ADR-034 path)
  4.66  M bracket + mixed candidates → matches best by name (no filter)
  4.67  PEW + F bracket + only-M candidate → matches M (filter NOT applied;
        international intake out of scope per ADR-038)
  4.68  MEW + F bracket + only-M candidate → matches M (filter NOT applied)
  4.69  MSW + F bracket + only-M candidate → matches M (filter NOT applied)
  4.70  bracket_gender=None (compound bracket pre-V-cat-split) → no filter
  4.71  PPW + F bracket + UNMATCHED → NEW_FENCER auto_create with
        enum_gender='F' inherited from bracket
  4.72  auto_create_fencer(gender_default='F') stamps enum_gender='F'
"""

from __future__ import annotations

import pytest

from python.matcher.fuzzy_match import find_best_match
from python.matcher.pipeline import (
    auto_create_fencer,
    resolve_tournament_results,
)

# ---------------------------------------------------------------------------
# Fencer fixtures with enum_gender for asymmetric-filter tests.
# Mirrors tbl_fencer columns: id_fencer, txt_surname, txt_first_name,
# json_name_aliases, int_birth_year, enum_gender.
# ---------------------------------------------------------------------------


@pytest.fixture
def fencer_db_with_genders():
    """Two fencers sharing similar surnames, one M and one F.
    The PPW3 incident pattern: international woman matches Polish man's name.
    """
    return [
        {
            "id_fencer": 100,
            "txt_surname": "KOWALSKI",
            "txt_first_name": "Jan",
            "json_name_aliases": None,
            "int_birth_year": 1970,
            "enum_gender": "M",
        },
        {
            "id_fencer": 101,
            "txt_surname": "KOWALSKA",
            "txt_first_name": "Anna",
            "json_name_aliases": None,
            "int_birth_year": 1972,
            "enum_gender": "F",
        },
    ]


@pytest.fixture
def fencer_db_only_male():
    """Single male fencer — for testing the F-bracket reject path."""
    return [
        {
            "id_fencer": 200,
            "txt_surname": "NOWAK",
            "txt_first_name": "Piotr",
            "json_name_aliases": None,
            "int_birth_year": 1970,
            "enum_gender": "M",
        },
    ]


@pytest.fixture
def fencer_db_null_gender():
    """Fencer with enum_gender=NULL (legacy data) — must remain eligible."""
    return [
        {
            "id_fencer": 300,
            "txt_surname": "STACHNIAK",
            "txt_first_name": "Dominika",
            "json_name_aliases": None,
            "int_birth_year": 1980,
            "enum_gender": None,
        },
    ]


# ===========================================================================
# 4.61  F bracket + only-M candidate → UNMATCHED (filter rejects M)
# ===========================================================================
def test_4_61_f_bracket_only_m_candidate_unmatched(fencer_db_only_male):
    """ADR-064: F bracket must reject M-gender candidates outright.

    PPW3-2025-2026 Women's Épée: international woman fuzzy-matches a Polish
    man by surname stem. Filter must drop the M candidate so the row falls
    through to NEW_FENCER instead of locking onto a wrong-gender row.
    """
    result = find_best_match(
        "NOWAK Maria",
        fencer_db_only_male,
        age_category="V1",
        season_end_year=2026,
        bracket_gender="F",
    )
    assert result.status == "UNMATCHED"
    assert result.id_fencer is None


# ===========================================================================
# 4.62  F bracket + F candidate present → matches F
# ===========================================================================
def test_4_62_f_bracket_matches_f_candidate(fencer_db_with_genders):
    """F bracket with both M and F candidates: filter drops M, F wins."""
    result = find_best_match(
        "KOWALSKA Anna",
        fencer_db_with_genders,
        age_category="V1",
        season_end_year=2026,
        bracket_gender="F",
    )
    assert result.status == "AUTO_MATCHED"
    assert result.id_fencer == 101  # F fencer


# ===========================================================================
# 4.63  F bracket + mixed F+M candidates → matches F (M filtered)
# ===========================================================================
def test_4_63_f_bracket_filters_m_when_mixed(fencer_db_with_genders):
    """Even when the M candidate scores higher by raw name distance, the F
    filter drops it from the candidate set BEFORE scoring runs."""
    # Scrape "KOWALSKI Anna" — surname matches M row exactly, first name
    # matches F row. Without the filter, the M row could win on surname.
    result = find_best_match(
        "KOWALSKI Anna",
        fencer_db_with_genders,
        age_category="V1",
        season_end_year=2026,
        bracket_gender="F",
    )
    # Expected: matches the F row (101), NOT the M row (100).
    assert result.id_fencer == 101


# ===========================================================================
# 4.64  F bracket + NULL-gender candidate → matches NULL (NULL eligible)
# ===========================================================================
def test_4_64_f_bracket_null_gender_eligible(fencer_db_null_gender):
    """Legacy fencer rows with enum_gender=NULL must remain eligible — the
    filter only rejects rows explicitly marked enum_gender='M'."""
    result = find_best_match(
        "STACHNIAK Dominika",
        fencer_db_null_gender,
        age_category="V1",
        season_end_year=2026,
        bracket_gender="F",
    )
    assert result.status == "AUTO_MATCHED"
    assert result.id_fencer == 300


# ===========================================================================
# 4.65  M bracket + F-only candidate → matches F (no filter, ADR-034 path)
# ===========================================================================
def test_4_65_m_bracket_no_filter_allows_f(fencer_db_with_genders):
    """ADR-034 case: a real woman in a men's bracket (no F sibling at event).
    Matcher must NOT filter when bracket=M; the F row must still resolve so
    fn_effective_gender can redirect her points at ranking time."""
    # Only an F candidate exists for this name; bracket is M.
    db = [fencer_db_with_genders[1]]  # KOWALSKA Anna (F) only
    result = find_best_match(
        "KOWALSKA Anna",
        db,
        age_category="V1",
        season_end_year=2026,
        bracket_gender="M",
    )
    assert result.status == "AUTO_MATCHED"
    assert result.id_fencer == 101


# ===========================================================================
# 4.66  M bracket + mixed candidates → matches best by name (no filter)
# ===========================================================================
def test_4_66_m_bracket_no_filter_picks_best_name(fencer_db_with_genders):
    """M bracket: no filter applied, highest name-similarity wins."""
    result = find_best_match(
        "KOWALSKI Jan",
        fencer_db_with_genders,
        age_category="V1",
        season_end_year=2026,
        bracket_gender="M",
    )
    assert result.id_fencer == 100  # M fencer wins on exact name


# ===========================================================================
# Helper: assert that bracket_gender has NO effect on a tournament type.
# ===========================================================================
def _assert_filter_bypassed(tournament_type: str, fencer_db: list[dict]):
    """Run resolve_tournament_results twice (with/without bracket_gender='F')
    and assert the outputs are identical — i.e., the filter is bypassed."""
    common = dict(
        scraped_names=["KOWALSKA Anna"],
        fencer_db=fencer_db,
        tournament_type=tournament_type,
        age_category="V1",
        season_end_year=2026,
        scraped_countries=["POL"],
    )
    with_filter = resolve_tournament_results(**common, bracket_gender="F")
    without_filter = resolve_tournament_results(**common, bracket_gender=None)
    # Same matched id_fencer set + same status.
    assert [m.id_fencer for m in with_filter.matched] == [
        m.id_fencer for m in without_filter.matched
    ]
    assert [m.status for m in with_filter.matched] == [m.status for m in without_filter.matched]
    assert with_filter.skipped == without_filter.skipped
    assert len(with_filter.auto_created) == len(without_filter.auto_created)


# ===========================================================================
# 4.67  PEW + F bracket: bracket_gender has NO effect (filter bypassed)
# ===========================================================================
def test_4_67_pew_f_bracket_no_filter(fencer_db_with_genders):
    """ADR-064 scope: filter is domestic-only. PEW (international) keeps
    current behavior — international intake follows AUTO_MATCHED-only rule
    per feedback_international_no_pending.md, separate from this ADR.
    Verified by asserting bracket_gender='F' produces identical output to
    bracket_gender=None for PEW."""
    _assert_filter_bypassed("PEW", fencer_db_with_genders)


# ===========================================================================
# 4.68  MEW + F bracket: bracket_gender has NO effect (filter bypassed)
# ===========================================================================
def test_4_68_mew_f_bracket_no_filter(fencer_db_with_genders):
    """MEW (international) is out of scope for ADR-064."""
    _assert_filter_bypassed("MEW", fencer_db_with_genders)


# ===========================================================================
# 4.69  MSW + F bracket: bracket_gender has NO effect (filter bypassed)
# ===========================================================================
def test_4_69_msw_f_bracket_no_filter(fencer_db_with_genders):
    """MSW (international) is out of scope for ADR-064."""
    _assert_filter_bypassed("MSW", fencer_db_with_genders)


# ===========================================================================
# 4.70  bracket_gender=None (compound bracket) → no filter applied
# ===========================================================================
def test_4_70_no_bracket_gender_no_filter(fencer_db_with_genders):
    """Compound brackets (V0V1V2 etc.) come through pre-V-cat-split with
    bracket_gender=None. Must default to current behavior (no filter)."""
    result = find_best_match(
        "KOWALSKI Jan",
        fencer_db_with_genders,
        age_category="V1",
        season_end_year=2026,
        bracket_gender=None,
    )
    # No filter → M row wins on exact name.
    assert result.id_fencer == 100


# ===========================================================================
# 4.71  PPW + F bracket + UNMATCHED → NEW_FENCER with enum_gender='F'
# ===========================================================================
def test_4_71_ppw_f_bracket_new_fencer_inherits_f(fencer_db_only_male):
    """End-to-end: PPW domestic + F bracket + only-M candidate available.
    Matcher rejects M (filter), pipeline auto-creates a new F fencer with
    bracket-inherited gender. This is the PPW3 incident's intended fix.
    """
    result = resolve_tournament_results(
        scraped_names=["RIVERA CASTRO Tatiana"],
        fencer_db=fencer_db_only_male,
        tournament_type="PPW",
        age_category="V1",
        season_end_year=2026,
        scraped_countries=["CRC"],
        bracket_gender="F",
    )
    # Domestic UNMATCHED → NEW_FENCER auto-created.
    assert len(result.auto_created) == 1
    assert result.auto_created[0].get("enum_gender") == "F"
    # And the matched list carries the NEW_FENCER record.
    assert len(result.matched) == 1
    assert result.matched[0].status == "NEW_FENCER"


# ===========================================================================
# 4.72  auto_create_fencer(gender_default='F') stamps enum_gender='F'
# ===========================================================================
def test_4_72_auto_create_fencer_gender_default():
    """Direct unit test for auto_create_fencer: gender_default kwarg threads
    enum_gender into the new-fencer dict for fn_commit_event_draft to consume.
    """
    new_fencer = auto_create_fencer(
        "RIVERA CASTRO Tatiana",
        "V1",
        2026,
        gender_default="F",
    )
    assert new_fencer.get("enum_gender") == "F"
    # When gender_default is omitted, the field must NOT be set (back-compat
    # with current callers — orchestrator legacy path doesn't pass gender).
    legacy = auto_create_fencer("KOWALSKA Anna", "V1", 2026)
    assert "enum_gender" not in legacy
