"""The V-category marker — one owner for a convention that had four.

WHAT THE MARKER IS. A domestic SPWS event runs one mix-all pool per weapon, all
categories together, and the DE brackets are split out of it by age category.
Fencing Time exports results as `name · place · country` and nothing else, so
the only way to know which V-category a fencer was placed in is to carry it in
the name itself. ADR-065 chose a single digit in parentheses.

WHERE IT GOES, AND WHY THAT CHANGED. Between the surname and the given name:

    Nom="KAMIŃSKA (1)"   Prenom="Gabriela"    ->   "KAMIŃSKA (1) Gabriela"

Until 2026-09-12 the exporter appended it to the GIVEN name instead
(`Prenom="Gabriela (1)"`), producing "KAMIŃSKA Gabriela (1)" — which this
module's own reader does not match, because it requires the digit in the
middle. Our seed files therefore did not round-trip through our own scraper.
Nothing had failed loudly because the files that did round-trip were the ones an
organizer typed by hand, and organizers use the mid-name form: all 20 events of
MPW 2026 do, including per-category brackets where the digit is redundant.

WHAT IT IS NOT. The age digit only. Gender travels as the FIE `Sexe` attribute,
and `format_marker` refuses a gendered value rather than accepting it quietly —
the same fact in two places is a disagreement waiting to happen, and the reader
would then have to guess which one is authoritative.

Callers: `python/scrapers/ftl.py`, `python/pipeline/review_cli.py`,
`python/matcher/fuzzy_match.py`, `python/pipeline/ftl_seed_export.py`.
"""

from __future__ import annotations

import re

# The canonical form this module writes, and the two forms it accepts back:
# parenthesised "(1)" and bare "1". Both occur in organizer-typed files.
_SPLIT_RE = re.compile(r"^(.+?)\s+\(?([0-4])\)?\s+(.+)$")

# Removal is deliberately broader than reading, because a name reaching the
# matcher must carry no marker in ANY form anyone has typed — including the
# "(kat V3)" spelling seen in older PZS files.
_STRIP_PARENS_RE = re.compile(r"\s*\((?:kat\s*)?V?\d+\)\s*")
_STRIP_BARE_RE = re.compile(r"\s+[0-4]\s+")

VALID_DIGITS = frozenset("01234")


def format_marker(surname: str, vcat: str | int) -> str:
    """Return the surname carrying its V-category marker.

    Raises ValueError on anything that is not a bare V0-V4 digit, rather than
    coercing it — a gendered marker like "MV3" reaching a seed file would be
    read back as a different fencer.
    """
    digit = str(vcat).strip()
    if digit.upper().startswith("V"):
        digit = digit[1:]
    if digit not in VALID_DIGITS:
        raise ValueError(
            f"V-category marker must be a bare digit V0-V4, got {vcat!r}. "
            "Gender is carried by the FIE Sexe attribute, not by the marker."
        )
    return f"{surname.strip()} ({digit})"


def split_name_marker(full_name: str) -> tuple[str, str, str] | None:
    """Split "SURNAME (N) Given Names" into its three parts.

    Returns None when there is no marker, which is the common case and not an
    error: most scraped names carry none. Returning None rather than raising
    keeps the caller's two branches explicit.
    """
    m = _SPLIT_RE.match(full_name.strip())
    if not m:
        return None
    return m.group(1).strip(), m.group(2), m.group(3).strip()


def extract_marker(full_name: str) -> str | None:
    """The V-category digit alone, for callers that do not need the name parts."""
    parts = split_name_marker(full_name)
    return parts[1] if parts else None


def strip_marker(name: str) -> str:
    """Remove every marker form, leaving the name as it should be stored.

    `tbl_fencer` holds 367 rows and not one contains a digit or a parenthesis.
    Keeping that true is this function's job: a marker that leaks into the
    master list creates a second identity for a fencer who already exists.
    """
    out = _STRIP_PARENS_RE.sub(" ", name)
    out = _STRIP_BARE_RE.sub(" ", out)
    return " ".join(out.split())
