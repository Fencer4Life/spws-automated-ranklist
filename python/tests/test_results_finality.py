"""FINAL / ENGINE — a bracket is taken only when it is final (ADR-119 §1, D2 B, D14 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, release 1.

Every results engine answers one question per bracket: is it finished? FTL says
so on its schedule row, Engarde in each competition's state. 4fence, Ophardt,
d'Artagnan, EVF's results API and a lone results page say nothing, so a bracket
from them is taken once its content has been seen unchanged for 60 minutes, or
once the event's end date has passed (the sightings rule). A bracket that is not
final is skipped with a reason that starts "not final", which keeps the event
IN_PROGRESS on CERT, on PROD and in the daily close.

  FINAL.01  a running Engarde final keeps the event IN_PROGRESS (error 7 of the
            31 Oct findings page, gap G3);
  FINAL.02  the Engarde reader and the event reader keep a running final's state;
  FINAL.03  the daily close keeps an event with a running Engarde final open;
  FINAL.04  the sightings rule: first sighting skipped, 60 minutes later taken,
            after the end date taken at once;
  FINAL.06  FTL's not-final reason and schedule hash are unchanged;
  FINAL.07  the daily close's re-read of several sources hashes as the run did;
  FINAL.08  the sightings never enter the PROD seed (a pin: the export names
            every table it writes, and none of them is the sightings table);
  SYNC.SEED.01  the results sync's pauses never enter it either (release 3);
  ENGINE.01 every engine is classified and answers the question;
  ENGINE.02 an engine without a signal cannot be read without the rule;
  ENGINE.03 the handbook's engine table lists exactly the engines the code has.

FINAL.05 (the sightings store) is pgTAP 119.
"""

from __future__ import annotations

import datetime as dt
import re
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind

ROOT = Path(__file__).resolve().parents[2]
ENGARDE_TOURNAMENT = "https://engarde-service.com/tournament/evf/madrid2026"
FOURFENCE = "https://www.4fence.it/FIS/Risultati/2026-11-14-07_Napoli/index.php"
OPHARDT = "https://fencingworldwide.com/en/12345-2026/tournament/"
DARTAGNAN = "https://dartagnan.live/2026/salzburg/en/index.html"
FTL = "https://www.fencingtimelive.com/tournaments/eventSchedule/CD17"
PAGE = "https://example.org/results/one-bracket.html"
END = dt.date(2026, 11, 1)
NOW = dt.datetime(2026, 11, 1, 12, 0, tzinfo=dt.UTC)


def _parsed(category="V1", weapon="EPEE", gender="M", url="https://e/1", places=(1, 2, 3)):
    return ParsedTournament(
        source_kind=SourceKind.ENGARDE,
        results=[
            ParsedResult(source_row_id=f"r{p}", fencer_name=f"FENCER{p} Jan", place=p)
            for p in places
        ],
        raw_pool_size=len(places),
        weapon=weapon,
        gender=gender,
        category_hint=category,
        source_url=url,
        tournament_name=f"{weapon} {gender} {category}",
    )


RUNNING = {
    "weapon": "EPEE",
    "name": "EPEE MALE 2",
    "url": "https://engarde-service.com/competition/evf/madrid2026/epeemale2",
    "reason": "not completed (tableau)",
    "finished": False,
    "state": "tableau",
}


def _fetcher(parsed, skipped=()):
    fetcher = MagicMock()
    fetcher.fetch_event_url_with_skips.return_value = (list(parsed), list(skipped))
    return fetcher


# --------------------------------------------------------------------------
# FINAL.01-03 — Engarde's own signal reaches the lifecycle
# --------------------------------------------------------------------------


def test_FINAL_01_a_running_engarde_final_keeps_the_event_in_progress():
    """Error 7 of doc/plans/ingestion-source-errors-findings-2026-10-31.html: one
    committed bracket and one Engarde final still running, the day after the end
    date. The lifecycle said COMPLETED; it must say IN_PROGRESS."""
    from python.pipeline import international_sources as src
    from python.pipeline.promotion import lifecycle
    from python.pipeline.promotion.run_record import ListingLog

    recs, kept, skipped = src.read_brackets(
        {"txt_code": "PEW2efs-2026-2027"},
        [ENGARDE_TOURNAMENT],
        fetcher=_fetcher([_parsed()], [RUNNING]),
        finality=src.SETTLED,
    )
    assert [r["uuid"] for r in recs] == ["https://e/1"]
    assert [s["name"] for s in skipped if lifecycle.is_not_final(s["reason"])] == ["EPEE MALE 2"]
    log = ListingLog()
    log.add_schedule(kept, skipped)
    log.rounds.append({"name": "EPEE M V1", "uuid": "https://e/1", "status": "committed"})
    verdict = lifecycle.event_status(log.listings(), dt_end=END, today=END + dt.timedelta(days=1))
    assert verdict.status == lifecycle.IN_PROGRESS
    assert "EPEE MALE 2" in verdict.reasons[0]


def test_FINAL_02_the_engarde_reader_keeps_a_running_finals_state():
    """The reader marks a competition it skips for its state as not finished,
    and the event reader hands that on instead of dropping it."""
    from python.pipeline.review_cli import Fetcher
    from python.scrapers.engarde import parse_competition_list

    xml = (
        '<comps><comp org="evf" evt="madrid2026" compe="epeemale1" sexe="m" arme="e" '
        'estindividuelle="1" etat="completed" date="2026 10 31"><titre>EPEE MALE 1</titre></comp>'
        '<comp org="evf" evt="madrid2026" compe="epeemale2" sexe="m" arme="e" '
        'estindividuelle="1" etat="tableau" date="2026 10 31"><titre>EPEE MALE 2</titre></comp>'
        '<comp org="evf" evt="madrid2026" compe="teq" sexe="m" arme="e" '
        'estindividuelle="0" etat="tableau" date="2026 10 31"><titre>EPEE MALE TEAM</titre></comp>'
        "</comps>"
    )
    _kept, skipped = parse_competition_list(xml, org="evf", event="madrid2026")
    by_slug = {s["slug"]: s for s in skipped}
    assert (by_slug["epeemale2"]["finished"], by_slug["epeemale2"]["state"]) == (False, "tableau")
    assert "finished" not in by_slug["teq"]  # a team event is not a bracket, final or not

    page = (
        Path(__file__).parent / "fixtures" / "engarde" / "competition_crit26_ehv2.html"
    ).read_text()
    http = MagicMock()
    http.get.side_effect = lambda url: MagicMock(
        text=xml if "getCompeForDisplay.php" in url else page, raise_for_status=lambda: None
    )
    _parsed_list, out = Fetcher(http_client=http).fetch_event_url_with_skips(ENGARDE_TOURNAMENT)
    running = next(s for s in out if s["name"] == "EPEE MALE 2")
    assert (running["finished"], running["state"]) == (False, "tableau")


def test_FINAL_03_the_daily_close_keeps_an_event_with_a_running_engarde_final_open():
    from python.pipeline import international_sources as src
    from python.pipeline.promotion import close
    from python.pipeline.promotion.run_record import ListingLog

    sources = [{"slot": "url_event", "url": ENGARDE_TOURNAMENT}]
    fetcher = _fetcher([_parsed()], [RUNNING])
    _recs, kept, skipped = src.read_brackets(
        {"txt_code": "PEW2efs-2026-2027"},
        [ENGARDE_TOURNAMENT],
        fetcher=fetcher,
        finality=src.SETTLED,
    )
    log = ListingLog()
    log.add_sources(sources)
    log.add_schedule(kept, skipped)
    log.rounds.append({"name": "EPEE M V1", "uuid": "https://e/1", "status": "committed"})
    run = {"url_event": "", "listings": log.listings(), "result_fingerprint": "f" * 64}

    env = MagicMock()
    env.event.return_value = {"status": "IN_PROGRESS", "dt_end": END.isoformat()}
    env.result_fingerprint.return_value = "f" * 64
    env.latest_finished_run.return_value = run
    reasons = close.check(
        "PEW2efs-2026-2027",
        env,
        env,
        read_schedule=MagicMock(side_effect=AssertionError("the FTL-only reader")),
        today=END + dt.timedelta(days=1),
        read_sources=lambda urls, event=None: src.read_schedule(urls, fetcher=fetcher, event=event),
    )
    assert any(r.startswith("not final yet") and "EPEE MALE 2" in r for r in reasons), reasons
    assert not any("schedule changed" in r for r in reasons), reasons


# --------------------------------------------------------------------------
# STUCK.01-05 — a competition stuck at the source never holds an event (G44 A)
# --------------------------------------------------------------------------
#
# The five read on 1 Nov 2026, every one still in that state at the source:
# Madrid 2024 "EPEE MALE 3 -4" and "FOIL FEMALE ALL cat" (poules), Budapest
# 2025 "Women's Sabre V4 (70)", Stockholm 2026 "Mens Foil Cat 4" and Madrid
# 2026 "TABLE FOIL MALE 4" (empty).

STUCK = (
    '<comps><comp org="o" evt="e" compe="em-3-4" sexe="m" arme="e" estindividuelle="1" '
    'etat="poules" date="2024 10 26"><titre>EPEE MALE 3 -4</titre></comp>'
    '<comp org="o" evt="e" compe="ff_all" sexe="f" arme="f" estindividuelle="1" '
    'etat="poules" date="2024 10 26"><titre>FOIL FEMALE ALL cat</titre></comp>'
    '<comp org="o" evt="e" compe="ws70" sexe="f" arme="s" estindividuelle="1" '
    'etat="empty" date="2025 09 20"><titre>Women\'s Sabre V4 (70)</titre></comp>'
    '<comp org="o" evt="e" compe="mf4" sexe="m" arme="f" estindividuelle="1" '
    'etat="empty" date="2026 03 14"><titre>Mens Foil Cat 4</titre></comp>'
    '<comp org="o" evt="e" compe="tfm4" sexe="m" arme="f" estindividuelle="1" '
    'etat="empty" date="2026 11 01"><titre>TABLE FOIL MALE 4</titre></comp>'
    '<comp org="o" evt="e" compe="tem2" sexe="m" arme="e" estindividuelle="1" '
    'etat="tableau" date="2026 11 01"><titre>TABLE EPEE MALE 2</titre></comp>'
    "</comps>"
)


def _stuck():
    from python.scrapers.engarde import parse_competition_list

    kept, skipped = parse_competition_list(STUCK, org="o", event="e")
    assert kept == []
    return {s["slug"]: s for s in skipped}


def test_STUCK_01_a_competition_we_would_never_take_is_never_not_final():
    """G44 A (1): the kind and category checks come before the state check,
    so a joined competition, or one without a category, at poules is skipped
    as what it is, not as a bracket still running."""
    by_slug = _stuck()
    assert by_slug["em-3-4"]["reason"] == "spans categories V3, V4"
    assert by_slug["ff_all"]["reason"] == "no category in the title"
    for slug in ("em-3-4", "ff_all"):
        assert "finished" not in by_slug[slug], slug


def test_STUCK_02_an_empty_competition_is_one_nobody_fenced():
    """G44 A (2): Engarde's empty is not a listing and never not final; a
    competition still running keeps its state (FINAL.02)."""
    from python.pipeline.promotion import lifecycle

    by_slug = _stuck()
    for slug in ("ws70", "mf4", "tfm4"):
        assert by_slug[slug]["reason"] == "nobody fenced (Engarde shows it empty)", slug
        assert "finished" not in by_slug[slug], slug
        assert not lifecycle.is_not_final(by_slug[slug]["reason"])
    assert (by_slug["tem2"]["finished"], by_slug["tem2"]["state"]) == (False, "tableau")


def _verdict(today):
    from python.pipeline import international_sources as src
    from python.pipeline.promotion import lifecycle
    from python.pipeline.promotion.run_record import ListingLog

    _recs, kept, skipped = src.read_brackets(
        {"txt_code": "PEW2efs-2026-2027"},
        [ENGARDE_TOURNAMENT],
        fetcher=_fetcher([_parsed()], [RUNNING]),
        finality=src.SETTLED,
    )
    log = ListingLog()
    log.add_schedule(kept, skipped)
    log.rounds.append({"name": "EPEE M V1", "uuid": "https://e/1", "status": "committed"})
    return lifecycle.event_status(log.listings(), dt_end=END, today=today)


def test_STUCK_03_a_bracket_still_running_holds_the_event_through_the_day_after_its_end():
    """G44 A (3): through the day after the end date (the sync's last day) a
    running bracket keeps the event IN_PROGRESS (FINAL.01); from the next day
    the event completes without it, and the verdict names it."""
    from python.pipeline.promotion import lifecycle

    assert _verdict(END + dt.timedelta(days=1)).status == lifecycle.IN_PROGRESS
    later = _verdict(END + dt.timedelta(days=2))
    assert later.status == lifecycle.COMPLETED
    assert later.left_out == ["EPEE MALE 2"]
    assert not any("EPEE MALE 2" in r for r in later.reasons)


def test_STUCK_04_the_daily_close_completes_it_and_names_what_it_left_out():
    from python.pipeline import international_sources as src
    from python.pipeline.promotion import close
    from python.pipeline.promotion.run_record import ListingLog

    sources = [{"slot": "url_event", "url": ENGARDE_TOURNAMENT}]
    fetcher = _fetcher([_parsed()], [RUNNING])
    _recs, kept, skipped = src.read_brackets(
        {"txt_code": "PEW2efs-2026-2027"},
        [ENGARDE_TOURNAMENT],
        fetcher=fetcher,
        finality=src.SETTLED,
    )
    log = ListingLog()
    log.add_sources(sources)
    log.add_schedule(kept, skipped)
    log.rounds.append({"name": "EPEE M V1", "uuid": "https://e/1", "status": "committed"})
    run = {"url_event": "", "listings": log.listings(), "result_fingerprint": "f" * 64}

    env = MagicMock()
    env.name = "cert"
    env.event.return_value = {"status": "IN_PROGRESS", "dt_end": END.isoformat()}
    env.result_fingerprint.return_value = "f" * 64
    env.latest_finished_run.return_value = run
    env.events_to_close.return_value = ["PEW2efs-2026-2027"]
    notifier = MagicMock()
    (outcome,) = close.close_events(
        env,
        env,
        read_schedule=MagicMock(side_effect=AssertionError("the FTL-only reader")),
        notifier=notifier,
        today=END + dt.timedelta(days=2),
        read_sources=lambda urls, event=None: src.read_schedule(urls, fetcher=fetcher, event=event),
    )
    assert outcome.closed
    (message,) = notifier.success.call_args.args
    assert "COMPLETED" in message and "EPEE MALE 2" in message
    assert "manual ingest" in message


def test_STUCK_05_the_cycle_line_names_the_listings_not_final():
    """G44 A (3): the cycle's line names what is not final, so the day after
    the end date says which bracket the close will leave out."""
    from python.pipeline.promotion import results_sync as rs

    run = {
        "listings": {
            "schedule": {"skipped": [{"name": "TABLE FOIL MALE 4", "reason": "not final (x)"}]},
            "rounds": [],
        }
    }
    assert rs._not_final_part(run) == "1 listing not final: TABLE FOIL MALE 4"
    assert rs._not_final_part({"listings": {}}) is None


# --------------------------------------------------------------------------
# FINAL.04 — the sightings rule for engines without a signal
# --------------------------------------------------------------------------


class _Seen:
    """A sightings store: first seen per (key, sha), as the database keeps it."""

    def __init__(self, earlier: dict | None = None):
        self.first = dict(earlier or {})
        self.calls: list[tuple[str, str]] = []

    def __call__(self, key, sha):
        self.calls.append((key, sha))
        return self.first.setdefault((key, sha), NOW)


@pytest.mark.parametrize("url", [FOURFENCE, OPHARDT, DARTAGNAN, PAGE])
def test_FINAL_04_a_bracket_without_a_signal_waits_60_minutes_unless_the_event_is_over(url):
    from python.pipeline import international_sources as src
    from python.pipeline.promotion import lifecycle
    from python.pipeline.promotion.run_record import listing_sha256

    event = {"txt_code": "PEW4efs-2026-2027"}
    parsed = _parsed(url="https://o/1")
    sha = listing_sha256("EPEE M V1", "https://o/1", True, parsed.results)

    seen = _Seen()
    recs, kept, skipped = src.read_brackets(
        event, [url], fetcher=_fetcher([parsed]), finality=src.Sightings(seen, now=NOW, ended=False)
    )
    assert recs == [] and kept == []
    assert skipped == [
        {
            "uuid": "https://o/1",
            "name": "EPEE M V1",
            "url": "https://o/1",
            "weapon": "EPEE",
            "reason": lifecycle.SEEN_ONCE,
        }
    ]
    assert lifecycle.is_not_final(lifecycle.SEEN_ONCE)
    assert seen.calls == [("https://o/1", sha)]

    later = _Seen({("https://o/1", sha): NOW - dt.timedelta(minutes=60)})
    recs, kept, _ = src.read_brackets(
        event,
        [url],
        fetcher=_fetcher([parsed]),
        finality=src.Sightings(later, now=NOW, ended=False),
    )
    assert [r["uuid"] for r in recs] == ["https://o/1"] and kept[0]["finished"] is True

    almost = _Seen({("https://o/1", sha): NOW - dt.timedelta(minutes=59)})
    recs, _, _ = src.read_brackets(
        event,
        [url],
        fetcher=_fetcher([parsed]),
        finality=src.Sightings(almost, now=NOW, ended=False),
    )
    assert recs == []

    over = _Seen()
    recs, _, _ = src.read_brackets(
        event, [url], fetcher=_fetcher([parsed]), finality=src.Sightings(over, now=NOW, ended=True)
    )
    assert [r["uuid"] for r in recs] == ["https://o/1"] and over.calls == []


def test_FINAL_04b_evf_results_follow_the_sightings_rule():
    from python.pipeline import international_sources as src
    from python.pipeline.promotion import lifecycle

    rows = [
        {
            "fencer_name": "NOWAK Jan",
            "place": 1,
            "country": "POL",
            "weapon": "FOIL",
            "gender": "M",
            "category": "V2",
        },
    ]
    event = {"txt_code": "PEW3-2026-2027", "id_evf_event": 85}
    recs, kept, skipped = src.read_brackets(
        event,
        ["evf:85"],
        evf_scrape=MagicMock(return_value=rows),
        finality=src.Sightings(_Seen(), now=NOW, ended=False),
    )
    assert recs == [] and kept == []
    assert [(s["uuid"], s["reason"]) for s in skipped] == [
        ("evf:85:FOIL:M:V2", lifecycle.SEEN_ONCE)
    ]


def test_FINAL_04c_the_promote_plan_takes_exactly_what_the_cert_run_took():
    """Plan mode never writes a sighting: it replays the CERT run's decision,
    bracket by bracket, by key and content hash."""
    from python.pipeline import international_sources as src
    from python.pipeline.promotion.run_record import listing_sha256

    parsed = _parsed(url="https://o/1")
    sha = listing_sha256("EPEE M V1", "https://o/1", True, parsed.results)
    taken = src.TakenByRun([{"uuid": "https://o/1", "sha256": sha, "status": "committed"}])
    recs, _, _ = src.read_brackets(
        {"txt_code": "PEW4efs-2026-2027"}, [OPHARDT], fetcher=_fetcher([parsed]), finality=taken
    )
    assert [r["uuid"] for r in recs] == ["https://o/1"]
    changed = src.TakenByRun([{"uuid": "https://o/1", "sha256": "0" * 64, "status": "committed"}])
    recs, _, skipped = src.read_brackets(
        {"txt_code": "PEW4efs-2026-2027"}, [OPHARDT], fetcher=_fetcher([parsed]), finality=changed
    )
    assert recs == [] and [s["uuid"] for s in skipped] == ["https://o/1"]


def test_FINAL_04d_the_live_ingest_records_sightings_on_its_own_database():
    """The CERT ingest decides with the sightings it stores; ended is the day
    after the end date in Warsaw."""
    from python.pipeline import international_sources as src

    db = MagicMock()
    db.record_listing_sighting.return_value = NOW
    finality = src.sightings_for(
        db, {"txt_code": "PEW4efs-2026-2027", "dt_end": "2026-11-01"}, now=NOW
    )
    assert finality.ended is False
    assert finality.settled("k", "s" * 64) is False
    db.record_listing_sighting.assert_called_once_with("PEW4efs-2026-2027", "k", "s" * 64)
    after = src.sightings_for(
        db,
        {"txt_code": "PEW4efs-2026-2027", "dt_end": "2026-11-01"},
        now=dt.datetime(2026, 11, 1, 23, 30, tzinfo=dt.UTC),  # 2 Nov 00:30 in Warsaw
    )
    assert after.ended is True


# --------------------------------------------------------------------------
# FINAL.06-07 — FTL unchanged; several sources hash alike in ingest and close
# --------------------------------------------------------------------------


def test_FINAL_06_ftls_not_final_reason_and_schedule_hash_are_unchanged():
    """Recorded runs hash their schedules with FTL's reason; it must not move."""
    from python.pipeline.promotion import lifecycle
    from python.pipeline.promotion.run_record import schedule_sha256

    assert lifecycle.NOT_FINAL == "not final (its schedule row does not say Finished)"
    assert lifecycle.is_not_final(lifecycle.NOT_FINAL)
    assert not lifecycle.is_not_final("team event")
    kept = [{"uuid": "A1", "name": "Men's Epee V1", "finished": True}]
    skipped = [{"uuid": "A3", "name": "Men's Epee V3", "reason": lifecycle.NOT_FINAL}]
    # Computed with the code of main 82b6ba78, before this release.
    assert schedule_sha256(kept, skipped) == (
        "175c7e56582b0ba57ac45c583834cc2901381e62c600be7e1437a0bec9e762ae"
    )


def test_FINAL_07_several_sources_rehash_in_the_daily_close_as_the_run_hashed_them():
    """Two FTL schedules, each with a listing not yet final: the run records
    each source's skips then its not-final listings; the close's re-read must
    give the same order, or it reports a schedule change that did not happen."""
    from python.pipeline import international_sources as src
    from python.pipeline.promotion import lifecycle
    from python.pipeline.promotion.run_record import schedule_sha256

    second = "https://www.fencingtimelive.com/tournaments/eventSchedule/EF22"
    listed = {
        FTL: (
            [
                {"uuid": "A1", "name": "Men's Epee V1", "finished": True, "day": "2026-10-31"},
                {"uuid": "A2", "name": "Men's Epee V2", "finished": False, "day": "2026-10-31"},
            ],
            [{"uuid": "AT", "name": "Men's Epee Team", "reason": "team event"}],
        ),
        second: (
            [
                {"uuid": "B1", "name": "Women's Foil V1", "finished": True, "day": "2026-11-01"},
                {"uuid": "B2", "name": "Women's Foil V2", "finished": False, "day": "2026-11-01"},
            ],
            [{"uuid": "BT", "name": "Women's Foil Team", "reason": "team event"}],
        ),
    }
    data = {"A1": [], "B1": []}
    client = MagicMock()
    client.__enter__.return_value = client
    client.get.side_effect = lambda url: MagicMock(
        text=url, json=lambda: data[url.rsplit("/", 1)[-1]], raise_for_status=lambda: None
    )
    with (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=client),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch(
            "python.tools.scrape_ftl_event_urls.parse_event_schedule",
            side_effect=lambda text, with_skips: (
                [dict(k) for k in listed[text][0]],
                [dict(s) for s in listed[text][1]],
            ),
        ),
        patch(
            "python.tools.scrape_ftl_event_urls.parse_tournament_name",
            side_effect=lambda name: (
                "EPEE" if "Epee" in name else "FOIL",
                "M" if "Men" in name else "F",
                name[-2:],
            ),
        ),
        patch(
            "python.scrapers.ftl.parse_json",
            side_effect=lambda js, source_url: _parsed(url=source_url),
        ),
    ):
        _recs, kept, skipped = src.read_brackets(
            {"txt_code": "MSW-2026-2027"}, [FTL, second], finality=src.SETTLED
        )
        re_kept, re_skipped = src.read_schedule([FTL, second])
    final, not_final = lifecycle.split_final(re_kept)
    assert not_final == []
    assert schedule_sha256(final, re_skipped) == schedule_sha256(kept, skipped)
    assert [s["uuid"] for s in skipped] == ["AT", "A2", "BT", "B2"]


# --------------------------------------------------------------------------
# ENGINE.01-03 — one contract for every engine
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("url", "engine", "signal"),
    [
        (FTL, "ftl", True),
        (ENGARDE_TOURNAMENT, "engarde", True),
        (FOURFENCE, "fourfence", False),
        (OPHARDT, "ophardt", False),
        (DARTAGNAN, "dartagnan", False),
        ("evf:85", "evf", False),
        (PAGE, "page", False),
        ("https://engarde-service.com/competition/evf/madrid2026/epeemale1", "page", False),
    ],
)
def test_ENGINE_01_every_engine_is_classified_and_says_whether_it_signals(url, engine, signal):
    from python.pipeline import international_sources as src

    assert src.engine_of(url) == engine
    assert src.ENGINES[engine].signal is signal


def test_ENGINE_01b_a_signalling_engine_marks_every_taken_bracket_finished():
    from python.pipeline import international_sources as src

    recs, kept, _ = src.read_brackets(
        {"txt_code": "PEW2efs-2026-2027"},
        [ENGARDE_TOURNAMENT],
        fetcher=_fetcher([_parsed(), _parsed("V2", url="https://e/2")], [RUNNING]),
        finality=src.Sightings(
            MagicMock(side_effect=AssertionError("no sighting")), now=NOW, ended=False
        ),
    )
    assert [k["finished"] for k in kept] == [True, True]
    assert [r["finished"] for r in recs] == [True, True]


def test_ENGINE_02_an_engine_without_a_signal_is_never_read_without_the_rule():
    from python.pipeline import international_sources as src

    with pytest.raises(ValueError, match="no finished signal"):
        src.read_brackets(
            {"txt_code": "PEW4efs-2026-2027"}, [OPHARDT], fetcher=_fetcher([_parsed()])
        )


def test_ENGINE_03_the_handbook_engine_table_lists_exactly_the_engines():
    from python.pipeline import international_sources as src

    page = (ROOT / "doc/handbook/reference/organizers-and-engines.html").read_text(encoding="utf-8")
    table = re.search(r'<table id="engines">(.*?)</table>', page, re.S)
    assert table, "the handbook page has no engine table"
    listed = set(re.findall(r'<tr data-engine="([a-z]+)"', table.group(1)))
    assert listed == set(src.ENGINES)
    for name, engine in src.ENGINES.items():
        row = re.search(rf'<tr data-engine="{name}"[^>]*data-signal="(yes|no)"', table.group(1))
        assert row and (row.group(1) == "yes") is engine.signal, name


def test_FINAL_08_the_sightings_never_enter_the_prod_seed():
    """The plan keeps the sightings on CERT (§04.2): the PROD seed export
    writes each table by name, so it must never name this one, and an export
    of an empty database carries no trace of it."""
    from unittest.mock import patch

    from python.pipeline import export_seed

    source = (ROOT / "python/pipeline/export_seed.py").read_text(encoding="utf-8")
    assert "listing_sighting" not in source

    def empty(_ref: str, _token: str, sql: str) -> list[dict]:
        if sql == export_seed.ROSTER_SQL:
            return [{"j": "[]"}]
        if sql == export_seed.SEQUENCE_SQL:
            return [{"j": "1"}]
        return []

    with patch.object(export_seed, "mgmt_query", side_effect=empty):
        dump = export_seed.export_monolithic("ref", "token")
    assert "tbl_season" in dump
    assert "listing_sighting" not in dump


def test_SYNC_SEED_01_the_results_sync_pauses_never_enter_the_prod_seed():
    """ADR-119 §4 (D8): the pause table is CERT's, as the sightings are; the
    export never names it, and an export carries no trace of it."""
    from unittest.mock import patch

    from python.pipeline import export_seed

    source = (ROOT / "python/pipeline/export_seed.py").read_text(encoding="utf-8")
    assert "results_sync" not in source

    def empty(_ref: str, _token: str, sql: str) -> list[dict]:
        if sql == export_seed.ROSTER_SQL:
            return [{"j": "[]"}]
        if sql == export_seed.SEQUENCE_SQL:
            return [{"j": "1"}]
        return []

    with patch.object(export_seed, "mgmt_query", side_effect=empty):
        dump = export_seed.export_monolithic("ref", "token")
    assert "tbl_season" in dump
    assert "results_sync" not in dump
