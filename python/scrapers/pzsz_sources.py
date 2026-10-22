"""PZSz calendar sources: the listing and the home page (ADR-116 §7).

The calendar run reads two public pzszerm.pl pages, both rendered by the
browser (§6) and both parsed here, one item at a time:

* the listing (``kalendarium-zawodow``): each event's row — city, dates — and
  its letter links. A row's last cell carries zero or more
  "Komunikat organizatora z dnia DD_MM_YYYY" icons; pass 0's candidate is the
  newest by that title date.
* the home page's "Najbliższe zawody" table: id, name, start and end of the
  next events — a second source for pass 1 (city) and pass 4 (dates). The
  "Zakończone zawody" table beside it (past events) is never read.

Pure: these functions read HTML and never fetch. They build on the listing
parse and helpers in :mod:`pzsz_calendar`.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date

from bs4 import BeautifulSoup, Tag

from python.scrapers.pzsz_calendar import (
    _EVENT_ID_RE,
    _absolute,
    _fold,
    normalise_date,
    parse_calendar_html,
)

_LETTER_DATE_RE = re.compile(r"z dnia (\d{1,2})_(\d{1,2})_(\d{4})")
_HOME_HEADING = "najblizsze zawody"


@dataclass(frozen=True)
class LetterLink:
    """One organizer's-letter link from a listing row: its absolute URL and the
    date in its title (``None`` when the title carries no date)."""

    url: str
    dated: date | None


@dataclass(frozen=True)
class ListingRow:
    """One listing row as a source: the event, its city and dates as the
    listing states them, and the newest letter link if any."""

    id_pzsz_event: int
    name: str
    url_event: str
    weapons: list[str]
    dt_start: str
    dt_end: str
    location: str
    txt_country: str
    letter: LetterLink | None


@dataclass(frozen=True)
class HomeRow:
    """One "Najbliższe zawody" row: the event, its dates and the city read from
    the name's suffix."""

    id_pzsz_event: int
    name: str
    dt_start: str
    dt_end: str
    city: str


def parse_letter_title_date(title: str) -> date | None:
    """The date in a letter icon's title, "… z dnia DD_MM_YYYY"; ``None`` when
    the title has no such date. The day and month may be one or two digits."""
    match = _LETTER_DATE_RE.search(title or "")
    if match is None:
        return None
    day, month, year = (int(g) for g in match.groups())
    try:
        return date(year, month, day)
    except ValueError:
        return None


def newest_letter(links: list[LetterLink]) -> LetterLink | None:
    """The letter to read: the newest by its title date. A dated letter always
    beats an undated one; with none dated, the first is kept; none at all →
    ``None``."""
    if not links:
        return None
    return max(links, key=lambda link: (link.dated is not None, link.dated or date.min))


def _letter_links_by_event(html: str) -> dict[int, list[LetterLink]]:
    """Every listing row's letter links, keyed by the event's PZSz id."""
    soup = BeautifulSoup(html, "html.parser")
    out: dict[int, list[LetterLink]] = {}
    for tr in soup.find_all("tr"):
        if not isinstance(tr, Tag):
            continue
        cells = [td for td in tr.find_all("td") if "tab-row" in (td.get("class") or [])]
        if len(cells) < 7:
            continue
        anchor = cells[0].find("a", href=True)
        if anchor is None:
            continue
        id_match = _EVENT_ID_RE.search(str(anchor["href"]))
        if id_match is None:
            continue
        links: list[LetterLink] = []
        for a in tr.find_all("a", href=True):
            href = str(a["href"])
            if "fileDownload" not in href:
                continue
            links.append(
                LetterLink(_absolute(href), parse_letter_title_date(str(a.get("title") or "")))
            )
        out[int(id_match.group(1))] = links
    return out


def parse_listing(html: str) -> list[ListingRow]:
    """Every listing row with its city, dates and newest letter link. The base
    fields come from :func:`pzsz_calendar.parse_calendar_html`; the letter links
    are read from the same rows."""
    letters = _letter_links_by_event(html)
    rows: list[ListingRow] = []
    for base in parse_calendar_html(html):
        eid = int(base["id_pzsz_event"])
        rows.append(
            ListingRow(
                id_pzsz_event=eid,
                name=str(base.get("name") or ""),
                url_event=str(base.get("url_event") or ""),
                weapons=list(base.get("weapons") or []),
                dt_start=str(base.get("dt_start") or ""),
                dt_end=str(base.get("dt_end") or ""),
                location=str(base.get("location") or ""),
                txt_country=str(base.get("txt_country") or "PL"),
                letter=newest_letter(letters.get(eid, [])),
            )
        )
    return rows


def _home_city(name: str) -> str:
    """The city from a home-row name's suffix: the text after the last " – "
    (or " - "), up to a comma or a four-digit year/edition. "… – Gdańsk
    2026/2027" → "Gdańsk"; "… – Oborniki Śląskie, 28-29.11.2026r." → "Oborniki
    Śląskie"."""
    parts = re.split(r"\s[–-]\s", name)
    if len(parts) < 2:
        return ""
    tail = parts[-1].strip()
    return re.split(r"\s*,|\s+\d{4}", tail)[0].strip()


def parse_home_page(html: str) -> list[HomeRow]:
    """The "Najbliższe zawody" table's rows: id, name, dates and city. The
    neighbouring "Zakończone zawody" table (past events) is never read."""
    soup = BeautifulSoup(html, "html.parser")
    for table in soup.find_all("table"):
        if not isinstance(table, Tag):
            continue
        head = table.find("tr")
        if head is None:
            continue
        headers = [_fold(c.get_text(" ", strip=True)) for c in head.find_all(["th", "td"])]
        if not headers or headers[0] != _HOME_HEADING:
            continue
        rows: list[HomeRow] = []
        for tr in table.find_all("tr")[1:]:
            anchor = tr.find("a", href=True)
            if anchor is None:
                continue
            id_match = _EVENT_ID_RE.search(str(anchor["href"]))
            cells = tr.find_all("td")
            if id_match is None or len(cells) < 3:
                continue
            name = anchor.get_text(" ", strip=True)
            rows.append(
                HomeRow(
                    id_pzsz_event=int(id_match.group(1)),
                    name=name,
                    dt_start=normalise_date(cells[1].get_text(" ", strip=True)),
                    dt_end=normalise_date(cells[2].get_text(" ", strip=True)),
                    city=_home_city(name),
                )
            )
        return rows
    return []
