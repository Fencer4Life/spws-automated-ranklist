"""The PZSz organizer-letter reader — the contract, and (piece 3) the parser.

The calendar run reads the organizer's letter for four fields (ADR-116 §8-§9):
pass 1 validates the city, pass 2 finds the venue address, pass 3 the entry
fee, pass 4 the dates. Each pass abstains rather than guess. This module holds
the result the run consumes (:class:`LetterResult`) and the context it is given
(:class:`LetterContext`); :func:`read_letter` turns a letter's PDF bytes into a
result.

The parser itself is built in piece 3, structure-agnostic and proven on the 31
past letters (the golden set and the mutation suite). Until then
:func:`read_letter` raises: the calendar run (piece 2) takes the reader as an
injected seam and is tested with a fake, exactly as the plan's build order
intends (the run is built before the reader).
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from datetime import date


def _fold(text: str) -> str:
    """Lower case without Polish diacritics (ł mapped by hand), for matching
    only; every stored value is cut from the original text."""
    decomposed = unicodedata.normalize("NFKD", text.replace("ł", "l").replace("Ł", "L"))
    return "".join(c for c in decomposed if not unicodedata.combining(c)).lower()


# The reader's version, recorded with every value the letter writes so a
# provenance row says which parser read it (ADR-116 §14). Piece 3 bumps it when
# the rules change.
PARSER_VERSION = "pzsz-letter-v1"

# ----------------------------------------------------------------------------
# Pass 4 — date grammar (ADR-116 §9, traps T15 and T17)
# ----------------------------------------------------------------------------
# Polish month names in the genitive, with and without diacritics (lower() keeps
# length, so match positions stay valid for the folded-copy guards).
_MONTHS: dict[str, int] = {
    "stycznia": 1,
    "lutego": 2,
    "marca": 3,
    "kwietnia": 4,
    "maja": 5,
    "czerwca": 6,
    "lipca": 7,
    "sierpnia": 8,
    "września": 9,
    "wrzesnia": 9,
    "października": 10,
    "pazdziernika": 10,
    "listopada": 11,
    "grudnia": 12,
}
_MONTH_RE = "|".join(sorted(_MONTHS, key=len, reverse=True))
_ROMAN_MONTH: dict[str, int] = {
    "I": 1,
    "II": 2,
    "III": 3,
    "IV": 4,
    "V": 5,
    "VI": 6,
    "VII": 7,
    "VIII": 8,
    "IX": 9,
    "X": 10,
    "XI": 11,
    "XII": 12,
}


@dataclass(frozen=True)
class DateHit:
    """One calendar date found in the text: the date, the span as printed, and
    where it starts. A range is returned as its two endpoints."""

    date: date
    text: str
    start: int


def _valid(year: int, month: int, day: int) -> date | None:
    try:
        return date(year, month, day)
    except ValueError:
        return None


def scan_dates(text: str, *, default_year: int | None = None) -> list[DateHit]:
    """Every calendar date in ``text``, the eleven shapes of T17, ranges
    expanded to their endpoints. Times are refused (T15): a candidate right
    after "godz", one with a colon, and anything that is not a real calendar
    date (month 0, 13, 31 February). A bare "dd.mm." borrows ``default_year``.

    Explicit-year and range forms are matched first and consume their span, so a
    date inside a range is never also read on its own and a bare "dd.mm." never
    bites into a full date."""
    low = text.lower()
    hits: list[DateHit] = []
    taken: list[tuple[int, int]] = []

    def _free(s: int, e: int) -> bool:
        return not any(s < b and e > a for a, b in taken)

    def _ctx_ok(s: int, e: int) -> bool:
        pre = low[max(0, s - 7) : s]
        near = text[max(0, s - 1) : min(len(text), e + 1)]
        return "godz" not in pre and ":" not in near

    def _add(year: int | None, month: int, day: int, s: int, e: int) -> None:
        if year is None:
            return
        day_date = _valid(year, month, day)
        if day_date is None or not _free(s, e) or not _ctx_ok(s, e):
            return
        hits.append(DateHit(day_date, text[s:e], s))

    def _scan(pattern: str, handle) -> None:
        # A span is marked taken once per match (after its endpoints are added),
        # so a range's two endpoints both pass _free, while a later pattern
        # never re-reads a date inside a span already matched.
        for m in re.finditer(pattern, low):
            before = len(hits)
            handle(m)
            if len(hits) > before:
                taken.append((m.start(), m.end()))

    _scan(
        r"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)",
        lambda m: _add(int(m[1]), int(m[2]), int(m[3]), m.start(), m.end()),
    )
    _scan(
        r"(?<!\d)(\d{1,2})/(\d{1,2})/(\d{4})(?!\d)",
        lambda m: _add(int(m[3]), int(m[2]), int(m[1]), m.start(), m.end()),
    )

    # numeric range dd-dd.mm.yyyy
    def _num_range(m):
        _add(int(m[4]), int(m[3]), int(m[1]), m.start(), m.end())
        _add(int(m[4]), int(m[3]), int(m[2]), m.start(), m.end())

    _scan(r"(?<!\d)(\d{1,2})\s*[-–]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})(?!\d)", _num_range)

    # dotted range dd.mm. - dd.mm.yyyy (each endpoint carries its own month)
    def _dot_range(m):
        _add(int(m[5]), int(m[2]), int(m[1]), m.start(), m.end())
        _add(int(m[5]), int(m[4]), int(m[3]), m.start(), m.end())

    _scan(
        r"(?<!\d)(\d{1,2})\.(\d{1,2})\.?\s*[-–]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})(?!\d)", _dot_range
    )
    _scan(
        r"(?<!\d)(\d{1,2})\.(\d{1,2})\.(\d{4})(?!\d)",
        lambda m: _add(int(m[3]), int(m[2]), int(m[1]), m.start(), m.end()),
    )

    # Roman-month dd.Roman.yyyy
    def _roman(m):
        month = _ROMAN_MONTH.get(m[2].upper())
        if month:
            _add(int(m[3]), month, int(m[1]), m.start(), m.end())

    _scan(r"(?<!\d)(\d{1,2})\.([ivx]{1,4})\.(\d{4})(?!\d)", _roman)

    # month-name range dd[-–i ]dd Month yyyy
    def _name_range(m):
        month = _MONTHS[m[3]]
        _add(int(m[4]), month, int(m[1]), m.start(), m.end())
        _add(int(m[4]), month, int(m[2]), m.start(), m.end())

    _scan(rf"(?<!\d)(\d{{1,2}})\s*[-–]\s*(\d{{1,2}})\s+({_MONTH_RE})\s+(\d{{4}})", _name_range)
    _scan(rf"(?<!\d)(\d{{1,2}})\s+i\s+(\d{{1,2}})\s+({_MONTH_RE})\s+(\d{{4}})", _name_range)

    # od dd do dd Month [yyyy]
    def _od_do(m):
        month = _MONTHS[m[3]]
        year = int(m[4]) if m[4] else default_year
        _add(year, month, int(m[1]), m.start(), m.end())
        _add(year, month, int(m[2]), m.start(), m.end())

    _scan(rf"od\s+(\d{{1,2}})\s+do\s+(\d{{1,2}})\s+({_MONTH_RE})(?:\s+(\d{{4}}))?", _od_do)
    # single dd Month yyyy
    _scan(
        rf"(?<!\d)(\d{{1,2}})\s+({_MONTH_RE})\s+(\d{{4}})",
        lambda m: _add(int(m[3]), _MONTHS[m[2]], int(m[1]), m.start(), m.end()),
    )
    # bare dd.mm. (trailing dot, no year) -> default_year
    if default_year is not None:
        _scan(
            r"(?<!\d)(\d{1,2})\.(\d{1,2})\.(?!\d)",
            lambda m: _add(default_year, int(m[2]), int(m[1]), m.start(), m.end()),
        )

    return sorted(hits, key=lambda h: (h.date, h.start))


# ----------------------------------------------------------------------------
# Pass 3 — fee grammar (ADR-116 §9 D4, traps T18 and T19)
# ----------------------------------------------------------------------------
_PLN_TOKENS = {"zł", "zł.", "zl", "złotych", "pln"}
_CURRENCY_RE = r"zł\.|zł|zl|złotych|pln|euro|eur|€"
_AMOUNT_RE = re.compile(
    rf"(\d{{1,4}})(?:[.,]\d{{1,2}})?\s*(?:[.,]?-)?\s*({_CURRENCY_RE})", re.IGNORECASE
)
_FEE_MIN, _FEE_MAX = 1, 500


@dataclass(frozen=True)
class Amount:
    """One money amount in the text: the whole-unit value, its currency (PLN or
    EUR), the line it sits on and the clause up to the next delimiter — the two
    scopes its class is read from."""

    value: int
    currency: str
    line: str
    clause: str


def _currency(token: str) -> str:
    return "PLN" if token.lower() in _PLN_TOKENS else "EUR"


def scan_amounts(text: str) -> list[Amount]:
    """Every money amount, with the line and clause around it. The value is the
    whole-unit integer (the ",00"/".-" tail dropped)."""
    out: list[Amount] = []
    for m in _AMOUNT_RE.finditer(text):
        line_start = text.rfind("\n", 0, m.start()) + 1
        line_end = text.find("\n", m.end())
        line_end = len(text) if line_end < 0 else line_end
        rest = text[m.start() : line_end]
        cuts = [i for i in (rest.find(d) for d in ("/", ";", "(")) if i > 0]
        clause = rest[: min(cuts)] if cuts else rest
        out.append(
            Amount(int(m.group(1)), _currency(m.group(2)), text[line_start:line_end], clause)
        )
    return out


def classify_amount(amount: Amount) -> str:
    """Which kind of fee an amount is (ADR-116 §9 D4). An explicit individual
    marker in its own clause wins; otherwise a disqualifying marker anywhere on
    its line rules it out; an unmarked PLN amount is individual-or-unmarked."""
    if amount.currency == "EUR":
        return "foreign"
    clause = _fold(amount.clause)
    line = _fold(amount.line)
    if any(w in clause for w in ("indywidualn", "od zawodnik", "zawodniczk", "uczestnik")):
        return "individual"
    if "zagraniczn" in line or "nie posiadajac" in line:
        return "foreign"
    if "druzyn" in line:
        return "team"
    if "nagrod" in line:
        return "prize"
    if "po terminie" in line:
        return "late"
    if any(w in line for w in ("hotel", "nocleg", "kaucj", "zakwaterowan")):
        return "other"
    return "individual"  # unmarked -> individual-or-unmarked


def read_fee(text: str) -> tuple[str | None, list[str]]:
    """The individual PLN entry fee, or two candidates, or none (ADR-116 §9 D4).
    EUR, team, prize, late and lodging amounts are excluded; sanity 1-500 PLN."""
    individual = sorted(
        {
            a.value
            for a in scan_amounts(text)
            if a.currency == "PLN"
            and classify_amount(a) == "individual"
            and _FEE_MIN <= a.value <= _FEE_MAX
        }
    )
    if len(individual) == 1:
        return str(individual[0]), []
    if len(individual) > 1:
        return None, [str(v) for v in individual]
    return None, []


# ----------------------------------------------------------------------------
# §8 — normalise and segment
# ----------------------------------------------------------------------------
_ZERO_WIDTH = dict.fromkeys(map(ord, "­​‌‍﻿"), None)
_DASHES = str.maketrans({c: "-" for c in "–—‒―−"})
_QUOTES = str.maketrans({**{c: '"' for c in "“”„‟"}, **{c: "'" for c in "‘’‚‛"}})
_BULLETS = str.maketrans({c: " " for c in "➢•▪◦‣·"})
_TRIPLED_WORD = re.compile(r"^(?:(.)\1{1,2}){3,}$")
_FOOTNOTE_LABELS = ("startowe", "nagrody", "wpisowe", "program", "termin", "turnieju")

# Label lexicon (folded, line-start) -> region. Longest/most specific first.
_LABEL_REGIONS: list[tuple[tuple[str, ...], str]] = [
    (("miejsce zawodow", "miejsce", "obiekt", "lokalizacja", "adres", "hala"), "venue"),
    (("termin zawodow", "w dniach", "w dniu", "data"), "date"),
    (("program", "terminarz"), "programme"),
    (("oplata startowa", "startowe", "wpisowe"), "fee"),
    (("zgloszenia", "potwierdzenie"), "entries"),
    (("zakwaterowanie", "noclegi", "nocleg", "hotel"), "lodging"),
    (("organizator", "wspolorganizator", "kontakt", "sedzia", "komisja techniczna"), "organizer"),
    (("nagrody", "regulamin", "punkt gastronomiczny"), "other"),
]
_CONTACT_RE = re.compile(r"(?i)\btel\b|e-?mail|@|www\.|\bfax\b")


def _collapse_tripled_word(word: str) -> str:
    if word.isalpha() and _TRIPLED_WORD.match(word):
        return re.sub(r"(.)\1{1,2}", r"\1", word)
    return word


# A run of four or more single letters each separated by whitespace is
# letter-spacing (T11): "M i e j s c e   z a w o d ó w" → "Miejsce zawodów".
# Words are kept apart at a run of two or more spaces, so a spaced-out label
# rejoins into the real words the segmenter keys on.
_SPACED = re.compile(r"(?<!\S)[^\W\d_](?:\s+[^\W\d_]){3,}(?!\S)")


def _rejoin_spaced_run(match: re.Match[str]) -> str:
    words = re.split(r"\s{2,}", match.group(0))
    return " ".join(re.sub(r"\s+", "", word) for word in words)


def _normalise(text: str) -> str:
    """Clean one text view (ADR-116 §8): Unicode NFKC, invisible characters and
    no-break spaces away, every dash and curly quote to its plain form, bullets
    to spaces, tripled glyphs collapsed (T12), end-of-line hyphenation rejoined,
    footnote digits glued to a label word stripped (T13). Nothing is guessed."""
    t = unicodedata.normalize("NFKC", text)
    t = t.translate(_ZERO_WIDTH).replace(" ", " ")
    t = t.translate(_DASHES).translate(_QUOTES).translate(_BULLETS)
    t = re.sub(r"\S+", lambda m: _collapse_tripled_word(m.group()), t)
    t = "\n".join(_SPACED.sub(_rejoin_spaced_run, line) for line in t.split("\n"))
    t = re.sub(r"-\n(?=[a-ząćęłńóśźż])", "", t)  # hyphenation across a line
    for label in _FOOTNOTE_LABELS:
        t = re.sub(rf"(?i)\b({label})\d\b", r"\1", t)
    return t


@dataclass(frozen=True)
class Line:
    """One text line with the region the segmenter put it in and its index."""

    text: str
    region: str
    index: int


def _region_of(folded_line: str) -> str | None:
    head = re.sub(r"^\s*\d+[.)]\s*", "", folded_line).lstrip()  # drop a numbered heading
    for labels, region in _LABEL_REGIONS:
        for label in labels:
            if head.startswith(label):
                return region
    return None


def segment(text: str) -> list[Line]:
    """Assign each line a region by the label that last opened one (ADR-116 §8).
    Text before the first label or KOMUNIKAT line is the letterhead; a line with
    tel/e-mail/@/www/fax, and the two above it, is contact. A label only marks a
    region; no pass requires one to exist."""
    raw = text.split("\n")
    regions: list[str] = []
    current = "letterhead"
    seen_heading = False
    for line in raw:
        folded = _fold(line).strip()
        opened = _region_of(folded)
        if not seen_heading and (opened is not None or folded.startswith("komunikat")):
            seen_heading = True
            if current == "letterhead":
                current = "other"
        if opened is not None:
            current = opened
        regions.append(current)
    # contact overrides: a contact line and the two above it
    for i, line in enumerate(raw):
        if _CONTACT_RE.search(line):
            for j in range(max(0, i - 2), i + 1):
                regions[j] = "contact"
    return [Line(raw[i], regions[i], i) for i in range(len(raw))]


# ----------------------------------------------------------------------------
# §9 — pass 2, the venue address
# ----------------------------------------------------------------------------
# A street marker: ul./ulica/al./aleja/pl./plac/os./osiedle/rondo/skwer, then a
# word. Matched on the folded copy so case and diacritics never matter.
_STREET_FOLD = re.compile(r"\b(?:ul|ulica|al|aleja|pl|plac|os|osiedle|rondo|skwer)\.?\s+\S")
_HALL_WORDS = (
    "hala",
    "hali",
    "sala",
    "sali",
    "osir",
    "mosir",
    "mosrir",
    "mosir",
    "awf",
    "azs",
    "szkola",
    "centrum",
    "arena",
    "osrodek",
    "hall",
    "cos",
    "ckis",
)
_PC_RE = re.compile(r"(\d{2}-\d{3})\s+([A-ZŁŚŻŹĆŃÓĄĘ][^\d,\n]{1,40})")
_POSTCODE = re.compile(r"\d{2}-\d{3}")
# The pure labels — words that are never a venue name, so the text after the
# label's separator is the value (Oborniki: "Miejsce zawodów - Hala …"). "hala"
# is NOT here: a line beginning "Hala Sportowa …" is the value, not a label.
_VENUE_LABEL = re.compile(
    r"^\s*(?:\d+[.)]\s*)?(?:miejsce\s+zawodow\w*|miejsce|obiekt|lokalizacja|adres)\b"
)
# Strip the pure label and only its own adjacent decoration — optional
# "(dokładny adres)", then at most one separator — never a wildcard that could
# reach a postcode hyphen deep in the value.
_VENUE_LABEL_STRIP = re.compile(_VENUE_LABEL.pattern + r"\s*(?:\([^)]*\)\s*)?[-:]?\s*")
_ENTRANCE = ("wjazd", "wejscie", "parking", "dojazd")
_FEE_CONTEXT = ("konto", "przelew", "tytulem", "ponizsze dane", "rachunek", "iban", "nr rach")
_LODGING_CONTEXT = ("hotel", "nocleg", "zakwaterowan")


def _hall_word(text: str) -> bool:
    folded = _fold(text)
    return any(re.search(rf"\b{w}\b", folded) for w in _HALL_WORDS)


def _has_house_number(text: str) -> bool:
    """A house number is a one-to-three-digit token once the postcode is removed
    (so '60-995' alone does not count, but 'ul. Długa 30' and '2A' do)."""
    return bool(re.search(r"\d{1,3}", _POSTCODE.sub("", text)))


def _postcode_city(text: str) -> tuple[str, str] | None:
    m = _PC_RE.search(text)
    if not m:
        return None
    return m.group(1), re.split(r"[,(]", m.group(2))[0].strip().rstrip(".")


def _is_venue_label_line(text: str) -> bool:
    return bool(_VENUE_LABEL.match(_fold(text)))


def _strip_venue_label(text: str) -> str:
    """Drop a leading pure label and its separator; _fold keeps length so the
    span found on the folded copy slices the original (diacritics intact)."""
    m = _VENUE_LABEL_STRIP.match(_fold(text))
    return text[m.end() :] if m else text


def _drop_entrance(text: str) -> str:
    def repl(m: re.Match[str]) -> str:
        folded = _fold(m.group(0))
        return "" if any(k in folded for k in _ENTRANCE) else m.group(0)

    return re.sub(r"\s*\([^)]*\)", repl, text)


def _clean_venue(text: str) -> str:
    text = _strip_venue_label(text)
    text = _drop_entrance(text)
    return re.sub(r"\s+", " ", text).strip().strip(",;").strip()


def _valid_venue(value: str) -> bool:
    if not 4 <= len(value) <= 120:
        return False
    if not re.search(r"[^\W\d_]", value):  # at least one letter
        return False
    if re.search(r"\d{7,}", value) or "@" in value or re.search(r"\btel\b", _fold(value)):
        return False
    return bool(_STREET_FOLD.search(_fold(value)))


def _street_key(text: str) -> str:
    folded = _fold(text)
    name = re.search(
        r"\b(?:ul|ulica|al|aleja|pl|plac|os|osiedle|rondo|skwer)\.?\s+([a-z]+)", folded
    )
    num = re.search(r"\b(\d{1,3}[a-z]?)\b", _POSTCODE.sub("", folded))
    return f"{name.group(1) if name else ''} {num.group(1) if num else ''}".strip()


def _venue_block(lines: list[Line], i: int) -> str:
    """Assemble the venue line around the street on line *i*: take the hall name
    from a hall-word line just above in the same region (T6), and the house
    number from the next line when the street split across the line break (T7)."""
    region = lines[i].region
    start = i
    for j in range(i - 1, max(-1, i - 4), -1):
        if not lines[j].text.strip() or lines[j].region != region:
            break
        if _hall_word(lines[j].text):
            start = j
    end = i
    if not _has_house_number(" ".join(lines[k].text for k in range(start, i + 1))):
        nxt = lines[i + 1] if i + 1 < len(lines) else None
        if (
            nxt is not None
            and nxt.region == region
            and nxt.text.strip()
            and _has_house_number(nxt.text)
            and not _STREET_FOLD.search(_fold(nxt.text))
        ):
            end = i + 1
    return _clean_venue(" ".join(lines[k].text for k in range(start, end + 1)))


def _score_street(
    lines: list[Line], i: int, held_city: str | None, corroborated: set[str], value: str
) -> int:
    region = lines[i].region
    score = 0
    if region == "venue":
        score += 5
    if any(_is_venue_label_line(lines[j].text) for j in range(max(0, i - 2), i + 1)):
        score += 2
    if _has_house_number(value):
        score += 2
    if _hall_word(value):
        score += 1
    pc = _postcode_city(value)
    if pc and held_city and _fold(pc[1]).startswith(_fold(held_city)):
        score += 1
    if _street_key(value) in corroborated:
        score += 1
    window = _fold(" ".join(lines[k].text for k in range(max(0, i - 2), min(len(lines), i + 3))))
    if region == "fee" or any(k in window for k in _FEE_CONTEXT):
        score -= 6
    if region == "lodging" or any(k in window for k in _LODGING_CONTEXT):
        score -= 6
    pre = _fold(lines[i].text + " " + (lines[i - 1].text if i > 0 else ""))
    if (
        any(f"{k} od" in pre or f"{k} " in pre for k in ("wjazd", "wejscie"))
        or "parking" in pre
        or "dojazd" in pre
    ):
        score -= 5
    if region in ("letterhead", "contact"):
        score -= 5
    if region == "organizer" and pc and held_city and not _fold(pc[1]).startswith(_fold(held_city)):
        score -= 3
    return score


def find_address(
    lines: list[Line], *, held_city: str | None, corroborated: set[str] | None = None
) -> tuple[Found | None, list[str]]:
    """Pass 2: the full venue line (hall + street + postcode + city), scored by
    the §9 weight table. The winner must score at least 5 and lead the next
    different address by at least 3; otherwise the reader abstains, returning two
    candidates when two compete or nothing when none is confident. It never
    guesses — a letter that states no address writes none (T22)."""
    corroborated = corroborated or set()
    scored: dict[str, tuple[int, int]] = {}
    for i, ln in enumerate(lines):
        if not _STREET_FOLD.search(_fold(ln.text)):
            continue
        value = _venue_block(lines, i)
        if not _valid_venue(value):
            continue
        s = _score_street(lines, i, held_city, corroborated, value)
        if value not in scored or s > scored[value][0]:
            scored[value] = (s, ln.index)
    ranked = sorted(((s, v, idx) for v, (s, idx) in scored.items()), key=lambda t: (-t[0], t[2]))
    if not ranked:
        return None, []
    top_s, top_v, top_idx = ranked[0]
    if top_s < 5:
        return None, []
    if len(ranked) == 1 or top_s - ranked[1][0] >= 3:
        return Found(top_v, f"letter line {top_idx + 1}"), []
    return None, [top_v, ranked[1][1]]


# ----------------------------------------------------------------------------
# §9 — pass 1, city validation (the city is never written, only confirmed)
# ----------------------------------------------------------------------------
def _city_prefix(city: str) -> str:
    """The folded stem a declined form shares: Oborniki→obornik(ach),
    Poznań→poznan(iu). Short enough to survive the locative, long enough not to
    collide (T21)."""
    folded = _fold(city).strip()
    return folded[: max(5, len(folded) - 3)]


def validate_city(lines: list[Line], held_city: str) -> tuple[str | None, bool | None]:
    """Pass 1 confirms the stored city; it never changes it. It returns the city
    of a postcode in the venue section and whether that city agrees with the
    stored one — True if it does, False if the venue postcode names a different
    city (a possible wrong-city letter), and ``(None, None)`` when the letter
    carries no venue postcode to check against. A declined or adjectival form
    (Obornikach, Poznaniu — T21) still agrees, through a folded-stem compare."""
    prefix = _city_prefix(held_city)
    city_seen: str | None = None
    match: bool | None = None
    for ln in lines:
        if ln.region != "venue":
            continue
        pc = _postcode_city(ln.text)
        if pc:
            agrees = bool(prefix) and _fold(pc[1]).startswith(prefix)
            if city_seen is None or not agrees:
                city_seen = pc[1]
            match = agrees if match is None else (match or agrees)
    return city_seen, match


# ----------------------------------------------------------------------------
# §9 — pass 4, selecting the event dates from the scanned hits
# ----------------------------------------------------------------------------
_NOT_EVENT_DATE = (
    "do dnia",
    "do ",
    "termin zglosz",
    "zgloszen",
    "zglaszan",
    "przelew",
    "konto",
    "oplata",
    "platne",
    "platnosc",
    "rezerwac",
    "wplat",
    "z dnia",
    "potwierdz",
    "nadeslania",
    "nadsylania",
    "wyslania",
)
_EVENT_WINDOW_DAYS = 10


def _as_date(value: str | None) -> date | None:
    if not value:
        return None
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def read_dates(views: list[str], ctx: LetterContext) -> tuple[str | None, str | None, str | None]:
    """Pass 4: the competition's start and end dates. Dates are scanned from
    every view, each is kept only if its line is not a deadline/payment/entry
    date (T15), it falls within ten days of the stored start, and it lies in the
    season. The earliest is the start, the latest the end (at most four days
    apart), both returned as ISO strings. A note flags a letter that looks
    copied from last year (a year off) or whose event dates sit outside the
    window (a possible move)."""
    anchor = _as_date(ctx.dt_start)
    season_start, season_end = _as_date(ctx.season_start), _as_date(ctx.season_end)
    default_year = anchor.year if anchor else None
    kept: set[date] = set()
    off_window = False
    copied = False
    for view in views:
        for ln in view.split("\n"):
            folded = _fold(ln)
            deadline = any(k in folded for k in _NOT_EVENT_DATE)
            for hit in scan_dates(ln, default_year=default_year):
                if season_start and season_end and not (season_start <= hit.date <= season_end):
                    if anchor and abs((hit.date - anchor).days) in range(360, 371):
                        copied = True
                    continue
                if deadline:
                    continue
                if anchor and abs((hit.date - anchor).days) > _EVENT_WINDOW_DAYS:
                    off_window = True
                    continue
                kept.add(hit.date)
    if not kept:
        note = (
            "copied-from-last-year" if copied else ("dates-outside-window" if off_window else None)
        )
        return None, None, note
    start, end = min(kept), max(kept)
    if (end - start).days > 4:
        end = start  # a spread this wide is two unrelated dates; keep the start only
    return start.isoformat(), end.isoformat(), None


@dataclass(frozen=True)
class LetterContext:
    """What the run tells the reader about the event: the held city (pass 1
    validates the letter's venue postcode-city against it), the held start date
    (pass 4's window anchor) and the active season's bounds."""

    city: str
    dt_start: str
    season_start: str
    season_end: str


@dataclass(frozen=True)
class Found:
    """A value a pass settled on, with the evidence line behind it."""

    value: str
    evidence: str = ""


@dataclass(frozen=True)
class LetterResult:
    """What the four passes read from one letter. Every field abstains by
    default; a pass fills only what it is sure of (ADR-116 §9)."""

    has_text: bool = True
    # pass 1 — the venue postcode-city, and whether it matched the held city.
    city_seen: str | None = None
    city_match: bool | None = None
    # pass 2 — the full venue line, or two candidates (both reported), else none.
    address: Found | None = None
    address_candidates: tuple[str, ...] = ()
    # pass 3 — the individual PLN fee, or two candidates, else none.
    fee: Found | None = None
    fee_candidates: tuple[str, ...] = ()
    # pass 4 — the event's start and end, with a note when they look off.
    dt_start: str | None = None
    dt_end: str | None = None
    dates_evidence: str = ""
    dates_note: str | None = None  # "differs" | "copied" | None
    # pass-level notes for the digest (e.g. two candidates, no text).
    notes: tuple[str, ...] = field(default_factory=tuple)


# ----------------------------------------------------------------------------
# §8 — the pipeline: kind, the two text views, then the four passes
# ----------------------------------------------------------------------------
def _kind(data: bytes) -> str:
    if data[:4] == b"%PDF":
        return "pdf"
    if data[:2] == b"PK":  # a zip — DOCX and friends
        return "docx"
    if data.lstrip()[:1] == b"<":
        return "html"
    return "other"


def _pdf_views(data: bytes) -> list[str]:
    import io

    from pypdf import PdfReader

    reader = PdfReader(io.BytesIO(data))
    if reader.is_encrypted:
        try:
            reader.decrypt("")
        except Exception:  # noqa: BLE001 — an undecryptable PDF yields no text, handled upstream
            return [""]

    def extract(**kw: object) -> str:
        out: list[str] = []
        for page in reader.pages:
            try:
                out.append(page.extract_text(**kw) or "")  # type: ignore[arg-type]
            except Exception:  # noqa: BLE001 — one bad page must not lose the rest
                out.append("")
        return "\n".join(out)

    return [extract(), extract(extraction_mode="layout")]


def _docx_text(data: bytes) -> str:
    import html as _html
    import io
    import zipfile

    try:
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            xml = z.read("word/document.xml").decode("utf-8", "ignore")
    except Exception:  # noqa: BLE001
        return ""
    xml = re.sub(r"</w:p>", "\n", xml)
    return _html.unescape(re.sub(r"<[^>]+>", "", xml))


def _html_text(data: bytes) -> str:
    import html as _html

    text = data.decode("utf-8", "ignore")
    text = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", text)
    text = re.sub(r"(?i)<br\s*/?>|</p>|</div>|</tr>", "\n", text)
    return _html.unescape(re.sub(r"<[^>]+>", "", text))


def _extract_views(data: bytes, kind: str) -> list[str]:
    if kind == "pdf":
        return _pdf_views(data)
    if kind == "docx":
        text = _docx_text(data)
        return [text, text]
    if kind == "html":
        text = _html_text(data)
        return [text, text]
    return [""]


def read_letter(pdf_bytes: bytes, ctx: LetterContext) -> LetterResult:
    """Read a letter's four fields from its bytes (ADR-116 §8-§9). The bytes may
    be a PDF, a DOCX or an HTML page; a PDF is read in pypdf's plain and layout
    views so a value hidden in one shows in the other. The text is normalised and
    segmented once, then four independent passes run — each abstains rather than
    guess, so a field the letter does not state (or states ambiguously) is simply
    left unwritten. A letter with no extractable text (a scan, T22) returns
    ``has_text=False`` and nothing else."""
    views_raw = _extract_views(pdf_bytes, _kind(pdf_bytes))
    if not any(v.strip() for v in views_raw):
        return LetterResult(has_text=False)

    views = [_normalise(v) for v in views_raw]
    layout = views[-1]
    lines = segment(layout)
    corroborated = {
        _street_key(ln)
        for view in views
        for ln in view.split("\n")
        if _STREET_FOLD.search(_fold(ln))
    }

    city_seen, city_match = validate_city(lines, ctx.city)
    address, address_candidates = find_address(lines, held_city=ctx.city, corroborated=corroborated)
    fee_value, fee_candidates = read_fee(layout)
    dt_start, dt_end, dates_note = read_dates(views, ctx)

    notes: list[str] = []
    if address is None and address_candidates:
        notes.append("address: two candidates")
    if fee_value is None and fee_candidates:
        notes.append("fee: two candidates")

    return LetterResult(
        has_text=True,
        city_seen=city_seen,
        city_match=city_match,
        address=address,
        address_candidates=tuple(address_candidates),
        fee=Found(fee_value) if fee_value else None,
        fee_candidates=tuple(fee_candidates),
        dt_start=dt_start,
        dt_end=dt_end,
        dates_note=dates_note,
        notes=tuple(notes),
    )
