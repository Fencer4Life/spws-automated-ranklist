"""
Identity resolution — fuzzy name matching.

Compares scraped fencer names against the master fencer list (tbl_fencer)
using RapidFuzz for fuzzy string matching.

Thresholds:
  ≥95  → AUTO_MATCHED  (confident match)
  ≥50  → PENDING       (needs admin review)
  <50  → UNMATCHED     (no viable candidate)
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from rapidfuzz import fuzz

AUTO_MATCH_THRESHOLD = 95
PENDING_THRESHOLD = 50


@dataclass
class MatchResult:
    """Result of matching a scraped name against the fencer database."""

    scraped_name: str
    id_fencer: int | None
    confidence: float
    status: str  # AUTO_MATCHED, PENDING, UNMATCHED
    matched_name: str | None = None


def normalize_name(name: str) -> str:
    """Normalize a name for comparison: lowercase, collapse whitespace."""
    return re.sub(r"\s+", " ", name.strip()).lower()


def parse_scraped_name(name: str) -> tuple[str, str]:
    """Parse 'SURNAME FirstName' into (surname, first_name).

    Single-word names (aliases like 'TK') return (word, '').
    Compound surnames with hyphens are preserved.
    """
    parts = name.strip().split(None, 1)
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[1]


def _build_full_name(fencer: dict) -> str:
    """Build 'SURNAME FirstName' from a fencer record."""
    surname = fencer["txt_surname"]
    first = fencer["txt_first_name"]
    if first:
        return f"{surname} {first}"
    return surname


def _score_against_fencer(scraped: str, fencer: dict) -> float:
    """Compute best match score between scraped name and a fencer.

    Checks:
    1. Full name match (token_sort_ratio for word-order independence)
    2. Alias match (exact match against json_name_aliases)
    """
    scraped_norm = normalize_name(scraped)

    # Check aliases first (exact match = 100)
    aliases = fencer.get("json_name_aliases") or []
    for alias in aliases:
        if normalize_name(alias) == scraped_norm:
            return 100.0

    # Full name fuzzy comparison
    full_name = _build_full_name(fencer)
    full_name_norm = normalize_name(full_name)

    # Use token_sort_ratio: order-independent, handles "Jan KOWALSKI" vs "KOWALSKI Jan"
    score = fuzz.token_sort_ratio(scraped_norm, full_name_norm)

    return score


def find_best_match(
    scraped_name: str,
    fencer_db: list[dict],
) -> MatchResult:
    """Find the best matching fencer for a scraped name.

    Args:
        scraped_name: Name as extracted by scraper (e.g., "KOWALSKI Jan")
        fencer_db: List of fencer dicts with keys:
            id_fencer, txt_surname, txt_first_name, json_name_aliases

    Returns:
        MatchResult with status AUTO_MATCHED, PENDING, or UNMATCHED
    """
    if not fencer_db:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=None,
            confidence=0,
            status="UNMATCHED",
        )

    best_score = 0.0
    best_fencer_id = None
    best_name = None

    for fencer in fencer_db:
        score = _score_against_fencer(scraped_name, fencer)
        if score > best_score:
            best_score = score
            best_fencer_id = fencer["id_fencer"]
            best_name = _build_full_name(fencer)

    if best_score >= AUTO_MATCH_THRESHOLD:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=best_fencer_id,
            confidence=best_score,
            status="AUTO_MATCHED",
            matched_name=best_name,
        )
    elif best_score >= PENDING_THRESHOLD:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=best_fencer_id,
            confidence=best_score,
            status="PENDING",
            matched_name=best_name,
        )
    else:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=None,
            confidence=best_score,
            status="UNMATCHED",
        )
