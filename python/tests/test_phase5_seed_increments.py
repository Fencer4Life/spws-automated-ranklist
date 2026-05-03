"""
Plan-test-ID 5.13: phase5_runner._append_event_to_seed emits INSERT INTO tbl_fencer
for every fencer touched by the event's results.

Bug history (2026-05-03): operator added BURLIKOWSKI Bartosz via Create-new-fencer
during GP1 triage; commit-export wrote tbl_tournament + tbl_result INSERTs but
NOT tbl_fencer INSERTs. After ./scripts/reset-dev.sh the fencer was gone, the
result-row sub-SELECT couldn't resolve id_fencer, ingestion mis-matched
"BURLIKOWSKI Bartosz" to "KOWALSKI Bartosz" again.

Fix: emit tbl_fencer INSERTs (with ON CONFLICT DO NOTHING so baseline rows are
no-ops) BEFORE the tbl_result INSERTs in the seed-increment file.

Defence in depth: txt_first_name and txt_surname are .strip()-ped at write time
so the leading-space corruption ('  Bartosz') doesn't propagate even if the
runtime DB row has it.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock

import pytest


def _make_mock_db(event_id, tournaments, results, fencers):
    """Build a mock supabase client whose .table().select().*().execute() chain
    returns the right data for _append_event_to_seed."""
    db = MagicMock()
    sb = MagicMock()
    db._sb = sb

    def _table(name):
        tbl = MagicMock()
        if name == "tbl_event":
            tbl.select.return_value.eq.return_value.execute.return_value.data = (
                [{"id_event": event_id}] if event_id else []
            )
        elif name == "tbl_tournament":
            chain = tbl.select.return_value.eq.return_value
            chain.order.return_value.order.return_value.order.return_value.execute.return_value.data = tournaments
        elif name == "tbl_result":
            tbl.select.return_value.in_.return_value.execute.return_value.data = results
        elif name == "tbl_fencer":
            tbl.select.return_value.in_.return_value.execute.return_value.data = fencers
        return tbl

    sb.table.side_effect = _table
    return db


def test_seed_export_emits_fencer_inserts(tmp_path, monkeypatch):
    # 5.13.1 — every distinct fencer referenced by results is emitted as INSERT INTO tbl_fencer
    from python.tools import phase5_runner

    monkeypatch.chdir(tmp_path)

    db = _make_mock_db(
        event_id=42,
        tournaments=[{
            "id_tournament": 100, "txt_code": "GPX-V2-EPEE-M-2023-2024",
            "txt_name": "GPX V2 M EPEE", "enum_type": "PPW", "num_multiplier": 1.0,
            "dt_tournament": "2023-11-18", "int_participant_count": 8,
            "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V2",
            "url_results": "https://example.com/r/100",
            "enum_import_status": "SCORED", "txt_import_status_reason": None,
            "bool_joint_pool_split": False, "enum_parser_kind": "FTL",
            "dt_last_scraped": "2026-05-03T10:00:00Z",
            "txt_source_url_used": "https://example.com/r/100",
        }],
        results=[
            {"id_fencer": 999, "id_tournament": 100, "int_place": 4,
             "num_final_score": 12.3, "num_match_confidence": 1.0,
             "enum_match_method": "AUTO_MATCH",
             "txt_scraped_name": "BURLIKOWSKI Bartosz"},
        ],
        fencers=[
            {"id_fencer": 999, "txt_surname": "BURLIKOWSKI", "txt_first_name": "Bartosz",
             "int_birth_year": 1974, "enum_gender": "M",
             "txt_nationality": "PL"},
        ],
    )

    n = phase5_runner._append_event_to_seed(db, "GPX-2023-2024")
    assert n > 0

    out_path = tmp_path / "supabase" / "seed_phase5_increments.sql"
    assert out_path.exists()
    sql = out_path.read_text()

    # The fencer INSERT must appear, with ON CONFLICT DO NOTHING.
    assert "INSERT INTO tbl_fencer" in sql, "missing fencer INSERT"
    assert "BURLIKOWSKI" in sql
    assert "Bartosz" in sql
    assert "1974" in sql
    assert "ON CONFLICT" in sql, "fencer INSERT must be idempotent"


def test_seed_export_strips_leading_trailing_whitespace(tmp_path, monkeypatch):
    # 5.13.2 — defence in depth: even if the DB row has '  Bartosz' (leading space
    # corruption from the legacy window.prompt flow), the emitted SQL is sanitised.
    from python.tools import phase5_runner

    monkeypatch.chdir(tmp_path)

    db = _make_mock_db(
        event_id=42,
        tournaments=[{
            "id_tournament": 100, "txt_code": "GPX-V2-EPEE-M-2023-2024",
            "txt_name": "x", "enum_type": "PPW", "num_multiplier": 1.0,
            "dt_tournament": "2023-11-18", "int_participant_count": 1,
            "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V2",
            "url_results": None, "enum_import_status": "SCORED",
            "txt_import_status_reason": None, "bool_joint_pool_split": False,
            "enum_parser_kind": "FTL", "dt_last_scraped": None,
            "txt_source_url_used": None,
        }],
        results=[
            {"id_fencer": 999, "id_tournament": 100, "int_place": 4,
             "num_final_score": None, "num_match_confidence": 1.0,
             "enum_match_method": "AUTO_MATCH", "txt_scraped_name": "BURLIKOWSKI Bartosz"},
        ],
        fencers=[
            # Corrupted row: leading space on first_name + trailing on surname
            {"id_fencer": 999, "txt_surname": "BURLIKOWSKI ",
             "txt_first_name": " Bartosz", "int_birth_year": 1974,
             "enum_gender": "M", "txt_nationality": "PL"},
        ],
    )

    phase5_runner._append_event_to_seed(db, "GPX-2023-2024")
    sql = (tmp_path / "supabase" / "seed_phase5_increments.sql").read_text()

    # The emitted SQL must use the trimmed values for both the fencer INSERT
    # and the result-row sub-SELECT lookup. Specifically it MUST NOT contain
    # the leading-space form ' Bartosz' as a quoted SQL literal.
    assert "' Bartosz'" not in sql, "leading-space first_name must be stripped"
    assert "'BURLIKOWSKI '" not in sql, "trailing-space surname must be stripped"
    assert "'Bartosz'" in sql
    assert "'BURLIKOWSKI'" in sql


def test_seed_export_dedupes_repeat_fencers_within_event(tmp_path, monkeypatch):
    # 5.13.3 — two results for the same fencer in the same event → one fencer INSERT
    from python.tools import phase5_runner

    monkeypatch.chdir(tmp_path)

    db = _make_mock_db(
        event_id=42,
        tournaments=[
            {"id_tournament": 100, "txt_code": "GPX-V2-EPEE-M",
             "txt_name": "x", "enum_type": "PPW", "num_multiplier": 1.0,
             "dt_tournament": "2023-11-18", "int_participant_count": 1,
             "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V2",
             "url_results": None, "enum_import_status": "SCORED",
             "txt_import_status_reason": None, "bool_joint_pool_split": False,
             "enum_parser_kind": "FTL", "dt_last_scraped": None,
             "txt_source_url_used": None},
            {"id_tournament": 101, "txt_code": "GPX-V2-FOIL-M",
             "txt_name": "y", "enum_type": "PPW", "num_multiplier": 1.0,
             "dt_tournament": "2023-11-18", "int_participant_count": 1,
             "enum_weapon": "FOIL", "enum_gender": "M", "enum_age_category": "V2",
             "url_results": None, "enum_import_status": "SCORED",
             "txt_import_status_reason": None, "bool_joint_pool_split": False,
             "enum_parser_kind": "FTL", "dt_last_scraped": None,
             "txt_source_url_used": None},
        ],
        results=[
            {"id_fencer": 999, "id_tournament": 100, "int_place": 4,
             "num_final_score": None, "num_match_confidence": 1.0,
             "enum_match_method": "AUTO_MATCH", "txt_scraped_name": "X Y"},
            {"id_fencer": 999, "id_tournament": 101, "int_place": 6,
             "num_final_score": None, "num_match_confidence": 1.0,
             "enum_match_method": "AUTO_MATCH", "txt_scraped_name": "X Y"},
        ],
        fencers=[
            {"id_fencer": 999, "txt_surname": "X", "txt_first_name": "Y",
             "int_birth_year": 1974, "enum_gender": "M", "txt_nationality": "PL"},
        ],
    )

    phase5_runner._append_event_to_seed(db, "GPX-2023-2024")
    sql = (tmp_path / "supabase" / "seed_phase5_increments.sql").read_text()
    # Exactly one fencer INSERT for this event (deduped)
    assert sql.count("INSERT INTO tbl_fencer") == 1


def test_seed_export_includes_birth_year_and_gender(tmp_path, monkeypatch):
    # 5.13.4 — the fencer INSERT MUST carry int_birth_year + enum_gender (both
    # FK-required by the V-cat trigger). txt_nationality defaults to PL when null.
    from python.tools import phase5_runner

    monkeypatch.chdir(tmp_path)

    db = _make_mock_db(
        event_id=42,
        tournaments=[{
            "id_tournament": 100, "txt_code": "GPX-V2-EPEE-M",
            "txt_name": "x", "enum_type": "PPW", "num_multiplier": 1.0,
            "dt_tournament": "2023-11-18", "int_participant_count": 1,
            "enum_weapon": "EPEE", "enum_gender": "M", "enum_age_category": "V2",
            "url_results": None, "enum_import_status": "SCORED",
            "txt_import_status_reason": None, "bool_joint_pool_split": False,
            "enum_parser_kind": "FTL", "dt_last_scraped": None,
            "txt_source_url_used": None,
        }],
        results=[
            {"id_fencer": 999, "id_tournament": 100, "int_place": 4,
             "num_final_score": None, "num_match_confidence": 1.0,
             "enum_match_method": "AUTO_MATCH", "txt_scraped_name": "X Y"},
        ],
        fencers=[
            {"id_fencer": 999, "txt_surname": "X", "txt_first_name": "Y",
             "int_birth_year": 1974, "enum_gender": "F", "txt_nationality": None},
        ],
    )

    phase5_runner._append_event_to_seed(db, "GPX-2023-2024")
    sql = (tmp_path / "supabase" / "seed_phase5_increments.sql").read_text()
    assert "1974" in sql
    assert "'F'" in sql
    # NULL nationality should fall back to PL
    assert "'PL'" in sql
