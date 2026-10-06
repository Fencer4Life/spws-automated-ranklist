"""The PZSz start-list reader (ADR-111 §3; RTM PZSZ.SL.01–02).

FencingTimeLive gives a PZSz field's places but no birth year. The PZSz
tournament page lists every starter with a birth date, and its year is the
birth year the admission compares. The reader is pure: it reads HTML and
never fetches.

The two start-list fixtures keep the markup of Poznań's pages
(turniej 10628 and 10629, read 2026-10-06) with synthetic people, because the
repository is public. The event-page fixture is verbatim.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path

import pytest

from python.scrapers.pzsz_start_list import (
    PzszPageError,
    PzszTournament,
    Starter,
    parse_event_tournaments,
    parse_start_list,
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
        assert by_name["Wzorcowy Jakub"] == Starter("Wzorcowy Jakub", date(2008, 6, 16))
        assert by_name["Wzorcowy Jakub"].birth_year == 2008
        assert by_name["Przykładowy Jan"].birth_date == date(1971, 2, 15)
        women = parse_start_list(_read("pzsz_start_list_sabre_women.html"))
        assert Starter("TESTOWSKA Marta", date(2007, 7, 26)) in women
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
