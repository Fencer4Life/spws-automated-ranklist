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

    def test_engarde_budapest_v_notation_titles(self):
        """3.16k: Budapest event with V-notation titles parses all 8 tournaments."""
        from python.tools.populate_tournament_urls import parse_engarde_competitions_xml

        xml = (FIXTURES / "engarde" / "competitions_budapest.xml").read_text()
        results = parse_engarde_competitions_xml(
            xml, org="hunfencing", event="2025_09_20_pbt"
        )
        assert len(results) == 8
        # All epee, 4 male + 4 female, V1-V4
        weapons = {r["weapon"] for r in results}
        assert weapons == {"EPEE"}
        genders = {r["gender"] for r in results}
        assert genders == {"M", "F"}
        categories = {r["category"] for r in results}
        assert categories == {"V1", "V2", "V3", "V4"}

    def test_engarde_skips_poules_and_empty(self):
        """3.16l: Poules and empty entries filtered out."""
        from python.tools.populate_tournament_urls import parse_engarde_competitions_xml

        xml = (FIXTURES / "engarde" / "competitions_budapest.xml").read_text()
        results = parse_engarde_competitions_xml(
            xml, org="hunfencing", event="2025_09_20_pbt"
        )
        slugs = [r.get("slug", "") for r in results]
        # No combined poule slugs
        assert not any("-" in s for s in slugs)


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


# ── dart.url.1: Dartagnan discovery ──────────────────────────────────────

class TestDiscoverDartagnan:
    def test_discover_dartagnan_tournament_urls(self):
        """dart.url.1: Dartagnan index → per-category rankings URLs."""
        from python.tools.populate_tournament_urls import discover_tournament_urls_from_html

        html = (FIXTURES / "dartagnan" / "index.html").read_text()
        index_url = (
            "https://www.dartagnan.live/turniere/EuropeanVeteransCup_2026/de/index.html"
        )
        results = discover_tournament_urls_from_html(
            html, "dartagnan", index_url=index_url
        )

        assert len(results) > 0
        first = results[0]
        assert "weapon" in first and first["weapon"] in ("EPEE", "FOIL", "SABRE")
        assert "gender" in first and first["gender"] in ("M", "F")
        assert "category" in first and first["category"] in ("V0", "V1", "V2", "V3", "V4")
        assert "url" in first
        assert first["url"].endswith("-rankings.html")

        # Sanity: Men Epee V1 (6687) and Women Foil V4 (7027) both present
        keys = {(r["weapon"], r["gender"], r["category"]) for r in results}
        assert ("EPEE", "M", "V1") in keys
        assert ("FOIL", "F", "V4") in keys

        # No combined "Runde" entries — every discovered URL is for a single category
        urls = [r["url"] for r in results]
        assert all(u.endswith("-rankings.html") for u in urls)


# ── 3.16k–m: Multi-slot event-level URLs (ADR-040) ──────────────────────

class TestMultiSlotEventUrls:
    """Plan tests 3.16k–3.16m: discovery iterates url_event + url_event_2..5,
    merges results across URLs deduping by (weapon, gender, category).
    """

    def test_3_16k_iterates_non_null_slots(self, monkeypatch):
        """3.16k: discover_tournament_urls_for_event iterates non-null url_event slots
        and skips NULL/empty ones."""
        from python.tools import populate_tournament_urls as ptu

        called_with: list[str] = []

        # Each URL yields a distinct (weapon,gender,category) tuple so all
        # three results survive deduplication.
        per_url = {
            "https://a.example/": {"weapon": "EPEE", "gender": "M", "category": "V1"},
            "https://c.example/": {"weapon": "FOIL", "gender": "F", "category": "V2"},
            "https://e.example/": {"weapon": "SABRE", "gender": "M", "category": "V3"},
        }

        def fake_discover(url: str) -> list[dict]:
            called_with.append(url)
            wgc = per_url[url]
            return [{**wgc, "url": f"{url}#cat", "source_name": f"slot for {url}"}]

        monkeypatch.setattr(ptu, "discover_tournament_urls", fake_discover)

        event = {
            "url_event":   "https://a.example/",
            "url_event_2": None,
            "url_event_3": "https://c.example/",
            "url_event_4": "",        # empty → skip
            "url_event_5": "https://e.example/",
        }
        results = ptu.discover_tournament_urls_for_event(event)
        assert called_with == ["https://a.example/", "https://c.example/", "https://e.example/"]
        assert len(results) == 3

    def test_3_16l_dedupes_by_weapon_gender_category(self, monkeypatch):
        """3.16l: when two URLs both yield results for the same (weapon,gender,category),
        keep the first occurrence and log a warning."""
        from python.tools import populate_tournament_urls as ptu

        # URL A returns Epee M V1; URL B returns Epee M V1 (collision) + Foil F V2
        def fake_discover(url: str) -> list[dict]:
            if url == "https://a.example/":
                return [{"weapon": "EPEE", "gender": "M", "category": "V1",
                         "url": "https://a.example/em-v1", "source_name": "A"}]
            if url == "https://b.example/":
                return [
                    {"weapon": "EPEE", "gender": "M", "category": "V1",
                     "url": "https://b.example/em-v1-dup", "source_name": "B-dup"},
                    {"weapon": "FOIL", "gender": "F", "category": "V2",
                     "url": "https://b.example/ff-v2", "source_name": "B"},
                ]
            return []

        monkeypatch.setattr(ptu, "discover_tournament_urls", fake_discover)

        event = {
            "url_event":   "https://a.example/",
            "url_event_2": "https://b.example/",
            "url_event_3": None, "url_event_4": None, "url_event_5": None,
        }
        results = ptu.discover_tournament_urls_for_event(event)
        # 2 unique (weapon, gender, category) combos: (EPEE,M,V1) + (FOIL,F,V2)
        keys = {(r["weapon"], r["gender"], r["category"]) for r in results}
        assert keys == {("EPEE", "M", "V1"), ("FOIL", "F", "V2")}
        # First occurrence wins → URL A's URL is kept for the duplicate
        em_v1 = next(r for r in results if (r["weapon"], r["gender"], r["category"]) == ("EPEE","M","V1"))
        assert em_v1["url"] == "https://a.example/em-v1"

    def test_3_16m_all_null_returns_empty(self, monkeypatch):
        """3.16m: event with all 5 URL slots NULL/empty → empty result list, no calls."""
        from python.tools import populate_tournament_urls as ptu

        called = []
        monkeypatch.setattr(ptu, "discover_tournament_urls",
                            lambda u: (called.append(u), [])[1])

        event = {"url_event": None, "url_event_2": "", "url_event_3": None,
                 "url_event_4": None, "url_event_5": None}
        results = ptu.discover_tournament_urls_for_event(event)
        assert results == []
        assert called == []
