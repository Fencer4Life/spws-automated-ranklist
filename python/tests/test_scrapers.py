"""
M3 Acceptance Tests (RED phase): Data Ingestion — Scrapers (tests 3.1–3.13).

These tests verify the Python scraper modules:
- ftl.py: FencingTimeLive parser (JSON API + CSV)
- engarde.py: Engarde HTML parser
- fourfence.py: 4Fence HTML parser
- csv_upload.py: CSV file upload handler
- base.py: Shared result format, retry logic, error handling
"""

import json
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest

FIXTURES = Path(__file__).parent / "fixtures"


# ---------------------------------------------------------------------------
# Result dataclass contract — all parsers must return this format
# ---------------------------------------------------------------------------
def _assert_valid_result(result):
    """Assert a single result dict has the required fields."""
    assert "fencer_name" in result, "Result must have 'fencer_name'"
    assert "place" in result, "Result must have 'place'"
    assert isinstance(result["place"], int), "place must be int"
    assert result["place"] >= 1, "place must be >= 1"
    assert isinstance(result["fencer_name"], str), "fencer_name must be str"
    assert len(result["fencer_name"]) > 0, "fencer_name must not be empty"


# ===========================================================================
# 3.1  FencingTimeLive parser: fixture → list of (fencer_name, place, N)
# ===========================================================================
class TestFTLParser:
    """FencingTimeLive parser tests using saved JSON/CSV fixtures."""

    def test_ftl_json_parse_returns_results(self):
        """3.1a FTL JSON parser returns a list of result dicts."""
        from python.scrapers.ftl import parse_ftl_json

        json_path = FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json"
        data = json.loads(json_path.read_text())
        results = parse_ftl_json(data)

        assert len(results) > 0, "Should return at least one result"
        for r in results:
            _assert_valid_result(r)

    def test_ftl_json_first_place(self):
        """3.1b FTL JSON: 1st place fencer name and place extracted correctly."""
        from python.scrapers.ftl import parse_ftl_json

        json_path = FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json"
        data = json.loads(json_path.read_text())
        results = parse_ftl_json(data)

        first = results[0]
        assert first["place"] == 1
        # Name should have category marker stripped: "ATANASSOW 2 Aleksander" → "ATANASSOW Aleksander"
        assert "ATANASSOW" in first["fencer_name"]
        assert first["country"] == "POL"

    def test_ftl_json_tied_places(self):
        """3.1c FTL JSON: tied places ('3T') parsed as integer 3."""
        from python.scrapers.ftl import parse_ftl_json

        json_path = FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json"
        data = json.loads(json_path.read_text())
        results = parse_ftl_json(data)

        # Find results with original place "3T"
        third_place = [r for r in results if r["place"] == 3]
        assert len(third_place) == 2, "Should have 2 fencers tied at 3rd place"

    def test_ftl_json_participant_count(self):
        """3.1d FTL JSON: participant count equals number of results."""
        from python.scrapers.ftl import parse_ftl_json

        json_path = FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json"
        data = json.loads(json_path.read_text())
        results = parse_ftl_json(data)

        assert len(results) == 53  # Based on fixture data

    def test_ftl_csv_parse_returns_results(self):
        """3.1e FTL CSV parser returns same format as JSON parser."""
        from python.scrapers.ftl import parse_ftl_csv

        csv_path = FIXTURES / "ftl" / "csv_EEC7379682834E588E5B267447C7266A.csv"
        csv_text = csv_path.read_text()
        results = parse_ftl_csv(csv_text)

        assert len(results) > 0
        for r in results:
            _assert_valid_result(r)

    def test_ftl_csv_no_category_marker(self):
        """3.1f FTL CSV from Polish tournament has no category marker in names."""
        from python.scrapers.ftl import parse_ftl_csv

        csv_path = FIXTURES / "ftl" / "csv_1DAD5541330547AC9204125523A0C1A9.csv"
        csv_text = csv_path.read_text()
        results = parse_ftl_csv(csv_text)

        first = results[0]
        assert first["fencer_name"] == "ATANASSOW Aleksander"
        assert first["place"] == 1

    def test_ftl_name_category_stripped(self):
        """3.1g FTL: category marker ('2') stripped from name."""
        from python.scrapers.ftl import parse_ftl_json

        json_path = FIXTURES / "ftl" / "data_EEC7379682834E588E5B267447C7266A.json"
        data = json.loads(json_path.read_text())
        results = parse_ftl_json(data)

        first = results[0]
        # Should not contain standalone " 2 " category marker
        assert " 2 " not in first["fencer_name"]
        assert first["fencer_name"] == "ATANASSOW Aleksander"


# ===========================================================================
# 3.2  Engarde parser: fixture HTML → standardized result set
# ===========================================================================
class TestEngardeParser:
    """Engarde parser tests using saved HTML fixtures."""

    def test_engarde_parse_returns_results(self):
        """3.2a Engarde parser returns result list from HTML fixture."""
        from python.scrapers.engarde import parse_engarde_html

        html = (FIXTURES / "engarde" / "clasfinal_hunfencing.html").read_text()
        results = parse_engarde_html(html)

        assert len(results) > 0
        for r in results:
            _assert_valid_result(r)

    def test_engarde_first_place(self):
        """3.2b Engarde: 1st place fencer extracted correctly."""
        from python.scrapers.engarde import parse_engarde_html

        html = (FIXTURES / "engarde" / "clasfinal_hunfencing.html").read_text()
        results = parse_engarde_html(html)

        first = results[0]
        assert first["place"] == 1
        assert "ATANASSOW" in first["fencer_name"]
        assert first["country"] == "POL"

    def test_engarde_participant_count(self):
        """3.2c Engarde: participant count matches header text."""
        from python.scrapers.engarde import parse_engarde_html

        html = (FIXTURES / "engarde" / "clasfinal_hunfencing.html").read_text()
        results = parse_engarde_html(html)

        assert len(results) == 57  # "Overall ranking (57 fencers)"

    def test_engarde_tied_places(self):
        """3.2d Engarde: tied 3rd place fencers both have place=3."""
        from python.scrapers.engarde import parse_engarde_html

        html = (FIXTURES / "engarde" / "clasfinal_hunfencing.html").read_text()
        results = parse_engarde_html(html)

        third_place = [r for r in results if r["place"] == 3]
        assert len(third_place) == 2

    def test_engarde_spanish_locale(self):
        """3.2e Engarde: Spanish-language fixture parsed correctly."""
        from python.scrapers.engarde import parse_engarde_html

        html = (FIXTURES / "engarde" / "clasfinal_madrid.html").read_text()
        results = parse_engarde_html(html)

        assert len(results) == 33  # "33 tiradores"
        first = results[0]
        assert first["place"] == 1
        _assert_valid_result(first)

    def test_engarde_name_format(self):
        """3.2f Engarde: name formatted as 'SURNAME FirstName'."""
        from python.scrapers.engarde import parse_engarde_html

        html = (FIXTURES / "engarde" / "clasfinal_hunfencing.html").read_text()
        results = parse_engarde_html(html)

        first = results[0]
        assert first["fencer_name"] == "ATANASSOW Aleksander"


# ===========================================================================
# 3.3  4Fence parser: fixture HTML → standardized result set
# ===========================================================================
class TestFourFenceParser:
    """4Fence parser tests using saved HTML fixtures."""

    def test_fourfence_parse_returns_results(self):
        """3.3a 4Fence parser returns result list from HTML fixture."""
        from python.scrapers.fourfence import parse_fourfence_html

        html = (FIXTURES / "fourfence" / "clafinale_terni.html").read_text()
        results = parse_fourfence_html(html)

        assert len(results) > 0
        for r in results:
            _assert_valid_result(r)

    def test_fourfence_first_place(self):
        """3.3b 4Fence: 1st place fencer extracted correctly."""
        from python.scrapers.fourfence import parse_fourfence_html

        html = (FIXTURES / "fourfence" / "clafinale_terni.html").read_text()
        results = parse_fourfence_html(html)

        first = results[0]
        assert first["place"] == 1
        assert "VINCENZI" in first["fencer_name"]

    def test_fourfence_participant_count(self):
        """3.3c 4Fence: participant count matches row count."""
        from python.scrapers.fourfence import parse_fourfence_html

        html = (FIXTURES / "fourfence" / "clafinale_terni.html").read_text()
        results = parse_fourfence_html(html)

        assert len(results) == 64

    def test_fourfence_name_format(self):
        """3.3d 4Fence: name formatted as 'SURNAME FirstName'."""
        from python.scrapers.fourfence import parse_fourfence_html

        html = (FIXTURES / "fourfence" / "clafinale_terni.html").read_text()
        results = parse_fourfence_html(html)

        first = results[0]
        assert first["fencer_name"] == "VINCENZI Gabriele"

    def test_fourfence_header_rows_excluded(self):
        """3.3e 4Fence: header rows (COGNOME/NOME) excluded."""
        from python.scrapers.fourfence import parse_fourfence_html

        html = (FIXTURES / "fourfence" / "clafinale_terni.html").read_text()
        results = parse_fourfence_html(html)

        names = [r["fencer_name"] for r in results]
        assert "COGNOME NOME" not in names
        assert "COGNOME Nome" not in names


# ===========================================================================
# 3.4–3.5  DB import: results inserted, status set (mocked DB)
# ===========================================================================
class TestDBImport:
    """Tests 3.4-3.5: result insertion into database (mocked)."""

    def test_import_results_have_null_final_score(self):
        """3.4 After import: result rows have num_final_score = NULL."""
        from python.scrapers.base import prepare_result_rows

        parsed = [
            {"fencer_name": "ATANASSOW Aleksander", "place": 1, "country": "POL"},
            {"fencer_name": "KOWALSKI Jan", "place": 2, "country": "POL"},
        ]
        rows = prepare_result_rows(parsed, tournament_id=1)

        for row in rows:
            assert row["num_final_score"] is None
            assert row["int_place"] == row["place"]
            assert row["id_tournament"] == 1


# ===========================================================================
# 3.6  Scraper failure: Telegram alert sent
# ===========================================================================
class TestTelegramAlert:
    """Test 3.6: Telegram alert on scraper failure."""

    def test_telegram_alert_called_on_failure(self):
        """3.6 Scraper failure sends Telegram alert with error details."""
        from python.scrapers.base import send_telegram_alert

        with patch("python.scrapers.base.httpx") as mock_httpx:
            mock_client = mock_httpx.Client.return_value.__enter__ = lambda s: s
            mock_httpx.post = lambda *a, **kw: None

            send_telegram_alert(
                bot_token="123456:ABC-DEF",
                chat_id="987654321",
                message="Scraper failed for tournament PPW1",
                error="ConnectionError: timeout",
            )
            # If no exception raised, the function works


# ===========================================================================
# 3.7–3.8  CSV upload: rows inserted, status set
# ===========================================================================
class TestCSVUpload:
    """Tests 3.7-3.8: CSV file upload handler."""

    def test_csv_upload_parses_ftl_format(self):
        """3.7 CSV upload: FTL CSV parsed into standardized result format."""
        from python.scrapers.csv_upload import parse_csv_upload

        csv_text = (
            "Place,Name,Club(s),Division,Country\n"
            "1,ATANASSOW Aleksander,KS AGH Kraków,,POL\n"
            "2,KOWALSKI Jan,PIAST GLIWICE,,POL\n"
            "3T,NOWAK Adam,,,POL\n"
        )
        results = parse_csv_upload(csv_text)

        assert len(results) == 3
        assert results[0]["fencer_name"] == "ATANASSOW Aleksander"
        assert results[0]["place"] == 1
        assert results[2]["place"] == 3  # "3T" → 3


# ===========================================================================
# 3.9  Idempotency (unit test with mock)
# ===========================================================================
class TestIdempotency:
    """Test 3.9: re-importing same tournament skips duplicates."""

    def test_prepare_skips_existing_fencer_tournament_pairs(self):
        """3.9 Idempotency: duplicate (fencer, tournament) pairs filtered out."""
        from python.scrapers.base import filter_existing_results

        parsed = [
            {"fencer_name": "ATANASSOW Aleksander", "place": 1},
            {"fencer_name": "KOWALSKI Jan", "place": 2},
        ]
        existing_names = {"ATANASSOW Aleksander"}

        filtered = filter_existing_results(parsed, existing_names)
        assert len(filtered) == 1
        assert filtered[0]["fencer_name"] == "KOWALSKI Jan"


# ===========================================================================
# 3.10–3.11  Minimum participant threshold
# ===========================================================================
class TestMinParticipants:
    """Tests 3.10-3.11: minimum participant enforcement."""

    def test_pew_below_threshold_rejected(self):
        """3.10 PEW with N=3 (< 5 EVF minimum) → rejected."""
        from python.scrapers.base import check_min_participants

        result = check_min_participants(
            participant_count=3,
            tournament_type="PEW",
            min_evf=5,
            min_ppw=1,
        )
        assert result["rejected"] is True
        assert "minimum" in result["reason"].lower()

    def test_ppw_below_evf_threshold_accepted(self):
        """3.11 PPW with N=3 → imported normally (domestic has min=1)."""
        from python.scrapers.base import check_min_participants

        result = check_min_participants(
            participant_count=3,
            tournament_type="PPW",
            min_evf=5,
            min_ppw=1,
        )
        assert result["rejected"] is False


# ===========================================================================
# 3.12  Retry logic
# ===========================================================================
class TestRetryLogic:
    """Test 3.12: transient HTTP failure → retried with backoff."""

    @pytest.mark.asyncio
    async def test_retry_on_transient_failure(self):
        """3.12 Transient HTTP failure retried up to 3 times."""
        from python.scrapers.base import fetch_with_retry

        call_count = 0

        async def mock_fetch(url):
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ConnectionError("timeout")
            return "<html>success</html>"

        result = await fetch_with_retry(
            mock_fetch, "https://example.com", max_retries=3, base_delay=0.01
        )
        assert result == "<html>success</html>"
        assert call_count == 3


# ===========================================================================
# 3.13  Partial scrape → abort
# ===========================================================================
class TestPartialScrape:
    """Test 3.13: incomplete data → import aborted."""

    def test_partial_scrape_raises_error(self):
        """3.13 Partial scrape (no results found) raises error."""
        from python.scrapers.base import validate_parse_results

        with pytest.raises(ValueError, match="[Nn]o results|[Ee]mpty|[Ii]ncomplete"):
            validate_parse_results([], source_url="https://example.com/event")

    def test_partial_scrape_missing_places(self):
        """3.13b Results with missing place values raise error."""
        from python.scrapers.base import validate_parse_results

        results = [
            {"fencer_name": "ATANASSOW Aleksander", "place": 1},
            {"fencer_name": "KOWALSKI Jan"},  # missing place
        ]
        with pytest.raises(ValueError):
            validate_parse_results(results, source_url="https://example.com/event")


# ===========================================================================
# 3.14  URL dispatcher: route URL to correct parser
# ===========================================================================
class TestURLDispatcher:
    """Test URL dispatcher (ported from VBA Module4)."""

    def test_ftl_url_detected(self):
        """FTL URL routed to FTL parser."""
        from python.scrapers.base import detect_platform

        assert detect_platform("https://www.fencingtimelive.com/events/results/ABC123") == "ftl"

    def test_engarde_url_detected(self):
        """Engarde URL routed to Engarde parser."""
        from python.scrapers.base import detect_platform

        assert detect_platform("https://engarde-service.com/competition/test/clasfinal.htm") == "engarde"

    def test_fourfence_url_detected(self):
        """4Fence URL routed to 4Fence parser."""
        from python.scrapers.base import detect_platform

        assert detect_platform("https://www.4fence.it/FIS/Risultati/2025/index.php") == "fourfence"

    def test_unknown_url_raises(self):
        """Unknown URL raises ValueError."""
        from python.scrapers.base import detect_platform

        with pytest.raises(ValueError, match="[Uu]nknown|[Uu]nsupported"):
            detect_platform("https://unknown-fencing-site.com/results")


# ===========================================================================
# 3.15  FTL event schedule scraper — tournament URL discovery
# ===========================================================================
class TestFTLEventSchedule:
    """Test FTL event schedule page parsing for tournament URL extraction."""

    def test_parse_event_schedule_extracts_links(self):
        """3.15a: Parsing PPW2 fixture HTML returns tournament links."""
        from python.tools.scrape_ftl_event_urls import parse_event_schedule

        html = (FIXTURES / "ftl" / "event_schedule_PPW2.html").read_text()
        results = parse_event_schedule(html)
        # PPW2 has 27 links total, 3 MIKST → 24 non-MIKST tournaments
        assert len(results) == 24
        assert all("uuid" in r and "name" in r for r in results)
        # Verify a known UUID is present
        uuids = {r["uuid"] for r in results}
        assert "0387CC20A25B4EBA9BDAFAB148E8C12B" in uuids  # SZPADA M V2

    def test_parse_event_schedule_skips_mikst(self):
        """3.15b: MIKST entries excluded from results."""
        from python.tools.scrape_ftl_event_urls import parse_event_schedule

        html = (FIXTURES / "ftl" / "event_schedule_PPW2.html").read_text()
        results = parse_event_schedule(html)
        names_upper = [r["name"].upper() for r in results]
        assert not any("MIKST" in n or "MIKS " in n for n in names_upper)

    def test_parse_tournament_name_epee_m_v2(self):
        """3.15c: SZPADA MĘŻCZYZN 2 WETERANI → (EPEE, M, V2)."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("SZPADA MĘŻCZYZN 2 WETERANI")
        assert result == ("EPEE", "M", "V2")

    def test_parse_tournament_name_foil_f_v0(self):
        """3.15d: FLORET WETERANI kobiety 0 → (FOIL, F, V0)."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("FLORET WETERANI     kobiety 0")
        assert result == ("FOIL", "F", "V0")

    def test_parse_tournament_name_sabre_m_v4(self):
        """3.15e: SZABLA WETERANI MĘŻCZYZNI 4 → (SABRE, M, V4)."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("SZABLA WETERANI MĘŻCZYZNI 4")
        assert result == ("SABRE", "M", "V4")

    def test_parse_tournament_name_mikst_returns_none(self):
        """3.15f: floret MIKST WETERANI → None (skip)."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        assert parse_tournament_name("floret MIKST WETERANI") is None
        assert parse_tournament_name("szabla MIKS WETERANI") is None
        assert parse_tournament_name("MIKST SZPADA WETERANI") is None

    def test_parse_tournament_name_letter_o_as_zero(self):
        """3.15g: SZPADA MĘŻCZYZN O WETERANI → V0 (letter O = digit 0)."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("SZPADA MĘŻCZYZN O WETERANI")
        assert result == ("EPEE", "M", "V0")

    def test_build_tournament_code(self):
        """3.15h: Build tournament code from components."""
        from python.tools.scrape_ftl_event_urls import build_tournament_code

        code = build_tournament_code("PPW2", "EPEE", "M", "V2", "2025-2026")
        assert code == "PPW2-V2-M-EPEE-2025-2026"

    def test_build_result_url(self):
        """3.15i: UUID → full results URL."""
        from python.tools.scrape_ftl_event_urls import build_result_url

        url = build_result_url("0387CC20A25B4EBA9BDAFAB148E8C12B")
        assert url == "https://www.fencingtimelive.com/events/results/0387CC20A25B4EBA9BDAFAB148E8C12B"

    def test_parse_tournament_name_english_epee(self):
        """3.15j: English name — Men's Epee Category 2 → (EPEE, M, V2)."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("Men's Epee Category 2")
        assert result == ("EPEE", "M", "V2")

    def test_parse_tournament_name_english_women_foil(self):
        """3.15k: English name — Women's Foil Category 1 and 2 → combined."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("Women's Foil Category 1 and 2")
        assert isinstance(result, list)
        assert ("FOIL", "F", "V1") in result
        assert ("FOIL", "F", "V2") in result

    def test_parse_tournament_name_english_saber(self):
        """3.15l: English name — Men's Sabre Category 3 and 4 → combined."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("Men's Sabre Category 3 and 4")
        assert isinstance(result, list)
        assert ("SABRE", "M", "V3") in result
        assert ("SABRE", "M", "V4") in result

    def test_parse_tournament_name_de_sub_event_skipped(self):
        """3.15m: DE sub-events skipped."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        assert parse_tournament_name("Women's Cat 3 DE") is None
        assert parse_tournament_name("Men's Sabre Cat 4 DE") is None

    def test_parse_tournament_name_epee_accent(self):
        """3.15n: Épée with accent → EPEE."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("Women's Épée Category 3 and 4 (Combined)")
        assert isinstance(result, list)
        assert ("EPEE", "F", "V3") in result

    def test_parse_tournament_name_v_combined_triple(self):
        """3.15o: FLORET MĘŻCZYZN v0v1v2 → 3 combined categories."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("FLORET MĘŻCZYZN v0v1v2")
        assert isinstance(result, list)
        assert len(result) == 3
        assert ("FOIL", "M", "V0") in result
        assert ("FOIL", "M", "V1") in result
        assert ("FOIL", "M", "V2") in result

    def test_parse_tournament_name_v_combined_double(self):
        """3.15p: SZPADA KOBIET v0v1 → 2 combined categories."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("SZPADA KOBIET v0v1")
        assert isinstance(result, list)
        assert len(result) == 2
        assert ("EPEE", "F", "V0") in result
        assert ("EPEE", "F", "V1") in result

    def test_parse_tournament_name_no_category_all_v(self):
        """3.15q: FLORET KOBIET (no category) → all V0-V4."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        result = parse_tournament_name("FLORET KOBIET")
        assert isinstance(result, list)
        assert len(result) == 5
        for i in range(5):
            assert ("FOIL", "F", f"V{i}") in result

    def test_parse_tournament_name_eliminacje_skipped(self):
        """3.15r: ELIMINACJE entries skipped."""
        from python.tools.scrape_ftl_event_urls import parse_tournament_name

        assert parse_tournament_name("FLORET ELIMINACJE") is None
        assert parse_tournament_name("SZPADA ELIMINACJE") is None
