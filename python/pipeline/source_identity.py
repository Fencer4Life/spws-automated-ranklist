"""
Is this source URL the event? — the URL-identity check for event result slots.

doc/plans/international-data-repair-batch-1-2026-10-01.html: before an event's
results are re-ingested from its organiser's pages, every URL in its result
slots (FR-98, `tbl_event.url_event..url_event_5`) must be that event. Three
things are compared with the event row:

  * date    — a date shown by the source lies within the event's dates,
              one day either side;
  * name    — the source names the event: its city (any alias in
              city_aliases.yaml), its country, a championship's own name
              ("World Championships" for MSW), or two distinctive words of the
              event's name. Organisers' pages often omit the city ("EVF
              Circuit in Poland", "BVF 6 Weapon International 2026"); when a
              page gives none of these, a person may confirm the name
              (`name_confirmed`), never the date or the weapons;
  * weapons — every weapon of the event is found at its sources, counted over
              all of them (an event split over one URL per day passes).

A source that shows no date, no weapon or no name cannot be checked and is
refused: the check fails closed. Stage 7 (url_validation.py) checks each
bracket against its tournament; it cannot catch a whole wrong event, because
Phase 5 stamps the event's own date on a bracket whose source has none.

Readers are per platform, from the HTML a URL serves:
  * FTL event schedule — <title>, "Month D, YYYY" day headings, bracket names;
  * Ophardt (fencingworldwide) — <h1>, "dd.mm. - dd.mm." with the year taken
    from the URL (".../32812-2025/...");
  * Engarde — `.tounament-title`; its competition list (and so its dates) is
    built in JavaScript, so it has no date and is refused until a reader
    exists;
  * anything else (4fence, d'Artagnan, ...) — <title> and the text, with the
    generic date and weapon patterns.

Tests: python/tests/test_source_identity.py (REPAIR.URL.01).
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from datetime import date, timedelta

from bs4 import BeautifulSoup


@dataclass(frozen=True)
class SourceIdentity:
    """What a source page says about itself."""

    url: str
    title: str
    text: str
    dates: frozenset[date]
    weapons: frozenset[str]


# ---------------------------------------------------------------------------
# Patterns
# ---------------------------------------------------------------------------

_MONTHS: dict[str, int] = {}
for _num, _names in enumerate(
    [
        "january jan janvier januar gennaio enero stycznia januari",
        "february feb fevrier februar febbraio febrero lutego februari",
        "march mar mars marz marzo marca",
        "april apr avril aprile abril kwietnia",
        "may mai maggio mayo maja maj",
        "june jun juin juni giugno junio czerwca",
        "july jul juillet juli luglio julio lipca",
        "august aug aout agosto sierpnia augusti",
        "september sep sept septembre settembre septiembre wrzesnia",
        "october oct octobre oktober ottobre octubre pazdziernika",
        "november nov novembre noviembre listopada",
        "december dec decembre dezember dicembre diciembre grudnia",
    ],
    start=1,
):
    for _n in _names.split():
        _MONTHS[_n] = _num
_MONTH_RE = "|".join(sorted(_MONTHS, key=len, reverse=True))

_ISO = re.compile(r"\b(\d{4})-(\d{2})-(\d{2})\b")
_NUMERIC = re.compile(r"\b(\d{1,2})([./])(\d{1,2})\2(\d{4})\b")
_DAY_MONTH_YEAR = re.compile(rf"\b(\d{{1,2}})\.?\s+({_MONTH_RE})\.?\s+(\d{{4}})\b")
_MONTH_DAY_YEAR = re.compile(rf"\b({_MONTH_RE})\.?\s+(\d{{1,2}}),?\s+(\d{{4}})\b")
_DAY_MONTH_NO_YEAR = re.compile(r"(?<![\d.])(\d{1,2})\.(\d{1,2})\.(?!\d)")
_URL_YEAR = re.compile(r"/\d+-(\d{4})/")

_WEAPON_WORDS = {
    "EPEE": "epee epees szpada szpady degen spada espada varja",
    "FOIL": "foil foils fleuret floret florett fioretto florete",
    "SABRE": "sabre sabres saber szabla szable sabel sciabola sable",
}
_WEAPON_OF: dict[str, str] = {w: k for k, words in _WEAPON_WORDS.items() for w in words.split()}
_WEAPON_RE = re.compile(r"\b(" + "|".join(sorted(_WEAPON_OF, key=len, reverse=True)) + r")\b")

_CODE_LETTERS = {"e": "EPEE", "f": "FOIL", "s": "SABRE"}


def _fold(s: str) -> str:
    """Lower case, diacritics removed (ł → l as well)."""
    s = s.replace("ł", "l").replace("Ł", "L")
    return "".join(
        c for c in unicodedata.normalize("NFKD", s) if unicodedata.category(c) != "Mn"
    ).lower()


def _safe_date(y: int, m: int, d: int) -> date | None:
    try:
        return date(y, m, d)
    except ValueError:
        return None


def find_dates(text: str, url_year: int | None = None) -> set[date]:
    """Every date the text shows, in the formats the platforms use.

    A numeric dd/mm/yyyy is also read as mm/dd/yyyy when that is a valid date:
    the check compares against a known date, so the extra reading only matters
    when it falls within the event's days.
    """
    folded = _fold(text)
    found: set[date] = set()
    for y, m, d in _ISO.findall(folded):
        if (v := _safe_date(int(y), int(m), int(d))) is not None:
            found.add(v)
    for a, sep, b, y in _NUMERIC.findall(folded):
        if (v := _safe_date(int(y), int(b), int(a))) is not None:
            found.add(v)
        if sep == "/" and (v := _safe_date(int(y), int(a), int(b))) is not None:
            found.add(v)
    for d, mon, y in _DAY_MONTH_YEAR.findall(folded):
        if (v := _safe_date(int(y), _MONTHS[mon], int(d))) is not None:
            found.add(v)
    for mon, d, y in _MONTH_DAY_YEAR.findall(folded):
        if (v := _safe_date(int(y), _MONTHS[mon], int(d))) is not None:
            found.add(v)
    if url_year is not None:
        for d, m in _DAY_MONTH_NO_YEAR.findall(folded):
            if (v := _safe_date(url_year, int(m), int(d))) is not None:
                found.add(v)
    return found


def find_weapons(text: str) -> set[str]:
    """The weapons named in the text, in any of the platforms' languages."""
    return {_WEAPON_OF[w] for w in _WEAPON_RE.findall(_fold(text))}


# ---------------------------------------------------------------------------
# Readers
# ---------------------------------------------------------------------------


def _title_tag(soup: BeautifulSoup) -> str:
    return soup.title.get_text(strip=True) if soup.title else ""


def read_source_identity(url: str, html: str) -> SourceIdentity:
    """Read a source page's own name, dates and weapons, by platform."""
    soup = BeautifulSoup(html, "html.parser")
    text = soup.get_text(" ", strip=True)
    host = url.lower()

    if "fencingtimelive.com" in host and "/tournaments/eventschedule/" in host:
        from python.tools.scrape_ftl_event_urls import parse_event_schedule

        kept, skipped = parse_event_schedule(html, with_skips=True)
        names = " ".join(e["name"] for e in kept + skipped)
        return SourceIdentity(
            url=url,
            title=_title_tag(soup),
            text=text,
            dates=frozenset(find_dates(text)),
            weapons=frozenset(find_weapons(names)),
        )

    if "fencingworldwide.com" in host or "ophardt" in host:
        m = _URL_YEAR.search(url)
        h1 = soup.find("h1")
        return SourceIdentity(
            url=url,
            title=h1.get_text(" ", strip=True) if h1 else _title_tag(soup),
            text=text,
            dates=frozenset(find_dates(text, int(m.group(1)) if m else None)),
            weapons=frozenset(find_weapons(text)),
        )

    if "engarde" in host:
        t = soup.select_one(".tounament-title")
        return SourceIdentity(
            url=url,
            title=t.get_text(" ", strip=True) if t else _title_tag(soup),
            text=text,
            dates=frozenset(find_dates(text)),
            weapons=frozenset(find_weapons(text)),
        )

    return SourceIdentity(
        url=url,
        title=_title_tag(soup),
        text=text,
        dates=frozenset(find_dates(f"{_title_tag(soup)} {text}")),
        weapons=frozenset(find_weapons(f"{_title_tag(soup)} {text}")),
    )


# ---------------------------------------------------------------------------
# The check
# ---------------------------------------------------------------------------


def event_weapons(event: dict) -> set[str]:
    """The event's weapons: `arr_weapons`, else a PEW code's letters (ADR-046)."""
    stored = event.get("arr_weapons") or []
    if stored:
        return {str(w).upper() for w in stored}
    m = re.match(r"PEW\d+([efs]+)-", str(event.get("txt_code") or ""))
    return {_CODE_LETTERS[c] for c in m.group(1)} if m else set()


def _as_date(v) -> date | None:
    if v is None or isinstance(v, date):
        return v
    return date.fromisoformat(str(v)[:10])


def _city_names(city: str) -> set[str]:
    """The event's city and every alias of it, folded."""
    from python.pipeline.url_validation import _load_city_aliases

    folded = _fold(city)
    aliases = _load_city_aliases()
    canonical = aliases.get(folded, folded)
    return {folded, canonical} | {a for a, c in aliases.items() if c == canonical}


_COUNTRY_NAMES = [
    "poland polska pologne polen pol",
    "great britain|united kingdom|england|britain|british|gbr",
    "germany deutschland allemagne ger deu",
    "austria osterreich autriche aut",
    "bulgaria bulgarie bul bgr",
    "bahrain bahrein brn bhr",
    "france fra",
    "sweden sverige suede swe",
    "ireland eire irlande irl",
    "belgium belgique belgie belgien bel",
    "hungary magyarorszag hongrie ungarn hun",
    "spain espana espagne esp",
    "italy italia italie ita",
    "czechia|czech republic|cesko|cze",
    "netherlands|nederland|pays-bas|ned|nld",
    "switzerland suisse schweiz svizzera sui che",
    "portugal por",
    "croatia hrvatska cro hrv",
    "slovakia slovensko svk",
    "georgia sakartvelo geo",
]


def _country_names(country: str) -> set[str]:
    """Every name and code of the event's country, folded."""
    folded = _fold(country)
    for line in _COUNTRY_NAMES:
        names = line.split("|") if "|" in line else line.split()
        if folded in names:
            return set(names)
    return {folded} if folded else set()


_GENERIC_WORDS = {
    "evf",
    "circuit",
    "veterans",
    "veteran",
    "veteranen",
    "veterans'",
    "vet",
    "fencing",
    "international",
    "open",
    "tournament",
    "event",
    "cup",
    "coupe",
    "puchar",
    "the",
    "and",
    "of",
    "in",
    "des",
    "de",
    "du",
    "la",
    "le",
    "der",
    "die",
}


def _distinctive_words(s: str) -> set[str]:
    return {w for w in re.findall(r"[a-z]{5,}", _fold(s)) if w not in _GENERIC_WORDS}


def _has_word(haystack: str, name: str) -> bool:
    return bool(name) and re.search(rf"\b{re.escape(name)}\b", haystack) is not None


def _names_the_event(event: dict, ident: SourceIdentity) -> bool:
    """Whether the source names the event: city, country, championship or name."""
    haystack = _fold(f"{ident.title} {ident.text}")
    city = str(event.get("txt_location") or "")
    if city and any(_has_word(haystack, n) for n in _city_names(city)):
        return True
    country = str(event.get("txt_country") or "")
    m = re.search(r"\(([A-Z]{3})\)", str(event.get("txt_name") or ""))
    countries = _country_names(country) | (_country_names(m.group(1)) if m else set())
    # The title only, and full names only: a results page lists every
    # fencer's country code, so "POL" is on any page with a Polish fencer.
    if any(_has_word(_fold(ident.title), n) for n in countries if len(n) > 3):
        return True
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    kind = derive_tourn_type_from_event_code(str(event.get("txt_code") or ""))
    title = _fold(ident.title)
    if "champion" in title and (
        (kind == "MSW" and "world" in title) or (kind == "MEW" and "europe" in title)
    ):
        return True
    return (
        len(_distinctive_words(str(event.get("txt_name") or "")) & _distinctive_words(ident.title))
        >= 2
    )


def check_event_sources(
    event: dict, idents: list[SourceIdentity], *, name_confirmed: bool = False
) -> dict[str, list[str]]:
    """Problems per URL, plus key "*" for the weapons counted over all URLs.

    An empty dict means every source is the event. `name_confirmed` means a
    person has confirmed that the sources are this event; the name is then not
    checked, the date and the weapons still are.
    """
    problems: dict[str, list[str]] = {}
    start = _as_date(event.get("dt_start"))
    end = _as_date(event.get("dt_end")) or start
    city = str(event.get("txt_location") or "")

    for ident in idents:
        own: list[str] = []
        if start is None:
            own.append("the event has no start date to compare")
        elif not ident.dates:
            own.append("the source shows no date")
        elif end is not None and not any(
            start - timedelta(days=1) <= d <= end + timedelta(days=1) for d in ident.dates
        ):
            shown = ", ".join(str(d) for d in sorted(ident.dates)[:4])
            own.append(f"the source is dated {shown}; the event is {start} to {end}")
        if not name_confirmed and not _names_the_event(event, ident):
            own.append(
                f"the source ({ident.title!r}) names neither {city or 'the city'}, "
                "its country nor the event"
            )
        if own:
            problems[ident.url] = own

    wanted = event_weapons(event)
    held = set().union(*(i.weapons for i in idents)) if idents else set()
    if not wanted:
        problems["*"] = ["the event has no weapons to compare"]
    elif missing := sorted(wanted - held):
        problems["*"] = [f"no source holds {', '.join(missing)}"]
    return problems
