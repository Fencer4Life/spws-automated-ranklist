"""The one way a calendar scraper writes an event's details on CERT (ADR-118).

An event's details are nine fields, eleven columns: name, start and end date,
city, country, weapons, venue address, the invitation letter, the organizer's
registration link, and the entry fee with its currency. Every calendar scraper
(EVF, PZSz, and any added later) writes them under one contract:

  1. an empty field takes the source's value; an event page in the letter
     counts as empty (ADR-117 D7 A);
  2. a source that changed replaces the scraper's own earlier value;
  3. a value a person set is kept, and the source's different value is
     reported once;
  4. a blank from the source clears nothing;
  5. our own register.html link is never written by a scraper.

The SQL function ``fn_calendar_apply_fields`` applies it and records, per event
and field, the value the scraper last wrote (``tbl_calendar_field_state``). EVF
and new scrapers send their source's values through :func:`apply_fields`; PZSz
keeps its own provenance (ADR-116) and the same rules. The CERT→PROD mirror then
carries any newer CERT write to PROD (``fn_mirror_events_to_prod``).
"""

from __future__ import annotations

import json
from collections.abc import Callable, Mapping

from python.pipeline.calendar_details import DETAIL_FIELDS as DETAIL_FIELDS
from python.pipeline.calendar_details import is_calendar_page as is_calendar_page
from python.pipeline.calendar_details import (
    is_our_registration_link as is_our_registration_link,
)

# What a run of the write returns: every field written, and every value held
# for a person (reported once).
Result = dict[str, list[dict]]


def _text(value: object) -> str | None:
    """A source value as text; blank is None (rule 4 clears nothing)."""
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def evf_fields(scraped: Mapping[str, object]) -> dict[str, str | None]:
    """An EVF calendar event's details as tbl_event columns.

    The weapons are left out: EVF writes them with the event code, whose
    letters state the same fact (ADR-089), so the code plan keeps them.
    """
    registration = _text(scraped.get("url_registration"))
    if is_our_registration_link(registration):
        registration = None
    return {
        "txt_name": _text(scraped.get("name")),
        "dt_start": _text(scraped.get("dt_start")),
        "dt_end": _text(scraped.get("dt_end") or scraped.get("dt_start")),
        "txt_location": _text(scraped.get("location")),
        "txt_country": _text(scraped.get("country")),
        "txt_venue_address": _text(scraped.get("address")),
        "url_invitation": _text(scraped.get("url_invitation")),
        "url_registration": registration,
        "num_entry_fee": _text(scraped.get("fee")),
        "txt_entry_fee_currency": _text(scraped.get("fee_currency")),
    }


def apply_fields(query: Callable[[str], list[dict]], scraper: str, events: list[dict]) -> Result:
    """Write ``events`` (each ``{"id_event": int, "fields": {column: value}}``)
    under the contract, as ``scraper``; returns what was written and held."""
    if not events:
        return {"written": [], "held": []}
    payload = json.dumps(events, ensure_ascii=False).replace("'", "''")
    tag = scraper.replace("'", "''")
    rows = query(f"SELECT fn_calendar_apply_fields('{tag}', '{payload}'::JSONB) AS r")
    result = rows[0].get("r") if rows else None
    if isinstance(result, str):
        result = json.loads(result)
    result = result or {}
    return {"written": list(result.get("written") or []), "held": list(result.get("held") or [])}


def held_lines(result: Result) -> list[str]:
    """One line per value held for a person, for the run's Telegram report."""
    return [
        f"{h.get('txt_code')} · {h.get('field')}: kept {h.get('current')!r}; "
        f"the source now says {h.get('source')!r}"
        for h in result.get("held", [])
    ]
