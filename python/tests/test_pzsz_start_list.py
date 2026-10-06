"""The PZSz start-list reader (ADR-111 §3, ADR-112 §1; RTM PZSZ.SL.01–04).

FencingTimeLive gives a PZSz field's places but no birth year. The PZSz
tournament page lists every starter with a birth date, and its year is the
birth year the admission compares. The reader is pure: it reads HTML and
never fetches.

The two start-list fixtures keep the markup of Poznań's pages
(turniej 10628 and 10629, read 2026-10-06) with synthetic people, because the
repository is public. The event-page fixture is verbatim.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from python.scrapers.pzsz_start_list import (
    PZSZ_EVENT_PAGE,
    PzszPageError,
    PzszTournament,
    Starter,
    parse_event_tournaments,
    parse_start_list,
    read_event_start_lists,
)

FIXTURES = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


class TestStartList:
    def test_reads_every_starter_of_both_poznan_pages(self):
        """PZSZ.SL.01: 53 men and 46 women, the start list only — the final
        classification table further down the page is not read."""
        assert len(parse_start_list(_read("pzsz_start_list_sabre_men.html"))) == 53
        assert len(parse_start_list(_read("pzsz_start_list_sabre_women.html"))) == 46

    def test_each_starter_keeps_the_printed_name_and_the_birth_date(self):
        """PZSZ.SL.01: the name as printed (stray spaces trimmed) and the
        dd.mm.yyyy birth date; the birth year is that date's year."""
        men = parse_start_list(_read("pzsz_start_list_sabre_men.html"))
        by_name = {s.name: s for s in men}
        assert by_name["Wzorcowy Jakub"] == Starter("Wzorcowy Jakub", 2008)
        assert by_name["Przykładowy Jan"].birth_year == 1971
        women = parse_start_list(_read("pzsz_start_list_sabre_women.html"))
        assert Starter("TESTOWSKA Marta", 2007) in women
        assert all(s.name == s.name.strip() for s in men + women)

    def test_letter_case_is_kept_as_printed(self):
        """PZSZ.SL.01: the source prints some names in capitals; the reader
        does not fold them — matching folds case, the reader only reads."""
        men = parse_start_list(_read("pzsz_start_list_sabre_men.html"))
        assert any(s.name == s.name.upper() for s in men)
        assert any(s.name != s.name.upper() for s in men)


class TestEventTournaments:
    def test_lists_the_individual_tournaments_with_weapon_and_gender(self):
        """PZSZ.SL.01: the event page names each tournament's PZSz id, weapon
        and gender; the empty team table adds nothing."""
        assert parse_event_tournaments(_read("pzsz_event_poznan_tournaments.html")) == [
            PzszTournament(
                10628,
                "I PGE Puchar Polski seniorów w szabli mężczyzn - Poznań 2026/2027",
                "SABRE",
                "M",
            ),
            PzszTournament(
                10629,
                "I PGE Puchar Polski seniorów w szabli kobiet - Poznań 2026/2027",
                "SABRE",
                "F",
            ),
        ]


def _fetch(pages: dict[tuple[str, int], str]):
    """A fetch over saved pages, keyed (page, id); it records every call."""
    calls: list[tuple[str, dict]] = []

    def fetch(url: str, params: dict) -> str:
        calls.append((url, params))
        kind = "event" if url == PZSZ_EVENT_PAGE else "tournament"
        return pages[(kind, params["id"])]

    fetch.calls = calls  # type: ignore[attr-defined]
    return fetch


POZNAN = {
    ("event", 4588): "pzsz_event_poznan_tournaments.html",
    ("tournament", 10628): "pzsz_start_list_sabre_men.html",
    ("tournament", 10629): "pzsz_start_list_sabre_women.html",
}


class TestEventStartLists:
    def test_reads_the_start_list_of_every_tournament_of_the_event(self):
        """PZSZ.SL.01: the event page leads to each tournament's page; the
        start lists come back keyed by weapon and gender."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        lists = read_event_start_lists(4588, fetch)
        assert set(lists) == {("SABRE", "M"), ("SABRE", "F")}
        tournament, starters = lists[("SABRE", "M")]
        assert tournament.id_pzsz_tournament == 10628
        assert len(starters) == 53
        assert len(lists[("SABRE", "F")][1]) == 46
        assert fetch.calls[0] == (PZSZ_EVENT_PAGE, {"id": 4588})  # type: ignore[attr-defined]

    def test_one_unreadable_tournament_page_refuses_the_whole_event(self):
        """PZSZ.SL.02: the women's page answering with the JavaScript check
        refuses the event; no start list is returned for the men either."""
        pages = {k: _read(v) for k, v in POZNAN.items()}
        pages[("tournament", 10629)] = _read("pzsz_js_check.html")
        with pytest.raises(PzszPageError, match="JavaScript check"):
            read_event_start_lists(4588, _fetch(pages))


class TestUnreadablePage:
    def test_the_javascript_check_page_is_refused(self):
        """PZSZ.SL.02: pzszerm.pl sometimes answers with a JavaScript check
        instead of the page. The reader says so and returns nothing; it never
        tries to get past the check."""
        with pytest.raises(PzszPageError, match="JavaScript check"):
            parse_start_list(_read("pzsz_js_check.html"))
        with pytest.raises(PzszPageError, match="JavaScript check"):
            parse_event_tournaments(_read("pzsz_js_check.html"))

    def test_a_page_without_a_start_list_is_refused(self):
        """PZSZ.SL.02: no start-list table, no starters — never an empty list
        that would read as 'nobody matched'."""
        with pytest.raises(PzszPageError, match="no start list"):
            parse_start_list(_read("pzsz_event_poznan_tournaments.html"))

    def test_an_unreadable_birth_date_is_refused(self):
        """PZSZ.SL.02: a birth date that is not dd.mm.yyyy stops the read; a
        starter is never kept without a birth year."""
        html = _read("pzsz_start_list_sabre_men.html").replace("16.06.2008", "2008-06-16")
        with pytest.raises(PzszPageError, match="birth date"):
            parse_start_list(html)


class TestYearOnly:
    """PZSZ.SL.03-04 (ADR-112 §1, ADR-078 §1): a start list is kept as
    printed name and birth year. The birth date is read only to check it is
    a date; it is never kept, and the stored hash is of name and year."""

    def test_a_starter_holds_the_year_only(self):
        """PZSZ.SL.03: no birth date survives the parse."""
        men = parse_start_list(_read("pzsz_start_list_sabre_men.html"))
        assert all(set(vars(s)) == {"name", "birth_year"} for s in men)

    def test_an_impossible_date_is_still_refused(self):
        """PZSZ.SL.03: 31 February is not a birth date, so the year beside it
        is not trusted either."""
        html = _read("pzsz_start_list_sabre_men.html").replace("16.06.2008", "31.02.2008")
        with pytest.raises(PzszPageError, match="birth date"):
            parse_start_list(html)

    def test_the_hash_is_of_name_and_year(self):
        """PZSZ.SL.04: the run record's start-list hash is the stored form's."""
        import hashlib
        import json

        from python.pipeline.promotion.run_record import start_list_sha256

        starters = [Starter("Testowy Jan", 1971), Starter("Wzorcowa Anna", 2009)]
        text = json.dumps(
            [["Testowy Jan", 1971], ["Wzorcowa Anna", 2009]],
            sort_keys=True,
            ensure_ascii=False,
            separators=(",", ":"),
        )
        assert start_list_sha256(starters) == hashlib.sha256(text.encode()).hexdigest()
