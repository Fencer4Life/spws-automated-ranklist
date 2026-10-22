"""Golden letters for the PZSz reader (ADR-116 §9; RTM PZSZ.LET.GOLDEN).

ADR-078 forbids committing a real organizer letter to this public repository:
the files carry fencer names, bank-account numbers and organizers' private
phone and e-mail. So the golden set is **PII-free and reproduces the shapes**:
each case is modelled on a real 2024-2027 letter whose extraction was verified
against the throwaway corpus (29 letters, zero wrong — recorded in ADR-116),
with invented clubs, streets and people. Every documented trap of plan §4
appears in at least one case, and the expected value is exact: a wrong value is
a test failure, abstention is explicit.

The same bases feed the mutation suite (``test_pzsz_letter_mutations``), which
perturbs them twenty-odd ways and asserts the reader never emits a *wrong*
value — it may abstain, never guess.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from python.scrapers.pzsz_letter import LetterContext

S26 = ("2026-09-01", "2027-08-31")


@dataclass(frozen=True)
class Golden:
    name: str
    traps: str
    text: str
    ctx: LetterContext
    has_text: bool = True
    city_match: bool | None = None
    address: str | None = None
    address_candidates: tuple[str, ...] = ()
    fee: str | None = None
    fee_candidates: tuple[str, ...] = ()
    dt_start: str | None = None
    dt_end: str | None = None
    notes: tuple[str, ...] = field(default_factory=tuple)


def _ctx(city: str, start: str) -> LetterContext:
    return LetterContext(city=city, dt_start=start, season_start=S26[0], season_end=S26[1])


GOLDEN: tuple[Golden, ...] = (
    Golden(
        name="oneline_hall_street_postcode",
        traps="T1 payee address, T5 entrance clause, one-line venue",
        text=(
            "POLSKI ZWIĄZEK SZERMIERCZY\n"
            "KOMUNIKAT ORGANIZACYJNY\n"
            "Puchar Polski Seniorów w szpadzie\n\n"
            "Miejsce zawodów (dokładny adres):\n\n"
            "Hala lekkoatletyczna AZS Poznań, ul. Pułaskiego 30, 60-995 Poznań\n"
            "(wjazd od ul. Cichej)\n\n"
            "Data:\n4 października 2026 r. (niedziela)\n\n"
            "Opłata startowa: 100 zł od zawodnika\n\n"
            "Wpłaty na konto organizatora:\n"
            "Klub Sportowy AZS Poznań\n"
            "ul. Noskowskiego 25, 61-705 Poznań\n"
            "Nr konta: 44 1090 1359 0000 0001 1466 1239\n"
            "Tytułem: nazwa klubu + liczba zawodników\n"
        ),
        ctx=_ctx("Poznań", "2026-10-04"),
        city_match=True,
        address="Hala lekkoatletyczna AZS Poznań, ul. Pułaskiego 30, 60-995 Poznań",
        fee="100",
        dt_start="2026-10-04",
        dt_end="2026-10-04",
    ),
    Golden(
        name="split_hall_street_other_city_club",
        traps="T3 other-city organizer, T6 hall split, T7 street split, no postcode",
        text=(
            "KOMUNIKAT\n"
            "Organizator:\n"
            "Dolnośląski Klub Szermierczy KOLEJARZ\n"
            "50-450 Wrocław, ul. Krasińskiego 30 B\n"
            "Miejsce zawodów     - Hala Sportowa Ośrodka Sportu i Rekreacji w\n"
            "Obornikach Śląskich, ul. Józefa\n"
            "Poniatowskiego 22\n"
            "Data - 20 września 2026 r.\n"
            "Opłata startowa - 50 zł od zawodnika\n"
        ),
        ctx=_ctx("Oborniki", "2026-09-20"),
        city_match=None,
        address=(
            "Hala Sportowa Ośrodka Sportu i Rekreacji w Obornikach Śląskich, "
            "ul. Józefa Poniatowskiego 22"
        ),
        fee="50",
        dt_start="2026-09-20",
        dt_end="2026-09-20",
    ),
    Golden(
        name="street_and_postcode_no_hall",
        traps="T8 no hall, T9 space in house number",
        text=(
            "KOMUNIKAT\n"
            "Miejsce zawodów (dokładny adres):\n\n"
            "ul. Dworcowa 2A, 62-510 Konin\n\n"
            "Data: 14 marca 2027 r.\n"
            "Startowe: 80 zł od zawodnika\n"
        ),
        ctx=_ctx("Konin", "2027-03-14"),
        city_match=True,
        address="ul. Dworcowa 2A, 62-510 Konin",
        fee="80",
        dt_start="2027-03-14",
        dt_end="2027-03-14",
    ),
    Golden(
        name="hall_street_no_postcode",
        traps="no postcode (city unconfirmable), label with colon",
        text=(
            "KOMUNIKAT\n"
            "Obiekt: Gdańska Szkoła Szermierki, ul. VII Dwór 7\n\n"
            "Termin zawodów: 24 października 2026 r.\n"
            "Opłata startowa wynosi 100 zł od osoby\n"
        ),
        ctx=_ctx("Gdańsk", "2026-10-24"),
        city_match=None,
        address="Gdańska Szkoła Szermierki, ul. VII Dwór 7",
        fee="100",
        dt_start="2026-10-24",
        dt_end="2026-10-24",
    ),
    Golden(
        name="label_without_separator",
        traps="label with no separator before the value",
        text=(
            "KOMUNIKAT\n"
            "Miejsce zawodów Hala Sportowa AWF w Poznaniu / hala gier / ul. Królowej Jadwigi 27\n"
            "Data 11 października 2026\n"
            "Wpisowe 100 zł\n"
        ),
        ctx=_ctx("Poznań", "2026-10-11"),
        city_match=None,
        address="Hala Sportowa AWF w Poznaniu / hala gier / ul. Królowej Jadwigi 27",
        fee="100",
        dt_start="2026-10-11",
        dt_end="2026-10-11",
    ),
    Golden(
        name="date_range_two_days",
        traps="T17 month-name range, D5 start+end",
        text=(
            "KOMUNIKAT\n"
            "Miejsce zawodów: Hala Sportowa MOSRiR Szczecin, ul. Narutowicza 17, 70-240 Szczecin\n"
            "w dniach 24 - 25 października 2026 r.\n"
            "Opłata startowa: 100 zł\n"
        ),
        ctx=_ctx("Szczecin", "2026-10-24"),
        city_match=True,
        address="Hala Sportowa MOSRiR Szczecin, ul. Narutowicza 17, 70-240 Szczecin",
        fee="100",
        dt_start="2026-10-24",
        dt_end="2026-10-25",
    ),
    Golden(
        name="deadline_not_event_date",
        traps="T14 payment deadline, T15 times — only the event date is read",
        text=(
            "KOMUNIKAT\n"
            "Miejsce zawodów: Hala Miejska, ul. Sportowa 5, 00-100 Warszawa\n"
            "Zgłoszenia do dnia 1 października 2026 r.\n"
            "Opłatę startową wpłacić na konto do dnia 5 października 2026 r.\n"
            "Zawody odbędą się 11 października 2026 r. o godz. 10.00\n"
            "Startowe: 90 zł od zawodnika\n"
        ),
        ctx=_ctx("Warszawa", "2026-10-11"),
        city_match=True,
        address="Hala Miejska, ul. Sportowa 5, 00-100 Warszawa",
        fee="90",
        dt_start="2026-10-11",
        dt_end="2026-10-11",
    ),
    Golden(
        name="no_text_scan",
        traps="T22 scanned image, no extractable text",
        text="",
        ctx=_ctx("Kraków", "2026-11-15"),
        has_text=False,
    ),
    Golden(
        name="two_individual_fee_candidates",
        traps="two different individual PLN amounts — abstain, report both",
        text=(
            "KOMUNIKAT\n"
            "Miejsce zawodów: Hala Sportowa, ul. Olimpijska 1, 40-100 Katowice\n"
            "Data: 18 października 2026 r.\n"
            "Startowe dla seniorów: 120 zł od zawodnika\n"
            "Startowe dla juniorów: 80 zł od zawodnika\n"
        ),
        ctx=_ctx("Katowice", "2026-10-18"),
        city_match=True,
        address="Hala Sportowa, ul. Olimpijska 1, 40-100 Katowice",
        fee=None,
        fee_candidates=("120", "80"),
        dt_start="2026-10-18",
        dt_end="2026-10-18",
        notes=("fee: two candidates",),
    ),
    Golden(
        name="wrong_city_in_venue_postcode",
        traps="T20 venue postcode names a different city than the calendar",
        text=(
            "KOMUNIKAT\n"
            "Miejsce zawodów: Hala Sportowa, ul. Lipowa 3, 20-400 Lublin\n"
            "Data: 25 października 2026 r.\n"
            "Opłata startowa: 70 zł\n"
        ),
        ctx=_ctx("Rzeszów", "2026-10-25"),
        city_match=False,
        address="Hala Sportowa, ul. Lipowa 3, 20-400 Lublin",
        fee="70",
        dt_start="2026-10-25",
        dt_end="2026-10-25",
    ),
    Golden(
        name="fee_section_without_amount",
        traps="T19 fee section states no amount — abstain",
        text=(
            "KOMUNIKAT\n"
            "Miejsce zawodów: Hala Sportowa, ul. Morska 12, 81-200 Gdynia\n"
            "Data: 8 listopada 2026 r.\n"
            "Opłata startowa dokonywana jest gotówką w biurze zawodów.\n"
        ),
        ctx=_ctx("Gdynia", "2026-11-08"),
        city_match=True,
        address="Hala Sportowa, ul. Morska 12, 81-200 Gdynia",
        fee=None,
        dt_start="2026-11-08",
        dt_end="2026-11-08",
    ),
    Golden(
        name="tripled_glyphs_and_letter_spacing",
        traps="T11 letter-spaced label, T12 tripled glyphs, T13 footnote digit",
        text=(
            "KKKOOOMMMUUUNNNIIIKKKAAATTT\n"
            "M i e j s c e   z a w o d ó w :\n"
            "Hala Sportowa, ul. Zielona 8, 50-500 Wrocław\n"
            "Data: 29 listopada 2026 r.\n"
            "Startowe3: 60 zł od zawodnika\n"
        ),
        ctx=_ctx("Wrocław", "2026-11-29"),
        city_match=True,
        address="Hala Sportowa, ul. Zielona 8, 50-500 Wrocław",
        fee="60",
        dt_start="2026-11-29",
        dt_end="2026-11-29",
    ),
)
