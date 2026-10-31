"""The weapons a text names, in the languages the result platforms use.

One table for every reader: the URL-identity check (`source_identity`) and the
rule that a bracket's title wins over its declared weapon (doc/plans/
weapon-declared-vs-title-check-2026-10-31.html, WPN.TITLE). Organisers give a
bracket's weapon twice, picked from a list (Engarde ``arme``, FencingTime
``Arme``, d'Artagnan's "männlich, Degen") and typed into its title; at PEW
Madrid 2026 "EPEE MALE 2" was declared sabre.

Tests: python/tests/test_weapon_title_wins.py (WPN.TITLE.01–02).
"""

from __future__ import annotations

import re
import unicodedata

# Matched on folded text: lower case, accents removed.
_WEAPON_WORDS = {
    "EPEE": "epee epees szpada szpady szpadzie szpade degen spada spade espada espadas varja",
    "FOIL": "foil foils fleuret fleurets floret florety floretu florecie floretem florett "
    "fioretto fioretti florete floretes",
    "SABRE": "sabre sabres saber szabla szable szabli szablami sabel sciabola sciabole "
    "sable sables kard",
}
# Matched with their accents: folded, the Hungarian foil "tőr" is "tor", a word
# of many place names ("Tor Vergata").
_ACCENTED_WORDS = {"párbajtőr": "EPEE", "tőr": "FOIL"}

_WEAPON_OF: dict[str, str] = {w: k for k, words in _WEAPON_WORDS.items() for w in words.split()}
_WEAPON_RE = re.compile(r"\b(" + "|".join(sorted(_WEAPON_OF, key=len, reverse=True)) + r")\b")
_ACCENTED_RE = re.compile(
    r"\b(" + "|".join(sorted(_ACCENTED_WORDS, key=len, reverse=True)) + r")\b"
)


def fold(s: str) -> str:
    """Lower case, diacritics removed (ł → l as well)."""
    s = s.replace("ł", "l").replace("Ł", "L")
    return "".join(
        c for c in unicodedata.normalize("NFKD", s) if unicodedata.category(c) != "Mn"
    ).lower()


def find_weapons(text: str) -> set[str]:
    """The weapons named in the text, in any of the platforms' languages."""
    found = {_WEAPON_OF[w] for w in _WEAPON_RE.findall(fold(text))}
    found |= {
        _ACCENTED_WORDS[w] for w in _ACCENTED_RE.findall(unicodedata.normalize("NFC", text).lower())
    }
    return found


def weapon_from_title(declared: str | None, title: str | None) -> tuple[str | None, str | None]:
    """A bracket's weapon: the title's when the title names exactly one weapon,
    otherwise the declared one (WPN.TITLE.02). The second value reports an
    override, a declared weapon the title replaced, and is None otherwise."""
    named = find_weapons(title or "")
    if len(named) != 1:
        return declared, None
    (weapon,) = named
    if declared is not None and declared != weapon:
        return (
            weapon,
            f"title {title!r} names {weapon}; the source declared {declared}; the title wins",
        )
    return weapon, None
