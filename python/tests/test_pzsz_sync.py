"""The PZSz calendar run R1-R7 (ADR-116 §7, §9, §11-§12; RTM PZSZ.RUN.01-13).

The run reads our list, discovers from the listing (browser), reads each
letter, decides every field with the write rules, writes atomically, sends one
digest, and sets its exit status last. These tests drive it with injected fakes
— query, browser fetch, home page, letter download, letter reader, Telegram —
so no network or CERT is touched. The write-rule engine and the sources have
their own tests; here the behaviours are the run's: a listing that will not
render stays green, a bad row is skipped, a past event is left alone, a
rejected write is fatal for its event alone, and there is one digest.
"""

from __future__ import annotations

from pathlib import Path

from python.scrapers import pzsz_sync
from python.scrapers.pzsz_letter import Found, LetterResult
from python.scrapers.pzsz_write_rules import FieldState

FIXTURES = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


SEASON = {
    "id_season": 4,
    "txt_code": "SPWS-2026-2027",
    "dt_start": "2026-09-01",
    "dt_end": "2027-08-31",
}
TODAY = pzsz_sync.dt.date(2026, 10, 21)


def _event(**kw) -> dict:
    base = {
        "id_event": 1,
        "txt_code": "PPS1f-2026-2027",
        "id_pzsz_event": 4581,
        "dt_start": "2026-10-24",
        "dt_end": "2026-10-24",
        "txt_location": "Gdańsk",
        "txt_venue_address": None,
        "num_entry_fee": None,
        "txt_entry_fee_currency": None,
        "url_invitation": None,
        "url_event": "https://pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=4581",
        "enum_status": "PLANNED",
    }
    base.update(kw)
    return base


# ---- discover_listing --------------------------------------------------------


class TestDiscover:
    def test_a_listing_that_will_not_render_is_recorded_not_served(self):
        """PZSZ.RUN.01: the JavaScript check is recognised; the run gets no
        events from it and is told, but is not stopped."""
        digest = pzsz_sync._Digest()

        def fetch(url, params):
            return _read("pzsz_js_check.html")

        rows, served = pzsz_sync.discover_listing(fetch, SEASON, digest)
        assert rows == {}
        assert served is False
        assert any("check" in w.lower() for w in digest.warn)

    def test_a_render_failure_is_recorded_not_served(self):
        """PZSZ.RUN.01: a fetch that raises (Chromium down / timeout) is a
        warning, not a crash."""
        digest = pzsz_sync._Digest()

        def fetch(url, params):
            raise RuntimeError("chromium missing")

        rows, served = pzsz_sync.discover_listing(fetch, SEASON, digest)
        assert rows == {} and served is False

    def test_national_senior_events_are_returned_with_letter_links(self):
        """PZSZ.RUN.02: the real PPS listing yields its senior events keyed by
        id, each carrying its newest letter link."""
        digest = pzsz_sync._Digest()
        html = _read("pzsz_calendar_pps_2026_2027.html")  # events inside our season window

        def fetch(url, params):
            return html

        rows, served = pzsz_sync.discover_listing(fetch, SEASON, digest)
        assert served is True
        assert rows  # senior events found
        assert all("id_pzsz_event" in r for r in rows.values())
        assert all("letter_url" in r for r in rows.values())

    def test_a_seventy_row_page_is_used_but_warned(self):
        """PZSZ.RUN.04: at the cap the rows are used and events missing from it
        are not judged gone — only a warning."""
        digest = pzsz_sync._Digest()
        html = _read("pzsz_calendar_capped_70.html")

        def fetch(url, params):
            return html

        pzsz_sync.discover_listing(fetch, SEASON, digest)
        assert any("cap" in w.lower() for w in digest.warn)


# ---- _new_events -------------------------------------------------------------


class TestNewEvents:
    def _listing(self) -> dict[int, dict]:
        return {
            4700: {
                "id_pzsz_event": 4700,
                "name": "I Puchar Polski Seniorów we florecie kobiet i mężczyzn",
                "weapons": ["FOIL"],
                "dt_start": "2026-11-28",
                "dt_end": "2026-11-29",
                "location": "Konin",
                "txt_country": "PL",
                "letter_url": None,
            }
        }

    def test_a_future_listing_event_not_in_cert_is_coded_for_creation(self):
        """PZSZ.RUN.03: a future event we do not hold gets its ADR-046 code."""
        digest = pzsz_sync._Digest()
        fresh = pzsz_sync._new_events(self._listing(), set(), SEASON, TODAY, digest)
        assert [r["desired_code"] for r in fresh] == ["PPS1f-2026-2027"]

    def test_an_event_already_in_cert_is_not_recreated(self):
        digest = pzsz_sync._Digest()
        fresh = pzsz_sync._new_events(self._listing(), {4700}, SEASON, TODAY, digest)
        assert fresh == []

    def test_a_past_listing_event_is_not_created(self):
        """PZSZ.RUN.07: discovery creates future events only."""
        listing = self._listing()
        listing[4700]["dt_start"] = "2026-10-03"
        listing[4700]["dt_end"] = "2026-10-04"
        digest = pzsz_sync._Digest()
        assert pzsz_sync._new_events(listing, set(), SEASON, TODAY, digest) == []

    def test_a_row_with_no_round_numeral_is_skipped_and_warned(self):
        """PZSZ.RUN.03/§11: a bad row is skipped, the others still created."""
        listing = self._listing()
        listing[4701] = {**listing[4700], "id_pzsz_event": 4701, "name": "Zawody bez numeru"}
        digest = pzsz_sync._Digest()
        fresh = pzsz_sync._new_events(listing, set(), SEASON, TODAY, digest)
        assert [r["id_pzsz_event"] for r in fresh] == [4700]
        assert any("numeral" in w.lower() for w in digest.warn)

    def test_two_rows_that_share_a_code_are_both_held(self):
        """PZSZ.RUN.03/§11: a shared code → neither created, reported."""
        listing = self._listing()
        listing[4702] = {
            **listing[4700],
            "id_pzsz_event": 4702,
        }  # same name+weapon+dates → same code
        digest = pzsz_sync._Digest()
        fresh = pzsz_sync._new_events(listing, set(), SEASON, TODAY, digest)
        assert fresh == []
        assert any("resolve to" in w for w in digest.warn)


# ---- _process_event ----------------------------------------------------------


def _letter(**kw) -> LetterResult:
    return LetterResult(**kw)


class TestProcessEvent:
    def _run(
        self,
        event,
        *,
        created=False,
        listing_row=None,
        home_row=None,
        state=None,
        reports=None,
        letter=None,
        letter_bytes=b"PDF",
    ):
        digest = pzsz_sync._Digest()

        def letter_fetch(url):
            return letter_bytes

        def read_letter_fn(data, ctx):
            if letter is None:
                raise AssertionError("read_letter should not be called")
            return letter

        changes, out_reports, checks = pzsz_sync._process_event(
            event,
            created=created,
            listing_row=listing_row,
            home_row=home_row,
            state=state or {},
            reports=reports or {},
            season=SEASON,
            letter_fetch=letter_fetch,
            read_letter_fn=read_letter_fn,
            digest=digest,
        )
        return changes, out_reports, checks, digest

    def test_an_empty_address_is_written_from_the_letter(self):
        """PZSZ.RUN.09: pass 2 writes the venue address when the field is
        empty, with letter provenance."""
        event = _event(url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=held")
        letter = _letter(address=Found("Hala AZS, ul. Testowa 1", "ul. Testowa 1"))
        changes, _r, _c, _d = self._run(event, letter=letter)
        addr = [c for c in changes if c["field"] == "txt_venue_address"]
        assert addr and addr[0]["value"] == "Hala AZS, ul. Testowa 1"
        assert addr[0]["source"] == "letter" and addr[0]["parser_version"]

    def test_a_held_fee_is_not_rewritten(self):
        """PZSZ.RUN.09 (rule 8): pass 3 is skipped once the fee is filled."""
        event = _event(
            num_entry_fee="100",
            txt_entry_fee_currency="PLN",
            url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=held",
        )
        letter = _letter(fee=Found("120", "120 zł"))
        changes, _r, _c, _d = self._run(event, letter=letter)
        assert not [c for c in changes if c["field"] == "num_entry_fee"]

    def test_a_fee_written_carries_the_currency(self):
        """PZSZ.RUN.09: an empty fee is written with txt_entry_fee_currency=PLN."""
        event = _event(url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=held")
        letter = _letter(fee=Found("100", "100 zł"))
        changes, _r, _c, _d = self._run(event, letter=letter)
        fields = {c["field"]: c["value"] for c in changes}
        assert fields.get("num_entry_fee") == "100"
        assert fields.get("txt_entry_fee_currency") == "PLN"

    def test_a_city_mismatch_is_warned_not_written(self):
        """PZSZ.RUN.09 (D2): the letter's venue city only validates; a mismatch
        is flagged, the city never rewritten by the letter."""
        event = _event(url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=held")
        letter = _letter(city_seen="Sopot", city_match=False)
        changes, _r, _c, digest = self._run(event, letter=letter)
        assert not [c for c in changes if c["field"] == "txt_location"]
        assert any("Sopot" in w for w in digest.warn)

    def test_no_text_letter_records_the_check_and_warns(self):
        """PZSZ.RUN.09 (D7): a letter with no text layer is recorded and the
        operator told to enter the fields in Admin; nothing is written."""
        event = _event(url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=held")
        letter = _letter(has_text=False)
        changes, _r, checks, digest = self._run(event, letter=letter)
        assert any(c["check"] == "letter" and c["state"] == "no_text" for c in checks)
        assert any("Admin" in w for w in digest.warn)

    def test_pass_0_uses_the_held_link_and_does_not_read_the_listing(self):
        """PZSZ.RUN.08 (rule 8): with a link held, pass 0 writes nothing new and
        reads the held letter, not the listing's."""
        event = _event(url_invitation="https://pzszerm.pl/test/fileDownload.php?fileId=held")
        listing_row = {"letter_url": "https://pzszerm.pl/test/fileDownload.php?fileId=other"}
        letter = _letter()
        changes, _r, _c, _d = self._run(event, listing_row=listing_row, letter=letter)
        assert not [c for c in changes if c["field"] == "url_invitation"]

    def test_the_letter_leads_on_dates_over_the_listing(self):
        """PZSZ.RUN.09 (D1): the letter's dates outrank the listing's, replacing
        the run's own listing value (rule 4)."""
        event = _event(dt_end="2026-10-25")
        state = {
            "dt_start": FieldState("2026-10-24", "listing"),
            "dt_end": FieldState("2026-10-25", "listing"),
        }
        listing_row = {"dt_start": "2026-10-24", "dt_end": "2026-10-25", "location": "Gdańsk"}
        letter = _letter(
            dt_start="2026-10-24", dt_end="2026-10-24", dates_evidence="Data: 24.10.2026 r."
        )
        event["url_invitation"] = "https://pzszerm.pl/test/fileDownload.php?fileId=held"
        changes, _r, _c, _d = self._run(event, listing_row=listing_row, state=state, letter=letter)
        end = [c for c in changes if c["field"] == "dt_end"]
        assert end and end[0]["value"] == "2026-10-24" and end[0]["source"] == "letter"

    def test_a_created_event_seeds_provenance_for_its_listing_values(self):
        """PZSZ.RUN.03: a created event records the dates and city it was
        inserted with as run-written, so a later run does not read them as a
        hand edit (rule 3)."""
        event = _event(id_event=999, url_invitation=None)
        listing_row = {"dt_start": "2026-10-24", "dt_end": "2026-10-24", "location": "Gdańsk"}
        changes, _r, _c, _d = self._run(event, created=True, listing_row=listing_row)
        seeded = {c["field"] for c in changes}
        assert {"dt_start", "dt_end", "txt_location"} <= seeded


# ---- run_calendar (integration) ---------------------------------------------


class FakeQuery:
    """A CERT stand-in that routes by the SQL it is given and records the
    fn_pzsz_apply_event payloads. Raises on the fn for one event to model a
    rejected write."""

    def __init__(
        self,
        events,
        *,
        field_state=None,
        source_reports=None,
        ingest=None,
        fn_result=None,
        fn_raise_id=None,
        create_id=777,
    ):
        self.events = events
        self.field_state = field_state or []
        self.source_reports = source_reports or []
        self.ingest = ingest or []
        self.fn_result = fn_result or {
            "applied": [],
            "hand_changed": [],
            "rejected": [],
            "checks_changed": [],
        }
        self.fn_raise_id = fn_raise_id
        self.create_id = create_id
        self.fn_calls: list[str] = []
        self.inserts: list[str] = []

    def __call__(self, ref, token, sql):
        if "bool_active" in sql:
            return [SEASON]
        if "FROM tbl_pzsz_field_state" in sql:
            return self.field_state
        if "FROM tbl_pzsz_source_report" in sql:
            return self.source_reports
        if "fn_pzsz_apply_event" in sql:
            self.fn_calls.append(sql)
            if self.fn_raise_id is not None and f"fn_pzsz_apply_event({self.fn_raise_id}," in sql:
                raise RuntimeError("permission denied")
            return [{"r": self.fn_result}]
        if "INSERT INTO tbl_event" in sql:
            self.inserts.append(sql)
            return [{"id_event": self.create_id}]
        if "has_list" in sql:
            return self.ingest
        if "FROM tbl_event e JOIN tbl_organizer" in sql:
            return self.events
        return []


def _run(query, *, fetch=None, home=None, letter=None, telegram_sink=None):
    sent: list[str] = []

    def _tel(bot, chat, msg):
        sent.append(msg)

    def _fetch(url, params):
        return _read("pzsz_js_check.html") if fetch is None else fetch(url, params)

    def _home():
        return _read("pzsz_home_najblizsze.html") if home is None else home()

    def _letter_fetch(url):
        return None if letter is None else b"PDF"

    def _read_letter(data, ctx):
        assert letter is not None  # only reached when a letter was provided
        return letter

    code = pzsz_sync.run_calendar(
        "ref",
        "tok",
        "bot",
        "chat",
        today=TODAY,
        query=query,
        telegram=telegram_sink or _tel,
        fetch=_fetch,
        home_fetch=_home,
        letter_fetch=_letter_fetch,
        read_letter_fn=_read_letter,
    )
    return code, sent


class TestRunCalendar:
    def test_a_past_event_is_left_alone(self):
        """PZSZ.RUN.07: a started event gets no fn call (the run reads nothing
        for it)."""
        past = _event(txt_code="PPS0f-2026-2027", dt_start="2026-10-03", dt_end="2026-10-04")
        q = FakeQuery([past])
        code, _sent = _run(q)
        assert code == 0
        assert q.fn_calls == []  # no write for a past event

    def test_a_future_event_with_no_sources_stays_green(self):
        """PZSZ.RUN.01: the listing does not render, no home row, no letter; the
        run writes nothing and is green (it still processes from our list)."""
        q = FakeQuery([_event()])
        code, _sent = _run(q, home=lambda: "<html><body></body></html>")
        assert code == 0
        assert q.fn_calls == []  # nothing to write

    def test_a_rejected_write_is_fatal_for_its_event_alone(self):
        """PZSZ.RUN.11-12: the fn raising for one event paints the run red and
        names it, while the others are still processed; one digest."""
        a = _event(id_event=1, txt_code="PPS1f-2026-2027", id_pzsz_event=4581)
        b = _event(
            id_event=2, txt_code="PPS1e-2026-2027", id_pzsz_event=4596, txt_location="Szczecin"
        )
        letter = LetterResult(address=Found("Hala, ul. X 1", "ul. X 1"))
        q = FakeQuery([a, b], fn_raise_id=1, fn_result={"applied": ["txt_venue_address"]})
        code, sent = _run(q, letter=letter)
        assert code == 1  # red
        assert len(sent) == 1  # one digest
        assert "❌" in sent[0] and "PPS1f-2026-2027" in sent[0]
        assert any("fn_pzsz_apply_event(2," in c for c in q.fn_calls)  # event 2 still processed

    def test_one_digest_lists_writes_and_warnings(self):
        """PZSZ.RUN.11: writes, warnings and the ingest notice ride one message."""
        a = _event()
        letter = LetterResult(address=Found("Hala, ul. X 1", "ul. X 1"))
        q = FakeQuery([a], fn_result={"applied": ["txt_venue_address"]})
        code, sent = _run(q, letter=letter)
        assert code == 0
        assert len(sent) == 1
        assert "txt_venue_address" in sent[0]

    def test_no_active_season_is_the_one_fatal_that_stops_the_start(self):
        """PZSZ.RUN.11: no active season raises before any event is touched."""

        def query(ref, token, sql):
            return []  # no bool_active row

        import pytest

        with pytest.raises(RuntimeError, match="active season"):
            _run(query)

    def test_dry_run_writes_nothing(self):
        """PZSZ.RUN.11: a dry run plans and prints, sends no Telegram, writes
        nothing."""
        q = FakeQuery([_event()])
        sent: list[str] = []
        pzsz_sync.run_calendar(
            "ref",
            "tok",
            "bot",
            "chat",
            today=TODAY,
            query=q,
            telegram=lambda b, c, m: sent.append(m),
            fetch=lambda u, p: _read("pzsz_js_check.html"),
            home_fetch=lambda: _read("pzsz_home_najblizsze.html"),
            letter_fetch=lambda u: None,
            read_letter_fn=lambda d, c: LetterResult(),
            dry_run=True,
        )
        assert q.fn_calls == [] and q.inserts == [] and sent == []
