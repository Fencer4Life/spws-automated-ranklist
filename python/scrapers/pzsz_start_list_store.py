"""PZSz start lists as stored inputs (ADR-112).

pzszerm.pl puts a JavaScript cookie gate in front of its pages and switches it
on and off. Our client runs no JavaScript, so a start list read at the moment
of the ingest fails whenever the gate is on. Here a start list is captured on
a day pzszerm.pl serves it and stored in tbl_pzsz_start_list on CERT, as
printed name and birth year in page order, one insert-only row per version.

- The daily capture (`pzsz_sync --capture-start-lists`) and the CERT ingest
  call `capture_event_start_lists`.
- The CERT ingest reads the newest stored version (`newest_by_series`).
- Promote reads the version the CERT run used, by its hash (`from_row`
  checks each row against its hash).
- `store` stores pages a person saved from their own browser, through the
  same parsers.

Nothing here tries to get past the gate: a gated page refuses the capture,
and nothing is stored.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from python.pipeline.promotion.run_record import start_list_sha256
from python.scrapers.pzsz_start_list import (
    PZSZ_EVENT_PAGE,
    PzszPageError,
    PzszTournament,
    Starter,
    read_event_start_lists,
)

SOURCE_PZSZERM = "pzszerm.pl"
SOURCE_SAVED_PAGE = "saved page"

Store = Callable[[dict], bool]
Fetch = Callable[[str, dict], str]

_CODE = re.compile(r"^[A-Za-z0-9]+-\d{4}-\d{4}$")


class StoredStartListError(RuntimeError):
    """A stored start list cannot be used as it is."""


@dataclass(frozen=True)
class StoredStartList:
    """One stored version of a tournament's start list."""

    id_pzsz_event: int
    id_pzsz_tournament: int
    weapon: str
    gender: str
    starters: tuple[Starter, ...]
    sha256: str
    source: str
    captured: str | None = None


def fetch_page(url: str, params: dict) -> str:
    """One pzszerm.pl page as served, by a plain HTTP client. A JavaScript
    check page comes back as it is, and the readers refuse it."""
    import httpx

    with httpx.Client(timeout=30.0, follow_redirects=True) as http:
        resp = http.get(url, params=params)
        resp.raise_for_status()
        return resp.text


def stored_payloads(
    id_pzsz_event: int,
    lists: Mapping[tuple[str, str], tuple[PzszTournament, list[Starter]]],
    source: str,
) -> list[dict]:
    """The fn_pzsz_start_list_store payload of every start list of an event."""
    payloads = []
    for (weapon, gender), (tournament, starters) in sorted(lists.items()):
        payloads.append(
            {
                "id_pzsz_event": int(id_pzsz_event),
                "id_pzsz_tournament": tournament.id_pzsz_tournament,
                "enum_weapon": weapon,
                "enum_gender": gender,
                "txt_sha256": start_list_sha256(starters),
                "jsonb_starters": [[s.name, s.birth_year] for s in starters],
                "txt_source": source,
            }
        )
    return payloads


def capture_event_start_lists(
    id_pzsz_event: int, fetch: Fetch, store: Store, *, source: str = SOURCE_PZSZERM
) -> int:
    """Read every start list of a PZSz event and store each version that is
    new; returns how many were stored. Every page is read before anything is
    stored, so one page that cannot be read (the JavaScript check among them)
    stores nothing."""
    lists = read_event_start_lists(int(id_pzsz_event), fetch)
    return sum(bool(store(p)) for p in stored_payloads(id_pzsz_event, lists, source))


def store_saved_pages(
    id_pzsz_event: int, event_html: str, tournament_html: Mapping[int, str], store: Store
) -> int:
    """Store pages a person saved from their own browser: the event page and
    every individual tournament page it lists. A saved gate page, or a
    tournament without its page, refuses the lot."""

    def fetch(url: str, params: dict) -> str:
        if url == PZSZ_EVENT_PAGE:
            return event_html
        page = tournament_html.get(int(params["id"]))
        if page is None:
            raise PzszPageError(
                f"No saved page for PZSz tournament {params['id']}: every individual "
                "tournament the event page lists needs its page."
            )
        return page

    return capture_event_start_lists(id_pzsz_event, fetch, store, source=SOURCE_SAVED_PAGE)


def from_row(row: Mapping[str, Any]) -> StoredStartList:
    """A stored row as a start list, after checking its starters still hash
    to its recorded hash."""
    starters = tuple(Starter(str(name), int(year)) for name, year in row["jsonb_starters"])
    if start_list_sha256(starters) != row["txt_sha256"]:
        raise StoredStartListError(
            f"The stored start list {row.get('id_pzsz_start_list')} of PZSz event "
            f"{row['id_pzsz_event']} ({row['enum_weapon']}/{row['enum_gender']}) does not "
            "match its hash."
        )
    return StoredStartList(
        id_pzsz_event=int(row["id_pzsz_event"]),
        id_pzsz_tournament=int(row["id_pzsz_tournament"]),
        weapon=str(row["enum_weapon"]),
        gender=str(row["enum_gender"]),
        starters=starters,
        sha256=str(row["txt_sha256"]),
        source=str(row["txt_source"]),
        captured=None if row.get("ts_captured") is None else str(row["ts_captured"]),
    )


def newest_by_series(rows: Iterable[Mapping[str, Any]]) -> dict[tuple[str, str], StoredStartList]:
    """The newest stored version (highest id) for each weapon and gender."""
    newest: dict[tuple[str, str], Mapping[str, Any]] = {}
    for row in rows:
        key = (str(row["enum_weapon"]), str(row["enum_gender"]))
        if key not in newest or int(row["id_pzsz_start_list"]) > int(
            newest[key]["id_pzsz_start_list"]
        ):
            newest[key] = row
    return {key: from_row(row) for key, row in newest.items()}


def _jsonb(payload: Mapping[str, Any]) -> str:
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    return "'" + text.replace("'", "''") + "'::jsonb"


class ManagementStore:
    """tbl_pzsz_start_list over the Management API: the daily capture and the
    `store` command."""

    def __init__(self, ref: str, token: str, *, query: Callable[..., Any] | None = None):
        if query is None:
            from python.scrapers._supabase import _management_query

            query = _management_query
        self._ref = ref
        self._token = token
        self._query = query

    def store(self, payload: dict) -> bool:
        rows = self._query(
            self._ref, self._token, f"SELECT fn_pzsz_start_list_store({_jsonb(payload)}) AS r"
        )
        return bool(((rows or [{}])[0].get("r") or {}).get("stored"))

    def purge(self) -> int:
        rows = self._query(self._ref, self._token, "SELECT fn_pzsz_start_list_purge() AS n")
        return int((rows or [{}])[0].get("n") or 0)


def _store_command(args: argparse.Namespace) -> int:
    code = args.event_code
    if not _CODE.match(code):
        print(f"not an event code: {code!r}", file=sys.stderr)
        return 2
    ref = os.environ.get("SUPABASE_CERT_REF", "")
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not ref or not token:
        print("SUPABASE_CERT_REF and SUPABASE_ACCESS_TOKEN are required", file=sys.stderr)
        return 2
    from python.scrapers._supabase import _management_query

    found = _management_query(
        ref, token, f"SELECT id_pzsz_event FROM tbl_event WHERE txt_code = '{code}'"
    )
    if not found or found[0].get("id_pzsz_event") is None:
        print(f"{code} has no id_pzsz_event on CERT", file=sys.stderr)
        return 2
    tournaments: dict[int, str] = {}
    for pair in args.tournament:
        tid, _, path = pair.partition("=")
        tournaments[int(tid)] = Path(path).read_text(encoding="utf-8")
    event_html = Path(args.event_page).read_text(encoding="utf-8")
    store = ManagementStore(ref, token)
    stored = store_saved_pages(int(found[0]["id_pzsz_event"]), event_html, tournaments, store.store)
    print(f"{code}: {stored} new start-list version(s) stored from saved pages")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="PZSz start lists stored on CERT (ADR-112)")
    sub = parser.add_subparsers(dest="command", required=True)
    saved = sub.add_parser("store", help="store pages saved from a browser")
    saved.add_argument("event_code")
    saved.add_argument("--event-page", required=True, help="the saved PZSz event page")
    saved.add_argument(
        "--tournament",
        action="append",
        default=[],
        metavar="ID=FILE",
        help="a saved tournament page, by its PZSz tournament id (repeat for each)",
    )
    args = parser.parse_args(argv)
    return _store_command(args)


if __name__ == "__main__":
    raise SystemExit(main())
