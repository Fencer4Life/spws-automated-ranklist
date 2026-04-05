"""
Tests for FencingTime XML parser.

Plan test IDs 9.116–9.128:
  9.116  Basic results: list[dict] with fencer_name, place, country
  9.117  Result count matches Tireur element count
  9.118  Places are valid (1..N, no gaps for single category)
  9.119  Fencer names are "SURNAME FirstName" format
  9.120  Enriched results include birth_date when available
  9.121  Enriched results: missing DOB → birth_date is None
  9.122  Metadata extraction: weapon, gender, date, title from root attrs
  9.123  detect_categories_from_altname single: "SZPADA MĘŻCZYZN v2" → ["V2"]
  9.124  detect_categories_from_altname combined: "SZPADA MĘŻCZYZN v0v1" → ["V0","V1"]
  9.125  detect_categories_from_altname all: "SZABLA KOBIET" → all 5
  9.126  Split combined results by birth year: 6 → 3+3, re-ranked
  9.127  Split missing DOB fallback: assigned to lowest category
  9.128  file_import.py dispatches .xml to XML parser
"""

from __future__ import annotations

from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"


def _load_fixture(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


class TestParseBasicResults:
    def test_parse_basic_results(self):
        """9.116 Returns list[dict] with fencer_name, place, country."""
        from scrapers.fencingtime_xml import parse_fencingtime_xml

        results = parse_fencingtime_xml(_load_fixture("single_category.xml"))
        assert isinstance(results, list)
        assert len(results) > 0
        for r in results:
            assert "fencer_name" in r
            assert "place" in r
            assert "country" in r
            assert isinstance(r["fencer_name"], str)
            assert isinstance(r["place"], int)
            assert isinstance(r["country"], str)

    def test_result_count_matches_tireurs(self):
        """9.117 Result count == number of Tireur elements (5 in fixture)."""
        from scrapers.fencingtime_xml import parse_fencingtime_xml

        results = parse_fencingtime_xml(_load_fixture("single_category.xml"))
        assert len(results) == 5

    def test_place_ordering(self):
        """9.118 Places are 1..N with no gaps for single category."""
        from scrapers.fencingtime_xml import parse_fencingtime_xml

        results = parse_fencingtime_xml(_load_fixture("single_category.xml"))
        places = sorted(r["place"] for r in results)
        assert places == [1, 2, 3, 4, 5]

    def test_fencer_name_format(self):
        """9.119 Names are 'SURNAME FirstName' format."""
        from scrapers.fencingtime_xml import parse_fencingtime_xml

        results = parse_fencingtime_xml(_load_fixture("single_category.xml"))
        # First result by place should be NOWAK Piotr (Classement=1)
        first = next(r for r in results if r["place"] == 1)
        assert first["fencer_name"] == "NOWAK Piotr"
        # Check one with Polish diacritics
        third = next(r for r in results if r["place"] == 2)
        assert third["fencer_name"] == "WIŚNIEWSKI Andrzej"


class TestEnrichedResults:
    def test_enriched_has_birth_date(self):
        """9.120 Enriched results include birth_date when available."""
        from scrapers.fencingtime_xml import parse_fencingtime_xml_enriched

        results = parse_fencingtime_xml_enriched(
            _load_fixture("single_category.xml")
        )
        # All 5 fencers in single_category.xml have DOB
        for r in results:
            assert "birth_date" in r
            assert r["birth_date"] is not None, (
                f"Expected birth_date for {r['fencer_name']}"
            )
        # Check specific date parsing (NOWAK Piotr: 22.07.1970)
        nowak = next(r for r in results if r["fencer_name"] == "NOWAK Piotr")
        assert nowak["birth_date"] == "1970-07-22"

    def test_enriched_missing_dob(self):
        """9.121 Missing DOB → birth_date is None."""
        from scrapers.fencingtime_xml import parse_fencingtime_xml_enriched

        results = parse_fencingtime_xml_enriched(_load_fixture("no_dob.xml"))
        for r in results:
            assert r["birth_date"] is None, (
                f"Expected None birth_date for {r['fencer_name']}, got {r['birth_date']}"
            )


class TestMetadata:
    def test_metadata_extraction(self):
        """9.122 Weapon, gender, date, title extracted from root attrs."""
        from scrapers.fencingtime_xml import parse_xml_metadata

        meta = parse_xml_metadata(_load_fixture("single_category.xml"))
        assert meta["weapon"] == "EPEE"
        assert meta["gender"] == "M"
        assert meta["date"] == "21.02.2026"
        assert "Gdańsk" in meta["title"]
        assert meta["alt_name"] == "SZPADA MĘŻCZYZN v2"
        assert meta["federation"] == "POL"


class TestCategoryDetection:
    def test_detect_categories_single(self):
        """9.123 'SZPADA MĘŻCZYZN v2' → ['V2']."""
        from scrapers.fencingtime_xml import detect_categories_from_altname

        cats = detect_categories_from_altname("SZPADA MĘŻCZYZN v2")
        assert cats == ["V2"]

    def test_detect_categories_combined(self):
        """9.124 'SZPADA MĘŻCZYZN v0v1' → ['V0', 'V1']."""
        from scrapers.fencingtime_xml import detect_categories_from_altname

        cats = detect_categories_from_altname("SZPADA MĘŻCZYZN v0v1")
        assert cats == ["V0", "V1"]

    def test_detect_categories_all(self):
        """9.125 'SZABLA KOBIET' (no vN suffix) → all 5 categories."""
        from scrapers.fencingtime_xml import detect_categories_from_altname

        cats = detect_categories_from_altname("SZABLA KOBIET")
        assert cats == ["V0", "V1", "V2", "V3", "V4"]


class TestCategorySplitting:
    def test_split_combined_by_birth_year(self):
        """9.126 6 fencers split into V0 (3) + V1 (3), re-ranked 1..3 each."""
        from python.scrapers.fencingtime_xml import (
            parse_fencingtime_xml_enriched,
            split_combined_results,
        )

        results = parse_fencingtime_xml_enriched(
            _load_fixture("combined_v0v1.xml")
        )
        # Fencer DB with birth years for the one missing DOB (NOWY Michał)
        fencer_db = [
            {
                "id_fencer": 99,
                "txt_surname": "NOWY",
                "txt_first_name": "Michał",
                "int_birth_year": 1993,  # V0 (age 33 in 2026)
                "json_name_aliases": [],
            },
        ]
        split_result = split_combined_results(
            results,
            categories=["V0", "V1"],
            fencer_db=fencer_db,
            season_end_year=2026,
        )
        assert "V0" in split_result.buckets
        assert "V1" in split_result.buckets
        assert len(split_result.buckets["V0"]) == 3
        assert len(split_result.buckets["V1"]) == 3
        # NOWY resolved via fencer_db → no unresolved
        assert len(split_result.unresolved) == 0
        # Check re-ranking: places should be 1, 2, 3 within each split
        v0_places = sorted(r["place"] for r in split_result.buckets["V0"])
        v1_places = sorted(r["place"] for r in split_result.buckets["V1"])
        assert v0_places == [1, 2, 3]
        assert v1_places == [1, 2, 3]

    def test_split_missing_dob_unresolved(self):
        """9.127 Fencer without DOB and not in fencer_db → in unresolved + lowest category (ADR-024)."""
        from python.scrapers.fencingtime_xml import (
            parse_fencingtime_xml_enriched,
            split_combined_results,
        )

        results = parse_fencingtime_xml_enriched(
            _load_fixture("combined_v0v1.xml")
        )
        # Empty fencer_db — NOWY Michał (no DOB) can't be resolved
        split_result = split_combined_results(
            results,
            categories=["V0", "V1"],
            fencer_db=[],
            season_end_year=2026,
        )
        # NOWY should be in unresolved
        unresolved_names = [r["fencer_name"] for r in split_result.unresolved]
        assert "NOWY Michał" in unresolved_names
        # But still assigned to V0 (lowest category) so data isn't lost
        v0_names = [r["fencer_name"] for r in split_result.buckets["V0"]]
        assert "NOWY Michał" in v0_names

    def test_split_unresolved_returns_correct_count(self):
        """9.194 split_combined_results returns unresolved for unknown DOB."""
        from python.scrapers.fencingtime_xml import (
            parse_fencingtime_xml_enriched,
            split_combined_results,
        )

        results = parse_fencingtime_xml_enriched(
            _load_fixture("combined_v0v1.xml")
        )
        split_result = split_combined_results(
            results,
            categories=["V0", "V1"],
            fencer_db=[],
            season_end_year=2026,
        )
        # Exactly 1 fencer has missing DOB in the fixture (NOWY Michał)
        assert len(split_result.unresolved) == 1
        assert split_result.unresolved[0]["fencer_name"] == "NOWY Michał"


class TestFileImportDispatch:
    def test_file_import_xml_dispatch(self):
        """9.128 parse_file(xml_bytes, 'results.xml') routes to XML parser."""
        from scrapers.file_import import parse_file

        xml_bytes = _load_fixture("single_category.xml")
        results = parse_file(xml_bytes, "results.xml")
        assert len(results) == 5
        assert all("fencer_name" in r for r in results)
        assert all("place" in r for r in results)
