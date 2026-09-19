"""
Plan-test-ID 5.M4 (ADR-066): get_min_participants helper resolves the
season-scoped threshold for ingestion.

Reads `tbl_scoring_config.int_min_participants_ppw` for PPW/MPW types
and `int_min_participants_evf` for PEW/MEW/MSW types.

REVERSED 2026-09-19 (versioned season scoring, design §07). This helper used
to return 1 — include everything — for an unrecognised tournament type and for
a season with no scoring config at all. That is failing OPEN: a missing
configuration let every bracket through instead of stopping it, and
`derive_tourn_type_from_event_code` returns None for an unmatched event code,
which landed on the same fallback. Both now raise
`UnconfiguredTournamentType`. The SQL side gained the mirror-image gate at the
same time (`fn_get_min_participants`, SS26.TYPE.03).

PSW classification: per the SPWS domain (Mistrzostwa Szkolne — school
events organized by SPWS), PSW falls under the domestic `_ppw`
threshold. (See ADR-066 for the per-type → column mapping table.)
"""

from __future__ import annotations

from unittest.mock import MagicMock


def _stub_db_with_threshold(threshold: int | str | None):
    """A DbConnector whose fn_get_min_participants RPC returns `threshold`.

    Typed to accept `str` as well as `int` because PostgREST is free to hand
    back either for a numeric column, which is why the helper coerces.

    `None` stands for the season/type pair having no configured row. The real
    RPC raises in that case; both shapes are covered — this one by the explicit
    None-data check in the helper, and the raising shape by
    `_stub_db_that_raises` below.
    """
    db = MagicMock()
    rpc = MagicMock()
    rpc.execute.return_value = MagicMock(data=threshold)
    db._sb.rpc.return_value = rpc
    return db


def _stub_db_that_raises(message: str):
    """A DbConnector whose RPC raises, as PostgREST does when the SQL function
    itself raises."""
    db = MagicMock()
    rpc = MagicMock()
    rpc.execute.side_effect = RuntimeError(message)
    db._sb.rpc.return_value = rpc
    return db


def _rpc_args(db):
    """The arguments the helper passed to the RPC."""
    return db._sb.rpc.call_args[0]


def test_5_M4_1_delegates_to_the_rpc_with_season_and_type():
    """5.M4.1 — the helper passes the season and the type straight through.

    REPURPOSED 2026-09-19. This and 5.M4.2-5.M4.5 used to assert which COLUMN
    each tournament type read. That routing no longer lives in Python: it is
    written down once in SQL (fn_sync_scoring_type_config) and asserted there by
    SS26.TYPE.02, because it is not what the column names suggest — PSW is
    domestic and takes the _ppw threshold. What is worth pinning here is that
    Python adds no routing of its own and simply delegates.
    """
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_threshold(1)
    assert get_min_participants(db, id_season=3, tourn_type="PPW") == 1
    name, params = _rpc_args(db)
    assert name == "fn_get_min_participants"
    assert params == {"p_id_season": 3, "p_type": "PPW"}


def test_5_M4_2_every_type_reaches_the_rpc_unaltered():
    """5.M4.2 — no type is special-cased on the way out."""
    from python.pipeline.db_connector import get_min_participants

    for ttype in ("PPW", "MPW", "PSW", "PEW", "MEW", "MSW"):
        db = _stub_db_with_threshold(7)
        assert get_min_participants(db, id_season=3, tourn_type=ttype) == 7
        assert _rpc_args(db)[1]["p_type"] == ttype


def test_5_M4_3_threshold_is_returned_as_an_int():
    """5.M4.3 — the RPC's value is what the caller gets, coerced to int."""
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_threshold("5")
    assert get_min_participants(db, id_season=3, tourn_type="PEW") == 5


def test_5_M4_4_psw_is_not_reclassified_in_python():
    """5.M4.4 — PSW is domestic (ADR-066) and takes the _ppw threshold, but that
    is SQL's business. Python must not second-guess it: the type goes out as
    written and whatever comes back is used.
    """
    from python.pipeline.db_connector import get_min_participants

    db = _stub_db_with_threshold(1)
    assert get_min_participants(db, id_season=3, tourn_type="PSW") == 1
    assert _rpc_args(db)[1]["p_type"] == "PSW"


def test_5_M4_5_transport_errors_are_not_reported_as_misconfiguration():
    """5.M4.5 — NEW. The helper translates the SQL function's own "no scoring
    configuration" error into UnconfiguredTournamentType. Anything else — a
    dropped connection, a timeout — must propagate untouched, or a transient
    outage would read as a configuration problem and be "fixed" in the wrong
    place.
    """
    import pytest

    from python.pipeline.db_connector import (
        UnconfiguredTournamentType,
        get_min_participants,
    )

    db = _stub_db_that_raises("connection reset by peer")
    with pytest.raises(RuntimeError) as exc:
        get_min_participants(db, id_season=3, tourn_type="PPW")
    assert not isinstance(exc.value, UnconfiguredTournamentType)

    db = _stub_db_that_raises("No scoring configuration for tournament type PPS in season 4")
    with pytest.raises(UnconfiguredTournamentType):
        get_min_participants(db, id_season=4, tourn_type="PPS")


def test_5_M4_6_missing_config_raises():
    """5.M4.6 — a season with no scoring config row RAISES (was: defaulted to 1).

    Reversed 2026-09-19: "include rather than exclude" is the wrong default when
    the thing missing is the configuration itself. A season with no config has
    not been set up, and scoring it would award points under rules nobody chose.
    """
    import pytest

    from python.pipeline.db_connector import (
        UnconfiguredTournamentType,
        get_min_participants,
    )

    db = _stub_db_with_threshold(None)
    with pytest.raises(UnconfiguredTournamentType):
        get_min_participants(db, id_season=999, tourn_type="PPW")


def test_5_M4_7_unknown_tournament_type_raises():
    """5.M4.7 — an unrecognised type RAISES (was: defaulted to 1).

    Reversed 2026-09-19. "Don't filter what we don't classify" reads as caution
    but behaves as the opposite: PPS and MPS are unclassified here until their
    settings exist, so the old default would have admitted every PZSz senior
    bracket ungated. Design §07 requires ingestion to raise instead.
    """
    import pytest

    from python.pipeline.db_connector import (
        UnconfiguredTournamentType,
        get_min_participants,
    )

    db = _stub_db_with_threshold(None)
    with pytest.raises(UnconfiguredTournamentType):
        get_min_participants(db, id_season=3, tourn_type="UNKNOWN")


def test_5_M4_8_none_tournament_type_raises():
    """5.M4.8 — NEW. `derive_tourn_type_from_event_code` returns None for an
    unmatched event code, which previously landed on the same fail-open
    fallback. None is the commonest way this helper is reached with nothing to
    classify, so it gets its own assertion.
    """
    import pytest

    from python.pipeline.db_connector import (
        UnconfiguredTournamentType,
        get_min_participants,
    )

    db = _stub_db_with_threshold(None)
    with pytest.raises(UnconfiguredTournamentType):
        get_min_participants(db, id_season=3, tourn_type=None)


# ---------------------------------------------------------------------------
# 5.M5 — gate_below_min_participants combines the helper + skip decision
# ---------------------------------------------------------------------------


def test_5_M5_1_n_below_threshold_returns_skip_true():
    """5.M5.1 — n=0, threshold=1 → skip with BELOW_MIN_PARTICIPANTS reason."""
    from python.pipeline.db_connector import gate_below_min_participants

    db = _stub_db_with_threshold(1)
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

    db = _stub_db_with_threshold(1)
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

    db = _stub_db_with_threshold(1)
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

    db = _stub_db_with_threshold(2)
    skip, reason = gate_below_min_participants(
        db,
        id_season=3,
        tourn_type="PPW",
        n_results=1,
    )
    assert skip is True
    assert reason is not None
    assert "n=1" in reason and "min=2" in reason


def test_5_M5_5_pew_below_its_threshold_is_skipped():
    """5.M5.5 — PEW with n=4 against a threshold of 5 → skip.

    Renamed 2026-09-19: the column this once named is no longer what the gate
    reads. Which threshold applies to PEW is SQL's business now (SS26.TYPE.02);
    what this pins is that the gate is strict less-than and reports the bound.
    """
    from python.pipeline.db_connector import gate_below_min_participants

    db = _stub_db_with_threshold(5)
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
