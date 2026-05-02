"""
Phase 4 (ADR-052) — URL→data validation at Stage 7.

Tests for python/pipeline/url_validation.py. Plan IDs P4.UV.1 - P4.UV.18.

The validator compares scraped source metadata to the canonical event_row
opportunistically (only fields the scraper returned are checked). Six fields
halt on mismatch; one (name) warns. PEW events get a special exception for
weapon-mismatch (flag-for-rename instead of halt). Combined-pool sources
skip the age-category check.
"""

from __future__ import annotations

from datetime import date

import pytest

from pipeline.url_validation import (
    ScrapedMetadata,
    ValidationResult,
    validate_metadata,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _evt(**overrides):
    """Default event row (SPWS organizer); overrides applied on top."""
    base = {
        "txt_code": "PPW1-2025-2026",
        "txt_organizer_code": "SPWS",
        "dt_start": date(2026, 3, 29),
        "dt_end": None,
        "enum_weapon": "EPEE",
        "enum_gender": "M",
        "enum_age_category": "V2",
        "txt_city": "Warszawa",
        "txt_country": "POL",
        "txt_name": "Polish Veterans Cup 1",
    }
    base.update(overrides)
    return base


def _scr(**overrides):
    """Default scraped metadata (matches default event row)."""
    base = {
        "parsed_date": date(2026, 3, 29),
        "weapon": "EPEE",
        "gender": "M",
        "age_category": "V2",
        "is_combined_pool": False,
        "city": "Warszawa",
        "country": "POL",
        "tournament_name": "Polish Veterans Cup 1",
    }
    base.update(overrides)
    return ScrapedMetadata(**base)


# ===========================================================================
# Happy path
# ===========================================================================


def test_all_fields_match_no_halts():
    """P4.UV.1: full match across six halt fields produces no halt."""
    r = validate_metadata(_evt(), _scr())
    assert isinstance(r, ValidationResult)
    assert not r.has_halt
    assert r.halts == []


# ===========================================================================
# Date — halt on >1 day diff, tolerate ±1 day
# ===========================================================================


def test_date_exact_match_no_halt():
    """P4.UV.2: date exact match passes."""
    r = validate_metadata(_evt(), _scr(parsed_date=date(2026, 3, 29)))
    assert not r.has_halt


def test_date_one_day_diff_within_tolerance():
    """P4.UV.3: date off by one day (multi-day event end-date) tolerated."""
    r = validate_metadata(_evt(), _scr(parsed_date=date(2026, 3, 30)))
    assert not r.has_halt


def test_date_two_day_diff_halts():
    """P4.UV.4: date off by more than one day halts."""
    r = validate_metadata(_evt(), _scr(parsed_date=date(2026, 3, 31)))
    assert r.has_halt
    assert any(f.field == "date" for f in r.halts)


# ===========================================================================
# Weapon — halt for non-PEW; flag-for-rename for PEW (ADR-046)
# ===========================================================================


def test_weapon_mismatch_non_pew_halts():
    """P4.UV.5: weapon mismatch on non-PEW event halts."""
    r = validate_metadata(_evt(), _scr(weapon="FOIL"))
    assert r.has_halt
    assert any(f.field == "weapon" for f in r.halts)


def test_weapon_mismatch_pew_no_halt_sets_cascade_flag():
    """P4.UV.6: weapon mismatch on PEW event flags cascade pending, no halt."""
    pew_evt = _evt(txt_code="PEW3fs-2024-2025", enum_weapon="FOIL")  # event tracks foil + sabre
    r = validate_metadata(pew_evt, _scr(weapon="EPEE"))  # source brings epee — should be cascade
    assert not r.has_halt
    assert r.pew_cascade_pending


def test_weapon_match_pew_no_cascade_flag():
    """P4.UV.7: weapon match on PEW event does not flag cascade."""
    pew_evt = _evt(txt_code="PEW3fs-2024-2025", enum_weapon="FOIL")
    r = validate_metadata(pew_evt, _scr(weapon="FOIL"))
    assert not r.has_halt
    assert not r.pew_cascade_pending


# ===========================================================================
# Gender
# ===========================================================================


def test_gender_mismatch_halts():
    """P4.UV.8: gender mismatch halts."""
    r = validate_metadata(_evt(), _scr(gender="F"))
    assert r.has_halt
    assert any(f.field == "gender" for f in r.halts)


# ===========================================================================
# Age category — halt unless combined-pool source
# ===========================================================================


def test_age_category_match_no_halt():
    """P4.UV.9: age category match passes."""
    r = validate_metadata(_evt(), _scr(age_category="V2"))
    assert not r.has_halt


def test_age_category_mismatch_per_category_halts():
    """P4.UV.10: age category mismatch on per-category source halts."""
    r = validate_metadata(_evt(), _scr(age_category="V3", is_combined_pool=False))
    assert r.has_halt
    assert any(f.field == "age_category" for f in r.halts)


def test_age_category_mismatch_combined_pool_skips():
    """P4.UV.11: combined-pool source skips age-category check."""
    r = validate_metadata(_evt(), _scr(age_category=None, is_combined_pool=True))
    assert not r.has_halt


# ===========================================================================
# Country (ISO-3 normalization)
# ===========================================================================


def test_country_iso2_vs_iso3_match():
    """P4.UV.12: country PL (ISO-2) vs POL (ISO-3) → match after normalize."""
    r = validate_metadata(_evt(txt_country="POL"), _scr(country="PL"))
    assert not r.has_halt


def test_country_full_name_vs_iso3_match():
    """P4.UV.13: country 'Poland' vs 'POL' → match after normalize."""
    r = validate_metadata(_evt(txt_country="POL"), _scr(country="Poland"))
    assert not r.has_halt


def test_country_mismatch_halts():
    """P4.UV.14: country mismatch (POL vs HUN) halts."""
    r = validate_metadata(_evt(txt_country="POL"), _scr(country="HUN"))
    assert r.has_halt
    assert any(f.field == "country" for f in r.halts)


# ===========================================================================
# City (alias-table normalization)
# ===========================================================================


def test_city_alias_warsaw_warszawa_matches():
    """P4.UV.15: 'Warsaw' (English alias) matches 'Warszawa' (canonical)."""
    r = validate_metadata(_evt(txt_city="Warszawa"), _scr(city="Warsaw"))
    assert not r.has_halt


def test_city_diacritics_folded():
    """P4.UV.16: 'Krakow' (no diacritic) matches 'Kraków' (canonical)."""
    r = validate_metadata(_evt(txt_city="Kraków"), _scr(city="Krakow"))
    assert not r.has_halt


def test_city_mismatch_after_normalize_halts():
    """P4.UV.17: 'Budapest' vs 'Warszawa' halts (no alias match)."""
    r = validate_metadata(_evt(txt_city="Warszawa"), _scr(city="Budapest"))
    assert r.has_halt
    assert any(f.field == "city" for f in r.halts)


# ===========================================================================
# Name — warn only
# ===========================================================================


def test_name_mismatch_warn_only():
    """P4.UV.18: tournament name mismatch produces warn, not halt."""
    r = validate_metadata(_evt(txt_name="Polish Veterans Cup 1"),
                          _scr(tournament_name="Pol. Vets. Cup #1"))
    assert not r.has_halt
    assert any(f.field == "name" for f in r.warns)


# ===========================================================================
# Opportunistic — missing scraped fields skipped
# ===========================================================================


def test_missing_scraped_field_skipped():
    """P4.UV.19: vendor scraper without city/country fields produces no halt."""
    r = validate_metadata(_evt(), _scr(city=None, country=None, tournament_name=None))
    assert not r.has_halt


# ===========================================================================
# Multiple mismatches
# ===========================================================================


def test_multiple_mismatches_all_reported():
    """P4.UV.20: multiple field mismatches produce multiple halts."""
    r = validate_metadata(
        _evt(),
        _scr(weapon="FOIL", gender="F", country="HUN")
    )
    assert r.has_halt
    halt_fields = {f.field for f in r.halts}
    assert {"weapon", "gender", "country"}.issubset(halt_fields)
