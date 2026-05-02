"""
Phase 4 (ADR-052) — Stage 7 URL→data validation.

Compares scraped source metadata to the canonical event_row opportunistically:
only fields the scraper returned are checked. Six fields halt on mismatch
(date, weapon, gender, age category, country, city); name warns only.

PEW events get a special exception for weapon-mismatch — instead of halting,
the result flags `pew_cascade_pending = True` so Stage 8b can run the cascade
rename via fn_pew_weapon_letters (ADR-046).

Combined-pool sources skip the age-category check (one source URL covers
multiple V-cats; the splitter handles per-category later).

Tests: python/tests/test_url_validation.py.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path
from typing import Any, Literal

import yaml


# ---------------------------------------------------------------------------
# Public types
# ---------------------------------------------------------------------------


@dataclass
class ScrapedMetadata:
    """Metadata extracted from a source for URL→data validation.

    Each field is optional — missing fields are skipped, not failed.
    Populated by scrapers and the orchestrator. The opportunistic policy
    means a vendor that doesn't expose city/country still gets validation
    on the fields it does expose.
    """
    parsed_date: date | None = None
    weapon: str | None = None
    gender: str | None = None
    age_category: str | None = None
    is_combined_pool: bool = False
    city: str | None = None
    country: str | None = None
    tournament_name: str | None = None


Severity = Literal["HALT", "WARN", "INFO"]


@dataclass
class ValidationFinding:
    """One field-level validation finding."""
    field: str
    expected: Any
    actual: Any
    severity: Severity
    message: str


@dataclass
class ValidationResult:
    """Aggregate result of validate_metadata().

    has_halt → at least one HALT finding. Pipeline must not advance to
    Stage 8 when has_halt is true (ADR-052).

    pew_cascade_pending → set by the weapon validator when the PEW exception
    fires (weapon mismatch on a PEW event); Stage 8b reads this to trigger
    cascade rename via fn_pew_weapon_letters.
    """
    halts: list[ValidationFinding] = field(default_factory=list)
    warns: list[ValidationFinding] = field(default_factory=list)
    infos: list[ValidationFinding] = field(default_factory=list)
    pew_cascade_pending: bool = False

    @property
    def has_halt(self) -> bool:
        return bool(self.halts)


# ---------------------------------------------------------------------------
# Normalization helpers
# ---------------------------------------------------------------------------


_POLISH_FOLD = str.maketrans({
    # Stroke / cedilla characters that NFKD doesn't decompose
    "Ą": "A", "Ć": "C", "Ę": "E", "Ł": "L", "Ń": "N",
    "Ó": "O", "Ś": "S", "Ź": "Z", "Ż": "Z",
    "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
    "ó": "o", "ś": "s", "ź": "z", "ż": "z",
})


def _ascii_fold(s: str) -> str:
    """Strip diacritics (incl. Polish strokes); lower-case; trim. 'Łódź' → 'lodz'."""
    if s is None:
        return ""
    s = s.translate(_POLISH_FOLD)
    nfkd = unicodedata.normalize("NFKD", s)
    return "".join(c for c in nfkd if not unicodedata.combining(c)).strip().lower()


_COUNTRY_ISO3: dict[str, str] = {
    # Polish veterans-fencing scope: small canonical map. Add more as needed.
    "POL": "POL", "PL": "POL", "POLAND": "POL", "POLSKA": "POL",
    "HUN": "HUN", "HU": "HUN", "HUNGARY": "HUN",
    "GER": "GER", "DE": "GER", "DEU": "GER", "GERMANY": "GER",
    "FRA": "FRA", "FR": "FRA", "FRANCE": "FRA",
    "ITA": "ITA", "IT": "ITA", "ITALY": "ITA",
    "AUT": "AUT", "AT": "AUT", "AUSTRIA": "AUT",
    "CZE": "CZE", "CZ": "CZE", "CZECH REPUBLIC": "CZE", "CZECHIA": "CZE",
    "SVK": "SVK", "SK": "SVK", "SLOVAKIA": "SVK",
    "FIN": "FIN", "FI": "FIN", "FINLAND": "FIN",
    "GBR": "GBR", "UK": "GBR", "GB": "GBR", "UNITED KINGDOM": "GBR",
    "ESP": "ESP", "ES": "ESP", "SPAIN": "ESP",
    "SWE": "SWE", "SE": "SWE", "SWEDEN": "SWE",
    "NOR": "NOR", "NO": "NOR", "NORWAY": "NOR",
    "DEN": "DEN", "DK": "DEN", "DENMARK": "DEN",
    "BEL": "BEL", "BE": "BEL", "BELGIUM": "BEL",
    "NED": "NED", "NL": "NED", "NETHERLANDS": "NED",
    "SUI": "SUI", "CH": "SUI", "SWITZERLAND": "SUI",
    "RUS": "RUS", "RU": "RUS", "RUSSIA": "RUS",
    "UKR": "UKR", "UA": "UKR", "UKRAINE": "UKR",
}


def _normalize_country(c: str | None) -> str | None:
    if c is None:
        return None
    return _COUNTRY_ISO3.get(c.strip().upper())


# ---------------------------------------------------------------------------
# City alias loader (lazy, module-cached)
# ---------------------------------------------------------------------------


_CITY_ALIASES_PATH = Path(__file__).parent / "city_aliases.yaml"
_alias_to_canonical_cache: dict[str, str] | None = None


def _load_city_aliases() -> dict[str, str]:
    """Load and cache the alias-to-canonical map (folded keys)."""
    global _alias_to_canonical_cache
    if _alias_to_canonical_cache is not None:
        return _alias_to_canonical_cache

    if not _CITY_ALIASES_PATH.exists():
        _alias_to_canonical_cache = {}
        return _alias_to_canonical_cache

    raw = yaml.safe_load(_CITY_ALIASES_PATH.read_text(encoding="utf-8")) or {}
    out: dict[str, str] = {}
    for canonical, aliases in raw.items():
        canonical_folded = _ascii_fold(canonical)
        out[canonical_folded] = canonical_folded  # canonical is its own alias
        for a in (aliases or []):
            out[_ascii_fold(a)] = canonical_folded
    _alias_to_canonical_cache = out
    return out


def _normalize_city(c: str | None) -> str | None:
    if c is None:
        return None
    folded = _ascii_fold(c)
    if not folded:
        return None
    aliases = _load_city_aliases()
    return aliases.get(folded, folded)  # if not in alias table, canonical = folded form


# ---------------------------------------------------------------------------
# Per-field validators
# ---------------------------------------------------------------------------


def _is_pew(event_row: dict) -> bool:
    code = event_row.get("txt_code", "") or ""
    return code.startswith("PEW")


def _coerce_date(v):
    """Accept ISO string / date / datetime / None; return date or None."""
    from datetime import datetime
    if v is None:
        return None
    if isinstance(v, date) and not isinstance(v, datetime):
        return v
    if isinstance(v, datetime):
        return v.date()
    try:
        return date.fromisoformat(str(v)[:10])
    except ValueError:
        return None


def _check_date(event_row: dict, scraped: ScrapedMetadata, result: ValidationResult) -> None:
    if scraped.parsed_date is None:
        return
    expected_start = _coerce_date(event_row.get("dt_start"))
    expected_end = _coerce_date(event_row.get("dt_end")) or expected_start
    if expected_start is None:
        return  # event row has no date — can't compare

    # Tolerance: ±1 day from any day in [start, end]
    earliest = expected_start - timedelta(days=1)
    latest = expected_end + timedelta(days=1)
    if earliest <= scraped.parsed_date <= latest:
        return

    result.halts.append(ValidationFinding(
        field="date",
        expected=expected_start.isoformat() + (
            f"..{expected_end.isoformat()}" if expected_end != expected_start else ""
        ),
        actual=scraped.parsed_date.isoformat(),
        severity="HALT",
        message=f"Date {scraped.parsed_date} outside ±1 day of event window",
    ))


def _check_weapon(event_row: dict, scraped: ScrapedMetadata, result: ValidationResult) -> None:
    if scraped.weapon is None:
        return
    expected = event_row.get("enum_weapon")
    if expected is None or scraped.weapon == expected:
        return

    if _is_pew(event_row):
        # PEW exception (ADR-046): mismatch is a flag for cascade rename, not a halt.
        result.pew_cascade_pending = True
        result.infos.append(ValidationFinding(
            field="weapon",
            expected=expected,
            actual=scraped.weapon,
            severity="INFO",
            message=f"PEW event weapon set will be cascade-renamed (Stage 8b) to include {scraped.weapon}",
        ))
        return

    result.halts.append(ValidationFinding(
        field="weapon",
        expected=expected,
        actual=scraped.weapon,
        severity="HALT",
        message=f"Weapon mismatch: event={expected} vs scraped={scraped.weapon}",
    ))


def _check_gender(event_row: dict, scraped: ScrapedMetadata, result: ValidationResult) -> None:
    if scraped.gender is None:
        return
    expected = event_row.get("enum_gender")
    if expected is None or scraped.gender == expected:
        return
    result.halts.append(ValidationFinding(
        field="gender",
        expected=expected,
        actual=scraped.gender,
        severity="HALT",
        message=f"Gender mismatch: event={expected} vs scraped={scraped.gender}",
    ))


def _check_age_category(event_row: dict, scraped: ScrapedMetadata, result: ValidationResult) -> None:
    if scraped.is_combined_pool:
        return  # Skip — splitter at Stage 4 handles per-category resolution
    if scraped.age_category is None:
        return
    expected = event_row.get("enum_age_category")
    if expected is None or scraped.age_category == expected:
        return
    result.halts.append(ValidationFinding(
        field="age_category",
        expected=expected,
        actual=scraped.age_category,
        severity="HALT",
        message=f"Age category mismatch: event={expected} vs scraped={scraped.age_category}",
    ))


def _check_country(event_row: dict, scraped: ScrapedMetadata, result: ValidationResult) -> None:
    if scraped.country is None:
        return
    expected_norm = _normalize_country(event_row.get("txt_country"))
    actual_norm = _normalize_country(scraped.country)
    if expected_norm is None:
        return  # event row has no country — can't compare
    if actual_norm is None:
        # scraped country not in our ISO map; can't normalize → skip with info
        result.infos.append(ValidationFinding(
            field="country",
            expected=expected_norm,
            actual=scraped.country,
            severity="INFO",
            message=f"Scraped country {scraped.country!r} not in ISO normalize map; check skipped",
        ))
        return
    if actual_norm == expected_norm:
        return
    result.halts.append(ValidationFinding(
        field="country",
        expected=expected_norm,
        actual=actual_norm,
        severity="HALT",
        message=f"Country mismatch: event={expected_norm} vs scraped={actual_norm}",
    ))


def _check_city(event_row: dict, scraped: ScrapedMetadata, result: ValidationResult) -> None:
    if scraped.city is None:
        return
    expected_canon = _normalize_city(event_row.get("txt_city"))
    actual_canon = _normalize_city(scraped.city)
    if expected_canon is None:
        return  # event row has no city
    if actual_canon == expected_canon:
        return
    result.halts.append(ValidationFinding(
        field="city",
        expected=event_row.get("txt_city"),
        actual=scraped.city,
        severity="HALT",
        message=f"City mismatch (after alias normalize): event={event_row.get('txt_city')!r} vs scraped={scraped.city!r}",
    ))


def _check_name(event_row: dict, scraped: ScrapedMetadata, result: ValidationResult) -> None:
    if scraped.tournament_name is None:
        return
    expected = (event_row.get("txt_name") or "").strip()
    actual = scraped.tournament_name.strip()
    if not expected:
        return
    if _ascii_fold(expected) == _ascii_fold(actual):
        return
    result.warns.append(ValidationFinding(
        field="name",
        expected=expected,
        actual=actual,
        severity="WARN",
        message=f"Tournament name differs (warn-only): event={expected!r} vs scraped={actual!r}",
    ))


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


_VALIDATORS = (
    _check_date,
    _check_weapon,
    _check_gender,
    _check_age_category,
    _check_country,
    _check_city,
    _check_name,
)


def validate_metadata(event_row: dict, scraped: ScrapedMetadata) -> ValidationResult:
    """Validate scraped source metadata against the canonical event row.

    See module docstring for behavior matrix. Returns a ValidationResult;
    callers check result.has_halt to decide whether to halt the pipeline,
    and result.pew_cascade_pending to flag Stage 8b post-commit work.

    Args:
        event_row: dict with keys txt_code, txt_organizer_code, dt_start,
            dt_end, enum_weapon, enum_gender, enum_age_category, txt_city,
            txt_country, txt_name. Missing keys are treated as None.
        scraped: ScrapedMetadata with what the scraper returned. None
            fields are skipped (opportunistic validation).
    """
    result = ValidationResult()
    for validator in _VALIDATORS:
        validator(event_row, scraped, result)
    return result
