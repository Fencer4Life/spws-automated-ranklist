"""
Tests for file import parsers (T9.10).

Covers: parse_file dispatcher, xlsx_parser, json_parser.
Plan test IDs: 9.93–9.100.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from scrapers.file_import import parse_file
from scrapers.xlsx_parser import parse_xlsx
from scrapers.json_parser import parse_json

FIXTURES = Path(__file__).parent / "fixtures" / "file_import"


def _assert_valid_result(result: dict) -> None:
    """Assert required fields: fencer_name (str, non-empty), place (int >= 1)."""
    assert "fencer_name" in result
    assert "place" in result
    assert isinstance(result["place"], int)
    assert result["place"] >= 1
    assert isinstance(result["fencer_name"], str)
    assert len(result["fencer_name"]) > 0


class TestParseFileDispatcher:
    """Tests for parse_file dispatcher routing."""

    def test_csv_dispatch(self):
        """9.93 parse_file dispatches .csv to csv_upload."""
        csv_bytes = b"Place,Name,Country\n1,ATANASSOW Aleksander,POL\n2,KOWALSKI Jan,POL\n"
        results = parse_file(csv_bytes, "results.csv")
        assert len(results) == 2
        assert results[0]["fencer_name"] == "ATANASSOW Aleksander"
        assert results[0]["place"] == 1

    def test_xlsx_dispatch(self):
        """9.94 parse_file dispatches .xlsx to xlsx_parser."""
        xlsx_bytes = (FIXTURES / "sample.xlsx").read_bytes()
        results = parse_file(xlsx_bytes, "results.xlsx")
        assert len(results) == 5
        assert results[0]["fencer_name"] == "ATANASSOW Aleksander"

    def test_json_dispatch(self):
        """9.95 parse_file dispatches .json to json_parser."""
        json_bytes = (FIXTURES / "sample.json").read_bytes()
        results = parse_file(json_bytes, "results.json")
        assert len(results) == 5
        assert results[0]["fencer_name"] == "ATANASSOW Aleksander"

    def test_unsupported_format(self):
        """9.96 parse_file raises ValueError for .pdf."""
        with pytest.raises(ValueError, match="Unsupported file format"):
            parse_file(b"fake pdf content", "results.pdf")


class TestXlsxParser:
    """Tests for Excel parser."""

    def test_xlsx_extracts_fields(self):
        """9.97 xlsx_parser extracts fencer_name, place, country from .xlsx."""
        xlsx_bytes = (FIXTURES / "sample.xlsx").read_bytes()
        results = parse_xlsx(xlsx_bytes)
        assert len(results) == 5
        first = results[0]
        assert first["fencer_name"] == "ATANASSOW Aleksander"
        assert first["place"] == 1
        assert first["country"] == "POL"
        # Verify all results have required keys
        for r in results:
            _assert_valid_result(r)
            assert "country" in r

    def test_xls_format(self):
        """9.99 xlsx_parser handles .xls format via xlrd."""
        xls_bytes = (FIXTURES / "sample.xls").read_bytes()
        results = parse_xlsx(xls_bytes, ext=".xls")
        assert len(results) == 5
        first = results[0]
        assert first["fencer_name"] == "ATANASSOW Aleksander"
        assert first["place"] == 1
        assert first["country"] == "POL"


class TestJsonParser:
    """Tests for JSON parser."""

    def test_json_extracts_fields(self):
        """9.98 json_parser extracts fencer_name, place, country from .json."""
        json_bytes = (FIXTURES / "sample.json").read_bytes()
        results = parse_json(json_bytes)
        assert len(results) == 5
        first = results[0]
        assert first["fencer_name"] == "ATANASSOW Aleksander"
        assert first["place"] == 1
        assert first["country"] == "POL"
        for r in results:
            _assert_valid_result(r)
            assert "country" in r


class TestAllParsersContract:
    """Cross-parser contract tests."""

    def test_all_parsers_return_standard_keys(self):
        """9.100 All parsers return list[dict] with keys fencer_name, place."""
        csv_bytes = b"Place,Name,Country\n1,TEST Fencer,POL\n"
        xlsx_bytes = (FIXTURES / "sample.xlsx").read_bytes()
        json_bytes = (FIXTURES / "sample.json").read_bytes()

        for label, results in [
            ("csv", parse_file(csv_bytes, "test.csv")),
            ("xlsx", parse_file(xlsx_bytes, "test.xlsx")),
            ("json", parse_file(json_bytes, "test.json")),
        ]:
            assert isinstance(results, list), f"{label}: expected list"
            assert len(results) > 0, f"{label}: expected non-empty"
            for r in results:
                assert isinstance(r, dict), f"{label}: expected dict"
                assert "fencer_name" in r, f"{label}: missing fencer_name"
                assert "place" in r, f"{label}: missing place"
