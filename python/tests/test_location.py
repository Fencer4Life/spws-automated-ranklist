"""
Tests for the shared calendar-location contract.

Every calendar scraper resolves the same three things — a city, a venue title
and a street address — by the same rules. The *rungs* differ because the sources
differ, but the normalisation and the venue rule are shared, so a fencer sees the
same shape of information whoever ran the competition.

Plan test IDs loc.1-loc.20:
  loc.1   the event name yields the city, stripping a country code
  loc.2   a trailing cancellation marker is stripped before the city is read
  loc.3   only en/em dashes split a name -- an ASCII hyphen never does
  loc.4   a name with no separator yields nothing rather than a guess
  loc.5   a city carrying a region takes the part before the comma
  loc.6   the address yields the city when the name has no separator
  loc.7   the final address part is dropped only when it IS the country
  loc.8   a two-letter province code is skipped, not mistaken for the city
  loc.9   a leading postcode is stripped off the city
  loc.10  an address with no country at all still yields its city
  loc.11  a venue-looking string is never accepted as a city
  loc.12  a venue field that actually holds a city is accepted
  loc.13  the ladder prefers the name over a disagreeing address
  loc.14  nothing anywhere yields a blank city, never a venue
  loc.15  address present -> the venue title is dropped
  loc.16  address blank -> the venue title becomes the address
  loc.17  guard: venue title equal to the city never becomes the address
  loc.18  the venue rule is case- and whitespace-insensitive in its guard
  loc.19  resolve_location never returns a city it also returned as the address
  loc.20  a blank everything resolves to two empty strings, not None
"""

import pytest

from python.scrapers._location import (
    city_from_address,
    city_from_name,
    looks_like_venue,
    normalise_city,
    resolve_location,
)


class TestCityFromName:
    """loc.1-loc.5: the event name, which is EVF's strongest signal."""

    @pytest.mark.parametrize(
        "name,expected",
        [
            ("EVF Circuit – Dublin (IRL)", "Dublin"),
            ("EVF Circuit – Athens (GRE)", "Athens"),
            ("EVF Circuit Memoriam Max Geuter – Munich (GER)", "Munich"),
            ("FOIL CELEBRATION IN BUDA CASTLE – Budapest (HUN)", "Budapest"),
            ("International Veterans Cup – Toronto (CAN)", "Toronto"),
            # No country code at all — the city is still the tail.
            ("European Team Championships 2026 – Cognac", "Cognac"),
        ],
    )
    def test_reads_the_city_off_the_name(self, name, expected):
        """loc.1: `<Title> – <City> (<CC>)`, the EVF naming convention."""
        assert city_from_name(name) == expected

    def test_strips_a_cancellation_marker_first(self):
        """loc.2: `– Cancelled` is appended AFTER the city, so it must come off
        before the tail is read or the city becomes 'Cancelled'."""
        assert city_from_name("EVF Circuit – Stockholm (SWE) – Cancelled") == "Stockholm"
        assert city_from_name("EVF Circuit – Samorin (SVK) – Cancelled") == "Samorin"

    def test_an_ascii_hyphen_is_never_a_separator(self):
        """loc.3: load-bearing. Fâches-Thumesnil is one city containing a hyphen,
        and IMEW-2026-2027 is a bare event code. Splitting on `-` would yield
        'Thumesnil' and '2027'."""
        assert city_from_name("EVF Circuit – Fâches-Thumesnil (FRA)") == "Fâches-Thumesnil"
        assert city_from_name("IMEW-2026-2027") == ""
        assert city_from_name("PEW3") == ""

    def test_a_name_without_a_separator_yields_nothing(self):
        """loc.4: no guess. 'Levi Open (FIN)' has a country code but no dash, and
        inventing a city from the title would be worse than leaving it blank."""
        assert city_from_name("Levi Open (FIN)") == ""
        assert city_from_name("EVF Circuit Dublin") == ""
        assert city_from_name("European Championships 2025") == ""

    def test_a_city_with_a_region_takes_the_part_before_the_comma(self):
        """loc.5: EVF writes 'Chania, Crete' — the city is the head."""
        assert city_from_name("EVF Circuit – Chania, Crete (GRE)") == "Chania"


class TestCityFromAddress:
    """loc.6-loc.10: the address, which rescues names with no separator."""

    def test_reads_the_city_off_the_address(self):
        """loc.6: second-from-the-end, once the country is removed."""
        assert city_from_address("81, boulevard Masséna, Paris, France", "France") == "Paris"
        assert city_from_address("Riesstrasse 40, Munich, Germany", "Germany") == "Munich"

    def test_the_last_part_is_dropped_only_when_it_is_the_country(self):
        """loc.7: 'always drop the last part' would destroy an address that has
        no country, which is exactly the Polish case in loc.10."""
        assert (
            city_from_address("Tsar Boris III Blvd 37, Plovdiv, Bulgaria", "Bulgaria") == "Plovdiv"
        )
        # Country not present in the string — nothing to drop.
        assert (
            city_from_address(
                "Bratislava, Slovakia (Slovak Republic)", "Slovakia (Slovak Republic)"
            )
            == "Bratislava"
        )

    def test_a_province_code_is_skipped(self):
        """loc.8: 'Napoli, NA, Italy' — NA is the Italian province, not the city."""
        assert (
            city_from_address("Palavesuvio ingresso carrabile, Napoli, NA, Italy", "Italy")
            == "Napoli"
        )

    def test_a_leading_postcode_is_stripped(self):
        """loc.9: Polish addresses read '05-092 Łomianki'."""
        assert city_from_address("Ul. Stanisława Staszica 2, 05-092 Łomianki", "") == "Łomianki"

    def test_empty_parts_are_ignored(self):
        """loc.10: 'Salzburg,, Austria' — the double comma is live source data."""
        assert (
            city_from_address("Schießstattstraße 26, Salzburg,, Austria", "Austria") == "Salzburg"
        )
        assert city_from_address("", "Austria") == ""


class TestVenueDetection:
    """loc.11-loc.12: what may and may not be accepted as a city."""

    def test_a_venue_is_never_a_city(self):
        """loc.11."""
        for venue in (
            "Sporthalle der Städtischen Berufsschule für Informationstechnik",
            "Guildford Spectrum",
            "POLIDEPORTIVO MUNICIPAL DE MORATALAZ",
            "Complexe Sportif Omnisports des Vauzelles",
            "Stora mossen IP idrottshall",
            "Savoy Terrace - Buda Castle",
            "Salle Jean Zay",
            "UCD Sport Center Dublin",
        ):
            assert looks_like_venue(venue), venue

    def test_a_venue_field_holding_a_city_is_accepted(self):
        """loc.12: EVF fills this field inconsistently — Liège's 'venue' is the
        city itself, and those rows must keep working."""
        for city in ("Liège", "Jabłonna", "Samorin", "Napoli", "Plovdiv", "Guildford"):
            assert not looks_like_venue(city), city


class TestTheLadder:
    """loc.13-loc.14: rung order."""

    def test_the_name_outranks_a_disagreeing_address(self):
        """loc.13: the address says Prilly and Bromma; a fencer looking for the
        competition knows it as Lausanne and Stockholm. EVF's own naming is the
        editorial choice of the recognisable city."""
        city, _ = resolve_location(
            city_candidates=[
                city_from_name("EVF Circuit – Lausanne (SUI)"),
                city_from_address("Chemin du Viaduc 14, Prilly, Switzerland", "Switzerland"),
            ],
            venue_title="Vaudoise aréna - Lausanne",
            address="Chemin du Viaduc 14, Prilly, Switzerland",
        )
        assert city == "Lausanne"

    def test_nothing_anywhere_yields_a_blank_city(self):
        """loc.14: never a venue, never a guess."""
        city, _ = resolve_location(
            city_candidates=[city_from_name("Levi Open (FIN)"), city_from_address("", "")],
            venue_title="",
            address="",
        )
        assert city == ""


class TestTheVenueRule:
    """loc.15-loc.20: where the venue title goes."""

    def test_address_present_drops_the_venue_title(self):
        """loc.15: it is already invisible in the UI when an address exists, and
        the address usually names the venue anyway."""
        city, address = resolve_location(
            city_candidates=["Dublin"],
            venue_title="UCD Sport Center Dublin",
            address="UCD Sport Center Belfield Dublin, Dublin, Ireland",
        )
        assert city == "Dublin"
        assert address == "UCD Sport Center Belfield Dublin, Dublin, Ireland"

    def test_address_blank_promotes_the_venue_title(self):
        """loc.16: the one piece of location detail available is not discarded."""
        city, address = resolve_location(
            city_candidates=["Warszawa"],
            venue_title="OSiR SIENNICKA – Praga Południe",
            address="",
        )
        assert city == "Warszawa"
        assert address == "OSiR SIENNICKA – Praga Południe"

    def test_a_venue_title_equal_to_the_city_is_not_promoted(self):
        """loc.17: the guard. All 15 blank-address EVF rows hold a CITY in the
        venue field, so without this the city would be duplicated into the
        address and the card would read 'Jabłonna / Jabłonna'."""
        for name in ("Jabłonna", "Samorin", "Napoli", "Plovdiv"):
            city, address = resolve_location(city_candidates=[name], venue_title=name, address="")
            assert city == name
            assert address == ""

    def test_the_guard_ignores_case_and_surrounding_space(self):
        """loc.18: '  liège ' is the same place as 'Liège'."""
        city, address = resolve_location(
            city_candidates=["Liège"], venue_title="  liège ", address=""
        )
        assert city == "Liège"
        assert address == ""

    def test_the_city_is_never_also_returned_as_the_address(self):
        """loc.19: the invariant behind loc.17, stated directly."""
        for venue, addr in (
            ("Guildford", ""),
            ("Guildford Spectrum", ""),
            ("Guildford Spectrum", "Parkway, Guildford, United Kingdom"),
        ):
            city, address = resolve_location(
                city_candidates=["Guildford"], venue_title=venue, address=addr
            )
            assert city == "Guildford"
            assert address.strip().casefold() != city.strip().casefold()

    def test_everything_blank_resolves_to_empty_strings(self):
        """loc.20: the callers write these straight into TEXT columns, so None
        would become the string 'None' somewhere downstream."""
        city, address = resolve_location(city_candidates=[], venue_title="", address="")
        assert city == ""
        assert address == ""
        assert normalise_city(None) == ""
