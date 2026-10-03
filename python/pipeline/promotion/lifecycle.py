"""The event lifecycle rule (ADR-108 §7, build step 11).

A listing is final only when its FTL schedule row says Finished. A domestic
ingestion skips a listing that is not final and lists it under the schedule's
skips, so the run record, promote's source check and the admin accordion all
show it. An event is COMPLETED once every listing is final and read, no listing
is dated after the end date, and today in Warsaw is later than the end date;
otherwise it is IN_PROGRESS. Organisers sometimes add a tournament the next day,
which is why the end date matters.

The same rule runs on CERT (the ingestion), in promote's plan (the status its
apply sets on PROD) and in the daily close (`promotion/close.py`).
"""

from __future__ import annotations

import datetime as dt
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from typing import Any
from zoneinfo import ZoneInfo

WARSAW = ZoneInfo("Europe/Warsaw")
NOT_FINAL = "not final (its schedule row does not say Finished)"
IN_PROGRESS = "IN_PROGRESS"
COMPLETED = "COMPLETED"


def warsaw_today(now: dt.datetime | None = None) -> dt.date:
    """Today's date in Warsaw."""
    return (now or dt.datetime.now(dt.UTC)).astimezone(WARSAW).date()


def split_final(kept: Iterable[Mapping[str, Any]]) -> tuple[list[dict], list[dict]]:
    """The final listings, and a schedule skip for each one that is not. A
    listing without the mark counts as not final."""
    final: list[dict] = []
    skips: list[dict] = []
    for k in kept:
        if k.get("finished") is True:
            final.append(dict(k))
        else:
            skips.append({**k, "reason": NOT_FINAL})
    return final, skips


def last_day(entries: Iterable[Mapping[str, Any]]) -> str | None:
    """The latest ISO day among the entries, or None."""
    return max((e["day"] for e in entries if e.get("day")), default=None)


@dataclass(frozen=True)
class Verdict:
    status: str
    committed: bool
    reasons: list[str] = field(default_factory=list)


def event_status(listings: Mapping[str, Any], *, dt_end: dt.date, today: dt.date) -> Verdict:
    """The rule over what a run read (`ListingLog.listings()`)."""
    schedule = listings.get("schedule") or {}
    rounds = listings.get("rounds") or []
    reasons: list[str] = []

    not_final = [s["name"] for s in schedule.get("skipped") or [] if s.get("reason") == NOT_FINAL]
    if not_final:
        reasons.append(f"not final yet: {', '.join(not_final)}")

    unparseable = [r["name"] for r in rounds if r.get("status") == "unparseable"]
    read = [r for r in rounds if r.get("status") != "unparseable"]
    if unparseable:
        reasons.append(f"not read (name not understood): {', '.join(unparseable)}")
    elif len(read) < int(schedule.get("kept") or 0):
        reasons.append(f"{int(schedule.get('kept') or 0) - len(read)} listing(s) not read")

    late = schedule.get("last_day")
    if late and late > dt_end.isoformat():
        reasons.append(
            f"a listing is dated {late}, after the end date {dt_end.isoformat()}: "
            "correct the event's dates"
        )

    if today <= dt_end:
        reasons.append(
            f"the end date {dt_end.isoformat()} has not passed (today in Warsaw: {today.isoformat()})"
        )

    committed = any(r.get("status") == "committed" for r in rounds)
    return Verdict(COMPLETED if not reasons else IN_PROGRESS, committed, reasons)


def target_status(listings: Mapping[str, Any], *, dt_end: dt.date, today: dt.date) -> str | None:
    """The status a run leaves the event in, or None when it committed nothing
    (an event without a result is not moved to IN_PROGRESS, ADR-037)."""
    v = event_status(listings, dt_end=dt_end, today=today)
    return v.status if v.committed else None


def steps(current: str | None, target: str) -> list[str]:
    """The writes from `current` to `target` through the transition validator's
    pairs: PLANNED never jumps to COMPLETED, and an unchanged status is not written."""
    if current == target:
        return []
    if target == COMPLETED and current in ("PLANNED", "CREATED", None):
        return [IN_PROGRESS, COMPLETED]
    return [target]


def as_date(value: Any) -> dt.date:
    """An event date as read from the database (a date or ISO text)."""
    if isinstance(value, dt.date):
        return value
    return dt.date.fromisoformat(str(value)[:10])


def apply(
    db: Any, event: Mapping[str, Any], listings: Mapping[str, Any], today: dt.date
) -> str | None:
    """Set the event's status by the rule through `db.set_event_status`.
    Returns the status written, or None when nothing changed."""
    end = event.get("dt_end") or event.get("dt_start")
    if not end:
        return None
    verdict = event_status(listings, dt_end=as_date(end), today=today)
    if not verdict.committed:
        return None
    current = event.get("enum_status")
    todo = steps(current, verdict.status)
    for status in todo:
        db.set_event_status(event["id_event"], status)
    if todo:
        why = (
            "; ".join(verdict.reasons)
            or "every listing is final and read, and the end date has passed"
        )
        print(f"lifecycle: {event.get('txt_code')} {current} -> {verdict.status} ({why})")
    return todo[-1] if todo else None
