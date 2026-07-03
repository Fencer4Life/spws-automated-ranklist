"""
Plan-test-ID 5.M4 (ADR-066): get_min_participants helper resolves the
season-scoped threshold for ingestion.

Reads `tbl_scoring_config.int_min_participants_ppw` for PPW/MPW types
and `int_min_participants_evf` for PEW/MEW/MSW types. Default to 1 if
no config row exists for the season (back-compat for orphan tournaments).

PSW classification: per the SPWS domain (Mistrzostwa Szkolne — school
events organized by SPWS), PSW falls under the domestic `_ppw`
threshold. (See ADR-066 for the per-type → column mapping table.)
"""

from __future__ import annotations

from unittest.mock import MagicMock


def _stub_db_with_config(rows: list[dict]):
    """Build a minimal DbConnector that returns `rows` from
    tbl_scoring_config when queried by id_season."""
    db = MagicMock()
    table = MagicMock()
    select = MagicMock()
    eq = MagicMock()
    eq.execute.return_value = MagicMock(data=rows)
    select.eq.return_value = eq
    table.select.return_value = select
    db._sb.table.return_value = table
    return db


def test_5_M4_1_ppw_type_reads_ppw_column():
    """5.M4.1 — PPW reads int_min_participants_ppw."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    assert get_min_participants(db, id_season=3, tourn_type="PPW") == 1


def test_5_M4_2_mpw_type_reads_ppw_column():
    """5.M4.2 — MPW also reads the _ppw column (domestic championship)."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 2,
                "int_min_participants_evf": 5,
            }
        ]
    )
    assert get_min_participants(db, id_season=3, tourn_type="MPW") == 2


def test_5_M4_3_pew_type_reads_evf_column():
    """5.M4.3 — PEW reads int_min_participants_evf."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    assert get_min_participants(db, id_season=3, tourn_type="PEW") == 5


def test_5_M4_4_mew_msw_use_evf_column():
    """5.M4.4 — MEW + MSW (international championships) use _evf."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    assert get_min_participants(db, id_season=3, tourn_type="MEW") == 5
    assert get_min_participants(db, id_season=3, tourn_type="MSW") == 5


def test_5_M4_5_psw_uses_ppw_column():
    """5.M4.5 — PSW (school championships, SPWS-organized domestic) uses _ppw."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    assert get_min_participants(db, id_season=3, tourn_type="PSW") == 1


def test_5_M4_6_missing_config_defaults_to_1():
    """5.M4.6 — orphan season (no scoring config row) defaults to 1.
    Conservative default: include rather than exclude."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_config([])
    assert get_min_participants(db, id_season=999, tourn_type="PPW") == 1


def test_5_M4_7_unknown_tournament_type_defaults_to_1():
    """5.M4.7 — unrecognised type → default 1 (don't filter what we
    don't classify)."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 5,
                "int_min_participants_evf": 5,
            }
        ]
    )
    assert get_min_participants(db, id_season=3, tourn_type="UNKNOWN") == 1


# ---------------------------------------------------------------------------
# 5.M5 — gate_below_min_participants combines the helper + skip decision
# ---------------------------------------------------------------------------


def test_5_M5_1_n_below_threshold_returns_skip_true():
    """5.M5.1 — n=0, threshold=1 → skip with BELOW_MIN_PARTICIPANTS reason."""
    from python.pipeline.db_connector import gate_below_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    skip, reason = gate_below_min_participants(
        db,
        id_season=3,
        tourn_type="PPW",
        n_results=0,
    )
    assert skip is True
    assert reason is not None
    assert "BELOW_MIN_PARTICIPANTS" in reason
    assert "n=0" in reason and "min=1" in reason


def test_5_M5_2_n_equal_threshold_returns_keep():
    """5.M5.2 — n=1, threshold=1 → keep (strict less-than semantics)."""
    from python.pipeline.db_connector import gate_below_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    skip, reason = gate_below_min_participants(
        db,
        id_season=3,
        tourn_type="PPW",
        n_results=1,
    )
    assert skip is False
    assert reason is None


def test_5_M5_3_n_above_threshold_returns_keep():
    """5.M5.3 — n=10, threshold=1 → keep."""
    from python.pipeline.db_connector import gate_below_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    skip, reason = gate_below_min_participants(
        db,
        id_season=3,
        tourn_type="PPW",
        n_results=10,
    )
    assert skip is False


def test_5_M5_4_threshold_2_skips_n_1_brackets():
    """5.M5.4 — threshold=2, n=1 → skip (the 'exclude single-competitor'
    semantics requested in the user spec)."""
    from python.pipeline.db_connector import gate_below_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 2,
                "int_min_participants_evf": 5,
            }
        ]
    )
    skip, reason = gate_below_min_participants(
        db,
        id_season=3,
        tourn_type="PPW",
        n_results=1,
    )
    assert skip is True
    assert reason is not None
    assert "n=1" in reason and "min=2" in reason


def test_5_M5_5_pew_uses_evf_column():
    """5.M5.5 — PEW with n=4 + evf threshold=5 → skip (ADR-066 routing)."""
    from python.pipeline.db_connector import gate_below_min_participants

    db = _stub_db_with_config(
        [
            {
                "int_min_participants_ppw": 1,
                "int_min_participants_evf": 5,
            }
        ]
    )
    skip, reason = gate_below_min_participants(
        db,
        id_season=3,
        tourn_type="PEW",
        n_results=4,
    )
    assert skip is True
    assert reason is not None
    assert "min=5" in reason


# ---------------------------------------------------------------------------
# 5.M6 — derive_tourn_type_from_event_code maps event txt_code → type
# ---------------------------------------------------------------------------


def test_5_M6_1_ppw_event_code_maps_to_ppw():
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    assert derive_tourn_type_from_event_code("PPW1-2025-2026") == "PPW"
    assert derive_tourn_type_from_event_code("PPW5-2024-2025") == "PPW"


def test_5_M6_2_mpw_event_code_maps_to_mpw():
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    assert derive_tourn_type_from_event_code("MPW-2025-2026") == "MPW"


def test_5_M6_3_pew_with_letter_suffix_maps_to_pew():
    """PEW codes per ADR-046 carry letter suffix (e.g. PEW3fs-2024-2025)."""
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    assert derive_tourn_type_from_event_code("PEW3fs-2024-2025") == "PEW"
    assert derive_tourn_type_from_event_code("PEW1efs-2025-2026") == "PEW"


def test_5_M6_4_mew_imew_dmew_routing():
    """MEW (international individual) → MEW; IMEW alternation → also MEW;
    DMEW (international team) → MPW (team-championship semantics)."""
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    assert derive_tourn_type_from_event_code("MEW-2024-2025") == "MEW"
    assert derive_tourn_type_from_event_code("IMEW-2024-2025") == "MEW"
    assert derive_tourn_type_from_event_code("DMEW-2024-2025") == "MPW"


def test_5_M6_5_msw_imsw_routing():
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    assert derive_tourn_type_from_event_code("MSW-2024-2025") == "MSW"
    assert derive_tourn_type_from_event_code("IMSW-2024-2025") == "MSW"


def test_5_M6_6_psw_routing():
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    assert derive_tourn_type_from_event_code("PSW-2025-2026") == "PSW"


def test_5_M6_7_unknown_returns_none():
    from python.pipeline.db_connector import derive_tourn_type_from_event_code

    assert derive_tourn_type_from_event_code("WEIRD-2025-2026") is None
    assert derive_tourn_type_from_event_code("") is None
