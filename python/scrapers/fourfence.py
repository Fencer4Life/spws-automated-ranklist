"""
4Fence parser.

Parses a 4fence.it final classification ("f=clafinale").

Structure:
- <tr class="null767"> rows hold one fencer each (full table): cells
  [2]=Cla Gir (the POOL ranking), [3]=CLASS (the final place), [4]=Surname,
  [5]=Name, [7]=Club ("Federazione POLONIA" for a foreign entry)
- the <tr class="nullmax"> row after it repeats the fencer (short table) with
  the club code in cell [4]: "EE" + IOC code for a foreign federation (EEPOL),
  a province-prefixed code for an Italian club (BACSB)
- header rows have surname "COGNOME"

The final place is CLASS, never Cla Gir (FOURFENCE.PLACE.01). A fencer listed
without a place is either the second bronze medallist, whom the page cannot
print as a second 3, or a fencer who left during the direct elimination. The
last-four tableau ("f=tab4") names both semi-final losers; the one without a
place is 3rd and in N. Any other fencer without a place is not in N, and the
places below him close up: a place is 1 + the number of placed fencers ahead
(FOURFENCE.BRONZE.01, FOURFENCE.CLOSE.01; doc/plans/
international-data-repair-batch-1-2026-10-01.html, decisions B A and W A).
"""

from __future__ import annotations

import re
import unicodedata

from bs4 import BeautifulSoup

# Matches &nbsp (with or without semicolon), case-insensitive
_NBSP_RE = re.compile(r"&nbsp;?", re.IGNORECASE)
_FOREIGN_CODE_RE = re.compile(r"^EE([A-Z]{3})$")


def _clean_text(text: str) -> str:
    """Strip non-breaking spaces in all forms from extracted text."""
    return _NBSP_RE.sub("", text).replace("\xa0", "").strip()


def _fold(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFKD", s) if unicodedata.category(c) != "Mn"
    ).upper()


def _country(code: str) -> str | None:
    """IOC country of a club code: "EE" + IOC for a foreign federation, Italy
    for an Italian club; None when the page shows no code."""
    if not code:
        return None
    m = _FOREIGN_CODE_RE.match(code)
    return m.group(1) if m else "ITA"


def _classification_rows(html: str) -> list[dict]:
    """Every fencer of a final classification, in page order: surname, name,
    pool rank, CLASS (None when the page prints no place), club, country."""
    soup = BeautifulSoup(html, "html.parser")
    rows: list[dict] = []
    last: dict | None = None
    for tr in soup.find_all("tr"):
        classes = tr.get("class") or []
        cells = tr.find_all("td")
        if "null767" in classes and len(cells) >= 9:
            surname = _clean_text(cells[4].get_text(strip=True))
            name = _clean_text(cells[5].get_text(strip=True))
            if not surname or surname.upper() == "COGNOME" or name.upper() == "NOME":
                last = None
                continue
            klass = _clean_text(cells[3].get_text(strip=True))
            pool = _clean_text(cells[2].get_text(strip=True))
            last = {
                "surname": surname,
                "name": name,
                "pool": int(pool) if pool.isdigit() else None,
                "place": int(klass) if klass.isdigit() else None,
                "club": _clean_text(cells[7].get_text(strip=True)),
                "country": None,
            }
            rows.append(last)
        elif "nullmax" in classes and last is not None and len(cells) >= 5:
            last["country"] = _country(_clean_text(cells[4].get_text(strip=True)))
            last = None
    return rows


def semifinal_losers(tab4_html: str) -> list[tuple[int | None, str]]:
    """(pool seed, folded surname) of both semi-final losers on a last-four
    tableau. A bout is two rows (seed, name, club code, score); the first four
    scored rows are the two semi-finals, and the lower score lost. The name is
    a clickable span holding the surname (Napoli 2026), or cell text
    "SURNAME Firstname" whose capitalised words are the surname (Terni 2025,
    FOURFENCE.BRONZE.02)."""
    soup = BeautifulSoup(tab4_html, "html.parser")
    entries: list[tuple[int | None, str, int]] = []
    for tr in soup.find_all("tr"):
        cells = tr.find_all("td", recursive=False)
        if len(cells) != 4:
            continue
        score = _clean_text(cells[3].get_text(strip=True))
        if not score.isdigit():
            continue
        span = cells[1].find("span", onclick=True)
        if span is not None:
            surname = _clean_text(span.get_text(strip=True))
        else:
            words = _clean_text(cells[1].get_text(" ", strip=True)).split()
            caps: list[str] = []
            for w in words:
                if w != w.upper() or not any(ch.isalpha() for ch in w):
                    break
                caps.append(w)
            surname = " ".join(caps)
        if not surname:
            continue
        seed = _clean_text(cells[0].get_text(strip=True))
        entries.append((int(seed) if seed.isdigit() else None, _fold(surname), int(score)))
        if len(entries) == 4:
            break
    losers = []
    for a, b in ((0, 1), (2, 3)):
        if b < len(entries):
            loser = entries[a] if entries[a][2] < entries[b][2] else entries[b]
            losers.append((loser[0], loser[1]))
    return losers


def resolve_classification(html: str, tab4_html: str | None = None) -> tuple[list[dict], int]:
    """The placed fencers, each with the place it counts, and N.

    The second bronze (a semi-final loser without a place) is 3rd; any other
    fencer without a place is left out of N, and places close up below him.
    Without the tableau, a single 3rd and a skipped 4th still count one bronze
    in N, though his row cannot be named.
    """
    rows = _classification_rows(html)
    losers = semifinal_losers(tab4_html) if tab4_html else []
    for row in rows:
        if row["place"] is None and any(
            seed == row["pool"] and _fold(row["surname"]).startswith(surname)
            for seed, surname in losers
        ):
            row["place"] = 3
    placed = [r for r in rows if r["place"] is not None]
    printed = [r["place"] for r in placed]
    unnamed_bronze = int(printed.count(3) == 1 and 4 not in printed and len(printed) > 3)
    for row in placed:
        row["place"] = 1 + sum(1 for p in printed if p < row["place"])
        if unnamed_bronze and row["place"] > 3:
            row["place"] += 1
    return placed, len(placed) + unnamed_bronze


def parse_fourfence_html(html: str, tab4_html: str | None = None) -> list[dict]:
    """Parse a 4Fence final classification into the standardized result list.

    Returns dicts with keys fencer_name, place, country (IOC, from the club
    code) and club.
    """
    placed, _ = resolve_classification(html, tab4_html)
    return [
        {
            "fencer_name": f"{r['surname']} {r['name'].title()}".strip(),
            "place": r["place"],
            "country": r["country"] or "",
            "club": r["club"],
        }
        for r in placed
    ]


# =============================================================================
# IR factory (Phase 1 / part 2 — ADR-050)
#
# parse_html emits ParsedTournament. 4Fence has no native row IDs, so the IR
# uses synthetic IDs; the country is the federation code (FOURFENCE.NAT.01).
# =============================================================================


def parse_html(
    html: str,
    source_url: str | None = None,
    tab4_html: str | None = None,
):
    """Parse a 4Fence final classification into a ParsedTournament.

    No native IDs are available; ``make_synthetic_id`` is used. The country is
    the federation a fencer enters under, N the placed fencers with the second
    bronze (``resolve_classification``).
    """
    from python.pipeline.ir import (
        ParsedResult,
        ParsedTournament,
        SourceKind,
        make_synthetic_id,
    )

    placed, n = resolve_classification(html, tab4_html)
    parsed_results: list[ParsedResult] = []
    for row_index, r in enumerate(placed, start=1):
        fencer_name = f"{r['surname']} {r['name'].title()}".strip()
        parsed_results.append(
            ParsedResult(
                source_row_id=make_synthetic_id(
                    SourceKind.FOURFENCE,
                    row_index=row_index,
                    place=r["place"],
                    name=fencer_name,
                ),
                fencer_name=fencer_name,
                place=r["place"],
                fencer_country=r["country"],
            )
        )

    return ParsedTournament(
        source_kind=SourceKind.FOURFENCE,
        results=parsed_results,
        raw_pool_size=n,
        source_url=source_url,
    )
