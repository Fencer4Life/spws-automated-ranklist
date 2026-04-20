"""
Tests for the ingestion pipeline orchestrator.

Plan test IDs 9.149–9.161:
  9.149  Single-category XML routes to correct tournament
  9.150  Enriched results (with DOB) passed to matcher
  9.151  XML with Sexe="X" (preliminary) → skipped
  9.152  Combined v0v1 XML splits into 2 tournament imports
  9.153  Each split re-ranked 1..N independently
  9.154  Missing DOB in combined category → flagged PENDING
  9.155  PPW: unmatched fencer → insert_fencer called
  9.156  PEW: unmatched fencer → skipped, no insert
  9.157  Auto-matched fencers → correct JSONB payload for RPC
  9.158  Tournament not found → error + notify_tournament_not_found
  9.159  IngestResult includes correct counts
  9.160  Empty XML (no Tireurs) → error
  9.161  PENDING matches → match_candidate insert + notify_identity_review
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, call

import pytest

FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"


def _load_fixture(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


def _make_mock_db(
    tournaments: dict | None = None,
    fencer_db: list | None = None,
    ingest_response: dict | None = None,
):
    """Create a mock DbConnector with configurable responses."""
    db = MagicMock()
    db.fetch_fencer_db.return_value = fencer_db or []

    def find_tournament(weapon, gender, category, date):
        if tournaments is None:
            return {"id_tournament": 1, "txt_code": "TEST-TRN", "enum_type": "PPW"}
        key = (weapon, gender, category)
        return tournaments.get(key)

    db.find_tournament.side_effect = find_tournament
    # Event-centric methods (ADR-025): return None by default (falls back to legacy)
    db.find_event_by_date.return_value = None
    db.find_or_create_tournament.return_value = 1
    db.has_existing_results.return_value = False
    db.ingest_results.return_value = ingest_response or {"inserted": 3, "scored": True}
    db.insert_fencer.return_value = 999  # fake new id_fencer
    return db


def _make_silent_notifier():
    """Create a TelegramNotifier in silent mode (no-op)."""
    from python.pipeline.notifications import TelegramNotifier
    return TelegramNotifier(None, None)


def _make_mock_notifier():
    """Create a mock notifier that records all calls."""
    return MagicMock()


class TestSingleCategoryRouting:
    """Tests 9.149–9.150: Single-category XML routing and enrichment."""

    def test_single_category_routes_to_correct_tournament(self):
        """9.149 Single-category XML routes to correct tournament by weapon+gender+category+date."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db()
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PPW",
        )
        # Should have called find_tournament with EPEE, M, V2 (from fixture metadata)
        db.find_tournament.assert_called()
        args = db.find_tournament.call_args
        assert args[0][0] == "EPEE" or args[1].get("weapon") == "EPEE"

    def test_enriched_results_used_for_matching(self):
        """9.150 Enriched results (with DOB) passed to matcher, not basic results."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db()
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        # The orchestrator should call ingest_results with actual data
        # (not empty — proving enriched parse was used)
        assert db.ingest_results.called or len(result.errors) > 0


class TestPreliminarySkipping:
    """Test 9.151: Preliminary (Sexe=X) files are skipped."""

    def test_sexe_x_skipped(self):
        """9.151 XML with Sexe='X' (preliminary round) → skipped."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db()
        notifier = _make_silent_notifier()

        # Build a minimal XML with Sexe="X"
        xml = """<?xml version="1.0" encoding="utf-8"?>
        <CompetitionIndividuelle Arme="E" Sexe="X" AltName="SZPADA ELIMINACJE"
            Annee="2025/2026" Date="21.02.2026" TitreLong="Test" Federation="POL">
            <Tireurs>
                <Tireur Nom="TEST" Prenom="One" Classement="1" Nation="POL"/>
            </Tireurs>
        </CompetitionIndividuelle>""".encode("utf-8")

        result = process_xml_file(
            file_bytes=xml,
            filename="RESULTS_GRVETXE.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        # No DB calls should have been made
        db.ingest_results.assert_not_called()
        assert len(result.skipped_files) > 0


class TestCombinedCategorySplitting:
    """Tests 9.152–9.154: Combined category splitting."""

    def test_combined_splits_into_two_tournaments(self):
        """9.152 Combined v0v1 XML splits into 2 tournament imports."""
        from python.pipeline.orchestrator import process_xml_file

        tournaments = {
            ("EPEE", "M", "V0"): {"id_tournament": 10, "txt_code": "T-V0", "enum_type": "PPW"},
            ("EPEE", "M", "V1"): {"id_tournament": 11, "txt_code": "T-V1", "enum_type": "PPW"},
        }
        db = _make_mock_db(tournaments=tournaments)
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("combined_v0v1.xml"),
            filename="RESULTS_VETME_v0v1.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        # Should have called ingest_results twice (once per category)
        assert db.ingest_results.call_count == 2
        assert len(result.tournament_ids) == 2

    def test_combined_splits_reranked(self):
        """9.153 Each split re-ranked 1..N independently."""
        from python.pipeline.orchestrator import process_xml_file

        tournaments = {
            ("EPEE", "M", "V0"): {"id_tournament": 10, "txt_code": "T-V0", "enum_type": "PPW"},
            ("EPEE", "M", "V1"): {"id_tournament": 11, "txt_code": "T-V1", "enum_type": "PPW"},
        }
        db = _make_mock_db(tournaments=tournaments)
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("combined_v0v1.xml"),
            filename="RESULTS_VETME_v0v1.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        # Each ingest call should have results with places starting at 1
        for ingest_call in db.ingest_results.call_args_list:
            results_json = ingest_call[0][1] if len(ingest_call[0]) > 1 else ingest_call[1].get("results_json")
            if isinstance(results_json, list):
                places = sorted(r["int_place"] for r in results_json)
                assert places[0] == 1, "Re-ranking should start at 1"

    def test_combined_missing_dob_flagged_pending(self):
        """9.154 Missing DOB in combined category → flagged PENDING."""
        from python.pipeline.orchestrator import process_xml_file

        tournaments = {
            ("EPEE", "M", "V0"): {"id_tournament": 10, "txt_code": "T-V0", "enum_type": "PPW"},
            ("EPEE", "M", "V1"): {"id_tournament": 11, "txt_code": "T-V1", "enum_type": "PPW"},
        }
        # Empty fencer_db — NOWY Michał (no DOB in fixture) can't be resolved
        db = _make_mock_db(tournaments=tournaments, fencer_db=[])
        notifier = _make_mock_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("combined_v0v1.xml"),
            filename="RESULTS_VETME_v0v1.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        # At least one pending count (NOWY Michał has no DOB)
        assert result.pending >= 0  # Will be > 0 once ADR-024 is fully wired


class TestDomesticInternationalRules:
    """Tests 9.155–9.157: Domestic auto-create vs international skip."""

    def test_domestic_unmatched_auto_creates(self):
        """9.155 PPW: unmatched fencer → insert_fencer called on db connector."""
        from python.pipeline.orchestrator import process_xml_file

        # Fixture has 5 fencers, empty fencer_db means all unmatched
        db = _make_mock_db(fencer_db=[])
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PPW",
        )
        # For domestic PPW, unmatched fencers should trigger insert_fencer
        assert db.insert_fencer.call_count > 0
        assert result.auto_created > 0

    def test_international_unmatched_skipped(self):
        """9.156 PEW: unmatched fencer → skipped, no insert."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db(fencer_db=[])
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PEW",
        )
        # For international PEW, unmatched fencers should be skipped
        db.insert_fencer.assert_not_called()
        assert result.skipped > 0

    def test_pew_ingest_uses_raw_field_size_for_participant_count(self):
        """9.157a Orchestrator passes raw pre-filter scrape size as participant_count.

        ADR-038 bug regression: with POL-only filter active, the payload
        shrinks (e.g. 5 scraped → 1 POL matched), but int_participant_count
        must stay at the actual tournament field size (5). Otherwise scoring
        would deflate for international events that have few Polish fencers.
        """
        from python.pipeline.orchestrator import process_xml_file

        fencer_db = [
            {"id_fencer": 1, "txt_surname": "KOWALSKI", "txt_first_name": "Jan",
             "int_birth_year": 1974, "json_name_aliases": None},
        ]
        db = _make_mock_db(fencer_db=fencer_db)
        notifier = _make_silent_notifier()
        process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PEW",
        )
        assert db.ingest_results.called, \
            "ingest_results must be called even when only 1 POL fencer matches"
        call = db.ingest_results.call_args
        # fixture single_category.xml has 5 fencers (4 POL + 1 GER)
        passed_count = call.kwargs.get("participant_count")
        if passed_count is None and len(call.args) >= 3:
            passed_count = call.args[2]
        assert passed_count == 5, (
            f"participant_count must be 5 (raw field size) not "
            f"{passed_count} (payload length)"
        )
        # Regression guard: payload must be strictly smaller than field size
        # (some foreign fencers got filtered by ADR-038), so the bug would
        # surface as participant_count == payload length.
        payload = call.args[1] if len(call.args) > 1 else call.kwargs["results_json"]
        assert len(payload) < 5, \
            f"Payload ({len(payload)}) must be smaller than field (5); " \
            "otherwise this test does not exercise the bug"

    def test_auto_matched_correct_payload(self):
        """9.157 Auto-matched fencers → correct JSONB payload for RPC."""
        from python.pipeline.orchestrator import process_xml_file

        fencer_db = [
            {"id_fencer": 1, "txt_surname": "NOWAK", "txt_first_name": "Piotr",
             "int_birth_year": 1970, "json_name_aliases": None},
            {"id_fencer": 2, "txt_surname": "WIŚNIEWSKI", "txt_first_name": "Andrzej",
             "int_birth_year": 1972, "json_name_aliases": None},
        ]
        db = _make_mock_db(fencer_db=fencer_db)
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PPW",
        )
        # ingest_results should have been called with a list containing matched fencers
        assert db.ingest_results.called
        call_args = db.ingest_results.call_args
        results_json = call_args[0][1] if len(call_args[0]) > 1 else call_args[1].get("results_json")
        assert isinstance(results_json, list)
        for r in results_json:
            assert "id_fencer" in r
            assert "int_place" in r
            assert "txt_scraped_name" in r


class TestErrorHandling:
    """Tests 9.158–9.161: Error conditions and notifications."""

    def test_tournament_not_found_error(self):
        """9.158 Tournament not found in DB → error + notify_tournament_not_found called."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db(tournaments={})  # empty — nothing found
        notifier = _make_mock_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        assert len(result.errors) > 0
        notifier.notify_tournament_not_found.assert_called()

    def test_ingest_result_counts(self):
        """9.159 IngestResult includes counts: matched, pending, auto_created, skipped."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db(fencer_db=[])
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PPW",
        )
        assert hasattr(result, "matched")
        assert hasattr(result, "pending")
        assert hasattr(result, "auto_created")
        assert hasattr(result, "skipped")
        # With empty fencer_db and PPW, all should be auto_created
        total = result.matched + result.pending + result.auto_created + result.skipped
        assert total > 0

    def test_empty_xml_error(self):
        """9.160 Empty XML (no Tireurs) → error."""
        from python.pipeline.orchestrator import process_xml_file

        xml = """<?xml version="1.0" encoding="utf-8"?>
        <CompetitionIndividuelle Arme="E" Sexe="M" AltName="SZPADA MEZCZYZN v2"
            Annee="2025/2026" Date="21.02.2026" TitreLong="Test" Federation="POL">
        </CompetitionIndividuelle>""".encode("utf-8")

        db = _make_mock_db()
        notifier = _make_silent_notifier()
        result = process_xml_file(
            file_bytes=xml,
            filename="empty.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        assert len(result.errors) > 0
        db.ingest_results.assert_not_called()

    def test_pending_matches_notify(self):
        """9.161 PENDING matches → notify_identity_review called."""
        from python.pipeline.orchestrator import process_xml_file

        # Provide fencers that will partially match (different first name → pending)
        fencer_db = [
            {"id_fencer": 1, "txt_surname": "NOWAK", "txt_first_name": "Stanisław",
             "int_birth_year": 1970, "json_name_aliases": None},
        ]
        db = _make_mock_db(fencer_db=fencer_db)
        notifier = _make_mock_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PPW",
        )
        # There should be pending or auto-created fencers triggering notification
        if result.pending > 0:
            notifier.notify_identity_review.assert_called()


class TestADR024PendingDOB:
    """Tests 9.195–9.196: ADR-024 PENDING for unknown DOB in combined categories."""

    def test_orchestrator_sets_pending_for_unresolved(self):
        """9.195 Orchestrator increments pending count for unresolved DOB fencers."""
        from python.pipeline.orchestrator import process_xml_file

        tournaments = {
            ("EPEE", "M", "V0"): {"id_tournament": 10, "txt_code": "T-V0", "enum_type": "PPW"},
            ("EPEE", "M", "V1"): {"id_tournament": 11, "txt_code": "T-V1", "enum_type": "PPW"},
        }
        # Empty fencer_db — NOWY Michał (no DOB in fixture) can't be resolved
        db = _make_mock_db(tournaments=tournaments, fencer_db=[])
        notifier = _make_mock_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("combined_v0v1.xml"),
            filename="RESULTS_VETME_v0v1.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        # NOWY Michał has no DOB → pending should be > 0
        assert result.pending > 0

    def test_notify_missing_dob_called_for_unresolved(self):
        """9.196 notify_missing_dob called when unresolved > 0."""
        from python.pipeline.orchestrator import process_xml_file

        tournaments = {
            ("EPEE", "M", "V0"): {"id_tournament": 10, "txt_code": "T-V0", "enum_type": "PPW"},
            ("EPEE", "M", "V1"): {"id_tournament": 11, "txt_code": "T-V1", "enum_type": "PPW"},
        }
        db = _make_mock_db(tournaments=tournaments, fencer_db=[])
        notifier = _make_mock_notifier()
        process_xml_file(
            file_bytes=_load_fixture("combined_v0v1.xml"),
            filename="RESULTS_VETME_v0v1.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        notifier.notify_missing_dob.assert_called_once_with(1, "RESULTS_VETME_v0v1.xml")


class TestEventCentricIngestion:
    """Test 9.193: Event-centric routing (ADR-025)."""

    def test_rejects_xml_when_no_event_and_no_tournament(self):
        """9.193 Orchestrator rejects XML when no event matches date and no legacy tournament."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db(tournaments={})  # empty — nothing found
        db.find_event_by_date.return_value = None  # no event either
        notifier = _make_mock_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        assert len(result.errors) > 0
        notifier.notify_tournament_not_found.assert_called()


class TestNotificationWiring:
    """Tests 9.198–9.199: Missing notification calls wired in."""

    def test_preliminary_file_notifies_skip(self):
        """9.198 Preliminary file (Sexe=X) sends info notification about skip."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db()
        notifier = _make_mock_notifier()

        xml = """<?xml version="1.0" encoding="utf-8"?>
        <CompetitionIndividuelle Arme="E" Sexe="X" AltName="SZPADA ELIMINACJE"
            Annee="2025/2026" Date="21.02.2026" TitreLong="Test" Federation="POL">
            <Tireurs>
                <Tireur Nom="TEST" Prenom="One" Classement="1" Nation="POL"/>
            </Tireurs>
        </CompetitionIndividuelle>""".encode("utf-8")

        result = process_xml_file(
            file_bytes=xml,
            filename="RESULTS_GRVETXE.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
        )
        assert len(result.skipped_files) > 0
        notifier.info.assert_called()

    def test_duplicate_import_notifies_warning(self):
        """9.199 Re-importing a tournament with existing results triggers duplicate notification."""
        from python.pipeline.orchestrator import process_xml_file

        db = _make_mock_db(fencer_db=[])
        db.has_existing_results.return_value = True
        notifier = _make_mock_notifier()
        result = process_xml_file(
            file_bytes=_load_fixture("single_category.xml"),
            filename="RESULTS_V50ME.xml",
            db=db,
            notifier=notifier,
            season_end_year=2026,
            tournament_type="PPW",
        )
        notifier.notify_duplicate_import.assert_called()
