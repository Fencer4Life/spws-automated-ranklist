"""
File import dispatcher.

Routes file bytes to the correct parser based on file extension.
Supported formats: .csv, .xlsx, .xls, .json
"""

from __future__ import annotations

from pathlib import Path

from scrapers.csv_upload import parse_csv_upload
from scrapers.fencingtime_xml import parse_fencingtime_xml
from scrapers.xlsx_parser import parse_xlsx
from scrapers.json_parser import parse_json


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
    ext = Path(filename).suffix.lower()
    if ext == ".csv":
        return parse_csv_upload(file_bytes.decode("utf-8"))
    elif ext in (".xlsx", ".xls"):
        return parse_xlsx(file_bytes, ext=ext)
    elif ext == ".json":
        return parse_json(file_bytes)
    elif ext == ".xml":
        return parse_fencingtime_xml(file_bytes)
    else:
        raise ValueError(f"Unsupported file format: {ext}")
