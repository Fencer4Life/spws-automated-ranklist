"""The hourly results sync (ADR-119 §4: D5–D9, D12, G7).

`results-sync.yml` runs a cycle every hour from 08:13 to 20:13 UTC. Its select
takes the active-season events on the route whose window is open (the first
day to the day after the end date in Warsaw, by the moment the cron was due),
neither COMPLETED nor CANCELLED, with a results link on CERT or on PROD (the
link is the switch, G7), and not paused (D8). Each one, one at a time in the
cert-write lane, is:

  1. compared: the schedule and every final listing, read as the ingest reads
     them and hashed as the run record hashes them, against the latest
     FINISHED CERT run and PROD's fingerprint: nothing to do, promote only, or
     changed;
  2. when changed, refreshed from PROD, ingested on CERT and promoted to PROD
     (ingest-event.yml and promote.yml, called);
  3. reported in one line (§04.6), and paused on any failure.

This module holds the pure parts: the window, the select, the compare, the
lines and the pause rules. A pause reason never names a fencer: it is shown in
the morning line and the Actions log, and the refusal itself stays on the run
row and in Telegram (D12).
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
from collections import Counter
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass, field
from typing import Any

from python.pipeline.organizers import INTERNATIONAL, route_of
from python.pipeline.promotion import lifecycle

CLOSED = ("COMPLETED", "CANCELLED")
NO_LINK = "no results link on CERT or PROD; set it in Admin, then sync again"

# The thirteen cycles, as two cron lines (G28 A): GitHub names the line that
# fired, so a morning run it starts late is still the morning cycle.
MORNING = "13 8 * * *"
HOURLY = "13 9-20 * * *"

# A cycle's verdict, recorded on the event's row (tbl_results_sync_event).
UNCHANGED = "unchanged"
PROMOTED = "promoted"
NOTHING_FINAL = "nothing_final"
FAILED = "failed"
BLOCKED = "blocked"
REFUSED = "refused"
STOPPED = "stopped"
VERDICTS = (UNCHANGED, PROMOTED, NOTHING_FINAL, FAILED, BLOCKED, REFUSED, STOPPED)


# ---------------------------------------------------------------- the window


def _days(row: Mapping[str, Any]) -> tuple[dt.date, dt.date]:
    """An event row's first and last day; no end date is a one-day event."""
    first = lifecycle.as_date(row["dt_start"])
    end = row.get("dt_end")
    return first, lifecycle.as_date(end) if end not in (None, "") else first


def in_window(row: Mapping[str, Any], day: dt.date) -> bool:
    """The sync reads an event from its first day to the day after its end."""
    first, last = _days(row)
    return first <= day <= last + dt.timedelta(days=1)


def is_morning(cron: str | None) -> bool:
    """The day's first cycle, which sends the ☀ line (G28 A, G29 A)."""
    return (cron or "").strip() == MORNING


def due_moment(cron: str | None, now: dt.datetime) -> dt.datetime:
    """A scheduled run's due moment in Warsaw (GitHub starts them late); a
    manual run's clock."""
    if cron is None:
        return now.astimezone(lifecycle.WARSAW)
    from python.scrapers.pzsz_start_list_store import scheduled_moment

    return scheduled_moment(cron, now)


def due_day(cron: str | None, now: dt.datetime) -> dt.date:
    """The Warsaw date a cycle works on, by its due moment."""
    return due_moment(cron, now).date()


# ---------------------------------------------------------------- the select


def has_link(code: str, row: Mapping[str, Any]) -> bool:
    """A results link the event's route reads (G7): url_event, or for the
    international route any result slot or an EVF results id."""
    if route_of(code) == INTERNATIONAL:
        from python.pipeline.international_sources import event_sources

        return bool(event_sources(row))
    return bool((row.get("url_event") or "").strip())


@dataclass
class Selection:
    """What one cycle takes (`events`, the matrix) and what it does not."""

    events: list[str] = field(default_factory=list)
    paused: list[dict] = field(default_factory=list)
    no_link: list[str] = field(default_factory=list)
    resume: list[str] = field(default_factory=list)
    refused: str | None = None
    off: bool = False

    @property
    def count(self) -> int:
        return len(self.events)

    def matrix(self) -> str:
        """The cycle job's matrix: each event with the season end year
        ingest-event.yml needs."""
        return json.dumps(
            [{"event_code": c, "season_end_year": season_end_year(c)} for c in self.events]
        )


def season_end_year(code: str) -> int:
    """The season an event code names ends in its last year: PPW2-2026-2027 → 2027."""
    match = re.search(r"-(\d{4})$", code)
    if match is None:
        raise ValueError(f"not an event code with its season: {code!r}")
    return int(match.group(1))


def select(
    cert_rows: Iterable[Mapping[str, Any]],
    prod_rows: Mapping[str, Mapping[str, Any]],
    pauses: Mapping[str, Mapping[str, Any]],
    *,
    day: dt.date,
    code: str | None = None,
    scheduled: bool = True,
    switch: str | None = None,
) -> Selection:
    """The events of a cycle. `cert_rows` are CERT's active-season events on
    the route, `prod_rows` PROD's link columns by code, `pauses` the pause rows
    by code. A manual code is taken in or out of its window, and its pause is
    lifted first (`resume`); the switch `RESULTS_SYNC=off` ends a scheduled
    select only."""
    rows = {str(r["txt_code"]): r for r in cert_rows}

    def linked(c: str) -> bool:
        return has_link(c, rows[c]) or has_link(c, prod_rows.get(c) or {})

    def paused(c: str) -> bool:
        return bool((pauses.get(c) or {}).get("paused_at"))

    if code is not None:
        row = rows.get(code)
        if row is None:
            return Selection(refused=f"{code} is not an event of the active season on the route")
        if row.get("enum_status") in CLOSED:
            return Selection(refused=f"{code} is {row['enum_status']}: the sync does not take it")
        if not linked(code):
            return Selection(refused=f"{code}: {NO_LINK}")
        return Selection(events=[code], resume=[code] if paused(code) else [])
    if scheduled and (switch or "").strip().lower() == "off":
        return Selection(off=True)
    out = Selection()
    for c in sorted(rows):
        row = rows[c]
        if row.get("enum_status") in CLOSED or row.get("dt_start") in (None, ""):
            continue
        if not in_window(row, day):
            continue
        if not linked(c):
            out.no_link.append(c)
        elif paused(c):
            out.paused.append({"code": c, **pauses[c]})
        else:
            out.events.append(c)
    return out


# ---------------------------------------------------------------- the compare


@dataclass(frozen=True)
class Comparison:
    """The compare step: `changed` (ingest), `promote_only` (PROD is behind
    the latest finished run), the run compared with, and the rounds whose
    content that run did not hold (name, rows)."""

    changed: bool
    promote_only: bool
    previous_run: int | None
    new: list[tuple[str, int]]


def _key(r: Mapping[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(r.get("name")),
        str(r.get("uuid")),
        str(r.get("sha256") or ""),
        str(r.get("start_list_sha256") or ""),
    )


def _signature(listings: Mapping[str, Any]) -> tuple:
    """What a cycle compares: the schedule hash, every listing's hash with its
    start list's (§04.9), the result slots and the PZSz event. Not a round's
    verdict, which the commit decides."""
    return (
        (listings.get("schedule") or {}).get("sha256"),
        sorted(_key(r) for r in listings.get("rounds") or []),
        listings.get("sources"),
        listings.get("pzsz_event"),
    )


def new_rounds(
    listings: Mapping[str, Any], before: Mapping[str, Any] | None
) -> list[tuple[str, int]]:
    """The rounds whose content the earlier run did not hold, in read order."""
    held = {_key(r) for r in (before or {}).get("rounds") or []}
    return [
        (str(r["name"]), int(r.get("count") or 0))
        for r in listings.get("rounds") or []
        if r.get("sha256") and _key(r) not in held
    ]


def compare(
    read: Any, previous_run: Mapping[str, Any] | None, prod_fingerprint: str | None
) -> Comparison:
    """Step 1 of a cycle, pure: the read (ingest_cli.EventRead) hashed as the
    run record hashes it, against the latest FINISHED CERT run (`id`,
    `listings`, `result_fingerprint`) and the fingerprint PROD holds."""
    from python.pipeline.promotion.run_record import ListingLog

    log = ListingLog()
    log.add_read(read)
    now = json.loads(json.dumps(log.listings(), ensure_ascii=False, default=str))
    if previous_run is None:
        return Comparison(True, False, None, new_rounds(now, None))
    before = previous_run.get("listings") or {}
    run_id = int(previous_run["id"])
    if _signature(now) != _signature(before):
        return Comparison(True, False, run_id, new_rounds(now, before))
    current = prod_fingerprint == previous_run.get("result_fingerprint")
    return Comparison(False, not current, run_id, [])


# ---------------------------------------------------------------- the outcome


@dataclass(frozen=True)
class Cycle:
    """What one event's cycle did, as its outcome job reads it: the compare,
    the refresh report when the refresh ran, the CERT run row the cycle ended
    on (`id`, `status`, `error`, `listings`, `gate`, `promote`: the ledger),
    the promote job (`result`, `writes`), and an error that opened no run."""

    code: str
    moment: dt.datetime
    comparison: Comparison | None
    run_url: str | None = None
    run: Mapping[str, Any] | None = None
    refresh: str | None = None
    promote: Mapping[str, Any] | None = None
    error: str | None = None
    prod_holds_previous: bool = True


@dataclass(frozen=True)
class _Said:
    verdict: str
    line: str | None = None
    pause: str | None = None


def _refresh_stop(text: str | None) -> tuple[str, str] | None:
    """The refresh report's stop: its status and its counts, or None."""
    status = re.search(r"^status: (stopped_\w+)$", text or "", re.M)
    if status is None:
        return None
    counts_line = re.search(r"^counts: (\{.*\})$", text or "", re.M)
    counts = json.loads(counts_line.group(1)) if counts_line else {}
    return status.group(1), ", ".join(f"{n} {what}" for what, n in counts.items())


def _plural(n: int, word: str) -> str:
    return f"{n} {word}{'' if n == 1 else 's'}"


def _not_final(run: Mapping[str, Any]) -> int:
    skipped = ((run.get("listings") or {}).get("schedule") or {}).get("skipped") or []
    return sum(lifecycle.is_not_final(s.get("reason")) for s in skipped)


def _error_type(error: str | None) -> str:
    return str(error or "").split(":", 1)[0].strip() or "error"


def _paused(code: str, fix: str = "Fix it") -> str:
    return f"   PAUSED. {fix}, then send: sync {code}"


def _said(c: Cycle) -> _Said:
    head = f"{c.code} · cycle {c.moment.astimezone(lifecycle.WARSAW):%H:%M}"
    stop = _refresh_stop(c.refresh)
    if stop is not None:
        status, counts = stop
        detail = f"{status}; {counts}" if counts else status
        return _Said(
            STOPPED,
            "\n".join(
                [
                    f"⏸ {head} · nothing written",
                    f"   the PROD→CERT refresh needs the administrator ({detail})",
                    _paused(c.code, "Apply the refresh"),
                ]
            ),
            f"refresh: {status}",
        )
    if c.error is not None and c.run is None:
        return _Said(
            FAILED,
            "\n".join(
                [
                    f"❌ {head} · nothing written, CERT and PROD unchanged",
                    f"   {c.error}",
                    _paused(c.code),
                ]
            ),
            f"read failed: {_error_type(c.error)}",
        )
    cmp = c.comparison
    if cmp is not None and not cmp.changed and not cmp.promote_only:
        return _Said(UNCHANGED)
    run = c.run
    if cmp is None or run is None:
        return _Said(
            FAILED,
            "\n".join(
                [
                    f"❌ {head} · the cycle ended before a CERT run",
                    f"   {c.run_url}",
                    _paused(c.code),
                ]
            ),
            "no run",
        )

    prev = cmp.previous_run
    prod_part = f"PROD keeps run {prev}" if prev and c.prod_holds_previous else "PROD unchanged"
    run_head = f"{head} · CERT run {run['id']}"
    if run.get("status") == "FAILED":
        refusal = (run.get("listings") or {}).get("refusal")
        kind = _error_type(run.get("error"))
        if refusal:
            where = f" {refusal['listing']}" if refusal.get("listing") else ""
            detail = f"{kind} [{refusal['kind']}]{where}: {refusal.get('message')}"
            reason = ", ".join(str(x) for x in (refusal["kind"], refusal.get("listing")) if x)
        else:
            detail, reason = str(run.get("error")), kind
        cert_part = f"CERT unchanged (run {prev} stands)" if prev else "CERT unchanged"
        return _Said(
            FAILED,
            "\n".join(
                [
                    f"❌ {run_head} FAILED, {cert_part}, {prod_part}",
                    f"   {detail}",
                    _paused(c.code),
                ]
            ),
            reason,
        )

    rounds = (run.get("listings") or {}).get("rounds") or []
    gate = run.get("gate")
    if (
        gate is None
        and not cmp.promote_only
        and not any(r.get("status") == "committed" for r in rounds)
    ):
        return _Said(
            NOTHING_FINAL,
            f"⏳ {run_head} · nothing final yet, nothing written · "
            f"{_plural(_not_final(run), 'listing')} not final",
        )
    # A promote-only cycle replays the run whatever its stored gate said;
    # promote's own gate decides, and its refusal is on the ledger (S3).
    if not cmp.promote_only and (gate is None or not gate.get("passed")):
        findings = [f for f in (gate or {}).get("findings") or [] if f.get("kind") != "information"]
        counts = Counter(str(f.get("kind")) for f in findings)
        lines = [f"   [{f.get('kind')}] {f.get('check')}: {f.get('message')}" for f in findings]
        if gate is None:
            lines = [f"   the gate did not run: {c.run_url}"]
        return _Said(
            BLOCKED,
            "\n".join(
                [f"❌ {run_head} · the gate blocks promote, {prod_part}", *lines, _paused(c.code)]
            ),
            "gate: " + (", ".join(f"{n} {k}" for k, n in counts.items()) or "did not run"),
        )

    ledger = run.get("promote") or {}
    current = not ledger.get("ts") or _ts(ledger["ts"]) >= c.moment
    job = (c.promote or {}).get("result")
    if current and ledger.get("outcome") == "refused":
        return _Said(
            REFUSED,
            "\n".join(
                [
                    f"❌ {run_head} · promote to PROD refused, PROD unchanged",
                    f"   {ledger.get('reason')}",
                    _paused(c.code),
                ]
            ),
            "promote refused",
        )
    reached = current and ledger.get("outcome") in ("applied", "skipped")
    if job != "success" or not reached:
        what = (
            "promoted to PROD, then the promote job failed"
            if reached
            else "promote to PROD failed, PROD unchanged"
        )
        return _Said(
            FAILED,
            "\n".join(
                [
                    f"❌ {run_head} · {what}",
                    f"   the promote job failed: {c.run_url}",
                    _paused(c.code),
                ]
            ),
            "promote failed",
        )

    writes = (c.promote or {}).get("writes")
    if ledger.get("outcome") == "skipped":
        done = "PROD already holds it"
    elif writes is None:
        done = "promoted to PROD"
    else:
        done = f"promoted to PROD ({_plural(int(writes), 'write')})"
    parts = []
    if cmp.new:
        parts.append("new: " + ", ".join(f"{name} ({n})" for name, n in cmp.new))
    if waiting := _not_final(run):
        parts.append(f"{_plural(waiting, 'listing')} not final")
    parts.append(f"report: staging-reports/{c.code}/full.md")
    return _Said(PROMOTED, f"✅ {run_head} · {done}\n   " + " · ".join(parts))


def _ts(value: Any) -> dt.datetime:
    return dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))


def cycle_line(cycle: Cycle) -> str | None:
    """The one Telegram line of a cycle (§04.6); None when nothing changed."""
    return _said(cycle).line


def verdict(cycle: Cycle) -> str:
    """The cycle's verdict, recorded on the event's row."""
    return _said(cycle).verdict


def pause_for(cycle: Cycle) -> tuple[str, str | None] | None:
    """The pause a failed cycle writes (D8): its reason, free of names, and the
    Actions run; None when the cycle did not fail."""
    said = _said(cycle)
    return None if said.pause is None else (said.pause, cycle.run_url)


# ---------------------------------------------------------------- the morning


def _since(paused_at: Any, moment: dt.datetime) -> str:
    at = _ts(paused_at).astimezone(lifecycle.WARSAW)
    today = moment.astimezone(lifecycle.WARSAW).date()
    if at.date() == today:
        return f"since {at:%H:%M}"
    if at.date() == today - dt.timedelta(days=1):
        return f"since yesterday {at:%H:%M}"
    return f"since {at.day} {at:%b} {at:%H:%M}"


def morning_line(moment: dt.datetime, selection: Selection) -> str:
    """The ☀ line: every event in window, syncing, paused or without a link."""
    head = f"☀ {moment.astimezone(lifecycle.WARSAW):%H:%M}"
    parts = [f"{c} (syncing)" for c in selection.events]
    parts += [
        f"{p['code']} (PAUSED {_since(p['paused_at'], moment)}: {p.get('paused_reason')})"
        for p in selection.paused
    ]
    parts += [f"{c} (no results link)" for c in selection.no_link]
    if not parts:
        return f"{head} · nothing in window"
    return f"{head} · in window: " + " · ".join(parts)


# ---------------------------------------------------------------- the command line


def public_error(e: BaseException) -> str:
    """A failure that opened no run, as a step may hand it on: a step's
    environment is printed in its log (D12), so only the pipeline's own
    messages pass with their text; any other error passes as its type."""
    from python.pipeline.promotion.cert_apply import GateUnavailable
    from python.scrapers.ftl_auth import FtlAuthError
    from python.scrapers.pzsz_start_list_store import StoredStartListError

    kind = type(e).__name__
    if not isinstance(e, (FtlAuthError, GateUnavailable, StoredStartListError)):
        return kind
    text = " ".join(str(e).split())
    return f"{kind}: {text}" if text else kind


class SyncSql:
    """CERT or PROD through a Management-API transport (refresh.Transport):
    the events, their links and pauses, the runs, and the sync's writes."""

    def __init__(self, transport: Any):
        self.transport = transport

    def _call(self, sql: str, **params: Any) -> Any:
        from python.pipeline.promotion.refresh import _literal as literal

        return self.transport.fetch_json(
            sql.replace("{p}", f"(SELECT {literal(params)} AS p) a") if params else sql
        )

    def events(self) -> list[dict]:
        return (
            self._call(
                "SELECT coalesce(jsonb_agg(jsonb_build_object('txt_code', e.txt_code, "
                "'enum_status', e.enum_status, 'dt_start', e.dt_start, 'dt_end', e.dt_end, "
                "'url_event', e.url_event, 'url_event_2', e.url_event_2, 'url_event_3', e.url_event_3, "
                "'url_event_4', e.url_event_4, 'url_event_5', e.url_event_5, "
                "'id_evf_event', e.id_evf_event) ORDER BY e.txt_code), '[]'::jsonb) AS j "
                "FROM tbl_event e JOIN tbl_season s ON s.id_season = e.id_season "
                f"WHERE s.bool_active AND e.txt_code ~ '{_route_regex()}'"
            )
            or []
        )

    def links(self) -> dict[str, dict]:
        return {e["txt_code"]: e for e in self.events()}

    def pauses(self) -> dict[str, dict]:
        return (
            self._call(
                "SELECT coalesce(jsonb_object_agg(txt_event_code, jsonb_build_object("
                "'paused_at', ts_paused_at, 'paused_reason', txt_paused_reason, "
                "'paused_by_run', url_paused_by_run)), '{}'::jsonb) AS j "
                "FROM tbl_results_sync_event WHERE ts_paused_at IS NOT NULL"
            )
            or {}
        )

    def resume(self, code: str) -> bool:
        return bool(
            self._call(
                "SELECT to_jsonb(fn_results_sync_resume(p->>'code')) AS j FROM {p}", code=code
            )
        )

    def pause(self, code: str, reason: str, run_url: str | None) -> None:
        self._call(
            "SELECT jsonb_build_object('paused', TRUE) AS j FROM {p}, "
            "LATERAL (SELECT fn_results_sync_pause(p->>'code', p->>'reason', p->>'run_url')) f",
            code=code,
            reason=reason,
            run_url=run_url,
        )

    def cycle(self, code: str, verdict: str) -> None:
        self._call(
            "SELECT jsonb_build_object('recorded', TRUE) AS j FROM {p}, "
            "LATERAL (SELECT fn_results_sync_cycle(p->>'code', p->>'verdict')) f",
            code=code,
            verdict=verdict,
        )

    def latest_finished_run(self, code: str) -> dict | None:
        return self._call(
            "SELECT jsonb_build_object('id', id_ingest_run, 'listings', jsonb_listings, "
            "'result_fingerprint', txt_result_fingerprint) AS j FROM tbl_ingest_run, {p} "
            "WHERE txt_event_code = p->>'code' AND txt_environment = 'cert' "
            "AND txt_status = 'FINISHED' ORDER BY id_ingest_run DESC LIMIT 1",
            code=code,
        )

    def run(self, run_id: int) -> dict | None:
        return self.transport.fetch_json(
            "SELECT jsonb_build_object('id', id_ingest_run, 'status', txt_status, "
            "'error', txt_error, 'listings', jsonb_listings, 'gate', jsonb_gate, "
            "'promote', jsonb_promote, 'result_fingerprint', txt_result_fingerprint) AS j "
            f"FROM tbl_ingest_run WHERE id_ingest_run = {int(run_id)}"
        )

    def result_fingerprint(self, code: str) -> str | None:
        return self._call(
            "SELECT to_jsonb(fn_event_result_fingerprint(p->>'code')) AS j FROM {p}", code=code
        )


def _route_regex() -> str:
    from python.pipeline.organizers import route_code_regex

    return route_code_regex()


Send = Callable[[str], None]
Output = Callable[..., None]


def run_select(
    cert: Any,
    prod: Any,
    *,
    now: dt.datetime,
    cron: str | None,
    code: str | None = None,
    switch: str | None = None,
    dry_run: bool = False,
    send: Send,
    output: Output,
) -> int:
    """The select job: the matrix of this cycle's events, a manual code's pause
    lifted first, and the ☀ line on the morning cycle (G29 A). Its log names
    events and reasons only."""
    moment = due_moment(cron, now)
    selection = select(
        cert.events(),
        prod.links(),
        cert.pauses(),
        day=moment.date(),
        code=code,
        scheduled=cron is not None,
        switch=switch,
    )
    output(events=selection.matrix(), count=selection.count, moment=moment.isoformat())
    if selection.off:
        print("RESULTS_SYNC=off: no scheduled cycle runs")
        return 0
    if selection.refused is not None:
        print(selection.refused)
        if not dry_run:
            send(selection.refused)
            output(reported="true")
        return 1
    for c in selection.resume:
        if dry_run:
            print(f"(dry run) would lift the pause of {c}")
        else:
            cert.resume(c)
            print(f"lifted the pause of {c}")
    print(f"{selection.count} event(s) to sync: {', '.join(selection.events) or 'none'}")
    if is_morning(cron):
        line = morning_line(moment, selection)
        print(line)
        if not dry_run:
            send(line)
    return 0


def run_compare(code: str, *, read: Callable[[], Any], cert: Any, prod: Any, output: Output) -> int:
    """The compare step (R3.3 A): read-only, it decides whether the cycle
    refreshes and ingests (`changed`) or only promotes (`promote_only`)."""
    try:
        got = compare(read(), cert.latest_finished_run(code), prod.result_fingerprint(code))
    except Exception as e:
        error = public_error(e)
        output(changed="", promote_only="", previous_run="", new="[]", error=error)
        print(f"{code}: the read failed: {error}")
        return 1
    output(
        changed=str(got.changed).lower(),
        promote_only=str(got.promote_only).lower(),
        previous_run="" if got.previous_run is None else str(got.previous_run),
        new=json.dumps(got.new, ensure_ascii=False),
        error="",
    )
    what = "changed" if got.changed else "promote only" if got.promote_only else "nothing to do"
    rounds = f": new {', '.join(name for name, _ in got.new)}" if got.new else ""
    print(f"{code}: {what} (against CERT run {got.previous_run or 'none'}){rounds}")
    return 0


def run_outcome(
    code: str,
    *,
    cert: Any,
    prod: Any,
    moment: dt.datetime,
    comparison: Comparison | None,
    run_id: int | None,
    error: str | None,
    refresh: Mapping[str, str] | None,
    promote: Mapping[str, str] | None,
    run_url: str | None,
    send: Send,
    dry_run: bool = False,
) -> int:
    """The outcome job (R3.2 A): the cycle recorded on the event's row, the
    pause on any failure, and the one Telegram line. The log carries the
    verdict and the pause reason, never the line, which can name a fencer."""
    previous = cert.run(comparison.previous_run) if comparison and comparison.previous_run else None
    run = (
        cert.run(run_id) if run_id else previous if comparison and comparison.promote_only else None
    )
    status = (refresh or {}).get("status")
    writes = str((promote or {}).get("writes") or "").strip()
    cycle = Cycle(
        code,
        moment,
        comparison,
        run_url=run_url,
        run=run,
        refresh=f"status: {status}\ncounts: {(refresh or {}).get('counts') or '{}'}"
        if status
        else None,
        promote={
            "result": (promote or {}).get("result"),
            "writes": int(writes) if writes.isdigit() else None,
        },
        error=error or None,
        prod_holds_previous=previous is not None
        and prod.result_fingerprint(code) == previous.get("result_fingerprint"),
    )
    said = _said(cycle)
    told = f"{code}: {said.verdict}" + (f", paused: {said.pause}" if said.pause else "")
    if dry_run:
        print(f"(dry run) {told}")
        return 0
    cert.cycle(code, said.verdict)
    if said.pause is not None:
        cert.pause(code, said.pause, run_url)
    if said.line is not None:
        send(said.line)
    print(told)
    return 0


def _github_output(**values: Any) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as f:
        for k, v in values.items():
            f.write(f"{k}={v}\n")


def _read_for(code: str, season_end_year: int) -> Callable[[], Any]:
    """The compare's read: the event as the recorded ingest reads it."""

    def read() -> Any:
        from python.pipeline import ingest_cli
        from python.pipeline.db_connector import create_db_connector
        from python.pipeline.organizers import require_route

        require_route(code)
        db = create_db_connector()
        event = db.find_event_by_code(code)
        if event is None:
            raise ValueError(f"Event {code!r} not found in tbl_event.")
        url_event = event.get("url_event") or event.get("url_results")
        return ingest_cli.read_event(event, code, season_end_year, url_event, None, db=db)

    return read


def main(argv: Iterable[str] | None = None) -> int:
    import argparse
    import sys

    from python.pipeline.notifications import TelegramNotifier
    from python.pipeline.promotion.refresh import CERT_REF, PROD_REF, ManagementTransport
    from python.pipeline.promotion.run_record import run_url

    ap = argparse.ArgumentParser(description="The hourly results sync (ADR-119 §4).")
    ap.add_argument("step", choices=("select", "compare", "outcome"))
    ap.add_argument("--code", default=None, help="one event (a manual sync, or the cycle's)")
    ap.add_argument("--season-end-year", type=int, default=None)
    ap.add_argument("--cron", default="", help="the cron line that fired; empty for a manual run")
    ap.add_argument("--moment", default="", help="the cycle's due moment (the select's output)")
    ap.add_argument("--dry-run", action="store_true", help="read only: write and send nothing")
    args = ap.parse_args(list(argv) if argv is not None else None)

    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not token:
        print("SUPABASE_ACCESS_TOKEN is required", file=sys.stderr)
        return 1
    writes_cert = args.step != "compare" and not args.dry_run
    cert = SyncSql(ManagementTransport(CERT_REF, token, read_only=not writes_cert))
    prod = SyncSql(ManagementTransport(PROD_REF, token, read_only=True))
    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
    )
    code = args.code or None
    if args.step == "select":
        return run_select(
            cert,
            prod,
            now=dt.datetime.now(dt.UTC),
            cron=args.cron.strip() or None,
            code=code,
            switch=os.environ.get("RESULTS_SYNC"),
            dry_run=args.dry_run,
            send=notifier.send,
            output=_github_output,
        )
    if code is None or args.season_end_year is None:
        ap.error(f"{args.step} needs --code and --season-end-year")
    if args.step == "compare":
        return run_compare(
            code,
            read=_read_for(code, args.season_end_year),
            cert=cert,
            prod=prod,
            output=_github_output,
        )
    env = os.environ
    changed = env.get("SYNC_CHANGED", "")
    comparison = (
        Comparison(
            changed == "true",
            env.get("SYNC_PROMOTE_ONLY") == "true",
            int(env["SYNC_PREVIOUS_RUN"]) if env.get("SYNC_PREVIOUS_RUN") else None,
            [(str(n), int(c)) for n, c in json.loads(env.get("SYNC_NEW") or "[]")],
        )
        if changed in ("true", "false")
        else None
    )
    run_id = env.get("SYNC_RUN_ID", "")
    return run_outcome(
        code,
        cert=cert,
        prod=prod,
        moment=dt.datetime.fromisoformat(args.moment) if args.moment else dt.datetime.now(dt.UTC),
        comparison=comparison,
        run_id=int(run_id) if run_id.isdigit() else None,
        error=env.get("SYNC_ERROR") or None,
        refresh={
            "status": env.get("SYNC_REFRESH_STATUS", ""),
            "counts": env.get("SYNC_REFRESH_COUNTS", ""),
        },
        promote={
            "result": env.get("SYNC_PROMOTE_RESULT", ""),
            "writes": env.get("SYNC_PROMOTE_WRITES", ""),
        },
        run_url=run_url(),
        send=notifier.send,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    raise SystemExit(main())
