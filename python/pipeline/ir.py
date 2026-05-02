"""
Intermediate Representation (IR) for the unified ingestion pipeline.

ADR-050 (Unified Ingestion Pipeline) + ADR-055 (Ingest Traceability).

The IR is the contract between parsers and the orchestrator. Eight source
mouths (FencingTime XML, FTL, Engarde, 4Fence, Dartagnan, EVF API,
file_import, Ophardt-HTML) each emit a `ParsedTournament` via a uniform
`parse(...) -> ParsedTournament` factory. The orchestrator consumes
`ParsedTournament` and merges it with admin-canonical metadata from
`tbl_event` / `tbl_tournament` before writing draft rows.

## Contract decisions

`source_row_id` (Q1 / Choice A): REQUIRED on every ParsedResult. Parsers
without a native stable ID call `make_synthetic_id()` to construct a
deterministic ID from `(source, row_index, place, name)`. Three parsers
have native IDs they can wrap directly: FencingTime XML (`fencer_id_xml`),
EVF API (`competition_id`), Ophardt (`/athlete/{id}/`).

`parsed_date` / `weapon` / `gender` / `category_hint` (Q2 / Choice A):
OPTIONAL. Parsers fill if natively extractable from the source; leave
None otherwise. The orchestrator overlays canonical values from admin
input before draft writes; ADR-052 validation compares parser-extracted
to admin-canonical and routes mismatches to admin review.

`season_end_year` / `organizer_hint` / `source_artifact_path`: orchestrator
fills these post-parse from admin context.

## Cross-language enum sync

`SourceKind` values MUST match the Postgres `enum_parser_kind` in declared
order (migration 20260501000003_phase1_ingest_traceability.sql). The pytest
`test_source_kind_matches_postgres_enum` enforces this — keep both in lockstep
when adding a new source.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date
from enum import Enum


class SourceKind(str, Enum):
    """The 8 parser sources feeding the unified pipeline.

    Mirror of Postgres `enum_parser_kind`. See module docstring for sync rule.
    """

    FENCINGTIME_XML = "FENCINGTIME_XML"
    FTL = "FTL"
    ENGARDE = "ENGARDE"
    FOURFENCE = "FOURFENCE"
    DARTAGNAN = "DARTAGNAN"
    EVF_API = "EVF_API"
    FILE_IMPORT = "FILE_IMPORT"
    OPHARDT_HTML = "OPHARDT_HTML"
    CERT_REF = "CERT_REF"  # Phase 4 (ADR-050): cert_ref fallback when no live URL


@dataclass
class ParsedResult:
    """One result row from one tournament parse.

    `source_row_id`, `fencer_name`, and `place` are required — the rest are
    fill-if-available. See `make_synthetic_id()` for parsers that lack a
    native stable ID.
    """

    source_row_id: str
    fencer_name: str
    place: int

    fencer_country: str | None = None
    birth_year: int | None = None
    birth_date: date | None = None
    raw_age_marker: str | None = None
    source_vcat_hint: str | None = None
    bool_excluded: bool = False


@dataclass
class ParsedTournament:
    """One tournament's parse output.

    Field-ownership convention:
      - `source_kind`, `results`: parser-required.
      - `raw_pool_size`, `parsed_date`, `weapon`, `gender`, `category_hint`,
        `source_url`: parser-optional (extract if natively available).
      - `season_end_year`, `organizer_hint`, `source_artifact_path`:
        orchestrator-injected (parser leaves None).
    """

    source_kind: SourceKind
    results: list[ParsedResult] = field(default_factory=list)

    raw_pool_size: int | None = None
    parsed_date: date | None = None
    weapon: str | None = None
    gender: str | None = None
    category_hint: str | None = None
    source_url: str | None = None

    # Phase 4 (ADR-052): scrapers populate opportunistically for URL→data validation.
    tournament_name: str | None = None
    city: str | None = None
    country: str | None = None

    season_end_year: int | None = None
    organizer_hint: str | None = None
    source_artifact_path: str | None = None


# ---------------------------------------------------------------------------
# Synthetic source_row_id helper for parsers without native stable IDs
# ---------------------------------------------------------------------------

# Polish + common European folding. Extend if a parser surfaces a charset
# the table doesn't already cover.
_FOLD_MAP = str.maketrans({
    "Ą": "A", "Ć": "C", "Ę": "E", "Ł": "L", "Ń": "N",
    "Ó": "O", "Ś": "S", "Ź": "Z", "Ż": "Z",
    "Á": "A", "É": "E", "Í": "I", "Ú": "U",
    "Ñ": "N", "Ä": "A", "Ö": "O", "Ü": "U",
})


def _slug(name: str) -> str:
    """Fold a name to ASCII slug for synthetic IDs.

    Idempotent — running twice gives the same result. Preserves uppercase
    letters and digits; collapses everything else to a single hyphen.
    """
    folded = name.upper().translate(_FOLD_MAP).replace("ß", "SS")
    return re.sub(r"[^A-Z0-9-]+", "-", folded).strip("-")


def make_synthetic_id(
    source: SourceKind,
    row_index: int,
    place: int,
    name: str,
) -> str:
    """Build a deterministic synthetic `source_row_id`.

    Used by parsers that have no native stable ID (FTL, Engarde, 4Fence,
    Dartagnan, file_import). Format::

        {source-prefix}:row{row_index}:place{place}:{name-slug}

    Same inputs always produce the same ID — re-parsing the same source
    yields stable IDs across runs (assuming the source rows haven't been
    reordered or renamed).

    Parsers with native stable IDs (FencingTime XML, EVF API, Ophardt)
    should construct their own ID directly, e.g.
    ``f"ophardt:athlete{athlete_id}"``, rather than using this helper.
    """
    return f"{source.value.lower()}:row{row_index}:place{place}:{_slug(name)}"
