"""
Tests for EVF results scraper (API + PDF fallback).

Plan test IDs evf.6–evf.10:
  evf.6   scrape_event_results returns fencer list for mocked event
  evf.7   Each result has fencer_name, place, country, weapon, gender, category
  evf.8   Category code mapping (EHV2 → EPEE M V2)
  evf.9   country_filter only returns matching fencers
  evf.10  parse_evf_result_pdf handles empty/invalid PDF gracefully
"""

from pathlib import Path
from unittest.mock import MagicMock

import pytest


FIXTURE_PDF = Path(__file__).parent / "fixtures" / "evf_result_ehv2.pdf"


def _mock_client():
    """Create a mock EvfApiClient that returns Naples-like data."""
    client = MagicMock()
    client.get_competitions.return_value = [
        {"id": 1216, "categoryId": 2, "weaponId": 2, "starts": "2026-03-07", "total": 79},
    ]
    client.get_results.return_value = [
        {
            "id": 62571, "competition_id": "1216", "place": "1",
            "fencer_surname": "LESNE", "fencer_firstname": "Ludovic",
            "fencer_dob": "1970-03-10", "country_abbr": "FRA",
            "weapon_abbr": "ME", "total_points": "158.618",
        },
        {
            "id": 62575, "competition_id": "1216", "place": "5",
            "fencer_surname": "KORONA", "fencer_firstname": "Przemyslaw",
            "fencer_dob": "1976-04-15", "country_abbr": "POL",
            "weapon_abbr": "ME", "total_points": "29.254",
        },
        {
            "id": 62599, "competition_id": "1216", "place": "58",
            "fencer_surname": "PARDUS", "fencer_firstname": "Borys",
            "fencer_dob": "1970-01-01", "country_abbr": "POL",
            "weapon_abbr": "ME", "total_points": "1.5",
        },
    ]
    return client


class TestEvfResultsApiScraper:
    """Tests evf.6–evf.9: API-based scraping."""

    def test_scrape_returns_fencer_list(self):
        """evf.6: scrape_event_results returns non-empty list."""
        from python.scrapers.evf_results import scrape_event_results

        results = scrape_event_results(85, client=_mock_client())
        assert len(results) == 3

    def test_result_fields(self):
        """evf.7: Each result has fencer_name, place, country, weapon, gender, category."""
        from python.scrapers.evf_results import scrape_event_results

        results = scrape_event_results(85, client=_mock_client())
        r = results[0]
        assert r["fencer_name"] == "LESNE Ludovic"
        assert r["place"] == 1
        assert r["country"] == "FRA"
        assert r["weapon"] == "EPEE"
        assert r["gender"] == "M"
        assert r["category"] == "V2"
        assert r["dob"] == "1970-03-10"
        assert r["evf_points"] == 158.618

    def test_category_code_mapping(self):
        """evf.8: EVF code EHV2 maps to EPEE M V2."""
        from python.scrapers.evf_results import evf_code_to_category

        assert evf_code_to_category("EHV2") == ("EPEE", "M", "V2")
        assert evf_code_to_category("SDV3") == ("SABRE", "F", "V3")
        assert evf_code_to_category("FHV1") == ("FOIL", "M", "V1")

    def test_country_filter(self):
        """evf.9: country_filter only returns matching fencers."""
        from python.scrapers.evf_results import scrape_event_results

        results = scrape_event_results(85, client=_mock_client(), country_filter="POL")
        assert len(results) == 2
        assert all(r["country"] == "POL" for r in results)

    def test_handles_empty_pdf(self):
        """evf.10: parse_evf_result_pdf returns empty list for invalid PDF."""
        from python.scrapers.evf_results import parse_evf_result_pdf

        results = parse_evf_result_pdf(b"not a valid pdf")
        assert results == []
