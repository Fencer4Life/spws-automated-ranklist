"""FOURFENCE — a 4fence final classification read as the source publishes it.

doc/plans/international-data-repair-batch-1-2026-10-01.html, decisions R4 A,
B A and W A (2 Oct 2026), from the EVF Circuit Napoli 2026 pages
(4fence, "4 Prova Circuito Nazionale Master").

* The place is the column "CLASS", the final classification. "Cla Gir" is the
  pool ranking; the parser read it as the place.
* The nationality is the federation a foreign fencer enters under: the short
  table's code "EE" + IOC code (EEPOL, EENED); an Italian club code is Italy.
* Every bracket lists its second bronze medallist with no place and skips
  place 4. The last-four tableau (f=tab4) names both semi-final losers: the one
  without a place is 3rd, joint bronze, and is in N (B A).
* A fencer listed without a place who is not a semi-final loser left during
  the direct elimination: he is not in N, and the places the page numbers below
  his skipped number close up by one each (W A). A place is 1 + the number of
  placed fencers ahead.
"""

from __future__ import annotations

from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures" / "fourfence"
BASE = (
    "https://www.4fence.it/FIS/Risultati/"
    "2026-03-08-07_Napoli_-_4_Prova_Circuito_Nazionale_Master_2025-2/"
)


def _page(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def _by_name(parsed) -> dict[str, tuple[int, str | None]]:
    return {r.fencer_name: (r.place, r.fencer_country) for r in parsed.results}


def test_FOURFENCE_PLACE_01_the_place_is_the_final_classification():
    """V1 men's épée: STOCKI Piotr's pool rank is 14, his final place 13;
    the winner, CARRILLO AYALA, was 2nd in the pools."""
    from python.scrapers.fourfence import parse_html

    rows = _by_name(
        parse_html(_page("napoli_spm6_clafinale.html"), tab4_html=_page("napoli_spm6_tab4.html"))
    )
    assert rows["STOCKI Piotr"][0] == 13
    assert rows["KORNAS Jaroslaw"][0] == 30
    assert rows["CARRILLO AYALA Andres Marcel"][0] == 1


def test_FOURFENCE_NAT_01_the_nationality_is_the_federation_entered_under():
    """A foreign fencer's federation code gives his country (EEPOL → POL,
    EENED → NED, EEHUN → HUN); an Italian club is Italy."""
    from python.scrapers.fourfence import parse_html

    rows = _by_name(
        parse_html(_page("napoli_spm6_clafinale.html"), tab4_html=_page("napoli_spm6_tab4.html"))
    )
    assert rows["STOCKI Piotr"][1] == "POL"
    assert rows["KORONA Radoslaw"][1] == "NED"
    assert rows["ALCSER Norbert"][1] == "HUN"
    assert rows["CARRILLO AYALA Andres Marcel"][1] == "ITA"


def test_FOURFENCE_BRONZE_01_the_second_bronze_is_third_and_in_N():
    """V2 men's foil: KORONA Przemysław lost his semi-final 3–10 and is
    listed with no place; he is 3rd with PESCE Filippo, and in N. V1 men's
    épée: SQUEO Benedetto, the same."""
    from python.scrapers.fourfence import parse_html

    foil = parse_html(_page("napoli_fm7_clafinale.html"), tab4_html=_page("napoli_fm7_tab4.html"))
    rows = _by_name(foil)
    assert rows["KORONA Przemyslaw"] == (3, "POL")
    assert rows["PESCE Filippo"][0] == 3
    epee = _by_name(
        parse_html(_page("napoli_spm6_clafinale.html"), tab4_html=_page("napoli_spm6_tab4.html"))
    )
    assert epee["SQUEO Benedetto"][0] == 3
    assert sorted(p for p, _ in epee.values())[:5] == [1, 2, 3, 3, 5]


def test_FOURFENCE_BRONZE_02_a_tableau_without_clickable_names_still_names_the_bronze():
    """EVF Circuit Terni 2025, V1 men's foil: GINZERY Tomas lost his
    semi-final and is listed with no place. Terni's last-four page prints each
    name as cell text, with no clickable span; he is still 3rd, beside
    BALESTRIERI Ugo, and in N (14, as EVF has it)."""
    from python.scrapers.fourfence import parse_html, semifinal_losers

    tab4 = _page("terni_fm6_tab4.html")
    assert {name for _seed, name in semifinal_losers(tab4)} == {"GINZERY", "BALESTRIERI"}
    foil = parse_html(_page("terni_fm6_clafinale.html"), tab4_html=tab4)
    rows = _by_name(foil)
    assert rows["GINZERY Tomas"][0] == 3
    assert rows["BALESTRIERI Ugo"][0] == 3
    assert foil.raw_pool_size == 14
    assert len(foil.results) == 14


def test_FOURFENCE_CLOSE_01_a_fencer_who_left_is_not_in_N_and_places_close_up():
    """V2 men's foil lists 23 fencers: 21 placed, the second bronze, and
    MULLER Ferenc, who left during the direct elimination (number 21 skipped).
    N is 22; the fencers printed 22nd and 23rd become 21st and 22nd."""
    from python.scrapers.fourfence import parse_html

    foil = parse_html(_page("napoli_fm7_clafinale.html"), tab4_html=_page("napoli_fm7_tab4.html"))
    names = {r.fencer_name for r in foil.results}
    places = sorted(r.place for r in foil.results)
    assert "MULLER Ferenc" not in names
    assert foil.raw_pool_size == 22
    assert len(foil.results) == 22
    assert max(places) == 22
    assert places[-2:] == [21, 22]


def test_FOURFENCE_NOTAB_01_without_the_tableau_the_bronze_still_counts():
    """Without the last-four page the second bronze cannot be named: his row
    is left out, but place 3 printed once and place 4 skipped mean he exists,
    so N still counts him."""
    from python.scrapers.fourfence import parse_html

    foil = parse_html(_page("napoli_fm7_clafinale.html"))
    assert foil.raw_pool_size == 22
    assert len(foil.results) == 21
    assert "KORONA Przemyslaw" not in {r.fencer_name for r in foil.results}


def test_FOURFENCE_EVT_01_an_event_url_expands_into_its_brackets():
    """The runner expands a 4fence event URL into its category brackets: each
    bracket's final classification and last-four tableau are read, a category
    with no fencers is skipped, and weapon, gender and category come from the
    URL's parameters."""
    from python.pipeline.review_cli import Fetcher

    pages = {
        f"{BASE}index.php?a=F&s=M&c=7&f=clafinale": _page("napoli_fm7_clafinale.html"),
        f"{BASE}index.php?a=F&s=M&c=7&f=tab4": _page("napoli_fm7_tab4.html"),
    }
    fetched: list[str] = []

    class _Http:
        def get(self, url):
            fetched.append(url)

            class _R:
                text = pages.get(url, "<html><body><table></table></body></html>")
                status_code = 200

                def raise_for_status(self):
                    return None

            return _R()

    fetcher = Fetcher(http_client=_Http())
    results, skipped = fetcher.fetch_event_url_with_skips(BASE)
    assert len(results) == 1
    t = results[0]
    assert (t.weapon, t.gender, t.category_hint) == ("FOIL", "M", "V2")
    assert t.raw_pool_size == 22
    assert f"{BASE}index.php?a=F&s=M&c=7&f=tab4" in fetched
    assert skipped == []
