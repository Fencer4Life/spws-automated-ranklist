"""
Tests for EVF calendar scraper.

Plan test IDs evf.1–evf.5:
  evf.1  Parses fixture HTML correctly
  evf.2  Extracts name, dates, location, weapons
  evf.3  Filters by season date range
  evf.4  Dedup identifies already-imported
  evf.5  Dedup passes new events through
"""

from pathlib import Path

import pytest


FIXTURE_PATH = Path(__file__).parent / "fixtures" / "evf_calendar.html"


class TestEvfCalendarScraper:
    """Tests evf.1–evf.3: calendar HTML parsing."""

    def test_parses_fixture_html(self):
        """evf.1: scrape_evf_calendar parses fixture HTML and returns events."""
        from python.scrapers.evf_calendar import parse_evf_calendar_html

        html = FIXTURE_PATH.read_text(encoding="utf-8")
        events = parse_evf_calendar_html(html)
        assert len(events) > 0

    def test_extracts_event_fields(self):
        """evf.2: Each event has name, dt_start, location, country, weapons."""
        from python.scrapers.evf_calendar import parse_evf_calendar_html

        html = FIXTURE_PATH.read_text(encoding="utf-8")
        events = parse_evf_calendar_html(html)
        event = events[0]
        assert "name" in event and event["name"]
        assert "dt_start" in event and event["dt_start"]
        assert "location" in event
        assert "weapons" in event and isinstance(event["weapons"], list)

    def test_filters_by_season_date_range(self):
        """evf.3: Events outside season range are excluded."""
        from python.scrapers.evf_calendar import parse_evf_calendar_html, filter_by_season

        html = FIXTURE_PATH.read_text(encoding="utf-8")
        all_events = parse_evf_calendar_html(html)
        # Filter to a narrow range that should exclude some events
        filtered = filter_by_season(all_events, "2026-04-01", "2026-05-01")
        assert len(filtered) < len(all_events)
        for e in filtered:
            assert e["dt_start"] >= "2026-04-01"
            assert e["dt_start"] <= "2026-05-01"


class TestEvfDedup:
    """Tests evf.4–evf.5: deduplication logic."""

    def test_dedup_identifies_existing(self):
        """evf.4: Events matching existing DB events (date+-7d + name) are flagged."""
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Salzburg", "dt_start": "2026-04-18", "location": "Salzburg"},
            {"name": "EVF Circuit Dublin", "dt_start": "2026-05-30", "location": "Dublin"},
        ]
        existing = [
            {"txt_name": "PEW7 Salzburg", "dt_start": "2026-04-19"},
        ]
        new, already = deduplicate_events(scraped, existing, date_tolerance=7, name_threshold=50.0)
        assert len(already) == 1
        assert already[0]["name"] == "EVF Circuit Salzburg"

    def test_dedup_passes_new(self):
        """evf.5: Events not matching any existing are returned as new."""
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Dublin", "dt_start": "2026-05-30", "location": "Dublin"},
        ]
        existing = [
            {"txt_name": "PEW7 Salzburg", "dt_start": "2026-04-19"},
        ]
        new, already = deduplicate_events(scraped, existing, date_tolerance=7, name_threshold=50.0)
        assert len(new) == 1
        assert new[0]["name"] == "EVF Circuit Dublin"
        assert len(already) == 0
