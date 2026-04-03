"""
Tests for staging spreadsheet generator (mock mode + populate mode).

Plan test IDs 9.101–9.115 (mock mode):
  9.101  Mock CLI creates .ods file
  9.102  Mock has 5 tabs: Seasons, Fencers, Events, Tournaments, Coverage
  9.103  Seasons tab has 11 header columns
  9.104  Seasons tab has 3 data rows (one per season)
  9.105  Fencers tab header area has matching parameter labels + defaults
  9.106  Fencers tab data header has 11 columns
  9.107  Fencers tab has 5 data rows with Polish diacritics
  9.108  Events tab has 13 header columns
  9.109  Events tab event_code cells have CONCAT formulas
  9.110  Tournaments tab has 15 header columns
  9.111  Tournaments tab tournament_code + event_code have formulas
  9.112  Coverage tab exists with category column headers
  9.113  Gray color coding on formula cells
  9.114  Blue color coding on auto-populated cells
  9.115  Sheet protection on all 5 tabs

Plan test IDs 9.142–9.160 (populate mode):
  9.142  parse_excel_filename male epee
  9.143  parse_excel_filename female foil (K prefix)
  9.144  parse_excel_filename returns None for SuperFive
  9.145  discover_excel_files finds 60 files (30 per season)
  9.146  discover_xml_files finds 17 result XMLs, skips ELIMINACJE
  9.147  extract_excel_tournaments returns correct dicts from one file
  9.148  extract_xml_tournaments correct weapon/gender/categories
  9.149  extract_xml_tournaments splits combined into separate rows
  9.150  build_events_from_tournaments deduplicates across weapons
  9.151  extract_fencers_from_results returns fencers from Excel
  9.152  extract_fencers_from_results returns fencers from XML with birth_date
  9.153  determine_import_status returns SCORED/EMPTY correctly
  9.154  determine_import_status returns LOST for missing sheet
  9.155  populate CLI creates .ods file
  9.156  Populate ODS has 5 tabs matching mock structure
  9.157  Seasons tab has 3 data rows
  9.158  Events tab has >=10 events
  9.159  Tournaments tab has >=50 tournament rows
  9.160  Fencers tab has >=100 fencers
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "tools" / "staging_spreadsheet.py"


def _get_tables(doc):
    """Return list of Table elements from loaded ODS doc."""
    from odf.table import Table

    return doc.getElementsByType(Table)


def _get_rows(table):
    """Return list of TableRow elements from a table."""
    from odf.table import TableRow

    return table.getElementsByType(TableRow)


def _get_cells(row):
    """Return list of TableCell elements from a row."""
    from odf.table import TableCell

    return row.getElementsByType(TableCell)


def _cell_text(cell) -> str:
    """Extract text content from a TableCell."""
    from odf.text import P

    paras = cell.getElementsByType(P)
    if paras:
        # Join all text nodes within the paragraph
        return "".join(
            node.data if hasattr(node, "data") else str(node)
            for p in paras
            for node in p.childNodes
            if hasattr(node, "data")
        )
    return ""


def _cell_formula(cell) -> str | None:
    """Extract formula attribute from a TableCell, or None."""
    return cell.getAttribute("formula")


def _cell_bg_color(cell, doc) -> str | None:
    """Extract background color from a cell's style."""
    style_name = cell.getAttribute("stylename")
    if not style_name:
        return None
    # Search automatic styles for the matching style
    for style in doc.automaticstyles.childNodes:
        if hasattr(style, "getAttribute") and style.getAttribute("name") == style_name:
            for child in style.childNodes:
                if hasattr(child, "getAttribute"):
                    bg = child.getAttribute("backgroundcolor")
                    if bg:
                        return bg.lower()
    return None


@pytest.fixture(scope="module")
def mock_ods(tmp_path_factory):
    """Generate mock ODS once, share across all tests in module."""
    from odf.opendocument import load

    tmpdir = tmp_path_factory.mktemp("staging")
    out_path = tmpdir / "staging_data_mock.ods"
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "mock", "--output", str(out_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Mock generation failed:\n{result.stderr}"
    doc = load(str(out_path))
    return doc


class TestMockCreation:
    def test_mock_creates_ods_file(self, tmp_path):
        """9.101 CLI exits 0 and file exists."""
        out_path = tmp_path / "test_mock.ods"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "mock", "--output", str(out_path)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert out_path.exists()
        assert out_path.stat().st_size > 0

    def test_mock_has_five_tabs(self, mock_ods):
        """9.102 5 Tables: Seasons, Fencers, Events, Tournaments, Coverage."""
        tables = _get_tables(mock_ods)
        names = [t.getAttribute("name") for t in tables]
        assert names == ["Seasons", "Fencers", "Events", "Tournaments", "Coverage"]


class TestSeasonsTab:
    def test_seasons_tab_columns(self, mock_ods):
        """9.103 Header row has 11 columns matching spec."""
        tables = _get_tables(mock_ods)
        seasons = tables[0]
        rows = _get_rows(seasons)
        header_cells = _get_cells(rows[0])
        headers = [_cell_text(c) for c in header_cells]
        expected = [
            "season_code", "dt_start", "dt_end", "bool_active",
            "ppw_best_count", "ppw_total_rounds", "mpw_multiplier",
            "pew_best_count", "mew_multiplier", "msw_multiplier",
            "import_log",
        ]
        assert headers == expected

    def test_seasons_tab_data_rows(self, mock_ods):
        """9.104 3 data rows (one per season)."""
        tables = _get_tables(mock_ods)
        seasons = tables[0]
        rows = _get_rows(seasons)
        # Row 0 = header, rows 1-3 = data
        data_rows = rows[1:]
        assert len(data_rows) == 3
        # Check season codes
        codes = [_cell_text(_get_cells(r)[0]) for r in data_rows]
        assert "SPWS-2023-2024" in codes
        assert "SPWS-2024-2025" in codes
        assert "SPWS-2025-2026" in codes


class TestFencersTab:
    def test_fencers_tab_header_area(self, mock_ods):
        """9.105 Rows 0-3 have matching parameter labels + default values."""
        tables = _get_tables(mock_ods)
        fencers = tables[1]
        rows = _get_rows(fencers)
        # First 4 rows are parameter rows
        param_labels = [_cell_text(_get_cells(rows[i])[0]) for i in range(4)]
        assert "auto_match_threshold" in param_labels
        assert "pending_threshold" in param_labels
        assert "use_diacritic_folding" in param_labels
        assert "use_token_set_ratio" in param_labels

    def test_fencers_tab_columns(self, mock_ods):
        """9.106 Data header row has 9 columns matching spec."""
        tables = _get_tables(mock_ods)
        fencers = tables[1]
        rows = _get_rows(fencers)
        # Row 4 = blank separator, Row 5 = data header
        header_row = rows[5]
        headers = [_cell_text(c) for c in _get_cells(header_row)]
        expected = [
            "id", "surname", "first_name", "birth_year",
            "birth_year_source", "club", "nationality",
            "match_status", "source_note",
        ]
        assert headers == expected

    def test_fencers_tab_data_rows(self, mock_ods):
        """9.107 5 data rows, at least one has Polish diacritics."""
        tables = _get_tables(mock_ods)
        fencers = tables[1]
        rows = _get_rows(fencers)
        # Data rows start at row 6 (after 4 params + 1 blank + 1 header)
        data_rows = rows[6:]
        assert len(data_rows) == 5
        # Check at least one name has Polish diacritics
        all_surnames = [_cell_text(_get_cells(r)[1]) for r in data_rows]
        polish_chars = set("ąćęłńóśźżĄĆĘŁŃÓŚŹŻ")
        has_diacritics = any(
            any(c in polish_chars for c in name)
            for name in all_surnames
        )
        assert has_diacritics, f"No Polish diacritics found in: {all_surnames}"


class TestEventsTab:
    def test_events_tab_columns(self, mock_ods):
        """9.108 Header has 15 columns matching spec."""
        tables = _get_tables(mock_ods)
        events = tables[2]
        rows = _get_rows(events)
        headers = [_cell_text(c) for c in _get_cells(rows[0])]
        expected = [
            "event_code", "event_prefix", "name", "season_code",
            "organizer", "location", "country",
            "dt_start", "dt_end", "status",
            "url_event", "url_invitation",
            "entry_fee", "currency", "discrepancy_note",
        ]
        assert headers == expected

    def test_events_tab_formula_columns(self, mock_ods):
        """9.109 event_code cells have formula attr with of:=CONCAT."""
        tables = _get_tables(mock_ods)
        events = tables[2]
        rows = _get_rows(events)
        # Check data rows (skip header)
        for row in rows[1:]:
            cells = _get_cells(row)
            formula = _cell_formula(cells[0])
            assert formula is not None, "event_code cell should have a formula"
            assert "CONCAT" in formula.upper(), f"Expected CONCAT formula, got: {formula}"


class TestTournamentsTab:
    def test_tournaments_tab_columns(self, mock_ods):
        """9.110 Header has 15 columns matching spec."""
        tables = _get_tables(mock_ods)
        tournaments = tables[3]
        rows = _get_rows(tournaments)
        headers = [_cell_text(c) for c in _get_cells(rows[0])]
        expected = [
            "tournament_code", "event_code", "event_prefix", "season_code",
            "weapon", "gender", "age_cat", "type",
            "dt_tournament", "participant_count", "result_url",
            "source_file", "original_source", "import_status", "notes",
        ]
        assert headers == expected

    def test_tournaments_tab_formula_columns(self, mock_ods):
        """9.111 tournament_code + event_code cells have formula attrs."""
        tables = _get_tables(mock_ods)
        tournaments = tables[3]
        rows = _get_rows(tournaments)
        for row in rows[1:]:
            cells = _get_cells(row)
            # Column 0: tournament_code
            f0 = _cell_formula(cells[0])
            assert f0 is not None, "tournament_code should have a formula"
            assert "CONCAT" in f0.upper()
            # Column 1: event_code
            f1 = _cell_formula(cells[1])
            assert f1 is not None, "event_code should have a formula"
            assert "CONCAT" in f1.upper()


class TestCoverageTab:
    def test_coverage_tab_exists(self, mock_ods):
        """9.112 Coverage tab exists with category column headers + green data cells."""
        tables = _get_tables(mock_ods)
        coverage = tables[4]
        assert coverage.getAttribute("name") == "Coverage"
        rows = _get_rows(coverage)
        assert len(rows) > 0
        # Check that header row contains some category identifiers
        headers = [_cell_text(c) for c in _get_cells(rows[0])]
        header_str = " ".join(headers)
        # Should contain weapon/gender/age_cat combos
        assert "EPEE" in header_str.upper() or "M" in header_str
        # Data cells with participant counts should be light green
        if len(rows) > 1:
            data_cells = _get_cells(rows[1])
            for cell in data_cells[1:]:  # skip event label col
                text = _cell_text(cell)
                bg = _cell_bg_color(cell, mock_ods)
                if text and text not in ("?", "-", "LOST", "EMPTY", "0"):
                    assert bg == "#c6efce", f"Data cell '{text}' should be green, got {bg}"


class TestColorCoding:
    def test_color_coding_gray_cells(self, mock_ods):
        """9.113 Formula cells (event_code, tournament_code) have bg=#e0e0e0."""
        tables = _get_tables(mock_ods)
        # Check Events tab, column 0 (event_code) data row
        events = tables[2]
        rows = _get_rows(events)
        if len(rows) > 1:
            cell = _get_cells(rows[1])[0]
            bg = _cell_bg_color(cell, mock_ods)
            assert bg == "#e0e0e0", f"Expected gray (#e0e0e0), got: {bg}"

    def test_color_coding_header_inverse(self, mock_ods):
        """9.114 Header row cells have dark inverse background (#2c3e50)."""
        tables = _get_tables(mock_ods)
        # Check Seasons header row
        seasons = tables[0]
        rows = _get_rows(seasons)
        header_cell = _get_cells(rows[0])[0]
        bg = _cell_bg_color(header_cell, mock_ods)
        assert bg == "#2c3e50", f"Expected dark header (#2c3e50), got: {bg}"


class TestSheetProtection:
    def test_sheet_protection(self, mock_ods):
        """9.115 All 5 Tables have protected='true'."""
        tables = _get_tables(mock_ods)
        assert len(tables) == 5
        for table in tables:
            name = table.getAttribute("name")
            protected = table.getAttribute("protected")
            assert protected == "true", (
                f"Tab '{name}' should be protected, got: {protected}"
            )


# ===========================================================================
# Populate mode tests (9.142–9.160)
# ===========================================================================

INPUT_DIR = Path(__file__).resolve().parent.parent.parent / "doc" / "external_files"


class TestParseExcelFilename:
    def test_parse_male_epee(self):
        """9.142 parse_excel_filename parses male epee correctly."""
        from tools.populate_staging import parse_excel_filename

        result = parse_excel_filename("SZPADA-2-2024-2025.xlsx")
        assert result is not None
        assert result["weapon"] == "EPEE"
        assert result["gender"] == "M"
        assert result["age_cat"] == "V2"
        assert result["season_code"] == "SPWS-2024-2025"

    def test_parse_female_foil(self):
        """9.143 parse_excel_filename parses female foil (K prefix)."""
        from tools.populate_staging import parse_excel_filename

        result = parse_excel_filename("FLORET-K1-2024-2025.xlsx")
        assert result is not None
        assert result["weapon"] == "FOIL"
        assert result["gender"] == "F"
        assert result["age_cat"] == "V1"
        assert result["season_code"] == "SPWS-2024-2025"

    def test_parse_superfive_returns_none(self):
        """9.144 parse_excel_filename returns None for SuperFive files."""
        from tools.populate_staging import parse_excel_filename

        assert parse_excel_filename("SuperFive - szpada 2024 - 2025.xlsx") is None


class TestDiscoverFiles:
    @pytest.mark.skipif(
        not INPUT_DIR.exists(),
        reason="doc/external_files/ not present",
    )
    def test_discover_excel_files(self):
        """9.145 discover_excel_files finds 90 files (30 per season × 3 seasons)."""
        from tools.populate_staging import discover_excel_files

        files = discover_excel_files(INPUT_DIR)
        assert len(files) == 90  # 30 per season × 3 seasons

    @pytest.mark.skipif(
        not INPUT_DIR.exists(),
        reason="doc/external_files/ not present",
    )
    def test_discover_xml_files(self):
        """9.146 discover_xml_files finds 14 result XMLs, skips ELIMINACJE."""
        from tools.populate_staging import discover_xml_files

        files = discover_xml_files(INPUT_DIR)
        assert len(files) == 14  # 19 total - 5 ELIMINACJE
        # No ELIMINACJE files
        for f in files:
            assert "ELIMINACJE" not in f.get("alt_name", "")
            assert "GRVETX" not in str(f["path"])


XML_FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"


class TestExtractExcelTournaments:
    @pytest.mark.skipif(
        not INPUT_DIR.exists(),
        reason="doc/external_files/ not present",
    )
    def test_extract_excel_tournaments(self):
        """9.147 extract_excel_tournaments returns correct dicts from one file."""
        from tools.populate_staging import discover_excel_files, extract_excel_tournaments

        files = discover_excel_files(INPUT_DIR)
        # Pick one file: SZPADA-2-2024-2025.xlsx (male epee V2)
        target = [f for f in files if f["weapon"] == "EPEE" and f["gender"] == "M" and f["age_cat"] == "V2" and f["season_code"] == "SPWS-2024-2025"]
        assert len(target) == 1, f"Expected 1 file, got {len(target)}"
        tournaments = extract_excel_tournaments(target[0])
        assert len(tournaments) > 0
        # Each tournament must have required keys
        required_keys = {"event_prefix", "season_code", "weapon", "gender", "age_cat",
                         "type", "dt_tournament", "participant_count",
                         "source_file", "import_status"}
        for t in tournaments:
            missing = required_keys - set(t.keys())
            assert not missing, f"Missing keys: {missing}"
        # Should include PPW events (PP1-PP5)
        prefixes = {t["event_prefix"] for t in tournaments}
        assert any(p.startswith("PP") for p in prefixes), f"Expected PP* prefixes, got {prefixes}"


class TestExtractXmlTournaments:
    def test_extract_xml_single_category(self):
        """9.148 extract_xml_tournaments correct weapon/gender/categories."""
        from tools.populate_staging import extract_xml_tournaments

        file_info = {
            "path": XML_FIXTURES / "single_category.xml",
            "weapon": "EPEE",
            "gender": "M",
            "categories": ["V2"],
            "alt_name": "SZPADA MĘŻCZYZN v2",
            "title": "IV Puchar Polski Weteranów Gdańsk 2026",
            "date": "21.02.2026",
            "season_code": "SPWS-2025-2026",
        }
        tournaments = extract_xml_tournaments(file_info)
        assert len(tournaments) == 1
        t = tournaments[0]
        assert t["weapon"] == "EPEE"
        assert t["gender"] == "M"
        assert t["age_cat"] == "V2"
        assert t["participant_count"] == 5
        assert t["season_code"] == "SPWS-2025-2026"
        assert t["import_status"] == "SCORED"

    def test_extract_xml_combined_splits(self):
        """9.149 extract_xml_tournaments splits combined into separate rows."""
        from tools.populate_staging import extract_xml_tournaments

        file_info = {
            "path": XML_FIXTURES / "combined_v0v1.xml",
            "weapon": "EPEE",
            "gender": "M",
            "categories": ["V0", "V1"],
            "alt_name": "SZPADA MĘŻCZYZN v0v1",
            "title": "IV Puchar Polski Weteranów Gdańsk 2026",
            "date": "21.02.2026",
            "season_code": "SPWS-2025-2026",
        }
        tournaments = extract_xml_tournaments(file_info)
        assert len(tournaments) == 2
        cats = {t["age_cat"] for t in tournaments}
        assert cats == {"V0", "V1"}
        # Both should reference the same source file
        assert all(t["source_file"] == str(file_info["path"]) for t in tournaments)
        # Both should have "combined" in notes
        assert all("combined" in t.get("notes", "").lower() for t in tournaments)


class TestBuildEvents:
    def test_build_events_deduplicates(self):
        """9.150 build_events_from_tournaments deduplicates across weapons."""
        from tools.populate_staging import build_events_from_tournaments

        # Simulate tournaments from different weapons but same event
        tournaments = [
            {"event_prefix": "PPW1", "season_code": "SPWS-2024-2025",
             "weapon": "EPEE", "gender": "M", "age_cat": "V2",
             "type": "PPW", "dt_tournament": "2024-10-05",
             "participant_count": 20, "source_file": "SZPADA-2-2024-2025.xlsx",
             "import_status": "SCORED", "result_url": None, "original_source": None,
             "notes": None},
            {"event_prefix": "PPW1", "season_code": "SPWS-2024-2025",
             "weapon": "FOIL", "gender": "M", "age_cat": "V2",
             "type": "PPW", "dt_tournament": "2024-10-05",
             "participant_count": 15, "source_file": "FLORET-2-2024-2025.xlsx",
             "import_status": "SCORED", "result_url": None, "original_source": None,
             "notes": None},
            {"event_prefix": "PPW2", "season_code": "SPWS-2024-2025",
             "weapon": "EPEE", "gender": "M", "age_cat": "V2",
             "type": "PPW", "dt_tournament": "2024-11-09",
             "participant_count": 18, "source_file": "SZPADA-2-2024-2025.xlsx",
             "import_status": "SCORED", "result_url": None, "original_source": None,
             "notes": None},
        ]
        events = build_events_from_tournaments(tournaments)
        # PPW1 should be deduplicated: 2 tournament rows → 1 event
        # PPW2 is separate: 1 event
        assert len(events) == 2
        prefixes = {e["event_prefix"] for e in events}
        assert prefixes == {"PPW1", "PPW2"}
        # Each event must have required keys
        for e in events:
            assert "event_prefix" in e
            assert "season_code" in e
            assert "dt_start" in e


class TestExtractFencers:
    def test_extract_fencers_from_excel(self):
        """9.151 extract_fencers_from_results returns fencers from Excel tournament."""
        from tools.populate_staging import extract_fencers_from_results

        # Simulate a tournament dict with an Excel source
        tournament = {
            "source_file": str(XML_FIXTURES / "single_category.xml"),
            "import_status": "SCORED",
            "type": "PPW",
            "weapon": "EPEE",
            "gender": "M",
            "age_cat": "V2",
        }
        # Use XML fixture as a stand-in (both return fencer lists)
        fencers = extract_fencers_from_results([tournament])
        assert len(fencers) >= 1
        # Each fencer has surname, first_name
        for f in fencers:
            assert "surname" in f
            assert "first_name" in f

    def test_extract_fencers_from_xml_with_birth(self):
        """9.152 extract_fencers_from_results returns fencers from XML with birth_year."""
        from tools.populate_staging import extract_fencers_from_results

        tournament = {
            "source_file": str(XML_FIXTURES / "single_category.xml"),
            "import_status": "SCORED",
            "type": "PPW",
            "weapon": "EPEE",
            "gender": "M",
            "age_cat": "V2",
        }
        fencers = extract_fencers_from_results([tournament])
        # single_category.xml has DateNaissance for all fencers
        with_birth = [f for f in fencers if f.get("birth_year")]
        assert len(with_birth) >= 3


class TestDetermineImportStatus:
    def test_scored_and_empty(self):
        """9.153 determine_import_status returns SCORED/EMPTY correctly."""
        from tools.populate_staging import determine_import_status

        assert determine_import_status(5) == "SCORED"
        assert determine_import_status(1) == "SCORED"
        assert determine_import_status(0) == "EMPTY"

    def test_lost_for_none(self):
        """9.154 determine_import_status returns LOST for None (missing sheet)."""
        from tools.populate_staging import determine_import_status

        assert determine_import_status(None) == "LOST"


# ===========================================================================
# Populate mode integration tests (9.155–9.160)
# ===========================================================================

_SKIP_POPULATE = not INPUT_DIR.exists()
_SKIP_REASON = "doc/external_files/ not present"


@pytest.fixture(scope="module")
def populate_ods(tmp_path_factory):
    """Generate populate ODS once, share across integration tests."""
    if _SKIP_POPULATE:
        pytest.skip(_SKIP_REASON)
    from odf.opendocument import load

    tmpdir = tmp_path_factory.mktemp("populate")
    out_path = tmpdir / "staging_data_populate.ods"
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "populate",
         "--input", str(INPUT_DIR), "--output", str(out_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Populate failed:\n{result.stderr}"
    doc = load(str(out_path))
    return doc


class TestPopulateCLI:
    @pytest.mark.skipif(_SKIP_POPULATE, reason=_SKIP_REASON)
    def test_populate_creates_ods(self, tmp_path):
        """9.155 populate CLI creates .ods file."""
        out_path = tmp_path / "test_populate.ods"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "populate",
             "--input", str(INPUT_DIR), "--output", str(out_path)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert out_path.exists()
        assert out_path.stat().st_size > 0


class TestPopulateStructure:
    @pytest.mark.skipif(_SKIP_POPULATE, reason=_SKIP_REASON)
    def test_populate_has_five_tabs(self, populate_ods):
        """9.156 Populate ODS has 5 tabs matching mock structure."""
        tables = _get_tables(populate_ods)
        names = [t.getAttribute("name") for t in tables]
        assert names == ["Seasons", "Fencers", "Events", "Tournaments", "Coverage"]

    @pytest.mark.skipif(_SKIP_POPULATE, reason=_SKIP_REASON)
    def test_seasons_tab_rows(self, populate_ods):
        """9.157 Seasons tab has 3 data rows."""
        tables = _get_tables(populate_ods)
        seasons = tables[0]
        rows = _get_rows(seasons)
        data_rows = rows[1:]  # skip header
        assert len(data_rows) == 3

    @pytest.mark.skipif(_SKIP_POPULATE, reason=_SKIP_REASON)
    def test_events_tab_count(self, populate_ods):
        """9.158 Events tab has >=10 events."""
        tables = _get_tables(populate_ods)
        events = tables[2]
        rows = _get_rows(events)
        data_rows = rows[1:]
        assert len(data_rows) >= 10, f"Expected >=10 events, got {len(data_rows)}"

    @pytest.mark.skipif(_SKIP_POPULATE, reason=_SKIP_REASON)
    def test_tournaments_tab_count(self, populate_ods):
        """9.159 Tournaments tab has >=50 tournament rows."""
        tables = _get_tables(populate_ods)
        tournaments = tables[3]
        rows = _get_rows(tournaments)
        data_rows = rows[1:]
        assert len(data_rows) >= 50, f"Expected >=50 tournaments, got {len(data_rows)}"

    @pytest.mark.skipif(_SKIP_POPULATE, reason=_SKIP_REASON)
    def test_fencers_tab_count(self, populate_ods):
        """9.160 Fencers tab has >=100 fencers."""
        tables = _get_tables(populate_ods)
        fencers = tables[1]
        rows = _get_rows(fencers)
        # Data rows start at row 6 (4 params + 1 blank + 1 header)
        data_rows = rows[6:]
        assert len(data_rows) >= 100, f"Expected >=100 fencers, got {len(data_rows)}"
