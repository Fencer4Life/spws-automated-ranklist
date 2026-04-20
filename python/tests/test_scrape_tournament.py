"""Tests for tournament URL scraping glue (ADR-029 §2.9).

Tests 3.17a–3.17d: scrape tournament results from url_results.
"""

from __future__ import annotations

import pytest
from pathlib import Path
from unittest.mock import MagicMock, patch

FIXTURES = Path(__file__).parent / "fixtures"


class TestScrapeTournament:
    """Test the scrape-from-URL glue logic."""

    def test_ftl_url_scraped_and_parsed(self):
        """3.17a: FTL url_results → fetched → parsed into results list."""
        from python.tools.scrape_tournament import scrape_and_parse

        # FTL JSON fixture
        ftl_json = (FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json").read_text()

        with patch("python.tools.scrape_tournament.httpx") as mock_httpx:
            mock_resp = MagicMock()
            mock_resp.status_code = 200
            mock_resp.json.return_value = __import__("json").loads(ftl_json)
            mock_resp.text = ftl_json
            mock_httpx.get.return_value = mock_resp

            results = scrape_and_parse(
                "https://www.fencingtimelive.com/events/results/EEC7379682834E588E5B267447C7266A"
            )
            assert len(results) > 0
            assert "fencer_name" in results[0]
            assert "place" in results[0]

    def test_engarde_url_scraped_and_parsed(self):
        """3.17b: Engarde url_results → fetched → parsed into results list."""
        from python.tools.scrape_tournament import scrape_and_parse

        engarde_html = (FIXTURES / "engarde" / "clasfinal_hunfencing.html").read_text()

        with patch("python.tools.scrape_tournament.httpx") as mock_httpx:
            mock_resp = MagicMock()
            mock_resp.status_code = 200
            mock_resp.text = engarde_html
            mock_httpx.get.return_value = mock_resp

            results = scrape_and_parse(
                "https://engarde-service.com/competition/hunfencing/2025_09_20_pbt/em-2/clasfinal.htm"
            )
            assert len(results) > 0
            assert "fencer_name" in results[0]
            assert "place" in results[0]

    def test_missing_url_raises(self):
        """3.17c: Empty or None url_results raises ValueError."""
        from python.tools.scrape_tournament import scrape_and_parse

        with pytest.raises(ValueError, match="No URL"):
            scrape_and_parse("")

        with pytest.raises(ValueError, match="No URL"):
            scrape_and_parse(None)

    def test_unknown_platform_raises(self):
        """3.17d: Unknown platform URL raises ValueError."""
        from python.tools.scrape_tournament import scrape_and_parse

        with pytest.raises(ValueError, match="Unsupported"):
            scrape_and_parse("https://unknown-site.com/results/123")

    def test_detect_platform_dartagnan(self):
        """dart.7: Dartagnan URL detected as 'dartagnan' platform."""
        from python.scrapers.base import detect_platform

        assert detect_platform(
            "https://www.dartagnan.live/turniere/EuropeanVeteransCup_2026/de/6687-rankings.html"
        ) == "dartagnan"
        assert detect_platform(
            "http://dartagnan.live/turniere/foo/de/index.html"
        ) == "dartagnan"
