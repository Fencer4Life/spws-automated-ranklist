"""
cert_ref parser — 9th source kind in the unified pipeline (ADR-050).

Reads pre-fetched rows from the cert_ref schema (a parallel mirror of CERT/PROD)
and produces a ParsedTournament IR. Used when an event has no live source URL
available (operator picks `[5] cert_ref placements` in review CLI). The pipeline
then runs Stages 1-11 normally — the engine still computes points from the
placements; no special status results.

This parser is I/O-free by design: the orchestrator queries cert_ref, hands
the rows to `parse()`, the parser maps them to IR. Keeps the parser pure and
testable without DB plumbing.

Tests: python/tests/test_cert_ref_parser.py.
"""

from __future__ import annotations

from datetime import date
from typing import Any

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind, make_synthetic_id


def parse(content: dict[str, Any]) -> ParsedTournament:
    """Map pre-fetched cert_ref rows to a ParsedTournament IR.

    Args:
        content: dict shaped as ``{
            'tournament': {tbl_tournament row columns as dict},
            'results':    [{tbl_result row columns + tbl_fencer.txt_surname/
                            txt_first_name/txt_nationality/int_birth_year}, ...]
        }``. Caller (orchestrator) joins ``cert_ref.tbl_tournament`` ↔
        ``cert_ref.tbl_result`` ↔ ``cert_ref.tbl_fencer`` before invoking.

    Returns:
        ParsedTournament populated from the cert_ref snapshot. ``source_url``
        is ``None`` (cert_ref has no live URL); ``raw_pool_size`` reads
        ``int_participant_count`` if available, else falls back to len(results).
    """
    tournament = content.get("tournament") or {}
    rows = content.get("results") or []

    results: list[ParsedResult] = []
    for idx, row in enumerate(rows):
        first = (row.get("txt_first_name") or "").strip()
        surname = (row.get("txt_surname") or "").strip()
        fencer_name = " ".join(p for p in (surname, first) if p)
        place = int(row.get("int_place")) if row.get("int_place") is not None else 0

        # Stable id when present; synthesize otherwise (cert_ref has id_result FK).
        id_result = row.get("id_result")
        source_row_id = (
            f"cert_ref:{id_result}"
            if id_result is not None
            else make_synthetic_id(SourceKind.CERT_REF, idx, place, fencer_name)
        )

        results.append(ParsedResult(
            source_row_id=source_row_id,
            fencer_name=fencer_name,
            place=place,
            fencer_country=row.get("txt_nationality"),
            birth_year=row.get("int_birth_year"),
            birth_date=None,
            raw_age_marker=None,
            source_vcat_hint=row.get("enum_age_category"),
            bool_excluded=False,
        ))

    raw_pool_size = tournament.get("int_participant_count")
    if raw_pool_size is None:
        raw_pool_size = len(results)

    parsed_date_raw = tournament.get("dt_tournament")
    parsed_date: date | None = None
    if isinstance(parsed_date_raw, date):
        parsed_date = parsed_date_raw
    elif isinstance(parsed_date_raw, str) and parsed_date_raw:
        try:
            parsed_date = date.fromisoformat(parsed_date_raw)
        except ValueError:
            parsed_date = None

    return ParsedTournament(
        source_kind=SourceKind.CERT_REF,
        results=results,
        raw_pool_size=raw_pool_size,
        parsed_date=parsed_date,
        weapon=tournament.get("enum_weapon"),
        gender=tournament.get("enum_gender"),
        category_hint=tournament.get("enum_age_category"),
        source_url=None,  # cert_ref has no URL
    )
