"""
Tests for the PZSz senior calendar scraper (pzszerm.pl).

Polish veterans also enter senior national competitions run by Polski Zwiazek
Szermierczy. This module covers the pure parsing and planning half of that
source: everything here reads a committed fixture and touches no network and no
database.

Plan test IDs pzsz.1-pzsz.24:
  pzsz.1   parse_calendar_html returns the six 2026/2027 PPS rows
  pzsz.2   every parsed row carries the full field set
  pzsz.3   a 70-row response raises: the cap truncates in silence
  pzsz.4   a complete response passes the cap assertion
  pzsz.5   normalise_date rejects an out-of-range year
  pzsz.6   a listing carrying a corrupt date raises rather than storing it
  pzsz.7   World Cup / Grand Prix / World Championship rows are rejected
  pzsz.8   a Weteran (W) row is rejected: those events are already ours
  pzsz.9   a row with no age category is rejected
  pzsz.10  both Seniorow and seniorow casings are accepted
  pzsz.11  our season window decides membership, not the PZSz season label
  pzsz.12  season_keys_for_window derives the pagination keys from our window
  pzsz.13  parse_round reads the Roman numeral; MPS has none
  pzsz.14  weapon_letters maps Floret / Szpada / Szabla
  pzsz.15  plan_event_codes produces the six announced codes
  pzsz.16  a gender-split round yields PPS4Me and PPS4We, not one colliding code
  pzsz.17  the diacritic fold absorbs the live 'mezczyzn' typo
  pzsz.18  two events resolving to one code raise rather than overwrite
  pzsz.19  an MPS code carries no round number
  pzsz.20  the invitation is found via the labelled section, as an absolute URL
  pzsz.21  'Brak komunikatow' yields no invitation
  pzsz.22  regression: the EVF '.pdf' suffix heuristic finds nothing here
  pzsz.23  the venue street address is extracted from the komunikat PDF
  pzsz.24  the deadline harvest is off and no registration URL is synthesised
"""

from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures"

PPS_2026_2027 = FIXTURES / "pzsz_calendar_pps_2026_2027.html"
PPS_2025_2026 = FIXTURES / "pzsz_calendar_pps_2025_2026.html"
PPS_2024_2025 = FIXTURES / "pzsz_calendar_pps_2024_2025.html"
CAPPED_70 = FIXTURES / "pzsz_calendar_capped_70.html"
DETAIL_NO_KOMUNIKAT = FIXTURES / "pzsz_event_no_komunikat.html"
DETAIL_WITH_KOMUNIKAT = FIXTURES / "pzsz_event_with_komunikat.html"
KOMUNIKAT_PDF = FIXTURES / "pzsz_komunikat_mps.pdf"

# The active SPWS season window, as tbl_season holds it.
SEASON_START = "2026-07-13"
SEASON_END = "2027-07-15"
SEASON_CODE = "SPWS-2026-2027"


class TestParsing:
    """pzsz.1-pzsz.2: the listing table."""

    def test_parses_the_six_announced_events(self):
        """pzsz.1: the narrowed PPS x season query yields exactly six rows."""
        from python.scrapers.pzsz_calendar import parse_calendar_html

        rows = parse_calendar_html(PPS_2026_2027.read_text(encoding="utf-8"))

        assert len(rows) == 6
        assert {row["id_pzsz_event"] for row in rows} == {4581, 4585, 4588, 4591, 4596, 4599}

    def test_every_row_carries_the_full_field_set(self):
        """pzsz.2: name, weapons, dates, location and provenance are all present."""
        from python.scrapers.pzsz_calendar import parse_calendar_html

        rows = parse_calendar_html(PPS_2026_2027.read_text(encoding="utf-8"))
        poznan = next(row for row in rows if row["id_pzsz_event"] == 4588)

        assert poznan["name"].startswith("I Puchar Polski seniorów w szabli")
        assert poznan["age_category"] == "Seniorzy (S)"
        assert poznan["weapons"] == ["SABRE"]
        assert poznan["dt_start"] == "2026-10-03"
        assert poznan["dt_end"] == "2026-10-03"
        assert poznan["location"] == "Poznań"
        assert poznan["txt_country"] == "PL"
        # The PZSz season label is captured as provenance only -- section 4.
        assert poznan["pzsz_season"] == "2026/2027"
        assert poznan["url_event"] == (
            "https://pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=4588"
        )


class TestTheSeventyRowCap:
    """pzsz.3-pzsz.4: the finding that shapes the whole scraper.

    Every broad query returns exactly 70 rows, truncated, with no pagination
    and no error. The default view renders descending and its earliest row is
    14.11.2026, so reading it loses all three round I events without any
    outward sign that anything is missing.
    """

    def test_a_capped_response_raises(self):
        """pzsz.3: exactly 70 rows is presumed truncated and must raise."""
        from python.scrapers.pzsz_calendar import (
            PzszTruncatedListingError,
            assert_not_truncated,
            parse_calendar_html,
        )

        rows = parse_calendar_html(CAPPED_70.read_text(encoding="utf-8"))
        assert len(rows) == 70

        with pytest.raises(PzszTruncatedListingError):
            assert_not_truncated(rows)

    def test_a_complete_response_passes(self):
        """pzsz.4: six rows is under the cap and passes untouched."""
        from python.scrapers.pzsz_calendar import assert_not_truncated, parse_calendar_html

        rows = parse_calendar_html(PPS_2026_2027.read_text(encoding="utf-8"))
        assert_not_truncated(rows)


class TestCorruptDates:
    """pzsz.5-pzsz.6: id 4307 carries an end date of 11.05.0251."""

    def test_normalise_date_rejects_an_out_of_range_year(self):
        """pzsz.5: 0251 is refused; a sane date passes."""
        from python.scrapers.pzsz_calendar import PzszSourceDataError, normalise_date

        assert normalise_date("03.10.2026") == "2026-10-03"

        with pytest.raises(PzszSourceDataError):
            normalise_date("11.05.0251")

    def test_a_listing_with_a_corrupt_date_raises(self):
        """pzsz.6: the corruption surfaces at parse time, never at write time."""
        from python.scrapers.pzsz_calendar import PzszSourceDataError, parse_calendar_html

        with pytest.raises(PzszSourceDataError):
            parse_calendar_html(PPS_2024_2025.read_text(encoding="utf-8"))


class TestScopeFilter:
    """pzsz.7-pzsz.10: which rows are national senior PPS/MPS events."""

    def test_rejects_international_events(self):
        """pzsz.7: World Cup, Grand Prix and World Championships carry the same
        age category on the same page, and are not ours."""
        from python.scrapers.pzsz_calendar import is_national_senior, parse_calendar_html

        rows = parse_calendar_html(CAPPED_70.read_text(encoding="utf-8"))
        kept = [row for row in rows if is_national_senior(row)]
        names = " ".join(row["name"] for row in kept)

        assert kept, "the capped listing does contain real PPS rows"
        assert "Świata" not in names
        assert "Grand Prix" not in names
        assert "Europy" not in names

    def test_rejects_a_veteran_row(self):
        """pzsz.8: PZSz's Weteran (W) category is SPWS's own MPW/PPW events."""
        from python.scrapers.pzsz_calendar import is_national_senior

        veteran = {
            "name": "Mistrzostwa Polski Weteranów w szpadzie - Warszawa 2026/2027",
            "age_category": "Weterani (W)",
        }
        assert not is_national_senior(veteran)

    def test_rejects_a_row_with_no_age_category(self):
        """pzsz.9: id 4709 leaves the age-category cell empty."""
        from python.scrapers.pzsz_calendar import is_national_senior

        assert not is_national_senior(
            {
                "name": "XI Turniej o Puchar Miasta Kalwarii Zebrzydowskiej",
                "age_category": "",
            }
        )

    def test_accepts_both_casings(self):
        """pzsz.10: one series carries both Seniorow and seniorow."""
        from python.scrapers.pzsz_calendar import is_national_senior

        for name in (
            "I Puchar Polski Seniorów w szabli kobiet i mężczyzn - Warszawa 2025/2026",
            "I Puchar Polski seniorów w szabli kobiet i mężczyzn - Poznań 2026/2027",
            "Mistrzostwa Polski Seniorów w szermierce - Warszawa 2025/2026",
        ):
            assert is_national_senior({"name": name, "age_category": "Seniorzy (S)"}), name

        assert not is_national_senior(
            {
                "name": "I Puchar Polski juniorów w szabli - Poznań 2026/2027",
                "age_category": "Juniorzy (JR)",
            }
        )


class TestSeasonMembership:
    """pzsz.11-pzsz.12: our season decides, theirs paginates."""

    def test_our_window_decides_not_their_label(self):
        """pzsz.11: an event PZSz labels 2025/2026 that runs after our season
        opens is ours; one they label 2026/2027 that runs past our close is not."""
        from python.scrapers.pzsz_calendar import belongs_to_season

        theirs_last_season_ours_this_one = {
            "dt_start": "2026-08-15",
            "dt_end": "2026-08-16",
            "pzsz_season": "2025/2026",
        }
        theirs_this_season_ours_next_one = {
            "dt_start": "2027-07-20",
            "dt_end": "2027-07-21",
            "pzsz_season": "2026/2027",
        }

        assert belongs_to_season(theirs_last_season_ours_this_one, SEASON_START, SEASON_END)
        assert not belongs_to_season(theirs_this_season_ours_next_one, SEASON_START, SEASON_END)

    def test_all_six_announced_events_fall_inside_our_window(self):
        """pzsz.11: the union, date-filtered, is exactly the six events."""
        from python.scrapers.pzsz_calendar import belongs_to_season, parse_calendar_html

        rows = parse_calendar_html(PPS_2026_2027.read_text(encoding="utf-8"))
        kept = [row for row in rows if belongs_to_season(row, SEASON_START, SEASON_END)]

        assert len(kept) == 6

    def test_season_keys_span_the_window(self):
        """pzsz.12: the keys are pagination, derived from the calendar years our
        own window touches -- and an unknown key returns zero rows, not 70."""
        from python.scrapers.pzsz_calendar import season_keys_for_window

        assert season_keys_for_window(SEASON_START, SEASON_END) == [
            "2025/2026",
            "2026/2027",
            "2027/2028",
        ]


class TestRoundsAndWeapons:
    """pzsz.13-pzsz.14."""

    def test_parse_round_reads_the_roman_numeral(self):
        """pzsz.13: the round lives in the name; MPS has no round."""
        from python.scrapers.pzsz_calendar import parse_round

        assert parse_round("I Puchar Polski seniorów w szabli - Poznań 2026/2027") == 1
        assert parse_round("II Puchar Polski seniorów we florecie - Wrocław 2026/2027") == 2
        assert parse_round("III Puchar Polski seniorów w szpadzie - Katowice 2025/2026") == 3
        assert parse_round("IV Puchar Polski seniorów w szpadzie kobiet - Warszawa 2025/2026") == 4
        assert parse_round("Mistrzostwa Polski Seniorów w szermierce - Warszawa 2025/2026") is None

    def test_weapon_letters_maps_the_polish_names(self):
        """pzsz.14: Floret/Szpada/Szabla become the alphabetical e/f/s run."""
        from python.scrapers.pzsz_calendar import weapon_letters

        assert weapon_letters({"weapons": ["FOIL"]}) == "f"
        assert weapon_letters({"weapons": ["EPEE"]}) == "e"
        assert weapon_letters({"weapons": ["SABRE"]}) == "s"
        assert weapon_letters({"weapons": ["SABRE", "FOIL", "EPEE"]}) == "efs"


class TestEventCodes:
    """pzsz.15-pzsz.19: ADR-046 codes, and the gender-split collision."""

    def test_the_six_announced_codes(self):
        """pzsz.15: round number, weapon letters, season suffix."""
        from python.scrapers.pzsz_calendar import parse_calendar_html, plan_event_codes

        rows = parse_calendar_html(PPS_2026_2027.read_text(encoding="utf-8"))
        planned = plan_event_codes(rows, SEASON_CODE)
        by_id = {row["id_pzsz_event"]: row["desired_code"] for row in planned}

        assert by_id == {
            4588: "PPS1s-2026-2027",
            4581: "PPS1f-2026-2027",
            4596: "PPS1e-2026-2027",
            4591: "PPS2s-2026-2027",
            4599: "PPS2e-2026-2027",
            4585: "PPS2f-2026-2027",
        }

    def test_a_gender_split_round_does_not_collide(self):
        """pzsz.16: round IV epee 2025/2026 ran men in Gliwice and women in
        Warszawa -- two competitions, different cities, days apart. An uppercase
        gender letter separates them, and it is W/M rather than the project's
        usual M/F because F already means foil in the trailing weapon run."""
        from python.scrapers.pzsz_calendar import parse_calendar_html, plan_event_codes

        rows = parse_calendar_html(PPS_2025_2026.read_text(encoding="utf-8"))
        planned = plan_event_codes(rows, "SPWS-2025-2026")
        by_id = {row["id_pzsz_event"]: row["desired_code"] for row in planned}

        assert by_id[4559] == "PPS4Me-2025-2026"  # mezczyzn, Gliwice
        assert by_id[4560] == "PPS4We-2025-2026"  # kobiet, Warszawa
        # The undivided rounds of the same season carry no gender letter.
        assert by_id[4549] == "PPS4f-2025-2026"
        assert by_id[4555] == "PPS4s-2025-2026"

    def test_the_live_typo_is_absorbed_by_the_fold(self):
        """pzsz.17: id 4412 reads 'mężćzyzn'. Diacritic-folding both spellings
        gives 'mezczyzn', so the typo costs nothing and the event is correctly
        read as open to both genders."""
        from python.scrapers.pzsz_calendar import parse_calendar_html, plan_event_codes

        rows = parse_calendar_html(PPS_2025_2026.read_text(encoding="utf-8"))
        typo_row = next(row for row in rows if row["id_pzsz_event"] == 4412)
        assert "mężćzyzn" in typo_row["name"]

        planned = plan_event_codes(rows, "SPWS-2025-2026")
        by_id = {row["id_pzsz_event"]: row["desired_code"] for row in planned}
        assert by_id[4412] == "PPS2e-2025-2026"

    def test_a_duplicate_code_raises(self):
        """pzsz.18: two events resolving to one code raise rather than overwrite."""
        from python.scrapers.pzsz_calendar import PzszCodeCollisionError, plan_event_codes

        rows = [
            {
                "id_pzsz_event": 9001,
                "name": "I Puchar Polski seniorów w szpadzie kobiet i mężczyzn - Poznań",
                "weapons": ["EPEE"],
                "dt_start": "2026-10-03",
                "dt_end": "2026-10-03",
            },
            {
                "id_pzsz_event": 9002,
                "name": "I Puchar Polski seniorów w szpadzie kobiet i mężczyzn - Gdańsk",
                "weapons": ["EPEE"],
                "dt_start": "2026-10-10",
                "dt_end": "2026-10-10",
            },
        ]

        with pytest.raises(PzszCodeCollisionError):
            plan_event_codes(rows, SEASON_CODE)

    def test_an_mps_code_carries_no_round(self):
        """pzsz.19: the championship is not a round of anything."""
        from python.scrapers.pzsz_calendar import plan_event_codes

        planned = plan_event_codes(
            [
                {
                    "id_pzsz_event": 4550,
                    "name": "Mistrzostwa Polski Seniorów w szermierce - Warszawa 2026/2027",
                    "weapons": ["EPEE", "FOIL", "SABRE"],
                    "dt_start": "2027-05-28",
                    "dt_end": "2027-05-31",
                }
            ],
            SEASON_CODE,
        )

        assert planned[0]["desired_code"] == "MPSefs-2026-2027"


class TestDetailPageEnrichment:
    """pzsz.20-pzsz.24: the fill-when-available pass."""

    def test_finds_the_invitation_via_the_labelled_section(self):
        """pzsz.20: absolute URL, anchored on 'Komunikaty organizatora'."""
        from python.scrapers.pzsz_calendar import parse_event_detail_html

        detail = parse_event_detail_html(DETAIL_WITH_KOMUNIKAT.read_text(encoding="utf-8"))

        assert detail["url_invitation"] == (
            "https://pzszerm.pl/test/fileDownload.php"
            "?fileId=878d72bbb42d1f043d30edd71f0347c27c2b5136"
        )

    def test_no_komunikat_yields_nothing(self):
        """pzsz.21: every 2026/2027 event reads 'Brak komunikatów' today."""
        from python.scrapers.pzsz_calendar import parse_event_detail_html

        detail = parse_event_detail_html(DETAIL_NO_KOMUNIKAT.read_text(encoding="utf-8"))

        assert detail["url_invitation"] is None

    def test_the_evf_pdf_suffix_heuristic_would_find_nothing(self):
        """pzsz.22: regression guard. EVF finds an invitation by testing
        href.endswith('.pdf'); PZSz serves /test/fileDownload.php?fileId=... with
        no extension at all. Anchoring on the labelled section is what works, and
        this test fails the day someone 'simplifies' it back to a suffix test."""
        import re

        html = DETAIL_WITH_KOMUNIKAT.read_text(encoding="utf-8")
        hrefs = re.findall(r'href="([^"]+)"', html)

        assert hrefs, "the fixture does carry anchors"
        assert not [href for href in hrefs if href.lower().endswith(".pdf")]

    def test_extracts_the_venue_street_address_from_the_komunikat(self):
        """pzsz.23: the city comes from the listing; the street only ever appears
        inside the letter, and did so in 7 of 7 measured komunikaty."""
        from python.scrapers.pzsz_calendar import venue_address_from_pdf_bytes

        address = venue_address_from_pdf_bytes(KOMUNIKAT_PDF.read_bytes())

        assert address == "ul. Siennicka 40B"

    def test_no_deadline_and_no_registration_url_are_synthesised(self):
        """pzsz.24: PZSz publishes neither per event. Entry is club-mediated
        through the login-walled licence system, so a plausible-looking link
        would light the tile's registration dot and tell a veteran they can
        enter when they cannot. Asserted, not merely unset."""
        from python.scrapers.pzsz_calendar import (
            HARVEST_DEADLINE,
            parse_event_detail_html,
            venue_address_from_pdf_bytes,
        )

        assert HARVEST_DEADLINE is False

        detail = parse_event_detail_html(DETAIL_WITH_KOMUNIKAT.read_text(encoding="utf-8"))
        assert detail["dt_registration_deadline"] is None
        assert detail["url_registration"] is None

        # And nothing in the letter itself supplies one: the only cutoff it
        # states is confirmation to the Technical Committee 45 minutes before
        # the start, which is a check-in rule at the venue.
        assert venue_address_from_pdf_bytes(KOMUNIKAT_PDF.read_bytes()) is not None
