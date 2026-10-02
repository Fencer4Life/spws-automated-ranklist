"""ENG.NAT — the Engarde nationality column is found by its heading.

doc/plans/international-data-repair-batch-1-2026-10-01.html, decision C A
(2 Oct 2026), from the EVF Circuit Budapest 2025 pages (hunfencing).

Three Budapest brackets (me40, wf70, ms70) print a "Club" column where the
others print "Country", and their fencer list has no nationality either. The
parser took the fourth column whatever its heading, so a club ("UKSSMK") was
read as a country and the POL-only rule dismissed BOBUSIA Jarosław, 5th of 33.
A page with no nationality column leaves the nationality blank: a Pole there
is recognised only by a nationality entry in the event's override file
(P3.OV16–18), never by the club.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures" / "engarde"


def _page(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def test_ENG_NAT_01_a_club_column_is_not_a_nationality():
    """V1 men's épée, Budapest 2025 (me40): the page is headed Rank, Name,
    First name, Club. Every nationality is blank; places and N are kept."""
    from python.scrapers.engarde import parse_engarde_html, parse_html

    html = _page("clasfinal_hunfencing_club.html")
    parsed = parse_html(html)
    rows = {r.fencer_name: r for r in parsed.results}
    assert parsed.raw_pool_size == 33
    assert rows["BOBUSIA Jaroslaw"].place == 5
    assert {r.fencer_country for r in parsed.results} == {None}
    assert {r["country"] for r in parse_engarde_html(html)} == {None}


@pytest.mark.parametrize(
    "fixture",
    [
        "clasfinal_hunfencing.html",  # Country
        "clasfinal_madrid.html",  # Nación
        "competition_crit26_fhv2.html",  # Nation, then Statut
        "competition_crit26_ehv2.html",  # Nation
    ],
)
def test_ENG_NAT_02_the_nationality_column_is_read_by_its_heading(fixture):
    """Country, Nation and Nación are read as before: every row carries its
    federation's three-letter code, whatever column follows."""
    from python.scrapers.engarde import parse_engarde_html, parse_html

    html = _page(fixture)
    code = re.compile(r"^[A-Z]{3}$")
    assert all(code.match(r.fencer_country or "") for r in parse_html(html).results)
    assert all(code.match(r["country"] or "") for r in parse_engarde_html(html))
