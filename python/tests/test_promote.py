"""
Tests for the CERT → PROD promotion script.

Plan test IDs 9.204–9.207:
  9.204  promote_event reads tournaments+results from CERT
  9.205  promote_event creates tournaments on PROD via fn_find_or_create_tournament
  9.206  promote_event calls fn_ingest_tournament_results on PROD for each tournament
  9.207  promote_event reports per-tournament success/failure
"""

from __future__ import annotations

from unittest.mock import MagicMock, call, patch

import pytest


def _make_cert_data():
    """Sample CERT event data as returned by Management API."""
    return {
        "event": {
            "id_event": 58,
            "txt_code": "PPW4.5-2025-2026",
            "txt_name": "PPW4.5 Test Gdańsk",
            "id_season": 3,
            "id_organizer": 1,
            "dt_start": "2026-02-21",
            "enum_status": "COMPLETED",
        },
        "tournaments": [
            {
                "id_tournament": 100,
                "txt_code": "PPW4.5-V2-M-EPEE-2025-2026",
                "enum_type": "PPW",
                "enum_weapon": "EPEE",
                "enum_gender": "M",
                "enum_age_category": "V2",
                "dt_tournament": "2026-02-21",
                "int_participant_count": 11,
            },
            {
                "id_tournament": 101,
                "txt_code": "PPW4.5-V0-F-FOIL-2025-2026",
                "enum_type": "PPW",
                "enum_weapon": "FOIL",
                "enum_gender": "F",
                "enum_age_category": "V0",
                "dt_tournament": "2026-02-21",
                "int_participant_count": 3,
            },
        ],
        "results": {
            100: [
                {"id_fencer": 1, "int_place": 1, "txt_scraped_name": "KOWALSKI Jan", "num_confidence": 99, "enum_match_status": "AUTO_MATCHED"},
                {"id_fencer": 2, "int_place": 2, "txt_scraped_name": "NOWAK Piotr", "num_confidence": 97, "enum_match_status": "AUTO_MATCHED"},
            ],
            101: [
                {"id_fencer": 3, "int_place": 1, "txt_scraped_name": "KAMIŃSKA Ewa", "num_confidence": 98, "enum_match_status": "AUTO_MATCHED"},
            ],
        },
    }


class TestPromoteEvent:
    """Tests 9.204–9.207: CERT → PROD promotion."""

    def test_reads_cert_data(self):
        """9.204 promote_event reads tournaments+results from CERT."""
        from python.pipeline.promote import read_cert_event

        call_count = [0]
        def mock_query(sql):
            call_count[0] += 1
            if call_count[0] == 1:  # event query
                return [{"event_code": "PPW4.5-2025-2026", "event_name": "PPW4.5 Test Gdańsk",
                         "id_event": 58, "id_season": 3, "id_organizer": 1,
                         "dt_start": "2026-02-21", "enum_status": "COMPLETED"}]
            elif call_count[0] == 2:  # tournaments query
                return [{"id_tournament": 100, "txt_code": "PPW4.5-V2-M-EPEE-2025-2026",
                         "enum_type": "PPW", "enum_weapon": "EPEE", "enum_gender": "M",
                         "enum_age_category": "V2", "dt_tournament": "2026-02-21",
                         "int_participant_count": 11}]
            elif call_count[0] == 3:  # results for tournament 100
                return [{"id_fencer": 1, "int_place": 1, "txt_scraped_name": "KOWALSKI Jan",
                         "num_confidence": 99, "enum_match_status": "AUTO_MATCHED"}]
            elif call_count[0] == 4:  # fencer names
                return [{"id_fencer": 1, "txt_surname": "KOWALSKI", "txt_first_name": "Jan"}]
            else:
                return []

        result = read_cert_event("PPW4.5", query_fn=mock_query)
        assert result is not None
        assert result["event"]["txt_code"] == "PPW4.5-2025-2026"
        assert len(result["tournaments"]) == 1
        assert 100 in result["results"]

    def test_creates_tournaments_on_prod(self):
        """9.205 promote_event creates tournaments on PROD."""
        from python.pipeline.promote import write_prod_tournament

        mock_query = MagicMock(return_value=[{"fn_find_or_create_tournament": 200}])

        tourn = {
            "enum_weapon": "EPEE",
            "enum_gender": "M",
            "enum_age_category": "V2",
            "dt_tournament": "2026-02-21",
            "enum_type": "PPW",
        }
        prod_id = write_prod_tournament(event_id=10, tournament=tourn, query_fn=mock_query)
        assert prod_id == 200
        mock_query.assert_called_once()

    def test_ingests_results_on_prod(self):
        """9.206 promote_event calls fn_ingest_tournament_results on PROD."""
        from python.pipeline.promote import write_prod_results

        mock_query = MagicMock(return_value=[{"fn_ingest_tournament_results": {"inserted": 2, "scored": True}}])

        results = [
            {"id_fencer": 1, "int_place": 1, "txt_scraped_name": "KOWALSKI Jan", "num_confidence": 99, "enum_match_status": "AUTO_MATCHED"},
            {"id_fencer": 2, "int_place": 2, "txt_scraped_name": "NOWAK Piotr", "num_confidence": 97, "enum_match_status": "AUTO_MATCHED"},
        ]
        summary = write_prod_results(tournament_id=200, results=results, query_fn=mock_query)
        assert summary["inserted"] == 2
        mock_query.assert_called_once()

    def test_reports_per_tournament_results(self):
        """9.207 promote_event reports per-tournament success/failure."""
        from python.pipeline.promote import promote_event

        cert_data = _make_cert_data()

        mock_cert_query = MagicMock()
        mock_prod_query = MagicMock()

        # PROD find_or_create returns tournament IDs
        mock_prod_query.side_effect = [
            [{"fn_find_or_create_tournament": 200}],  # first tournament
            [{"fn_ingest_tournament_results": {"inserted": 2, "scored": True}}],  # first results
            [{"fn_find_or_create_tournament": 201}],  # second tournament
            [{"fn_ingest_tournament_results": {"inserted": 1, "scored": True}}],  # second results
            [],  # update event status
        ]

        result = promote_event(
            cert_data=cert_data,
            prod_event_id=10,
            prod_query_fn=mock_prod_query,
        )
        assert result["tournaments_promoted"] == 2
        assert result["total_results"] == 3
        assert len(result["errors"]) == 0

    # 9.208 moved to test_export_seed.py (ADR-027 replaces append-based export)
