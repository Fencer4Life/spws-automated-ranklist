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


# ===========================================================================
# 3.18 — Universal scraper contract: participant_count = raw field size
# ===========================================================================
# Regression guard for an ADR-038 bug: the POL-only filter shrank the
# ingest payload, and callers that relied on jsonb_array_length(p_results)
# for int_participant_count silently deflated scoring. This test asserts
# every URL-based scraper (FTL, Engarde, 4fence, Dartagnan) threads the
# *raw* scrape size into fn_ingest_tournament_results's p_participant_count,
# independent of match/filter outcomes.

SCRAPER_FIXTURES = [
    pytest.param(
        "ftl",
        "https://www.fencingtimelive.com/events/results/EEC7379682834E588E5B267447C7266A",
        FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json",
        53,
        id="ftl",
    ),
    pytest.param(
        "engarde",
        "https://engarde-service.com/competition/hunfencing/2025_09_20_pbt/em-2/clasfinal.htm",
        FIXTURES / "engarde" / "clasfinal_hunfencing.html",
        57,
        id="engarde",
    ),
    pytest.param(
        "fourfence",
        "https://www.4fence.it/FIS/Risultati/2025/index.php?a=SP&s=M&c=7&f=clafinale",
        FIXTURES / "fourfence" / "clafinale_terni.html",
        64,
        id="fourfence",
    ),
    pytest.param(
        "dartagnan",
        "https://www.dartagnan.live/turniere/EuropeanVeteransCup_2026/de/6687-rankings.html",
        FIXTURES / "dartagnan" / "6687-rankings.html",
        15,
        id="dartagnan",
    ),
]


@pytest.mark.parametrize("platform,url,fixture,expected_n", SCRAPER_FIXTURES)
def test_every_scraper_returns_full_field_size(platform, url, fixture, expected_n):
    """3.18: Every parser returns one row per ranking row — length equals
    the tournament field size and is therefore the correct
    p_participant_count for fn_ingest_tournament_results.

    This is the universal contract: scrapers do NOT filter by nationality.
    Nationality filtering happens later in resolve_tournament_results
    (ADR-038), which is why callers must pass `len(scraped_results)` as
    p_participant_count — not the post-filter payload length.
    """
    from python.tools.scrape_tournament import scrape_and_parse

    content = fixture.read_bytes() if fixture.suffix == ".json" else fixture.read_text()

    with patch("python.tools.scrape_tournament.httpx") as mock_httpx:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        if fixture.suffix == ".json":
            import json as _json
            mock_resp.json.return_value = _json.loads(content)
            mock_resp.text = content.decode() if isinstance(content, bytes) else content
        else:
            mock_resp.text = content
            mock_resp.json.return_value = None
        mock_httpx.get.return_value = mock_resp

        results = scrape_and_parse(url)

    assert len(results) == expected_n, (
        f"{platform} parser returned {len(results)} rows; fixture has "
        f"{expected_n}. Scrapers must expose the full field size."
    )
    # Contract: participant_count sent to fn_ingest_tournament_results MUST
    # be len(results). Assert the shape once here so that every platform
    # shares the same downstream contract.
    rpc_participant_count = len(results)
    assert rpc_participant_count == expected_n
