"""The re-read of every international source (ADR-119 G45 A).

On 1 Nov 2026 a hand re-read of the international events found four kinds of
drift that no test and no run had shown (G43, G50, G51, G52). This makes it a
workflow, `.github/workflows/source-regression.yml`: every international event
whose start lies in the last 30 months is read and planned against CERT, as the
recorded ingest reads and plans (`ingest_cli.read_event`, `plan.plan_event`,
`created=[]`, a settled finality), and nothing is written. Each tournament's
planned (fencer, place) pairs and N are compared with CERT's stored ones, and
CERT's result fingerprint with PROD's: equal on both counts means the source
still yields what PROD holds (doc/plans/partial-ingest-promote-results-sync-
2026-10-31.html, the push 2b build sheet, 2b.7–2b.10).

It runs on demand, on Mondays, and the day before an international event
starts; every day it names the international events that start within 14
days, and the workflow dry-reads those with a results link through
results-sync.yml (G42 A (2)). The log names codes, kinds and counts only; the
named detail goes to CERT's staging-reports bucket (D12).

Tests: python/tests/test_source_regression.py (SRC.REGR.01–09) and
python/tests/test_refusals_explained.py (REFUSAL.SAY.08–10).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from collections import Counter
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Any

MONTHS = 30
UPCOMING_DAYS = 14

EQUAL = "equal"
DIFFERENT = "different"
REFUSED = "refused"
KNOWN = "known"

# Cases the plan has decided to leave as they are, each with its reason. They
# never name a fencer: the reason reaches the log.
KNOWN_REFUSALS = {
    "PEW4ef-2024-2025": "an FTL combined bracket the reader refuses (G51 A)",
    "PEW6efs-2025-2026": "an FTL combined bracket the reader refuses (G51 A)",
}
KNOWN_DIFFERENCES = {
    "PEW7es-2024-2025": "a men's épée V2 result waits for G53's re-ingest, after G56",
}
NOTED = {
    "IMEW-2023-2024": "its V1 row is stored unverified (G54 A)",
}

_CODE = re.compile(r"^[A-Za-z0-9-]+$")


@dataclass
class EventCheck:
    """One event's verdict. `public` names no fencer; `named` and
    `exceptions` go to the stored report only. `read_from` names the engines
    whose pages were read (G60 A)."""

    code: str
    status: str
    public: list[str] = field(default_factory=list)
    named: list[str] = field(default_factory=list)
    exceptions: list[str] = field(default_factory=list)
    disagreements: int = 0
    known: str | None = None
    read_from: tuple[str, ...] = ()


# ------------------------------------------------------------ which and when


def _international(code: str) -> bool:
    from python.pipeline.organizers import INTERNATIONAL, route_of

    return route_of(code) == INTERNATIONAL


def _start(row: Mapping[str, Any]) -> dt.date | None:
    text = str(row.get("dt_start") or "")[:10]
    return dt.date.fromisoformat(text) if text else None


def _months_before(day: dt.date, months: int) -> dt.date:
    import calendar

    index = day.year * 12 + day.month - 1 - months
    year, month = divmod(index, 12)
    month += 1
    return dt.date(year, month, min(day.day, calendar.monthrange(year, month)[1]))


def _candidates(rows: Iterable[Mapping[str, Any]]) -> list[tuple[str, dt.date, Mapping[str, Any]]]:
    out = []
    for row in rows:
        code = str(row.get("txt_code") or "")
        start = _start(row)
        if start and row.get("enum_status") != "CANCELLED" and _international(code):
            out.append((code, start, row))
    return out


def past_events(rows: Iterable[Mapping[str, Any]], today: dt.date) -> list[str]:
    """The events re-read: international, started in the last 30 months, not
    cancelled."""
    since = _months_before(today, MONTHS)
    return sorted(code for code, start, _ in _candidates(rows) if since <= start <= today)


def upcoming(rows: Iterable[Mapping[str, Any]], today: dt.date) -> list[dict]:
    """The international events that start within 14 days, each with whether
    it has a results link the sync reads (`results_sync.has_link`)."""
    from python.pipeline.promotion.results_sync import has_link

    soon = [
        {
            "code": code,
            "start": start.isoformat(),
            "days": (start - today).days,
            "linked": has_link(code, row),
        }
        for code, start, row in _candidates(rows)
        if today < start <= today + dt.timedelta(days=UPCOMING_DAYS)
    ]
    return sorted(soon, key=lambda u: (u["start"], u["code"]))


def full_due(rows: Iterable[Mapping[str, Any]], today: dt.date, *, manual: bool) -> bool:
    """The full re-read runs on demand, on Mondays, and the day before an
    international event starts."""
    tomorrow = today + dt.timedelta(days=1)
    return (
        manual
        or today.weekday() == 0
        or any(start == tomorrow for _, start, _ in _candidates(rows))
    )


# ------------------------------------------------------------ the comparison

Rows = Mapping[int, tuple[set, int | None]]


def compare_rows(planned: Rows, stored: Rows) -> tuple[list[str], list[str]]:
    """Each tournament's planned (fencer, place) pairs and N against CERT's.
    The public lines count; the named ones list the pairs (fencer ids)."""
    public: list[str] = []
    named: list[str] = []
    for tid in sorted(set(planned) | set(stored)):
        p_pairs, p_n = planned.get(tid, (set(), None))
        s_pairs, s_n = stored.get(tid, (set(), None))
        if p_pairs == s_pairs and p_n == s_n:
            continue
        only_p, only_s = sorted(p_pairs - s_pairs), sorted(s_pairs - p_pairs)
        public.append(
            f"tournament {tid}: N planned {'none' if p_n is None else p_n}, "
            f"stored {'none' if s_n is None else s_n}; "
            f"{len(only_p)} row(s) only planned, {len(only_s)} only stored"
        )
        named.append(f"tournament {tid}: only planned {only_p}; only stored {only_s}")
    return public, named


def verdict(
    code: str,
    public: list[str],
    cert_fingerprint: str | None,
    prod_fingerprint: str | None,
    *,
    disagreements: int,
    named: list[str] | None = None,
    exceptions: list[str] | None = None,
) -> EventCheck:
    """An event read and planned: equal when its rows and PROD's fingerprint
    agree with CERT's; a difference the plan has decided to leave is known."""
    public = list(public)
    if cert_fingerprint != prod_fingerprint:
        public.append(
            f"CERT's result fingerprint {cert_fingerprint} is not PROD's {prod_fingerprint}"
        )
    check = EventCheck(
        code,
        DIFFERENT if public else EQUAL,
        public,
        list(named or []),
        list(exceptions or []),
        disagreements,
        NOTED.get(code),
    )
    if check.status == DIFFERENT and code in KNOWN_DIFFERENCES:
        check.status, check.known = KNOWN, KNOWN_DIFFERENCES[code]
    return check


def refusal(
    code: str, reason: str, *, named: str | None = None, read_from: tuple[str, ...] = ()
) -> EventCheck:
    """An event the read or the plan refused; `reason` names no one."""
    if code in KNOWN_REFUSALS:
        return EventCheck(
            code,
            KNOWN,
            [reason],
            [named] if named else [],
            known=KNOWN_REFUSALS[code],
            read_from=read_from,
        )
    return EventCheck(code, REFUSED, [reason], [named] if named else [], read_from=read_from)


def public_reason(e: BaseException) -> str:
    """A refusal as the log may print it, never a name (D12), saying what it
    means (G60 A): a listing refused after its source was read, a source
    refused before anything was written, or a failure as the sync says it."""
    from python.pipeline.core.contract import ListingRefused, SourceRefused
    from python.pipeline.promotion.results_sync import public_error

    if isinstance(e, ListingRefused):
        where = f" from {', '.join(e.read_from)}" if e.read_from else ""
        return f"read{where}, then refused ({e.kind}): {e.summary}"
    if isinstance(e, SourceRefused):
        return f"refused before anything was written: {e.summary}"
    return f"failed: {public_error(e)}"


def engines_read(sources: Iterable[Mapping[str, Any]] | None) -> tuple[str, ...]:
    """The engines a read's result URLs were read with, by their labels."""
    from python.pipeline.international_sources import ENGINES, engine_of

    return tuple(sorted({ENGINES[engine_of(s["url"])].label for s in sources or []}))


# ------------------------------------------------------------ what it says


def _codes(checks: list[EventCheck], status: str) -> list[str]:
    return [c.code for c in checks if c.status == status]


def line(checks: list[EventCheck], soon: list[dict], *, roster_alike: bool = True) -> str:
    """The one Telegram line: codes and counts only."""
    if checks:
        parts = [f"{len(checks)} event(s), {len(_codes(checks, EQUAL))} equal"]
        for status in (DIFFERENT, REFUSED, KNOWN):
            if codes := _codes(checks, status):
                parts.append(f"{status}: {', '.join(codes)}")
        noted = [c for c in checks if c.disagreements]
        if noted:
            parts.append(
                f"source disagreements: {sum(c.disagreements for c in noted)} in "
                + ", ".join(c.code for c in noted)
            )
        read = Counter(label for c in checks for label in c.read_from)
        if read:  # G60 A: a refusal is not a sign-in failure when the source was read
            parts.append("sources read: " + ", ".join(f"{k} {n}" for k, n in sorted(read.items())))
        head = "; ".join(parts)
    else:
        head = "no event re-read today"
    if not roster_alike:
        head += "; CERT's roster is not PROD's, so a difference may be the refresh's"
    if soon:
        tail = "; ".join(
            f"{u['code']} in {u['days']} days, "
            + ("dry-read" if u["linked"] else "no results link")
            for u in soon
        )
    else:
        tail = "none"
    return f"🔎 Source re-read: {head}. Upcoming: {tail}"


def log_lines(check: EventCheck) -> list[str]:
    """What the public log prints of one event: its verdict, the counted
    differences and the number of disagreements, never a name or an id."""
    out = [f"{check.code}: {check.status}" + (f" ({check.known})" if check.known else "")]
    out += [f"  {p}" for p in check.public]
    if check.disagreements:
        out.append(f"  source disagreements: {check.disagreements}")
    return out


def report_md(checks: list[EventCheck], soon: list[dict], *, stamp: str) -> str:
    """The stored report: every event with its named detail."""
    lines = [f"# Source re-read — {stamp}", "", line(checks, soon), ""]
    for c in checks:
        lines += [f"## {c.code}: {c.status}", ""]
        if c.known:
            lines.append(f"- known: {c.known}")
        lines += [f"- {p}" for p in c.public]
        lines += [f"- {n}" for n in c.named]
        if c.disagreements:
            lines.append(f"- source disagreements: {c.disagreements} (the run's log lists each)")
        lines += [f"- source exception: {e}" for e in c.exceptions]
        lines.append("")
    return "\n".join(lines)


def report_path(stamp: str) -> str:
    return f"regression/{stamp}.md"


# ------------------------------------------------------------ the run


def planned_rows(ops: Iterable[Mapping[str, Any]]) -> dict[int, tuple[set, int | None]]:
    """A plan's tournaments: (fencer, place) pairs and N."""
    out: dict[int, tuple[set, int | None]] = {}
    for op in ops:
        if op.get("op") != "ingest_results":
            continue
        pairs = {
            (r.get("id_fencer"), r.get("place") if "place" in r else r.get("int_place"))
            for r in op.get("rows") or []
        }
        n = op.get("participant_count")
        out[int(op["tournament"])] = (pairs, None if n is None else int(n))
    return out


def stored_rows(stored: Iterable[Mapping[str, Any]] | None) -> dict[int, tuple[set, int | None]]:
    """CERT's tournaments as STORED_SQL returns them."""
    return {
        int(t["t"]): (
            {(int(f), int(p)) for f, p in t.get("rows") or []},
            None if t.get("n") is None else int(t["n"]),
        )
        for t in stored or []
    }


STORED_SQL = (
    "SELECT coalesce(jsonb_agg(jsonb_build_object("
    "'t', t.id_tournament, 'n', t.int_participant_count, 'rows', ("
    "SELECT coalesce(jsonb_agg(jsonb_build_array(r.id_fencer, r.int_place)), '[]'::jsonb) "
    "FROM tbl_result r WHERE r.id_tournament = t.id_tournament))), '[]'::jsonb) AS j "
    "FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event "
    "WHERE e.txt_code = '{code}'"
)
FINGERPRINT_SQL = "SELECT to_jsonb(fn_event_result_fingerprint('{code}')) AS j"
EVENTS_SQL = "SELECT coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb) AS j FROM tbl_event e"
ROSTER_SQL = (
    "SELECT to_jsonb(md5(string_agg(id_fencer::text || '|' || lower(txt_surname) || '|' || "
    "lower(txt_first_name) || '|' || coalesce(int_birth_year::text, ''), ',' "
    "ORDER BY id_fencer))) AS j FROM tbl_fencer"
)


def _sql(template: str, code: str) -> str:
    if not _CODE.match(code):
        raise ValueError(f"not an event code: {code!r}")
    return template.format(code=code)


def check_event(code: str, *, cert_db: Any, cert: Any, prod: Any) -> EventCheck:
    """One event read and planned against CERT, nothing written, and compared.
    The code goes into SQL, so it is checked first."""
    _sql(FINGERPRINT_SQL, code)
    from python.pipeline import ingest_cli
    from python.pipeline.core.contract import ListingRefused
    from python.pipeline.international_sources import SETTLED
    from python.pipeline.promotion.plan import plan_event
    from python.pipeline.promotion.results_sync import season_end_year

    year = season_end_year(code)
    event = cert_db.find_event_by_code(code)
    if event is None:
        raise ValueError(f"{code} is not on CERT")
    link = (event.get("url_event") or "").strip() or None
    read = ingest_cli.read_event(event, code, year, link, None, db=cert_db, finality=SETTLED)
    read_from = engines_read(read.sources)
    try:
        plan = plan_event(
            code, year, cert_db, url_event=link or "", created=[], read=read, target="CERT"
        )
    except ListingRefused as e:
        e.read_from = read_from  # the source was read; the plan refused a listing (G60 A)
        raise
    public, named = compare_rows(
        planned_rows(plan.ops), stored_rows(cert.fetch_json(_sql(STORED_SQL, code)))
    )
    listings = list(read.listings or [])
    check = verdict(
        code,
        public,
        cert.fetch_json(_sql(FINGERPRINT_SQL, code)),
        prod.fetch_json(_sql(FINGERPRINT_SQL, code)),
        disagreements=sum(len(r["_base"].source_disagreements or []) for r in listings),
        named=named,
        exceptions=[
            f'{r["name"]}, place {e.get("place")}: "{e.get("printed")}"'
            for r in listings
            for e in r["_base"].source_exceptions or []
        ],
    )
    check.read_from = read_from
    return check


def run(
    rows: Sequence[Mapping[str, Any]],
    today: dt.date,
    *,
    manual: bool,
    check: Callable[[str], EventCheck],
    send: Callable[[str], None],
    store: Callable[[bytes, str], str],
    output: Callable[..., None],
    stamp: str,
    roster_alike: bool = True,
) -> int:
    """One day's run: the upcoming events every day, the full re-read when it
    is due. A difference is reported, not a failure of the run."""
    soon = upcoming(rows, today)
    for u in soon:
        state = "dry-read" if u["linked"] else "no results link"
        print(f"upcoming {u['code']}: in {u['days']} day(s), {state}")
    output(dry_read=json.dumps([u["code"] for u in soon if u["linked"]]))
    checks: list[EventCheck] = []
    if full_due(rows, today, manual=manual):
        for code in past_events(rows, today):
            try:
                result = check(code)
            except Exception as e:  # the event's refusal, never the run's
                result = refusal(
                    code,
                    public_reason(e),
                    named=f"{type(e).__name__}: {e}",
                    read_from=tuple(getattr(e, "read_from", ())),
                )
            for text in log_lines(result):
                print(text)
            checks.append(result)
        print(f"report stored: {store(report_md(checks, soon, stamp=stamp).encode(), stamp)}")
    else:
        print("no full re-read today: it runs on demand, on Mondays and the day before an event")
    if checks or soon:
        said = line(checks, soon, roster_alike=roster_alike)
        print(f"summary: {said}")  # G60 A: the log ends with what Telegram is told
        send(said)
    return 0


def _github_output(**values: Any) -> None:
    import os

    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            for k, v in values.items():
                f.write(f"{k}={v}\n")


def main(argv: Iterable[str] | None = None) -> int:
    import os
    from zoneinfo import ZoneInfo

    from python.pipeline.db_connector import create_db_connector
    from python.pipeline.notifications import TelegramNotifier
    from python.pipeline.promotion.refresh import ManagementTransport
    from python.pipeline.storage_md import StorageMdHandler
    from python.supabase_token import supabase_access_token
    from python.tools._backends import CERT_REF, PROD_REF

    ap = argparse.ArgumentParser(description="Re-read every international source (G45 A).")
    ap.add_argument("--manual", action="store_true", help="run the full re-read today")
    args = ap.parse_args(list(argv) if argv is not None else None)
    token = supabase_access_token()
    if not token:
        print("SUPABASE_ACCESS_TOKEN is required to read CERT and PROD")
        return 1
    cert = ManagementTransport(CERT_REF, token, read_only=True)
    prod = ManagementTransport(PROD_REF, token, read_only=True)
    cert_db = create_db_connector()  # CERT: read_event and plan_event write nothing here
    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
    )
    roster_alike = cert.fetch_json(ROSTER_SQL) == prod.fetch_json(ROSTER_SQL)
    print(f"CERT's roster {'is' if roster_alike else 'is NOT'} PROD's")
    now = dt.datetime.now(ZoneInfo("Europe/Warsaw"))
    return run(
        list(cert.fetch_json(EVENTS_SQL) or []),
        now.date(),
        manual=args.manual,
        check=lambda code: check_event(code, cert_db=cert_db, cert=cert, prod=prod),
        send=notifier.send,
        store=lambda md, stamp: StorageMdHandler(cert_db._sb).upload_regression(md, stamp),
        output=_github_output,
        stamp=now.astimezone(dt.UTC).strftime("%Y%m%d-%H%M%SZ"),
        roster_alike=roster_alike,
    )


if __name__ == "__main__":
    raise SystemExit(main())
