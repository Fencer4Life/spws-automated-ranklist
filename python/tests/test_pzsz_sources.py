"""PZSz calendar sources — the listing and the home page (ADR-116 §7; RTM
PZSZ.SRC.01-05).

The calendar run reads two public sources. The listing
(kalendarium-zawodow) carries each event's row — city, dates — and its letter
links (cell with a "Komunikat organizatora z dnia DD_MM_YYYY" icon; several
possible, the newest by that date is pass 0's candidate). The home page's
"Najbliższe zawody" table is a second source for the next events' city and
dates. These parsers are pure; the fetch is the browser (§6).
"""

from __future__ import annotations

from datetime import date
from pathlib import Path

from python.scrapers.pzsz_sources import (
    LetterLink,
    newest_letter,
    parse_home_page,
    parse_letter_title_date,
    parse_listing,
)

FIXTURES = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


class TestLetterTitleDate:
    def test_reads_the_date_from_a_komunikat_title(self):
        """PZSZ.SRC.02: 'z dnia DD_MM_YYYY', one or two digit day and month."""
        assert parse_letter_title_date("Komunikat organizatora z dnia 30_04_2026") == date(
            2026, 4, 30
        )
        assert parse_letter_title_date("Komunikat organizatora z dnia 8_04_2026") == date(
            2026, 4, 8
        )

    def test_a_title_without_a_date_is_none(self):
        """PZSZ.SRC.02: no date in the title → undated, never a guess."""
        assert parse_letter_title_date("Komunikat organizatora") is None


class TestNewestLetter:
    def test_picks_the_newest_dated_link(self):
        """PZSZ.SRC.02: several letters → the newest by its title date."""
        links = [
            LetterLink("https://pzszerm.pl/test/fileDownload.php?fileId=old", date(2026, 4, 8)),
            LetterLink("https://pzszerm.pl/test/fileDownload.php?fileId=new", date(2026, 4, 30)),
        ]
        chosen = newest_letter(links)
        assert chosen is not None and chosen.url.endswith("fileId=new")

    def test_an_undated_link_never_beats_a_dated_one(self):
        """PZSZ.SRC.02: a dated letter wins over an undated one."""
        links = [
            LetterLink("https://pzszerm.pl/test/fileDownload.php?fileId=undated", None),
            LetterLink("https://pzszerm.pl/test/fileDownload.php?fileId=dated", date(2026, 1, 1)),
        ]
        chosen = newest_letter(links)
        assert chosen is not None and chosen.url.endswith("fileId=dated")

    def test_no_links_is_none(self):
        assert newest_letter([]) is None


class TestListing:
    def test_rows_carry_the_same_events_and_their_letter_links(self):
        """PZSZ.SRC.01: every listing row is parsed with its city, dates and
        newest letter link; the count matches the base calendar parse."""
        from python.scrapers.pzsz_calendar import parse_calendar_html

        html = _read("pzsz_calendar_pps_2025_2026.html")
        rows = parse_listing(html)
        assert len(rows) == len(parse_calendar_html(html))
        assert rows, "the fixture has rows"
        for r in rows:
            assert r.id_pzsz_event > 0
            if r.letter is not None:
                assert "fileDownload.php" in r.letter.url
                assert r.letter.url.startswith("https://pzszerm.pl/")

    def test_a_known_letter_is_dated_from_its_title(self):
        """PZSZ.SRC.02: the letter titled 'z dnia 30_04_2026' is dated so."""
        rows = parse_listing(_read("pzsz_calendar_pps_2025_2026.html"))
        letters = [r.letter for r in rows if r.letter is not None]
        dated = [link for link in letters if link.dated is not None]
        assert dated, "at least one row has a dated letter"
        assert all(isinstance(link.dated, date) for link in dated)


class TestHomePage:
    def test_reads_the_upcoming_table_only(self):
        """PZSZ.SRC.03: the 'Najbliższe zawody' table is the source; the
        'Zakończone zawody' table (past events) is ignored."""
        rows = parse_home_page(_read("pzsz_home_najblizsze.html"))
        ids = {r.id_pzsz_event for r in rows}
        assert 4581 in ids and 4596 in ids  # upcoming
        assert 4588 not in ids  # the finished Poznań event

    def test_each_row_has_id_name_dates_and_city(self):
        """PZSZ.SRC.03-04: id, dates (normalised) and the city from the name
        suffix — for pass 1 (city) and pass 4 (dates)."""
        by_id = {r.id_pzsz_event: r for r in parse_home_page(_read("pzsz_home_najblizsze.html"))}
        assert by_id[4581].dt_start == "2026-10-24"
        assert by_id[4581].dt_end == "2026-10-24"
        assert by_id[4581].city == "Gdańsk"
        assert by_id[4596].dt_end == "2026-10-25"
        assert by_id[4596].city == "Szczecin"
        assert by_id[4700].city == "Oborniki Śląskie"  # a two-word city before a comma
