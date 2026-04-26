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
        """evf.4: Events matching existing DB events (date ±7d + location) are flagged.

        Updated for ADR-039: name-fuzzy fallback removed. When country is
        missing on the existing row, dedup falls back to location string
        token similarity ≥ 70% (after diacritic-fold).
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Salzburg", "dt_start": "2026-04-18", "location": "Salzburg"},
            {"name": "EVF Circuit Dublin", "dt_start": "2026-05-30", "location": "Dublin"},
        ]
        existing = [
            {"txt_name": "PEW7 Salzburg", "dt_start": "2026-04-19", "txt_location": "Salzburg"},
        ]
        new, already = deduplicate_events(scraped, existing, date_tolerance=7)
        assert len(already) == 1
        assert already[0]["name"] == "EVF Circuit Salzburg"

    def test_dedup_passes_new(self):
        """evf.5: Events not matching any existing are returned as new."""
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Dublin", "dt_start": "2026-05-30", "location": "Dublin"},
        ]
        existing = [
            {"txt_name": "PEW7 Salzburg", "dt_start": "2026-04-19", "txt_location": "Salzburg"},
        ]
        new, already = deduplicate_events(scraped, existing, date_tolerance=7)
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

    def test_dedup_diacritic_folded_location_fallback(self):
        """evf.17: Fallback path (missing country) still works via diacritic-folded
        location — Jabłonna ↔ Jablonna match after NFKD fold.

        Updated for ADR-039: fallback is now location-based, not name-based.
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Jablonna", "dt_start": "2026-03-28",
             "location": "Jablonna"},
        ]
        existing = [
            {"txt_name": "EVF Circuit Jabłonna", "dt_start": "2026-03-28",
             "txt_location": "Jabłonna"},
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
# evf.19–evf.24: ADR-039 — name fallback removed, stale gate, integrity guard
# =============================================================================
class TestDedupAlgorithmRev2:
    """Tests evf.19–evf.21: name comparison removed, location fallback added."""

    def test_no_name_fuzzy_fallback_for_renames(self):
        """evf.19: Napoli vs 'EVF Circuit – Naples (ITA)' with country missing
        on existing must NOT match. The name-fuzzy fallback that produced the
        PEW-PALAVESUVI duplicate is gone (ADR-039). Without country or
        location to corroborate, distinct rows stay distinct.
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit – Naples (ITA)", "dt_start": "2026-03-07",
             "country": "Italy", "location": "Palavesuvio"},
        ]
        existing = [
            # Country and location both missing — only name is similar.
            {"txt_name": "EVF Circuit Napoli", "dt_start": "2026-03-07"},
        ]
        new, already = deduplicate_events(scraped, existing)
        assert len(new) == 1, "Name-only similarity must NOT trigger a match"
        assert len(already) == 0

    def test_location_fallback_when_country_missing(self):
        """evf.20: country missing on either side, location strings overlap
        ≥ 70% via token_set_ratio (after diacritic fold) → match.
        """
        from python.scrapers.evf_calendar import deduplicate_events

        scraped = [
            {"name": "EVF Circuit Stockholm", "dt_start": "2026-03-14",
             "location": "Stockholm, Sweden"},
        ]
        existing = [
            # No txt_country, but txt_location overlaps.
            {"txt_name": "Stockholm International", "dt_start": "2026-03-14",
             "txt_location": "Stockholm"},
        ]
        new, already = deduplicate_events(scraped, existing)
        assert len(already) == 1
        assert len(new) == 0

    def test_date_window_edge_seven_vs_eight_days(self):
        """evf.21: ±7 days matches; ±8 days does not. Confirms the 7-day
        window is wide enough for HTML/API skew + 6-day team championships
        but tight enough that adjacent same-country events stay separate.
        """
        from python.scrapers.evf_calendar import deduplicate_events

        # 7-day drift: still matches via country
        scraped_7 = [
            {"name": "EVF Circuit Madrid", "dt_start": "2026-04-08",
             "country": "Spain"},
        ]
        existing_7 = [
            {"txt_name": "Madrid Open", "dt_start": "2026-04-01",
             "txt_country": "Spain"},
        ]
        new7, already7 = deduplicate_events(scraped_7, existing_7)
        assert len(already7) == 1, "7-day drift with same country must match"

        # 8-day drift: no match — outside window even with same country
        scraped_8 = [
            {"name": "EVF Circuit Madrid", "dt_start": "2026-04-09",
             "country": "Spain"},
        ]
        existing_8 = [
            {"txt_name": "Madrid Open", "dt_start": "2026-04-01",
             "txt_country": "Spain"},
        ]
        new8, already8 = deduplicate_events(scraped_8, existing_8)
        assert len(new8) == 1, "8-day drift must NOT match"
        assert len(already8) == 0


class TestStaleEventGate:
    """Tests evf.22, evf.24: 30-day window + status-COMPLETED gate (ADR-039)."""

    def test_is_in_scope_classification(self):
        """evf.22: Four canonical states.

        - Stale (dt_end > 30d ago) AND status != COMPLETED  → out-of-scope
        - Stale AND status == COMPLETED                      → out-of-scope
        - Fresh (dt_end within 30d) AND status != COMPLETED  → in-scope
        - Future event AND status != COMPLETED               → in-scope
        """
        from datetime import date
        from python.scrapers.evf_calendar import is_in_scope

        today = date(2026, 4, 25)

        stale_planned = {"dt_end": "2026-03-25", "enum_status": "PLANNED"}
        stale_completed = {"dt_end": "2026-03-25", "enum_status": "COMPLETED"}
        fresh_planned = {"dt_end": "2026-04-20", "enum_status": "PLANNED"}
        fresh_completed = {"dt_end": "2026-04-20", "enum_status": "COMPLETED"}
        future_planned = {"dt_end": "2026-05-30", "enum_status": "PLANNED"}

        assert is_in_scope(stale_planned, today=today) is False
        assert is_in_scope(stale_completed, today=today) is False
        assert is_in_scope(fresh_planned, today=today) is True
        assert is_in_scope(fresh_completed, today=today) is False, (
            "COMPLETED always wins, even within 30-day window"
        )
        assert is_in_scope(future_planned, today=today) is True

    def test_caller_prefilter_excludes_out_of_scope(self):
        """evf.24: The caller-side pre-filter pattern — applying is_in_scope
        to existing rows BEFORE feeding them to deduplicate_events removes
        stale and COMPLETED rows so they're not dedup candidates. This is
        how sync_calendar / sync_results in evf_sync.py invoke the matcher.
        """
        from datetime import date
        from python.scrapers.evf_calendar import deduplicate_events, is_in_scope

        today = date(2026, 4, 25)

        scraped = [
            {"name": "EVF Circuit Stockholm", "dt_start": "2026-03-14",
             "country": "Sweden"},
        ]
        existing = [
            # Stockholm Mar 14 — would match by date+country, but COMPLETED.
            {"id_event": 51, "txt_name": "EVF Circuit Stockholm",
             "dt_start": "2026-03-14", "txt_country": "Sweden",
             "dt_end": "2026-03-14", "enum_status": "COMPLETED"},
            # A future PLANNED Stockholm — different date, won't match.
            {"id_event": 99, "txt_name": "Future Stockholm",
             "dt_start": "2030-03-14", "txt_country": "Sweden",
             "dt_end": "2030-03-14", "enum_status": "PLANNED"},
        ]
        in_scope = [e for e in existing if is_in_scope(e, today=today)]
        assert {e["id_event"] for e in in_scope} == {99}, (
            "Pre-filter removes the COMPLETED Stockholm row"
        )
        new, already = deduplicate_events(scraped, in_scope)
        assert len(new) == 1, "Without the COMPLETED candidate, scraped row is new"
        assert len(already) == 0


class TestLogicalIntegrityGuard:
    """Tests evf.23: future-COMPLETED row halts the sync (ADR-039 Step 0)."""

    def test_assert_no_future_completed_raises(self):
        """evf.23: A row with dt_start > today AND enum_status='COMPLETED'
        is data corruption. The guard raises LogicalIntegrityError so the
        sync aborts and Telegram alerts the admin.
        """
        from datetime import date
        from python.scrapers.evf_calendar import (
            assert_no_future_completed, LogicalIntegrityError,
        )

        today = date(2026, 4, 25)

        # No violation — this should pass silently.
        clean = [
            {"txt_code": "PEW8-2025-2026", "dt_start": "2026-05-02",
             "enum_status": "PLANNED"},
            {"txt_code": "PEW4-2025-2026", "dt_start": "2026-03-07",
             "enum_status": "COMPLETED"},
        ]
        assert_no_future_completed(clean, today=today)

        # Violation: future date AND COMPLETED.
        corrupt = clean + [
            {"txt_code": "PEW9-2025-2026", "dt_start": "2026-05-30",
             "enum_status": "COMPLETED"},
        ]
        with pytest.raises(LogicalIntegrityError) as exc_info:
            assert_no_future_completed(corrupt, today=today)
        # Error message must include the offending code so the admin can act.
        assert "PEW9-2025-2026" in str(exc_info.value)


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
        """evf.13: pair scraped events with their matching DB rows.

        Updated for ADR-039: matching now uses date + country (STRONG) or
        date + location (MEDIUM). Name fuzzy matching is gone.
        """
        from python.scrapers.evf_calendar import match_scraped_to_existing

        scraped = [
            {"name": "EVF Circuit Salzburg", "dt_start": "2026-04-18",
             "country": "Austria"},
            {"name": "EVF Circuit Dublin", "dt_start": "2026-05-30",
             "country": "Ireland"},
            {"name": "EVF Circuit Zurich", "dt_start": "2026-06-01",
             "country": "Switzerland"},   # no match (no Swiss row in existing)
        ]
        existing = [
            {"id_event": 101, "txt_name": "PEW7 Salzburg",    "dt_start": "2026-04-19",
             "txt_country": "Austria"},
            {"id_event": 102, "txt_name": "PEW9 Dublin",      "dt_start": "2026-05-30",
             "txt_country": "Ireland"},
            {"id_event": 103, "txt_name": "PPW5 Gdansk",      "dt_start": "2026-04-11",
             "txt_country": "Polska"},
        ]
        pairs = match_scraped_to_existing(scraped, existing, date_tolerance=7)
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


# =============================================================================
# evf.40–evf.42: Phase 2 — scraper drops `code` field, allocator RPC drives
# alerting per alloc_path returned by fn_import_evf_events_v2
# =============================================================================
class TestEvfPhase2Allocator:
    """Phase 2 — scraper sends classifier inputs (name, is_team) instead of
    pre-built code; RPC returns alerts only for NEXT_FREE_ALLOC; per-row
    telegram fired exclusively for those rows.
    """

    def _patch_sync(self, monkeypatch, scraped_events, rpc_returns):
        """Wire up monkeypatches shared by Phase 2 tests.

        - scrape_full_season_calendar → returns scraped_events
        - _management_query is recorded; for SELECT id_season... returns a
          fake active season; for fn_import_evf_events_v2 returns rpc_returns
          (one wrapped row); other queries return [].
        - _telegram is recorded into sent_msgs.
        """
        from python.scrapers import evf_sync

        sql_calls: list[str] = []
        sent_msgs: list[str] = []

        def fake_mgmt(ref, token, sql):
            sql_calls.append(sql)
            sl = sql.lower()
            if "from tbl_season where bool_active" in sl:
                return [{
                    "txt_code": "SPWS-2025-2026",
                    "dt_start": "2025-09-01",
                    "dt_end": "2026-08-31",
                    "id_season": 7,
                }]
            if "fn_import_evf_events_v2" in sl:
                return [{"r": json.dumps(rpc_returns)}]
            if "from tbl_event" in sl:
                return []  # no existing events
            return []

        def fake_telegram(bot_token, chat_id, msg):
            sent_msgs.append(msg)

        def fake_scrape(start, end):
            return scraped_events

        monkeypatch.setattr(evf_sync, "_management_query", fake_mgmt)
        monkeypatch.setattr(evf_sync, "_telegram", fake_telegram)
        monkeypatch.setattr(evf_sync, "scrape_full_season_calendar", fake_scrape)

        return sql_calls, sent_msgs

    def test_next_free_alloc_emits_telegram_per_alert(self, monkeypatch):
        """evf.40: One Telegram message per NEXT_FREE_ALLOC alert, with city + new code."""
        from python.scrapers import evf_sync

        scraped = [{
            "name": "EVF Circuit – Madrid (ESP)",
            "dt_start": "2026-06-01", "dt_end": "2026-06-02",
            "location": "Madrid", "country": "Spain",
            "weapons": ["EPEE"], "is_team": False,
            "url": "", "fee": None, "fee_currency": "",
        }]
        rpc_returns = {
            "created": 1, "slot_reused": 0, "prior_matched": 0,
            "alerts": [
                {"code": "PEW9-2025-2026", "location": "Madrid", "country": "Spain"},
            ],
        }
        _, sent = self._patch_sync(monkeypatch, scraped, rpc_returns)

        evf_sync.sync_calendar("ref", "token", "bot", "chat", dry_run=False)

        per_row_alerts = [m for m in sent if "Madrid" in m and "PEW9-2025-2026" in m]
        assert len(per_row_alerts) == 1, (
            f"expected exactly 1 NEXT_FREE_ALLOC telegram for Madrid, got {len(per_row_alerts)}: {sent}"
        )

    def test_slot_reuse_and_prior_match_only_in_summary(self, monkeypatch):
        """evf.41: CURRENT_SLOT_REUSE and PRIOR_SEASON_MATCH do NOT trigger per-row telegram.
        Only the summary line mentions them.
        """
        from python.scrapers import evf_sync

        scraped = [
            {"name": "EVF Circuit – Salzburg (AUT)", "dt_start": "2026-04-15",
             "dt_end": "2026-04-16", "location": "Salzburg", "country": "Austria",
             "weapons": ["EPEE"], "is_team": False, "url": "",
             "fee": None, "fee_currency": ""},
            {"name": "EVF Circuit – Krakow (POL)", "dt_start": "2026-05-15",
             "dt_end": "2026-05-16", "location": "Krakow", "country": "Poland",
             "weapons": ["EPEE"], "is_team": False, "url": "",
             "fee": None, "fee_currency": ""},
        ]
        rpc_returns = {
            "created": 0, "slot_reused": 1, "prior_matched": 1,
            "alerts": [],  # no NEXT_FREE_ALLOC
        }
        _, sent = self._patch_sync(monkeypatch, scraped, rpc_returns)

        evf_sync.sync_calendar("ref", "token", "bot", "chat", dry_run=False)

        # No per-row telegram should mention specific cities for slot-reuse / prior-match
        per_row = [m for m in sent if "Salzburg" in m or "Krakow" in m]
        assert per_row == [], (
            f"slot-reuse / prior-match must NOT fire per-row telegrams; got {per_row}"
        )
        # Summary message should still be sent (and reference reuse/match counts)
        summary = [m for m in sent if "slot_reused" in m.lower() or "pre-allocated" in m.lower()
                   or "prior_matched" in m.lower() or "carried" in m.lower()]
        assert summary, f"expected a summary message; got {sent}"

    def test_payload_omits_code_includes_classifier_inputs(self, monkeypatch):
        """evf.42: Payload to RPC has `name` + `is_team` but NOT `code`."""
        from python.scrapers import evf_sync

        scraped = [{
            "name": "EVF Circuit – Berlin (GER)",
            "dt_start": "2026-07-01", "dt_end": "2026-07-02",
            "location": "Berlin", "country": "Germany",
            "weapons": ["EPEE"], "is_team": False,
            "url": "", "fee": None, "fee_currency": "",
        }]
        rpc_returns = {
            "created": 1, "slot_reused": 0, "prior_matched": 0,
            "alerts": [{"code": "PEW8-2025-2026", "location": "Berlin", "country": "Germany"}],
        }
        sql_calls, _ = self._patch_sync(monkeypatch, scraped, rpc_returns)

        evf_sync.sync_calendar("ref", "token", "bot", "chat", dry_run=False)

        rpc_calls = [s for s in sql_calls if "fn_import_evf_events_v2" in s.lower()]
        assert rpc_calls, f"expected fn_import_evf_events_v2 to be invoked; got {sql_calls}"

        # Find the JSON literal in the SQL string
        sql = rpc_calls[0]
        json_start = sql.find("'[")
        json_end = sql.find("]'", json_start)
        assert json_start != -1 and json_end != -1, f"no JSONB array literal in: {sql}"
        payload_str = sql[json_start + 1: json_end + 1].replace("''", "'")
        payload = json.loads(payload_str)

        assert isinstance(payload, list) and len(payload) == 1
        evt = payload[0]
        assert "code" not in evt, f"payload must not include `code`; got keys: {list(evt.keys())}"
        assert "name" in evt and evt["name"]
        assert "is_team" in evt
