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


# =============================================================================
# FencingTime XML — XML export from FencingTime v4.7+
# =============================================================================
class TestFencingTimeXMLIRContract:
    """FencingTime XML must emit ParsedTournament with native ID + metadata."""

    SINGLE_FIXTURE = FIXTURES / "fencingtime_xml" / "single_category.xml"
    NO_DOB_FIXTURE = FIXTURES / "fencingtime_xml" / "no_dob.xml"

    def test_parse_returns_parsed_tournament(self):
        """ftxml_ir.1: parse returns ParsedTournament with source_kind=FENCINGTIME_XML."""
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.scrapers.fencingtime_xml import parse

        pt = parse(self.SINGLE_FIXTURE.read_bytes())

        assert isinstance(pt, ParsedTournament)
        assert pt.source_kind == SourceKind.FENCINGTIME_XML
        assert len(pt.results) == 5
        assert pt.raw_pool_size == 5

    def test_parse_uses_native_id(self):
        """ftxml_ir.2: source_row_id uses Tireur.ID, format `ft_xml:{ID}`."""
        from python.scrapers.fencingtime_xml import parse

        pt = parse(self.SINGLE_FIXTURE.read_bytes())

        # Fixture's first Tireur has ID="-1"; second ID="-2"; etc.
        ids = {r.source_row_id for r in pt.results}
        assert any(rid.startswith("ft_xml:") for rid in ids)
        assert len(ids) == len(pt.results), "every row has a distinct source_row_id"

    def test_parse_birth_date_from_date_naissance(self):
        """ftxml_ir.3: birth_date populated from DateNaissance attribute (DD.MM.YYYY)."""
        import datetime
        from python.scrapers.fencingtime_xml import parse

        pt = parse(self.SINGLE_FIXTURE.read_bytes())

        # Find NOWAK Piotr (Classement=1, DateNaissance=22.07.1970)
        nowak = next((r for r in pt.results if "NOWAK" in r.fencer_name), None)
        assert nowak is not None
        assert nowak.birth_date == datetime.date(1970, 7, 22)

    def test_parse_metadata_weapon_gender_date(self):
        """ftxml_ir.4: weapon, gender, parsed_date extracted from root attributes."""
        import datetime
        from python.scrapers.fencingtime_xml import parse

        pt = parse(self.SINGLE_FIXTURE.read_bytes())

        assert pt.weapon == "EPEE"          # Arme="E" -> EPEE
        assert pt.gender == "M"             # Sexe="M"
        assert pt.parsed_date == datetime.date(2026, 2, 21)  # Date="21.02.2026"

    def test_parse_category_hint_from_altname(self):
        """ftxml_ir.5: category_hint extracted from AltName ('SZPADA MĘŻCZYZN v2' -> 'V2')."""
        from python.scrapers.fencingtime_xml import parse

        pt = parse(self.SINGLE_FIXTURE.read_bytes())

        assert pt.category_hint == "V2"

    def test_parse_handles_missing_dob(self):
        """ftxml_ir.6: missing/empty DateNaissance leaves birth_date=None, no exception."""
        from python.scrapers.fencingtime_xml import parse

        pt = parse(self.NO_DOB_FIXTURE.read_bytes())

        assert len(pt.results) > 0
        # At least one row should have birth_date=None (the fixture's purpose).
        no_dob = [r for r in pt.results if r.birth_date is None]
        assert len(no_dob) >= 1


# =============================================================================
# 4Fence — 4fence.it competition results HTML
# =============================================================================
class TestFourFenceIRContract:
    """4Fence parser must emit ParsedTournament with synthetic IDs (no native)."""

    FIXTURE = FIXTURES / "fourfence" / "clafinale_terni.html"

    def test_parse_html_returns_parsed_tournament(self):
        """fourfence_ir.1: parse_html returns ParsedTournament with source_kind=FOURFENCE."""
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.scrapers.fourfence import parse_html

        html = self.FIXTURE.read_text()
        pt = parse_html(html)

        assert isinstance(pt, ParsedTournament)
        assert pt.source_kind == SourceKind.FOURFENCE
        assert len(pt.results) > 0
        assert pt.raw_pool_size == len(pt.results)

    def test_parse_html_synthetic_id_format(self):
        """fourfence_ir.2: 4Fence has no native ID; uses synthetic format `fourfence:row1:place1:`."""
        from python.scrapers.fourfence import parse_html

        html = self.FIXTURE.read_text()
        pt = parse_html(html)

        first = pt.results[0]
        assert first.source_row_id.startswith("fourfence:row1:place1:")

    def test_parse_html_country_is_none(self):
        """fourfence_ir.3: 4Fence doesn't surface country reliably — IR shows None, not empty string."""
        from python.scrapers.fourfence import parse_html

        html = self.FIXTURE.read_text()
        pt = parse_html(html)

        for r in pt.results:
            assert r.fencer_country is None, (
                f"expected None country, got {r.fencer_country!r}"
            )

    def test_parse_html_results_well_formed(self):
        """fourfence_ir.4: each result has non-empty name + valid place."""
        from python.scrapers.fourfence import parse_html

        html = self.FIXTURE.read_text()
        pt = parse_html(html)

        for r in pt.results:
            assert r.fencer_name and isinstance(r.fencer_name, str)
            assert isinstance(r.place, int) and r.place >= 1


# =============================================================================
# Dartagnan — dartagnan.live competition rankings page
# =============================================================================
class TestDartagnanIRContract:
    """Dartagnan parse_rankings: pure function on rankings HTML, no I/O."""

    FIXTURE = FIXTURES / "dartagnan" / "6687-rankings.html"
    EMPTY_FIXTURE = FIXTURES / "dartagnan" / "7027-rankings-empty.html"

    def test_parse_rankings_returns_parsed_tournament(self):
        """dartagnan_ir.1: parse_rankings returns ParsedTournament source_kind=DARTAGNAN."""
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.scrapers.dartagnan import parse_rankings

        html = self.FIXTURE.read_text()
        pt = parse_rankings(html)

        assert isinstance(pt, ParsedTournament)
        assert pt.source_kind == SourceKind.DARTAGNAN
        assert len(pt.results) > 0
        assert pt.raw_pool_size == len(pt.results)

    def test_parse_rankings_synthetic_id_format(self):
        """dartagnan_ir.2: synthetic IDs prefixed `dartagnan:row1:place1:`."""
        from python.scrapers.dartagnan import parse_rankings

        html = self.FIXTURE.read_text()
        pt = parse_rankings(html)

        first = pt.results[0]
        assert first.source_row_id.startswith("dartagnan:row1:place1:")

    def test_parse_rankings_country_from_flag(self):
        """dartagnan_ir.3: country (3-letter ISO) extracted from flag img src."""
        from python.scrapers.dartagnan import parse_rankings

        html = self.FIXTURE.read_text()
        pt = parse_rankings(html)

        # At least one row should have a 3-letter country code (HUN, GER, etc.)
        countries = {r.fencer_country for r in pt.results if r.fencer_country}
        assert any(len(c) == 3 and c.isupper() for c in countries), (
            f"expected at least one 3-letter ISO code, got {countries}"
        )

    def test_parse_rankings_metadata_unknown_at_this_layer(self):
        """dartagnan_ir.4: weapon/gender/category_hint are None — parser only sees the rankings page.

        The orchestrator scrapes the event index separately to learn weapon/gender/category
        per competition, then injects them. The rankings parser is pure on the rankings HTML.
        """
        from python.scrapers.dartagnan import parse_rankings

        html = self.FIXTURE.read_text()
        pt = parse_rankings(html)

        assert pt.weapon is None
        assert pt.gender is None
        assert pt.category_hint is None

    def test_parse_rankings_empty_table_returns_empty_results(self):
        """dartagnan_ir.5: rankings page with no rows returns ParsedTournament with empty results, no exception."""
        from python.scrapers.dartagnan import parse_rankings

        html = self.EMPTY_FIXTURE.read_text()
        pt = parse_rankings(html)

        assert pt.results == []
        assert pt.raw_pool_size == 0


# =============================================================================
# EVF API — api.veteransfencing.eu /results/{comp_id}
# =============================================================================
class TestEvfApiIRContract:
    """EVF parse_results: pure function on raw API response data, no I/O."""

    SAMPLE_DATA = [
        {
            "fencer_surname": "KOWAL", "fencer_firstname": "Anna",
            "country_abbr": "POL", "place": 1,
            "fencer_dob": "1980-05-12", "total_points": 158.6,
            "weapon_abbr": "WE",
        },
        {
            "fencer_surname": "STEINER", "fencer_firstname": "Eva",
            "country_abbr": "GER", "place": 2,
            "fencer_dob": "1975-11-03", "total_points": 145.0,
            "weapon_abbr": "WE",
        },
        {
            "fencer_surname": "NOWAK", "fencer_firstname": "Beata",
            "country_abbr": "POL", "place": 3,
            "fencer_dob": "", "total_points": 130.5,  # missing DOB
            "weapon_abbr": "WE",
        },
    ]

    def test_parse_results_returns_parsed_tournament(self):
        """evf_ir.1: parse_results returns ParsedTournament source_kind=EVF_API."""
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.scrapers.evf_results import parse_results

        pt = parse_results(self.SAMPLE_DATA)

        assert isinstance(pt, ParsedTournament)
        assert pt.source_kind == SourceKind.EVF_API
        assert len(pt.results) == 3
        assert pt.raw_pool_size == 3

    def test_parse_results_metadata_passthrough(self):
        """evf_ir.2: weapon, gender, category_hint, parsed_date passed in by orchestrator land in IR."""
        import datetime
        from python.scrapers.evf_results import parse_results

        pt = parse_results(
            self.SAMPLE_DATA,
            weapon="EPEE", gender="F",
            category_hint="V2",
            parsed_date=datetime.date(2026, 4, 18),
            source_url="https://api.veteransfencing.eu/fe/results/301",
        )
        assert pt.weapon == "EPEE"
        assert pt.gender == "F"
        assert pt.category_hint == "V2"
        assert pt.parsed_date == datetime.date(2026, 4, 18)
        assert pt.source_url == "https://api.veteransfencing.eu/fe/results/301"

    def test_parse_results_birth_date_from_dob(self):
        """evf_ir.3: fencer_dob ISO string -> birth_date datetime.date; missing -> None."""
        import datetime
        from python.scrapers.evf_results import parse_results

        pt = parse_results(self.SAMPLE_DATA)

        kowal = next(r for r in pt.results if r.fencer_name.startswith("KOWAL"))
        assert kowal.birth_date == datetime.date(1980, 5, 12)
        assert kowal.birth_year == 1980

        nowak = next(r for r in pt.results if r.fencer_name.startswith("NOWAK"))
        assert nowak.birth_date is None
        assert nowak.birth_year is None

    def test_parse_results_synthetic_id(self):
        """evf_ir.4: EVF result rows have no native per-row ID — uses synthetic format."""
        from python.scrapers.evf_results import parse_results

        pt = parse_results(self.SAMPLE_DATA)

        first = pt.results[0]
        assert first.source_row_id.startswith("evf_api:row1:place1:")
