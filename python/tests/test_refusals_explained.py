"""REFUSAL.SAY — every refusal the public log prints says what it means (ADR-119 G60 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G60.

The first source re-read (1 Nov 2026) printed "IMSW-2025-2026: refused /
ListingRefused (identity)", which reads as an FTL sign-in failure; the source
had been read and the identity step had refused a row (G59). Each refusal now
carries a summary that names no fencer (D12), and the re-read says which
sources it read:

  REFUSAL.SAY.01  an international PENDING refusal counts its rows and their reasons;
  REFUSAL.SAY.02  a reason that is not the admission's own is counted, never printed;
  REFUSAL.SAY.03  a joined-bracket refusal says which places;
  REFUSAL.SAY.04  a refusal without its own summary says what its kind means;
  REFUSAL.SAY.05  a source the reader refuses is a SourceRefused with its kind;
  REFUSAL.SAY.06  a SourceRefused passes the public error with its meaning;
  REFUSAL.SAY.07  the sync's pause reason says what the refusal means;
  REFUSAL.SAY.08  the re-read's reason: read and refused, refused unread, or failed;
  REFUSAL.SAY.09  the re-read records which sources it read, a refused read included;
  REFUSAL.SAY.10  the re-read's summary line and log say which sources were read.
"""

from __future__ import annotations

import datetime as dt
from types import SimpleNamespace

import pytest

from python.pipeline import source_regression as sr
from python.pipeline.core.contract import REFUSAL_MEANING, ListingRefused, SourceRefused
from python.pipeline.types import StageMatchResult

FTL = "https://www.fencingtimelive.com/tournaments/eventSchedule/" + "a" * 32


def _held(name, notes):
    return StageMatchResult(
        scraped_name=name, place=7, id_fencer=None, confidence=0.0, method="PENDING", notes=notes
    )


def _refuse_pending(*members):
    from python.pipeline.plugins.ingest import Commit

    pctx = SimpleNamespace(event={"txt_code": "MSW-2026-2027"})
    with pytest.raises(ListingRefused) as e:
        Commit._refuse_international_pending(pctx, {"V1": list(members)}, "SABRE", "M")
    return e.value


def test_REFUSAL_SAY_01_an_international_pending_refusal_counts_rows_and_reasons():
    e = _refuse_pending(
        _held("SEKOWSKI Maciej", "two roster fencers fit"),
        _held("KORONA Przemyslaw", "two roster fencers fit"),
        _held("NOWAK Jan", "no identity match"),
    )
    assert e.kind == "identity"
    assert e.public == (
        "3 row(s) fit no single roster fencer (two roster fencers fit: 2, no identity match: 1)"
    )
    assert "SEKOWSKI" in str(e)  # the run row and Telegram keep the names
    assert e.summary == e.public


def test_REFUSAL_SAY_02_a_reason_not_the_admissions_own_is_counted_never_printed():
    e = _refuse_pending(_held("NOWAK Jan", "NOWAK Jan 1970 or NOWAK Jan 1972"))
    assert e.public == "1 row(s) fit no single roster fencer (another reason: 1)"


def test_REFUSAL_SAY_03_a_joined_bracket_refusal_says_which_places():
    from python.pipeline.joined_brackets import listing_order

    with pytest.raises(ListingRefused) as e:
        listing_order([(1, "V1")], [1, 2])
    assert e.value.public == "place(s) [2] of the listing have no category"
    with pytest.raises(ListingRefused) as e:
        listing_order([(1, "V1"), (1, "V2")], [1, 1])
    assert e.value.public == "a joined listing repeats place(s) [1]"


def test_REFUSAL_SAY_04_a_refusal_without_a_summary_says_what_its_kind_means():
    assert ListingRefused("identity", "NOWAK Jan …").summary == "a row fits no single roster fencer"
    assert ListingRefused("joined_bracket", "…").summary == REFUSAL_MEANING["joined_bracket"]
    assert ListingRefused("something new", "…").summary == "something new"


def test_REFUSAL_SAY_05_a_source_the_reader_refuses_is_a_source_refusal():
    from python.pipeline import international_sources as src

    with pytest.raises(SourceRefused) as e:
        src.read_brackets({"txt_code": "PEW1f-2026-2027"}, [])
    assert isinstance(e.value, ValueError)  # a refusal stops the run, as it always did
    assert (e.value.kind, e.value.summary) == ("no_link", "no results link")

    with pytest.raises(SourceRefused) as e:
        src._refuse_uncategorised("Veterans Mixed Sabre", FTL, None)
    assert e.value.kind == "combined"
    assert e.value.summary == "a combined bracket (no single category): 'Veterans Mixed Sabre'"

    rec = {"weapon": "SABRE", "gender": "M", "cats": ["V1"], "url": FTL, "uuid": "u"}
    with pytest.raises(SourceRefused) as e:
        src._refuse_two_sources({"txt_code": "PEW9efs-2025-2026"}, [rec, dict(rec)])
    assert (e.value.kind, e.value.summary) == (
        "two_sources",
        "two sources for one bracket SABRE/M/V1",
    )


def test_REFUSAL_SAY_06_a_source_refusal_passes_the_public_error_with_its_meaning():
    from python.pipeline.promotion.results_sync import _error_type, public_error

    e = SourceRefused("combined", "International bracket 'X' (u) has no single source category")
    text = public_error(e)
    assert text == (
        "SourceRefused (a combined bracket (no single category)): "
        "International bracket 'X' (u) has no single source category"
    )
    assert _error_type(text) == "SourceRefused (a combined bracket (no single category))"


def test_REFUSAL_SAY_07_the_pause_reason_says_what_the_refusal_means():
    from python.pipeline.promotion import results_sync as rs

    reason = rs.refusal_reason
    assert reason({"kind": "identity", "listing": "Women's Foil V1", "public": "2 row(s) …"}) == (
        "identity, Women's Foil V1: 2 row(s) …"
    )
    # a run recorded before G60 has no summary: its kind's meaning stands in
    assert reason({"kind": "identity", "listing": "Women's Foil V1"}) == (
        "identity, Women's Foil V1: a row fits no single roster fencer"
    )
    assert reason({"kind": "nothing_final", "listing": None}) == (
        "nothing_final: no listing is final, and the event holds an earlier run's results"
    )


def test_REFUSAL_SAY_08_the_re_reads_reason_read_refused_unread_or_failed():
    from python.scrapers.ftl_auth import FtlAuthError

    e = ListingRefused("identity", "SEKOWSKI Maciej: two roster fencers fit", public="1 row(s) …")
    assert sr.public_reason(e) == "read, then refused (identity): 1 row(s) …"
    e.read_from = ("FencingTimeLive",)
    assert sr.public_reason(e) == "read from FencingTimeLive, then refused (identity): 1 row(s) …"
    assert sr.public_reason(SourceRefused("no_link", "Event 'X' has no result URL")) == (
        "refused before anything was written: no results link"
    )
    assert sr.public_reason(FtlAuthError("wrong password")) == (
        "failed: FtlAuthError: wrong password"
    )
    assert sr.public_reason(KeyError("KOWALSKI Jan")) == "failed: KeyError"


class _Db:
    def find_event_by_code(self, code):
        return {"txt_code": code, "url_event": FTL}


class _Transport:
    def fetch_json(self, sql):
        return [] if "jsonb_agg" in sql else "fp"


def _read(sources):
    from python.pipeline.ingest_cli import EventRead

    return EventRead("international", [], [], [], [], [], None, sources=sources)


def test_REFUSAL_SAY_09_the_re_read_records_which_sources_it_read(monkeypatch):
    from python.pipeline import ingest_cli
    from python.pipeline.promotion import plan

    sources = [{"slot": 1, "url": FTL}, {"slot": 2, "url": "evf:41"}]
    monkeypatch.setattr(ingest_cli, "read_event", lambda *a, **k: _read(sources))
    monkeypatch.setattr(plan, "plan_event", lambda *a, **k: SimpleNamespace(ops=[]))
    check = sr.check_event("IMSW-2025-2026", cert_db=_Db(), cert=_Transport(), prod=_Transport())
    assert (check.status, check.read_from) == (sr.EQUAL, ("EVF results", "FencingTimeLive"))

    def refuse(*a, **k):
        raise ListingRefused("identity", "SEKOWSKI Maciej: two roster fencers fit")

    monkeypatch.setattr(plan, "plan_event", refuse)
    with pytest.raises(ListingRefused) as e:
        sr.check_event("IMSW-2025-2026", cert_db=_Db(), cert=_Transport(), prod=_Transport())
    assert e.value.read_from == ("EVF results", "FencingTimeLive")


def test_REFUSAL_SAY_10_the_summary_and_log_say_which_sources_were_read(capsys):
    rows = [
        {"txt_code": c, "dt_start": "2026-03-01", "url_event": FTL}
        for c in ("IMSW-2025-2026", "IMEW-2025-2026", "PEW1f-2026-2027")
    ]

    def check(code):
        if code == "IMSW-2025-2026":
            e = ListingRefused("identity", "SEKOWSKI Maciej: two roster fencers fit")
            e.public, e.read_from = "1 row(s) fit no single roster fencer", ("FencingTimeLive",)
            raise e
        if code == "PEW1f-2026-2027":
            raise SourceRefused("no_link", "Event 'PEW1f-2026-2027' has no result URL")
        c = sr.verdict(code, [], "a", "a", disagreements=0)
        c.read_from = ("EVF results",)
        return c

    sent: list[str] = []
    sr.run(
        rows,
        dt.date(2026, 11, 2),
        manual=True,
        check=check,
        send=sent.append,
        store=lambda md, stamp: "regression/x.md",
        output=lambda **kw: None,
        stamp="x",
    )
    log = capsys.readouterr().out
    assert sent == [
        "🔎 Source re-read: 3 event(s), 1 equal; refused: IMSW-2025-2026, PEW1f-2026-2027; "
        "sources read: EVF results 1, FencingTimeLive 1. Upcoming: none"
    ]
    assert "  read from FencingTimeLive, then refused (identity): 1 row(s) fit no single" in log
    assert "  refused before anything was written: no results link" in log
    assert f"summary: {sent[0]}" in log
    assert "SEKOWSKI" not in log
