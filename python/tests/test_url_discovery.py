"""Tests for tournament URL auto-population (ADR-029).

Tests 3.16a–3.16j: discover tournament result URLs from event pages
for FTL, Engarde, and 4Fence platforms.
"""

from __future__ import annotations

import pytest
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"


# ── 3.16a: FTL discovery (reuses existing parse_event_schedule) ─────────

class TestDiscoverFTL:
    def test_discover_ftl_returns_urls(self):
        """3.16a: FTL event page → tournament URLs with weapon/gender/category."""
        from python.tools.populate_tournament_urls import discover_tournament_urls_from_html

        html = (FIXTURES / "ftl" / "event_schedule_PPW2.html").read_text()
        results = discover_tournament_urls_from_html(html, "ftl")
        # Should return list of dicts with weapon, gender, category, url
        assert len(results) > 0
        first = results[0]
        assert "weapon" in first
        assert "gender" in first
        assert "category" in first
        assert "url" in first
        assert first["weapon"] in ("EPEE", "FOIL", "SABRE")
        assert first["gender"] in ("M", "F")
        assert first["url"].startswith("https://www.fencingtimelive.com/events/results/")

    def test_ftl_combined_maps_multiple(self):
        """3.16h: Combined 'Category 1 and 2' maps to multiple URLs."""
        from python.tools.populate_tournament_urls import discover_tournament_urls_from_html

        html = (FIXTURES / "ftl" / "event_schedule_PPW2.html").read_text()
        results = discover_tournament_urls_from_html(html, "ftl")
        # PPW2 has combined categories — check we get V1 and V2 from the same UUID
        categories = {(r["weapon"], r["gender"], r["category"]) for r in results}
        # Should have multiple categories for same weapon+gender
        epee_m_cats = {c for w, g, c in categories if w == "EPEE" and g == "M"}
        assert len(epee_m_cats) >= 2  # At least V0+V1 or V2+V3 etc.


# ── 3.16b: Engarde discovery (XML API) ──────────────────────────────────

class TestDiscoverEngarde:
    def test_discover_engarde_returns_urls(self):
        """3.16b: Engarde XML API → tournament URLs."""
        from python.tools.populate_tournament_urls import parse_engarde_competitions_xml

        xml = (FIXTURES / "engarde" / "competitions_madrid.xml").read_text()
        results = parse_engarde_competitions_xml(
            xml, org="aeve_esgrima", event="evf_madrid_2025"
        )
        assert len(results) > 0
        first = results[0]
        assert "weapon" in first
        assert "gender" in first
        assert "category" in first
        assert "url" in first
        assert "engarde-service.com/competition/" in first["url"]
        assert "clasfinal.htm" in first["url"]

    def test_engarde_skips_table_entries(self):
        """3.16d: TABLE/DE entries (t_ prefix) excluded from results."""
        from python.tools.populate_tournament_urls import parse_engarde_competitions_xml

        xml = (FIXTURES / "engarde" / "competitions_madrid.xml").read_text()
        results = parse_engarde_competitions_xml(
            xml, org="aeve_esgrima", event="evf_madrid_2025"
        )
        slugs = [r.get("slug", "") for r in results]
        assert not any(s.startswith("t_") for s in slugs)

    def test_engarde_weapon_mapping(self):
        """3.16d: Engarde arme attribute maps correctly (e→EPEE, f→FOIL, s→SABRE)."""
        from python.tools.populate_tournament_urls import parse_engarde_competitions_xml

        xml = (FIXTURES / "engarde" / "competitions_madrid.xml").read_text()
        results = parse_engarde_competitions_xml(
            xml, org="aeve_esgrima", event="evf_madrid_2025"
        )
        weapons = {r["weapon"] for r in results}
        # Madrid has at least epee
        assert "EPEE" in weapons
        for r in results:
            assert r["weapon"] in ("EPEE", "FOIL", "SABRE")

    def test_engarde_combined_category(self):
        """3.16h: Engarde combined '3-4' maps to multiple entries."""
        from python.tools.populate_tournament_urls import parse_engarde_competitions_xml

        xml = (FIXTURES / "engarde" / "competitions_madrid.xml").read_text()
        results = parse_engarde_competitions_xml(
            xml, org="aeve_esgrima", event="evf_madrid_2025"
        )
        # Madrid has "ef-3-4" → should produce V3 and V4 entries
        v3_f_epee = [r for r in results if r["weapon"] == "EPEE" and r["gender"] == "F" and r["category"] == "V3"]
        v4_f_epee = [r for r in results if r["weapon"] == "EPEE" and r["gender"] == "F" and r["category"] == "V4"]
        assert len(v3_f_epee) > 0
        assert len(v4_f_epee) > 0


# ── 3.16c: 4Fence discovery (deterministic URL generation) ──────────────

class TestDiscoverFourfence:
    def test_discover_fourfence_generates_urls(self):
        """3.16c: 4Fence base URL → all valid tournament URL combos."""
        from python.tools.populate_tournament_urls import generate_fourfence_urls

        base = "https://www.4fence.it/FIS/Risultati/2026-03-08-07_Napoli_-_4_Prova_Circuito_Nazionale_Master_2025-2/"
        results = generate_fourfence_urls(base)
        assert len(results) > 0
        first = results[0]
        assert "weapon" in first
        assert "gender" in first
        assert "category" in first
        assert "url" in first
        assert "f=clafinale" in first["url"]

    def test_fourfence_weapon_map(self):
        """3.16e: 4Fence weapon params: SP→EPEE, F→FOIL, SC→SABRE."""
        from python.tools.populate_tournament_urls import generate_fourfence_urls

        base = "https://www.4fence.it/FIS/Risultati/2026-test/"
        results = generate_fourfence_urls(base)
        weapons = {r["weapon"] for r in results}
        assert weapons == {"EPEE", "FOIL", "SABRE"}

    def test_fourfence_category_map(self):
        """3.16f: 4Fence category params: c=5→V0, c=6→V1, ..., c=9→V4."""
        from python.tools.populate_tournament_urls import generate_fourfence_urls

        base = "https://www.4fence.it/FIS/Risultati/2026-test/"
        results = generate_fourfence_urls(base)
        categories = {r["category"] for r in results}
        assert categories == {"V0", "V1", "V2", "V3", "V4"}


# ── 3.16g: URL matching to DB tournaments ────────────────────────────────

class TestMatchUrls:
    def test_match_urls_to_tournaments(self):
        """3.16g: Discovered URLs correctly matched to DB tournament records."""
        from python.tools.populate_tournament_urls import match_urls_to_tournaments

        discovered = [
            {"weapon": "EPEE", "gender": "M", "category": "V2", "url": "https://example.com/em-v2"},
            {"weapon": "FOIL", "gender": "F", "category": "V1", "url": "https://example.com/ff-v1"},
            {"weapon": "SABRE", "gender": "M", "category": "V3", "url": "https://example.com/sm-v3"},
        ]
        tournaments = [
            {"id_tournament": 1, "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V2", "url_results": None},
            {"id_tournament": 2, "enum_weapon": "FOIL", "enum_gender": "F", "enum_age_category": "V1", "url_results": None},
            {"id_tournament": 3, "enum_weapon": "EPEE", "enum_gender": "F", "enum_age_category": "V0", "url_results": None},
        ]
        matched, unmatched = match_urls_to_tournaments(discovered, tournaments)
        assert len(matched) == 2  # EPEE M V2 + FOIL F V1
        assert len(unmatched) == 1  # SABRE M V3 has no DB tournament
        assert matched[0]["id_tournament"] == 1
        assert matched[0]["url"] == "https://example.com/em-v2"


# ── 3.16i: Platform detection ────────────────────────────────────────────

class TestPlatformDetection:
    def test_unknown_platform_raises(self):
        """3.16i: Unknown URL raises ValueError."""
        from python.scrapers.base import detect_platform

        with pytest.raises(ValueError):
            detect_platform("https://unknown-site.com/results")
