"""
PZSz senior calendar sync (CERT).

Fetch -> filter -> plan -> diff against CERT -> insert/update. The parsing and
planning live in pzsz_calendar.py and touch nothing; this module is the half
that decides what to write.

    python -m python.scrapers.pzsz_sync --dry-run
    python -m python.scrapers.pzsz_sync

WHAT THIS WRITES, AND WHAT IT DOES NOT.

Events are created CHILDLESS -- no tournament rows at all.
tbl_tournament.enum_age_category is NOT NULL over V0..V4 and a senior bracket
has no honest value for it, so that question belongs to the scoring deliverable.
This is a supported state, not a workaround: ADR-081 records that the
reconciler's CREATE is childless, and ADR-084 deliberately reads weapons from
the event code rather than from arr_weapons, so tiles and cards render weapons
correctly with zero tournaments present.

url_registration and dt_registration_deadline are never written. PZSz publishes
neither per event: all seven measured komunikaty resolve entry to the
federation's standing regulations, and entry itself runs through a login-walled,
club-mediated licence system. A non-empty url_registration plus dt_end is what
lights an event tile's live-registration dot (ADR-084), so a plausible-looking
value would tell a veteran they can enter when they cannot. An empty field
states the truth.

FIELD OWNERSHIP mirrors the reconciler's existing split (ADR-081). Identity and
schedule are source-owned and actively propagated, because a moved date or a
renamed round must reach the calendar. Enrichment is fill-blank-only, because
an admin who typed a better value should keep it.

DELETION IS NOT OURS. A row whose PZSz id we hold but which has vanished from
the listing is a cancellation or a re-key; deleting it would take any
registrations with it. The scraper reports and leaves it for a human.
"""

from __future__ import annotations

import argparse
import os
import sys
import traceback
from dataclasses import dataclass, field

import httpx

from python.scrapers._supabase import _get_active_season as _shared_get_active_season
from python.scrapers._supabase import _management_query, _telegram
from python.scrapers.pzsz_calendar import (
    PZSZ_EVENT,
    collect_season_candidates,
    parse_event_detail_html,
    plan_event_codes,
    venue_address_from_pdf_bytes,
)

ORGANIZER_CODE = "PZSz"

# Identity and schedule: the source owns these outright and changes are pushed
# onto the existing row, because a reschedule or a renamed round has to reach
# the calendar a veteran is planning around.
SOURCE_OWNED_FIELDS = ("txt_code", "txt_name", "dt_start", "dt_end", "txt_location", "txt_country")

# Published late and only once: filled the first time the source has them, never
# overwritten afterwards.
FILL_BLANK_FIELDS = ("url_invitation", "txt_venue_address")

# The scraped-row key that feeds each column.
_SCRAPED_KEY = {
    "txt_code": "desired_code",
    "txt_name": "name",
    "dt_start": "dt_start",
    "dt_end": "dt_end",
    "txt_location": "location",
    "txt_country": "txt_country",
    "url_invitation": "url_invitation",
    "txt_venue_address": "txt_venue_address",
}


@dataclass
class SyncPlan:
    """What one run intends to do to CERT, before anything is sent."""

    creates: list[dict] = field(default_factory=list)
    updates: list[dict] = field(default_factory=list)
    vanished: list[dict] = field(default_factory=list)


def _get_active_season(ref: str, token: str) -> dict | None:
    """Active season from CERT, pinned to THIS module's `_management_query`.

    A thin wrapper rather than a re-export, so patching `pzsz_sync
    ._management_query` in a test intercepts this query like every other.
    """
    return _shared_get_active_season(ref, token, query=_management_query)


def _sql(value: object) -> str:
    """One SQL literal. NULL for absent, doubled quotes for everything else."""
    if value is None or value == "":
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, int):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def _blank(value: object) -> bool:
    return value is None or (isinstance(value, str) and not value.strip())


def diff_against_cert(planned: list[dict], existing: list[dict]) -> SyncPlan:
    """Decide the writes for one run. Pure: no I/O, no ordering assumptions.

    Matching is by PZSz id FIRST and by event code only as a fallback. That
    order is load-bearing rather than tidy. PZSz names drift in casing and carry
    live typos, and a round number can move, which changes the code -- so a
    code-first match would read a rescheduled event as "delete this one, create
    that one" and lose whatever is anchored to the old code. The code fallback
    exists for the other direction: a row an admin entered by hand before the
    scraper existed has no source id, and should be adopted rather than
    duplicated.
    """
    plan = SyncPlan()

    by_source_id = {
        int(row["id_pzsz_event"]): row for row in existing if row.get("id_pzsz_event") is not None
    }
    by_code = {row["txt_code"]: row for row in existing}

    matched_ids: set[int] = set()
    for scraped in planned:
        source_id = int(scraped["id_pzsz_event"])
        current = by_source_id.get(source_id) or by_code.get(scraped["desired_code"])

        if current is None:
            plan.creates.append(scraped)
            continue

        matched_ids.add(int(current["id_event"]))
        changes: dict[str, object] = {}

        if current.get("id_pzsz_event") is None:
            changes["id_pzsz_event"] = source_id

        for column in SOURCE_OWNED_FIELDS:
            value = scraped.get(_SCRAPED_KEY[column])
            if _blank(value):
                continue
            if str(current.get(column) or "") != str(value):
                changes[column] = value

        for column in FILL_BLANK_FIELDS:
            value = scraped.get(_SCRAPED_KEY[column])
            if _blank(value) or not _blank(current.get(column)):
                continue
            changes[column] = value

        if changes:
            plan.updates.append({"id_event": int(current["id_event"]), "fields": changes})

    scraped_ids = {int(row["id_pzsz_event"]) for row in planned}
    plan.vanished = [
        row
        for row in existing
        if row.get("id_pzsz_event") is not None
        and int(row["id_pzsz_event"]) not in scraped_ids
        and int(row["id_event"]) not in matched_ids
    ]

    return plan


def build_insert_sql(scraped: dict, season: dict) -> str:
    """One INSERT for a new PZSz event.

    The organizer is resolved by code in the statement itself, exactly as
    promote.py resolves it onto PROD. If the organizer migration has not reached
    this environment the subquery yields NULL, id_organizer is NOT NULL, and the
    insert fails loudly -- which is the right outcome, because the alternative
    is an event nobody owns.
    """
    return (
        "INSERT INTO tbl_event ("
        "txt_code, txt_name, id_season, id_organizer, txt_location, txt_country, "
        "dt_start, dt_end, url_event, arr_weapons, id_pzsz_event) VALUES ("
        f"{_sql(scraped['desired_code'])}, "
        f"{_sql(scraped['name'])}, "
        f"{int(season['id_season'])}, "
        f"(SELECT id_organizer FROM tbl_organizer WHERE txt_code = '{ORGANIZER_CODE}'), "
        f"{_sql(scraped.get('location'))}, "
        f"{_sql(scraped.get('txt_country') or 'PL')}, "
        f"{_sql(scraped['dt_start'])}::DATE, "
        f"{_sql(scraped.get('dt_end') or scraped['dt_start'])}::DATE, "
        f"{_sql(scraped.get('url_event'))}, "
        f"'{{{','.join(scraped.get('weapons') or [])}}}'::enum_weapon_type[], "
        f"{int(scraped['id_pzsz_event'])})"
    )


def build_update_sql(update: dict) -> str:
    """One UPDATE for a matched PZSz event."""
    assignments = []
    for column, value in update["fields"].items():
        cast = "::DATE" if column.startswith("dt_") else ""
        assignments.append(f"{column} = {_sql(value)}{cast}")
    assignments.append("ts_updated = NOW()")
    return (
        f"UPDATE tbl_event SET {', '.join(assignments)} WHERE id_event = {int(update['id_event'])}"
    )


def enrich_events(
    rows: list[dict],
    client: httpx.Client | None = None,
    timeout: float = 30.0,
) -> list[dict]:
    """Re-visit each event's detail page and fill the letter and address.

    Runs on every event, every day, on purpose. None of the six 2026/2027 events
    carries a komunikat today -- their detail pages read "Brak komunikatow" --
    because the letter is published closer to the date. So the field cannot be
    filled at first scrape, and the daily cron is what eventually fills it. A
    detail page that fails is logged and skipped: one unreachable page must not
    cost the whole run.
    """
    owned = client is None
    http = client or httpx.Client(timeout=timeout, follow_redirects=True)
    enriched: list[dict] = []
    try:
        for row in rows:
            event = dict(row)
            try:
                page = http.get(PZSZ_EVENT, params={"id": int(event["id_pzsz_event"])})
                page.raise_for_status()
                detail = parse_event_detail_html(page.text)
                invitation = detail.get("url_invitation")
                if invitation:
                    event["url_invitation"] = invitation
                    letter = http.get(invitation)
                    letter.raise_for_status()
                    address = venue_address_from_pdf_bytes(letter.content)
                    if address:
                        event["txt_venue_address"] = address
            except Exception as exc:  # noqa: BLE001 — enrichment is best-effort
                print(f"  ! detail page {event.get('id_pzsz_event')} skipped: {exc}")
            enriched.append(event)
    finally:
        if owned:
            http.close()
    return enriched


def sync_calendar(
    ref: str,
    token: str,
    bot_token: str,
    chat_id: str,
    dry_run: bool,
) -> SyncPlan:
    """One full PZSz calendar run against CERT."""
    season = _get_active_season(ref, token)
    if not season:
        raise RuntimeError("No active season on CERT — cannot sync the PZSz calendar")

    print(
        f"PZSz calendar sync — season {season['txt_code']} "
        f"({season['dt_start']} … {season['dt_end']})"
    )

    candidates = collect_season_candidates(season["dt_start"], season["dt_end"])
    candidates = enrich_events(candidates)
    planned = plan_event_codes(candidates, season["txt_code"])

    print(f"  {len(planned)} national senior event(s) inside our window")
    for row in planned:
        letter = " +komunikat" if row.get("url_invitation") else ""
        print(
            f"  {row['dt_start']}  {row['desired_code']:<18} "
            f"{row['location']:<12} {','.join(row.get('weapons') or [])}{letter}"
        )

    existing = _management_query(
        ref,
        token,
        "SELECT e.id_event, e.txt_code, e.id_pzsz_event, e.txt_name, "
        "e.dt_start::TEXT, e.dt_end::TEXT, e.txt_location, e.txt_country, "
        "e.url_invitation, e.txt_venue_address "
        "FROM tbl_event e JOIN tbl_organizer o ON o.id_organizer = e.id_organizer "
        f"WHERE e.id_season = {int(season['id_season'])} AND o.txt_code = '{ORGANIZER_CODE}'",
    )

    plan = diff_against_cert(planned, existing)
    print(
        f"  {len(plan.creates)} to create, {len(plan.updates)} to update, "
        f"{len(plan.vanished)} vanished from the source"
    )

    for row in plan.vanished:
        print(
            f"  ! {row['txt_code']} (PZSz id {row['id_pzsz_event']}) is no longer listed — "
            "cancellation or re-key; left for an admin, never deleted here"
        )

    if dry_run:
        for row in plan.creates:
            print(f"  [dry-run] {build_insert_sql(row, season)}")
        for update in plan.updates:
            print(f"  [dry-run] {build_update_sql(update)}")
        return plan

    for row in plan.creates:
        _management_query(ref, token, build_insert_sql(row, season))
    for update in plan.updates:
        _management_query(ref, token, build_update_sql(update))

    if plan.creates or plan.updates or plan.vanished:
        vanished_note = (
            f"\n⚠️ {len(plan.vanished)} no longer listed: "
            + ", ".join(row["txt_code"] for row in plan.vanished)
            if plan.vanished
            else ""
        )
        _telegram(
            bot_token,
            chat_id,
            f"<b>PZSz Calendar</b>\n"
            f"created={len(plan.creates)}, updated={len(plan.updates)}"
            f"{vanished_note}",
        )

    return plan


def main() -> None:
    parser = argparse.ArgumentParser(description="PZSz senior calendar sync")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Plan and print the statements without sending any write.",
    )
    args = parser.parse_args()

    ref = os.environ.get("SUPABASE_CERT_REF", "")
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "")

    if not ref or not token:
        print("ERROR: SUPABASE_CERT_REF and SUPABASE_ACCESS_TOKEN required", file=sys.stderr)
        raise SystemExit(2)

    try:
        sync_calendar(ref, token, bot_token, chat_id, args.dry_run)
    except Exception as exc:
        print(f"ERROR: PZSz calendar sync failed: {exc}", file=sys.stderr)
        traceback.print_exc()
        _telegram(bot_token, chat_id, f"❌ <b>PZSz Calendar</b> failed\n{exc}")
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
