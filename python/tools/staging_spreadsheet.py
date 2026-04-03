"""
Staging spreadsheet tool for SPWS data import pipeline.

Generates and manages the .ods staging spreadsheet used as a human-editable
intermediate layer between raw source files and SQL seed scripts.

Three modes:
  mock     — Generate doc/staging_data_mock.ods with sample data for review
  populate — (future) Read source data → write doc/staging_data.ods
  export   — (future) Read curated spreadsheet → generate SQL seed files

Usage:
    python python/tools/staging_spreadsheet.py mock [--output PATH]
    python python/tools/staging_spreadsheet.py populate --input PATH [--output PATH]
    python python/tools/staging_spreadsheet.py export --input PATH
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from odf import config
from odf.opendocument import OpenDocumentSpreadsheet
from odf.style import Style, TableCellProperties, TableColumnProperties, TextProperties
from odf.table import DatabaseRange, DatabaseRanges, Table, TableCell, TableColumn, TableRow
from odf.text import P

# ---------------------------------------------------------------------------
# Column definitions
# ---------------------------------------------------------------------------

SEASONS_COLUMNS = [
    "season_code", "dt_start", "dt_end", "bool_active",
    "ppw_best_count", "ppw_total_rounds", "mpw_multiplier",
    "pew_best_count", "mew_multiplier", "msw_multiplier",
    "import_log",
]

FENCERS_PARAMS = [
    ("auto_match_threshold", "90"),
    ("pending_threshold", "50"),
    ("use_diacritic_folding", "TRUE"),
    ("use_token_set_ratio", "TRUE"),
]

FENCERS_COLUMNS = [
    "id", "surname", "first_name", "birth_year",
    "birth_year_source", "club", "nationality",
    "match_status", "source_note",
]

EVENTS_COLUMNS = [
    "event_code", "event_prefix", "name", "season_code",
    "organizer", "location", "country",
    "dt_start", "dt_end", "status",
    "url_event", "url_invitation",
    "entry_fee", "currency", "discrepancy_note",
]

TOURNAMENTS_COLUMNS = [
    "tournament_code", "event_code", "event_prefix", "season_code",
    "weapon", "gender", "age_cat", "type",
    "dt_tournament", "participant_count", "result_url",
    "source_file", "original_source", "import_status", "notes",
]

# Column indices that are gray (locked formulas)
EVENTS_GRAY_COLS = {0}  # event_code
TOURNAMENTS_GRAY_COLS = {0, 1}  # tournament_code, event_code

# ---------------------------------------------------------------------------
# 30 category columns for Coverage tab
# ---------------------------------------------------------------------------

WEAPONS = ["EPEE", "FOIL", "SABRE"]
GENDERS = ["M", "F"]
AGE_CATS = ["V0", "V1", "V2", "V3", "V4"]

CATEGORY_COLUMNS = [
    f"{w}_{g}_{a}" for w in WEAPONS for g in GENDERS for a in AGE_CATS
]

# ---------------------------------------------------------------------------
# Mock data
# ---------------------------------------------------------------------------

MOCK_SEASONS = [
    {
        "season_code": "SPWS-2023-2024",
        "dt_start": "2023-09-01",
        "dt_end": "2024-08-31",
        "bool_active": "FALSE",
        "ppw_best_count": "4",
        "ppw_total_rounds": "8",
        "mpw_multiplier": "1.2",
        "pew_best_count": "3",
        "mew_multiplier": "2.0",
        "msw_multiplier": "2.0",
        "import_log": "Historical season — fully imported",
    },
    {
        "season_code": "SPWS-2024-2025",
        "dt_start": "2024-09-01",
        "dt_end": "2025-08-31",
        "bool_active": "TRUE",
        "ppw_best_count": "4",
        "ppw_total_rounds": "5",
        "mpw_multiplier": "1.2",
        "pew_best_count": "3",
        "mew_multiplier": "2.0",
        "msw_multiplier": "2.0",
        "import_log": "Current season — PP4/PP5 added",
    },
    {
        "season_code": "SPWS-2025-2026",
        "dt_start": "2025-09-01",
        "dt_end": "2026-08-31",
        "bool_active": "FALSE",
        "ppw_best_count": "4",
        "ppw_total_rounds": "5",
        "mpw_multiplier": "1.2",
        "pew_best_count": "3",
        "mew_multiplier": "2.0",
        "msw_multiplier": "2.0",
        "import_log": "PP3 LOST; PP1+PP2 from FTL scrape",
    },
]

MOCK_FENCERS = [
    {
        "id": "1", "surname": "KOWALSKI", "first_name": "Jan",
        "birth_year": "1970", "birth_year_source": "EXACT",
        "club": "WKS Wawel Kraków", "nationality": "PL",
        "match_status": "CONFIRMED",
        "source_note": "seed_tbl_fencer.sql",
    },
    {
        "id": "2", "surname": "NOWAKOWSKA-WIŚNIEWSKA", "first_name": "Anna",
        "birth_year": "1975", "birth_year_source": "EXACT",
        "club": "AZS AWF Warszawa", "nationality": "PL",
        "match_status": "CONFIRMED",
        "source_note": "seed_tbl_fencer.sql",
    },
    {
        "id": "3", "surname": "BŁAŻEJEWSKI", "first_name": "Krzysztof",
        "birth_year": "1968", "birth_year_source": "ESTIMATED",
        "club": "KS Szpada Wrocław", "nationality": "PL",
        "match_status": "FUZZY_85",
        "source_note": "SZPADA-2-2024-2025.xlsx PP3",
    },
    {
        "id": "4", "surname": "DĄBROWSKI", "first_name": "Łukasz",
        "birth_year": "1972", "birth_year_source": "ESTIMATED",
        "club": "UKS Atena Gdańsk", "nationality": "PL",
        "match_status": "NEW",
        "source_note": "PP4 XML auto-created",
    },
    {
        "id": "5", "surname": "ZIĘBA", "first_name": "Małgorzata",
        "birth_year": "1980", "birth_year_source": "EXACT",
        "club": "RMKS Rybnik", "nationality": "PL",
        "match_status": "AMBIGUOUS",
        "source_note": "seed_tbl_fencer.sql",
    },
]

MOCK_EVENTS = [
    {
        "event_prefix": "PP1", "name": "I Puchar Polski Weteranów",
        "season_code": "SPWS-2024-2025", "organizer": "SPWS",
        "location": "Kraków", "country": "PL",
        "dt_start": "2024-10-12", "dt_end": "2024-10-13",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "80", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "PP2", "name": "II Puchar Polski Weteranów",
        "season_code": "SPWS-2024-2025", "organizer": "SPWS",
        "location": "Wrocław", "country": "PL",
        "dt_start": "2024-11-16", "dt_end": "2024-11-17",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "80", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "MPW", "name": "Mistrzostwa Polski Weteranów",
        "season_code": "SPWS-2024-2025", "organizer": "SPWS",
        "location": "Warszawa", "country": "PL",
        "dt_start": "2025-05-10", "dt_end": "2025-05-11",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "100", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "PEW1", "name": "EVF Grand Prix 1 — Budapeszt",
        "season_code": "SPWS-2024-2025", "organizer": "EVF",
        "location": "Budapest", "country": "HU",
        "dt_start": "2024-09-28", "dt_end": "2024-09-29",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "50", "currency": "EUR", "discrepancy_note": "",
    },
    {
        "event_prefix": "GP1", "name": "Grand Prix (runda 1)",
        "season_code": "SPWS-2023-2024", "organizer": "SPWS",
        "location": "Gdańsk", "country": "PL",
        "dt_start": "2023-10-14", "dt_end": "2023-10-15",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "70", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "GP2", "name": "Grand Prix (runda 2)",
        "season_code": "SPWS-2023-2024", "organizer": "SPWS",
        "location": "Poznań", "country": "PL",
        "dt_start": "2023-11-18", "dt_end": "2023-11-19",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "70", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "MPW", "name": "Mistrzostwa Polski Weteranów",
        "season_code": "SPWS-2023-2024", "organizer": "SPWS",
        "location": "Łódź", "country": "PL",
        "dt_start": "2024-05-04", "dt_end": "2024-05-05",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "100", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "PP1", "name": "I Puchar Polski Weteranów",
        "season_code": "SPWS-2025-2026", "organizer": "SPWS",
        "location": "Katowice", "country": "PL",
        "dt_start": "2025-10-11", "dt_end": "2025-10-12",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "80", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "PP2", "name": "II Puchar Polski Weteranów",
        "season_code": "SPWS-2025-2026", "organizer": "SPWS",
        "location": "Gdańsk", "country": "PL",
        "dt_start": "2025-11-08", "dt_end": "2025-11-09",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "80", "currency": "PLN", "discrepancy_note": "",
    },
    {
        "event_prefix": "PEW1", "name": "EVF Grand Prix 1",
        "season_code": "SPWS-2025-2026", "organizer": "EVF",
        "location": "Roma", "country": "IT",
        "dt_start": "2025-09-20", "dt_end": "2025-09-21",
        "status": "COMPLETED", "url_event": "", "url_invitation": "",
        "entry_fee": "50", "currency": "EUR", "discrepancy_note": "",
    },
]

MOCK_TOURNAMENTS = [
    {
        "event_prefix": "PP1", "season_code": "SPWS-2024-2025",
        "weapon": "EPEE", "gender": "M", "age_cat": "V2", "type": "PPW",
        "dt_tournament": "2024-10-12", "participant_count": "15",
        "result_url": "", "source_file": "SZPADA-2-2024-2025.xlsx",
        "original_source": "", "import_status": "SCORED", "notes": "",
    },
    {
        "event_prefix": "PP1", "season_code": "SPWS-2024-2025",
        "weapon": "FOIL", "gender": "F", "age_cat": "V1", "type": "PPW",
        "dt_tournament": "2024-10-12", "participant_count": "8",
        "result_url": "", "source_file": "FLORET-K1-2024-2025.xlsx",
        "original_source": "", "import_status": "SCORED", "notes": "",
    },
    {
        "event_prefix": "MPW", "season_code": "SPWS-2024-2025",
        "weapon": "SABRE", "gender": "M", "age_cat": "V0", "type": "MPW",
        "dt_tournament": "2025-05-10", "participant_count": "12",
        "result_url": "", "source_file": "SZABLA-0-2024-2025.xlsx",
        "original_source": "", "import_status": "SCORED", "notes": "",
    },
    {
        "event_prefix": "PEW1", "season_code": "SPWS-2024-2025",
        "weapon": "EPEE", "gender": "M", "age_cat": "V3", "type": "PEW",
        "dt_tournament": "2024-09-28", "participant_count": "22",
        "result_url": "https://fencing-timing.com/example", "source_file": "",
        "original_source": "", "import_status": "SCRAPED", "notes": "",
    },
    {
        "event_prefix": "GP1", "season_code": "SPWS-2023-2024",
        "weapon": "EPEE", "gender": "M", "age_cat": "V2", "type": "PPW",
        "dt_tournament": "2023-10-14", "participant_count": "18",
        "result_url": "", "source_file": "SZPADA-2-2023-2024.xlsx",
        "original_source": "", "import_status": "SCORED", "notes": "",
    },
]


# ---------------------------------------------------------------------------
# Style helpers
# ---------------------------------------------------------------------------

def _create_styles(doc: OpenDocumentSpreadsheet) -> dict[str, Style]:
    """Create and register cell styles. Returns dict of style names.

    Color scheme:
      - header:         dark bg (#2C3E50), white bold text, locked
      - editable:       no background, unlocked (user can modify)
      - gray:           gray bg (#E0E0E0), locked (formulas & non-editable)
      - coverage_data:  light green bg (#C6EFCE), locked
      - coverage_empty: no background, locked
      - param_label:    gray bg, bold, locked
      - param_value:    no background, unlocked
    """
    styles = {}

    # Header: inverse — dark background, white bold text
    s = Style(name="header", family="table-cell")
    s.addElement(TextProperties(fontweight="bold", color="#FFFFFF"))
    s.addElement(TableCellProperties(backgroundcolor="#2C3E50", cellprotect="protected"))
    doc.automaticstyles.addElement(s)
    styles["header"] = s

    # Editable: no background (user-modifiable columns)
    s = Style(name="editable", family="table-cell")
    s.addElement(TableCellProperties(cellprotect="none"))
    doc.automaticstyles.addElement(s)
    styles["editable"] = s

    # Gray: locked cells (formulas, non-editable data)
    s = Style(name="gray", family="table-cell")
    s.addElement(TableCellProperties(backgroundcolor="#E0E0E0", cellprotect="protected"))
    doc.automaticstyles.addElement(s)
    styles["gray"] = s

    # Coverage data: light green (data exists)
    s = Style(name="coverage_data", family="table-cell")
    s.addElement(TableCellProperties(backgroundcolor="#C6EFCE", cellprotect="protected"))
    doc.automaticstyles.addElement(s)
    styles["coverage_data"] = s

    # Coverage empty: no background (data not yet there)
    s = Style(name="coverage_empty", family="table-cell")
    s.addElement(TableCellProperties(cellprotect="protected"))
    doc.automaticstyles.addElement(s)
    styles["coverage_empty"] = s

    # Parameter label: gray bg, bold, locked
    s = Style(name="param_label", family="table-cell")
    s.addElement(TextProperties(fontweight="bold"))
    s.addElement(TableCellProperties(backgroundcolor="#E0E0E0", cellprotect="protected"))
    doc.automaticstyles.addElement(s)
    styles["param_label"] = s

    # Parameter value: no bg, editable
    s = Style(name="param_value", family="table-cell")
    s.addElement(TableCellProperties(cellprotect="none"))
    doc.automaticstyles.addElement(s)
    styles["param_value"] = s

    return styles


def _add_cell(
    row: TableRow,
    value: str,
    style: Style,
    *,
    formula: str | None = None,
) -> TableCell:
    """Add a cell to a row with text content and optional formula."""
    attrs = {"stylename": style}
    if formula:
        attrs["formula"] = formula
    cell = TableCell(**attrs)
    cell.addElement(P(text=str(value)))
    row.addElement(cell)
    return cell


def _add_header_row(table: Table, columns: list[str], style: Style) -> None:
    """Add a header row to a table."""
    row = TableRow()
    for col in columns:
        _add_cell(row, col, style)
    table.addElement(row)


# ---------------------------------------------------------------------------
# Tab builders
# ---------------------------------------------------------------------------

def _build_seasons_tab(
    doc: OpenDocumentSpreadsheet,
    styles: dict[str, Style],
    data: list[dict],
) -> Table:
    """Build the Seasons tab."""
    table = Table(name="Seasons", protected="true", protectionkey="")

    _add_header_row(table, SEASONS_COLUMNS, styles["header"])

    for season in data:
        row = TableRow()
        for col in SEASONS_COLUMNS:
            _add_cell(row, season.get(col, ""), styles["editable"])
        table.addElement(row)

    doc.spreadsheet.addElement(table)
    return table


def _build_fencers_tab(
    doc: OpenDocumentSpreadsheet,
    styles: dict[str, Style],
    data: list[dict],
    params: list[tuple[str, str]],
) -> Table:
    """Build the Fencers tab with parameter header area."""
    table = Table(name="Fencers", protected="true", protectionkey="")

    # Parameter header area (rows 0-3)
    for label, value in params:
        row = TableRow()
        _add_cell(row, label, styles["param_label"])
        _add_cell(row, value, styles["param_value"])
        table.addElement(row)

    # Blank separator row (row 4)
    table.addElement(TableRow())

    # Column header row (row 5)
    _add_header_row(table, FENCERS_COLUMNS, styles["header"])

    # Data rows (rows 6+)
    for fencer in data:
        row = TableRow()
        for col in FENCERS_COLUMNS:
            _add_cell(row, fencer.get(col, ""), styles["editable"])
        table.addElement(row)

    doc.spreadsheet.addElement(table)
    return table


def _col_letter(idx: int) -> str:
    """Convert 0-based column index to Excel-style letter (A..Z, AA..AZ, ...)."""
    result = ""
    n = idx + 1  # 1-based
    while n > 0:
        n -= 1
        result = chr(ord("A") + n % 26) + result
        n //= 26
    return result


def _build_events_tab(
    doc: OpenDocumentSpreadsheet,
    styles: dict[str, Style],
    data: list[dict],
) -> Table:
    """Build the Events tab with formula columns."""
    table = Table(name="Events", protected="true", protectionkey="")

    _add_header_row(table, EVENTS_COLUMNS, styles["header"])

    for i, event in enumerate(data):
        row_num = i + 2  # 1-indexed, row 1 = header, row 2 = first data
        row = TableRow()

        for col_idx, col in enumerate(EVENTS_COLUMNS):
            if col_idx in EVENTS_GRAY_COLS:
                # event_code: formula = CONCAT(event_prefix, "-", season_code)
                # B = event_prefix (col 1), D = season_code (col 3)
                formula = f"of:=CONCAT([.B{row_num}];\"-\";[.D{row_num}])"
                computed = f"{event['event_prefix']}-{event['season_code']}"
                _add_cell(row, computed, styles["gray"], formula=formula)
            else:
                _add_cell(row, event.get(col, ""), styles["editable"])

        table.addElement(row)

    doc.spreadsheet.addElement(table)
    return table


def _build_tournaments_tab(
    doc: OpenDocumentSpreadsheet,
    styles: dict[str, Style],
    data: list[dict],
) -> Table:
    """Build the Tournaments tab with formula columns."""
    table = Table(name="Tournaments", protected="true", protectionkey="")

    _add_header_row(table, TOURNAMENTS_COLUMNS, styles["header"])

    for i, tourn in enumerate(data):
        row_num = i + 2
        row = TableRow()

        for col_idx, col in enumerate(TOURNAMENTS_COLUMNS):
            if col_idx == 0:
                # tournament_code: CONCAT(event_prefix, "-", age_cat, "-", gender, "-", weapon, "-", season_code)
                # C=event_prefix(2), D=season_code(3), E=weapon(4), F=gender(5), G=age_cat(6)
                formula = (
                    f"of:=CONCAT([.C{row_num}];\"-\";"
                    f"[.G{row_num}];\"-\";"
                    f"[.F{row_num}];\"-\";"
                    f"[.E{row_num}];\"-\";"
                    f"[.D{row_num}])"
                )
                computed = (
                    f"{tourn['event_prefix']}-{tourn['age_cat']}-"
                    f"{tourn['gender']}-{tourn['weapon']}-{tourn['season_code']}"
                )
                _add_cell(row, computed, styles["gray"], formula=formula)
            elif col_idx == 1:
                # event_code: CONCAT(event_prefix, "-", season_code)
                formula = f"of:=CONCAT([.C{row_num}];\"-\";[.D{row_num}])"
                computed = f"{tourn['event_prefix']}-{tourn['season_code']}"
                _add_cell(row, computed, styles["gray"], formula=formula)
            else:
                _add_cell(row, tourn.get(col, ""), styles["editable"])

        table.addElement(row)

    doc.spreadsheet.addElement(table)
    return table


def _build_coverage_tab(
    doc: OpenDocumentSpreadsheet,
    styles: dict[str, Style],
    events: list[dict],
    tournaments: list[dict],
) -> Table:
    """Build the Coverage tab (read-only gap matrix)."""
    table = Table(name="Coverage", protected="true", protectionkey="")

    # Header row: "event" + 30 category columns
    header_cols = ["event"] + CATEGORY_COLUMNS
    _add_header_row(table, header_cols, styles["header"])

    # Build lookup: (event_prefix, season_code) → {category: participant_count}
    tourn_lookup: dict[tuple[str, str], dict[str, str]] = {}
    for t in tournaments:
        key = (t["event_prefix"], t["season_code"])
        cat = f"{t['weapon']}_{t['gender']}_{t['age_cat']}"
        tourn_lookup.setdefault(key, {})[cat] = t.get("participant_count", "?")

    # One row per event
    for event in events:
        row = TableRow()
        event_label = f"{event['event_prefix']}-{event['season_code']}"
        _add_cell(row, event_label, styles["gray"])

        key = (event["event_prefix"], event["season_code"])
        cats = tourn_lookup.get(key, {})
        for cat_col in CATEGORY_COLUMNS:
            value = cats.get(cat_col, "?")
            # Light green if data exists (numeric count), no bg if not yet there
            if value not in ("?", "-", "LOST", "EMPTY", "0", ""):
                _add_cell(row, value, styles["coverage_data"])
            else:
                _add_cell(row, value, styles["coverage_empty"])

        table.addElement(row)

    doc.spreadsheet.addElement(table)
    return table


# ---------------------------------------------------------------------------
# Freeze panes & autofilter helpers
# ---------------------------------------------------------------------------

def _add_freeze_panes(
    doc: OpenDocumentSpreadsheet,
    tab_freeze_rows: dict[str, int],
) -> None:
    """Add freeze-pane settings so header rows stay visible when scrolling.

    Args:
        tab_freeze_rows: mapping of tab name → number of rows to freeze
            (e.g., {"Seasons": 1, "Fencers": 6} freezes after row 1 / row 6)
    """
    settings_set = config.ConfigItemSet(name="ooo:view-settings")
    views = config.ConfigItemMapIndexed(name="Views")
    view_entry = config.ConfigItemMapEntry()

    vid = config.ConfigItem(name="ViewId", type="string")
    vid.addText("view1")
    view_entry.addElement(vid)

    tables = config.ConfigItemMapNamed(name="Tables")
    for tab_name, freeze_row in tab_freeze_rows.items():
        tab_entry = config.ConfigItemMapEntry(name=tab_name)
        for ci_name, ci_type, ci_val in [
            ("HorizontalSplitMode", "short", "0"),
            ("VerticalSplitMode", "short", "2"),
            ("HorizontalSplitPosition", "int", "0"),
            ("VerticalSplitPosition", "int", str(freeze_row)),
            ("PositionBottom", "int", str(freeze_row)),
            ("ActiveSplitRange", "short", "2"),
        ]:
            ci = config.ConfigItem(name=ci_name, type=ci_type)
            ci.addText(ci_val)
            tab_entry.addElement(ci)
        tables.addElement(tab_entry)

    view_entry.addElement(tables)
    views.addElement(view_entry)
    settings_set.addElement(views)
    doc.settings.addElement(settings_set)


def _add_autofilter(
    doc: OpenDocumentSpreadsheet,
    ranges: list[tuple[str, str, int, int]],
) -> None:
    """Add database ranges with autofilter buttons on header rows.

    Args:
        ranges: list of (tab_name, last_col_letter, header_row_1based, last_row_1based)
    """
    db_ranges = DatabaseRanges()
    for i, (tab_name, last_col, header_row, last_row) in enumerate(ranges):
        safe_name = tab_name.replace(" ", "_")
        dr = DatabaseRange(
            name=f"__filter_{safe_name}_{i}",
            targetrangeaddress=(
                f"{tab_name}.A{header_row}:{tab_name}.{last_col}{last_row}"
            ),
            displayfilterbuttons="true",
        )
        db_ranges.addElement(dr)
    doc.spreadsheet.addElement(db_ranges)


# ---------------------------------------------------------------------------
# Mode orchestrators
# ---------------------------------------------------------------------------

def mock_mode(output_path: Path) -> None:
    """Generate mock .ods spreadsheet for user review."""
    doc = OpenDocumentSpreadsheet()
    styles = _create_styles(doc)

    _build_seasons_tab(doc, styles, MOCK_SEASONS)
    _build_fencers_tab(doc, styles, MOCK_FENCERS, FENCERS_PARAMS)
    _build_events_tab(doc, styles, MOCK_EVENTS)
    _build_tournaments_tab(doc, styles, MOCK_TOURNAMENTS)
    _build_coverage_tab(doc, styles, MOCK_EVENTS, MOCK_TOURNAMENTS)

    # Freeze header rows
    _add_freeze_panes(doc, {
        "Seasons": 1,
        "Fencers": 6,       # 4 params + 1 blank + 1 header
        "Events": 1,
        "Tournaments": 1,
        "Coverage": 1,
    })

    # Autofilter on data tables
    n_seasons = 1 + len(MOCK_SEASONS)         # header + data
    n_fencers_hdr = 6                          # param area header row (1-based)
    n_fencers_end = 6 + len(MOCK_FENCERS)
    n_events = 1 + len(MOCK_EVENTS)
    n_tournaments = 1 + len(MOCK_TOURNAMENTS)
    n_coverage = 1 + len(MOCK_EVENTS)
    last_cov_col = _col_letter(len(CATEGORY_COLUMNS))  # +1 for event col, 0-based

    _add_autofilter(doc, [
        ("Seasons", _col_letter(len(SEASONS_COLUMNS) - 1), 1, n_seasons),
        ("Fencers", _col_letter(len(FENCERS_COLUMNS) - 1), n_fencers_hdr, n_fencers_end),
        ("Events", _col_letter(len(EVENTS_COLUMNS) - 1), 1, n_events),
        ("Tournaments", _col_letter(len(TOURNAMENTS_COLUMNS) - 1), 1, n_tournaments),
        ("Coverage", last_cov_col, 1, n_coverage),
    ])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(output_path))
    print(f"Wrote {output_path}")


def _load_overrides(overrides_dir: Path, filename: str, key_col: str) -> dict[str, dict]:
    """Load a CSV override file into a dict keyed by key_col.

    Returns:
        {key_value: {col: val, ...}} — only non-empty values included.
    """
    import csv

    csv_path = overrides_dir / filename
    if not csv_path.exists():
        return {}

    overrides: dict[str, dict] = {}
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            key = row.get(key_col, "").strip()
            if not key:
                continue
            vals = {k: v for k, v in row.items() if k != key_col and v.strip()}
            if vals:
                overrides[key] = vals
    return overrides


def _apply_event_overrides(events: list[dict], overrides_dir: Path) -> int:
    """Apply events.csv overrides. Key = event_code (event_prefix-season_code).

    Patches existing events and appends new rows for override keys
    that don't match any auto-generated event.
    """
    ov = _load_overrides(overrides_dir, "events.csv", "event_code")
    if not ov:
        return 0
    applied = 0
    matched_keys = set()
    for e in events:
        event_code = f"{e.get('event_prefix', '')}-{e.get('season_code', '')}"
        if event_code in ov:
            e.update(ov[event_code])
            matched_keys.add(event_code)
            applied += 1
    # Add new rows for unmatched override keys
    for event_code, vals in ov.items():
        if event_code in matched_keys:
            continue
        # Parse event_code → event_prefix + season_code
        # Format: PREFIX-SPWS-YYYY-YYYY
        parts = event_code.split("-", 1)
        if len(parts) < 2:
            continue
        prefix = parts[0]
        season_code = parts[1]
        new_event = {
            "event_prefix": prefix,
            "name": vals.get("name", prefix),
            "season_code": season_code,
            "organizer": "SPWS" if prefix in ("GPW", "MPW") or prefix.startswith(("GP", "PPW")) else "EVF",
            "location": "",
            "country": "",
            "dt_start": "",
            "dt_end": "",
            "status": "COMPLETED",
            "url_event": "",
            "url_invitation": "",
            "entry_fee": "",
            "currency": "",
            "discrepancy_note": "",
        }
        new_event.update(vals)
        events.append(new_event)
        applied += 1
    return applied


def _apply_fencer_overrides(fencers: list[dict], overrides_dir: Path) -> int:
    """Apply fencers.csv overrides. Key = surname,first_name (combined)."""
    import csv

    csv_path = overrides_dir / "fencers.csv"
    if not csv_path.exists():
        return 0

    ov: dict[tuple[str, str], dict] = {}
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            key = (row.get("surname", "").strip().upper(),
                   row.get("first_name", "").strip().upper())
            vals = {k: v for k, v in row.items()
                    if k not in ("surname", "first_name") and v.strip()}
            if vals:
                ov[key] = vals

    applied = 0
    for f_row in fencers:
        key = (f_row.get("surname", "").upper(), f_row.get("first_name", "").upper())
        if key in ov:
            f_row.update(ov[key])
            applied += 1
    return applied


def _apply_tournament_overrides(tournaments: list[dict], overrides_dir: Path) -> int:
    """Apply tournaments.csv overrides. Key = tournament_code."""
    ov = _load_overrides(overrides_dir, "tournaments.csv", "tournament_code")
    if not ov:
        return 0
    applied = 0
    for t in tournaments:
        code = (
            f"{t.get('event_prefix','')}-{t.get('age_cat','')}-"
            f"{t.get('gender','')}-{t.get('weapon','')}-{t.get('season_code','')}"
        )
        if code in ov:
            t.update(ov[code])
            applied += 1
    return applied


def populate_mode(input_dir: Path, output_path: Path) -> None:
    """Generate .ods from real source data, applying CSV overrides."""
    from tools.populate_staging import collect_populate_data

    data = collect_populate_data(input_dir)

    # Convert seasons to string values for tab builder
    seasons = []
    for s in data["seasons"]:
        seasons.append({k: str(v) for k, v in s.items()})

    # Convert fencers to tab builder format
    fencers = []
    for i, f in enumerate(data["fencers"], 1):
        fencers.append({
            "id": str(i),
            "surname": f.get("surname", ""),
            "first_name": f.get("first_name", ""),
            "birth_year": str(f["birth_year"]) if f.get("birth_year") else "",
            "birth_year_source": "EXACT" if f.get("birth_year") else "",
            "club": "",
            "nationality": "",
            "match_status": "NEW",
            "source_note": f.get("source_note", ""),
        })

    # Convert events to tab builder format
    events = []
    for e in data["events"]:
        events.append({
            "event_prefix": e.get("event_prefix", ""),
            "name": e.get("name", ""),
            "season_code": e.get("season_code", ""),
            "organizer": e.get("organizer", ""),
            "location": "",
            "country": "",
            "dt_start": e.get("dt_start", "") or "",
            "dt_end": e.get("dt_end", "") or "",
            "status": e.get("status", "COMPLETED"),
            "url_event": "",
            "url_invitation": "",
            "entry_fee": "",
            "currency": "",
            "discrepancy_note": "",
        })

    # Convert tournaments — ensure participant_count is string
    tournaments = []
    for t in data["tournaments"]:
        tournaments.append({
            "event_prefix": t.get("event_prefix", ""),
            "season_code": t.get("season_code", ""),
            "weapon": t.get("weapon", ""),
            "gender": t.get("gender", ""),
            "age_cat": t.get("age_cat", ""),
            "type": t.get("type", ""),
            "dt_tournament": t.get("dt_tournament", "") or "",
            "participant_count": str(t.get("participant_count", "")),
            "result_url": t.get("result_url", "") or "",
            "source_file": t.get("source_file", ""),
            "original_source": t.get("original_source", "") or "",
            "import_status": t.get("import_status", ""),
            "notes": t.get("notes", "") or "",
        })

    # Apply CSV overrides (hand-entered data preserved across re-generates)
    overrides_dir = input_dir.parent / "staging_overrides"
    if overrides_dir.exists():
        n_ev = _apply_event_overrides(events, overrides_dir)
        n_fn = _apply_fencer_overrides(fencers, overrides_dir)
        n_tn = _apply_tournament_overrides(tournaments, overrides_dir)
        if n_ev or n_fn or n_tn:
            print(f"  Overrides applied: {n_ev} events, {n_fn} fencers, {n_tn} tournaments")

    doc = OpenDocumentSpreadsheet()
    styles = _create_styles(doc)

    _build_seasons_tab(doc, styles, seasons)
    _build_fencers_tab(doc, styles, fencers, FENCERS_PARAMS)
    _build_events_tab(doc, styles, events)
    _build_tournaments_tab(doc, styles, tournaments)
    _build_coverage_tab(doc, styles, events, tournaments)

    # Freeze header rows
    _add_freeze_panes(doc, {
        "Seasons": 1,
        "Fencers": 6,
        "Events": 1,
        "Tournaments": 1,
        "Coverage": 1,
    })

    # Autofilter
    n_seasons = 1 + len(seasons)
    n_fencers_hdr = 6
    n_fencers_end = 6 + len(fencers)
    n_events = 1 + len(events)
    n_tournaments = 1 + len(tournaments)
    n_coverage = 1 + len(events)
    last_cov_col = _col_letter(len(CATEGORY_COLUMNS))

    _add_autofilter(doc, [
        ("Seasons", _col_letter(len(SEASONS_COLUMNS) - 1), 1, n_seasons),
        ("Fencers", _col_letter(len(FENCERS_COLUMNS) - 1), n_fencers_hdr, n_fencers_end),
        ("Events", _col_letter(len(EVENTS_COLUMNS) - 1), 1, n_events),
        ("Tournaments", _col_letter(len(TOURNAMENTS_COLUMNS) - 1), 1, n_tournaments),
        ("Coverage", last_cov_col, 1, n_coverage),
    ])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(output_path))

    print(f"Wrote {output_path}")
    print(f"  Seasons: {len(seasons)}")
    print(f"  Fencers: {len(fencers)}")
    print(f"  Events: {len(events)}")
    print(f"  Tournaments: {len(tournaments)}")


# ---------------------------------------------------------------------------
# Export mode — generate SQL seed files from staging data
# ---------------------------------------------------------------------------

_CURRENCY_MAP = {"zł": "PLN", "PLN": "PLN", "€": "EUR", "EUR": "EUR"}


def _staging_to_db_code(event_prefix: str, season_code: str) -> str:
    """Convert staging event_prefix + season_code to short DB event code.

    e.g. PPW1 + SPWS-2024-2025 → PPW1-2024-2025
    """
    year_suffix = season_code.removeprefix("SPWS-")
    return f"{event_prefix}-{year_suffix}"


def _currency_to_db(currency: str) -> str | None:
    """Convert staging currency to DB value."""
    if not currency:
        return None
    return _CURRENCY_MAP.get(currency, currency)


def _organizer_code(event_prefix: str) -> str:
    """Derive organizer from event prefix."""
    if event_prefix.startswith(("PEW", "MEW")):
        return "EVF"
    if event_prefix.startswith(("PSW", "MSW", "PS", "IMSW")):
        return "FIE"
    return "SPWS"


def _sq(s: str | None) -> str:
    """Escape single quotes for SQL literal, or return NULL."""
    if s is None or s == "":
        return "NULL"
    return "'" + str(s).replace("'", "''") + "'"


def _generate_events_metadata_sql(
    events: list[dict], season_code: str
) -> str:
    """Generate zz_events_metadata.sql content for one season."""
    year_suffix = season_code.removeprefix("SPWS-")
    season_events = [e for e in events if e.get("season_code") == season_code]

    lines: list[str] = [
        "-- =========================================================================",
        f"-- Event metadata for season {year_suffix}",
        "-- Auto-generated by staging_spreadsheet.py export mode.",
        "-- Loaded AFTER per-category v*.sql files (zz_ prefix ensures ordering).",
        "-- Phase 1: INSERT events not yet created by result files.",
        "-- Phase 2: UPDATE all events with enriched metadata.",
        "-- =========================================================================",
        "",
    ]

    # Phase 1: INSERT events that might not exist yet (calendar-only, no results)
    lines.append("-- Phase 1: Ensure all events exist")
    for e in season_events:
        db_code = _staging_to_db_code(e["event_prefix"], season_code)
        name = e.get("name", "") or e["event_prefix"]
        org = _organizer_code(e["event_prefix"])
        status = e.get("status", "COMPLETED")
        lines += [
            f"INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)",
            f"SELECT",
            f"    {_sq(db_code)},",
            f"    {_sq(name)},",
            f"    (SELECT id_season FROM tbl_season WHERE txt_code = {_sq(season_code)}),",
            f"    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = {_sq(org)}),",
            f"    {_sq(status)}",
            f"WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = {_sq(db_code)});",
            "",
        ]

    # Phase 2: UPDATE all events with enriched metadata
    lines.append("-- Phase 2: Update events with enriched metadata")
    for e in season_events:
        db_code = _staging_to_db_code(e["event_prefix"], season_code)
        name = e.get("name", "") or e["event_prefix"]
        location = e.get("location", "") or None
        country = e.get("country", "") or None
        dt_start = e.get("dt_start", "") or None
        dt_end = e.get("dt_end", "") or None
        url_event = e.get("url_event", "") or None
        url_invitation = e.get("url_invitation", "") or None
        entry_fee = e.get("entry_fee", "") or None
        currency = _currency_to_db(e.get("currency", ""))
        status = e.get("status", "COMPLETED")

        fee_sql = str(entry_fee) if entry_fee else "NULL"

        lines += [
            f"UPDATE tbl_event SET",
            f"    txt_name = {_sq(name)},",
            f"    txt_location = {_sq(location)},",
            f"    txt_country = {_sq(country)},",
            f"    dt_start = {_sq(dt_start)},",
            f"    dt_end = {_sq(dt_end)},",
            f"    url_event = {_sq(url_event)},",
            f"    url_invitation = {_sq(url_invitation)},",
            f"    num_entry_fee = {fee_sql},",
            f"    txt_entry_fee_currency = {_sq(currency)}",
            f"WHERE txt_code = {_sq(db_code)};",
            "",
        ]

    return "\n".join(lines)


def _generate_fencer_sql(
    fencers: list[dict], existing_path: Path
) -> str:
    """Generate seed_tbl_fencer.sql preserving existing fencer order.

    Reads the existing file to extract the first N fencers in order,
    then appends any new fencers from staging data alphabetically.
    """
    import re

    # Parse existing fencers from seed file
    existing_fencers: list[tuple[str, str, str | None]] = []
    if existing_path.exists():
        content = existing_path.read_text(encoding="utf-8")
        # Match lines like:    ('SURNAME',   'FirstName',   1969),
        pattern = re.compile(
            r"\('([^']+)',\s+'([^']+)',\s+(NULL|\d+)\)"
        )
        for m in pattern.finditer(content):
            surname, first, birth = m.groups()
            birth_val = None if birth == "NULL" else birth
            existing_fencers.append((surname, first, birth_val))

    # Build set of existing (surname, first_name) for dedup
    existing_keys = {(s.upper(), f.upper()) for s, f, _ in existing_fencers}

    # Find new fencers from staging data
    new_fencers: list[tuple[str, str, str | None]] = []
    for f in fencers:
        surname = f.get("surname", "").strip()
        first = f.get("first_name", "").strip()
        if not surname:
            continue
        key = (surname.upper(), first.upper())
        if key not in existing_keys:
            birth = f.get("birth_year", "") or None
            new_fencers.append((surname.upper(), first, birth))
            existing_keys.add(key)  # prevent duplicates within new batch

    # Sort new fencers alphabetically
    new_fencers.sort(key=lambda x: (x[0], x[1]))

    all_fencers = list(existing_fencers) + new_fencers

    # Generate SQL
    lines: list[str] = [
        "-- =============================================================================",
        "-- Master Fencer List — tbl_fencer",
        f"-- {len(all_fencers)} SPWS members; birth year only; club and nationality not tracked.",
        "-- Auto-loaded via config.toml sql_paths glob after seed.sql.",
        "-- Note: birth year alone is sufficient for SPWS age-category rules (calendar-year-based).",
        "-- NULL int_birth_year = year unknown.",
        "-- =============================================================================",
        "INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year) VALUES",
    ]

    for i, (surname, first, birth) in enumerate(all_fencers):
        birth_sql = birth if birth else "NULL"
        sep = "," if i < len(all_fencers) - 1 else ";"
        lines.append(
            f"    ('{surname.replace(chr(39), chr(39)*2)}',"
            f"{' ' * max(1, 24 - len(surname))}"
            f"'{first.replace(chr(39), chr(39)*2)}',"
            f"{' ' * max(1, 14 - len(first))}"
            f"{birth_sql}){sep}"
        )

    lines += [
        "",
        "-- Name aliases for identity resolution (M4/M5)",
        "-- KOŃCZYŁO Tomasz competed as \"TK\" in some tournament systems",
        "UPDATE tbl_fencer SET json_name_aliases = '[\"TK\"]'",
        "WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz';",
        "",
    ]

    return "\n".join(lines)


def export_mode(input_dir: Path) -> None:
    """Export staging data to SQL seed files."""
    from tools.populate_staging import collect_populate_data

    data = collect_populate_data(input_dir)

    # Convert to staging format (same as populate_mode)
    fencers = []
    for i, f in enumerate(data["fencers"], 1):
        fencers.append({
            "id": str(i),
            "surname": f.get("surname", ""),
            "first_name": f.get("first_name", ""),
            "birth_year": str(f["birth_year"]) if f.get("birth_year") else "",
            "birth_year_source": "EXACT" if f.get("birth_year") else "",
            "source_note": f.get("source_note", ""),
        })

    events = []
    for e in data["events"]:
        events.append({
            "event_prefix": e.get("event_prefix", ""),
            "name": e.get("name", ""),
            "season_code": e.get("season_code", ""),
            "organizer": e.get("organizer", ""),
            "location": "",
            "country": "",
            "dt_start": e.get("dt_start", "") or "",
            "dt_end": e.get("dt_end", "") or "",
            "status": e.get("status", "COMPLETED"),
            "url_event": "",
            "url_invitation": "",
            "entry_fee": "",
            "currency": "",
            "discrepancy_note": "",
        })

    # Apply CSV overrides
    overrides_dir = input_dir.parent / "staging_overrides"
    if overrides_dir.exists():
        n_ev = _apply_event_overrides(events, overrides_dir)
        print(f"  Overrides applied: {n_ev} events")

    # Determine season codes
    season_codes = sorted({e["season_code"] for e in events})

    # Generate per-season event metadata SQL
    repo_root = Path(__file__).resolve().parent.parent.parent
    for season_code in season_codes:
        year_parts = season_code.removeprefix("SPWS-").split("-")
        season_folder = f"{year_parts[0]}_{year_parts[1][2:]}"
        out_dir = repo_root / "supabase" / "data" / season_folder
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / "zz_events_metadata.sql"

        sql = _generate_events_metadata_sql(events, season_code)
        out_path.write_text(sql, encoding="utf-8")
        season_event_count = sum(
            1 for e in events if e.get("season_code") == season_code
        )
        print(f"  Wrote {out_path} ({season_event_count} events)")

    # Regenerate fencer seed
    fencer_path = repo_root / "supabase" / "seed_tbl_fencer.sql"
    fencer_sql = _generate_fencer_sql(fencers, fencer_path)
    fencer_path.write_text(fencer_sql, encoding="utf-8")
    print(f"  Wrote {fencer_path} ({len(fencers)} fencers from staging)")

    print("Export complete.")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Staging spreadsheet tool for SPWS data import pipeline.",
    )
    subparsers = parser.add_subparsers(dest="mode", required=True)

    mock_parser = subparsers.add_parser("mock", help="Generate mock .ods for review")
    mock_parser.add_argument(
        "--output",
        type=Path,
        default=Path("doc/staging_data_mock.ods"),
        help="Output file path (default: doc/staging_data_mock.ods)",
    )

    populate_parser = subparsers.add_parser(
        "populate", help="Populate .ods from real source data",
    )
    populate_parser.add_argument("--input", type=Path, required=True)
    populate_parser.add_argument(
        "--output", type=Path, default=Path("doc/staging_data.ods"),
    )

    export_parser = subparsers.add_parser(
        "export", help="Export staging data to SQL seed files",
    )
    export_parser.add_argument("--input", type=Path, required=True)

    args = parser.parse_args()

    if args.mode == "mock":
        mock_mode(args.output)
    elif args.mode == "populate":
        populate_mode(args.input, args.output)
    elif args.mode == "export":
        export_mode(args.input)


if __name__ == "__main__":
    main()
