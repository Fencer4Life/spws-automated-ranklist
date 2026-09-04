"""
The shared location contract for every calendar scraper.

Each source publishes the same three things about where a competition happens —
a **city**, a **venue title** and a **street address** — and each publishes them
in a different place and a different shape. This module owns what is common: how
a city string is cleaned, what disqualifies a string from being a city at all,
and where the venue title ends up.

The *rungs* stay with each scraper, because they read different pages. EVF's
strongest signal is the event name; PZSz's is a dedicated `Miejsce` column.
Running one source's rungs against the other produces nonsense — PZSz addresses
are street-only (`ul. Siennicka 40B`, no city, no country), so EVF's address rung
would happily return the street as the city.

WHY THE CITY IS RESOLVED AT SCRAPE TIME AND NOT AT RENDER TIME. It used to be the
other way round: the scraper wrote whatever the source called a "venue" into
`tbl_event.txt_location`, and the frontend guessed venue-from-city on the way out
(`calendarMonths.ts:splitLocation`). A guess made at render time is made again on
every page load, cannot be corrected by an admin, and silently printed
"Sporthalle der Städtischen Berufsschule für Informationstechnik" into a 48px
calendar tile. Resolving once, at the source, puts a real city in the column that
is documented to hold one.

THE VENUE RULE.
  * An address is present  -> the venue title is dropped. It is already invisible
    in the UI whenever an address exists (EventCard renders `txt_venue_address`
    and only falls back to the venue when that is blank), and the addresses
    themselves usually already name the venue: "Palavesuvio ingresso carrabile,
    Napoli, NA, Italy", "UCD Sport Center Belfield Dublin, Dublin, Ireland".
  * An address is absent   -> the venue title becomes the address, so the only
    piece of location detail we have is not thrown away.
  * Unless the venue title IS the city -- see `resolve_location`.
"""

from __future__ import annotations

import re
import unicodedata

# Words that mark a string as the name of a building rather than a place. Kept in
# step with VENUE_WORDS in frontend/src/lib/calendarMonths.ts, which stays as the
# render-time safety net for admin-entered values and legacy rows.
_VENUE_WORDS = re.compile(
    r"sporthalle|salle |complexe|polideportivo|palavesuvio|spectrum|idrottshall"
    r"|topsporthal|sport ?cent|sports city|castle|pavilh|palais|paladozza"
    r"|country hall|variety village|olympic palace|arena|ar[eé]na|berufsschule"
    r"|stadium|stadion|gymnasium|gimnasio|ginnasio|sportcsarnok|hala |hall\b"
    r"|centre|center|terrace|osir\b|mosir\b",
    re.IGNORECASE,
)

# `– Cancelled` is appended AFTER the city, so it comes off before the tail is
# read. EVF writes it with an en dash; tolerate the ASCII form too.
_CANCELLED_SUFFIX = re.compile(r"\s*[–—-]\s*cancell?ed\s*$", re.IGNORECASE)

# A trailing IOC/ISO-ish country code in parentheses: "(IRL)", "(GER)", "(FIN)".
_TRAILING_COUNTRY_CODE = re.compile(r"\s*\(\s*[A-Za-z]{2,3}\s*\)\s*$")

# ONLY en dash and em dash. An ASCII hyphen is part of city names
# ("Fâches-Thumesnil") and of bare event codes ("IMEW-2026-2027"), so splitting on
# it would yield "Thumesnil" and "2027".
_NAME_SEPARATORS = ("–", "—")

# "05-092 Łomianki" -> "Łomianki". Also covers "1234 AB Amsterdam".
_LEADING_POSTCODE = re.compile(r"^\d[\d\s-]*[A-Z]{0,2}\s+")

# An Italian province ("NA"), a US state ("CA") — an administrative subdivision
# sitting between the city and the country, never the city itself.
_PROVINCE_CODE = re.compile(r"^[A-Z]{2}$")


def normalise_city(value: str | None) -> str:
    """Trim a city candidate to its usable form.

    Takes the part before the first comma, because both sources write a city with
    its region attached: EVF's "Chania, Crete", PZSz's occasional
    "Warszawa, mazowieckie".
    """
    if not value:
        return ""
    text = str(value).split(",", 1)[0]
    return " ".join(text.split()).strip(" -–—,;")


def _fold(value: str) -> str:
    """Case- and diacritic-insensitive form, for comparing two spellings."""
    decomposed = unicodedata.normalize("NFKD", str(value or "").strip().casefold())
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def looks_like_venue(value: str | None) -> bool:
    """Whether a string names a building rather than a place.

    Deliberately conservative: it must be cheaper to leave a city line blank than
    to print a hall name where a fencer expects a town.
    """
    if not value:
        return False
    return bool(_VENUE_WORDS.search(str(value)))


def city_from_name(name: str | None) -> str:
    """The city out of an event name shaped `<Title> – <City> (<CC>)`.

    Returns "" when the name carries no separator at all rather than guessing
    from the title — "Levi Open (FIN)" gives nothing, which is correct.
    """
    if not name:
        return ""
    text = _CANCELLED_SUFFIX.sub("", str(name)).strip()
    text = _TRAILING_COUNTRY_CODE.sub("", text).strip()

    cut = max(text.rfind(sep) for sep in _NAME_SEPARATORS)
    if cut < 0:
        return ""

    tail = normalise_city(text[cut + 1 :])
    return "" if looks_like_venue(tail) else tail


def city_from_address(address: str | None, country: str | None = "") -> str:
    """The city out of a comma-separated postal address.

    The final part is dropped only when it actually IS the country. "Always drop
    the last part" would destroy `Ul. Stanisława Staszica 2, 05-092 Łomianki`,
    which carries no country and whose city is therefore last.
    """
    if not address:
        return ""

    parts = [p.strip() for p in str(address).split(",")]
    parts = [p for p in parts if p]
    if not parts:
        return ""

    if len(parts) > 1 and country and _fold(parts[-1]) == _fold(country):
        parts.pop()

    while parts:
        candidate = parts[-1]
        if _PROVINCE_CODE.match(candidate):
            parts.pop()
            continue
        cleaned = _LEADING_POSTCODE.sub("", candidate).strip()
        cleaned = normalise_city(cleaned)
        return "" if looks_like_venue(cleaned) else cleaned

    return ""


def resolve_location(
    city_candidates: list[str] | None,
    venue_title: str | None,
    address: str | None,
) -> tuple[str, str]:
    """Resolve one event's `(txt_location, txt_venue_address)`.

    `city_candidates` is the scraper's own rung order, best first; the first
    non-blank, non-venue entry wins, and the venue title is the last resort.

    The venue rule is applied here so both scrapers cannot drift apart on it. The
    guard on promoting a venue title into the address matters more than it looks:
    every EVF row that currently has no address holds a *city* in its venue field
    (`Samorin`, `Jabłonna`, `Napoli`, `Plovdiv`), so without it the city would be
    copied into the address and the card would read the same word twice.
    """
    city = ""
    for candidate in list(city_candidates or []):
        cleaned = normalise_city(candidate)
        if cleaned and not looks_like_venue(cleaned):
            city = cleaned
            break

    venue = " ".join(str(venue_title or "").split()).strip()
    resolved_address = " ".join(str(address or "").split()).strip()

    if not city and venue and not looks_like_venue(venue):
        city = normalise_city(venue)

    if not resolved_address and venue and _fold(venue) != _fold(city):
        resolved_address = venue

    return city, resolved_address
