"""LOCALSL.01–04 — LOCAL takes CERT's stored PZSz start lists (D4 A).

LOCAL has no PZSz start lists after a mirror: they are CERT's stored inputs
(ADR-112), not PROD's seed, so a LOCAL PZSz ingest stopped or, copied by hand
out of order, read an older version (25 Oct 2026, PPS1e). The mirror now
copies them: CERT's rows are read inside a read-only transaction, in CERT's
id order, and replayed through LOCAL's own fn_pzsz_start_list_store, so the
newest version of every list — the one the ingest reads — is CERT's newest.

The starters here are synthetic.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest

from python.pipeline.promotion import refresh as rf
from python.tools import mirror_start_lists as msl

ROOT = Path(__file__).resolve().parents[2]


def _row(id_, event, weapon, gender, sha, starters):
    return {
        "id_pzsz_start_list": id_,
        "id_pzsz_event": event,
        "id_pzsz_tournament": event * 10,
        "enum_weapon": weapon,
        "enum_gender": gender,
        "txt_sha256": sha,
        "jsonb_starters": starters,
        "txt_source": "pzszerm",
    }


CERT_ROWS = [
    _row(7, 4596, "EPEE", "M", "a" * 64, [["Wzorcowy Jan", 1971]]),
    _row(9, 4596, "EPEE", "F", "b" * 64, [["Próbna Anna", 1980]]),
    _row(12, 4596, "EPEE", "M", "c" * 64, [["Wzorcowy Jan", 1971], ["Szybki Adam", 2004]]),
]


class _Cert:
    read_only = True

    def __init__(self, newest: dict[str, str]):
        self.newest = newest
        self.sql: list[str] = []

    def fetch_json(self, sql: str) -> Any:
        self.sql.append(sql)
        if "DISTINCT ON" in sql:
            return self.newest
        return CERT_ROWS


class _Local:
    read_only = False

    def __init__(self, newest: dict[str, str]):
        self.newest = newest
        self.stored: list[str] = []

    def fetch_json(self, sql: str) -> Any:
        if "DISTINCT ON" in sql:
            return self.newest
        assert "fn_pzsz_start_list_store(" in sql, sql[:80]
        self.stored.append(sql)
        return {"stored": True}


NEWEST = {"4596/EPEE/M": "c" * 64, "4596/EPEE/F": "b" * 64}


class TestCopy:
    def test_cert_rows_are_replayed_in_cert_id_order(self):
        """LOCALSL.01: every CERT row goes through LOCAL's store function, in
        CERT's id order, so the newest version stays the newest."""
        cert, local = _Cert(NEWEST), _Local(NEWEST)
        out = msl.copy_start_lists(cert, local)
        assert "ORDER BY l.id_pzsz_start_list" in cert.sql[0]
        assert ["a" * 64 in s for s in local.stored] == [True, False, False]
        assert ["c" * 64 in s for s in local.stored] == [False, False, True]
        assert out == {"read": 3, "stored": 3, "lists": 2}

    def test_a_newest_version_that_differs_from_certs_fails(self):
        """LOCALSL.02: the copy is checked, list by list, against CERT's newest."""
        cert, local = _Cert(NEWEST), _Local({"4596/EPEE/M": "a" * 64, "4596/EPEE/F": "b" * 64})
        with pytest.raises(rf.RefreshError, match="4596/EPEE/M"):
            msl.copy_start_lists(cert, local)

    def test_cert_is_read_only_and_local_the_only_target(self):
        """LOCALSL.03: CERT through a read-only transport; LOCAL only."""
        writable = _Cert(NEWEST)
        writable.read_only = False
        with pytest.raises(rf.RefreshError, match="read-only"):
            msl.copy_start_lists(writable, _Local(NEWEST))
        reader = _Local(NEWEST)
        reader.read_only = True
        with pytest.raises(rf.RefreshError, match="LOCAL"):
            msl.copy_start_lists(_Cert(NEWEST), reader)


def test_the_mirror_copies_the_start_lists_after_the_registrations():
    """LOCALSL.04: scripts/mirror-prod-local.sh runs the copy as its last step."""
    script = (ROOT / "scripts" / "mirror-prod-local.sh").read_text()
    registrations = script.index("--mode registrations")
    copy = script.index("python.tools.mirror_start_lists")
    assert copy > registrations
