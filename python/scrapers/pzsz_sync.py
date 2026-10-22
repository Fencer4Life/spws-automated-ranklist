"""The PZSz senior calendar run (ADR-116 §7): seven steps, none stops the next.

Rewritten for the robust calendar workflow. The run reads OUR list of future
PZSz events from CERT, discovers new ones from the listing (rendered by the
browser, §6), reads each event's organizer letter, decides every field with
one rule set (§9, :mod:`pzsz_write_rules`), and writes each event atomically
through ``fn_pzsz_apply_event`` (§14). It processes everything, sends one
Telegram digest, and sets its exit status last — green with warnings, red only
for a fatal state on a named event (§11-§12).

R1 read our list · R2 discover (listing) · R3 the home page · R4 the per-event
passes and the write · R5 the "send ingest" notice · R6 one digest · R7 exit.

The letter reader (passes 1-4) is :func:`pzsz_letter.read_letter`, built in
piece 3 and injected here as a seam so the run is tested with a fake. Every
external edge — the CERT query, the browser fetch, the home page, the letter
download, the letter reader, Telegram — is an injected seam on
:func:`run_calendar`; :func:`main` wires the real ones.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import sys
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field

from python.pipeline.promotion.lifecycle import warsaw_today
from python.scrapers._supabase import _get_active_season as _shared_get_active_season
from python.scrapers._supabase import _management_query, _telegram
from python.scrapers.pzsz_calendar import (
    LISTING_ROW_CAP,
    PZSZ_CALENDAR,
    SERIES_QUERIES,
    PzszSourceDataError,
    belongs_to_season,
    is_national_senior,
    parse_calendar_html,
    plan_event_codes,
    season_keys_for_window,
)
from python.scrapers.pzsz_letter import PARSER_VERSION, LetterContext, LetterResult, read_letter
from python.scrapers.pzsz_sources import (
    HomeRow,
    _letter_links_by_event,
    newest_letter,
    parse_home_page,
)
from python.scrapers.pzsz_start_list import is_js_check
from python.scrapers.pzsz_write_rules import Candidate, FieldState, decide

ORGANIZER_CODE = "PZSz"
_TERMINAL = ("COMPLETED", "CANCELLED")

# Query / Telegram / fetch seams.
Query = Callable[[str, str, str], list[dict]]
Telegram = Callable[[str, str, str], None]
Fetch = Callable[[str, Mapping[str, object]], str]  # the browser: (url, params) -> html
HomeFetch = Callable[[], str]  # the home page HTML (not gated)
LetterFetch = Callable[[str], bytes | None]  # a letter's bytes, or None if unreadable
ReadLetter = Callable[[bytes, LetterContext], LetterResult]

# The fields the run decides, in order. City is written from the listing/home
# (the letter only validates it, §9 D2); the letter owns address and leads on
# dates; link and fee are read only while empty (rule 8).
_DECIDED_FIELDS = (
    "url_invitation",
    "txt_location",
    "dt_start",
    "dt_end",
    "txt_venue_address",
    "num_entry_fee",
)
_FILL_BLANK = {"url_invitation", "num_entry_fee"}
# What a created event's INSERT sets, so its provenance is seeded this run.
_CREATE_SEEDED = ("dt_start", "dt_end", "txt_location")


def _sql(value: object) -> str:
    """One SQL literal. NULL for absent, doubled quotes otherwise."""
    if value is None or value == "":
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, int):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def _blank(value: object) -> bool:
    return value is None or (isinstance(value, str) and not value.strip())


def _jsonb(payload: Mapping[str, object]) -> str:
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    return "'" + text.replace("'", "''") + "'::jsonb"


def _is_future(dt_start: object, today: dt.date) -> bool:
    """A future event: no start date yet, or its first day is after today
    (from its first day the run reads nothing for it — §9 rule 7, D6)."""
    if _blank(dt_start):
        return True
    return dt.date.fromisoformat(str(dt_start)[:10]) > today


def _get_active_season(ref: str, token: str, query: Query) -> dict | None:
    return _shared_get_active_season(ref, token, query=query)


@dataclass
class _Digest:
    """The one message a run builds as it goes, and the fatal events."""

    plain: list[str] = field(default_factory=list)
    warn: list[str] = field(default_factory=list)
    fatal: list[str] = field(default_factory=list)

    def message(self) -> str:
        lines = ["<b>PZSz Calendar</b>"]
        lines += self.plain
        lines += [f"⚠️ {w}" for w in self.warn]
        lines += [f"❌ {f}" for f in self.fatal]
        return "\n".join(lines)

    def is_red(self) -> bool:
        return bool(self.fatal)


def build_insert_sql(scraped: dict, season: dict) -> str:
    """One INSERT for a new PZSz event, returning its id_event. Dates, city and
    the pzszerm page URL come from the listing; the letter fields are left for
    the per-event passes. The organizer is resolved by code, exactly as
    promote.py does onto PROD; a missing organizer fails loudly."""
    weapons = ",".join(scraped.get("weapons") or [])
    return (
        "INSERT INTO tbl_event ("
        "txt_code, txt_name, id_season, id_organizer, txt_location, txt_country, "
        "dt_start, dt_end, url_event, arr_weapons, id_pzsz_event) VALUES ("
        f"{_sql(scraped['desired_code'])}, {_sql(scraped['name'])}, {int(season['id_season'])}, "
        f"(SELECT id_organizer FROM tbl_organizer WHERE txt_code = '{ORGANIZER_CODE}'), "
        f"{_sql(scraped.get('location'))}, {_sql(scraped.get('txt_country') or 'PL')}, "
        f"{_sql(scraped.get('dt_start'))}::DATE, "
        f"{_sql(scraped.get('dt_end') or scraped.get('dt_start'))}::DATE, "
        f"{_sql(scraped.get('url_event'))}, "
        f"'{{{weapons}}}'::enum_weapon_type[], {int(scraped['id_pzsz_event'])}) "
        "RETURNING id_event"
    )


def discover_listing(fetch: Fetch, season: dict, digest: _Digest) -> tuple[dict[int, dict], bool]:
    """R2: the national-senior PPS/MPS events the listing shows inside our
    season window, keyed by PZSz id, each with its newest letter link. Fetched
    by the browser, one series/season query at a time. Returns the rows and
    whether the listing was fully served (False → a check or render failure was
    met; the run goes on from our list, §11). A 70-row page is used but warned
    (the source truncates silently)."""
    by_id: dict[int, dict] = {}
    served = True
    for series in SERIES_QUERIES:
        for key in season_keys_for_window(season["dt_start"], season["dt_end"]):
            params = {"Nazwa": SERIES_QUERIES[series], "SezonAutocomplete": key}
            try:
                html = fetch(PZSZ_CALENDAR, params)
            except Exception as exc:  # noqa: BLE001 — a source that will not read is recorded
                served = False
                digest.warn.append(f"listing {series} {key}: not served ({exc})")
                continue
            if is_js_check(html):
                served = False
                digest.warn.append(f"listing {series} {key}: the JavaScript check, not the page")
                continue
            rows = parse_calendar_html(html)
            if len(rows) >= LISTING_ROW_CAP:
                digest.warn.append(
                    f"listing {series} {key}: {len(rows)} rows at the {LISTING_ROW_CAP} cap — "
                    "events missing from it are not judged gone"
                )
            letters = _letter_links_by_event(html)
            for row in rows:
                if not is_national_senior(row) or not belongs_to_season(
                    row, season["dt_start"], season["dt_end"]
                ):
                    continue
                rid = int(row["id_pzsz_event"])
                link = newest_letter(letters.get(rid, []))
                row["letter_url"] = link.url if link else None
                by_id.setdefault(rid, row)
    return by_id, served


def _code_for(row: dict, season_code: str) -> str | None:
    """A row's event code, or None when it has no round numeral (skipped)."""
    try:
        return plan_event_codes([row], season_code)[0]["desired_code"]
    except PzszSourceDataError:
        return None


def _new_events(
    listing: dict[int, dict],
    existing_ids: set[int],
    season: dict,
    today: dt.date,
    digest: _Digest,
) -> list[dict]:
    """The future listing events not already in CERT, each with a code. A row
    with no numeral, an empty start date, or a code another row also resolves
    to is skipped and warned — one bad row never stops the others (§11)."""
    coded: list[dict] = []
    for rid, row in listing.items():
        if rid in existing_ids:
            continue
        if _blank(row.get("dt_start")) or not _is_future(row.get("dt_start"), today):
            continue
        code = _code_for(row, season["txt_code"])
        if code is None:
            digest.warn.append(
                f"listing event {rid}: no round numeral in {row.get('name')!r} — skipped"
            )
            continue
        coded.append({**row, "desired_code": code})
    by_code: dict[str, list[dict]] = {}
    for row in coded:
        by_code.setdefault(row["desired_code"], []).append(row)
    fresh: list[dict] = []
    for code, group in by_code.items():
        if len(group) > 1:
            ids = ", ".join(str(r["id_pzsz_event"]) for r in group)
            digest.warn.append(f"listing events {ids} all resolve to {code} — none created")
            continue
        fresh.append(group[0])
    return fresh


def _apply_event(
    ref: str,
    token: str,
    query: Query,
    id_event: int,
    changes: list[dict],
    reports: list[dict],
    checks: list[dict],
) -> dict:
    payload = {"changes": changes, "reports": reports, "checks": checks}
    rows = query(ref, token, f"SELECT fn_pzsz_apply_event({int(id_event)}, {_jsonb(payload)}) AS r")
    return (rows or [{}])[0].get("r") or {}


def _process_event(  # noqa: PLR0912, PLR0913, PLR0915 — R4's pass pipeline, kept in one place
    event: dict,
    *,
    created: bool,
    listing_row: dict | None,
    home_row: HomeRow | None,
    state: Mapping[str, FieldState],
    reports: Mapping[str, Mapping[str, str]],
    season: dict,
    letter_fetch: LetterFetch,
    read_letter_fn: ReadLetter,
    digest: _Digest,
) -> tuple[list[dict], list[dict], list[dict]]:
    """R4 for one event: gather each field's candidates from the letter, the
    listing and the home page; decide every field; return the fn payload parts
    (changes, reports, checks). One event's work never touches another's."""
    code = str(event["txt_code"])
    current = {f: event.get(f) for f in _DECIDED_FIELDS}
    city = str(current.get("txt_location") or "")
    anchor = str(current.get("dt_start") or (listing_row or {}).get("dt_start") or "")

    # pass 0: the letter link is read only while empty; the held link is what the
    # passes read. Look in the listing row when none is held.
    letter_url = str(current.get("url_invitation") or "") or (
        str((listing_row or {}).get("letter_url") or "")
        if _blank(current.get("url_invitation"))
        else ""
    )

    letter: LetterResult | None = None
    letter_sha: str | None = None
    if letter_url:
        data = letter_fetch(letter_url)
        if data is None:
            digest.warn.append(f"{code}: the letter at {letter_url} could not be downloaded")
        else:
            letter_sha = hashlib.sha256(data).hexdigest()
            ctx = LetterContext(
                city=city,
                dt_start=anchor,
                season_start=str(season["dt_start"]),
                season_end=str(season["dt_end"]),
            )
            try:
                letter = read_letter_fn(data, ctx)
            except Exception as exc:  # noqa: BLE001 — a pass that raises is caught (§11)
                digest.warn.append(f"{code}: the letter could not be read ({exc})")

    candidates: dict[str, list[Candidate]] = {f: [] for f in _DECIDED_FIELDS}
    if _blank(current.get("url_invitation")) and letter_url:
        candidates["url_invitation"].append(Candidate("listing", letter_url))
    if listing_row and not _blank(listing_row.get("location")):
        candidates["txt_location"].append(Candidate("listing", str(listing_row["location"])))
    if home_row and home_row.city:
        candidates["txt_location"].append(Candidate("home", home_row.city))
    for src, row_start, row_end in (
        ("listing", (listing_row or {}).get("dt_start"), (listing_row or {}).get("dt_end")),
        ("home", getattr(home_row, "dt_start", ""), getattr(home_row, "dt_end", "")),
    ):
        if not _blank(row_start):
            candidates["dt_start"].append(Candidate(src, str(row_start)))
        if not _blank(row_end):
            candidates["dt_end"].append(Candidate(src, str(row_end)))

    checks: list[dict] = []
    if letter is not None:
        if not letter.has_text:
            checks.append(
                {"scope": code, "check": "letter", "state": "no_text", "detail": letter_url}
            )
            digest.warn.append(f"{code}: the letter has no text — enter its fields in Admin (D7)")
        else:
            checks.append({"scope": code, "check": "letter", "state": "read", "detail": ""})
            if letter.city_match is False:
                digest.warn.append(
                    f"{code}: the letter's venue city {letter.city_seen!r} is not the calendar city {city!r}"
                )
            if letter.dt_start:
                candidates["dt_start"].insert(
                    0, Candidate("letter", letter.dt_start, letter.dates_evidence)
                )
                candidates["dt_end"].insert(
                    0, Candidate("letter", letter.dt_end or letter.dt_start, letter.dates_evidence)
                )
            if letter.dates_note:
                digest.warn.append(f"{code}: dates — {letter.dates_note}")
            if letter.address:
                candidates["txt_venue_address"].append(
                    Candidate("letter", letter.address.value, letter.address.evidence)
                )
            elif letter.address_candidates:
                digest.warn.append(
                    f"{code}: two venue-address candidates, none written: "
                    + " | ".join(letter.address_candidates)
                )
            if letter.fee:
                candidates["num_entry_fee"].append(
                    Candidate("letter", letter.fee.value, letter.fee.evidence)
                )
            elif letter.fee_candidates:
                digest.warn.append(
                    f"{code}: two fee candidates, none written: "
                    + " | ".join(letter.fee_candidates)
                )
            for note in letter.notes:
                digest.warn.append(f"{code}: {note}")

    changes: list[dict] = []
    out_reports: list[dict] = []
    for fld in _DECIDED_FIELDS:
        decision = decide(
            fld,
            current=None if _blank(current.get(fld)) else str(current.get(fld)),
            state=state.get(fld),
            candidates=candidates[fld],
            reports=reports.get(fld, {}),
            fill_blank_only=fld in _FILL_BLANK,
        )
        out_reports += [{"field": fld, "source": s, "value": v} for s, v in decision.reports]
        for warning in decision.warnings:
            digest.warn.append(f"{code}: {warning}")
        if decision.change is not None:
            ch = decision.change
            entry: dict = {
                "field": fld,
                "value": ch.value,
                "expected": ch.expected,
                "source": ch.source,
            }
            if ch.evidence:
                entry["evidence"] = ch.evidence
            if ch.source == "letter":
                entry["parser_version"] = PARSER_VERSION
                if letter_sha:
                    entry["letter_sha256"] = letter_sha
            changes.append(entry)
            if fld == "num_entry_fee":
                changes.append(
                    {
                        "field": "txt_entry_fee_currency",
                        "value": "PLN",
                        "expected": event.get("txt_entry_fee_currency"),
                        "source": ch.source,
                    }
                )

    if created:
        changed = {c["field"] for c in changes}
        for fld in _CREATE_SEEDED:
            value = current.get(fld)
            if fld not in changed and not _blank(value):
                # A no-op compare-and-set that records the run owns the inserted value.
                changes.append(
                    {"field": fld, "value": str(value), "expected": str(value), "source": "listing"}
                )
    return changes, out_reports, checks


def run_calendar(
    ref: str,
    token: str,
    bot_token: str,
    chat_id: str,
    *,
    today: dt.date,
    query: Query,
    telegram: Telegram,
    fetch: Fetch,
    home_fetch: HomeFetch,
    letter_fetch: LetterFetch,
    read_letter_fn: ReadLetter,
    dry_run: bool = False,
) -> int:
    """One PZSz calendar run against CERT (R1-R7). Returns 0 (green, perhaps
    with warnings) or 1 if any event ended fatal. Raises only the one fatal that
    ends the run at the start: no active season (CERT unreachable raises from
    the query)."""
    digest = _Digest()

    # R1 — our list.
    season = _get_active_season(ref, token, query)
    if not season:
        raise RuntimeError("No active season on CERT — the PZSz calendar run cannot start")
    cert = query(
        ref,
        token,
        "SELECT e.id_event, e.txt_code, e.id_pzsz_event, e.dt_start::TEXT AS dt_start, "
        "e.dt_end::TEXT AS dt_end, e.txt_location, e.txt_venue_address, "
        "e.num_entry_fee::TEXT AS num_entry_fee, e.txt_entry_fee_currency, e.url_invitation, "
        "e.url_event, e.enum_status::TEXT AS enum_status "
        "FROM tbl_event e JOIN tbl_organizer o ON o.id_organizer = e.id_organizer "
        f"WHERE e.id_season = {int(season['id_season'])} AND o.txt_code = '{ORGANIZER_CODE}' "
        "AND e.id_pzsz_event IS NOT NULL ORDER BY e.dt_start, e.txt_code",
    )
    existing_ids = {int(r["id_pzsz_event"]) for r in cert}
    state = _load_field_state(ref, token, query, [int(r["id_event"]) for r in cert])
    source_reports = _load_source_reports(ref, token, query, [int(r["id_event"]) for r in cert])

    # R2 — discover.
    listing, _served = discover_listing(fetch, season, digest)
    fresh = _new_events(listing, existing_ids, season, today, digest)

    # R3 — the home page.
    home_by_id: dict[int, HomeRow] = {}
    try:
        for row in parse_home_page(home_fetch()):
            home_by_id[row.id_pzsz_event] = row
    except Exception as exc:  # noqa: BLE001 — the home page is a secondary source
        digest.warn.append(f"the home page could not be read ({exc})")

    if dry_run:
        digest.plain.append(
            f"[dry-run] {len(cert)} on CERT, {len(fresh)} to create, listing {len(listing)} events"
        )
        print(digest.message())
        return 0

    # create the fresh events first, so they are processed like the rest.
    created_ids: set[int] = set()
    for row in fresh:
        try:
            result = query(ref, token, build_insert_sql(row, season))
            new_id = int((result or [{}])[0]["id_event"])
            created_ids.add(new_id)
            cert.append(
                {
                    "id_event": new_id,
                    "txt_code": row["desired_code"],
                    "id_pzsz_event": int(row["id_pzsz_event"]),
                    "dt_start": row.get("dt_start"),
                    "dt_end": row.get("dt_end") or row.get("dt_start"),
                    "txt_location": row.get("location"),
                    "txt_venue_address": None,
                    "num_entry_fee": None,
                    "txt_entry_fee_currency": None,
                    "url_invitation": None,
                    "url_event": row.get("url_event"),
                    "enum_status": "PLANNED",
                }
            )
            digest.plain.append(
                f"created {row['desired_code']} ({row.get('location')}, {row.get('dt_start')})"
            )
        except Exception as exc:  # noqa: BLE001 — one create failing is fatal for it alone
            digest.fatal.append(f"{row['desired_code']}: could not be created ({exc})")

    # R4 — the per-event passes and the write.
    for event in cert:
        if not _is_future(event.get("dt_start"), today) or event.get("enum_status") in _TERMINAL:
            continue  # a started or terminal event: the run reads nothing for it (rule 7)
        rid = int(event["id_pzsz_event"])
        eid = int(event["id_event"])
        try:
            changes, reports, checks = _process_event(
                event,
                created=eid in created_ids,
                listing_row=listing.get(rid),
                home_row=home_by_id.get(rid),
                state=state.get(eid, {}),
                reports=source_reports.get(eid, {}),
                season=season,
                letter_fetch=letter_fetch,
                read_letter_fn=read_letter_fn,
                digest=digest,
            )
            if changes or reports or checks:
                result = _apply_event(ref, token, query, eid, changes, reports, checks)
                applied = result.get("applied") or []
                if applied:
                    digest.plain.append(f"{event['txt_code']}: wrote {', '.join(applied)}")
                for fld in result.get("hand_changed") or []:
                    digest.warn.append(
                        f"{event['txt_code']}: {fld} changed by hand meanwhile — not overwritten"
                    )
        except Exception as exc:  # noqa: BLE001 — a write rejected is fatal for this event only
            digest.fatal.append(f"{event['txt_code']}: the write to CERT was rejected ({exc})")

    # R5 — the "send ingest" notice.
    _ingest_notice(ref, token, query, season, today, digest)

    # R6 — one digest.
    if digest.plain or digest.warn or digest.fatal:
        telegram(bot_token, chat_id, digest.message())
    print(digest.message())

    # R7 — exit status, set last.
    return 1 if digest.is_red() else 0


def _load_field_state(
    ref: str, token: str, query: Query, event_ids: list[int]
) -> dict[int, dict[str, FieldState]]:
    if not event_ids:
        return {}
    ids = ",".join(str(i) for i in sorted(set(event_ids)))
    rows = query(
        ref,
        token,
        f"SELECT id_event, txt_field, txt_value, txt_source FROM tbl_pzsz_field_state "
        f"WHERE id_event IN ({ids})",
    )
    out: dict[int, dict[str, FieldState]] = {}
    for r in rows or []:
        out.setdefault(int(r["id_event"]), {})[str(r["txt_field"])] = FieldState(
            str(r["txt_value"]), str(r["txt_source"])
        )
    return out


def _load_source_reports(
    ref: str, token: str, query: Query, event_ids: list[int]
) -> dict[int, dict[str, dict[str, str]]]:
    if not event_ids:
        return {}
    ids = ",".join(str(i) for i in sorted(set(event_ids)))
    rows = query(
        ref,
        token,
        f"SELECT id_event, txt_field, txt_source, txt_value FROM tbl_pzsz_source_report "
        f"WHERE id_event IN ({ids})",
    )
    out: dict[int, dict[str, dict[str, str]]] = {}
    for r in rows or []:
        out.setdefault(int(r["id_event"]), {}).setdefault(str(r["txt_field"]), {})[
            str(r["txt_source"])
        ] = str(r["txt_value"])
    return out


def _ingest_notice(
    ref: str, token: str, query: Query, season: dict, today: dt.date, digest: _Digest
) -> None:
    """R5 (ADR-112 §5, corrected): a CERT-only check — a past PZSz event whose
    url_event is now the FencingTimeLive link (no longer the pzszerm.pl page),
    that has a stored start list and no FINISHED CERT run, is ready to ingest.
    Told once (tbl_pzsz_check keyed on the event). With no stored list it says
    the ingest will stop instead. pzszerm.pl is never touched here."""
    rows = query(
        ref,
        token,
        "SELECT e.txt_code, e.id_pzsz_event, e.dt_end::TEXT AS dt_end, e.dt_start::TEXT AS dt_start, "
        "e.url_event, "
        "EXISTS (SELECT 1 FROM tbl_pzsz_start_list l WHERE l.id_pzsz_event = e.id_pzsz_event) AS has_list, "
        "EXISTS (SELECT 1 FROM tbl_ingest_run r WHERE r.txt_event_code = e.txt_code "
        "AND r.txt_environment = 'cert' AND r.txt_status = 'FINISHED') AS has_cert_run, "
        "(SELECT c.txt_state FROM tbl_pzsz_check c WHERE c.txt_scope = e.txt_code "
        "AND c.txt_check = 'ingest_notice') AS notice_state "
        "FROM tbl_event e JOIN tbl_organizer o ON o.id_organizer = e.id_organizer "
        f"WHERE e.id_season = {int(season['id_season'])} AND o.txt_code = '{ORGANIZER_CODE}' "
        "AND e.id_pzsz_event IS NOT NULL",
    )
    for r in rows or []:
        end = r.get("dt_end") or r.get("dt_start")
        if _blank(end) or dt.date.fromisoformat(str(end)[:10]) >= today:
            continue  # not past yet
        url = str(r.get("url_event") or "")
        if not url or "pzszerm.pl" in url:
            continue  # still the pzszerm.pl page — the operator has not added the FTL link
        if r.get("has_cert_run"):
            continue  # already ingested
        state = "ready" if r.get("has_list") else "no_list"
        if r.get("notice_state") == state:
            continue  # already told
        if r.get("has_list"):
            digest.plain.append(f"📋 Send ingest {r['txt_code']}")
        else:
            digest.fatal.append(
                f"{r['txt_code']}: no stored start list and the window is closed — the ingest will stop (ADR-111)"
            )
        _apply_event(
            ref,
            token,
            query,
            0,
            [],
            [],
            [
                {
                    "scope": str(r["txt_code"]),
                    "check": "ingest_notice",
                    "state": state,
                    "detail": url,
                }
            ],
        )


def _letter_fetch(url: str) -> bytes | None:
    """Download a letter PDF (never gated): three tries, 5 s then 20 s apart; a
    404 is final. None when it cannot be read."""
    import time

    import httpx

    delays = [5.0, 20.0]
    with httpx.Client(timeout=30.0, follow_redirects=True) as http:
        for attempt in range(3):
            try:
                resp = http.get(url)
                if resp.status_code == 404:
                    return None
                resp.raise_for_status()
                return resp.content
            except httpx.HTTPError:
                if attempt < len(delays):
                    time.sleep(delays[attempt])
    return None


def _home_fetch() -> str:
    import httpx

    with httpx.Client(timeout=30.0, follow_redirects=True) as http:
        resp = http.get("https://pzszerm.pl/")
        resp.raise_for_status()
        return resp.text


def main() -> None:
    parser = argparse.ArgumentParser(description="PZSz senior calendar run (ADR-116)")
    parser.add_argument("--dry-run", action="store_true", help="plan without writing to CERT")
    args = parser.parse_args()

    ref = os.environ.get("SUPABASE_CERT_REF", "")
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "")
    if not ref or not token:
        print("ERROR: SUPABASE_CERT_REF and SUPABASE_ACCESS_TOKEN required", file=sys.stderr)
        raise SystemExit(2)

    from python.scrapers.pzsz_browser import browser_fetch

    try:
        with browser_fetch() as fetch:
            code = run_calendar(
                ref,
                token,
                bot_token,
                chat_id,
                today=warsaw_today(),
                query=_management_query,
                telegram=_telegram,
                fetch=fetch,
                home_fetch=_home_fetch,
                letter_fetch=_letter_fetch,
                read_letter_fn=read_letter,
                dry_run=args.dry_run,
            )
    except Exception as exc:
        print(f"ERROR: PZSz calendar run failed: {exc}", file=sys.stderr)
        _telegram(bot_token, chat_id, f"❌ <b>PZSz Calendar</b> failed to run\n{exc}")
        raise SystemExit(1) from exc
    raise SystemExit(code)


if __name__ == "__main__":
    main()
