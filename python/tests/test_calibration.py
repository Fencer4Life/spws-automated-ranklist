"""
M2 Acceptance Tests (RED phase): Calibration scripts — tests 2.19–2.25.

These tests verify the Python calibration CLI tools:
- calibrate_compare.py: Compare DB scores vs Excel reference
- calibrate_config.py: Export/import scoring config via Supabase RPC
"""

import json
from pathlib import Path

import pytest


# ---------------------------------------------------------------------------
# 2.19  calibrate_compare: matching data → success message
# ---------------------------------------------------------------------------
def test_compare_matching_data_reports_success(capsys):
    """When DB and Excel scores match within tolerance, print success."""
    from python.calibration.calibrate_compare import compare

    excel_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.23},
        "KOWALSKI Jan": {"PPW1": 95.50},
    }
    db_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.23},
        "KOWALSKI Jan": {"PPW1": 95.50},
    }

    compare(excel_scores, db_scores, tolerance=0.01)
    captured = capsys.readouterr()
    assert "match" in captured.out.lower() or "0 mismatches" in captured.out.lower()


# ---------------------------------------------------------------------------
# 2.20  calibrate_compare: deliberate mismatch → reported
# ---------------------------------------------------------------------------
def test_compare_mismatch_reported(capsys):
    """A 0.05 mismatch with tolerance 0.01 should be reported."""
    from python.calibration.calibrate_compare import compare

    excel_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.23},
    }
    db_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.28},  # diff = 0.05 > 0.01
    }

    compare(excel_scores, db_scores, tolerance=0.01)
    captured = capsys.readouterr()
    assert "mismatch" in captured.out.lower() or "ATANASSOW" in captured.out


# ---------------------------------------------------------------------------
# 2.21  calibrate_compare: mismatch within tolerance → no report
# ---------------------------------------------------------------------------
def test_compare_within_tolerance_no_report(capsys):
    """A 0.005 mismatch with tolerance 0.01 should NOT be reported."""
    from python.calibration.calibrate_compare import compare

    excel_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.23},
    }
    db_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.235},  # diff = 0.005 < 0.01
    }

    compare(excel_scores, db_scores, tolerance=0.01)
    captured = capsys.readouterr()
    assert "match" in captured.out.lower() or "0 mismatches" in captured.out.lower()


# ---------------------------------------------------------------------------
# 2.22  calibrate_compare: fencer in Excel but missing from DB
# ---------------------------------------------------------------------------
def test_compare_missing_fencer_in_db(capsys):
    """Fencer in Excel but not in DB → MISSING_IN_DB."""
    from python.calibration.calibrate_compare import compare

    excel_scores = {
        "GHOST Fencer": {"PPW1": 50.00},
    }
    db_scores = {}

    compare(excel_scores, db_scores, tolerance=0.01)
    captured = capsys.readouterr()
    assert "MISSING_IN_DB" in captured.out


# ---------------------------------------------------------------------------
# 2.23  calibrate_compare: tournament score in Excel but missing from DB
# ---------------------------------------------------------------------------
def test_compare_missing_score_in_db(capsys):
    """Tournament score in Excel but not in DB → MISSING_SCORE."""
    from python.calibration.calibrate_compare import compare

    excel_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.23, "PPW2": 80.00},
    }
    db_scores = {
        "ATANASSOW Aleksander": {"PPW1": 119.23},
        # PPW2 missing
    }

    compare(excel_scores, db_scores, tolerance=0.01)
    captured = capsys.readouterr()
    assert "MISSING_SCORE" in captured.out


# ---------------------------------------------------------------------------
# 2.24  calibrate_config: export writes valid JSON
# ---------------------------------------------------------------------------
def test_config_export_writes_json(tmp_path, monkeypatch):
    """calibrate_config.py export should write a valid JSON file."""
    from python.calibration.calibrate_config import export_config

    output_file = tmp_path / "test_config.json"

    # Mock the Supabase client
    class MockRPCResult:
        data = {
            "id_season": 1,
            "season_code": "SPWS-2024-2025",
            "mp_value": 50,
            "podium_gold": 3,
            "podium_silver": 2,
            "podium_bronze": 1,
            "ppw_multiplier": 1.0,
            "ppw_best_count": 4,
            "ppw_total_rounds": 5,
            "mpw_multiplier": 1.2,
            "mpw_droppable": True,
            "pew_multiplier": 1.0,
            "pew_best_count": 3,
            "mew_multiplier": 2.0,
            "mew_droppable": True,
            "msw_multiplier": 2.0,
            "min_participants_evf": 5,
            "min_participants_ppw": 1,
            "extra": {},
        }

    class MockRPC:
        def execute(self):
            return MockRPCResult()

    class MockClient:
        def rpc(self, fn_name, params):
            return MockRPC()

    import python.calibration.calibrate_config as mod
    monkeypatch.setattr(mod, "sb", MockClient())

    export_config(season_id=1, output_path=output_file)

    assert output_file.exists()
    config = json.loads(output_file.read_text())
    assert config["mp_value"] == 50
    assert config["season_code"] == "SPWS-2024-2025"
    assert "ppw_multiplier" in config


# ---------------------------------------------------------------------------
# 2.25  calibrate_config: import reads JSON and calls RPC
# ---------------------------------------------------------------------------
def test_config_import_calls_rpc(tmp_path, monkeypatch):
    """calibrate_config.py import should read JSON and call the RPC."""
    from python.calibration.calibrate_config import import_config

    input_file = tmp_path / "test_config.json"
    input_file.write_text(json.dumps({"id_season": 1, "mp_value": 60}))

    rpc_calls = []

    class MockRPC:
        def execute(self):
            return type("Result", (), {"data": None})()

    class MockClient:
        def rpc(self, fn_name, params):
            rpc_calls.append((fn_name, params))
            return MockRPC()

    import python.calibration.calibrate_config as mod
    monkeypatch.setattr(mod, "sb", MockClient())

    import_config(input_path=input_file)

    assert len(rpc_calls) == 1
    assert rpc_calls[0][0] == "fn_import_scoring_config"
    assert rpc_calls[0][1]["p_config"]["id_season"] == 1
    assert rpc_calls[0][1]["p_config"]["mp_value"] == 60
