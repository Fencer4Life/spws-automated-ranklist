"""
File import dispatcher.

Routes file bytes to the correct parser based on file extension.
Supported formats: .csv, .xlsx, .xls, .json
"""

from __future__ import annotations

from pathlib import Path


def parse_file(file_bytes: bytes, filename: str) -> list[dict]:
    """Dispatch file to correct parser by extension.

    Args:
        file_bytes: Raw file content as bytes.
        filename: Original filename (used for extension detection).

    Returns:
        list[dict] with keys: fencer_name (str), place (int), country (str).

    Raises:
        ValueError: If file extension is not supported.
    """
    # Lazy imports — avoids a circular dependency when this module is
    # imported as part of `python/scrapers/__init__.py`'s registry build,
    # and matches the absolute-path convention used by the rest of the
    # package.
    ext = Path(filename).suffix.lower()
    if ext == ".csv":
        from python.scrapers.csv_upload import parse_csv_upload
        return parse_csv_upload(file_bytes.decode("utf-8"))
    elif ext in (".xlsx", ".xls"):
        from python.scrapers.xlsx_parser import parse_xlsx
        return parse_xlsx(file_bytes, ext=ext)
    elif ext == ".json":
        from python.scrapers.json_parser import parse_json
        return parse_json(file_bytes)
    elif ext == ".xml":
        from python.scrapers.fencingtime_xml import parse_fencingtime_xml
        return parse_fencingtime_xml(file_bytes)
    else:
        raise ValueError(f"Unsupported file format: {ext}")


# =============================================================================
# IR factory (Phase 1 / part 2 — ADR-050)
#
# parse() emits ParsedTournament with source_kind=FILE_IMPORT for admin
# uploads (CSV / XLSX / JSON). The .xml extension is intentionally not
# handled here — XML files go through the FencingTime XML ingest path
# under source_kind=FENCINGTIME_XML once that parser is refactored.
# =============================================================================

def parse(
    file_bytes: bytes,
    filename: str,
    source_url: str | None = None,
):
    """Dispatch admin-uploaded file to the correct internal parser, return IR.

    Supported extensions: .csv .xlsx .xls .json. XML files belong to the
    FencingTime XML source path, not file_import.

    Synthetic source_row_id (no native IDs in upload formats): format
    ``file_import:row{i}:place{p}:{name-slug}`` via make_synthetic_id().
    """
    from python.pipeline.ir import (
        ParsedResult, ParsedTournament, SourceKind, make_synthetic_id,
    )

    ext = Path(filename).suffix.lower()
    if ext == ".csv":
        from python.scrapers.csv_upload import parse_csv_upload
        rows = parse_csv_upload(file_bytes.decode("utf-8"))
    elif ext in (".xlsx", ".xls"):
        from python.scrapers.xlsx_parser import parse_xlsx
        rows = parse_xlsx(file_bytes, ext=ext)
    elif ext == ".json":
        from python.scrapers.json_parser import parse_json as _parse_json_file
        rows = _parse_json_file(file_bytes)
    else:
        raise ValueError(f"Unsupported file format for IR: {ext}")

    parsed: list[ParsedResult] = []
    for i, row in enumerate(rows, start=1):
        place = int(row["place"])
        name = row["fencer_name"]
        country = row.get("country") or None
        parsed.append(ParsedResult(
            source_row_id=make_synthetic_id(
                SourceKind.FILE_IMPORT,
                row_index=i,
                place=place,
                name=name,
            ),
            fencer_name=name,
            place=place,
            fencer_country=country,
        ))

    return ParsedTournament(
        source_kind=SourceKind.FILE_IMPORT,
        results=parsed,
        raw_pool_size=len(parsed),
        source_url=source_url,
        source_artifact_path=filename,
    )
