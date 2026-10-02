"""OPH.EVT / DART.EVT / INTL.EVT — an Ophardt or d'Artagnan event page expands into its brackets.

doc/plans/evf-circuit-four-events-organiser-sources-plan-2026-10-02.html. Munich
2024, Munich 2025 and Chania 2026 publish on Ophardt (fencingworldwide); the
tournament page (``/{lang}/{id}-{year}/tournament/``) lists one competition per
weapon, gender and age band, each with a ``/results/`` page. Salzburg 2026
publishes on d'Artagnan; its ``index.html`` lists the competitions, combined
pool rounds included. Only individual single-category competitions are
brackets; anything else is skipped with a reason, never guessed (ADR-105).

An Ophardt page prints a competition's day and month ("08.12.:") and no year.
The year comes from the competition's results page, which prints when its
results were last transmitted ("Last transmission: 08.12.2024 13:02"): the
competition day is the latest one on or before that moment. The number in the
URL ("-2024") is Ophardt's season, not the year: Chania on 2 May 2026 is
``32819-2025``.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path

OPH = Path(__file__).parent / "fixtures" / "ophardt"
DART = Path(__file__).parent / "fixtures" / "dartagnan"
FWW = "https://www.fencingworldwide.com"
SALZBURG = "https://dartagnan.live/turniere/EuropeanVeteransCup_2026/de/index.html"


def _page(name: str) -> str:
    return (OPH / name).read_text(encoding="utf-8")


def test_OPH_EVT_01_a_tournament_page_lists_each_competition_with_weapon_gender_category():
    from python.scrapers.ophardt import parse_tournament_competitions

    kept, skipped = parse_tournament_competitions(
        _page("tournament_32812-2025_munich2025.html"), f"{FWW}/en/32812-2025/tournament/"
    )

    assert skipped == []
    assert len(kept) == 16
    by_id = {c["id"]: c for c in kept}
    assert by_id["903539-2025"] == {
        "id": "903539-2025",
        "weapon": "FOIL",
        "gender": "M",
        "category": "V1",
        "title": "Foil Men's O40",
        "day_month": (7, 12),
        "url": f"{FWW}/en/903539-2025/results/",
    }
    assert by_id["912301-2025"]["weapon"] == "SABRE"
    assert by_id["912301-2025"]["gender"] == "F"
    assert by_id["912301-2025"]["category"] == "V2"
    assert {(c["weapon"], c["gender"]) for c in kept} == {
        (w, g) for w in ("FOIL", "SABRE") for g in ("M", "F")
    }
    assert {c["category"] for c in kept} == {"V1", "V2", "V3", "V4"}


def test_OPH_EVT_02_the_three_event_pages_give_sixteen_brackets_each():
    from python.scrapers.ophardt import parse_tournament_competitions

    for name, tid, weapons in (
        ("tournament_30657-2024_munich2024.html", "30657-2024", {"FOIL", "SABRE"}),
        ("tournament_32812-2025_munich2025.html", "32812-2025", {"FOIL", "SABRE"}),
        ("tournament_32819-2025_chania2026.html", "32819-2025", {"EPEE", "SABRE"}),
    ):
        kept, skipped = parse_tournament_competitions(_page(name), f"{FWW}/en/{tid}/tournament/")
        assert (len(kept), skipped) == (16, []), name
        assert {c["weapon"] for c in kept} == weapons, name
        assert len({(c["weapon"], c["gender"], c["category"]) for c in kept}) == 16, name


def test_OPH_EVT_03_team_events_and_age_bands_outside_EVF_are_skipped_not_guessed():
    from python.scrapers.ophardt import parse_tournament_competitions

    def item(cid: str, kind: str, title: str) -> str:
        return (
            f'<li><a href="/en/{cid}/global/" class="dropdown-item"><small>07.12.:</small>'
            f'<span title="{kind}"><i></i></span> {title} </a></li>'
        )

    html = (
        "<ul>"
        + "".join(
            [
                item("1-2024", "Individual", "Foil Men&#039;s O40"),
                item("2-2024", "Team", "Foil Men&#039;s O40"),
                item("3-2024", "Individual", "Sabre Women&#039;s U23"),
                item("4-2024", "Individual", "Epee Men&#039;s O80"),
                item("5-2024", "Individual", "Epee Mixed O60"),
            ]
        )
        + "</ul>"
    )

    kept, skipped = parse_tournament_competitions(html, f"{FWW}/en/9-2024/tournament/")

    assert [c["id"] for c in kept] == ["1-2024"]
    assert {s["url"]: s["reason"] for s in skipped} == {
        f"{FWW}/en/2-2024/results/": "team event",
        f"{FWW}/en/3-2024/results/": "no EVF category (U23)",
        f"{FWW}/en/4-2024/results/": "no EVF category (O80)",
        f"{FWW}/en/5-2024/results/": "no single gender",
    }
    assert all(s["name"] for s in skipped)


def test_OPH_EVT_04_the_year_comes_from_the_results_page_never_from_the_url():
    from python.scrapers.ophardt import resolve_day_month, transmission_date

    munich = transmission_date(_page("results_903540-2024_munich_foil_men_v2.html"))
    chania = transmission_date(_page("results_920967-2025_chania_epee_women_v1.html"))
    assert munich == date(2024, 12, 8)
    assert chania == date(2026, 5, 2)
    assert munich is not None and chania is not None

    assert resolve_day_month((8, 12), munich) == date(2024, 12, 8)
    assert resolve_day_month((7, 12), munich) == date(2024, 12, 7)
    # Chania 2026's URL says 2025; its competition is in May 2026.
    assert resolve_day_month((2, 5), chania) == date(2026, 5, 2)
    # Results transmitted after New Year belong to the December before.
    assert resolve_day_month((31, 12), date(2027, 1, 2)) == date(2026, 12, 31)
    assert transmission_date("<p>no data yet</p>") is None


def test_DART_EVT_01_an_index_lists_single_category_competitions_and_skips_pool_rounds():
    from python.scrapers.dartagnan import list_dartagnan_competitions, parse_dartagnan_event_index

    html = (DART / "index.html").read_text(encoding="utf-8")
    kept, skipped = list_dartagnan_competitions(html, SALZBURG)

    assert len(kept) == 16
    assert kept[0] == {
        "id": "6687",
        "weapon": "EPEE",
        "gender": "M",
        "category": "V1",
        "title": "Men Epee V1",
        "rankings_url": SALZBURG.replace("index.html", "6687-rankings.html"),
    }
    assert sorted(s["name"] for s in skipped) == [
        "Men Epee V3/V4 Runde",
        "Men Foil V1/V2 Runde",
        "Men Foil V3/V4 Runde",
        "Women Epee V1/V2 Runde",
        "Women Epee V3/V4 Runde",
        "Women Foil V1/V2/V3/V4 Runde",
    ]
    assert {s["reason"] for s in skipped} == {"no single category"}
    # The existing index reader is unchanged.
    assert parse_dartagnan_event_index(html, SALZBURG) == [
        {k: v for k, v in c.items() if k != "title"} for c in kept
    ]


def _fetcher(served: dict[str, str]):
    from python.pipeline.review_cli import Fetcher

    f = Fetcher.__new__(Fetcher)
    f._get = lambda url: served[url]  # type: ignore[method-assign]
    return f


def test_DART_EVT_02_the_runner_reads_each_competition_never_the_index_as_a_bracket():
    index = (DART / "index.html").read_text(encoding="utf-8")
    rankings = (DART / "6687-rankings.html").read_text(encoding="utf-8")

    class Served(dict):
        def __missing__(self, url: str) -> str:
            assert url.endswith("-rankings.html"), url
            return rankings

    parsed, skipped = _fetcher(Served({SALZBURG: index})).fetch_event_url_with_skips(SALZBURG)

    assert len(parsed) == 16
    assert len(skipped) == 6
    first = parsed[0]
    assert (first.weapon, first.gender, first.category_hint) == ("EPEE", "M", "V1")
    assert first.source_url.endswith("/6687-rankings.html")
    assert first.tournament_name == "Men Epee V1"
    assert all(p.results for p in parsed)
    assert {(p.weapon, p.gender, p.category_hint) for p in parsed} == {
        (w, g, v) for w in ("EPEE", "FOIL") for g in ("M", "F") for v in ("V1", "V2", "V3", "V4")
    }


def test_INTL_EVT_01_the_runner_expands_an_ophardt_tournament_with_each_bracket_dated():
    url = f"{FWW}/en/30657-2024/tournament/"
    results = _page("results_903540-2024_munich_foil_men_v2.html")

    class Served(dict):
        def __missing__(self, u: str) -> str:
            assert u.endswith("/results/"), u
            return results

    parsed, skipped = _fetcher(
        Served({url: _page("tournament_30657-2024_munich2024.html")})
    ).fetch_event_url_with_skips(url)

    assert (len(parsed), skipped) == (16, [])
    by_url = {p.source_url: p for p in parsed}
    v2 = by_url[f"{FWW}/en/903540-2024/results/"]
    assert (v2.weapon, v2.gender, v2.category_hint) == ("FOIL", "M", "V2")
    assert v2.tournament_name == "Foil Men's O50"
    assert v2.parsed_date == date(2024, 12, 8)
    assert {p.parsed_date for p in parsed} == {date(2024, 12, 7), date(2024, 12, 8)}
    assert all(p.results for p in parsed)


def test_INTL_EVT_02_an_ophardt_results_page_is_still_one_bracket():
    url = f"{FWW}/en/903540-2024/results/"
    parsed, skipped = _fetcher(
        {url: _page("results_903540-2024_munich_foil_men_v2.html")}
    ).fetch_event_url_with_skips(url)

    assert (len(parsed), skipped) == (1, [])
    assert parsed[0].source_url == url
    assert parsed[0].results
