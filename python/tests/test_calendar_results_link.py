"""Calendar automation never writes an event's results link (URL wyników).

`tbl_event.url_event` … `url_event_5` stay empty until an administrator fills
them in the Admin UI. The calendar scrapers (EVF, PZSz) and the CERT→PROD
calendar mirror write the organizer's letter to `url_invitation` (URL
komunikatu) and nothing to the results slots, before or after the event.

Plan test IDs (doc/plans/pzsz-results-url-rca-2026-10-25.html):
  CALURL.01  EVF create/reuse payload (fn_ingest_evf_calendar) has no results slot,
             even for an event that has ended.
  CALURL.02  EVF refresh payload (fn_refresh_evf_event_urls) has no results slot.
  CALURL.03  EVF date heal rewrites the dates only, never url_event.
  CALURL.04  PZSz create (build_insert_sql) writes no url_event.
  CALURL.05  PZSz "Send ingest" notice fires once an administrator has set
             url_event, whatever its host.
  CALURL.06  Calendar mirror CREATE payload carries no results slot.
  CALURL.07  Calendar mirror UPDATE payload carries no results slot.
"""

from __future__ import annotations

import datetime as dt
import json
import re
from datetime import date, timedelta
from functools import partial
from unittest.mock import patch

import python.scrapers.evf_sync as evf_sync
from python.scrapers import pzsz_sync

RESULT_SLOTS = ("url_event", "url_event_2", "url_event_3", "url_event_4", "url_event_5")
EVF_PAGE = "https://www.veteransfencing.eu/event/evf-circuit-samorin-svk/"


def _json_arg(sql: str) -> list[dict]:
    """The JSONB array literal an RPC call was given."""
    start = sql.find("'[")
    end = sql.find("]'", start)
    return json.loads(sql[start + 1 : end + 1].replace("''", "'"))


def _evf_sync_calls(monkeypatch) -> list[str]:
    """One EVF calendar run over an event that ended eight days earlier and
    is already on CERT; returns every SQL statement sent."""
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
            "evf_slug": "evf-circuit-samorin-svk",
            "evf_calendar_id": 5074,
            "fee": None,
            "fee_currency": "",
        }
    ]
    calls: list[str] = []

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
    monkeypatch.setattr(evf_sync, "_telegram", lambda *a: None)
    monkeypatch.setattr(evf_sync, "scrape_full_season_calendar", lambda *a, **k: scraped)
    evf_sync.sync_calendar("ref", "token", "bot", "chat", dry_run=False)
    return calls


class TestEvfCalendar:
    def test_create_payload_has_no_results_slot(self, monkeypatch):
        """CALURL.01: the event has ended and its EVF page is known, yet the
        fn_ingest_evf_calendar payload carries no results slot; the letter
        still goes to url_invitation."""
        calls = _evf_sync_calls(monkeypatch)
        ingest = next(s for s in calls if "fn_ingest_evf_calendar" in s.lower())
        (evt,) = _json_arg(ingest)
        assert not set(RESULT_SLOTS) & set(evt), f"results slot in payload: {evt}"
        assert evt["url_invitation"].endswith("samorin.pdf")

    def test_refresh_payload_has_no_results_slot(self, monkeypatch):
        """CALURL.02: the fn_refresh_evf_event_urls payload carries no results
        slot; the letter goes to url_invitation through the shared calendar
        write (ADR-118), never to a results slot."""
        calls = _evf_sync_calls(monkeypatch)
        refresh = next(s for s in calls if "fn_refresh_evf_event_urls" in s.lower())
        (evt,) = _json_arg(refresh)
        assert not set(RESULT_SLOTS) & set(evt), f"results slot in payload: {evt}"
        write = next(s for s in calls if "fn_calendar_apply_fields" in s.lower())
        (detail,) = _json_arg(write)
        assert not set(RESULT_SLOTS) & set(detail["fields"]), detail
        assert detail["fields"]["url_invitation"].endswith("samorin.pdf")


class _DummyClient:
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class TestEvfDateHeal:
    def test_heal_rewrites_dates_only(self):
        """CALURL.03: a future-COMPLETED row whose EVF calendar page is matched
        and whose date comes from its FTL tournament links gets its dates
        rewritten; url_event is not written."""
        future = (date.today() + timedelta(days=30)).isoformat()
        violator = {
            "id_event": 82,
            "txt_code": "PEW63e-2026-2027",
            "dt_start": future,
            "dt_end": future,
            "enum_status": "COMPLETED",
            "txt_country": None,
            "txt_location": None,
            "url_event": None,
        }
        sql_log: list[str] = []

        def fake_query(_ref, _token, sql):
            sql_log.append(sql)
            if "FROM tbl_tournament" in sql:
                return [{"url_results": "https://www.fencingtimelive.com/events/results/ABC"}]
            return []

        with (
            patch.object(evf_sync, "_management_query", side_effect=fake_query),
            patch.object(evf_sync, "_scraped_event_url", return_value=EVF_PAGE),
            patch.object(evf_sync, "get_authed_ftl_client", return_value=_DummyClient()),
            patch.object(evf_sync, "fetch_ftl_event_metadata", return_value={"date": "2026-01-10"}),
            patch.object(evf_sync, "_telegram"),
        ):
            evf_sync._heal_future_completed(
                "ref", "tok", [violator], [{}], "bot", "chat", dry_run=False
            )
        updates = [s for s in sql_log if s.startswith("UPDATE tbl_event SET dt_start")]
        assert updates, f"expected a date UPDATE; got {sql_log}"
        assert all("url_event" not in s for s in updates), updates


class TestPzszCalendar:
    def test_create_writes_no_results_link(self):
        """CALURL.04: a PZSz event is created with no url_event."""
        sql = pzsz_sync.build_insert_sql(
            {
                "desired_code": "PPS3f-2026-2027",
                "name": "III PGE Puchar Polski seniorów we florecie",
                "id_pzsz_event": 4600,
                "location": "Gdańsk",
                "dt_start": "2027-01-16",
                "dt_end": "2027-01-17",
                "weapons": ["FOIL"],
                "url_event": "https://pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=4600",
            },
            {"id_season": 4},
        )
        assert "url_event" not in sql
        assert "pzszerm.pl/zawody" not in sql

    def test_ingest_notice_follows_the_admin_results_link(self):
        """CALURL.05: once an administrator has set url_event on a past PZSz
        event with a stored start list and no CERT run, the digest names the
        ingest command, whatever the link's host; with no link it stays silent."""
        today = dt.date(2026, 10, 26)

        def rows(url):
            return [
                {
                    "txt_code": "PPS1f-2026-2027",
                    "id_pzsz_event": 4581,
                    "dt_end": "2026-10-25",
                    "dt_start": "2026-10-24",
                    "url_event": url,
                    "has_list": True,
                    "has_cert_run": False,
                    "notice_state": None,
                }
            ]

        for url, told in (
            (None, False),
            ("https://pzszerm.pl/test/fileDownload.php?fileId=wyniki", True),
            ("https://www.fencingtimelive.com/tournaments/eventSchedule/B547", True),
        ):
            digest = pzsz_sync._Digest()

            def query(_ref, _token, sql, _url=url):
                return rows(_url) if "FROM tbl_event e" in sql else []

            pzsz_sync._ingest_notice("ref", "tok", query, {"id_season": 4}, today, digest)
            assert ("📋 Send ingest PPS1f-2026-2027" in digest.plain) is told, (url, digest.plain)


class TestNoticeReadsProd:
    def test_the_ingest_notice_reads_the_link_set_in_prods_admin(self):
        """CALURL.21 (D2 A): CERT holds no results link, PROD's Admin holds
        one: the digest names the ingest command, which the refresh then
        carries to CERT. Without a PROD reference only CERT is read."""
        today = dt.date(2026, 10, 26)
        cert_rows = [
            {
                "txt_code": "PPS1f-2026-2027",
                "id_pzsz_event": 4581,
                "dt_end": "2026-10-25",
                "dt_start": "2026-10-24",
                "url_event": None,
                "has_list": True,
                "has_cert_run": False,
                "notice_state": None,
            }
        ]
        prod_rows = [
            {
                "txt_code": "PPS1f-2026-2027",
                "url_event": "https://www.fencingtimelive.com/tournaments/eventSchedule/B547",
            }
        ]
        seen: list[str] = []

        def query(ref, _token, sql):
            seen.append(ref)
            if ref == "prod-ref":
                assert "PPS1f-2026-2027" in sql
                return prod_rows
            return cert_rows if "FROM tbl_event e" in sql else []

        digest = pzsz_sync._Digest()
        pzsz_sync._ingest_notice(
            "cert-ref", "tok", query, {"id_season": 4}, today, digest, prod_ref="prod-ref"
        )
        assert "📋 Send ingest PPS1f-2026-2027" in digest.plain
        assert "prod-ref" in seen

        digest = pzsz_sync._Digest()
        seen.clear()
        pzsz_sync._ingest_notice("cert-ref", "tok", query, {"id_season": 4}, today, digest)
        assert digest.plain == [] and "prod-ref" not in seen


def _cert_row(**kw) -> dict:
    row = {
        "txt_code": "PEW3ef-2026-2027",
        "txt_name": "EVF Circuit Budapest",
        "enum_status": "PLANNED",
        "dt_start": "2026-11-14",
        "dt_end": "2026-11-15",
        "txt_location": "Budapest",
        "txt_country": "HUN",
        "txt_venue_address": None,
        "url_event": "https://www.veteransfencing.eu/event/evf-circuit-budapest/",
        "url_event_2": "https://e/p2",
        "url_event_3": None,
        "url_event_4": None,
        "url_event_5": None,
        "url_invitation": "https://www.veteransfencing.eu/wp-content/uploads/budapest.pdf",
        "url_registration": None,
        "dt_registration_deadline": None,
        "num_entry_fee": 45.0,
        "txt_entry_fee_currency": "EUR",
        "weapons": ["EPEE", "FOIL"],
        "id_evf_event": None,
        "txt_evf_slug": None,
        "organizer_code": "EVF",
        "prior_code": None,
    }
    row.update(kw)
    return row


def _mirror_payload(prod_events: list[dict]) -> dict:
    """The fn_mirror_events_to_prod call's create and update arrays."""
    from python.pipeline.promote import promote_calendar

    calls: list[str] = []

    def season(id_season: int) -> dict:
        return {
            "txt_code": "SPWS-2026-2027",
            "dt_start": "2026-07-13",
            "dt_end": "2027-07-15",
            "id_season": id_season,
        }

    def cert_query(sql: str):
        if "s.bool_active" in sql:
            return [season(3)]
        return [_cert_row()]

    def prod_query(sql: str):
        calls.append(sql)
        if "s.bool_active" in sql:
            return [season(5)]
        if "FROM tbl_event WHERE id_season" in sql:
            return prod_events
        if "FROM tbl_organizer WHERE txt_code IN" in sql:
            return [{"txt_code": "EVF", "id": 7}]
        if "FROM tbl_event WHERE txt_code IN" in sql:
            return []
        return [{"r": {"created": 0, "updated": 0, "deleted": 0, "delete_skipped": []}}]

    promote_calendar(cert_query_fn=cert_query, prod_query_fn=prod_query, dry_run=False)
    (rpc,) = [s for s in calls if "fn_mirror_events_to_prod" in s]
    arrays = [
        json.loads(a.replace("''", "'")) for a in re.findall(r"'(\[.*?\])'::JSONB", rpc, re.S)
    ]
    return {"creates": arrays[0], "updates": arrays[1]}


class TestCalendarMirror:
    def test_create_carries_no_results_slot(self):
        """CALURL.06: an event new to PROD is created with no results slot;
        its letter is carried."""
        payload = _mirror_payload(prod_events=[])
        (evt,) = payload["creates"]
        assert not set(RESULT_SLOTS) & set(evt), f"results slot in CREATE: {evt}"
        assert evt["url_invitation"].endswith("budapest.pdf")

    def test_update_carries_no_results_slot(self):
        """CALURL.07: an event PROD already holds is updated with no results
        slot; its letter is carried."""
        payload = _mirror_payload(prod_events=[{"id_event": 99, "txt_code": "PEW3ef-2026-2027"}])
        (evt,) = payload["updates"]
        assert not set(RESULT_SLOTS) & set(evt), f"results slot in UPDATE: {evt}"
        assert evt["url_invitation"].endswith("budapest.pdf")
