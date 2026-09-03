"""
PZSz senior calendar — parsing and planning (pzszerm.pl).

Polish veterans also enter senior national competitions, fencing the same pools
as people half their age. The calendar carried SPWS (PPW/MPW), EVF (PEW) and FIE
(MEW/MSW/PSW) events and nothing at all from Polski Zwiazek Szermierczy, so those
outings were invisible to the system. This module makes them readable.

It is pure: every function here takes text or dicts and returns text or dicts.
Nothing in it touches our database. `fetch_series` is the single exception and
speaks only to the public pzszerm.pl listing.

Scope is PPS (Puchar Polski Seniorow) and MPS (Mistrzostwa Polski Seniorow) in
the Seniorzy (S) age category. Scoring those results is a separate deliverable
and nothing here anticipates it.

WHY THIS IS NOT evf_calendar.py WITH A FLAG. That module's length is EVF-specific
pathology -- invitation-PDF weapon archaeology, slug dedup, future-COMPLETED
healing -- none of which applies to a clean server-rendered HTML table. PZSz
detail pages publish a full weapon x gender tournament breakdown, so no weapon
evidence ladder is needed at all.

THE FINDING THAT SHAPES EVERYTHING HERE. The listing caps at 70 rows with no
pagination, no error, and no outward sign. Different filters return entirely
different 70-row windows: the default view renders descending and its earliest
row is 14.11.2026, so simply reading it would have silently dropped every round I
event of 2026/2027. Any response of exactly 70 rows is presumed truncated and
raises -- see `assert_not_truncated`, which is the one assertion that stops this
scraper failing quietly.
"""

from __future__ import annotations

import logging
import re
import unicodedata
from datetime import date
from io import BytesIO

import httpx
from bs4 import BeautifulSoup, Tag

logger = logging.getLogger(__name__)


PZSZ_BASE = "https://pzszerm.pl"
PZSZ_CALENDAR = f"{PZSZ_BASE}/zawody/kalendarium-zawodow/"
PZSZ_EVENT = f"{PZSZ_CALENDAR}zawody/"

# The source truncates here. Not a page size we can raise -- there is no offset
# parameter on the form at all, only Nazwa, Kategorie_wiekowe_z_turniejow,
# Bronie[0], SezonAutocomplete and Miejsce.
LISTING_ROW_CAP = 70

# ASCII-safe on purpose. Nazwa matches case-insensitively as a substring, so
# these catch both the "Seniorow" and "seniorow" casings the source mixes inside
# one series -- while a raw "o with acute" returns zero rows outright.
SERIES_QUERIES: dict[str, str] = {
    "PPS": "Puchar Polski senior",
    "MPS": "Mistrzostwa Polski senior",
}

# TODO: disabled 2026-09-03, mirroring evf_calendar.HARVEST_DEADLINE. PZSz
# publishes no per-event registration deadline: all seven measured komunikaty
# resolve "Termin zgloszen" to the federation's standing regulations, and the
# only concrete cutoff any of them states is confirmation to the Technical
# Committee 45 minutes before the start -- a check-in rule at the venue, not a
# registration deadline. Live yield was 0 of 7. Turn this on only if a real
# per-event phrasing is ever observed.
HARVEST_DEADLINE = False

_WEAPON_NAMES = {
    "floret": "FOIL",
    "szpada": "EPEE",
    "szabla": "SABRE",
}
# English weapon letters, as ADR-046 already fixes them for PEW codes.
_WEAPON_LETTERS = {"EPEE": "e", "FOIL": "f", "SABRE": "s"}

_ROMAN = {"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5, "VI": 6, "VII": 7, "VIII": 8}
_ROUND_RE = re.compile(r"^\s*(I{1,3}|IV|VI{0,3}|V)\s+(?=\S)")

_EVENT_ID_RE = re.compile(r"[?&]id=(\d+)")
_DATE_RE = re.compile(r"^(\d{1,2})\.(\d{1,2})\.(\d{1,4})$")

# A calendar row outside this is corruption, not history: the live listing
# carries an end date of 11.05.0251 on id 4307.
_MIN_YEAR = 2000
_MAX_YEAR = 2100

_SENIOR_AGE_RE = re.compile(r"seniorzy\s*\(s\)")
_PPS_NAME_RE = re.compile(r"puchar\s+polski\s+senior")
_MPS_NAME_RE = re.compile(r"mistrzostwa\s+polski\s+senior")
# The same page carries World Cups, Grand Prix and World/European championships
# under the identical Seniorzy (S) category. None of them is a Polish national
# competition, and "Puchar Swiata" contains "Puchar" -- so the reject list is
# not optional.
_INTERNATIONAL_RE = re.compile(r"\b(swiata|europy|grand\s+prix|world|european)\b")

_WOMEN_RE = re.compile(r"\bkobiet")
# Folding absorbs the live typo for free: both "mezczyzn" and the misspelt
# "mezczyzn" (id 4412 writes 'm-e-z-c-z-y-z-n' with a stray acute) reduce to the
# same ASCII run once diacritics are stripped.
_MEN_RE = re.compile(r"\bmezczyzn")

_STREET_RE = re.compile(r"^(?:ul|Ul|UL|al|Al|AL)\.\s*\S.*?\d")


class PzszTruncatedListingError(RuntimeError):
    """Raised when a listing response is at the 70-row cap, and so is presumed
    truncated. The source gives no other signal, so the row count is the signal.
    """


class PzszSourceDataError(RuntimeError):
    """Raised when a source cell cannot be trusted — an out-of-range year, a
    malformed date. Refusing loudly is the point: an unnoticed 0251 would land
    in tbl_event.dt_end and reach a fencer reading the calendar.
    """


class PzszCodeCollisionError(RuntimeError):
    """Raised when two events resolve to one event code. Mirrors
    evf_calendar.CalendarIntegrityError: overwriting is never the right answer.
    """


def _fold(text: str | None) -> str:
    """Lower-case and strip diacritics, so Polish spellings compare as one.

    Seniorow/seniorow, Gdansk/Gdansk and the misspelt mezczyzn all collapse here.
    """
    if not text:
        return ""
    decomposed = unicodedata.normalize("NFKD", str(text).strip().lower())
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def normalise_date(raw: str) -> str:
    """`dd.mm.yyyy` -> ISO `yyyy-mm-dd`, refusing anything implausible.

    The source's own data quality forces this: id 4307 carries an end date of
    11.05.0251. Writing that to dt_end would corrupt the calendar silently, so a
    year outside 2000..2100 raises instead.
    """
    match = _DATE_RE.match(str(raw or "").strip())
    if not match:
        raise PzszSourceDataError(f"unparseable PZSz date {raw!r}")

    day, month, year = (int(part) for part in match.groups())
    if not _MIN_YEAR <= year <= _MAX_YEAR:
        raise PzszSourceDataError(
            f"PZSz date {raw!r} carries an out-of-range year {year}; refusing to store it"
        )
    try:
        return date(year, month, day).isoformat()
    except ValueError as exc:
        raise PzszSourceDataError(f"invalid PZSz date {raw!r}: {exc}") from exc


def _weapons_from_cell(cell_text: str) -> list[str]:
    """'Floret (Fl), Szpada (Szp)' -> ['FOIL', 'EPEE']."""
    folded = _fold(cell_text)
    return [name for polish, name in _WEAPON_NAMES.items() if polish in folded]


def parse_calendar_html(html: str) -> list[dict]:
    """Parse one listing response into row dicts.

    The table interleaves month-separator rows (`colspan=5`, no `tab-row` class)
    with data rows, so the cell class is what selects the data.
    """
    soup = BeautifulSoup(html, "html.parser")
    rows: list[dict] = []

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

        texts = [cell.get_text(" ", strip=True) for cell in cells]
        rows.append(
            {
                "id_pzsz_event": int(id_match.group(1)),
                "name": anchor.get_text(" ", strip=True),
                "url_event": f"{PZSZ_EVENT}?id={id_match.group(1)}",
                "age_category": texts[1],
                "weapons": _weapons_from_cell(texts[2]),
                # Provenance only. Membership is decided by our own season
                # window, never by this label -- see `belongs_to_season`.
                "pzsz_season": texts[3],
                "dt_start": normalise_date(texts[4]),
                "dt_end": normalise_date(texts[5]),
                "location": texts[6],
                "txt_country": "PL",
            }
        )

    return rows


def assert_not_truncated(rows: list[dict]) -> None:
    """Raise when a response sits exactly on the cap.

    The source truncates from the bottom of a descending render and says nothing
    about it, so a full page is indistinguishable from a complete result except
    by its size. Presuming truncation at exactly 70 costs a false alarm on the
    day a query legitimately returns 70 rows; presuming completeness costs
    missing events on a calendar veterans plan around.
    """
    if len(rows) >= LISTING_ROW_CAP:
        raise PzszTruncatedListingError(
            f"PZSz listing returned {len(rows)} rows, at or above the {LISTING_ROW_CAP}-row cap: "
            "the response is truncated with no pagination. Narrow the query "
            "(the Bronie[0] weapon axis is the held-in-reserve third narrowing)."
        )


def is_national_senior(row: dict) -> bool:
    """Whether a listing row is a Polish national senior PPS or MPS event.

    Two independent conditions, because either alone lets the wrong events in:
    the Seniorzy (S) age category also covers World Cups and World
    Championships, and the PPS/MPS name shape also appears on junior events
    ("juniorow" does not match "senior", which is what keeps them out).
    """
    name = _fold(row.get("name"))
    if not _SENIOR_AGE_RE.search(_fold(row.get("age_category"))):
        return False
    if _INTERNATIONAL_RE.search(name):
        return False
    return bool(_PPS_NAME_RE.search(name) or _MPS_NAME_RE.search(name))


def belongs_to_season(row: dict, dt_start: str, dt_end: str) -> bool:
    """Whether an event falls inside OUR season window.

    PZSz does not define seasons the way we do, so their label decides nothing.
    An event they call 2025/2026 that runs after our season opens is ours; one
    they call 2026/2027 that runs past our close is not. `pzsz_season` is kept
    as provenance and is deliberately not consulted here.
    """
    start = str(row.get("dt_start") or "")
    return bool(start) and dt_start <= start <= dt_end


def season_keys_for_window(dt_start: str, dt_end: str) -> list[str]:
    """The PZSz season keys that could hold a date in our window.

    SezonAutocomplete is demoted to what it actually is: a pagination key for
    getting under the 70-row cap, worthless as semantics but load-bearing as
    access. A key PZSz does not have returns zero rows rather than the
    unfiltered 70 -- verified against 2027/2028 -- which is exactly what makes
    querying a year ahead of publication safe.
    """
    first = int(dt_start[:4])
    last = int(dt_end[:4])
    # A window opening mid-2026 can hold events PZSz filed under 2025/2026
    # (their season straddles the new year), so reach one key back.
    return [f"{year}/{year + 1}" for year in range(first - 1, last + 1)]


def parse_round(name: str) -> int | None:
    """The leading Roman numeral of a PPS name. MPS is not a round of anything."""
    match = _ROUND_RE.match(str(name or ""))
    if match is None:
        return None
    return _ROMAN.get(match.group(1))


def weapon_letters(row: dict) -> str:
    """The canonical alphabetical e/f/s run, as ADR-046 fixes it for PEW."""
    letters = {
        _WEAPON_LETTERS[str(weapon).upper()]
        for weapon in row.get("weapons") or []
        if str(weapon).upper() in _WEAPON_LETTERS
    }
    return "".join(sorted(letters))


def _gender_letter(name: str) -> str:
    """'' when a competition is open to both, else 'W' for women or 'M' for men.

    A PPS round is occasionally split by gender into two genuinely separate
    competitions -- round IV epee 2025/2026 ran men in Gliwice 16-17.05 and women
    in Warszawa 17.05, different cities, different organising clubs, six days
    apart -- and both halves would otherwise resolve to PPS4e.

    W and M, NOT the project's usual M/F. Event-code weapon letters are English
    (e/f/s) and the trailing lowercase run of a code IS the weapon list, so
    following the enum_gender_type convention would give PPS4Fe -- one case-fold
    away from PPS4fe, in which F means foil. W carries no weapon meaning. The
    uppercase also keeps the gender letter clear of the weapon run, so the
    frontend's weaponLetters() /[efs]+$/ still resolves 'e' correctly.
    """
    folded = _fold(name)
    women = bool(_WOMEN_RE.search(folded))
    men = bool(_MEN_RE.search(folded))
    if women and not men:
        return "W"
    if men and not women:
        return "M"
    return ""


def plan_event_codes(rows: list[dict], season_code: str) -> list[dict]:
    """Attach a `desired_code` to every row, refusing to let two share one.

    ADR-046 shape: series, round number, optional gender letter, weapon letters,
    season suffix. MPS carries no round.
    """
    season_suffix = re.sub(r"^SPWS-", "", season_code)
    planned: list[dict] = []

    for row in rows:
        event = dict(row)
        name = str(event.get("name") or "")
        folded = _fold(name)

        if _MPS_NAME_RE.search(folded):
            series, round_part = "MPS", ""
        else:
            series = "PPS"
            number = parse_round(name)
            if number is None:
                raise PzszSourceDataError(
                    f"PPS event {event.get('id_pzsz_event')} has no round numeral: {name!r}"
                )
            round_part = str(number)

        event["desired_code"] = (
            f"{series}{round_part}{_gender_letter(name)}{weapon_letters(event)}-{season_suffix}"
        )
        planned.append(event)

    seen: dict[str, int] = {}
    for event in planned:
        code = event["desired_code"]
        if code in seen:
            raise PzszCodeCollisionError(
                f"PZSz events {seen[code]} and {event['id_pzsz_event']} both resolve to {code}; "
                "refusing to overwrite one with the other"
            )
        seen[code] = int(event["id_pzsz_event"])

    return sorted(planned, key=lambda event: (event["dt_start"], event["id_pzsz_event"]))


def fetch_series(
    series: str,
    season_key: str,
    client: httpx.Client | None = None,
    timeout: float = 30.0,
) -> list[dict]:
    """Fetch one Nazwa x SezonAutocomplete query and return its parsed rows.

    Both narrowing axes are required. Nazwa alone returns the capped 70; the
    season key alone returns the capped 70. Together they return a complete
    result -- 6 rows for PPS 2026/2027, 13 for PPS 2025/2026.
    """
    if series not in SERIES_QUERIES:
        raise ValueError(
            f"unknown PZSz series {series!r}; expected one of {sorted(SERIES_QUERIES)}"
        )

    params = {"Nazwa": SERIES_QUERIES[series], "SezonAutocomplete": season_key}
    owned = client is None
    http = client or httpx.Client(timeout=timeout, follow_redirects=True)
    try:
        response = http.get(PZSZ_CALENDAR, params=params)
        response.raise_for_status()
        rows = parse_calendar_html(response.text)
    finally:
        if owned:
            http.close()

    assert_not_truncated(rows)
    logger.info("PZSz %s %s -> %d rows", series, season_key, len(rows))
    return rows


def collect_season_candidates(
    dt_start: str,
    dt_end: str,
    client: httpx.Client | None = None,
) -> list[dict]:
    """Every PPS/MPS event inside our season window, deduplicated on PZSz id.

    Fetch each series x season key, assert none is truncated, union, then filter
    by OUR dates. The union deliberately over-fetches: PPS 2025/2026 returns 13
    rows and PPS 2027/2028 returns 0, and the date filter is what makes the
    boundary cases right rather than merely lucky.
    """
    by_id: dict[int, dict] = {}
    for series in SERIES_QUERIES:
        for season_key in season_keys_for_window(dt_start, dt_end):
            for row in fetch_series(series, season_key, client=client):
                if not is_national_senior(row):
                    continue
                if not belongs_to_season(row, dt_start, dt_end):
                    continue
                by_id.setdefault(int(row["id_pzsz_event"]), row)

    return sorted(by_id.values(), key=lambda row: (row["dt_start"], row["id_pzsz_event"]))


def parse_event_detail_html(html: str) -> dict:
    """Read one PZSz event detail page.

    The invitation letter is anchored on the labelled "Komunikaty organizatora"
    section, NOT on a filename. EVF finds an invitation by testing
    href.lower().endswith(".pdf"); PZSz serves /test/fileDownload.php?fileId=...,
    an opaque download endpoint with no extension, so that rule finds nothing
    here. The label is the more reliable anchor, not the weaker one.

    url_registration and dt_registration_deadline are returned as None
    deliberately, not merely left unset -- see the module docstring on
    HARVEST_DEADLINE, and section 6 of the plan. PZSz entry is club-mediated
    through a login-walled licence system, and a plausible-looking link would
    light the event tile's registration dot and tell a veteran they can enter
    when in fact they cannot.
    """
    soup = BeautifulSoup(html, "html.parser")
    detail: dict = {
        "url_invitation": None,
        "url_registration": None,
        "dt_registration_deadline": None,
    }

    label = soup.find(
        lambda tag: (
            tag.name in ("strong", "b", "h3", "h4")
            and "komunikaty organizatora" in _fold(tag.get_text())
        )
    )
    if label is None:
        return detail

    for element in label.parent.next_elements if label.parent else []:
        if not isinstance(element, Tag):
            continue
        # The Turnieje table closes the section.
        if element.name in ("h4", "table"):
            break
        if element.name == "a" and element.get("href"):
            detail["url_invitation"] = _absolute(str(element["href"]))
            break

    return detail


def _absolute(href: str) -> str:
    """Site-root hrefs become absolute; anything already absolute is untouched."""
    if href.startswith(("http://", "https://")):
        return href
    return f"{PZSZ_BASE}/{href.lstrip('/')}"


def venue_address_from_pdf_bytes(pdf_bytes: bytes) -> str | None:
    """The venue street address, out of the organizer's komunikat.

    The listing's Miejsce cell gives a clean city -- Poznan, Gdansk, Szczecin --
    with none of the venue-string pollution the EVF scraper wrote into
    txt_location. The street appears only inside the letter, but does so
    reliably: 7 of 7 measured komunikaty carried one, on its own line, under the
    "Miejsce Zawodow" heading.
    """
    try:
        import pypdf

        reader = pypdf.PdfReader(BytesIO(pdf_bytes))
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
    except Exception as exc:  # noqa: BLE001 — a bad PDF must not fail the run
        logger.warning("PZSz komunikat unreadable: %s", exc)
        return None

    for line in text.splitlines():
        collapsed = " ".join(line.split())
        if _STREET_RE.match(collapsed):
            return collapsed
    return None
