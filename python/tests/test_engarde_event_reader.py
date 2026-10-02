"""ENG.EVT — an Engarde tournament URL expands into one bracket per category final.

doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html. An Engarde
tournament page (``/tournament/<org>/<event>``) is built in JavaScript; its
competitions come from Engarde's list (``getCompeForDisplay.php``, XML). Each
competition page (``/competition/<org>/<event>/<compe>``) carries its final
classification, read by ``parse_html``. Only individual, completed,
single-category finals are brackets: a pool round, a team event, a competition
without one category, or one still running is skipped and listed for review,
never guessed. The Criterium 2026 has 24 finals and 3 V3–V4 pool rounds that
Engarde marks completed.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path
from unittest.mock import MagicMock

FIXTURES = Path(__file__).parent / "fixtures" / "engarde"


def _crit26():
    from python.scrapers.engarde import parse_competition_list

    xml = (FIXTURES / "competitions_crit26.xml").read_text()
    return parse_competition_list(xml, org="fencingaddict", event="crit26")


def test_ENG_EVT_01_category_finals_are_listed_with_weapon_gender_category_and_date():
    kept, _skipped = _crit26()

    assert len(kept) == 24
    by_slug = {c["slug"]: c for c in kept}
    assert by_slug["ehv2"] == {
        "slug": "ehv2",
        "weapon": "EPEE",
        "gender": "M",
        "category": "V2",
        "title": "Épée Hommes V2",
        "date": date(2026, 7, 5),
        "url": "https://engarde-service.com/competition/fencingaddict/crit26/ehv2",
    }
    assert {(c["weapon"], c["gender"]) for c in kept} == {
        (w, g) for w in ("EPEE", "FOIL", "SABRE") for g in ("M", "F")
    }
    assert {c["category"] for c in kept} == {"V1", "V2", "V3", "V4"}


def test_ENG_EVT_02_pool_rounds_team_events_and_open_competitions_are_skipped_with_a_reason():
    from python.scrapers.engarde import parse_competition_list

    _kept, skipped = _crit26()
    assert sorted(s["slug"] for s in skipped) == ["edv34", "fdv34", "sdv34"]
    assert {s["reason"] for s in skipped} == {"pool round"}
    assert all(s["url"].endswith(f"/crit26/{s['slug']}") for s in skipped)

    budapest = (FIXTURES / "competitions_budapest.xml").read_text()
    _kept, skipped = parse_competition_list(budapest, org="hunfencing", event="2025_09_20_pbt")
    assert {s["slug"]: s["reason"] for s in skipped} == {
        "we40-50": "pool round",
        "we60-70": "pool round",
        "me60-70": "pool round",
    }

    team = (
        '<comps><comp org="o" evt="e" compe="teq" sexe="m" arme="s" estindividuelle="0" '
        'etat="completed" date="2026 07 04"><titre>Sabre Hommes V1</titre></comp>'
        '<comp org="o" evt="e" compe="open" sexe="m" arme="s" estindividuelle="1" '
        'etat="tableau" date="2026 07 04"><titre>Sabre Hommes V2</titre></comp></comps>'
    )
    kept, skipped = parse_competition_list(team, org="o", event="e")
    assert kept == []
    assert {s["slug"]: s["reason"] for s in skipped} == {
        "teq": "team event",
        "open": "not completed (tableau)",
    }


def test_ENG_EVT_03_the_title_gives_gender_and_category_and_one_category_is_required():
    from python.scrapers.engarde import parse_competition_list

    budapest = (FIXTURES / "competitions_budapest.xml").read_text()
    kept, _skipped = parse_competition_list(budapest, org="hunfencing", event="2025_09_20_pbt")
    by_slug = {c["slug"]: c for c in kept}
    # Engarde's sexe attribute says f for "Men's Epee V4 (70)"; the published title wins.
    assert (by_slug["me70"]["gender"], by_slug["me70"]["category"]) == ("M", "V4")
    assert (by_slug["we70"]["gender"], by_slug["we70"]["category"]) == ("F", "V4")

    madrid = (FIXTURES / "competitions_madrid.xml").read_text()
    kept, skipped = parse_competition_list(madrid, org="aeve_esgrima", event="evf_madrid_2025")
    by_slug = {c["slug"]: c for c in kept}
    assert (by_slug["ef-2"]["gender"], by_slug["ef-2"]["category"]) == ("F", "V2")
    assert (by_slug["t_em-3"]["gender"], by_slug["t_em-3"]["category"]) == ("M", "V3")
    reasons = {s["slug"]: s["reason"] for s in skipped}
    assert reasons["em-3-4"] == "spans categories V3, V4"
    assert reasons["ff_all"] == "no category in the title"


class _FakeHttp:
    """Engarde's list for the list request, a classification page for any competition."""

    def __init__(self):
        self.list_xml = (FIXTURES / "competitions_crit26.xml").read_text()
        self.page = (FIXTURES / "competition_crit26_ehv2.html").read_text()
        self.urls: list[str] = []

    def get(self, url):
        self.urls.append(url)
        resp = MagicMock()
        resp.raise_for_status.return_value = None
        resp.text = self.list_xml if "getCompeForDisplay.php" in url else self.page
        return resp


def test_ENG_EVT_04_the_runner_expands_an_engarde_tournament_into_annotated_brackets():
    from python.pipeline.review_cli import Fetcher

    http = _FakeHttp()
    parsed, skipped = Fetcher(http_client=http).fetch_event_url_with_skips(
        "https://engarde-service.com/tournament/fencingaddict/crit26"
    )

    assert len(parsed) == 24
    ehv2 = next(p for p in parsed if p.source_url.endswith("/crit26/ehv2"))
    assert (ehv2.weapon, ehv2.gender, ehv2.category_hint) == ("EPEE", "M", "V2")
    assert ehv2.tournament_name == "Épée Hommes V2"
    assert ehv2.parsed_date == date(2026, 7, 5)
    assert ehv2.raw_pool_size == 72
    assert [r.place for r in ehv2.results if r.fencer_country == "POL"] == [18, 59, 66]

    assert sorted(s["name"] for s in skipped) == [
        "Epée Dames V3-V4 Poules",
        "Fleuret Dames V3-V4 (Poules)",
        "Sabre Dames V3-V4 (Poules)",
    ]
    assert {s["weapon"] for s in skipped} == {"EPEE", "FOIL", "SABRE"}
    assert all(s["reason"] == "pool round" for s in skipped)
    # One list request, then one page per final; the pool rounds are not fetched.
    assert sum("getCompeForDisplay.php" in u for u in http.urls) == 1
    assert len(http.urls) == 25


def test_ENG_EVT_05_the_header_count_is_the_bracket_including_a_fencer_without_a_place():
    """V2 men's foil: "Classement général (33 tireurs)", 32 places and one DNS
    fencer listed without a place. EVF scores it as 33 (entry 33)."""
    from python.scrapers.engarde import parse_html

    page = (FIXTURES / "competition_crit26_fhv2.html").read_text()
    parsed = parse_html(page, source_url="https://engarde-service.com/competition/x/y/fhv2")

    assert len(parsed.results) == 32
    assert parsed.raw_pool_size == 33
    assert [r.place for r in parsed.results if r.fencer_country == "POL"] == [29]
