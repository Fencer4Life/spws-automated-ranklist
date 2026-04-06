"""
Tests for EVF results PDF parser.

Plan test IDs evf.6–evf.10:
  evf.6   Extracts fencer list from fixture PDF
  evf.7   Rank, surname, first_name, country parsed correctly
  evf.8   Category code mapping (EHV2 → EPEE M V2)
  evf.9   Result format matches scraper contract
  evf.10  Handles empty/missing PDF gracefully
"""

from pathlib import Path

import pytest


FIXTURE_PDF = Path(__file__).parent / "fixtures" / "evf_result_ehv2.pdf"


class TestEvfResultsPdfParser:
    """Tests evf.6–evf.10: PDF result parsing."""

    def test_extracts_fencer_list(self):
        """evf.6: parse_evf_result_pdf returns non-empty list from fixture PDF."""
        from python.scrapers.evf_results import parse_evf_result_pdf

        pdf_bytes = FIXTURE_PDF.read_bytes()
        results = parse_evf_result_pdf(pdf_bytes)
        assert len(results) > 200  # 226 fencers in fixture, expect most parsed

    def test_rank_name_country_parsed(self):
        """evf.7: Each result has rank (int), fencer_name (str), country (3-letter code)."""
        from python.scrapers.evf_results import parse_evf_result_pdf

        pdf_bytes = FIXTURE_PDF.read_bytes()
        results = parse_evf_result_pdf(pdf_bytes)
        first = results[0]
        assert isinstance(first["place"], int)
        assert isinstance(first["fencer_name"], str)
        assert len(first["fencer_name"]) > 3
        assert isinstance(first["country"], str)
        assert len(first["country"]) == 3

    def test_category_code_mapping(self):
        """evf.8: EVF code EHV2 maps to EPEE M V2."""
        from python.scrapers.evf_results import evf_code_to_category

        weapon, gender, category = evf_code_to_category("EHV2")
        assert weapon == "EPEE"
        assert gender == "M"
        assert category == "V2"

        weapon, gender, category = evf_code_to_category("SDV3")
        assert weapon == "SABRE"
        assert gender == "F"
        assert category == "V3"

        weapon, gender, category = evf_code_to_category("FHV1")
        assert weapon == "FOIL"
        assert gender == "M"
        assert category == "V1"

    def test_result_format_matches_contract(self):
        """evf.9: Results match scraper contract: fencer_name, place, country keys."""
        from python.scrapers.evf_results import parse_evf_result_pdf

        pdf_bytes = FIXTURE_PDF.read_bytes()
        results = parse_evf_result_pdf(pdf_bytes)
        for r in results[:5]:
            assert "fencer_name" in r
            assert "place" in r
            assert "country" in r

    def test_handles_empty_pdf(self):
        """evf.10: Empty/invalid PDF returns empty list."""
        from python.scrapers.evf_results import parse_evf_result_pdf

        results = parse_evf_result_pdf(b"not a valid pdf")
        assert results == []
