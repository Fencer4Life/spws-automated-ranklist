"""
M4 Identity Resolution — Acceptance Tests.

Tests cover:
  4.1  Exact name match → AUTO_MATCHED with score ≥95
  4.2  Alias match → AUTO_MATCHED with score ≥95
  4.3  Uncertain match (score ~80) → PENDING candidate
  4.4  No match at all → UNMATCHED
  4.5  "SURNAME FirstName" format parsed correctly
  4.6  Admin approves PENDING → APPROVED, id_fencer linked
  4.7  Admin creates new fencer → NEW_FENCER
  4.8  Admin dismisses → DISMISSED
  4.9  International fencer not in tbl_fencer → no match candidate created

  Tournament-type-based intake rules:
  4.10–4.14  Domestic intake (PPW/MPW): all results enter ranklist
  4.15–4.18  International intake (PEW/MEW): only existing master data
  4.19–4.21  Birth year estimation from age category
  4.22–4.24  Auto-create fencer from scraped name

  Duplicate name disambiguation:
  4.25–4.31  Age-category tiebreaker for duplicate surname+first_name pairs
  4.32–4.35  birth_year_matches_category helper
  4.36–4.37  Duplicate names through pipeline
"""

from __future__ import annotations

import pytest

from python.matcher.fuzzy_match import (
    MatchResult,
    birth_year_matches_category,
    find_best_match,
    normalize_name,
    parse_scraped_name,
)
from python.matcher.pipeline import (
    approve_match,
    auto_create_fencer,
    create_new_fencer_from_match,
    dismiss_match,
    estimate_birth_year,
    resolve_results,
    resolve_tournament_results,
)


# ---------------------------------------------------------------------------
# Fencer master data fixtures (simulating tbl_fencer rows)
# ---------------------------------------------------------------------------
@pytest.fixture
def fencer_db():
    """Simulate tbl_fencer rows as list of dicts."""
    return [
        {
            "id_fencer": 1,
            "txt_surname": "BARAŃSKI",
            "txt_first_name": "Witold",
            "json_name_aliases": None,
        },
        {
            "id_fencer": 2,
            "txt_surname": "KOŃCZYŁO",
            "txt_first_name": "Tomasz",
            "json_name_aliases": ["TK"],
        },
        {
            "id_fencer": 3,
            "txt_surname": "KOWALSKI",
            "txt_first_name": "Jan",
            "json_name_aliases": None,
        },
        {
            "id_fencer": 4,
            "txt_surname": "NOWAK",
            "txt_first_name": "Piotr",
            "json_name_aliases": ["NOWAK P."],
        },
        {
            "id_fencer": 5,
            "txt_surname": "DĄBROWSKA-MANDRELA",
            "txt_first_name": "Maria",
            "json_name_aliases": None,
        },
    ]


# ---------------------------------------------------------------------------
# 4.1 Exact name match → AUTO_MATCHED with score ≥95
# ---------------------------------------------------------------------------
class TestExactMatch:
    def test_exact_match_returns_high_confidence(self, fencer_db):
        result = find_best_match("KOWALSKI Jan", fencer_db)
        assert result is not None
        assert result.id_fencer == 3
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_exact_match_case_insensitive(self, fencer_db):
        result = find_best_match("kowalski jan", fencer_db)
        assert result is not None
        assert result.id_fencer == 3
        assert result.confidence >= 95

    def test_exact_match_with_diacritics(self, fencer_db):
        result = find_best_match("BARAŃSKI Witold", fencer_db)
        assert result is not None
        assert result.id_fencer == 1
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"


# ---------------------------------------------------------------------------
# 4.2 Alias match → AUTO_MATCHED with score ≥95
# ---------------------------------------------------------------------------
class TestAliasMatch:
    def test_alias_exact_match(self, fencer_db):
        """TK is an alias for KOŃCZYŁO Tomasz."""
        result = find_best_match("TK", fencer_db)
        assert result is not None
        assert result.id_fencer == 2
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_alias_partial_name(self, fencer_db):
        """NOWAK P. is an alias for NOWAK Piotr."""
        result = find_best_match("NOWAK P.", fencer_db)
        assert result is not None
        assert result.id_fencer == 4
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"


# ---------------------------------------------------------------------------
# 4.3 Uncertain match → PENDING candidate
# ---------------------------------------------------------------------------
class TestUncertainMatch:
    def test_close_but_not_exact_is_pending(self, fencer_db):
        """A misspelled name should produce a PENDING match."""
        result = find_best_match("KOWALSKY Jan", fencer_db)
        assert result is not None
        assert result.id_fencer == 3
        assert 50 <= result.confidence < 95
        assert result.status == "PENDING"

    def test_surname_only_partial_match(self, fencer_db):
        """Surname matches but first name differs significantly."""
        result = find_best_match("BARAŃSKI Tomasz", fencer_db)
        assert result is not None
        assert result.status == "PENDING"
        assert result.confidence < 95


# ---------------------------------------------------------------------------
# 4.4 No match → UNMATCHED
# ---------------------------------------------------------------------------
class TestNoMatch:
    def test_completely_unknown_name(self, fencer_db):
        result = find_best_match("XYZ Unknown", fencer_db)
        assert result is not None
        assert result.id_fencer is None
        assert result.status == "UNMATCHED"

    def test_empty_fencer_db(self):
        result = find_best_match("KOWALSKI Jan", [])
        assert result is not None
        assert result.id_fencer is None
        assert result.status == "UNMATCHED"


# ---------------------------------------------------------------------------
# 4.5 Name format parsing
# ---------------------------------------------------------------------------
class TestNameParsing:
    def test_parse_surname_firstname(self):
        surname, first = parse_scraped_name("KOWALSKI Jan")
        assert surname == "KOWALSKI"
        assert first == "Jan"

    def test_parse_compound_surname(self):
        surname, first = parse_scraped_name("DĄBROWSKA-MANDRELA Maria")
        assert surname == "DĄBROWSKA-MANDRELA"
        assert first == "Maria"

    def test_parse_single_word(self):
        """Single word (like alias 'TK') → surname only."""
        surname, first = parse_scraped_name("TK")
        assert surname == "TK"
        assert first == ""

    def test_parse_multiple_first_names(self):
        """Handle names with multiple first names."""
        surname, first = parse_scraped_name("KOWALSKI Jan Maria")
        assert surname == "KOWALSKI"
        assert first == "Jan Maria"

    def test_normalize_strips_whitespace_and_lowercases(self):
        assert normalize_name("  KOWALSKI  Jan  ") == "kowalski jan"

    def test_compound_surname_match(self, fencer_db):
        result = find_best_match("DĄBROWSKA-MANDRELA Maria", fencer_db)
        assert result is not None
        assert result.id_fencer == 5
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"


# ---------------------------------------------------------------------------
# 4.6 Admin approves PENDING → APPROVED, id_fencer linked
# ---------------------------------------------------------------------------
class TestAdminApprove:
    def test_approve_sets_status_and_links_fencer(self):
        candidate = {
            "id_match": 10,
            "id_result": 100,
            "txt_scraped_name": "KOWALSKY Jan",
            "id_fencer": 3,
            "num_confidence": 85.0,
            "enum_status": "PENDING",
        }
        updated = approve_match(candidate, fencer_id=3)
        assert updated["enum_status"] == "APPROVED"
        assert updated["id_fencer"] == 3

    def test_approve_non_pending_raises(self):
        candidate = {
            "id_match": 10,
            "id_result": 100,
            "txt_scraped_name": "KOWALSKY Jan",
            "id_fencer": 3,
            "num_confidence": 85.0,
            "enum_status": "AUTO_MATCHED",
        }
        with pytest.raises(ValueError, match="Only PENDING"):
            approve_match(candidate, fencer_id=3)


# ---------------------------------------------------------------------------
# 4.7 Admin creates new fencer → NEW_FENCER
# ---------------------------------------------------------------------------
class TestAdminCreateNewFencer:
    def test_create_new_fencer_returns_new_fencer_status(self):
        candidate = {
            "id_match": 10,
            "id_result": 100,
            "txt_scraped_name": "SMITH John",
            "id_fencer": None,
            "num_confidence": 0,
            "enum_status": "UNMATCHED",
        }
        result = create_new_fencer_from_match(
            candidate,
            surname="SMITH",
            first_name="John",
        )
        assert result["enum_status"] == "NEW_FENCER"
        assert result["new_fencer"]["txt_surname"] == "SMITH"
        assert result["new_fencer"]["txt_first_name"] == "John"

    def test_create_new_fencer_from_pending(self):
        candidate = {
            "id_match": 10,
            "id_result": 100,
            "txt_scraped_name": "SMITH John",
            "id_fencer": 3,
            "num_confidence": 70.0,
            "enum_status": "PENDING",
        }
        result = create_new_fencer_from_match(
            candidate, surname="SMITH", first_name="John"
        )
        assert result["enum_status"] == "NEW_FENCER"


# ---------------------------------------------------------------------------
# 4.8 Admin dismisses → DISMISSED
# ---------------------------------------------------------------------------
class TestAdminDismiss:
    def test_dismiss_sets_status(self):
        candidate = {
            "id_match": 10,
            "id_result": 100,
            "txt_scraped_name": "SMITH John",
            "id_fencer": None,
            "num_confidence": 0,
            "enum_status": "PENDING",
        }
        updated = dismiss_match(candidate, note="Not a SPWS member")
        assert updated["enum_status"] == "DISMISSED"
        assert updated["txt_admin_note"] == "Not a SPWS member"


# ---------------------------------------------------------------------------
# 4.9 International fencer (not in tbl_fencer) → UNMATCHED
# ---------------------------------------------------------------------------
class TestInternationalFencer:
    def test_foreign_fencer_not_matched(self, fencer_db):
        """A fencer not in the master DB should be UNMATCHED."""
        result = find_best_match("MÜLLER Hans", fencer_db)
        assert result is not None
        assert result.id_fencer is None
        assert result.status == "UNMATCHED"


# ---------------------------------------------------------------------------
# resolve_results — legacy batch matching (backwards-compatible)
# ---------------------------------------------------------------------------
class TestResolveResults:
    def test_resolve_multiple_results(self, fencer_db):
        """Batch-resolve a list of scraped names."""
        scraped_names = [
            "KOWALSKI Jan",       # exact → AUTO_MATCHED
            "TK",                 # alias → AUTO_MATCHED
            "MÜLLER Hans",        # unknown → UNMATCHED
            "KOWALSKY Jan",       # close → PENDING
        ]
        matches = resolve_results(scraped_names, fencer_db)
        assert len(matches) == 4
        assert matches[0].status == "AUTO_MATCHED"
        assert matches[1].status == "AUTO_MATCHED"
        assert matches[2].status == "UNMATCHED"
        assert matches[3].status == "PENDING"

    def test_resolve_empty_list(self, fencer_db):
        matches = resolve_results([], fencer_db)
        assert matches == []


# ===========================================================================
# Tournament-type-based intake rules (new tests)
# ===========================================================================

# ---------------------------------------------------------------------------
# 4.10–4.14  Domestic intake (PPW/MPW): all results always enter ranklist
# ---------------------------------------------------------------------------
class TestDomesticIntake:
    def test_ppw_exact_match_in_matched_list(self, fencer_db):
        """4.10 PPW exact match → AUTO_MATCHED, in matched list."""
        resolved = resolve_tournament_results(
            ["KOWALSKI Jan"], fencer_db, "PPW", "V2", 2025
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].status == "AUTO_MATCHED"
        assert resolved.matched[0].id_fencer == 3
        assert len(resolved.auto_created) == 0
        assert len(resolved.skipped) == 0

    def test_ppw_pending_provisionally_linked(self, fencer_db):
        """4.11 PPW PENDING → provisionally linked, in matched list."""
        resolved = resolve_tournament_results(
            ["KOWALSKY Jan"], fencer_db, "PPW", "V2", 2025
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].status == "PENDING"
        assert resolved.matched[0].id_fencer == 3  # provisionally linked
        assert len(resolved.auto_created) == 0
        assert len(resolved.skipped) == 0

    def test_ppw_unmatched_auto_creates_fencer(self, fencer_db):
        """4.12 PPW UNMATCHED → auto_created list has new fencer."""
        resolved = resolve_tournament_results(
            ["MÜLLER Hans"], fencer_db, "PPW", "V2", 2025
        )
        assert len(resolved.auto_created) == 1
        assert resolved.auto_created[0]["txt_surname"] == "MÜLLER"
        assert resolved.auto_created[0]["txt_first_name"] == "Hans"
        # Also appears in matched list with NEW_FENCER status
        new_fencer_matches = [
            m for m in resolved.matched if m.status == "NEW_FENCER"
        ]
        assert len(new_fencer_matches) == 1
        assert len(resolved.skipped) == 0

    def test_ppw_auto_created_has_estimated_flag(self, fencer_db):
        """4.13 PPW auto-created fencer has bool_birth_year_estimated=True."""
        resolved = resolve_tournament_results(
            ["MÜLLER Hans"], fencer_db, "PPW", "V2", 2025
        )
        assert resolved.auto_created[0]["bool_birth_year_estimated"] is True

    def test_ppw_auto_created_birth_year_youngest_boundary(self, fencer_db):
        """4.14 PPW auto-created fencer birth_year uses youngest boundary."""
        resolved = resolve_tournament_results(
            ["MÜLLER Hans"], fencer_db, "PPW", "V2", 2025
        )
        # V2 in season ending 2025: youngest boundary = 2025 - 50 = 1975
        assert resolved.auto_created[0]["int_birth_year"] == 1975

    def test_mpw_unmatched_also_auto_creates(self, fencer_db):
        """4.14b MPW follows same rules as PPW (domestic)."""
        resolved = resolve_tournament_results(
            ["MÜLLER Hans"], fencer_db, "MPW", "V2", 2025
        )
        assert len(resolved.auto_created) == 1
        assert len(resolved.skipped) == 0


# ---------------------------------------------------------------------------
# 4.15–4.18  International intake (PEW/MEW): only existing master data
# ---------------------------------------------------------------------------
class TestInternationalIntake:
    def test_pew_exact_match_imported(self, fencer_db):
        """4.15 PEW exact match → AUTO_MATCHED, in matched list."""
        resolved = resolve_tournament_results(
            ["KOWALSKI Jan"], fencer_db, "PEW", "V2", 2025
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].status == "AUTO_MATCHED"
        assert len(resolved.auto_created) == 0
        assert len(resolved.skipped) == 0

    def test_pew_pending_provisionally_linked(self, fencer_db):
        """4.16 PEW PENDING → provisionally linked, in matched list."""
        resolved = resolve_tournament_results(
            ["KOWALSKY Jan"], fencer_db, "PEW", "V2", 2025
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].status == "PENDING"
        assert resolved.matched[0].id_fencer == 3

    def test_pew_unmatched_skipped(self, fencer_db):
        """4.17 PEW UNMATCHED → in skipped list, NOT in matched."""
        resolved = resolve_tournament_results(
            ["MÜLLER Hans"], fencer_db, "PEW", "V2", 2025
        )
        assert len(resolved.skipped) == 1
        assert resolved.skipped[0] == "MÜLLER Hans"
        assert len(resolved.matched) == 0
        assert len(resolved.auto_created) == 0

    def test_mew_unmatched_skipped(self, fencer_db):
        """4.18 MEW UNMATCHED → skipped (same as PEW)."""
        resolved = resolve_tournament_results(
            ["MÜLLER Hans"], fencer_db, "MEW", "V2", 2025
        )
        assert len(resolved.skipped) == 1
        assert len(resolved.matched) == 0


# ---------------------------------------------------------------------------
# 4.19–4.21  Birth year estimation from age category
# ---------------------------------------------------------------------------
class TestBirthYearEstimation:
    def test_v0_category(self):
        """4.19 V0 → season_end_year - 30."""
        assert estimate_birth_year("V0", 2025) == 1995

    def test_v2_category(self):
        """4.20 V2 → season_end_year - 50."""
        assert estimate_birth_year("V2", 2025) == 1975

    def test_v4_category(self):
        """4.21 V4 → season_end_year - 70."""
        assert estimate_birth_year("V4", 2025) == 1955

    def test_v1_category(self):
        """9.83 V1 → season_end_year - 40."""
        assert estimate_birth_year("V1", 2025) == 1985

    def test_v3_category(self):
        """9.84 V3 → season_end_year - 60."""
        assert estimate_birth_year("V3", 2025) == 1965

    def test_unknown_category_raises(self):
        """Unknown category raises ValueError."""
        with pytest.raises(ValueError, match="Unknown age category"):
            estimate_birth_year("V9", 2025)


# ---------------------------------------------------------------------------
# 4.22–4.24  Auto-create fencer from scraped name
# ---------------------------------------------------------------------------
class TestAutoCreateFencer:
    def test_parsed_name_fields(self):
        """4.22 Parsed name: 'SMITH John' → correct surname/first_name."""
        fencer = auto_create_fencer("SMITH John", "V2", 2025)
        assert fencer["txt_surname"] == "SMITH"
        assert fencer["txt_first_name"] == "John"

    def test_returns_all_required_fields(self):
        """4.23 Returns dict with all required tbl_fencer fields."""
        fencer = auto_create_fencer("SMITH John", "V2", 2025)
        assert "txt_surname" in fencer
        assert "txt_first_name" in fencer
        assert "int_birth_year" in fencer
        assert "bool_birth_year_estimated" in fencer

    def test_birth_year_estimated_flag(self):
        """4.24 bool_birth_year_estimated is True."""
        fencer = auto_create_fencer("SMITH John", "V2", 2025)
        assert fencer["bool_birth_year_estimated"] is True
        assert fencer["int_birth_year"] == 1975


# ===========================================================================
# Duplicate name disambiguation (age-category tiebreaker)
# ===========================================================================

@pytest.fixture
def fencer_db_with_duplicates():
    """Fencer DB including real duplicate pairs from SPWS master data."""
    return [
        {
            "id_fencer": 1,
            "txt_surname": "BARAŃSKI",
            "txt_first_name": "Witold",
            "int_birth_year": 1964,
            "json_name_aliases": None,
        },
        {
            "id_fencer": 2,
            "txt_surname": "KOŃCZYŁO",
            "txt_first_name": "Tomasz",
            "int_birth_year": 1973,
            "json_name_aliases": ["TK"],
        },
        # Duplicate pair: KRAWCZYK Paweł (1954 = V4, 1989 = V0 in season ending 2025)
        {
            "id_fencer": 6,
            "txt_surname": "KRAWCZYK",
            "txt_first_name": "Paweł",
            "int_birth_year": 1954,
            "json_name_aliases": None,
        },
        {
            "id_fencer": 7,
            "txt_surname": "KRAWCZYK",
            "txt_first_name": "Paweł",
            "int_birth_year": 1989,
            "json_name_aliases": None,
        },
        # Duplicate pair: MŁYNEK Janusz (1951 = V4, 1984 = V1 in season ending 2025)
        {
            "id_fencer": 8,
            "txt_surname": "MŁYNEK",
            "txt_first_name": "Janusz",
            "int_birth_year": 1951,
            "json_name_aliases": None,
        },
        {
            "id_fencer": 9,
            "txt_surname": "MŁYNEK",
            "txt_first_name": "Janusz",
            "int_birth_year": 1984,
            "json_name_aliases": None,
        },
        # Duplicate with NULL birth years (for edge case testing)
        {
            "id_fencer": 10,
            "txt_surname": "NOWAK",
            "txt_first_name": "Adam",
            "int_birth_year": None,
            "json_name_aliases": None,
        },
        {
            "id_fencer": 11,
            "txt_surname": "NOWAK",
            "txt_first_name": "Adam",
            "int_birth_year": None,
            "json_name_aliases": None,
        },
    ]


# ---------------------------------------------------------------------------
# 4.25–4.31  Age-category tiebreaker for duplicate names
# ---------------------------------------------------------------------------
class TestDuplicateNameDisambiguation:
    def test_krawczyk_v4_picks_older(self, fencer_db_with_duplicates):
        """4.25 KRAWCZYK Paweł in V4 (season end 2025) → picks born 1954 (age 71)."""
        result = find_best_match(
            "KRAWCZYK Paweł", fencer_db_with_duplicates, "V4", 2025
        )
        assert result.id_fencer == 6  # born 1954
        assert result.status == "AUTO_MATCHED"

    def test_krawczyk_v0_picks_younger(self, fencer_db_with_duplicates):
        """4.26 KRAWCZYK Paweł in V0 (season end 2025) → picks born 1989 (age 36)."""
        result = find_best_match(
            "KRAWCZYK Paweł", fencer_db_with_duplicates, "V0", 2025
        )
        assert result.id_fencer == 7  # born 1989
        assert result.status == "AUTO_MATCHED"

    def test_mlynek_v1_picks_younger(self, fencer_db_with_duplicates):
        """4.27 MŁYNEK Janusz in V1 (season end 2025) → picks born 1984 (age 41)."""
        result = find_best_match(
            "MŁYNEK Janusz", fencer_db_with_duplicates, "V1", 2025
        )
        assert result.id_fencer == 9  # born 1984
        assert result.status == "AUTO_MATCHED"

    def test_mlynek_v4_picks_older(self, fencer_db_with_duplicates):
        """4.28 MŁYNEK Janusz in V4 (season end 2025) → picks born 1951 (age 74)."""
        result = find_best_match(
            "MŁYNEK Janusz", fencer_db_with_duplicates, "V4", 2025
        )
        assert result.id_fencer == 8  # born 1951
        assert result.status == "AUTO_MATCHED"

    def test_duplicate_no_category_forces_pending(self, fencer_db_with_duplicates):
        """4.29 Duplicate with no age_category → PENDING (ambiguous)."""
        result = find_best_match(
            "KRAWCZYK Paweł", fencer_db_with_duplicates
        )
        assert result.status == "PENDING"
        assert result.confidence >= 95  # name match is still 100%

    def test_duplicate_neither_fits_category_forces_pending(self, fencer_db_with_duplicates):
        """4.30 Duplicate where neither fits category → PENDING."""
        # V2 (50-59): 1954 → age 71 (V4), 1989 → age 36 (V0). Neither fits V2.
        result = find_best_match(
            "KRAWCZYK Paweł", fencer_db_with_duplicates, "V2", 2025
        )
        assert result.status == "PENDING"

    def test_duplicate_both_null_birth_year_forces_pending(self, fencer_db_with_duplicates):
        """4.31 Duplicate where both have NULL birth_year → PENDING."""
        result = find_best_match(
            "NOWAK Adam", fencer_db_with_duplicates, "V2", 2025
        )
        assert result.status == "PENDING"


# ---------------------------------------------------------------------------
# 4.32–4.35  birth_year_matches_category helper
# ---------------------------------------------------------------------------
class TestBirthYearMatchesCategory:
    def test_age_55_in_v2(self):
        """4.32 Age 55 in V2 → True."""
        assert birth_year_matches_category(1969, "V2", 2025) is True

    def test_age_35_in_v2(self):
        """4.33 Age 35 in V2 → False."""
        assert birth_year_matches_category(1989, "V2", 2025) is False

    def test_age_75_in_v4(self):
        """4.34 Age 75 in V4 → True (no upper bound)."""
        assert birth_year_matches_category(1949, "V4", 2025) is True

    def test_null_birth_year(self):
        """4.35 NULL birth year → False."""
        assert birth_year_matches_category(None, "V2", 2025) is False


# ---------------------------------------------------------------------------
# 4.36–4.37  Duplicate names through pipeline
# ---------------------------------------------------------------------------
class TestDuplicateInPipeline:
    def test_ppw_duplicate_resolved_via_category(self, fencer_db_with_duplicates):
        """4.36 PPW tournament with duplicate name → correct fencer via category."""
        resolved = resolve_tournament_results(
            ["KRAWCZYK Paweł"], fencer_db_with_duplicates, "PPW", "V4", 2025
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].id_fencer == 6  # born 1954
        assert resolved.matched[0].status == "AUTO_MATCHED"

    def test_pew_duplicate_resolved_via_category(self, fencer_db_with_duplicates):
        """4.37 PEW tournament with duplicate name → correct fencer via category."""
        resolved = resolve_tournament_results(
            ["MŁYNEK Janusz"], fencer_db_with_duplicates, "PEW", "V1", 2025
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].id_fencer == 9  # born 1984
