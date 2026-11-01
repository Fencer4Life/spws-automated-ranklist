"""
Tests for the Supabase DB connector.

Plan test IDs 9.162–9.165:
  9.162  fetch_fencer_db() returns list[dict] with expected keys
  9.163  find_tournament(weapon, gender, category, date) returns dict or None
  9.164  ingest_results(tournament_id, results_json) calls .rpc()
  9.165  insert_fencer(fencer_dict) inserts and returns id_fencer
"""

from __future__ import annotations

from unittest.mock import MagicMock


class TestDbConnector:
    """Tests 9.162–9.165: DbConnector wrapping Supabase client."""

    def test_fetch_fencer_db_returns_list_of_dicts(self):
        """9.162 fetch_fencer_db() returns list[dict] with expected keys."""
        from python.pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.table.return_value.select.return_value.execute.return_value.data = [
            {
                "id_fencer": 1,
                "txt_surname": "NOWAK",
                "txt_first_name": "Piotr",
                "int_birth_year": 1970,
                "json_name_aliases": None,
            },
        ]
        db = DbConnector(mock_sb)
        result = db.fetch_fencer_db()
        assert isinstance(result, list)
        assert len(result) == 1
        assert "id_fencer" in result[0]
        assert "txt_surname" in result[0]
        assert "txt_first_name" in result[0]
        assert "int_birth_year" in result[0]
        assert "json_name_aliases" in result[0]

    def test_find_tournament_returns_dict_or_none(self):
        """9.163 find_tournament returns dict when found, None when not."""
        from python.pipeline.db_connector import DbConnector

        # Found case
        mock_sb = MagicMock()
        mock_sb.table.return_value.select.return_value.eq.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
            {"id_tournament": 5, "txt_code": "PPW4-E-M-V2", "enum_type": "PPW"},
        ]
        db = DbConnector(mock_sb)
        result = db.find_tournament("EPEE", "M", "V2", "2026-02-21")
        assert result is not None
        assert result["id_tournament"] == 5

        # Not found case
        mock_sb2 = MagicMock()
        mock_sb2.table.return_value.select.return_value.eq.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value.data = []
        db2 = DbConnector(mock_sb2)
        result2 = db2.find_tournament("FOIL", "F", "V4", "2026-02-21")
        assert result2 is None

    def test_ingest_results_calls_rpc(self):
        """9.164 ingest_results calls .rpc('fn_ingest_tournament_results')."""
        from python.pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.rpc.return_value.execute.return_value.data = {"inserted": 3, "scored": True}
        db = DbConnector(mock_sb)
        db.ingest_results(5, [{"id_fencer": 1, "int_place": 1}])
        mock_sb.rpc.assert_called_once()
        call_args = mock_sb.rpc.call_args
        assert "fn_ingest_tournament_results" in str(call_args)

    def test_insert_fencer_returns_id(self):
        """9.165 insert_fencer inserts and returns id_fencer."""
        from python.pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.table.return_value.insert.return_value.execute.return_value.data = [
            {"id_fencer": 42},
        ]
        db = DbConnector(mock_sb)
        new_id = db.insert_fencer(
            {
                "txt_surname": "NOWY",
                "txt_first_name": "Michał",
                "int_birth_year": 1993,
                "txt_nationality": "PL",
                "bool_birth_year_estimated": True,
            }
        )
        assert new_id == 42
        mock_sb.table.return_value.insert.assert_called_once()

    def test_claim_recompute_batch_reclaims_orphaned_claimed(self):
        """claim_recompute_batch claims every not-DONE row — PENDING AND orphaned
        CLAIMED. CERT drains are serialised, so a leftover CLAIMED is always an
        orphan from a dead worker; reclaiming it is deterministic (no time
        heuristic). Both flip straight to CLAIMED — never back to PENDING — keeping
        the one-PENDING-per-event index safe."""
        from python.pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.table.return_value.select.return_value.in_.return_value.execute.return_value.data = [
            {"id_event": 5},
            {"id_event": 7},
            {"id_event": 5},  # duplicate id collapses
        ]
        db = DbConnector(mock_sb)
        ids = db.claim_recompute_batch()
        assert ids == [5, 7]
        # Status filter is a deterministic membership test, no ts_claimed / time value.
        status_filter = mock_sb.table.return_value.select.return_value.in_.call_args
        assert status_filter.args[0] == "enum_status"
        assert set(status_filter.args[1]) == {"PENDING", "CLAIMED"}
        # And the claim flips those ids to CLAIMED (never to PENDING).
        update_arg = mock_sb.table.return_value.update.call_args.args[0]
        assert update_arg["enum_status"] == "CLAIMED"
        mock_sb.table.return_value.update.return_value.in_.return_value.in_.return_value.execute.assert_called_once()

    def test_has_existing_results(self):
        """9.200 has_existing_results returns True when results exist, False when not."""
        from python.pipeline.db_connector import DbConnector

        # Has results
        mock_sb = MagicMock()
        mock_sb.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
            {"id_result": 1},
        ]
        db = DbConnector(mock_sb)
        assert db.has_existing_results(5) is True

        # No results
        mock_sb2 = MagicMock()
        mock_sb2.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = []
        db2 = DbConnector(mock_sb2)
        assert db2.has_existing_results(5) is False


class TestSupabaseClient:
    """SBCLIENT.01–04 (ADR-119 G22): supabase-py 2.31 hands `timeout` and `verify`
    to its PostgREST and Storage clients unless it is given an HTTP client, and
    both libraries deprecate those arguments. Every client is built by one helper
    that gives it one, so none raises the warning."""

    def test_connector_builds_without_deprecation_warnings(self, monkeypatch):
        """SBCLIENT.01"""
        import warnings

        from python.pipeline.db_connector import create_db_connector

        monkeypatch.setenv("SUPABASE_URL", "http://127.0.0.1:54321")
        monkeypatch.setenv("SUPABASE_KEY", "header.payload.signature")
        with warnings.catch_warnings():
            warnings.simplefilter("error")
            db = create_db_connector()
            # Both are built on first use; that is where the warnings came from.
            assert db._sb.postgrest is not None
            assert db._sb.storage is not None

    def test_the_http_client_keeps_the_librarys_defaults(self):
        """SBCLIENT.02"""
        from postgrest.constants import DEFAULT_POSTGREST_CLIENT_TIMEOUT

        from python.pipeline.db_connector import make_supabase_client

        sb = make_supabase_client("http://127.0.0.1:54321", "header.payload.signature")
        session = sb.postgrest.session
        assert session.timeout.read == DEFAULT_POSTGREST_CLIENT_TIMEOUT
        assert session.follow_redirects is True
        assert sb.storage.session is session

    def test_postgrest_and_storage_send_their_own_address_and_key(self, httpx_mock):
        """SBCLIENT.03 The shared HTTP client carries no address or headers of its
        own, so each sub-client must send them with every request. LOCAL runs
        without Storage, so the requests are recorded here instead."""
        from python.pipeline.db_connector import make_supabase_client

        base, key = "http://127.0.0.1:54321", "header.payload.signature"
        httpx_mock.add_response(url=f"{base}/rest/v1/tbl_season?select=txt_code", json=[])
        httpx_mock.add_response(url=f"{base}/storage/v1/bucket", json=[])
        sb = make_supabase_client(base, key)
        sb.table("tbl_season").select("txt_code").execute()
        sb.storage.list_buckets()

        requests = httpx_mock.get_requests()
        assert [r.url.path for r in requests] == ["/rest/v1/tbl_season", "/storage/v1/bucket"]
        for r in requests:
            assert r.headers["apikey"] == key
            assert r.headers["authorization"] == f"Bearer {key}"

    def test_every_client_is_built_by_the_helper(self):
        """SBCLIENT.04 No Python the repository runs calls create_client itself."""
        from pathlib import Path

        repo = Path(__file__).resolve().parents[2]
        direct = sorted(
            str(p.relative_to(repo))
            for top in ("python", "scripts", "tools")
            for p in (repo / top).rglob("*.py")
            if "tests" not in p.parts
            and p.name != "db_connector.py"
            and "create_client(" in p.read_text(encoding="utf-8")
        )
        assert direct == [], f"build clients with db_connector.make_supabase_client: {direct}"
