"""An event's details, as the calendar contract names them (ADR-118).

Nine fields, eleven tbl_event columns: name, start and end date, city,
country, weapons, venue address, the invitation letter, the organizer's
registration link, and the entry fee with its currency. The calendar scrapers
write them on CERT under one contract (``python/scrapers/calendar_write.py``,
``fn_calendar_apply_fields``) and the CERT→PROD mirror carries a newer CERT
write to PROD (``python/pipeline/promote.py``, ``fn_mirror_events_to_prod``).

It lives here, imported by both, because importing anything under
``python.scrapers`` loads every parser and its third-party dependencies, which
the mirror's workflow does not install (WFDEPS.01). Pure: no I/O.
"""

from __future__ import annotations

import re

# The nine details, as tbl_event columns, in the order Admin shows them.
DETAIL_FIELDS: tuple[str, ...] = (
    "txt_name",
    "dt_start",
    "dt_end",
    "txt_location",
    "txt_country",
    "arr_weapons",
    "txt_venue_address",
    "url_invitation",
    "url_registration",
    "num_entry_fee",
    "txt_entry_fee_currency",
)

# Admin writes our own registration link when the SPWS registration box is
# ticked (ADR-079 §7): register.html on the Pages host, keyed by the event code.
_OUR_LINK = re.compile(r"/register\.html\?event=", re.IGNORECASE)
# A calendar page, not a letter: a pzszerm.pl or veteransfencing.eu event page.
_CALENDAR_PAGE = re.compile(
    r"^https?://(www\.)?(pzszerm\.pl/zawody/kalendarium-zawodow/zawody/|veteransfencing\.eu/event/)",
    re.IGNORECASE,
)


def is_our_registration_link(url: str | None) -> bool:
    """True for the register.html link Admin writes for our own registration."""
    return bool(url) and bool(_OUR_LINK.search(str(url)))


def is_calendar_page(url: str | None) -> bool:
    """True for an EVF or pzszerm.pl event page, which is not a letter."""
    return bool(url) and bool(_CALENDAR_PAGE.match(str(url)))
