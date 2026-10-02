"""
Write an event's organiser result URLs, only when each one is that event.

doc/plans/international-data-repair-batch-1-2026-10-01.html. The given URLs
replace every result slot of the event (FR-98: `url_event..url_event_5`), in
the order given, duplicates dropped. Before anything is written, each URL is
fetched and checked against the event (python/pipeline/source_identity.py):
its date, its city and, over all URLs, its weapons. One failure refuses the
whole write.

    python -m python.tools.set_event_source_urls --event-code PEW62efs-2025-2026 URL [URL ...]
    python -m python.tools.set_event_source_urls --event-code PEW3fs-2024-2025 --check-only

`--check-only` writes nothing; with no URL it checks the URLs already stored.
`--name-confirmed-by "<who, when>"` records that a person confirmed the URLs
are this event when the page names neither its city, its country nor the
event; the date and the weapons are still checked.

Tests: python/tests/test_source_identity.py (REPAIR.URL.01).
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Callable

from python.pipeline.source_identity import (
    SourceIdentity,
    check_event_sources,
    read_source_identity,
)

MAX_SLOTS = 5
_SLOTS = ("url_event", "url_event_2", "url_event_3", "url_event_4", "url_event_5")


def stored_urls(event: dict) -> list[str]:
    return [event[s] for s in _SLOTS if event.get(s)]


def fetch_source_identity(url: str) -> SourceIdentity:
    """GET the page (FTL through the logged-in client) and read it."""
    if "fencingtimelive.com" in url:
        from python.pipeline.review_cli import _normalize_ftl_url
        from python.scrapers.ftl_auth import get_authed_ftl_client

        with get_authed_ftl_client() as client:
            resp = client.get((_normalize_ftl_url(url) or url).split("#")[0])
            resp.raise_for_status()
            return read_source_identity(url, resp.text)
    import httpx

    resp = httpx.get(
        url, follow_redirects=True, timeout=30.0, headers={"User-Agent": "Mozilla/5.0"}
    )
    resp.raise_for_status()
    return read_source_identity(url, resp.text)


def _report(problems: dict[str, list[str]]) -> str:
    lines = []
    for url, items in problems.items():
        where = "all sources" if url == "*" else url
        lines.extend(f"  {where}: {p}" for p in items)
    return "\n".join(lines)


def check_urls(
    db,
    event_code: str,
    urls: list[str],
    *,
    read: Callable[[str], SourceIdentity],
    name_confirmed: bool = False,
) -> tuple[dict, list[str], dict[str, list[str]]]:
    """Return (event, the de-duplicated URLs, problems), refusing bad input first."""
    event = db.fetch_event_for_source_check(event_code)
    if event is None:
        raise ValueError(f"no event with code {event_code!r} (an exact code)")
    wanted = list(dict.fromkeys(u.strip() for u in urls if u and u.strip()))
    if not wanted:
        raise ValueError(f"{event_code}: no URL to check")
    if len(wanted) > MAX_SLOTS:
        raise ValueError(f"{event_code}: {len(wanted)} URLs; an event has five result slots")
    idents = [read(u) for u in wanted]
    return event, wanted, check_event_sources(event, idents, name_confirmed=name_confirmed)


def set_event_source_urls(
    db,
    event_code: str,
    urls: list[str],
    *,
    read: Callable[[str], SourceIdentity],
    name_confirmed: bool = False,
) -> list[str]:
    """Check every URL against the event, then write them; refuse on any problem."""
    event, wanted, problems = check_urls(
        db, event_code, urls, read=read, name_confirmed=name_confirmed
    )
    if problems:
        raise ValueError(
            f"{event_code}: not written, a source is not this event:\n{_report(problems)}"
        )
    db.set_event_source_urls(event["id_event"], wanted)
    return wanted


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Write an event's organiser result URLs, only when each one is that event."
    )
    parser.add_argument("--event-code", required=True)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--name-confirmed-by", default=None)
    parser.add_argument("urls", nargs="*")
    args = parser.parse_args()

    from python.pipeline.db_connector import create_db_connector

    db = create_db_connector()
    urls = args.urls
    if not urls:
        if not args.check_only:
            parser.error("URLs are required unless --check-only")
        event = db.fetch_event_for_source_check(args.event_code)
        urls = stored_urls(event) if event else []
    confirmed = bool(args.name_confirmed_by)
    if confirmed:
        print(f"{args.event_code}: name confirmed by {args.name_confirmed_by}")
    try:
        if args.check_only:
            _, wanted, problems = check_urls(
                db, args.event_code, urls, read=fetch_source_identity, name_confirmed=confirmed
            )
            print(f"{args.event_code}: {len(wanted)} URL(s) checked")
            if problems:
                print(_report(problems))
                return 1
            print("  every source is this event")
            return 0
        written = set_event_source_urls(
            db, args.event_code, urls, read=fetch_source_identity, name_confirmed=confirmed
        )
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 1
    print(f"{args.event_code}: wrote {len(written)} URL(s) to the result slots")
    return 0


if __name__ == "__main__":
    sys.exit(main())
