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
"""

from unittest.mock import patch

import pytest

import python.scrapers.pzsz_sync as pzsz_sync

SEASON = {
    "txt_code": "SPWS-2026-2027",
    "dt_start": "2026-07-13",
    "dt_end": "2027-07-15",
    "id_season": 4,
}


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
        plan = pzsz_sync.diff_against_cert([_scraped()], [])

        assert [row["desired_code"] for row in plan.creates] == ["PPS1s-2026-2027"]
        assert plan.updates == []

    def test_an_unchanged_event_produces_no_write(self):
        """pzsz.26: the daily cron must be a no-op on a settled calendar."""
        plan = pzsz_sync.diff_against_cert([_scraped()], [_existing()])

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
        plan = pzsz_sync.diff_against_cert([scraped], [_existing()])

        assert plan.creates == []
        assert len(plan.updates) == 1
        update = plan.updates[0]
        assert update["id_event"] == 501
        assert update["fields"]["txt_code"] == "PPS2s-2026-2027"
        assert update["fields"]["dt_start"] == "2026-11-07"

    def test_a_row_without_a_source_id_is_adopted_by_code(self):
        """pzsz.28: an event an admin entered by hand before the scraper existed
        is adopted rather than duplicated, and gains the source id."""
        plan = pzsz_sync.diff_against_cert([_scraped()], [_existing(id_pzsz_event=None)])

        assert plan.creates == []
        assert len(plan.updates) == 1
        assert plan.updates[0]["fields"]["id_pzsz_event"] == 4588

    def test_a_vanished_event_is_surfaced_not_deleted(self):
        """pzsz.29: a row whose id we hold but which is gone from the listing is
        a cancellation or a re-key. Deleting it would take any registrations with
        it, so the scraper reports and leaves it for a human."""
        gone = _existing(id_event=777, txt_code="PPS3e-2026-2027", id_pzsz_event=4999)
        plan = pzsz_sync.diff_against_cert([_scraped()], [_existing(), gone])

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

        plan = pzsz_sync.diff_against_cert([scraped], [existing])

        assert plan.updates == []

    def test_a_blank_invitation_is_filled_when_the_source_supplies_one(self):
        """pzsz.31: the whole point of the daily re-visit. None of the six
        2026/2027 events carries a letter today; each will get one closer to the
        date, and the run that first sees it writes it."""
        scraped = _scraped(
            url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=abc",
            txt_venue_address="ul. Siennicka 40B",
        )
        plan = pzsz_sync.diff_against_cert([scraped], [_existing()])

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
        plan = pzsz_sync.diff_against_cert([scraped], [_existing()])

        assert plan.updates == []
        assert "url_registration" not in pzsz_sync.SOURCE_OWNED_FIELDS
        assert "url_registration" not in pzsz_sync.FILL_BLANK_FIELDS
        assert "dt_registration_deadline" not in pzsz_sync.SOURCE_OWNED_FIELDS
        assert "dt_registration_deadline" not in pzsz_sync.FILL_BLANK_FIELDS

        create_plan = pzsz_sync.diff_against_cert([scraped], [])
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
        plan = pzsz_sync.diff_against_cert([_scraped()], [])
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
            [_scraped(name="I Puchar Polski seniorów - Poznań's hall")], []
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
