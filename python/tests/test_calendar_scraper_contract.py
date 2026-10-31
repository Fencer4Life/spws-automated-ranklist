"""Every calendar scraper writes an event's details on CERT under one contract,
and the mirror carries a newer CERT write to PROD (ADR-118).

The nine details: name, dates, city, country, weapons, venue address, the
invitation letter, the organizer's registration link, and the entry fee with
its currency. On CERT, for every scraper (EVF, PZSz, and the ones still to
come):

  1. an empty field takes the source's value — an event page in the letter
     counts as empty (C1, ADR-117 D7 A);
  2. a source that changed replaces the scraper's own value;
  3. a person's value is kept and the source's different value reported once;
  4. a blank from the source clears nothing;
  5. our own register.html link is never written by a scraper.

EVF and new scrapers write through the shared ``fn_calendar_apply_fields``
(``python/scrapers/calendar_write.py``); PZSz keeps its own provenance and
loses rule 8. The SQL side is pgTAP 117 (the mirror) and 118 (the contract).

Plan test IDs (doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html):
  CALSYNC.40  our register.html link and an event page are recognised.
  CALSYNC.41  an EVF event's details map to the nine columns; blanks are
              None; our own link and the weapons (C2) are not sent.
  CALSYNC.42  the EVF run writes the details through fn_calendar_apply_fields.
  CALSYNC.43  the EVF refresh and identity sync no longer carry the details.
  CALSYNC.44  a held value is reported on Telegram.
  CALSYNC.45  PZSz without rule 8: a link the run wrote follows the listing's
              new link, and the passes read the new letter.
  CALSYNC.46  PZSz: a link a person set stays, and the passes read it.
  CALSYNC.47  PZSz: an event page in the letter counts as empty (C1).
  CALSYNC.48  PZSz without rule 8: a fee the run wrote follows the letter.
  CALSYNC.49  PZSz: a fee with no provenance is a person's and stays.
  CALSYNC.50  promote reads when CERT's details were last written and sends it.
"""

from __future__ import annotations

import json
from datetime import date
from functools import partial

import python.scrapers.evf_sync as evf_sync
from python.scrapers import calendar_write, pzsz_sync
from python.scrapers.pzsz_letter import Found, LetterResult
from python.scrapers.pzsz_write_rules import FieldState

OUR_LINK = (
    "https://fencer4life.github.io/spws-automated-ranklist/register.html?event=PEW5efs-2026-2027"
)
EVF_PAGE = "https://www.veteransfencing.eu/event/evf-circuit-samorin-svk/"
PZSZ_PAGE = "https://pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=4581"
HELD_LINK = "https://pzszerm.pl/test/fileDownload.php?fileId=held"
NEW_LINK = "https://pzszerm.pl/test/fileDownload.php?fileId=new"


def _json_arg(sql: str) -> list[dict]:
    """The JSONB array literal an RPC call was given."""
    start = sql.find("'[")
    end = sql.rfind("]'")
    return json.loads(sql[start + 1 : end + 1].replace("''", "'"))


class TestSharedHelper:
    def test_our_link_and_event_pages_are_recognised(self):
        """CALSYNC.40"""
        assert calendar_write.is_our_registration_link(OUR_LINK)
        assert not calendar_write.is_our_registration_link("https://aevesgrima.es/evento/madrid")
        assert not calendar_write.is_our_registration_link(None)
        assert calendar_write.is_calendar_page(EVF_PAGE)
        assert calendar_write.is_calendar_page(PZSZ_PAGE)
        assert not calendar_write.is_calendar_page(
            "https://www.veteransfencing.eu/wp-content/uploads/2026/10/Madrid.pdf"
        )
        assert not calendar_write.is_calendar_page(None)

    def test_evf_details_map_to_the_nine_columns(self):
        """CALSYNC.41"""
        fields = calendar_write.evf_fields(
            {
                "name": "EVF Circuit – Madrid (ESP)",
                "dt_start": "2026-10-31",
                "dt_end": "2026-11-01",
                "location": "Madrid",
                "country": "",
                "address": "Calle 1, Madrid",
                "url_invitation": "https://www.veteransfencing.eu/wp-content/uploads/m.pdf",
                "url_registration": OUR_LINK,
                "fee": 60,
                "fee_currency": "EUR",
                "weapons": ["EPEE", "FOIL"],
            }
        )
        assert fields == {
            "txt_name": "EVF Circuit – Madrid (ESP)",
            "dt_start": "2026-10-31",
            "dt_end": "2026-11-01",
            "txt_location": "Madrid",
            "txt_country": None,
            "txt_venue_address": "Calle 1, Madrid",
            "url_invitation": "https://www.veteransfencing.eu/wp-content/uploads/m.pdf",
            "url_registration": None,
            "num_entry_fee": "60",
            "txt_entry_fee_currency": "EUR",
        }


def _evf_run(monkeypatch, held: list[dict] | None = None) -> tuple[list[str], list[str]]:
    """One EVF calendar run over an event already on CERT; returns every SQL
    statement sent and every Telegram message."""
    from python.scrapers.evf_calendar import is_in_scope

    monkeypatch.setattr(evf_sync, "is_in_scope", partial(is_in_scope, today=date(2026, 9, 20)))
    scraped = [
        {
            "name": "EVF Circuit – Samorin (SVK)",
            "dt_start": "2026-09-12",
            "dt_end": "2026-09-12",
            "location": "Samorin",
            "country": "Slovakia",
            "weapons": ["EPEE"],
            "is_team": False,
            "url": EVF_PAGE,
            "url_invitation": "https://www.veteransfencing.eu/wp-content/uploads/samorin.pdf",
            "url_registration": "https://organizer.example.org/samorin",
            "address": "Hala 1, Samorin",
            "evf_slug": "evf-circuit-samorin-svk",
            "evf_calendar_id": 5074,
            "fee": 50,
            "fee_currency": "EUR",
        }
    ]
    calls: list[str] = []
    sent: list[str] = []

    def fake_mgmt(_ref, _token, sql):
        calls.append(sql)
        sl = sql.lower()
        if "from tbl_season s where s.bool_active" in sl:
            return [
                {
                    "txt_code": "SPWS-2026-2027",
                    "dt_start": "2026-07-13",
                    "dt_end": "2027-07-15",
                    "id_season": 4,
                }
            ]
        if "fn_sync_evf_event_fields" in sl:
            return [{"r": json.dumps({"touched": 1, "changed": 0})}]
        if "fn_refresh_evf_event_urls" in sl:
            return [{"r": json.dumps({"touched": 1, "refreshed": 0})}]
        if "fn_calendar_apply_fields" in sl:
            return [{"r": json.dumps({"written": [], "held": held or []})}]
        if "from tbl_event" in sl:
            return [
                {
                    "id_event": 111,
                    "txt_code": "PEW0efs-2026-2027",
                    "txt_name": "EVF Circuit – Samorin (SVK)",
                    "dt_start": "2026-09-12",
                    "dt_end": "2026-09-12",
                    "txt_country": None,
                    "txt_location": None,
                    "enum_status": "PLANNED",
                    "url_event": None,
                    "id_evf_event": None,
                    "txt_evf_slug": "evf-circuit-samorin-svk",
                    "id_evf_calendar_event": 5074,
                }
            ]
        return []

    monkeypatch.setattr(evf_sync, "_management_query", fake_mgmt)
    monkeypatch.setattr(evf_sync, "_telegram", lambda _b, _c, text: sent.append(text))
    monkeypatch.setattr(evf_sync, "scrape_full_season_calendar", lambda *a, **k: scraped)
    evf_sync.sync_calendar("ref", "token", "bot", "chat", dry_run=False)
    return calls, sent


class TestEvfRun:
    def test_details_go_through_the_shared_write(self, monkeypatch):
        """CALSYNC.42"""
        calls, _sent = _evf_run(monkeypatch)
        (write,) = [s for s in calls if "fn_calendar_apply_fields" in s]
        assert "fn_calendar_apply_fields('EVF'," in write
        (evt,) = _json_arg(write)
        assert evt["id_event"] == 111
        assert evt["fields"] == {
            "txt_name": "EVF Circuit – Samorin (SVK)",
            "dt_start": "2026-09-12",
            "dt_end": "2026-09-12",
            "txt_location": "Samorin",
            "txt_country": "Slovakia",
            "txt_venue_address": "Hala 1, Samorin",
            "url_invitation": "https://www.veteransfencing.eu/wp-content/uploads/samorin.pdf",
            "url_registration": "https://organizer.example.org/samorin",
            "num_entry_fee": "50",
            "txt_entry_fee_currency": "EUR",
        }

    def test_refresh_and_identity_sync_no_longer_carry_the_details(self, monkeypatch):
        """CALSYNC.43"""
        calls, _sent = _evf_run(monkeypatch)
        (refresh,) = [s for s in calls if "fn_refresh_evf_event_urls" in s]
        (evt,) = _json_arg(refresh)
        assert set(evt) == {"id_event", "dt_registration_deadline", "weapons"}
        (identity,) = [s for s in calls if "fn_sync_evf_event_fields" in s]
        (ident,) = _json_arg(identity)
        assert not {"name", "dt_start", "dt_end", "location", "country"} & set(ident)

    def test_a_held_value_is_reported(self, monkeypatch):
        """CALSYNC.44"""
        held = [
            {
                "id_event": 111,
                "txt_code": "PEW0efs-2026-2027",
                "field": "txt_venue_address",
                "current": "Typed by hand",
                "source": "Hala 1, Samorin",
            }
        ]
        _calls, sent = _evf_run(monkeypatch, held=held)
        (msg,) = [m for m in sent if "PEW0efs-2026-2027" in m and "txt_venue_address" in m]
        assert "Typed by hand" in msg and "Hala 1, Samorin" in msg


class TestPzszWithoutRule8:
    def _run(self, event, *, state=None, listing_row=None, letter=None):
        fetched: list[str] = []

        def letter_fetch(url):
            fetched.append(url)
            return b"PDF"

        def read_letter_fn(_data, _ctx):
            return letter or LetterResult(has_text=True)

        digest = pzsz_sync._Digest()
        changes, _reports, _checks = pzsz_sync._process_event(
            event,
            created=False,
            listing_row=listing_row,
            home_row=None,
            state=state or {},
            reports={},
            season={"dt_start": "2026-09-01", "dt_end": "2027-08-31"},
            letter_fetch=letter_fetch,
            read_letter_fn=read_letter_fn,
            digest=digest,
        )
        return {c["field"]: c["value"] for c in changes}, fetched, digest

    @staticmethod
    def _event(**kw) -> dict:
        base = {
            "id_event": 1,
            "txt_code": "PPS2e-2026-2027",
            "dt_start": "2026-11-21",
            "dt_end": "2026-11-21",
            "txt_location": "Gdańsk",
            "txt_venue_address": None,
            "num_entry_fee": None,
            "txt_entry_fee_currency": None,
            "url_invitation": None,
        }
        base.update(kw)
        return base

    def test_a_run_written_link_follows_the_listing(self):
        """CALSYNC.45"""
        changes, fetched, _d = self._run(
            self._event(url_invitation=HELD_LINK),
            state={"url_invitation": FieldState(HELD_LINK, "listing")},
            listing_row={"letter_url": NEW_LINK},
        )
        assert changes.get("url_invitation") == NEW_LINK
        assert fetched == [NEW_LINK]

    def test_a_person_set_link_stays(self):
        """CALSYNC.46"""
        changes, fetched, digest = self._run(
            self._event(url_invitation=HELD_LINK),
            listing_row={"letter_url": NEW_LINK},
        )
        assert "url_invitation" not in changes
        assert fetched == [HELD_LINK]
        assert any("hand" in w for w in digest.warn)

    def test_an_event_page_in_the_letter_counts_as_empty(self):
        """CALSYNC.47"""
        changes, fetched, _d = self._run(
            self._event(url_invitation=PZSZ_PAGE),
            listing_row={"letter_url": NEW_LINK},
        )
        assert changes.get("url_invitation") == NEW_LINK
        assert fetched == [NEW_LINK]

    def test_a_run_written_fee_follows_the_letter(self):
        """CALSYNC.48"""
        changes, _f, _d = self._run(
            self._event(
                url_invitation=HELD_LINK, num_entry_fee="100", txt_entry_fee_currency="PLN"
            ),
            state={
                "url_invitation": FieldState(HELD_LINK, "listing"),
                "num_entry_fee": FieldState("100", "letter"),
            },
            letter=LetterResult(has_text=True, fee=Found("120", "120 zł")),
        )
        assert changes.get("num_entry_fee") == "120"

    def test_a_fee_with_no_provenance_stays(self):
        """CALSYNC.49"""
        changes, _f, digest = self._run(
            self._event(
                url_invitation=HELD_LINK, num_entry_fee="100", txt_entry_fee_currency="PLN"
            ),
            state={"url_invitation": FieldState(HELD_LINK, "listing")},
            letter=LetterResult(has_text=True, fee=Found("120", "120 zł")),
        )
        assert "num_entry_fee" not in changes
        assert any("num_entry_fee" in w and "hand" in w for w in digest.warn)


class TestPromoteCarriesTheTime:
    def test_cert_read_and_update_payload_carry_details_set(self):
        """CALSYNC.50"""
        from python.pipeline.promote import _build_update_payload, _read_cert_promotable_events

        seen: list[str] = []

        def fake_query(sql: str):
            seen.append(sql)
            return []

        _read_cert_promotable_events(fake_query, 7)
        assert "AS ts_details_set" in seen[0]
        assert "tbl_audit_log" in seen[0]
        for field in calendar_write.DETAIL_FIELDS:
            assert f"'{field}'" in seen[0], field
        evt = {"txt_code": "PEW2efs-2026-2027", "ts_details_set": "2026-10-02 12:09:00+00"}
        assert _build_update_payload(99, evt, 3)["ts_details_set"] == "2026-10-02 12:09:00+00"
        assert _build_update_payload(99, {"txt_code": "X"}, 3)["ts_details_set"] == ""
