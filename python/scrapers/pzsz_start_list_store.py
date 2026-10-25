"""PZSz start lists as stored inputs (ADR-112).

pzszerm.pl puts a JavaScript cookie gate in front of its pages and switches it
on and off. Our client runs no JavaScript, so a start list read at the moment
of the ingest fails whenever the gate is on. Here a start list is captured on
a day pzszerm.pl serves it and stored in tbl_pzsz_start_list on CERT, as
printed name and birth year in page order, one insert-only row per version.

- The scheduled capture (`pzsz-start-lists.yml`, the `capture` command here)
  reads every event in its window, D-4 to the morning of the event's last day
  (`capture_window`); the CERT ingest calls `capture_event_start_lists`.
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
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

from python.pipeline.promotion.lifecycle import WARSAW
from python.pipeline.promotion.run_record import start_list_sha256
from python.scrapers.pzsz_start_list import (
    PZSZ_EVENT_PAGE,
    PzszPageError,
    PzszTournament,
    Starter,
    in_start_list_window,
    read_event_start_lists,
    read_event_start_lists_for_capture,
    start_list_window,
)

SOURCE_PZSZERM = "pzszerm.pl"
SOURCE_SAVED_PAGE = "saved page"
ORGANIZER_CODE = "PZSz"

# Events whose start lists the capture never reads: already over or called off.
_NOT_CAPTURED = ("COMPLETED", "CANCELLED")

# How a weapon and gender read in a Telegram line ("men's foil").
_WEAPON_WORD = {"SABRE": "sabre", "EPEE": "épée", "FOIL": "foil"}
_GENDER_WORD = {"M": "men's", "F": "women's"}


def _wg(weapon: str, gender: str) -> str:
    return f"{_GENDER_WORD.get(gender, gender)} {_WEAPON_WORD.get(weapon, weapon.lower())}"


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


@dataclass(frozen=True)
class CaptureOutcome:
    """One attempt at one event: the lists stored new, the lists already held
    unchanged, the tournaments not read this attempt (each with weapon,
    gender, reason), whether the event page itself did not render, and any
    error note. All in weapon/gender terms, for the digest."""

    code: str
    id_pzsz_event: int
    first_day: date
    stored: list[tuple[str, str, int]]
    unchanged: list[tuple[str, str, int]]
    missing: list[tuple[str, str, str]]
    not_served: bool
    error: str | None
    # The event's last day: the window closes at its noon (K2 A). None is a
    # one-day event.
    last_day: date | None = None

    @property
    def window(self) -> tuple[date, date]:
        return start_list_window(self.first_day, self.last_day or self.first_day)


_DAILY_CRON = re.compile(r"(\d{1,2}) (\d{1,2}) \* \* \*")


def scheduled_moment(cron: str, now: datetime) -> datetime:
    """The moment a scheduled run was due (PZSZ.SL.10): the latest moment at or
    before ``now`` matching the cron's minute and hour in UTC, read in Warsaw.
    GitHub starts scheduled runs hours late (0.2-3.5 hours measured), so a run
    can start after midnight, or after noon, in Warsaw; it still works on the
    moment it was due, for both the window and its alarms. Pure."""
    match = _DAILY_CRON.fullmatch(cron.strip())
    if match is None:
        raise ValueError(f"not one daily UTC time: {cron!r}")
    minute, hour = int(match.group(1)), int(match.group(2))
    due = now.astimezone(UTC).replace(hour=hour, minute=minute, second=0, microsecond=0)
    if due > now:
        due -= timedelta(days=1)
    return due.astimezone(WARSAW)


def scheduled_day(cron: str, now: datetime) -> date:
    """The Warsaw date a scheduled run was due on (PZSZ.SL.10). Pure."""
    return scheduled_moment(cron, now).date()


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _days(row: Mapping[str, Any]) -> tuple[date, date]:
    """An event row's first and last day; no end date is a one-day event."""
    first = date.fromisoformat(str(row["dt_start"])[:10])
    end = row.get("dt_end")
    return first, date.fromisoformat(str(end)[:10]) if end not in (None, "") else first


def select_window_events(rows: Iterable[Mapping[str, Any]], due: datetime) -> list[dict]:
    """Check 1 of the window rule (ADR-112 §2): the PZSz events whose start
    lists this run reads — a PZSz id, not COMPLETED/CANCELLED, and the run due
    between D-4 and the morning of the event's last day (K2 A). Pure."""
    chosen: list[dict] = []
    for row in rows:
        if row.get("id_pzsz_event") is None or row.get("enum_status") in _NOT_CAPTURED:
            continue
        if row.get("dt_start") in (None, ""):
            continue
        if in_start_list_window(*_days(row), due):
            chosen.append(dict(row))
    return chosen


def _capture_one(
    row: Mapping[str, Any], due: datetime, fetch: Fetch, store: Store
) -> CaptureOutcome:
    code = str(row["txt_code"])
    eid = int(row["id_pzsz_event"])
    first_day, last_day = _days(row)
    try:
        result = read_event_start_lists_for_capture(
            eid, fetch, first_day=first_day, last_day=last_day, due=due
        )
    except Exception as exc:  # noqa: BLE001 -- one event never stops another (ADR-116 §11)
        return CaptureOutcome(
            code,
            eid,
            first_day,
            [],
            [],
            [],
            not_served=True,
            error=str(exc),
            last_day=last_day,
        )
    stored: list[tuple[str, str, int]] = []
    unchanged: list[tuple[str, str, int]] = []
    for (weapon, gender), (tournament, starters) in sorted(result.captured.items()):
        payload = stored_payloads(eid, {(weapon, gender): (tournament, starters)}, SOURCE_PZSZERM)[
            0
        ]
        is_new = store(payload)
        (stored if is_new else unchanged).append((weapon, gender, len(starters)))
    missing = [(t.weapon, t.gender, reason) for t, reason in result.missing]
    return CaptureOutcome(
        code,
        eid,
        first_day,
        stored,
        unchanged,
        missing,
        not_served=False,
        error=None,
        last_day=last_day,
    )


def capture_window(
    rows: Iterable[Mapping[str, Any]], due: datetime, fetch: Fetch, store: Store
) -> list[CaptureOutcome]:
    """Read and store the start lists of every in-window event, one event at a
    time; one event never stops another (ADR-116 §11). Returns an outcome per
    selected event."""
    return [_capture_one(row, due, fetch, store) for row in select_window_events(rows, due)]


@dataclass(frozen=True)
class WindowReport:
    """The digest of a capture run: the Telegram lines and the event codes
    that ended fatal (a start list missing after the window)."""

    lines: list[str]
    fatal: list[str]


def window_report(
    outcomes: Iterable[CaptureOutcome],
    *,
    due: datetime,
    first_run: bool,
    last_attempt: bool,
    stored_keys: Mapping[int, set[tuple[str, str]]],
) -> WindowReport:
    """Shape one capture run into Telegram lines and the fatal list (§10, §11).

    ``stored_keys`` is the (weapon, gender) pairs already stored for each event
    across the whole window — the ground truth for whether the ingest can run.
    A tournament the event is known to have but with nothing stored is fatal,
    but only on the window's last attempt: the run due before noon on the
    event's last day (K2 A). From D-1 until then a missing list is a warning,
    because a later attempt may still catch it."""
    lines: list[str] = []
    fatal: list[str] = []
    today = due.astimezone(WARSAW).date()
    for out in outcomes:
        opens, closes = out.window
        have = stored_keys.get(out.id_pzsz_event, set())
        if first_run and today == opens:
            lines.append(
                f"📋 Start-list window open for {out.code} ({out.first_day:%d %b}), "
                f"capturing to the morning of {closes:%d %b}."
            )
        if out.stored:
            counts = ", ".join(f"{_wg(w, g)} {n}" for w, g, n in out.stored)
            lines.append(f"✅ {out.code}: {counts} stored.")
        if out.not_served:
            lines.append(f"⚠️ {out.code}: start lists not served this run ({out.error}).")
        known = (
            {(w, g) for w, g, _ in out.stored}
            | {(w, g) for w, g, _ in out.unchanged}
            | {(w, g) for w, g, _ in out.missing}
            | set(have)
        )
        short = known - set(have)
        if last_attempt and today == closes:
            if short or not known:
                fatal.append(out.code)
                miss = ", ".join(sorted(_wg(w, g) for w, g in short)) or "every tournament"
                lines.append(
                    f"❌ No start list for {out.code} after the window ({miss}): "
                    "the result ingest will stop (ADR-111)."
                )
        elif short and today >= out.first_day - timedelta(days=1):
            miss = ", ".join(sorted(_wg(w, g) for w, g in short))
            lines.append(f"⚠️ {out.code}: still missing {miss}.")
    return WindowReport(lines, fatal)


def _stored_keys(
    query: Callable[..., list[dict]], ref: str, token: str, event_ids: Iterable[int]
) -> dict[int, set[tuple[str, str]]]:
    """The (weapon, gender) pairs already stored on CERT for each event, across
    the whole window — the ground truth for whether the ingest can run."""
    ids = sorted({int(e) for e in event_ids})
    if not ids:
        return {}
    in_list = ",".join(str(i) for i in ids)
    rows = query(
        ref,
        token,
        "SELECT DISTINCT id_pzsz_event, enum_weapon::TEXT AS enum_weapon, "
        f"enum_gender::TEXT AS enum_gender FROM tbl_pzsz_start_list WHERE id_pzsz_event IN ({in_list})",
    )
    out: dict[int, set[tuple[str, str]]] = {}
    for r in rows or []:
        out.setdefault(int(r["id_pzsz_event"]), set()).add(
            (str(r["enum_weapon"]), str(r["enum_gender"]))
        )
    return out


def run_capture(
    ref: str,
    token: str,
    bot_token: str,
    chat_id: str,
    *,
    due: datetime,
    first_run: bool = False,
    last_attempt: bool = False,
    query: Callable[..., list[dict]] | None = None,
    telegram: Callable[[str, str, str], None] | None = None,
    store: Store | None = None,
    fetch: Fetch | None = None,
    season: Mapping[str, Any] | None = None,
) -> int:
    """Capture every in-window event's start lists to CERT and send one digest
    (ADR-112 §2, ADR-116 §10-§11). Returns 0 (green, possibly with warnings) or
    1 if any event ended fatal. Raises only the start-fatal: no active season.

    The seams (``query``, ``telegram``, ``store``, ``fetch``, ``season``) have
    production defaults and exist so the orchestration is driven in tests
    without CERT or a browser. When ``fetch`` is not given, one headless
    Chromium renders every page of the run."""
    from python.scrapers._supabase import _management_query, _telegram

    query = query or _management_query
    telegram = telegram or _telegram
    if season is None:
        from python.scrapers._supabase import _get_active_season

        season = _get_active_season(ref, token, query)
    if season is None:
        raise RuntimeError("No active season on CERT: nothing to capture start lists for.")

    managed = ManagementStore(ref, token, query=query) if store is None else None
    store_fn: Store = store or managed.store  # type: ignore[union-attr]
    if managed is not None:
        print(
            f"start-list retention: {managed.purge()} version(s) outside the active season deleted"
        )

    rows = query(
        ref,
        token,
        "SELECT e.txt_code, e.id_pzsz_event, e.dt_start::TEXT AS dt_start, "
        "e.dt_end::TEXT AS dt_end, e.enum_status::TEXT AS enum_status FROM tbl_event e "
        "JOIN tbl_organizer o ON o.id_organizer = e.id_organizer "
        f"WHERE e.id_season = {int(season['id_season'])} AND o.txt_code = '{ORGANIZER_CODE}' "
        "AND e.id_pzsz_event IS NOT NULL ORDER BY e.dt_start, e.txt_code",
    )

    if fetch is not None:
        outcomes = capture_window(rows, due, fetch, store_fn)
    else:
        from python.scrapers.pzsz_browser import browser_fetch

        with browser_fetch() as browser:
            outcomes = capture_window(rows, due, browser, store_fn)

    stored_keys = _stored_keys(query, ref, token, [o.id_pzsz_event for o in outcomes])
    report = window_report(
        outcomes, due=due, first_run=first_run, last_attempt=last_attempt, stored_keys=stored_keys
    )
    for o in outcomes:
        note = " [not served]" if o.not_served else ""
        print(
            f"  {o.code}: {len(o.stored)} new, {len(o.unchanged)} unchanged, "
            f"{len(o.missing)} missing{note}"
        )
    if report.lines:
        telegram(bot_token, chat_id, "📋 <b>PZSz start lists</b>\n" + "\n".join(report.lines))
    return 1 if report.fatal else 0


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


def _capture_command(args: argparse.Namespace) -> int:
    """The scheduled capture (pzsz-start-lists.yml): capture every in-window
    event's start lists to CERT and send one digest. Catches the start-fatal so
    the run still reports red on Telegram rather than crashing silently."""
    ref = os.environ.get("SUPABASE_CERT_REF", "")
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    bot = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat = os.environ.get("TELEGRAM_CHAT_ID", "")
    if not ref or not token:
        print("SUPABASE_CERT_REF and SUPABASE_ACCESS_TOKEN are required", file=sys.stderr)
        return 2
    try:
        now = _now_utc()
        # A scheduled run works on the moment it was due, a manual run on now (PZSZ.SL.11).
        due = scheduled_moment(args.cron, now) if args.cron else now.astimezone(WARSAW)
        print(
            f"capture for {due:%Y-%m-%d %H:%M} Warsaw (cron {args.cron or 'none: manual run'})",
            file=sys.stderr,
        )
        return run_capture(
            ref,
            token,
            bot,
            chat,
            due=due,
            first_run=args.first_run,
            last_attempt=args.last_attempt,
        )
    except Exception as exc:  # noqa: BLE001 -- start-fatal: report red, do not crash
        from python.scrapers._supabase import _telegram

        _telegram(bot, chat, f"❌ <b>PZSz start-list capture failed</b>\n{exc}")
        print(f"capture failed: {exc}", file=sys.stderr)
        return 1


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
    cap = sub.add_parser("capture", help="capture every in-window start list to CERT")
    cap.add_argument(
        "--first-run", action="store_true", help="the day's first run (cron 11 5 * * *)"
    )
    cap.add_argument(
        "--last-attempt",
        action="store_true",
        help="the window's last attempt: the run due before noon Warsaw (cron 11 9 * * *); "
        "on an event's last day a list still missing is fatal",
    )
    cap.add_argument(
        "--cron",
        default="",
        help="the cron that fired; the run works on the moment it was due (PZSZ.SL.10)",
    )
    args = parser.parse_args(argv)
    if args.command == "capture":
        return _capture_command(args)
    return _store_command(args)


if __name__ == "__main__":
    raise SystemExit(main())
