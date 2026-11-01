"""The daily close (ADR-108 §7, decision P4b A, build step 11).

The last promote of an event usually runs on its final day, before the end date
has passed, so the event stays IN_PROGRESS. Every morning `event-close.yml` (in
`prod-write`) takes each event of the active season, of every organizer (ADR-113), that is still
IN_PROGRESS on CERT or PROD and whose end date has passed, re-reads the
organiser's schedule, and completes the event on CERT and then on PROD when:

  - every listing is final, and none is dated after the end date;
  - the schedule is the one the latest finished CERT run read (nothing was
    added, removed or renamed since);
  - by the rule, that run read every listing;
  - CERT and PROD both hold that run's result (`fn_event_result_fingerprint`).

Otherwise it changes nothing and says on Telegram what to do: wait, ingest CERT
and promote again, promote, or correct the event's dates. It is idempotent: an
environment already COMPLETED is not written again, so a close that stopped
after CERT is finished by the next run, and a failure raises (the workflow
alerts).
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass, field
from typing import Any, Protocol

from python.pipeline.promotion import lifecycle
from python.pipeline.promotion.run_record import schedule_sha256
from python.supabase_token import supabase_access_token

_CODE = re.compile(r"^[A-Za-z0-9_-]+$")
Schedule = tuple[list[dict], list[dict]]


def route_code_regex() -> str:
    """Every event code the route carries, from the organizer registry
    (ADR-113 §6, ADR-119 §2): SPWS, PZSz, EVF, FIE and any organizer added."""
    from python.pipeline.organizers import route_code_regex as _regex

    return _regex()


class CloseFailed(RuntimeError):
    """At least one event could not be written; the others were handled."""


class Env(Protocol):
    name: str

    def events_to_close(self, today: dt.date) -> list[str]: ...

    def event(self, code: str) -> dict | None: ...

    def result_fingerprint(self, code: str) -> str | None: ...

    def latest_finished_run(self, code: str) -> dict | None: ...

    def set_status(self, code: str, status: str) -> None: ...


class Notifier(Protocol):
    def warning(self, message: str) -> None: ...

    def success(self, message: str) -> None: ...

    def error(self, message: str) -> None: ...


@dataclass
class Outcome:
    code: str
    closed: bool
    reasons: list[str] = field(default_factory=list)
    written: list[str] = field(default_factory=list)


def check(
    code: str,
    cert: Env,
    prod: Env,
    read_schedule: Callable[[str], Schedule],
    today: dt.date,
    read_sources: Callable[[list[str]], Schedule] | None = None,
) -> list[str]:
    """Why the event cannot be closed today; empty when it can. An
    international run is checked against the result slots it read
    (`read_sources`, ADR-113); every other run against its FTL schedule."""
    cert_event, prod_event = cert.event(code), prod.event(code)
    if prod_event is None or cert_event is None:
        return [f"the event is missing on {'PROD' if prod_event is None else 'CERT'}"]
    end = lifecycle.as_date(prod_event["dt_end"])
    reasons: list[str] = []
    if lifecycle.as_date(cert_event["dt_end"]) != end:
        reasons.append(
            f"CERT and PROD give different end dates ({cert_event['dt_end']}, {prod_event['dt_end']})"
        )
    run = cert.latest_finished_run(code)
    if run is None:
        return [*reasons, "CERT has no finished run of it: ingest CERT, then promote"]

    listings = run.get("listings") or {}
    if listings.get("sources") is not None:
        if read_sources is None:
            # The close runs after the end date, so every published bracket of
            # an engine without a finished signal is settled (ADR-119 §1).
            from python.pipeline.international_sources import read_schedule as _read_sources

            read_sources = _read_sources
        kept, skipped = read_sources([s["url"] for s in listings["sources"]])
    else:
        kept, skipped = read_schedule(run["url_event"])
    kept, not_final = lifecycle.split_final(kept)
    skipped = [*skipped, *not_final]
    # Every engine's not-final bracket: FTL's from its schedule row, and an
    # Engarde competition still running, which the reader already skipped.
    waiting = [s for s in skipped if lifecycle.is_not_final(s.get("reason"))]
    if waiting:
        names = ", ".join(s["name"] for s in waiting)
        if lifecycle.holds_open(end, today):
            reasons.append(f"not final yet: {names}")
        else:
            reasons.append(LeftOut(names))
    late = lifecycle.last_day([*kept, *waiting])
    if late and late > end.isoformat():
        reasons.append(
            f"a listing is dated {late}, after the end date {end.isoformat()}: "
            "correct the event's dates"
        )
    if schedule_sha256(kept, skipped) != (listings.get("schedule") or {}).get("sha256"):
        reasons.append(
            "the schedule changed since the CERT run (a listing was added, removed, renamed "
            "or finished): ingest CERT and promote again"
        )
    verdict = lifecycle.event_status(listings, dt_end=end, today=today)
    if verdict.status != lifecycle.COMPLETED:
        reasons.extend(f"the CERT run: {r}" for r in verdict.reasons)
    fingerprint = run.get("result_fingerprint")
    if cert.result_fingerprint(code) != fingerprint:
        reasons.append("CERT no longer holds its run's result: ingest CERT again")
    if prod.result_fingerprint(code) != fingerprint:
        reasons.append(_promote_reason(run.get("promote")))
    return reasons


class LeftOut(str):
    """Listings still not final at the source after the day after the end date
    (G44 A (3)): they no longer hold the event, which closes without them,
    and the close's message names them."""

    def line(self) -> str:
        return (
            f"completed without {self}: still not final at the source after the day after "
            "the end date; a manual ingest takes their results if they appear"
        )


class Quoted(str):
    """A reason quoting the promote ledger: Telegram gets it whole, the public
    Actions log only `public`, since a refusal can name a fencer (D12)."""

    public: str

    def __new__(cls, text: str, public: str) -> Quoted:
        quoted = super().__new__(cls, text)
        quoted.public = public
        return quoted


def _promote_reason(entry: Mapping[str, Any] | None) -> str:
    """Why PROD lacks the CERT run's result: the ledger's refusal when the last
    promote was refused (ADR-119 §3, D10), else the instruction to promote."""
    if not entry or entry.get("outcome") != "refused":
        return "PROD does not hold the CERT run's result: promote it"
    ts = dt.datetime.fromisoformat(str(entry.get("ts")))
    head = f"promote refused at {ts.astimezone(lifecycle.WARSAW):%Y-%m-%d %H:%M}"
    return Quoted(
        f"{head}: {entry.get('reason')}",
        f"{head} (the reason is in Telegram and on the CERT run's row)",
    )


def close_events(
    cert: Env,
    prod: Env,
    *,
    read_schedule: Callable[[str], Schedule],
    notifier: Notifier | None,
    today: dt.date,
    write: bool = True,
    read_sources: Callable[[list[str]], Schedule] | None = None,
) -> list[Outcome]:
    """Close every event that can be closed; report the others."""
    codes = sorted({*cert.events_to_close(today), *prod.events_to_close(today)})
    outcomes: list[Outcome] = []
    failures: list[str] = []
    for code in codes:
        try:
            found = check(code, cert, prod, read_schedule, today, read_sources)
        except Exception as e:  # one event's failure does not stop the others
            failures.append(f"{code}: {type(e).__name__}: {e}")
            continue
        left_out = [r for r in found if isinstance(r, LeftOut)]
        reasons = [r for r in found if not isinstance(r, LeftOut)]
        if reasons:
            outcomes.append(Outcome(code, False, reasons))
            head = f"Daily close: {code} stays IN_PROGRESS.\n"
            message = head + "\n".join(f"• {r}" for r in reasons)
            print(head + "\n".join(f"• {getattr(r, 'public', r)}" for r in reasons))
            if notifier is not None and write:
                notifier.warning(message)
            continue
        outcome = Outcome(code, True)
        where = cert.name
        try:
            for env in (cert, prod):  # CERT first, then PROD
                where = env.name
                event = env.event(code) or {}
                for step in lifecycle.steps(event.get("status"), lifecycle.COMPLETED):
                    if write:
                        env.set_status(code, step)
                    outcome.written.append(f"{env.name}:{step}")
        except Exception as e:
            failures.append(f"{code} on {where}: {type(e).__name__}: {e}")
            continue
        outcomes.append(outcome)
        message = f"Daily close: {code} is COMPLETED ({', '.join(outcome.written) or 'already'})."
        message += "".join(f"\n• {r.line()}" for r in left_out)
        print(message if write else f"(dry run) {message}")
        if notifier is not None and write:
            notifier.success(message)
    if failures:
        message = "Daily close failed:\n" + "\n".join(f"• {f}" for f in failures)
        print(message, file=sys.stderr)
        if notifier is not None:
            notifier.error(message)
        raise CloseFailed(message)
    return outcomes


# ---------------------------------------------------------------------------
# The environments over SQL (the gate's transports)
# ---------------------------------------------------------------------------


def _code(code: str) -> str:
    if not _CODE.match(code or ""):
        raise ValueError(f"not an event code: {code!r}")
    return code


class SqlEnv:
    """One environment through a `fetch_json` transport (refresh.Transport)."""

    def __init__(self, name: str, transport: Any):
        self.name = name
        self.transport = transport

    def events_to_close(self, today: dt.date) -> list[str]:
        return (
            self.transport.fetch_json(
                "SELECT coalesce(jsonb_agg(e.txt_code ORDER BY e.txt_code), '[]'::jsonb) AS j "
                "FROM tbl_event e JOIN tbl_season s ON s.id_season = e.id_season "
                f"WHERE s.bool_active AND e.enum_status = 'IN_PROGRESS' AND e.txt_code ~ '{route_code_regex()}' "
                f"AND e.dt_end < DATE '{today.isoformat()}'"
            )
            or []
        )

    def event(self, code: str) -> dict | None:
        return self.transport.fetch_json(
            "SELECT jsonb_build_object('code', txt_code, 'status', enum_status, "
            "'dt_end', dt_end, 'url_event', url_event) AS j "
            f"FROM tbl_event WHERE txt_code = '{_code(code)}'"
        )

    def result_fingerprint(self, code: str) -> str | None:
        return self.transport.fetch_json(
            f"SELECT to_jsonb(fn_event_result_fingerprint('{_code(code)}')) AS j"
        )

    def latest_finished_run(self, code: str) -> dict | None:
        return self.transport.fetch_json(
            "SELECT jsonb_build_object('url_event', url_event, 'listings', jsonb_listings, "
            "'result_fingerprint', txt_result_fingerprint, 'promote', jsonb_promote) AS j "
            "FROM tbl_ingest_run "
            f"WHERE txt_event_code = '{_code(code)}' AND txt_environment = 'cert' "
            "AND txt_status = 'FINISHED' ORDER BY id_ingest_run DESC LIMIT 1"
        )

    def set_status(self, code: str, status: str) -> None:
        if status not in (lifecycle.IN_PROGRESS, lifecycle.COMPLETED):
            raise ValueError(f"the close sets IN_PROGRESS or COMPLETED, not {status!r}")
        done = self.transport.fetch_json(
            f"WITH u AS (UPDATE tbl_event SET enum_status = '{status}' "
            f"WHERE txt_code = '{_code(code)}' RETURNING txt_code) "
            "SELECT coalesce(jsonb_agg(txt_code), '[]'::jsonb) AS j FROM u"
        )
        if done != [code]:
            raise RuntimeError(f"{self.name}: setting {code} to {status} updated {done}")


def read_ftl_schedule(url: str) -> Schedule:
    """The organiser's schedule as the ingestion reads it."""
    from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url
    from python.tools.scrape_ftl_event_urls import parse_event_schedule

    with get_authed_ftl_client() as client:
        resp = client.get(normalize_ftl_url(url))
        resp.raise_for_status()
        return parse_event_schedule(resp.text, with_skips=True)


def main(argv: Iterable[str] | None = None) -> int:
    from python.pipeline.notifications import TelegramNotifier
    from python.pipeline.promotion.refresh import CERT_REF, PROD_REF, ManagementTransport

    ap = argparse.ArgumentParser(description="The daily close (ADR-108 §7).")
    ap.add_argument("--dry-run", action="store_true", help="read only: report, write nothing")
    ap.add_argument("--today", default=None, help="the date in Warsaw (default: today)")
    args = ap.parse_args(list(argv) if argv is not None else None)

    token = supabase_access_token()
    if not token:
        print("SUPABASE_ACCESS_TOKEN is required", file=sys.stderr)
        return 1
    cert = SqlEnv("cert", ManagementTransport(CERT_REF, token, read_only=args.dry_run))
    prod = SqlEnv("prod", ManagementTransport(PROD_REF, token, read_only=args.dry_run))
    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
    )
    today = dt.date.fromisoformat(args.today) if args.today else lifecycle.warsaw_today()
    try:
        outcomes = close_events(
            cert,
            prod,
            read_schedule=read_ftl_schedule,
            notifier=notifier,
            today=today,
            write=not args.dry_run,
        )
    except CloseFailed:
        return 1
    closed = sum(o.closed for o in outcomes)
    print(f"daily close {today.isoformat()}: {closed} closed, {len(outcomes) - closed} left open")
    return 0


if __name__ == "__main__":
    sys.exit(main())
