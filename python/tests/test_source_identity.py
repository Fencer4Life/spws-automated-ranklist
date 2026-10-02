"""
REPAIR.URL.01 — a source URL is written to an event only when it is that event.

doc/plans/international-data-repair-batch-1-2026-10-01.html: before an event
is re-ingested from its organiser's results, every URL in its result slots
(FR-98) is checked against the event: the source's date, its name and its
weapons must match. The URL stored for PEW3fs-2024-2025 (EVF Circuit Munich,
7–8 December 2024) opened "BVF 6 Weapon International 2025", held on 4–5
January 2025; staging from it would have filed another event's results under
Munich. That case is pinned here.

Tests: python/pipeline/source_identity.py, python/tools/set_event_source_urls.py.
"""

from __future__ import annotations

from datetime import date

import pytest

from python.pipeline.source_identity import (
    SourceIdentity,
    check_event_sources,
    event_weapons,
    read_source_identity,
)

MUNICH_2024 = {
    "id_event": 7,
    "txt_code": "PEW3fs-2024-2025",
    "txt_name": "PEW3",
    "txt_location": "Munich",
    "dt_start": "2024-12-07",
    "dt_end": "2024-12-08",
    "arr_weapons": ["FOIL", "SABRE"],
}

BVF_2025 = SourceIdentity(
    url="https://www.fencingtimelive.com/tournaments/eventSchedule/9CC8D1BC59084DC0852659F9B68D97DB",
    title="BVF 6 Weapon International 2025",
    text="BVF 6 Weapon International 2025 Event Schedule",
    dates=frozenset({date(2025, 1, 4), date(2025, 1, 5)}),
    weapons=frozenset({"EPEE", "FOIL", "SABRE"}),
)

MUNICH_OPHARDT = SourceIdentity(
    url="https://www.fencingworldwide.com/en/30001-2024/tournament/",
    title="EVF Circuit Memoriam Max Geuter",
    text="EVF Circuit Memoriam Max Geuter München (Munich) 07.12. - 08.12. foil sabre",
    dates=frozenset({date(2024, 12, 7), date(2024, 12, 8)}),
    weapons=frozenset({"FOIL", "SABRE"}),
)


class TestCheck:
    def test_the_matching_source_passes(self):
        """REPAIR.URL.01 a source with the event's dates, city and weapons
        passes with no problem."""
        assert check_event_sources(MUNICH_2024, [MUNICH_OPHARDT]) == {}

    def test_another_events_url_is_refused(self):
        """REPAIR.URL.01 the URL stored for Munich 2024 opens BVF 2025: the
        date and the name are both wrong, and both are reported."""
        problems = check_event_sources(MUNICH_2024, [BVF_2025])
        text = " ".join(problems[BVF_2025.url])
        assert "2025-01-04" in text and "2024-12-07" in text
        assert "Munich" in text

    def test_a_missing_weapon_is_refused(self):
        """REPAIR.URL.01 every weapon of the event must be at its sources;
        a sabre-only source cannot stand for a foil-and-sabre event."""
        sabre_only = SourceIdentity(
            url=MUNICH_OPHARDT.url,
            title=MUNICH_OPHARDT.title,
            text=MUNICH_OPHARDT.text,
            dates=MUNICH_OPHARDT.dates,
            weapons=frozenset({"SABRE"}),
        )
        problems = check_event_sources(MUNICH_2024, [sabre_only])
        assert any("FOIL" in p for p in problems["*"])

    def test_weapons_are_counted_over_all_sources(self):
        """REPAIR.URL.01 an event split over two URLs (one per day) passes
        when the two together hold all its weapons."""
        day1 = SourceIdentity(
            url="https://example.org/day1",
            title="EVF Circuit Munich",
            text="Munich",
            dates=frozenset({date(2024, 12, 7)}),
            weapons=frozenset({"FOIL"}),
        )
        day2 = SourceIdentity(
            url="https://example.org/day2",
            title="EVF Circuit Munich",
            text="Munich",
            dates=frozenset({date(2024, 12, 8)}),
            weapons=frozenset({"SABRE"}),
        )
        assert check_event_sources(MUNICH_2024, [day1, day2]) == {}

    def test_no_date_is_refused(self):
        """REPAIR.URL.01 a source that shows no date cannot be checked, so it
        is refused (fail closed)."""
        undated = SourceIdentity(
            url="https://engarde-service.com/tournament/x/y",
            title="Munich Open",
            text="Munich Open",
            dates=frozenset(),
            weapons=frozenset({"FOIL", "SABRE"}),
        )
        assert any("no date" in p for p in check_event_sources(MUNICH_2024, [undated])[undated.url])

    def test_a_city_alias_counts_as_the_name(self):
        """REPAIR.URL.01 the event's city may appear under an alias (München
        for Munich, Liege for Liège) or folded (no diacritics)."""
        alias_only = SourceIdentity(
            url=MUNICH_OPHARDT.url,
            title="EVF Circuit",
            text="GER München",
            dates=MUNICH_OPHARDT.dates,
            weapons=MUNICH_OPHARDT.weapons,
        )
        assert check_event_sources(MUNICH_2024, [alias_only]) == {}

    def test_the_country_a_championship_or_shared_words_count_as_the_name(self):
        """REPAIR.URL.01 organisers' pages often omit the city. The name also
        matches when the page names the event's country ("EVF Circuit in
        Poland" for Jabłonna), when a championship's page carries its own
        name (a world championship for IMSW), or when the event's name and the
        page's title share two distinctive words (Criterium Mondial)."""
        jablonna = {
            "txt_code": "PEW7es-2024-2025",
            "txt_name": "European Veterans Circuit – Jabłonna (POL)",
            "txt_location": "Jabłonna",
            "txt_country": "Poland",
            "dt_start": "2025-03-29",
            "dt_end": "2025-03-29",
            "arr_weapons": ["EPEE", "SABRE"],
        }
        in_poland = SourceIdentity(
            url="https://x/jab",
            title="EVF Circuit in Poland/ Puchar Europy Weteranów w szermierce",
            text="Event Schedule",
            dates=frozenset({date(2025, 3, 29)}),
            weapons=frozenset({"EPEE", "SABRE", "FOIL"}),
        )
        assert check_event_sources(jablonna, [in_poland]) == {}

        manama = {
            "txt_code": "IMSW-2025-2026",
            "txt_name": "IMSW",
            "txt_location": "Manama",
            "txt_country": "Bahrain",
            "dt_start": "2025-11-12",
            "dt_end": "2025-11-19",
            "arr_weapons": ["EPEE"],
        }
        worlds = SourceIdentity(
            url="https://x/wch",
            title="2025 Veteran World Championships",
            text="",
            dates=frozenset({date(2025, 11, 12)}),
            weapons=frozenset({"EPEE"}),
        )
        assert check_event_sources(manama, [worlds]) == {}
        assert check_event_sources({**manama, "txt_code": "PEW9-2025-2026"}, [worlds])

        paris = {
            "txt_code": "PEW10efs-2024-2025",
            "txt_name": "EVF Criterium Mondial Vétérans 2025",
            "txt_location": "Paris",
            "dt_start": "2025-07-05",
            "dt_end": "2025-07-06",
            "arr_weapons": ["EPEE"],
        }
        crit = SourceIdentity(
            url="https://x/crit",
            title="Criterium Mondial Vétérans 2025",
            text="",
            dates=frozenset({date(2025, 7, 5)}),
            weapons=frozenset({"EPEE"}),
        )
        assert check_event_sources(paris, [crit]) == {}

    def test_a_person_may_confirm_the_name_but_never_the_date(self):
        """REPAIR.URL.01 a page that names neither the city, the country nor
        the event (Guildford's FTL page is "BVF 6 Weapon International 2026")
        passes when a person confirms the name; the date and the weapons are
        still checked, so BVF 2025 still cannot stand for Munich 2024."""
        guildford = {
            "txt_code": "PEW62efs-2025-2026",
            "txt_name": "EVF Circuit – Guildford (GBR)",
            "txt_location": "Guildford",
            "txt_country": "Great Britain",
            "dt_start": "2026-01-10",
            "dt_end": "2026-01-11",
            "arr_weapons": ["EPEE", "FOIL", "SABRE"],
        }
        bvf26 = SourceIdentity(
            url="https://x/bvf26",
            title="BVF 6 Weapon International 2026",
            text="Event Schedule",
            dates=frozenset({date(2026, 1, 10), date(2026, 1, 11)}),
            weapons=frozenset({"EPEE", "FOIL", "SABRE"}),
        )
        assert check_event_sources(guildford, [bvf26])
        assert check_event_sources(guildford, [bvf26], name_confirmed=True) == {}
        still = check_event_sources(MUNICH_2024, [BVF_2025], name_confirmed=True)
        assert any("2025-01-04" in p for p in still[BVF_2025.url])
        assert not any("Munich" in p for p in still[BVF_2025.url])

    def test_event_weapons_fall_back_to_the_code_letters(self):
        """REPAIR.URL.01 with no stored weapons, a PEW code's letters give
        them (ADR-046): PEW62efs is épée, foil and sabre."""
        assert event_weapons({"txt_code": "PEW62efs-2025-2026", "arr_weapons": None}) == {
            "EPEE",
            "FOIL",
            "SABRE",
        }
        assert event_weapons({"txt_code": "IMEW-2024-2025", "arr_weapons": ["EPEE"]}) == {"EPEE"}


FTL_SCHEDULE = """
<html><head><title>BVF 6 Weapon International 2025</title></head><body>
<h2>Event Schedule</h2>
<div>Saturday, January 4, 2025</div>
<a href="/events/view/EEC73796">Men's Epee Category 2</a>
<a href="/events/view/AB48ED10">Men's Foil Category 2</a>
<div>Sunday, January 5, 2025</div>
<a href="/events/view/D75459BD">Women's Sabre Category 3</a>
</body></html>
"""

OPHARDT_EVENT = """
<html><head><title>Fencing Worldwide</title></head><body>
<h1>EVF Circuit Memoriam Max Geuter</h1>
<ol class="breadcrumb"><li class="breadcrumb-item">München (GER)</li></ol>
<div><img src="/img/flags/ger.svg" /> GER München (Munich) <br /> 06.12. - 07.12. </div>
<table><tr><td>Foil</td></tr><tr><td>Sabre</td></tr></table>
</body></html>
"""

ENGARDE_EVENT = """
<html><head><title>engarde-service: fencing competitions managed with Engarde</title></head><body>
<div class="tounament-titles"><strong class="tounament-title">Stockholm International Veteran Open 2026</strong></div>
<div id="competitionsTab"><table><tbody id="table_comp"></tbody></table></div>
</body></html>
"""

FOURFENCE_EVENT = """
<html><head><title>2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 -</title></head>
<body><a>Spada Maschile</a><a>Fioretto Femminile</a><a>Sciabola Maschile</a></body></html>
"""

DARTAGNAN_EVENT = """
<html><head><title>European Veterans Cup 2026</title></head><body>
<h2>Men Epee V1</h2><p>Salzburg, 19.04.2026</p><h2>Women Foil V2</h2></body></html>
"""


class TestReaders:
    def test_ftl_schedule(self):
        """REPAIR.URL.01 an FTL event schedule gives its title, the day
        headings' dates and the weapons of its bracket names."""
        ident = read_source_identity(
            "https://www.fencingtimelive.com/tournaments/eventSchedule/9CC8D1BC", FTL_SCHEDULE
        )
        assert ident.title == "BVF 6 Weapon International 2025"
        assert ident.dates == {date(2025, 1, 4), date(2025, 1, 5)}
        assert ident.weapons == {"EPEE", "FOIL", "SABRE"}

    def test_ophardt_page_alone_shows_no_date(self):
        """REPAIR.URL.03 an Ophardt event page shows "06.12. - 07.12." with no
        year, and the number in its URL is Ophardt's season, not the year
        (Chania, 2 May 2026, is 32819-2025): alone, the page has no date and
        is refused. Its name and weapons are read."""
        ident = read_source_identity(
            "https://www.fencingworldwide.com/en/32812-2025/tournament/", OPHARDT_EVENT
        )
        assert ident.title == "EVF Circuit Memoriam Max Geuter"
        assert ident.dates == frozenset()
        assert ident.weapons == {"FOIL", "SABRE"}
        assert "münchen" in ident.text.lower()

    def test_engarde_has_a_title_and_no_date(self):
        """REPAIR.URL.01 an Engarde tournament page builds its competition
        list in JavaScript: the reader finds the title and no date, so the
        check refuses it until an Engarde reader exists."""
        ident = read_source_identity(
            "https://engarde-service.com/tournament/sthlm/vet2026", ENGARDE_EVENT
        )
        assert ident.title == "Stockholm International Veteran Open 2026"
        assert ident.dates == frozenset()

    def test_4fence_and_dartagnan(self):
        """REPAIR.URL.01 4fence carries the ISO date in its title and Italian
        weapon names; d'Artagnan a dd.mm.yyyy date."""
        nap = read_source_identity("https://www.4fence.it/FIS/Risultati/x/", FOURFENCE_EVENT)
        assert date(2026, 3, 8) in nap.dates
        assert nap.weapons == {"EPEE", "FOIL", "SABRE"}
        sal = read_source_identity(
            "https://dartagnan.live/turniere/EuropeanVeteransCup_2026/de/index.html",
            DARTAGNAN_EVENT,
        )
        assert sal.dates == {date(2026, 4, 19)}
        assert sal.weapons == {"EPEE", "FOIL"}


class _Db:
    """The two calls the tool makes, recorded."""

    def __init__(self, event: dict):
        self.event = event
        self.writes: list[tuple[int, list[str]]] = []

    def fetch_event_for_source_check(self, event_code: str) -> dict | None:
        return self.event if event_code == self.event["txt_code"] else None

    def set_event_source_urls(self, id_event: int, urls: list[str]) -> None:
        self.writes.append((id_event, urls))


class TestWrite:
    def test_nothing_is_written_when_a_url_is_another_event(self):
        """REPAIR.URL.01 the write is refused and nothing reaches the
        database when any URL fails the check; the error names each
        problem."""
        from python.tools.set_event_source_urls import set_event_source_urls

        db = _Db(MUNICH_2024)
        with pytest.raises(ValueError, match="2025-01-04"):
            set_event_source_urls(db, "PEW3fs-2024-2025", [BVF_2025.url], read=lambda u: BVF_2025)
        assert db.writes == []

    def test_matching_urls_replace_the_slots(self):
        """REPAIR.URL.01 matching URLs replace every result slot, in the
        order given, duplicates dropped; an old EVF link is not kept."""
        from python.tools.set_event_source_urls import set_event_source_urls

        db = _Db(MUNICH_2024)
        urls = [MUNICH_OPHARDT.url, MUNICH_OPHARDT.url]
        set_event_source_urls(db, "PEW3fs-2024-2025", urls, read=lambda u: MUNICH_OPHARDT)
        assert db.writes == [(7, [MUNICH_OPHARDT.url])]

    def test_a_confirmed_name_reaches_the_write(self):
        """REPAIR.URL.01 with the name confirmed, a page that does not name
        the event is written when its date and weapons match."""
        from python.tools.set_event_source_urls import set_event_source_urls

        unnamed = SourceIdentity(
            url=MUNICH_OPHARDT.url,
            title="Winter Tournament",
            text="",
            dates=MUNICH_OPHARDT.dates,
            weapons=MUNICH_OPHARDT.weapons,
        )
        db = _Db(MUNICH_2024)
        with pytest.raises(ValueError, match="names neither"):
            set_event_source_urls(db, "PEW3fs-2024-2025", [unnamed.url], read=lambda u: unnamed)
        set_event_source_urls(
            db, "PEW3fs-2024-2025", [unnamed.url], read=lambda u: unnamed, name_confirmed=True
        )
        assert db.writes == [(7, [unnamed.url])]

    def test_an_unknown_event_and_too_many_urls_are_refused(self):
        """REPAIR.URL.01 an unknown event code, no URL, or more than the five
        slots FR-98 allows, is refused before any fetch."""
        from python.tools.set_event_source_urls import set_event_source_urls

        db = _Db(MUNICH_2024)

        def no_fetch(u):
            raise AssertionError("fetched")

        with pytest.raises(ValueError, match="no event"):
            set_event_source_urls(db, "PEW3fs", [MUNICH_OPHARDT.url], read=no_fetch)
        with pytest.raises(ValueError, match="five"):
            set_event_source_urls(
                db, "PEW3fs-2024-2025", [f"https://x/{i}" for i in range(6)], read=no_fetch
            )
        with pytest.raises(ValueError, match="no URL"):
            set_event_source_urls(db, "PEW3fs-2024-2025", [], read=no_fetch)
        assert db.writes == []


# ---------------------------------------------------------------------------
# REPAIR.URL.02 — an Engarde tournament is read from its competition list
# ---------------------------------------------------------------------------

FIXTURES = __import__("pathlib").Path(__file__).parent / "fixtures" / "engarde"
CRIT26_URL = "https://engarde-service.com/tournament/fencingaddict/crit26"
CRIT26_PAGE = """
<html><head><title>engarde-service: fencing competitions managed with Engarde</title></head><body>
<div class="tounament-titles"><strong class="tounament-title">Criterium Mondial Vétérans 2026</strong></div>
<div id="competitionsTab"><table><tbody id="table_comp"></tbody></table></div>
</body></html>
"""
CRIT26 = {
    "id_event": 7314,
    "txt_code": "PEW10efs-2025-2026",
    "txt_name": "EVF Criterium Mondial Vétérans 2026",
    "txt_location": "Paris",
    "txt_country": "France",
    "dt_start": "2026-07-04",
    "dt_end": "2026-07-06",
    "arr_weapons": ["EPEE", "FOIL", "SABRE"],
}


class TestEngarde:
    def _list(self) -> str:
        return (FIXTURES / "competitions_crit26.xml").read_text(encoding="utf-8")

    def test_the_competition_list_gives_dates_weapons_and_city(self):
        """REPAIR.URL.02 Engarde builds its competition list in JavaScript, so
        the page alone shows no date (REPAIR.URL.01). The list it loads
        (getCompeForDisplay) gives each competition's date, weapon and city:
        the Criterium 2026 is held 4–6 July 2026 in Paris, in all three
        weapons."""
        ident = read_source_identity(CRIT26_URL, CRIT26_PAGE, competitions=self._list())
        assert ident.title == "Criterium Mondial Vétérans 2026"
        assert ident.dates == {date(2026, 7, 4), date(2026, 7, 5), date(2026, 7, 6)}
        assert ident.weapons == {"EPEE", "FOIL", "SABRE"}
        assert "paris" in ident.text.lower()
        assert check_event_sources(CRIT26, [ident]) == {}

    def test_another_edition_is_refused(self):
        """REPAIR.URL.02 the 2026 list does not pass for the 2025 edition
        (5 July 2025): its dates are a year later."""
        ident = read_source_identity(CRIT26_URL, CRIT26_PAGE, competitions=self._list())
        crit25 = {
            **CRIT26,
            "txt_code": "PEW10efs-2024-2025",
            "dt_start": "2025-07-05",
            "dt_end": "2025-07-05",
            "txt_name": "EVF Criterium Mondial Vétérans 2025",
        }
        problems = check_event_sources(crit25, [ident])
        assert any("2026-07-04" in p for p in problems[CRIT26_URL])

    def test_fetch_reads_the_page_and_its_competition_list(self, monkeypatch):
        """REPAIR.URL.02 the tool fetches both the tournament page and the
        competition list it loads, so the check sees the dates."""
        import httpx

        from python.scrapers.engarde import ENGARDE_LIST_URL
        from python.tools.set_event_source_urls import fetch_source_identity

        list_url = ENGARDE_LIST_URL.format(org="fencingaddict", event="crit26")
        served = {CRIT26_URL: CRIT26_PAGE, list_url: self._list()}
        fetched: list[str] = []

        def fake_get(url, **kwargs):
            fetched.append(url)
            return httpx.Response(200, text=served[url], request=httpx.Request("GET", url))

        monkeypatch.setattr(httpx, "get", fake_get)
        ident = fetch_source_identity(CRIT26_URL)
        assert fetched == [CRIT26_URL, list_url]
        assert check_event_sources(CRIT26, [ident]) == {}


OPH = __import__("pathlib").Path(__file__).parent / "fixtures" / "ophardt"
FWW = "https://www.fencingworldwide.com"
CHANIA_2026 = {
    "id_event": 8,
    "txt_code": "PEW8es-2025-2026",
    "txt_name": "EVF Circuit – Chania (GRE)",
    "txt_location": "Chania",
    "txt_country": "Greece",
    "dt_start": "2026-05-02",
    "dt_end": "2026-05-03",
    "arr_weapons": ["EPEE", "SABRE"],
}
MUNICH_2025 = {
    **MUNICH_2024,
    "txt_code": "PEW3fs-2025-2026",
    "dt_start": "2025-12-06",
    "dt_end": "2025-12-07",
}


def _oph(name: str) -> str:
    return (OPH / name).read_text(encoding="utf-8")


class TestOphardtYear:
    def test_the_results_page_fixes_the_year(self):
        """REPAIR.URL.03 with a competition's results page, which prints when
        its results were transmitted, each "dd.mm." of the event page gets
        its year: Chania's page reads 2–3 May 2026 and passes for Chania 2026."""
        ident = read_source_identity(
            f"{FWW}/en/32819-2025/tournament/",
            _oph("tournament_32819-2025_chania2026.html"),
            competitions=_oph("results_920967-2025_chania_epee_women_v1.html"),
        )
        assert ident.dates == {date(2026, 5, 2), date(2026, 5, 3)}
        assert ident.weapons == {"EPEE", "SABRE"}
        assert check_event_sources(CHANIA_2026, [ident]) == {}

    def test_last_years_edition_is_refused(self):
        """REPAIR.URL.03 Munich 2024's page (7–8 December 2024) never reads as
        December 2025: it is refused for Munich 2025."""
        ident = read_source_identity(
            f"{FWW}/en/30657-2024/tournament/",
            _oph("tournament_30657-2024_munich2024.html"),
            competitions=_oph("results_903540-2024_munich_foil_men_v2.html"),
        )
        assert ident.dates == {date(2024, 12, 7), date(2024, 12, 8)}
        assert check_event_sources(MUNICH_2024, [ident]) == {}
        problems = check_event_sources(MUNICH_2025, [ident])
        assert any("2024-12-07" in p for p in problems[ident.url])

    def test_fetch_reads_the_page_and_one_results_page(self, monkeypatch):
        """REPAIR.URL.03 the tool fetches the event page and the results page
        of its first competition, so the check sees the year."""
        import httpx

        from python.tools.set_event_source_urls import fetch_source_identity

        url = f"{FWW}/en/32819-2025/tournament/"
        first = f"{FWW}/en/920967-2025/results/"
        served = {
            url: _oph("tournament_32819-2025_chania2026.html"),
            first: _oph("results_920967-2025_chania_epee_women_v1.html"),
        }
        fetched: list[str] = []

        def fake_get(u, **kwargs):
            fetched.append(u)
            return httpx.Response(200, text=served[u], request=httpx.Request("GET", u))

        monkeypatch.setattr(httpx, "get", fake_get)
        ident = fetch_source_identity(url)
        assert fetched == [url, first]
        assert check_event_sources(CHANIA_2026, [ident]) == {}
