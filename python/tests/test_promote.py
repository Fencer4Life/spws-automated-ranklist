"""
Tests for the CERT → PROD promotion script.

Plan test IDs 9.204–9.207:
  9.204  promote_event reads tournaments+results from CERT
  9.205  promote_event creates tournaments on PROD via fn_find_or_create_tournament
  9.206  promote_event calls fn_ingest_tournament_results on PROD for each tournament
  9.207  promote_event reports per-tournament success/failure
"""

from __future__ import annotations

from unittest.mock import MagicMock

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
                {
                    "id_fencer": 1,
                    "int_place": 1,
                    "txt_scraped_name": "KOWALSKI Jan",
                    "num_confidence": 99,
                    "enum_match_status": "AUTO_MATCHED",
                },
                {
                    "id_fencer": 2,
                    "int_place": 2,
                    "txt_scraped_name": "NOWAK Piotr",
                    "num_confidence": 97,
                    "enum_match_status": "AUTO_MATCHED",
                },
            ],
            101: [
                {
                    "id_fencer": 3,
                    "int_place": 1,
                    "txt_scraped_name": "KAMIŃSKA Ewa",
                    "num_confidence": 98,
                    "enum_match_status": "AUTO_MATCHED",
                },
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
                return [
                    {
                        "event_code": "PPW4.5-2025-2026",
                        "event_name": "PPW4.5 Test Gdańsk",
                        "id_event": 58,
                        "id_season": 3,
                        "id_organizer": 1,
                        "dt_start": "2026-02-21",
                        "enum_status": "COMPLETED",
                    }
                ]
            elif call_count[0] == 2:  # tournaments query
                return [
                    {
                        "id_tournament": 100,
                        "txt_code": "PPW4.5-V2-M-EPEE-2025-2026",
                        "enum_type": "PPW",
                        "enum_weapon": "EPEE",
                        "enum_gender": "M",
                        "enum_age_category": "V2",
                        "dt_tournament": "2026-02-21",
                        "int_participant_count": 11,
                    }
                ]
            elif call_count[0] == 3:  # results for tournament 100
                return [
                    {
                        "id_fencer": 1,
                        "int_place": 1,
                        "txt_scraped_name": "KOWALSKI Jan",
                        "num_confidence": 99,
                        "enum_match_status": "AUTO_MATCHED",
                    }
                ]
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

        mock_query = MagicMock(
            return_value=[{"fn_ingest_tournament_results": {"inserted": 2, "scored": True}}]
        )

        results = [
            {
                "id_fencer": 1,
                "int_place": 1,
                "txt_scraped_name": "KOWALSKI Jan",
                "num_confidence": 99,
                "enum_match_status": "AUTO_MATCHED",
            },
            {
                "id_fencer": 2,
                "int_place": 2,
                "txt_scraped_name": "NOWAK Piotr",
                "num_confidence": 97,
                "enum_match_status": "AUTO_MATCHED",
            },
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
            {
                "id_fencer": 1,
                "int_place": 1,
                "txt_scraped_name": "KOWALSKI Jan",
                "num_confidence": 99,
                "enum_match_status": "AUTO_MATCHED",
            },
            {
                "id_fencer": 2,
                "int_place": 2,
                "txt_scraped_name": "NOWAK Piotr",
                "num_confidence": 97,
                "enum_match_status": "AUTO_MATCHED",
            },
        ]
        write_prod_results(
            tournament_id=200,
            results=results,
            query_fn=fake_query,
            participant_count=31,
        )
        assert len(recorded_sql) == 1
        sql = recorded_sql[0]
        # RPC must be called with 3 positional args: (tid, payload, participant_count)
        assert "fn_ingest_tournament_results(200," in sql, (
            f"expected tournament_id as first arg; got SQL:\n{sql}"
        )
        assert sql.rstrip().endswith(", 31)") or ", 31)" in sql, (
            f"participant_count=31 must be passed to PROD RPC; got SQL:\n{sql}"
        )

    def test_promote_event_threads_cert_participant_count_to_prod(self):
        """9.206b promote_event must pass CERT's int_participant_count to PROD.

        End-to-end guard: read_cert_event already captures
        int_participant_count per tournament; promote_event must forward
        that value so PROD scoring matches CERT scoring exactly.
        """
        from python.pipeline.promote import promote_event

        cert_data = {
            "event": {
                "id_event": 54,
                "txt_code": "PEW7-2025-2026",
                "txt_name": "EVF Circuit Salzburg",
                "id_season": 3,
                "id_organizer": 2,
                "dt_start": "2026-04-18",
                "enum_status": "IN_PROGRESS",
            },
            "tournaments": [
                {
                    "id_tournament": 101,
                    "txt_code": "PEW7-V2-M-EPEE-2025-2026",
                    "enum_type": "PEW",
                    "enum_weapon": "EPEE",
                    "enum_gender": "M",
                    "enum_age_category": "V2",
                    "dt_tournament": "2026-04-18",
                    "int_participant_count": 31,
                    "url_results": "https://dart/x",
                },
            ],
            "results": {
                101: [
                    {
                        "id_fencer": 1,
                        "int_place": 1,
                        "txt_scraped_name": "X Y",
                        "num_confidence": 99,
                        "enum_match_status": "AUTO_MATCHED",
                    },
                    {
                        "id_fencer": 2,
                        "int_place": 2,
                        "txt_scraped_name": "A B",
                        "num_confidence": 97,
                        "enum_match_status": "AUTO_MATCHED",
                    },
                    {
                        "id_fencer": 3,
                        "int_place": 3,
                        "txt_scraped_name": "C D",
                        "num_confidence": 95,
                        "enum_match_status": "AUTO_MATCHED",
                    },
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
                return [{"fn_ingest_tournament_results": {"inserted": 3, "scored": True}}]
            return []

        promote_event(
            cert_data=cert_data,
            prod_event_id=10,
            prod_query_fn=fake_prod_query,
        )

        ingest_calls = [s for s in recorded_sql if "fn_ingest_tournament_results" in s]
        assert len(ingest_calls) == 1, "promote_event should call the RPC once per tournament"
        # N=31 must reach PROD, NOT 3 (the payload length)
        assert ", 31)" in ingest_calls[0], (
            "promote_event must thread CERT int_participant_count (31) "
            f"into PROD RPC. Got:\n{ingest_calls[0]}"
        )

    def test_reports_per_tournament_results(self):
        """9.207 promote_event reports per-tournament success/failure."""
        from python.pipeline.promote import promote_event

        cert_data = _make_cert_data()

        mock_prod_query = MagicMock()

        # PROD find_or_create returns tournament IDs
        mock_prod_query.side_effect = [
            [{"fn_find_or_create_tournament": 200}],  # first tournament
            [{"fn_ingest_tournament_results": {"inserted": 2, "scored": True}}],  # first results
            [{"fn_find_or_create_tournament": 201}],  # second tournament
            [{"fn_ingest_tournament_results": {"inserted": 1, "scored": True}}],  # second results
            [],  # update event status → IN_PROGRESS
            [],  # update event status → COMPLETED
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
# prom.5–prom.7 — Calendar-mode CERT→PROD reconciliation (reconciler amendment,
# pending ADR sign-off; supersedes the calendar-delta half of ADR-026)
# =============================================================================


def _active_season_row(id_season: int) -> dict:
    return {
        "txt_code": "SPWS-2025-2026",
        "dt_start": "2025-08-01",
        "dt_end": "2026-07-15",
        "id_season": id_season,
    }


class TestPromoteCalendar:
    """Plan test IDs prom.5–prom.7 — see doc/archive/evf_calendar_promote_plan.md
    (superseded by the reconciler design; test names kept stable)."""

    def test_refuses_when_cert_and_prod_active_seasons_differ(self):
        """New (found via live CERT/PROD dry-run 2026-07-11): if CERT has
        rolled to a new season that PROD hasn't been bootstrapped onto yet,
        the reconciler must refuse rather than misfile CERT's new-season
        events under PROD's old id_season and propose deleting PROD's whole
        outgoing season."""
        from python.pipeline.promote import promote_calendar

        def cert_query(sql: str):
            assert "bool_active = TRUE" in sql, f"unexpected CERT query before season check: {sql}"
            return [
                {
                    "txt_code": "SPWS-2026-2027",
                    "dt_start": "2026-08-01",
                    "dt_end": "2027-07-15",
                    "id_season": 4,
                }
            ]

        def prod_query(sql: str):
            assert "bool_active = TRUE" in sql, f"unexpected PROD query before season check: {sql}"
            return [_active_season_row(3)]

        with pytest.raises(RuntimeError, match="active season mismatch"):
            promote_calendar(cert_query_fn=cert_query, prod_query_fn=prod_query, dry_run=True)

    def test_calendar_mode_creates_new_events_on_prod(self):
        """prom.5: reconciler CREATEs, via fn_mirror_events_to_prod, for CERT-only
        events — no code-prefix filter, organizer resolved by code (not hardcoded)."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "bool_active = TRUE" in sql:
                return [_active_season_row(3)]
            # _read_cert_promotable_events — no code-prefix filter
            return [
                {
                    "txt_code": "PPW-NEWCITY-2025-2026",
                    "txt_name": "Domestic Circuit New City",
                    "enum_status": "PLANNED",
                    "dt_start": "2026-06-15",
                    "dt_end": "2026-06-15",
                    "txt_location": "New City",
                    "txt_country": "POL",
                    "txt_venue_address": "Street 1",
                    "url_event": "https://spws/new",
                    "url_invitation": None,
                    "url_registration": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": 50.0,
                    "txt_entry_fee_currency": "PLN",
                    "weapons": ["EPEE", "FOIL"],
                    "id_evf_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "SPWS",
                    "prior_code": None,
                },
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "bool_active = TRUE" in sql:
                return [_active_season_row(5)]
            if "SELECT id_event, txt_code FROM tbl_event" in sql:
                # PROD has nothing matching yet
                return []
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "SPWS", "id": 42}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            # RPC call return (SQL uses `AS r` alias)
            return [{"r": {"created": 1, "updated": 0, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1, f"expected 1 reconcile call, got {len(rpc_calls)}"
        assert "PPW-NEWCITY-2025-2026" in rpc_calls[0]
        # Organizer must be the RESOLVED PROD id (42), not a hardcoded literal
        assert '"id_organizer": 42' in rpc_calls[0]
        assert summary["created"] == 1
        assert summary["updated"] == 0
        assert summary["new_codes"] == ["PPW-NEWCITY-2025-2026"]

    def test_calendar_mode_updates_existing_events_on_prod(self):
        """prom.6: reconciler UPDATEs, via fn_mirror_events_to_prod, for events
        present on both sides — identity fields (incl. organizer) overwritten."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "bool_active = TRUE" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PEW1-2025-2026",
                    "txt_name": "EVF Circuit Budapest",
                    "enum_status": "PLANNED",
                    "dt_start": "2025-09-20",
                    "dt_end": "2025-09-20",
                    "txt_location": "Budapest",
                    "txt_country": "HUN",
                    "txt_venue_address": "Street 1",
                    "url_event": "https://e/budapest",
                    "url_invitation": "https://e/inv.pdf",
                    "url_registration": "https://reg",
                    "dt_registration_deadline": None,
                    "num_entry_fee": 45.0,
                    "txt_entry_fee_currency": "EUR",
                    "weapons": ["EPEE", "FOIL", "SABRE"],
                    "id_evf_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "EVF",
                    "prior_code": None,
                },
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "bool_active = TRUE" in sql:
                return [_active_season_row(5)]
            if "SELECT id_event, txt_code FROM tbl_event" in sql:
                return [{"id_event": 99, "txt_code": "PEW1-2025-2026"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "EVF", "id": 7}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1, f"expected 1 reconcile call, got {len(rpc_calls)}"
        # UPDATE payload must reference PROD id_event (99), NOT CERT id, and the
        # RESOLVED organizer id (7) — the mis-tag repair, no hardcoded literal
        assert '"id_event": 99' in rpc_calls[0]
        assert '"id_organizer": 7' in rpc_calls[0]
        assert summary["created"] == 0
        assert summary["updated"] == 1

    def test_calendar_mode_deletes_orphaned_prod_events(self):
        """New: reconciler DELETEs (guarded server-side) events present on PROD
        but absent from CERT — the missing operation the old insert-or-refresh
        path never had, which stranded the 6 dead Samorin duplicates."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "bool_active = TRUE" in sql:
                return [_active_season_row(3)]
            return []  # CERT has nothing this season — everything on PROD is orphaned

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "bool_active = TRUE" in sql:
                return [_active_season_row(5)]
            if "SELECT id_event, txt_code FROM tbl_event" in sql:
                return [{"id_event": 114, "txt_code": "PEW69-2026-2027"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return []
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 0, "deleted": 1, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1
        assert "114" in rpc_calls[0]
        assert summary["deleted"] == 1
        assert summary["deleted_codes"] == ["PEW69-2026-2027"]

    def test_calendar_mode_surfaces_delete_skipped(self):
        """New: a results-bearing event the RPC refused to delete (guard) is
        surfaced in the summary for investigation, never silently dropped."""
        from python.pipeline.promote import promote_calendar

        def cert_query(sql: str):
            if "bool_active = TRUE" in sql:
                return [_active_season_row(3)]
            return []

        def prod_query(sql: str):
            if "bool_active = TRUE" in sql:
                return [_active_season_row(5)]
            if "SELECT id_event, txt_code FROM tbl_event" in sql:
                return [{"id_event": 200, "txt_code": "PPW-COMPLETED-2025-2026"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return []
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 0, "deleted": 0, "delete_skipped": [200]}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        assert summary["deleted"] == 0
        assert summary["delete_skipped"] == [200]

    def test_calendar_mode_cli_rejects_event_arg(self, monkeypatch):
        """prom.7: `promote --mode calendar --event PEW1` exits non-zero with a clear error."""
        import io
        import sys

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


# prom.8 — Multi-slot event URLs are propagated CERT → PROD (ADR-040)


class TestPromoteCalendarMultiUrl:
    """Plan test prom.8 — calendar reconcile ships url_event_2..5 from CERT to
    PROD via the fn_mirror_events_to_prod UPDATE payload (fill-blank-only per
    slot, enforced server-side)."""

    def test_calendar_mode_propagates_url_event_2_through_5(self):
        """prom.8: UPDATE payload carries url_event_2..5 keys when CERT row has them."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "bool_active = TRUE" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PEW1-2025-2026",
                    "txt_name": "EVF Circuit Budapest",
                    "enum_status": "PLANNED",
                    "dt_start": "2025-09-20",
                    "dt_end": "2025-09-21",
                    "txt_location": "Budapest",
                    "txt_country": "HUN",
                    "txt_venue_address": "Street 1",
                    "url_event": "https://e/p1",
                    "url_event_2": "https://e/p2",
                    "url_event_3": "https://e/p3",
                    "url_event_4": None,
                    "url_event_5": None,
                    "url_invitation": None,
                    "url_registration": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": 45.0,
                    "txt_entry_fee_currency": "EUR",
                    "weapons": ["EPEE", "FOIL", "SABRE"],
                    "id_evf_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "EVF",
                    "prior_code": None,
                }
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "bool_active = TRUE" in sql:
                return [_active_season_row(5)]
            if "SELECT id_event, txt_code FROM tbl_event" in sql:
                return [{"id_event": 99, "txt_code": "PEW1-2025-2026"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "EVF", "id": 7}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1
        body = rpc_calls[0]
        # All five URL slots present in the JSONB payload
        assert "url_event_2" in body and "https://e/p2" in body
        assert "url_event_3" in body and "https://e/p3" in body
        assert "url_event_4" in body  # key present even when value null/empty
        assert "url_event_5" in body
        assert summary["updated"] == 1
