"""
IR contract tests for parser refactors.

Phase 1 / part 2 of the rebuild. As each of the 8 parsers gets refactored
to emit ParsedTournament, its contract test class lands here.

One test class per parser. Each class verifies the parser's `parse_*()`
factory produces a schema-valid ParsedTournament with correct fields,
correct source_row_id strategy (native vs synthetic), and the parser's
quirks preserved (excluded flags, age markers, ties, locale handling).

Plan test IDs are namespaced per parser:
  ftl_ir.1..N  — FTL JSON + CSV paths
  engarde_ir.1..N  — Engarde HTML
  ... (added as parsers are migrated)
"""

from __future__ import annotations

import json
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"


# =============================================================================
# FTL — FencingTimeLive (JSON API + CSV download)
# =============================================================================
class TestFTLIRContract:
    """FTL parser must emit ParsedTournament; native ID for JSON, synthetic for CSV."""

    JSON_FIXTURE = FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json"
    CSV_FIXTURE = FIXTURES / "ftl" / "csv_EEC7379682834E588E5B267447C7266A.csv"

    def test_parse_json_returns_parsed_tournament(self):
        """ftl_ir.1: parse_json returns ParsedTournament with source_kind=FTL."""
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.scrapers.ftl import parse_json

        data = json.loads(self.JSON_FIXTURE.read_text())
        pt = parse_json(data)

        assert isinstance(pt, ParsedTournament)
        assert pt.source_kind == SourceKind.FTL
        assert len(pt.results) == 53
        assert pt.raw_pool_size == 53

    def test_parse_json_uses_native_id(self):
        """ftl_ir.2: JSON path uses FTL's native `id` field, format `ftl:{id}`."""
        from python.scrapers.ftl import parse_json

        data = json.loads(self.JSON_FIXTURE.read_text())
        pt = parse_json(data)

        # First entry in fixture has id="BB730C05A6CE496B918951F0AC0684FE".
        first = pt.results[0]
        assert first.source_row_id == "ftl:BB730C05A6CE496B918951F0AC0684FE"
        assert first.place == 1
        assert "ATANASSOW" in first.fencer_name
        assert first.fencer_country == "POL"

    def test_parse_json_ties_have_distinct_ids(self):
        """ftl_ir.3: two fencers tied at 3T both get place=3 but distinct IDs (native)."""
        from python.scrapers.ftl import parse_json

        data = json.loads(self.JSON_FIXTURE.read_text())
        pt = parse_json(data)

        thirds = [r for r in pt.results if r.place == 3]
        assert len(thirds) == 2, "fixture has 2 fencers tied at 3T"
        assert thirds[0].source_row_id != thirds[1].source_row_id

    def test_parse_json_age_marker_preserved(self):
        """ftl_ir.4: marker between surname and given name lands in raw_age_marker.

        Fixture names are like "ATANASSOW 2 Aleksander" — the digit '2' is the
        FTL combined-pool age-cat marker. IR keeps it as raw_age_marker; the
        cleaned name drops it.
        """
        from python.scrapers.ftl import parse_json

        data = json.loads(self.JSON_FIXTURE.read_text())
        pt = parse_json(data)

        first = pt.results[0]
        assert first.raw_age_marker == "2"
        assert "2" not in first.fencer_name.split()  # marker stripped from name

    def test_parse_json_excluded_filtered(self):
        """ftl_ir.5: entries with excluded=True are dropped from the IR."""
        from python.scrapers.ftl import parse_json

        # Build a synthetic dataset including an excluded entry.
        data = [
            {"id": "AAA", "place": "1", "excluded": False, "name": "ALPHA", "country": "POL"},
            {"id": "BBB", "place": "2", "excluded": True,  "name": "BETA",  "country": "POL"},
            {"id": "CCC", "place": "3", "excluded": False, "name": "GAMMA", "country": "POL"},
        ]
        pt = parse_json(data)

        names = [r.fencer_name for r in pt.results]
        assert "BETA" not in names
        assert names == ["ALPHA", "GAMMA"]

    def test_parse_csv_uses_synthetic_id(self):
        """ftl_ir.6: CSV path has no native ID; falls back to make_synthetic_id format."""
        from python.scrapers.ftl import parse_csv

        csv_text = self.CSV_FIXTURE.read_text()
        pt = parse_csv(csv_text)

        first = pt.results[0]
        # Synthetic format: ftl:row{i}:place{p}:{name-slug}
        assert first.source_row_id.startswith("ftl:row1:place1:")
        # Polish folding + name preservation in slug
        assert first.fencer_name  # non-empty

    def test_parse_json_weapon_from_title(self):
        """ftl_ir.7: parser extracts weapon hint from page title when supplied."""
        from python.scrapers.ftl import parse_json

        data = json.loads(self.JSON_FIXTURE.read_text())
        pt_with_title = parse_json(data, title="V2 Men's Épée — Some Tournament")
        pt_without = parse_json(data)

        assert pt_with_title.weapon == "EPEE"
        assert pt_without.weapon is None


# =============================================================================
# Engarde — engarde-service.com final-classification HTML (multilingual)
# =============================================================================
class TestEngardeIRContract:
    """Engarde parser must emit ParsedTournament with synthetic IDs."""

    HU_FIXTURE = FIXTURES / "engarde" / "clasfinal_hunfencing.html"
    ES_FIXTURE = FIXTURES / "engarde" / "clasfinal_madrid.html"

    def test_parse_html_returns_parsed_tournament(self):
        """engarde_ir.1: parse_html returns ParsedTournament with source_kind=ENGARDE."""
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.scrapers.engarde import parse_html

        html = self.HU_FIXTURE.read_text()
        pt = parse_html(html)

        assert isinstance(pt, ParsedTournament)
        assert pt.source_kind == SourceKind.ENGARDE
        assert len(pt.results) > 0
        assert pt.raw_pool_size == len(pt.results)

    def test_parse_html_synthetic_id_format(self):
        """engarde_ir.2: Engarde has no native ID; uses synthetic ID format."""
        from python.scrapers.engarde import parse_html

        html = self.HU_FIXTURE.read_text()
        pt = parse_html(html)

        first = pt.results[0]
        assert first.source_row_id.startswith("engarde:row1:place1:")

    def test_parse_html_results_well_formed(self):
        """engarde_ir.3: each result has non-empty name, place>=1, place is int."""
        from python.scrapers.engarde import parse_html

        html = self.HU_FIXTURE.read_text()
        pt = parse_html(html)

        for r in pt.results:
            assert isinstance(r.place, int) and r.place >= 1
            assert r.fencer_name and isinstance(r.fencer_name, str)

    def test_parse_html_hungarian_locale_agnostic(self):
        """engarde_ir.4: Hungarian fixture parses despite localized headers (R012)."""
        from python.scrapers.engarde import parse_html

        html = self.HU_FIXTURE.read_text()
        pt = parse_html(html)

        # If parsing failed, results would be empty.
        assert len(pt.results) >= 5, "HU fixture should yield > 5 fencers"
        # First-place fencer should have place=1.
        firsts = [r for r in pt.results if r.place == 1]
        assert len(firsts) >= 1

    def test_parse_html_spanish_locale_agnostic(self):
        """engarde_ir.5: Spanish fixture parses too — same parser, no locale code."""
        from python.scrapers.engarde import parse_html

        html = self.ES_FIXTURE.read_text()
        pt = parse_html(html)

        assert len(pt.results) > 0
        for r in pt.results:
            assert r.fencer_name


# =============================================================================
# file_import — admin upload dispatcher (CSV / XLSX / JSON)
# =============================================================================
class TestFileImportIRContract:
    """file_import dispatcher must emit ParsedTournament with source_kind=FILE_IMPORT."""

    def test_parse_csv_returns_parsed_tournament(self):
        """file_import_ir.1: CSV bytes route to ParsedTournament."""
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.scrapers.file_import import parse

        csv_bytes = (
            "Place,Name,Club(s),Division,Country\n"
            "1,KOWAL Anna,KS Foo,V2,POL\n"
            "2,NOWAK Beata,KS Bar,V2,POL\n"
            "3,STEINER Eva,KS Baz,V2,GER\n"
        ).encode("utf-8")
        pt = parse(csv_bytes, filename="results.csv")

        assert isinstance(pt, ParsedTournament)
        assert pt.source_kind == SourceKind.FILE_IMPORT
        assert len(pt.results) == 3
        assert pt.raw_pool_size == 3
        assert pt.results[0].fencer_name.startswith("KOWAL")
        assert pt.results[0].place == 1

    def test_parse_csv_uses_synthetic_id(self):
        """file_import_ir.2: CSV path generates synthetic IDs prefixed with `file_import:`."""
        from python.scrapers.file_import import parse

        csv_bytes = (
            "Place,Name,Club(s),Division,Country\n"
            "1,KOWAL Anna,,V2,POL\n"
        ).encode("utf-8")
        pt = parse(csv_bytes, filename="results.csv")

        first = pt.results[0]
        assert first.source_row_id.startswith("file_import:row1:place1:")

    def test_parse_unsupported_extension_raises(self):
        """file_import_ir.3: Unsupported extension still raises ValueError as the legacy path does."""
        import pytest as _pytest
        from python.scrapers.file_import import parse

        with _pytest.raises(ValueError):
            parse(b"whatever", filename="results.txt")
