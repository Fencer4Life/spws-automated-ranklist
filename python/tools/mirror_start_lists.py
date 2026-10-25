"""LOCAL takes CERT's stored PZSz start lists (D4 A).

The start lists are stored inputs on CERT (ADR-112), not part of PROD's seed,
so after `scripts/mirror-prod-local.sh` LOCAL holds none and a LOCAL PZSz
ingest cannot run. This copy reads CERT's rows inside a read-only transaction,
in CERT's id order, and replays each through LOCAL's own
`fn_pzsz_start_list_store`, so LOCAL keeps CERT's sequence of versions and the
newest version of every list — the one the ingest reads, the highest id — is
CERT's newest. It then checks exactly that, list by list.

READS CERT, WRITES ONLY LOCAL. Usage: python -m python.tools.mirror_start_lists
"""

from __future__ import annotations

import os
import sys
from typing import Any

from python.pipeline.promotion.refresh import (
    LocalTransport,
    ManagementTransport,
    RefreshError,
    Transport,
    _literal,
)
from python.tools._backends import CERT_REF

ROWS_SQL = (
    "SELECT coalesce(jsonb_agg(jsonb_build_object("
    "'id_pzsz_start_list', l.id_pzsz_start_list, 'id_pzsz_event', l.id_pzsz_event, "
    "'id_pzsz_tournament', l.id_pzsz_tournament, 'enum_weapon', l.enum_weapon, "
    "'enum_gender', l.enum_gender, 'txt_sha256', l.txt_sha256, "
    "'jsonb_starters', l.jsonb_starters, 'txt_source', l.txt_source) "
    "ORDER BY l.id_pzsz_start_list), '[]'::jsonb) AS j FROM tbl_pzsz_start_list l"
)
# The newest version of each list, keyed event/weapon/gender (ADR-112: the
# highest id is the newest).
NEWEST_SQL = (
    "SELECT coalesce(jsonb_object_agg(k, sha), '{}'::jsonb) AS j FROM ("
    "SELECT DISTINCT ON (id_pzsz_event, enum_weapon, enum_gender) "
    "id_pzsz_event || '/' || enum_weapon || '/' || enum_gender AS k, txt_sha256 AS sha "
    "FROM tbl_pzsz_start_list "
    "ORDER BY id_pzsz_event, enum_weapon, enum_gender, id_pzsz_start_list DESC) n"
)
_STORE_KEYS = (
    "id_pzsz_event",
    "id_pzsz_tournament",
    "enum_weapon",
    "enum_gender",
    "txt_sha256",
    "jsonb_starters",
    "txt_source",
)


def copy_start_lists(cert: Transport, local: Transport) -> dict[str, int]:
    """Replay CERT's start lists on LOCAL in CERT's order and check that every
    list's newest version equals CERT's."""
    if not getattr(cert, "read_only", False):
        raise RefreshError("CERT is read through a read-only transport only")
    if getattr(local, "read_only", True):
        raise RefreshError(
            "the start lists are written to LOCAL only, through a writable transport"
        )
    rows: list[dict[str, Any]] = list(cert.fetch_json(ROWS_SQL) or [])
    stored = 0
    for row in rows:
        payload = {k: row.get(k) for k in _STORE_KEYS}
        out = local.fetch_json(f"SELECT fn_pzsz_start_list_store({_literal(payload)}) AS j") or {}
        stored += 1 if out.get("stored") else 0
    want = dict(cert.fetch_json(NEWEST_SQL) or {})
    have = dict(local.fetch_json(NEWEST_SQL) or {})
    differ = sorted(k for k in set(want) | set(have) if want.get(k) != have.get(k))
    if differ:
        raise RefreshError(
            f"after the copy LOCAL's newest start list differs from CERT's for: {', '.join(differ)}"
        )
    return {"read": len(rows), "stored": stored, "lists": len(want)}


def main() -> int:
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not token:
        print("SUPABASE_ACCESS_TOKEN is required to read CERT", file=sys.stderr)
        return 1
    try:
        out = copy_start_lists(
            ManagementTransport(CERT_REF, token, read_only=True), LocalTransport()
        )
    except RefreshError as e:
        print(f"START LISTS STOPPED: {e}", file=sys.stderr)
        return 1
    print(
        f"start lists: {out['read']} version(s) read from CERT, {out['stored']} stored on LOCAL; "
        f"the newest of all {out['lists']} list(s) equals CERT's"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
