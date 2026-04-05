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
        from pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.table.return_value.select.return_value.execute.return_value.data = [
            {"id_fencer": 1, "txt_surname": "NOWAK", "txt_first_name": "Piotr",
             "int_birth_year": 1970, "json_name_aliases": None},
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
        from pipeline.db_connector import DbConnector

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
        from pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.rpc.return_value.execute.return_value.data = {"inserted": 3, "scored": True}
        db = DbConnector(mock_sb)
        result = db.ingest_results(5, [{"id_fencer": 1, "int_place": 1}])
        mock_sb.rpc.assert_called_once()
        call_args = mock_sb.rpc.call_args
        assert "fn_ingest_tournament_results" in str(call_args)

    def test_insert_fencer_returns_id(self):
        """9.165 insert_fencer inserts and returns id_fencer."""
        from pipeline.db_connector import DbConnector

        mock_sb = MagicMock()
        mock_sb.table.return_value.insert.return_value.execute.return_value.data = [
            {"id_fencer": 42},
        ]
        db = DbConnector(mock_sb)
        new_id = db.insert_fencer({
            "txt_surname": "NOWY",
            "txt_first_name": "Michał",
            "int_birth_year": 1993,
            "txt_nationality": "PL",
            "bool_birth_year_estimated": True,
        })
        assert new_id == 42
        mock_sb.table.return_value.insert.assert_called_once()
