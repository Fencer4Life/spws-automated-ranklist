"""
Excel file parser (.xlsx and .xls).

Uses openpyxl for .xlsx and xlrd for .xls (legacy Excel 97-2003).
Auto-detects header row by looking for Place/Name or Miejsce/Nazwisko columns.
"""

from __future__ import annotations

import io

import openpyxl

# Header detection: maps normalized column names to standard keys
_HEADER_MAP = {
    "place": "place", "miejsce": "place",
    "name": "fencer_name", "nazwisko": "fencer_name",
    "fencer": "fencer_name", "fencer_name": "fencer_name",
    "country": "country", "kraj": "country", "nat": "country",
}


def parse_xlsx(file_bytes: bytes, ext: str = ".xlsx") -> list[dict]:
    """Parse Excel file into standardized result list.

    Args:
        file_bytes: Raw Excel file content.
        ext: File extension (".xlsx" or ".xls") to select engine.

    Returns:
        list[dict] with keys: fencer_name (str), place (int), country (str).
    """
    if ext == ".xls":
        return _parse_xls(file_bytes)
    return _parse_xlsx(file_bytes)


def _parse_xlsx(file_bytes: bytes) -> list[dict]:
    wb = openpyxl.load_workbook(io.BytesIO(file_bytes), read_only=True, data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    wb.close()
    return _rows_to_results(rows)


def _parse_xls(file_bytes: bytes) -> list[dict]:
    import xlrd

    wb = xlrd.open_workbook(file_contents=file_bytes)
    ws = wb.sheet_by_index(0)
    rows = [ws.row_values(i) for i in range(ws.nrows)]
    return _rows_to_results(rows)


def _rows_to_results(rows: list) -> list[dict]:
    """Convert raw spreadsheet rows to standardized results.

    Auto-detects header row, maps columns, extracts data rows.
    """
    if not rows:
        return []

    # Find header row and build column mapping
    col_map = None
    header_idx = None
    for i, row in enumerate(rows):
        mapping: dict[str, int] = {}
        for j, cell in enumerate(row):
            if cell is None:
                continue
            key = str(cell).strip().lower()
            if key in _HEADER_MAP:
                mapping[_HEADER_MAP[key]] = j
        if "place" in mapping and "fencer_name" in mapping:
            col_map = mapping
            header_idx = i
            break

    if col_map is None:
        raise ValueError("Could not detect header row (need Place + Name columns)")

    results = []
    for row in rows[header_idx + 1:]:
        place_val = row[col_map["place"]]
        name_val = row[col_map["fencer_name"]]
        if place_val is None or name_val is None:
            continue
        country = ""
        if "country" in col_map and col_map["country"] < len(row):
            country = str(row[col_map["country"]] or "").strip()
        results.append({
            "fencer_name": str(name_val).strip(),
            "place": int(float(str(place_val))),
            "country": country,
        })
    return results
