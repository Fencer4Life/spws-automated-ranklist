"""
M4 Identity Resolution — Acceptance Tests (RED phase).

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
"""

from __future__ import annotations

import pytest

from python.matcher.fuzzy_match import (
    MatchResult,
    find_best_match,
    normalize_name,
    parse_scraped_name,
)
from python.matcher.pipeline import (
    approve_match,
    create_new_fencer_from_match,
    dismiss_match,
    resolve_results,
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
# resolve_results — batch matching for tournament results
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
