"""The PZSz organizer-letter reader (ADR-116 §8-§9; RTM PZSZ.LET.*).

The reader is structure-agnostic: it normalises both pypdf text views, segments
at labels, guards relevance, and runs four passes that abstain rather than
guess. These tests build it from the documented shapes and traps (plan §4) and,
in the golden set, against the 31 real letters (masked).

This file is grown pass by pass, test-first. Date grammar first (pass 4): the
eleven date shapes of trap T17 and the non-dates of T15.
"""

from __future__ import annotations

from datetime import date

from python.scrapers.pzsz_letter import (
    _normalise,
    find_address,
    read_fee,
    scan_amounts,
    scan_dates,
    segment,
)


def _addr(raw: str, *, city: str) -> tuple[str | None, list[str]]:
    found, candidates = find_address(segment(_normalise(raw)), held_city=city)
    return (found.value if found else None), candidates


def _dates(text: str, **kw) -> set[date]:
    return {h.date for h in scan_dates(text, **kw)}


class TestScanDatesShapes:
    def test_dotted_day_month_year(self):
        assert _dates("Data: 24.10.2026 r.") == {date(2026, 10, 24)}

    def test_polish_month_name(self):
        assert _dates("4 października 2026 r. (niedziela)") == {date(2026, 10, 4)}

    def test_month_name_range(self):
        assert _dates("w dniach 24 - 25 października 2026 r.") == {
            date(2026, 10, 24),
            date(2026, 10, 25),
        }

    def test_month_name_and(self):
        assert _dates("24 i 25 października 2026") == {date(2026, 10, 24), date(2026, 10, 25)}

    def test_od_do_month(self):
        assert _dates("od 28 do 31 maja 2026") == {date(2026, 5, 28), date(2026, 5, 31)}

    def test_numeric_range_shared_month_year(self):
        assert _dates("7-8.12.2024") == {date(2024, 12, 7), date(2024, 12, 8)}

    def test_numeric_range_en_dash(self):
        assert _dates("Katowice 08–09.03.2025") == {date(2025, 3, 8), date(2025, 3, 9)}

    def test_dotted_range_each_with_month(self):
        assert _dates("19.10. – 20.10.2024 r.") == {date(2024, 10, 19), date(2024, 10, 20)}

    def test_slash_form(self):
        assert _dates("10/05/2025") == {date(2025, 5, 10)}

    def test_iso_form(self):
        assert _dates("2026-05-29") == {date(2026, 5, 29)}

    def test_roman_month(self):
        assert _dates("24.X.2026 r.") == {date(2026, 10, 24)}

    def test_glued_weekday_and_city_title(self):
        assert _dates("29.05.2026(piątek)") == {date(2026, 5, 29)}
        assert _dates("POZNAŃ 14.03.2026") == {date(2026, 3, 14)}
        assert _dates("SZPADA KOBIET 08.03.2025") == {date(2025, 3, 8)}

    def test_bare_day_month_takes_the_default_year(self):
        """T17: 'dd.mm.' with no year borrows the year from the held start."""
        assert _dates("eliminacje 05.12.", default_year=2026) == {date(2026, 12, 5)}

    def test_a_bare_day_month_without_a_default_year_is_not_read(self):
        assert _dates("05.12.") == set()


class TestScanDatesNonDates:
    def test_a_bare_number_after_godz_is_a_time(self):
        assert _dates("Godz. 900") == set()

    def test_a_time_with_a_decimal_is_not_a_date(self):
        """T15: 10.00 and 15.00-15.30 are times — month 00 is no month."""
        assert _dates("początek godz. 10.00.") == set()
        assert _dates("15.00-15.30") == set()

    def test_a_time_with_a_colon_is_not_a_date(self):
        assert _dates("9:30-11:30") == set()

    def test_a_day_month_time_near_godz_is_not_a_date(self):
        """T15: 'godz. 9.05' is five past nine, not the 9th of May."""
        assert _dates("godz. 9.05") == set()

    def test_an_impossible_calendar_date_is_refused(self):
        assert _dates("31.02.2026") == set()


class TestFeeGrammar:
    def test_amount_shapes_are_read_with_their_currency(self):
        """T18: the fourteen fee shapes; the value is the whole-złoty integer."""
        cases = {
            "100 zł od zawodnika": (100, "PLN"),
            "100zł": (100, "PLN"),
            "100,00 zł": (100, "PLN"),
            "50.- zł": (50, "PLN"),
            "50 zł.": (50, "PLN"),
            "100 PLN": (100, "PLN"),
            "40 €": (40, "EUR"),
            "1200 euro": (1200, "EUR"),
        }
        for text, (value, currency) in cases.items():
            amounts = scan_amounts(text)
            assert amounts, text
            assert (amounts[0].value, amounts[0].currency) == (value, currency), text

    def test_the_individual_pln_fee_is_chosen(self):
        """D4: the individual PLN amount, euro and team excluded."""
        found, candidates = read_fee("Startowe: 100 zł / 25 euro - indywidualnie")
        assert found == "100" and candidates == []

    def test_the_team_pln_fee_is_not_the_individual_one(self):
        """D4: '400 zł / 100 euro - drużynowo' is a team line; nothing individual."""
        found, candidates = read_fee("Startowe drużynowe: 400 zł / 100 euro - drużynowo")
        assert found is None and candidates == []

    def test_a_payee_prize_and_deadline_are_not_fees(self):
        """T1/T14/T18: a prize (euro, 'miejsce') and a payment deadline are not
        the entry fee; neither is a team amount in parentheses."""
        assert read_fee("1 miejsce 1200 euro")[0] is None
        assert read_fee("na konto do dnia 13.03.2026")[0] is None
        assert read_fee("( drużyna 400,00 zł )")[0] is None

    def test_od_zawodnika_marks_the_individual_fee(self):
        assert read_fee("w / kwocie 100,00 zł od zawodnika")[0] == "100"
        assert read_fee("– 50 zł/uczestnik")[0] == "50"

    def test_a_fee_section_with_no_amount_is_not_stated(self):
        """T19: a fee section naming no amount abstains, never guesses."""
        found, candidates = read_fee("Opłata startowa dokonywana jest gotówką w biurze zawodów")
        assert found is None and candidates == []

    def test_two_different_individual_amounts_are_two_candidates(self):
        found, candidates = read_fee("Startowe 80 zł od zawodnika\nStartowe 120 zł od zawodnika")
        assert found is None and sorted(candidates) == ["120", "80"]

    def test_an_absurd_amount_is_outside_the_sanity_range(self):
        """1-500 PLN: a four-figure 'fee' is a prize or an account number."""
        assert read_fee("1200 zł od zawodnika")[0] is None


class TestNormalise:
    def test_tripled_glyphs_collapse(self):
        """T12: a word whose every run is 2-3 long collapses to one glyph each."""
        assert _normalise("PPPUUUCCCHHHAAARRR") == "PUCHAR"

    def test_a_normal_word_with_one_double_is_left_alone(self):
        assert _normalise("Mistrzostwa") == "Mistrzostwa"
        assert _normalise("klasy") == "klasy"

    def test_every_dash_becomes_a_hyphen(self):
        assert _normalise("24 – 25") == "24 - 25"
        assert _normalise("24—25") == "24-25"
        assert _normalise("24−25") == "24-25"

    def test_invisible_characters_and_nbsp(self):
        assert _normalise("Po\u00adznań") == "Poznań"  # soft hyphen
        assert _normalise("ul.\u00a0Długa") == "ul. Długa"  # no-break space

    def test_footnote_digit_glued_to_a_label_is_stripped(self):
        """T13: 'Startowe3' is the label with a footnote marker, not 'Startowe3'."""
        assert _normalise("Startowe3: 100 zł") == "Startowe: 100 zł"

    def test_hyphenation_across_a_line_is_rejoined(self):
        assert _normalise("Mistrzo-\nstwa") == "Mistrzostwa"

    def test_letter_spaced_words_rejoin_keeping_word_breaks(self):
        """T11: single letters spaced out rejoin; a double space keeps the word
        boundary, so a spaced label becomes the words the segmenter needs."""
        assert _normalise("M i e j s c e   z a w o d ó w :") == "Miejsce zawodów :"

    def test_short_letter_runs_are_left_alone(self):
        """Two or three spaced letters (initials, 'A B') are not letter-spacing."""
        assert _normalise("ul. A B 5") == "ul. A B 5"


class TestSegment:
    def test_a_label_opens_a_region_its_following_lines_inherit(self):
        lines = segment("Miejsce zawodów:\nHala AZS\nul. Długa 3")
        assert [ln.region for ln in lines] == ["venue", "venue", "venue"]

    def test_a_new_label_closes_the_previous_region(self):
        lines = segment("Miejsce zawodów:\nHala AZS\nOpłata startowa:\n100 zł")
        assert [ln.region for ln in lines] == ["venue", "venue", "fee", "fee"]

    def test_a_contact_line_and_the_two_above_it_are_contact(self):
        lines = segment("Organizator\nKlub AZS\nJan Kowalski\ntel. 600 100 200")
        assert [ln.region for ln in lines] == [
            "organizer",
            "contact",
            "contact",
            "contact",
        ]

    def test_text_before_the_first_heading_is_letterhead(self):
        lines = segment("Polski Związek Szermierczy\nKOMUNIKAT\nMiejsce zawodów:\nHala")
        assert lines[0].region == "letterhead"
        assert lines[2].region == "venue"

    def test_a_numbered_heading_still_opens_its_region(self):
        lines = segment("2. Miejsce zawodów\nHala AZS")
        assert [ln.region for ln in lines] == ["venue", "venue"]


class TestFindAddress:
    def test_one_line_venue_with_entrance_and_payee_trap(self):
        """Poznań: hall+street+postcode on one line; the entrance clause (T5) is
        dropped and the payee address in the account block (T1) is not chosen."""
        raw = (
            "KOMUNIKAT\n"
            "Miejsce zawodów (dokładny adres):\n\n"
            "Hala lekkoatletyczna AZS Poznań, ul. Pułaskiego 30, 60-995 Poznań\n"
            "(wjazd od ul. Cichej)\n\n"
            "Data:\n4 października 2026 r.\n\n"
            "Opłata startowa: 100 zł\n\n"
            "Organizacja Środowiskowa AZS w Poznaniu\n"
            "Ul. Noskowskiego 25, 61-705 Poznań\n"
            "Nr konta: 44 1090 1359 0000 0001 1466 1239\n"
            "Tytułem: Nazwa klubu\n"
        )
        value, candidates = _addr(raw, city="Poznań")
        assert value == "Hala lekkoatletyczna AZS Poznań, ul. Pułaskiego 30, 60-995 Poznań"
        assert candidates == []

    def test_street_and_postcode_without_a_hall(self):
        """Konin: no hall name, just the street and the postcode-city (T8/T9)."""
        raw = "Miejsce zawodów (dokładny adres):\n\nul. Dworcowa 2A, 62-510 Konin\n\nData:\n"
        value, _ = _addr(raw, city="Konin")
        assert value == "ul. Dworcowa 2A, 62-510 Konin"

    def test_hall_and_street_split_across_lines_other_city_club_rejected(self):
        """Oborniki: the hall name (T6) and the street (T7) span three lines;
        the organizer's Wrocław address (T3) must not win."""
        raw = (
            "KOMUNIKAT\n"
            "Organizator:\n"
            "Wrocławski Klub Szermierczy KOLEJARZ\n"
            "50-450 Wrocław, ul. Krasińskiego 30 B\n"
            "Miejsce zawodów     - Hala Sportowa Ośrodka Sportu i Rekreacji w\n"
            "Obornikach Śląskich, ul. Józefa\n"
            "Poniatowskiego 22\n"
            "Data - 20.12.2025 r.\n"
        )
        value, _ = _addr(raw, city="Oborniki")
        assert value == (
            "Hala Sportowa Ośrodka Sportu i Rekreacji w Obornikach Śląskich, "
            "ul. Józefa Poniatowskiego 22"
        )

    def test_a_venue_section_with_no_street_takes_nothing_from_the_account_block(self):
        """T22: the venue names only a hall; the only street is the payee's. The
        reader abstains rather than publish the account address."""
        raw = (
            "Miejsce zawodów: Hala Miejska\n"
            "Opłata startowa: 80 zł\n"
            "Wpłata na konto:\n"
            "Klub Sportowy\n"
            "ul. Bankowa 5, 00-100 Warszawa\n"
            "Nr konta: 11 2222 3333 4444\n"
        )
        value, candidates = _addr(raw, city="Warszawa")
        assert value is None and candidates == []
