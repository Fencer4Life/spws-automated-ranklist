"""
Tests for EVF calendar scraper.

Plan test IDs evf.1–evf.12:
  evf.1   Parses fixture HTML correctly
  evf.2   Extracts name, dates, location, weapons
  evf.3   Filters by season date range
  evf.4   Dedup identifies already-imported
  evf.5   Dedup passes new events through
  evf.6   fetch_calendar_from_api returns event dicts with full schema
  evf.7   parse_event_detail_html extracts invitation PDF URL
  evf.8   parse_event_detail_html extracts Engarde registration URL
  evf.9   parse_event_detail_html extracts registration deadline (EN + PL)
  evf.10  enrich_event_details tolerates single detail-page failure
  evf.11  scrape_full_season_calendar raises RuntimeError on all-source failure
  evf.12  Integration: live EVF API reachable (skipped by default)
"""

import json
import logging
from pathlib import Path
from unittest.mock import MagicMock

import httpx
import pytest


FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE_PATH = FIXTURES / "evf_calendar.html"


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

    def test_dedup_matches_renamed_events_by_date_and_country(self):
        """evf.14: EVF renames (Napoli→Naples, Jabłonna→Jablonna, Chania→Chania Crete)
        score <80 on token_set_ratio but share exact dt_start + country.
        `(dt_start, country)` primary match must catch these as duplicates.
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit – Naples (ITA)", "dt_start": "2026-03-07",
             "country": "Italy"},
            {"name": "EVF Circuit – Jablonna (POL)", "dt_start": "2026-03-28",
             "country": "Poland"},
            {"name": "EVF Circuit – Chania, Crete (GRE)", "dt_start": "2026-05-02",
             "country": "Greece"},
        ]
        existing = [
            {"txt_name": "EVF Circuit Napoli", "dt_start": "2026-03-07",
             "txt_country": "Italy"},
            {"txt_name": "EVF Circuit Jabłonna", "dt_start": "2026-03-28",
             "txt_country": "Polska"},
            {"txt_name": "EVF Circuit Chania", "dt_start": "2026-05-02",
             "txt_country": "Greece"},
        ]
        new, already = deduplicate_events(scraped, existing)
        assert len(new) == 0, (
            f"Renamed EVF events must NOT create new rows. Got new={[e['name'] for e in new]}"
        )
        assert len(already) == 3

    def test_dedup_country_aliases_fold(self):
        """evf.15: Multi-language country names (Polska↔Poland, Italia↔Italy,
        Deutschland↔Germany) fold to the same canonical form.
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Warsaw", "dt_start": "2026-06-15",
             "country": "Poland"},
            {"name": "EVF Circuit Rome", "dt_start": "2026-07-10",
             "country": "Italy"},
            {"name": "EVF Circuit Berlin", "dt_start": "2026-08-20",
             "country": "Germany"},
        ]
        existing = [
            {"txt_name": "EVF Event X", "dt_start": "2026-06-15",
             "txt_country": "Polska"},
            {"txt_name": "EVF Event Y", "dt_start": "2026-07-10",
             "txt_country": "Italia"},
            {"txt_name": "EVF Event Z", "dt_start": "2026-08-20",
             "txt_country": "Deutschland"},
        ]
        new, already = deduplicate_events(scraped, existing)
        assert len(new) == 0
        assert len(already) == 3

    def test_dedup_same_day_different_country_stays_separate(self):
        """evf.16: Two EVF events on the same day in different countries are
        NOT duplicates. Primary key must include country — date alone would
        over-match (regression guard against aggressive dedup).
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit – Liège (BEL)", "dt_start": "2026-04-11",
             "country": "Belgium"},
        ]
        existing = [
            {"txt_name": "V Puchar Polski Weteranów", "dt_start": "2026-04-11",
             "txt_country": "Polska"},
        ]
        new, already = deduplicate_events(scraped, existing)
        assert len(new) == 1, "Same day, different country → separate events"
        assert len(already) == 0

    def test_dedup_diacritic_folded_name_fallback(self):
        """evf.17: Fallback path (missing country) still works via diacritic-folded
        fuzzy name — ensures backward compat when scraper can't emit country.
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Jablonna", "dt_start": "2026-03-28"},
        ]
        existing = [
            {"txt_name": "EVF Circuit Jabłonna", "dt_start": "2026-03-28"},
        ]
        new, already = deduplicate_events(scraped, existing)
        assert len(already) == 1
        assert len(new) == 0

    def test_match_scraped_to_existing_uses_same_primary_key(self):
        """evf.18: match_scraped_to_existing (the URL-refresh pair builder)
        must apply the same (dt_start + country) primary match so refresh
        hits the right existing row even when EVF renamed the event.
        """
        from python.scrapers.evf_calendar import match_scraped_to_existing

        scraped = [
            {"name": "EVF Circuit – Naples (ITA)", "dt_start": "2026-03-07",
             "country": "Italy", "url": "https://evf/naples"},
        ]
        existing = [
            {"id_event": 42, "txt_name": "EVF Circuit Napoli",
             "dt_start": "2026-03-07", "txt_country": "Italy"},
        ]
        pairs = match_scraped_to_existing(scraped, existing)
        assert len(pairs) == 1
        assert pairs[0][1]["id_event"] == 42


# =============================================================================
# evf.6–evf.11: API-first scraper + detail-page URL harvesting
# =============================================================================


def _build_fake_api_client() -> MagicMock:
    """Construct a MagicMock EvfApiClient pre-loaded with the JSON fixtures."""
    events = json.loads((FIXTURES / "evf_api_events.json").read_text())
    comps = json.loads((FIXTURES / "evf_api_competitions.json").read_text())

    client = MagicMock()
    client.get_events.return_value = events
    client.get_competitions.side_effect = lambda eid: comps.get(str(eid), [])
    return client


class TestEvfApiCalendar:
    """Tests evf.6: JSON-API primary path."""

    def test_fetch_calendar_from_api_returns_schema(self):
        """evf.6: fetch_calendar_from_api returns dicts with all public keys."""
        from python.scrapers.evf_calendar import fetch_calendar_from_api

        client = _build_fake_api_client()
        events = fetch_calendar_from_api(client, "2026-01-01", "2026-12-31")

        assert len(events) == 3, "expected 3 events from fixture"
        required_keys = {
            "name", "dt_start", "dt_end", "location", "address", "country",
            "weapons", "is_team", "url", "fee", "fee_currency",
            "url_invitation", "url_registration", "dt_registration_deadline",
        }
        for e in events:
            missing = required_keys - set(e.keys())
            assert not missing, f"event missing keys: {missing}"
            assert e["name"], "event name must be non-empty"
            assert e["dt_start"], "event dt_start must be non-empty"
            assert isinstance(e["weapons"], list)

        # Weapons derived from competitions.weaponId → WEAPON_MAP (1=FOIL, 2=EPEE, 3=SABRE)
        salzburg = next(e for e in events if "Salzburg" in e["name"])
        assert "EPEE" in salzburg["weapons"]
        assert "FOIL" in salzburg["weapons"]
        assert "SABRE" in salzburg["weapons"]


class TestEvfEventDetailParser:
    """Tests evf.7–evf.9: parse_event_detail_html."""

    def test_parses_invitation_pdf(self):
        """evf.7: parse_event_detail_html extracts url_invitation from PDF link."""
        from python.scrapers.evf_calendar import parse_event_detail_html

        html = (FIXTURES / "evf_event_detail_with_invitation.html").read_text()
        out = parse_event_detail_html(html)
        assert out["url_invitation"], "expected invitation URL to be found"
        assert out["url_invitation"].endswith(".pdf")
        assert "salzburg-invitation" in out["url_invitation"]

    def test_parses_engarde_registration(self):
        """evf.8: parse_event_detail_html extracts url_registration from Engarde link."""
        from python.scrapers.evf_calendar import parse_event_detail_html

        html = (FIXTURES / "evf_event_detail_with_engarde.html").read_text()
        out = parse_event_detail_html(html)
        assert out["url_registration"], "expected registration URL to be found"
        assert "engarde-service.com" in out["url_registration"]
        # Should also pick up invitation PDF on same page
        assert out["url_invitation"], "invitation should also be detected"
        assert out["url_invitation"].endswith(".pdf")

    @pytest.mark.skip(reason="ADR-028: deadline harvesting disabled pending real-world pattern data (HARVEST_DEADLINE=False)")
    def test_parses_engarde_registration_deadline(self):
        """evf.8b: deadline '15 May 2026' normalised to ISO — DISABLED."""
        from python.scrapers.evf_calendar import parse_event_detail_html

        html = (FIXTURES / "evf_event_detail_with_engarde.html").read_text()
        out = parse_event_detail_html(html)
        assert out["dt_registration_deadline"] == "2026-05-15"

    def test_parses_polish_registration(self):
        """evf.9: parse_event_detail_html handles Polish 'Zgłoszenia' link."""
        from python.scrapers.evf_calendar import parse_event_detail_html

        html = (FIXTURES / "evf_event_detail_with_deadline_polish.html").read_text()
        out = parse_event_detail_html(html)
        assert out["url_registration"], "Polish 'Zgłoszenia' link should be found"
        assert "engarde-escrime.com" in out["url_registration"]

    @pytest.mark.skip(reason="ADR-028: deadline harvesting disabled pending real-world pattern data (HARVEST_DEADLINE=False)")
    def test_parses_polish_deadline(self):
        """evf.9b: Polish ISO deadline '2026-03-10' — DISABLED."""
        from python.scrapers.evf_calendar import parse_event_detail_html

        html = (FIXTURES / "evf_event_detail_with_deadline_polish.html").read_text()
        out = parse_event_detail_html(html)
        assert out["dt_registration_deadline"] == "2026-03-10"


class TestEvfEnrichment:
    """Test evf.10: per-event detail fetch resilience."""

    def test_enrich_tolerates_single_failure(self, monkeypatch, caplog):
        """evf.10: One failing detail page must not abort the batch."""
        from python.scrapers import evf_calendar

        events = [
            {
                "name": "Good Event", "url": "https://example.org/good",
                "dt_start": "2026-04-18", "dt_end": "2026-04-19",
                "location": "Salzburg", "address": "", "country": "AUT",
                "weapons": ["EPEE"], "is_team": False, "fee": None, "fee_currency": "",
                "url_invitation": None, "url_registration": None, "dt_registration_deadline": None,
            },
            {
                "name": "Broken Event", "url": "https://example.org/broken",
                "dt_start": "2026-05-30", "dt_end": "2026-05-31",
                "location": "Dublin", "address": "", "country": "IRL",
                "weapons": ["EPEE"], "is_team": False, "fee": None, "fee_currency": "",
                "url_invitation": None, "url_registration": None, "dt_registration_deadline": None,
            },
        ]

        good_html = (FIXTURES / "evf_event_detail_with_invitation.html").read_text()

        def fake_get(url, **kwargs):
            if url.endswith("/broken"):
                raise httpx.ConnectError("boom")
            resp = MagicMock()
            resp.text = good_html
            resp.raise_for_status = MagicMock()
            return resp

        monkeypatch.setattr(evf_calendar.httpx, "get", fake_get)

        with caplog.at_level(logging.WARNING, logger="evf.calendar"):
            enriched = evf_calendar.enrich_event_details(events, delay=0)

        assert len(enriched) == 2, "all events returned even if one detail failed"
        good = next(e for e in enriched if e["name"] == "Good Event")
        broken = next(e for e in enriched if e["name"] == "Broken Event")
        assert good["url_invitation"], "good event should be enriched"
        assert broken["url_invitation"] in (None, ""), "broken event should stay un-enriched"
        # Warning was logged for the failure
        assert any("broken" in rec.getMessage().lower() for rec in caplog.records)


class TestEvfScrapeFailureSurface:
    """Test evf.11: total failure raises RuntimeError."""

    def test_scrape_raises_when_all_sources_fail(self, monkeypatch):
        """evf.11: RuntimeError with aggregated error message when API + HTML both fail."""
        from python.scrapers import evf_calendar

        def raise_api(*a, **kw):
            raise RuntimeError("api exploded")

        def raise_html(*a, **kw):
            raise RuntimeError("html exploded")

        monkeypatch.setattr(evf_calendar, "fetch_calendar_from_api", raise_api)
        monkeypatch.setattr(evf_calendar, "_fetch_html_list", raise_html)

        with pytest.raises(RuntimeError) as excinfo:
            evf_calendar.scrape_full_season_calendar("2026-01-01", "2026-12-31", skip_details=True)

        msg = str(excinfo.value)
        assert "api exploded" in msg
        assert "html exploded" in msg


# =============================================================================
# evf.13: match_scraped_to_existing pairs for the URL-refresh path
# =============================================================================


class TestEvfMatchExisting:
    """evf.13: pair scraped events with their matching DB rows (by date+name)."""

    def test_match_scraped_to_existing_returns_pairs(self):
        from python.scrapers.evf_calendar import match_scraped_to_existing

        scraped = [
            {"name": "EVF Circuit Salzburg", "dt_start": "2026-04-18"},
            {"name": "EVF Circuit Dublin", "dt_start": "2026-05-30"},
            {"name": "EVF Circuit Zurich", "dt_start": "2026-06-01"},   # no match
        ]
        existing = [
            {"id_event": 101, "txt_name": "PEW7 Salzburg",    "dt_start": "2026-04-19"},
            {"id_event": 102, "txt_name": "PEW9 Dublin",      "dt_start": "2026-05-30"},
            {"id_event": 103, "txt_name": "PPW5 Gdansk",      "dt_start": "2026-04-11"},
        ]
        pairs = match_scraped_to_existing(scraped, existing,
                                          date_tolerance=7, name_threshold=50.0)
        names = sorted((s["name"], e["id_event"]) for s, e in pairs)
        assert names == [("EVF Circuit Dublin", 102), ("EVF Circuit Salzburg", 101)]


# =============================================================================
# evf.12: live integration smoke test (skipped by default)
# =============================================================================


@pytest.mark.integration
class TestEvfLiveSmoke:
    """evf.12: hits the real EVF API + one real detail page."""

    def test_live_api_reachable(self):
        """evf.12: real EvfApiClient.connect() + get_events() returns a list."""
        from python.scrapers.evf_results import EvfApiClient

        client = EvfApiClient(request_delay=0.5)
        try:
            client.connect()
            events = client.get_events()
            assert isinstance(events, list)
        finally:
            client.close()
