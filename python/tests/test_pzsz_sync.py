"""
Tests for the PZSz calendar sync CLI.

The scraper's parsing half is covered in test_pzsz_calendar.py. This file covers
the half that decides what to write: how a scraped row is matched against what
CERT already holds, which fields the source owns outright, which it may only
fill when blank, and which it must never write at all.

Plan test IDs pzsz.25-pzsz.34:
  pzsz.25  an unseen event is a create
  pzsz.26  a matched, unchanged event produces no write
  pzsz.27  a rescheduled event matches on the PZSz id even when its code changed
  pzsz.28  an existing row with no PZSz id is adopted by code
  pzsz.29  an event that vanished from the listing is surfaced, never deleted
  pzsz.30  an admin-entered invitation URL is never overwritten
  pzsz.31  a blank invitation URL is filled when the source supplies one
  pzsz.32  url_registration and dt_registration_deadline are never written
  pzsz.33  --dry-run issues no write whatsoever
  pzsz.34  a create carries the PZSz organizer, the source id and country PL
  pzsz.41-pzsz.43  the JavaScript check fails the run (plan §6 F1)
  pzsz.44-pzsz.48  the dates of an event that has started stay as they are (plan §7, Q6 A)
"""

import datetime as dt
from pathlib import Path
from unittest.mock import patch

import httpx
import pytest

import python.scrapers.pzsz_sync as pzsz_sync
from python.scrapers import pzsz_calendar
from python.scrapers.pzsz_start_list import PzszPageError

SEASON = {
    "txt_code": "SPWS-2026-2027",
    "dt_start": "2026-07-13",
    "dt_end": "2027-07-15",
    "id_season": 4,
}

# pzsz.25-pzsz.34 were written in September, before any PZSz event of the
# season had started, so every date still follows the source there.
BEFORE_THE_SEASON = dt.date(2026, 9, 1)


def _scraped(**overrides) -> dict:
    row = {
        "id_pzsz_event": 4588,
        "name": "I Puchar Polski seniorów w szabli kobiet i mężczyzn - Poznań 2026/2027",
        "url_event": "https://pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=4588",
        "age_category": "Seniorzy (S)",
        "weapons": ["SABRE"],
        "pzsz_season": "2026/2027",
        "dt_start": "2026-10-03",
        "dt_end": "2026-10-03",
        "location": "Poznań",
        "txt_country": "PL",
        "desired_code": "PPS1s-2026-2027",
    }
    row.update(overrides)
    return row


def _existing(**overrides) -> dict:
    row = {
        "id_event": 501,
        "txt_code": "PPS1s-2026-2027",
        "id_pzsz_event": 4588,
        "txt_name": "I Puchar Polski seniorów w szabli kobiet i mężczyzn - Poznań 2026/2027",
        "dt_start": "2026-10-03",
        "dt_end": "2026-10-03",
        "txt_location": "Poznań",
        "txt_country": "PL",
        "url_invitation": None,
        "txt_venue_address": None,
    }
    row.update(overrides)
    return row


class TestDiff:
    """pzsz.25-pzsz.29: matching a scraped row against CERT."""

    def test_an_unseen_event_is_a_create(self):
        """pzsz.25."""
        plan = pzsz_sync.diff_against_cert([_scraped()], [], today=BEFORE_THE_SEASON)

        assert [row["desired_code"] for row in plan.creates] == ["PPS1s-2026-2027"]
        assert plan.updates == []

    def test_an_unchanged_event_produces_no_write(self):
        """pzsz.26: the daily cron must be a no-op on a settled calendar."""
        plan = pzsz_sync.diff_against_cert([_scraped()], [_existing()], today=BEFORE_THE_SEASON)

        assert plan.creates == []
        assert plan.updates == []

    def test_a_reschedule_matches_on_the_source_id(self):
        """pzsz.27: PZSz names drift and one live row carries a typo, so identity
        is the id. Here the round moved from I to II, which changes the code --
        matched on the code alone this would read as 'delete one, create
        another' and lose the event's registrations with it."""
        scraped = _scraped(
            name="II Puchar Polski seniorów w szabli kobiet i mężczyzn - Poznań 2026/2027",
            desired_code="PPS2s-2026-2027",
            dt_start="2026-11-07",
            dt_end="2026-11-07",
        )
        plan = pzsz_sync.diff_against_cert([scraped], [_existing()], today=BEFORE_THE_SEASON)

        assert plan.creates == []
        assert len(plan.updates) == 1
        update = plan.updates[0]
        assert update["id_event"] == 501
        assert update["fields"]["txt_code"] == "PPS2s-2026-2027"
        assert update["fields"]["dt_start"] == "2026-11-07"

    def test_a_row_without_a_source_id_is_adopted_by_code(self):
        """pzsz.28: an event an admin entered by hand before the scraper existed
        is adopted rather than duplicated, and gains the source id."""
        plan = pzsz_sync.diff_against_cert(
            [_scraped()], [_existing(id_pzsz_event=None)], today=BEFORE_THE_SEASON
        )

        assert plan.creates == []
        assert len(plan.updates) == 1
        assert plan.updates[0]["fields"]["id_pzsz_event"] == 4588

    def test_a_vanished_event_is_surfaced_not_deleted(self):
        """pzsz.29: a row whose id we hold but which is gone from the listing is
        a cancellation or a re-key. Deleting it would take any registrations with
        it, so the scraper reports and leaves it for a human."""
        gone = _existing(id_event=777, txt_code="PPS3e-2026-2027", id_pzsz_event=4999)
        plan = pzsz_sync.diff_against_cert(
            [_scraped()], [_existing(), gone], today=BEFORE_THE_SEASON
        )

        assert [row["id_event"] for row in plan.vanished] == [777]
        assert plan.creates == []
        assert plan.updates == []


class TestFieldOwnership:
    """pzsz.30-pzsz.32: what the source may and may not write."""

    def test_an_admin_entered_invitation_is_never_overwritten(self):
        """pzsz.30: fill-blank-only, matching the reconciler's field-ownership
        split (ADR-081)."""
        scraped = _scraped(url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=abc")
        existing = _existing(url_invitation="https://example.org/admin-put-this-here.pdf")

        plan = pzsz_sync.diff_against_cert([scraped], [existing], today=BEFORE_THE_SEASON)

        assert plan.updates == []

    def test_a_blank_invitation_is_filled_when_the_source_supplies_one(self):
        """pzsz.31: the whole point of the daily re-visit. None of the six
        2026/2027 events carries a letter today; each will get one closer to the
        date, and the run that first sees it writes it."""
        scraped = _scraped(
            url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=abc",
            txt_venue_address="ul. Siennicka 40B",
        )
        plan = pzsz_sync.diff_against_cert([scraped], [_existing()], today=BEFORE_THE_SEASON)

        assert len(plan.updates) == 1
        fields = plan.updates[0]["fields"]
        assert fields["url_invitation"] == "https://pzszerm.pl/test/fileDownload.php?fileId=abc"
        assert fields["txt_venue_address"] == "ul. Siennicka 40B"

    def test_registration_fields_are_never_written(self):
        """pzsz.32: PZSz publishes no per-event registration link and no
        deadline. url_registration plus dt_end is what lights the event tile's
        live-registration dot (ADR-084), so a plausible-looking value would tell
        a veteran they can enter when entry is club-mediated and login-walled.

        Asserted rather than merely unset, so a future change of heart has to be
        a deliberate edit to this test."""
        scraped = _scraped(
            url_registration="https://pzszerm.pl/logowanie/",
            dt_registration_deadline="2026-09-25",
        )
        plan = pzsz_sync.diff_against_cert([scraped], [_existing()], today=BEFORE_THE_SEASON)

        assert plan.updates == []
        assert "url_registration" not in pzsz_sync.SOURCE_OWNED_FIELDS
        assert "url_registration" not in pzsz_sync.FILL_BLANK_FIELDS
        assert "dt_registration_deadline" not in pzsz_sync.SOURCE_OWNED_FIELDS
        assert "dt_registration_deadline" not in pzsz_sync.FILL_BLANK_FIELDS

        create_plan = pzsz_sync.diff_against_cert([scraped], [], today=BEFORE_THE_SEASON)
        statement = pzsz_sync.build_insert_sql(create_plan.creates[0], SEASON)
        assert "url_registration" not in statement
        assert "dt_registration_deadline" not in statement


class TestWriting:
    """pzsz.33-pzsz.34: the SQL, and the dry run that suppresses it."""

    def test_dry_run_issues_no_write(self):
        """pzsz.33: LOCAL parity — the planned rows are printed and nothing is
        sent."""
        statements: list[str] = []

        def fake_query(ref, token, sql):
            statements.append(sql)
            if "tbl_season" in sql:
                return [SEASON]
            return []

        with (
            patch.object(pzsz_sync, "_management_query", side_effect=fake_query),
            patch.object(pzsz_sync, "_telegram"),
            patch.object(pzsz_sync, "collect_season_candidates", return_value=[_scraped()]),
            patch.object(pzsz_sync, "enrich_events", side_effect=lambda rows, **kw: rows),
        ):
            pzsz_sync.sync_calendar("ref", "tok", "bot", "chat", dry_run=True)

        assert statements, "the dry run still READS CERT"
        writes = [s for s in statements if s.lstrip().upper().startswith(("INSERT", "UPDATE"))]
        assert writes == []

    def test_a_create_carries_organizer_source_id_and_country(self):
        """pzsz.34: the organizer is resolved by code, exactly as promote.py
        resolves it onto PROD -- so a missing PZSz organizer row fails loudly
        here rather than producing an event nobody owns."""
        plan = pzsz_sync.diff_against_cert([_scraped()], [], today=BEFORE_THE_SEASON)
        statement = pzsz_sync.build_insert_sql(plan.creates[0], SEASON)

        assert "tbl_organizer WHERE txt_code = 'PZSz'" in statement
        assert "id_pzsz_event" in statement and "4588" in statement
        assert "'PL'" in statement
        assert "'PPS1s-2026-2027'" in statement
        # Childless: enum_age_category is NOT NULL over V0..V4 and a senior
        # bracket has no honest value for it, so no tournament row is created.
        assert "tbl_tournament" not in statement

    def test_an_apostrophe_in_a_name_cannot_break_the_statement(self):
        """pzsz.34: PZSz names are free text from a WordPress form."""
        plan = pzsz_sync.diff_against_cert(
            [_scraped(name="I Puchar Polski seniorów - Poznań's hall")], [], today=BEFORE_THE_SEASON
        )
        statement = pzsz_sync.build_insert_sql(plan.creates[0], SEASON)

        assert "Poznań''s hall" in statement


class TestSeasonGuard:
    def test_no_active_season_raises(self):
        """pzsz.34: without a season window there is nothing to filter against,
        and guessing one would write events into the wrong season."""

        def fake_query(ref, token, sql):
            return []

        with (
            patch.object(pzsz_sync, "_management_query", side_effect=fake_query),
            patch.object(pzsz_sync, "_telegram"),
        ):
            with pytest.raises(RuntimeError, match="active season"):
                pzsz_sync.sync_calendar("ref", "tok", "bot", "chat", dry_run=True)


CHECK_PAGE = (Path(__file__).parent / "fixtures" / "pzsz_js_check.html").read_text(encoding="utf-8")
# Kept before any test patches httpx.Client, which _check_client stands in for.
_REAL_CLIENT = httpx.Client


def _check_client(*args, **kwargs) -> httpx.Client:
    """An HTTP client that receives pzszerm.pl's JavaScript check for every page."""
    return _REAL_CLIENT(
        transport=httpx.MockTransport(lambda request: httpx.Response(200, text=CHECK_PAGE))
    )


class TestTheJavaScriptCheck:
    """pzsz.41-pzsz.43: a run that meets pzszerm.pl's JavaScript check fails
    red, writes nothing and reports nothing as vanished (ADR-111, plan §6 F1).
    It never tries to get past the check."""

    def test_a_sync_meeting_the_check_writes_nothing_and_vanishes_nothing(self):
        """pzsz.41: the listing is the check page — no CERT write, no
        'no longer listed' report, and the run raises."""
        statements: list[str] = []
        sent: list[str] = []

        def fake_query(ref, token, sql):
            statements.append(sql)
            if "tbl_season" in sql:
                return [SEASON]
            return [_existing()]

        with (
            patch.object(pzsz_sync, "_management_query", side_effect=fake_query),
            patch.object(pzsz_sync, "_telegram", side_effect=lambda b, c, text: sent.append(text)),
            patch.object(pzsz_calendar.httpx, "Client", side_effect=_check_client),
        ):
            with pytest.raises(PzszPageError, match="JavaScript check"):
                pzsz_sync.sync_calendar("ref", "tok", "bot", "chat", dry_run=False)

        assert not [s for s in statements if s.lstrip().upper().startswith(("INSERT", "UPDATE"))]
        assert not [t for t in sent if "no longer listed" in t]

    def test_main_fails_red_and_says_why_on_telegram(self):
        """pzsz.42: the workflow step exits 1, and the Telegram message names
        the check and says to run again later."""
        sent: list[str] = []

        def fake_query(ref, token, sql):
            return [SEASON] if "tbl_season" in sql else []

        env = {"SUPABASE_CERT_REF": "ref", "SUPABASE_ACCESS_TOKEN": "tok"}
        with (
            patch.dict("os.environ", env),
            patch("sys.argv", ["pzsz_sync"]),
            patch.object(pzsz_sync, "_management_query", side_effect=fake_query),
            patch.object(pzsz_sync, "_telegram", side_effect=lambda b, c, text: sent.append(text)),
            patch.object(pzsz_calendar.httpx, "Client", side_effect=_check_client),
        ):
            with pytest.raises(SystemExit) as exit_info:
                pzsz_sync.main()

        assert exit_info.value.code == 1
        assert len(sent) == 1
        assert "PZSz Calendar" in sent[0] and "failed" in sent[0]
        assert "JavaScript check" in sent[0] and "again later" in sent[0]

    def test_enrichment_names_the_check_page(self, capsys):
        """pzsz.43: a detail page that is the check page is skipped by name,
        and the event keeps what it had."""
        rows = [_scraped()]
        with _check_client() as client:
            enriched = pzsz_sync.enrich_events(rows, client=client)

        assert enriched == rows
        assert "JavaScript check" in capsys.readouterr().out


# The day the plan §7 decision was taken: Poznań (3-4 October) has started.
TODAY = dt.date(2026, 10, 7)


class TestStartedEventDates:
    """pzsz.44-pzsz.48: the sync stops changing dt_start and dt_end once an
    event has started, meaning CERT's start date is before today in Warsaw
    (plan §7, Q6 A). pzszerm.pl's listing prints Poznań as 3-3 October while
    one FencingTimeLive listing is dated the 4th; the admin's 4 October must survive every
    later sync. Future events still follow every PZSz reschedule."""

    def test_a_started_events_corrected_end_date_survives(self):
        """pzsz.44: Poznań. CERT holds 3-4 October, the listing says 3-3."""
        plan = pzsz_sync.diff_against_cert(
            [_scraped()], [_existing(dt_end="2026-10-04")], today=TODAY
        )

        assert plan.updates == []

    def test_a_started_event_still_takes_its_other_source_fields(self):
        """pzsz.45: only the dates stay; a renamed event is still renamed."""
        renamed = "I Puchar Polski seniorów w szabli - Poznań 2026/2027"
        scraped = _scraped(name=renamed, dt_start="2026-10-02")
        plan = pzsz_sync.diff_against_cert([scraped], [_existing(dt_end="2026-10-04")], today=TODAY)

        assert plan.updates == [{"id_event": 501, "fields": {"txt_name": renamed}}]

    def test_a_future_event_still_follows_a_reschedule(self):
        """pzsz.46: PZSz moves an event that has not started; the calendar follows."""
        scraped = _scraped(dt_start="2026-11-28", dt_end="2026-11-29")
        existing = _existing(dt_start="2026-11-21", dt_end="2026-11-21")
        plan = pzsz_sync.diff_against_cert([scraped], [existing], today=TODAY)

        assert plan.updates == [
            {"id_event": 501, "fields": {"dt_start": "2026-11-28", "dt_end": "2026-11-29"}}
        ]

    def test_an_event_starting_today_still_follows(self):
        """pzsz.47: the boundary. Started means a start date BEFORE today."""
        scraped = _scraped(dt_start="2026-10-07", dt_end="2026-10-08")
        existing = _existing(dt_start="2026-10-07", dt_end="2026-10-07")
        plan = pzsz_sync.diff_against_cert([scraped], [existing], today=TODAY)

        assert plan.updates == [{"id_event": 501, "fields": {"dt_end": "2026-10-08"}}]

    def test_the_sync_judges_started_by_todays_date_in_warsaw(self):
        """pzsz.48: sync_calendar passes Warsaw's today, so a run on 7 October
        writes nothing to Poznań's corrected end date."""
        statements: list[str] = []

        def fake_query(ref, token, sql):
            statements.append(sql)
            if "tbl_season" in sql:
                return [SEASON]
            if sql.lstrip().upper().startswith("SELECT"):
                return [_existing(dt_end="2026-10-04")]
            return []

        with (
            patch.object(pzsz_sync, "_management_query", side_effect=fake_query),
            patch.object(pzsz_sync, "_telegram"),
            patch.object(pzsz_sync, "collect_season_candidates", return_value=[_scraped()]),
            patch.object(pzsz_sync, "enrich_events", side_effect=lambda rows: rows),
            patch.object(pzsz_sync, "plan_event_codes", side_effect=lambda rows, code: rows),
            patch.object(pzsz_sync, "warsaw_today", return_value=TODAY),
        ):
            pzsz_sync.sync_calendar("ref", "tok", "bot", "chat", dry_run=False)

        assert not [s for s in statements if s.lstrip().upper().startswith("UPDATE")]


CODE_POZNAN = "PPS1s-2026-2027"
FIXTURES = Path(__file__).parent / "fixtures"
START_LIST_PAGES = {
    "event": FIXTURES / "pzsz_event_poznan_tournaments.html",
    10628: FIXTURES / "pzsz_start_list_sabre_men.html",
    10629: FIXTURES / "pzsz_start_list_sabre_women.html",
}


def _start_list_fetch(url: str, params: dict) -> str:
    """Every PZSz event page as Poznań's, every tournament page as its own."""
    from python.scrapers.pzsz_start_list import PZSZ_EVENT_PAGE

    key = "event" if url == PZSZ_EVENT_PAGE else int(params["id"])
    return START_LIST_PAGES[key].read_text(encoding="utf-8")


def _calendar_row(code: str, id_pzsz: int | None, start: str, end: str, **over) -> dict:
    row = {
        "txt_code": code,
        "id_pzsz_event": id_pzsz,
        "dt_start": start,
        "dt_end": end,
        "enum_status": "PLANNED",
        "url_event": "https://www.fencingtimelive.com/tournaments/eventSchedule/X",
        "has_cert_run": False,
    }
    row.update(over)
    return row


def _capture_query(rows: list[dict], stored: bool = True, statements: list[str] | None = None):
    """CERT for the capture: the active season, the purge, the PZSz events of
    the season, and the store's answer."""

    def fake_query(ref, token, sql):
        if statements is not None:
            statements.append(sql)
        if "tbl_season" in sql:
            return [SEASON]
        if "fn_pzsz_start_list_purge" in sql:
            return [{"n": 0}]
        if "fn_pzsz_start_list_store" in sql:
            return [{"r": {"stored": stored}}]
        return rows

    return fake_query


class TestStartListCapture:
    """pzsz.49-pzsz.53: the daily capture stores the start lists of PZSz
    events around today while pzszerm.pl serves them (ADR-112 §2, §5, §7)."""

    def test_the_capture_window(self):
        """pzsz.49: events with a PZSz id, not COMPLETED or CANCELLED, starting
        within 14 days either side of today in Warsaw."""
        rows = [
            _calendar_row("IN-PAST", 1, "2026-09-23", "2026-09-23"),
            _calendar_row("IN-FUTURE", 2, "2026-10-21", "2026-10-22"),
            _calendar_row("TOO-OLD", 3, "2026-09-22", "2026-09-22"),
            _calendar_row("TOO-FAR", 4, "2026-10-22", "2026-10-22"),
            _calendar_row("DONE", 5, "2026-10-03", "2026-10-04", enum_status="COMPLETED"),
            _calendar_row("OFF", 6, "2026-10-03", "2026-10-04", enum_status="CANCELLED"),
            _calendar_row("NO-ID", None, "2026-10-03", "2026-10-04"),
            _calendar_row("RUNNING", 7, "2026-10-07", "2026-10-08", enum_status="IN_PROGRESS"),
        ]
        chosen = pzsz_sync.select_capture_events(rows, TODAY)
        assert [r["txt_code"] for r in chosen] == ["IN-PAST", "IN-FUTURE", "RUNNING"]

    def test_retention_runs_first_even_on_a_gated_day(self):
        """pzsz.50: the purge of lists outside the active season is the first
        write, and it runs although pzszerm.pl then answers with its gate."""
        statements: list[str] = []
        rows = [_calendar_row(CODE_POZNAN, 4588, "2026-10-03", "2026-10-04")]
        with (
            patch.object(
                pzsz_sync,
                "_management_query",
                side_effect=_capture_query(rows, statements=statements),
            ),
            patch.object(pzsz_sync, "_telegram"),
        ):
            with pytest.raises(PzszPageError, match="JavaScript check"):
                pzsz_sync.capture_start_lists(
                    "ref", "tok", "bot", "chat", today=TODAY, fetch=lambda url, params: CHECK_PAGE
                )
        writes = [s for s in statements if "fn_pzsz_start_list" in s]
        assert writes and "fn_pzsz_start_list_purge" in writes[0]
        assert not [s for s in statements if "fn_pzsz_start_list_store" in s]

    def test_telegram_names_the_ingest_only_for_an_event_waiting_for_it(self):
        """pzsz.51 (Q8 A): a new version stored for an event that has ended, has
        an FTL URL and no FINISHED CERT run: Telegram names the ingest. An event
        already ingested, one still ahead, and one without a URL get nothing."""
        sent: list[str] = []
        rows = [
            _calendar_row(CODE_POZNAN, 4588, "2026-10-03", "2026-10-04"),
            _calendar_row("PPS0s-2026-2027", 4500, "2026-09-26", "2026-09-27", has_cert_run=True),
            _calendar_row("PPS1f-2026-2027", 4581, "2026-10-20", "2026-10-21"),
            _calendar_row("PPS0e-2026-2027", 4501, "2026-09-27", "2026-09-28", url_event=None),
        ]
        with (
            patch.object(pzsz_sync, "_management_query", side_effect=_capture_query(rows)),
            patch.object(pzsz_sync, "_telegram", side_effect=lambda b, c, text: sent.append(text)),
        ):
            pzsz_sync.capture_start_lists(
                "ref", "tok", "bot", "chat", today=TODAY, fetch=_start_list_fetch
            )
        assert len(sent) == 1
        assert CODE_POZNAN in sent[0] and f"ingest {CODE_POZNAN}" in sent[0]

    def test_no_telegram_when_nothing_new_was_stored(self):
        """pzsz.51: the same lists again store nothing, so nothing is said."""
        sent: list[str] = []
        rows = [_calendar_row(CODE_POZNAN, 4588, "2026-10-03", "2026-10-04")]
        with (
            patch.object(
                pzsz_sync, "_management_query", side_effect=_capture_query(rows, stored=False)
            ),
            patch.object(pzsz_sync, "_telegram", side_effect=lambda b, c, text: sent.append(text)),
        ):
            pzsz_sync.capture_start_lists(
                "ref", "tok", "bot", "chat", today=TODAY, fetch=_start_list_fetch
            )
        assert sent == []

    def test_the_workflow_runs_the_capture_after_the_calendar(self):
        """pzsz.52: a job after the calendar job, also when that failed, never
        on a dry run, reading the repository only, and running the capture."""
        import yaml

        workflow = yaml.safe_load(
            (Path(__file__).parents[2] / ".github" / "workflows" / "pzsz-sync.yml").read_text()
        )
        job = workflow["jobs"]["capture"]
        assert job["needs"] == "sync"
        assert "!cancelled()" in job["if"] and "dry_run" in job["if"]
        assert job["permissions"] == {"contents": "read"}
        runs = " ".join(str(step.get("run", "")) for step in job["steps"])
        assert "python -m python.scrapers.pzsz_sync --capture-start-lists" in runs

    def test_a_gated_capture_fails_without_a_second_telegram(self):
        """pzsz.53: the gate stops the capture at the first page, the job
        exits 1, and Telegram is not told again (the calendar job said it)."""
        sent: list[str] = []
        fetched: list[str] = []
        rows = [
            _calendar_row(CODE_POZNAN, 4588, "2026-10-03", "2026-10-04"),
            _calendar_row("PPS1f-2026-2027", 4581, "2026-10-20", "2026-10-21"),
        ]

        def gated(url, params):
            fetched.append(url)
            return CHECK_PAGE

        env = {"SUPABASE_CERT_REF": "ref", "SUPABASE_ACCESS_TOKEN": "tok"}
        with (
            patch.dict("os.environ", env),
            patch("sys.argv", ["pzsz_sync", "--capture-start-lists"]),
            patch.object(pzsz_sync, "_management_query", side_effect=_capture_query(rows)),
            patch.object(pzsz_sync, "_telegram", side_effect=lambda b, c, text: sent.append(text)),
            patch.object(pzsz_sync, "fetch_page", side_effect=gated, create=True),
        ):
            with pytest.raises(SystemExit) as exit_info:
                pzsz_sync.main()
        assert exit_info.value.code == 1
        assert sent == []
        assert len(fetched) == 1
