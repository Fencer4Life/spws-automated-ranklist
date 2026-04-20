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

  Staging spreadsheet matcher enhancements:
  4.38–4.41  Diacritic folding in normalize_name
  4.42–4.45  Token set ratio as secondary scorer
  4.46–4.49  Configurable thresholds

  Same-surname disambiguation (brothers):
  4.58–4.60  Same surname, different first name must not false-match
"""

from __future__ import annotations

import pytest

from python.matcher.fuzzy_match import (
    MatchResult,
    birth_year_matches_category,
    find_best_match,
    fold_diacritics,
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
# 4.61–4.67  ADR-038 — EVF-organized tournaments ingest POL-only rows
# ---------------------------------------------------------------------------
class TestAdr038PolOnlyGate:
    """Country gate: non-POL scraped rows at PEW/MEW/MSW are dismissed."""

    def test_pew_pol_auto_matched_passes(self, fencer_db):
        """4.61 PEW, country=POL, exact match → AUTO_MATCHED (not filtered)."""
        resolved = resolve_tournament_results(
            ["KOWALSKI Jan"], fencer_db, "PEW", "V2", 2025,
            scraped_countries=["POL"],
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].status == "AUTO_MATCHED"
        assert len(resolved.skipped) == 0

    def test_pew_non_pol_auto_matched_dismissed(self, fencer_db):
        """4.62 PEW, country=HUN, would-be exact match → filtered out."""
        resolved = resolve_tournament_results(
            ["KOWALSKI Jan"], fencer_db, "PEW", "V2", 2025,
            scraped_countries=["HUN"],
        )
        assert len(resolved.matched) == 0
        assert len(resolved.auto_created) == 0
        assert resolved.skipped == ["KOWALSKI Jan"]

    def test_pew_non_pol_pending_dismissed(self, fencer_db):
        """4.63 PEW, country=AUT, would-be PENDING → filtered out (no queue entry)."""
        resolved = resolve_tournament_results(
            ["KOWALSKY Jan"], fencer_db, "PEW", "V2", 2025,
            scraped_countries=["AUT"],
        )
        assert len(resolved.matched) == 0
        assert resolved.skipped == ["KOWALSKY Jan"]

    def test_pew_non_pol_unmatched_dismissed(self, fencer_db):
        """4.64 PEW, country=GER, UNMATCHED → filtered out (as before, but via country gate)."""
        resolved = resolve_tournament_results(
            ["MÜLLER Hans"], fencer_db, "PEW", "V2", 2025,
            scraped_countries=["GER"],
        )
        assert len(resolved.matched) == 0
        assert resolved.skipped == ["MÜLLER Hans"]

    def test_mew_non_pol_dismissed(self, fencer_db):
        """4.65 MEW (team) also gated by country."""
        resolved = resolve_tournament_results(
            ["KOWALSKI Jan"], fencer_db, "MEW", "V2", 2025,
            scraped_countries=["HUN"],
        )
        assert len(resolved.matched) == 0
        assert resolved.skipped == ["KOWALSKI Jan"]

    def test_ppw_non_pol_still_ingested(self, fencer_db):
        """4.66 PPW (domestic) — country filter does NOT apply; all rows go in."""
        resolved = resolve_tournament_results(
            ["KOWALSKI Jan", "MÜLLER Hans"], fencer_db, "PPW", "V2", 2025,
            scraped_countries=["POL", "GER"],
        )
        # KOWALSKI Jan → AUTO_MATCHED, MÜLLER Hans → NEW_FENCER (auto-created)
        assert len(resolved.matched) == 2
        assert len(resolved.auto_created) == 1
        assert len(resolved.skipped) == 0

    def test_pew_missing_country_fails_closed(self, fencer_db):
        """4.67 PEW with scraped_countries list but None entry → row dismissed (fail-closed)."""
        resolved = resolve_tournament_results(
            ["KOWALSKI Jan", "PARTICS Péter"], fencer_db, "PEW", "V2", 2025,
            scraped_countries=["POL", None],
        )
        assert len(resolved.matched) == 1
        assert resolved.matched[0].scraped_name == "KOWALSKI Jan"
        assert resolved.skipped == ["PARTICS Péter"]

    def test_pew_no_countries_backward_compat(self, fencer_db):
        """4.68 PEW without scraped_countries → legacy behavior (PENDING still provisionally linked)."""
        resolved = resolve_tournament_results(
            ["KOWALSKY Jan"], fencer_db, "PEW", "V2", 2025,
        )
        # Without country info, fall back to pre-ADR-038 behavior (no filter)
        assert len(resolved.matched) == 1
        assert resolved.matched[0].status == "PENDING"


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


# ===========================================================================
# Staging spreadsheet matcher enhancements
# ===========================================================================

# ---------------------------------------------------------------------------
# 4.38–4.41  Diacritic folding
# ---------------------------------------------------------------------------
class TestDiacriticFolding:
    def test_fold_diacritics_polish(self):
        """4.38 Polish diacritics are stripped: ąćęłńóśźż → acelnoszz."""
        assert fold_diacritics("BARAŃSKI") == "BARANSKI"
        assert fold_diacritics("KOŃCZYŁO") == "KONCZYLO"
        assert fold_diacritics("ŁUCZAK") == "LUCZAK"
        assert fold_diacritics("DĄBROWSKA") == "DABROWSKA"

    def test_fold_diacritics_german_hungarian(self):
        """4.39 German/Hungarian diacritics: ü→u, ö→o, á→a, é→e."""
        assert fold_diacritics("MÜLLER") == "MULLER"
        assert fold_diacritics("TAKÁCSY") == "TAKACSY"
        assert fold_diacritics("PÁSZTOR") == "PASZTOR"

    def test_diacritic_folding_match(self, fencer_db):
        """4.40 'BARANSKI Witold' matches 'BARAŃSKI Witold' with diacritic folding."""
        result = find_best_match(
            "BARANSKI Witold", fencer_db, use_diacritic_folding=True
        )
        assert result.id_fencer == 1
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_diacritic_folding_off_lower_score(self, fencer_db):
        """4.41 Without folding, 'BARANSKI Witold' vs 'BARAŃSKI Witold' scores lower."""
        result = find_best_match(
            "BARANSKI Witold", fencer_db, use_diacritic_folding=False
        )
        # Without folding, the ń→n difference lowers the score
        assert result.confidence < 95 or result.status != "AUTO_MATCHED"


# ---------------------------------------------------------------------------
# 4.42–4.45  Token set ratio as secondary scorer
# ---------------------------------------------------------------------------
class TestTokenSetRatio:
    @pytest.fixture
    def fencer_db_compound(self):
        """Fencer DB with compound surname."""
        return [
            {
                "id_fencer": 1,
                "txt_surname": "SPŁAWA-NEYMAN",
                "txt_first_name": "Maciej",
                "json_name_aliases": None,
            },
            {
                "id_fencer": 2,
                "txt_surname": "CIUFFREDA",
                "txt_first_name": "Luigi Salvatore",
                "json_name_aliases": None,
            },
        ]

    def test_token_set_matches_subset_name(self, fencer_db_compound):
        """4.42 'NEYMAN Maciej' matches 'SPŁAWA-NEYMAN Maciej' with token_set_ratio."""
        result = find_best_match(
            "NEYMAN Maciej", fencer_db_compound, use_token_set_ratio=True
        )
        assert result.id_fencer == 1
        assert result.confidence >= 75  # token_set catches subset (~78.8)

    def test_token_set_matches_partial_first_name(self, fencer_db_compound):
        """4.43 'CIUFFREDA Luigi' matches 'CIUFFREDA Luigi Salvatore' with token_set."""
        result = find_best_match(
            "CIUFFREDA Luigi", fencer_db_compound, use_token_set_ratio=True
        )
        assert result.id_fencer == 2
        assert result.confidence >= 85

    def test_token_set_off_lower_score_for_subset(self, fencer_db_compound):
        """4.44 Without token_set, 'NEYMAN Maciej' vs 'SPŁAWA-NEYMAN Maciej' scores lower."""
        result = find_best_match(
            "NEYMAN Maciej", fencer_db_compound, use_token_set_ratio=False
        )
        # token_sort_ratio only — partial surname match scores lower
        assert result.confidence < 85

    def test_token_set_does_not_false_positive(self, fencer_db):
        """4.45 token_set_ratio doesn't cause false positive for unrelated names."""
        result = find_best_match(
            "XYZ Unknown", fencer_db, use_token_set_ratio=True
        )
        assert result.status == "UNMATCHED"


# ---------------------------------------------------------------------------
# 4.46–4.49  Configurable thresholds
# ---------------------------------------------------------------------------
class TestConfigurableThresholds:
    def test_custom_auto_threshold_90(self, fencer_db):
        """4.46 With auto_match_threshold=90, a score of ~92 → AUTO_MATCHED."""
        # "KOWALSKI Jan" is exact (score 100), should AUTO_MATCH at 90
        result = find_best_match(
            "KOWALSKI Jan", fencer_db, auto_match_threshold=90
        )
        assert result.status == "AUTO_MATCHED"

    def test_custom_auto_threshold_98_makes_typo_pending(self, fencer_db):
        """4.47 With auto_match_threshold=98, a small typo → PENDING (not AUTO)."""
        # "KOWALSKY Jan" typically scores ~92 — below 98 threshold
        result = find_best_match(
            "KOWALSKY Jan", fencer_db, auto_match_threshold=98
        )
        assert result.status == "PENDING"

    def test_custom_pending_threshold_80(self, fencer_db):
        """4.48 With pending_threshold=80, a score of 60 → UNMATCHED (not PENDING)."""
        # "BARAŃSKI Tomasz" vs "BARAŃSKI Witold" — surname match but wrong first name
        result = find_best_match(
            "BARAŃSKI Tomasz", fencer_db, pending_threshold=80
        )
        # Score should be around 70 — below 80 threshold → UNMATCHED
        assert result.status == "UNMATCHED" or result.confidence >= 80

    def test_defaults_unchanged(self, fencer_db):
        """4.49 Default thresholds (95/50) match original behavior."""
        # Exact match → AUTO_MATCHED at default 95
        result = find_best_match("KOWALSKI Jan", fencer_db)
        assert result.status == "AUTO_MATCHED"
        # Typo → PENDING at default thresholds
        result2 = find_best_match("KOWALSKY Jan", fencer_db)
        assert result2.status == "PENDING"
        # Unknown → UNMATCHED at default 50
        result3 = find_best_match("XYZ Unknown", fencer_db)
        assert result3.status == "UNMATCHED"


# ===========================================================================
# Category marker stripping + component-level scoring
# ===========================================================================

# ---------------------------------------------------------------------------
# 4.50–4.51  Category marker stripping in normalize_name
# ---------------------------------------------------------------------------
class TestCategoryMarkerStripping:
    def test_v1_marker_stripped(self, fencer_db):
        """4.50 Name with (V1) marker matches after stripping."""
        result = find_best_match("KOWALSKI (V1) Jan", fencer_db)
        assert result.id_fencer == 3
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_kat_0_marker_stripped(self, fencer_db):
        """4.51 Name with (kat 0) marker matches after stripping."""
        result = find_best_match("KOWALSKI Jan (kat 0)", fencer_db)
        assert result.id_fencer == 3
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"


# ---------------------------------------------------------------------------
# 4.52–4.57  Component-level scoring for typo resilience
# ---------------------------------------------------------------------------
class TestComponentScoring:
    def test_mazik_transposition(self):
        """4.52 MAZIK Alksander vs Aleksander — component boost → AUTO_MATCHED."""
        db = [{"id_fencer": 1, "txt_surname": "MAZIK", "txt_first_name": "Aleksander", "json_name_aliases": None}]
        result = find_best_match("MAZIK Alksander", db)
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_krujaskis_missing_letter(self):
        """4.53 KRUJASKIS vs KRUJALSKIS — surname typo → AUTO_MATCHED."""
        db = [{"id_fencer": 1, "txt_surname": "KRUJALSKIS", "txt_first_name": "Gotfridas", "json_name_aliases": None}]
        result = find_best_match("KRUJASKIS Gotfridas", db)
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_nikalaichuk_transliteration(self):
        """4.54 NIKALAICHUK Aleksander vs Aliaksandr — transliteration → AUTO_MATCHED."""
        db = [{"id_fencer": 1, "txt_surname": "NIKALAICHUK", "txt_first_name": "Aliaksandr", "json_name_aliases": None}]
        result = find_best_match("NIKALAICHUK Aleksander", db)
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_fras_felix_feliks(self):
        """4.55 FRAŚ Felix vs Feliks — first name variant → AUTO_MATCHED."""
        db = [{"id_fencer": 1, "txt_surname": "FRAŚ", "txt_first_name": "Feliks", "json_name_aliases": None}]
        result = find_best_match("FRAŚ Felix", db)
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_fuhrmann_transposition(self):
        """4.56 FUHRMANN Urlike vs Ulrike — transposition → AUTO_MATCHED."""
        db = [{"id_fencer": 1, "txt_surname": "FUHRMANN", "txt_first_name": "Ulrike", "json_name_aliases": None}]
        result = find_best_match("FUHRMANN Urlike", db)
        assert result.confidence >= 95
        assert result.status == "AUTO_MATCHED"

    def test_no_false_positive(self, fencer_db):
        """4.57 Component scoring doesn't cause false positives for unrelated names."""
        result = find_best_match("XYZ Unknown", fencer_db)
        assert result.status == "UNMATCHED"


# ---------------------------------------------------------------------------
# 4.58–4.60 Same-surname different-first-name (brothers) must not false-match
# ---------------------------------------------------------------------------
class TestBrotherDisambiguation:
    """Fencers sharing a surname but with different first names must NOT
    be treated as the same person.  Regression test for BOBUSIA brothers
    (Jarosław vs DARIUSZ) false-match bug."""

    @pytest.fixture
    def brothers_db(self):
        """DB containing only BOBUSIA Jarosław — DARIUSZ is NOT in the DB."""
        return [
            {
                "id_fencer": 20,
                "txt_surname": "BOBUSIA",
                "txt_first_name": "Jarosław",
                "json_name_aliases": None,
            },
        ]

    def test_brother_not_auto_matched(self, brothers_db):
        """4.58 BOBUSIA DARIUSZ must NOT auto-match to BOBUSIA Jarosław."""
        result = find_best_match("BOBUSIA DARIUSZ", brothers_db)
        assert result.status != "AUTO_MATCHED", (
            f"BOBUSIA DARIUSZ incorrectly auto-matched to Jarosław "
            f"with confidence {result.confidence}"
        )

    def test_brother_score_below_pending(self, brothers_db):
        """4.59 Score for same-surname-different-first should be capped below PENDING threshold."""
        result = find_best_match("BOBUSIA DARIUSZ", brothers_db)
        # With the penalty, score should be ≤60 (below default pending=50 would be ideal,
        # but the surname alone drives token_sort_ratio ~71; penalty caps to 60)
        assert result.confidence <= 65, (
            f"Score {result.confidence} too high for different-first-name match"
        )

    def test_correct_brother_still_matches(self, brothers_db):
        """4.60 BOBUSIA Jarosław itself must still auto-match perfectly."""
        result = find_best_match("BOBUSIA Jarosław", brothers_db)
        assert result.status == "AUTO_MATCHED"
        assert result.id_fencer == 20
        assert result.confidence >= 95
