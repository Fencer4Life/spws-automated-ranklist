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

    def test_write_prod_results_carries_participant_count(self):
        """9.206a write_prod_results passes participant_count to PROD RPC.

        Regression guard for CERT→PROD promotion deflation: after ADR-038
        shrank the payload to POL-only rows, the 3rd RPC argument
        (p_participant_count) must carry CERT's actual field size to PROD.
        Without it, PROD falls back to jsonb_array_length(payload) and
        deflates scoring on the production ranklist.
        """
        from python.pipeline.promote import write_prod_results

        recorded_sql: list[str] = []

        def fake_query(sql: str):
            recorded_sql.append(sql)
            return [{"fn_ingest_tournament_results": {"inserted": 2, "scored": True}}]

        results = [
            {"id_fencer": 1, "int_place": 1, "txt_scraped_name": "KOWALSKI Jan",
             "num_confidence": 99, "enum_match_status": "AUTO_MATCHED"},
            {"id_fencer": 2, "int_place": 2, "txt_scraped_name": "NOWAK Piotr",
             "num_confidence": 97, "enum_match_status": "AUTO_MATCHED"},
        ]
        write_prod_results(
            tournament_id=200, results=results, query_fn=fake_query,
            participant_count=31,
        )
        assert len(recorded_sql) == 1
        sql = recorded_sql[0]
        # RPC must be called with 3 positional args: (tid, payload, participant_count)
        assert "fn_ingest_tournament_results(200," in sql, \
            f"expected tournament_id as first arg; got SQL:\n{sql}"
        assert sql.rstrip().endswith(", 31)") or ", 31)" in sql, \
            f"participant_count=31 must be passed to PROD RPC; got SQL:\n{sql}"

    def test_promote_event_threads_cert_participant_count_to_prod(self):
        """9.206b promote_event must pass CERT's int_participant_count to PROD.

        End-to-end guard: read_cert_event already captures
        int_participant_count per tournament; promote_event must forward
        that value so PROD scoring matches CERT scoring exactly.
        """
        from python.pipeline.promote import promote_event

        cert_data = {
            "event": {
                "id_event": 54, "txt_code": "PEW7-2025-2026",
                "txt_name": "EVF Circuit Salzburg",
                "id_season": 3, "id_organizer": 2,
                "dt_start": "2026-04-18", "enum_status": "IN_PROGRESS",
            },
            "tournaments": [
                {"id_tournament": 101, "txt_code": "PEW7-V2-M-EPEE-2025-2026",
                 "enum_type": "PEW", "enum_weapon": "EPEE", "enum_gender": "M",
                 "enum_age_category": "V2", "dt_tournament": "2026-04-18",
                 "int_participant_count": 31, "url_results": "https://dart/x"},
            ],
            "results": {
                101: [
                    {"id_fencer": 1, "int_place": 1, "txt_scraped_name": "X Y",
                     "num_confidence": 99, "enum_match_status": "AUTO_MATCHED"},
                    {"id_fencer": 2, "int_place": 2, "txt_scraped_name": "A B",
                     "num_confidence": 97, "enum_match_status": "AUTO_MATCHED"},
                    {"id_fencer": 3, "int_place": 3, "txt_scraped_name": "C D",
                     "num_confidence": 95, "enum_match_status": "AUTO_MATCHED"},
                ],
            },
            "fencers": {},
        }

        recorded_sql: list[str] = []

        def fake_prod_query(sql: str):
            recorded_sql.append(sql)
            if "fn_find_or_create_tournament" in sql:
                return [{"fn_find_or_create_tournament": 200}]
            if "fn_ingest_tournament_results" in sql:
                return [{"fn_ingest_tournament_results":
                         {"inserted": 3, "scored": True}}]
            return []

        promote_event(
            cert_data=cert_data, prod_event_id=10,
            prod_query_fn=fake_prod_query,
        )

        ingest_calls = [s for s in recorded_sql
                        if "fn_ingest_tournament_results" in s]
        assert len(ingest_calls) == 1, \
            "promote_event should call the RPC once per tournament"
        # N=31 must reach PROD, NOT 3 (the payload length)
        assert ", 31)" in ingest_calls[0], (
            "promote_event must thread CERT int_participant_count (31) "
            f"into PROD RPC. Got:\n{ingest_calls[0]}"
        )

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


# =============================================================================
# prom.5–prom.7 — Calendar-mode CERT→PROD promotion (ADR-026 amendment)
# =============================================================================


class TestPromoteCalendar:
    """Plan test IDs prom.5–prom.7 — see doc/evf_calendar_promote_plan.md."""

    def test_calendar_mode_imports_new_events_on_prod(self):
        """prom.5: calendar mode calls fn_import_evf_events on PROD for CERT-only events."""
        from python.pipeline.promote import promote_calendar

        cert_query_calls: list[str] = []
        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            cert_query_calls.append(sql)
            if "bool_active = TRUE" in sql:
                return [{"txt_code": "SPWS-2025-2026", "dt_start": "2025-08-01",
                         "dt_end": "2026-07-15", "id_season": 3}]
            # EVF events on CERT
            return [
                {"txt_code": "PEW-NEWCITY-2025-2026", "txt_name": "EVF Circuit New City",
                 "dt_start": "2026-06-15", "dt_end": "2026-06-15",
                 "txt_location": "New City", "txt_country": "AUT",
                 "txt_venue_address": "Street 1", "url_event": "https://evf/new",
                 "url_invitation": "https://evf/inv.pdf", "url_registration": None,
                 "dt_registration_deadline": None, "num_entry_fee": 50.0,
                 "txt_entry_fee_currency": "EUR", "weapons": ["EPEE", "FOIL"],
                 "is_team": False},
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "bool_active = TRUE" in sql:
                return [{"txt_code": "SPWS-2025-2026", "dt_start": "2025-08-01",
                         "dt_end": "2026-07-15", "id_season": 5}]
            if "SELECT id_event, txt_code FROM tbl_event" in sql:
                # PROD has nothing matching yet
                return []
            # RPC call return (SQL uses `AS r` alias)
            return [{"r": {"created": 1, "skipped": 0}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        # Expect fn_import_evf_events called on PROD, NOT fn_refresh (no matches)
        import_calls = [s for s in prod_query_calls if "fn_import_evf_events" in s]
        refresh_calls = [s for s in prod_query_calls if "fn_refresh_evf_event_urls" in s]
        assert len(import_calls) == 1, f"expected 1 import call, got {len(import_calls)}"
        assert len(refresh_calls) == 0, "no refresh expected (no existing events)"
        assert "PEW-NEWCITY-2025-2026" in import_calls[0]
        assert summary["imported"] == 1
        assert summary["refreshed"] == 0

    def test_calendar_mode_refreshes_existing_events_on_prod(self):
        """prom.6: calendar mode calls fn_refresh_evf_event_urls for events present on both sides."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "bool_active = TRUE" in sql:
                return [{"txt_code": "SPWS-2025-2026", "dt_start": "2025-08-01",
                         "dt_end": "2026-07-15", "id_season": 3}]
            return [
                {"txt_code": "PEW1-2025-2026", "txt_name": "EVF Circuit Budapest",
                 "dt_start": "2025-09-20", "dt_end": "2025-09-20",
                 "txt_location": "Budapest", "txt_country": "HUN",
                 "txt_venue_address": "Street 1", "url_event": "https://e/budapest",
                 "url_invitation": "https://e/inv.pdf", "url_registration": "https://reg",
                 "dt_registration_deadline": None, "num_entry_fee": 45.0,
                 "txt_entry_fee_currency": "EUR", "weapons": ["EPEE", "FOIL", "SABRE"],
                 "is_team": False},
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "bool_active = TRUE" in sql:
                return [{"txt_code": "SPWS-2025-2026", "dt_start": "2025-08-01",
                         "dt_end": "2026-07-15", "id_season": 5}]
            if "SELECT id_event, txt_code FROM tbl_event" in sql:
                return [{"id_event": 99, "txt_code": "PEW1-2025-2026"}]
            return [{"r": {"touched": 1, "refreshed": 1}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        import_calls = [s for s in prod_query_calls if "fn_import_evf_events" in s]
        refresh_calls = [s for s in prod_query_calls if "fn_refresh_evf_event_urls" in s]
        assert len(refresh_calls) == 1, f"expected 1 refresh call, got {len(refresh_calls)}"
        assert len(import_calls) == 0, "no import expected (event already on PROD)"
        # Refresh payload must reference PROD id_event (99), NOT CERT id
        assert '"id_event": 99' in refresh_calls[0] or "99" in refresh_calls[0]
        assert summary["imported"] == 0
        assert summary["refreshed"] == 1

    def test_calendar_mode_cli_rejects_event_arg(self, monkeypatch):
        """prom.7: `promote --mode calendar --event PEW1` exits non-zero with a clear error."""
        import sys
        import io
        from python.pipeline import promote

        monkeypatch.setenv("SUPABASE_ACCESS_TOKEN", "x")
        monkeypatch.setenv("SUPABASE_CERT_REF", "cert")
        monkeypatch.setenv("SUPABASE_PROD_REF", "prod")
        monkeypatch.setattr(sys, "argv", ["promote", "--mode", "calendar", "--event", "PEW1"])

        captured = io.StringIO()
        monkeypatch.setattr(sys, "stderr", captured)
        with pytest.raises(SystemExit) as excinfo:
            promote.main()
        assert excinfo.value.code != 0
        msg = captured.getvalue().lower()
        assert "calendar" in msg and "event" in msg
