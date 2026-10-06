"""PZSz admission — surname, first name and birth year; nothing else (ADR-111).

RTM PZSZ.ADM.01–08. A PZSz (PPS, MPS) row is kept only when exactly one
fencer in the fencer table matches its surname, its first name and the birth
year from the PZSz start list. Everything else is skipped: no fencer is
created, no alias written, no birth year changed and nothing queued for
review. Nobody matched: nothing is written at all.

The names are synthetic. The namesake case mirrors Poznań (6 October 2026):
a junior born 2008 on the start list, and our veteran of the same name born
1976.
"""

from __future__ import annotations

import ast
from datetime import date
from pathlib import Path
from unittest.mock import MagicMock

from python.pipeline.core.contract import Context, Services
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.plugins.bridge import ensure_pctx
from python.pipeline.plugins.pzsz_admission import (
    SKIPPED,
    STORED,
    AdmitPzszRoster,
    admit,
    start_list_years,
)
from python.pipeline.plugins.pzsz_commit import CommitPzszSenior
from python.pipeline.types import Overrides
from python.scrapers.pzsz_start_list import Starter

PLUGIN_SOURCE = Path(__file__).resolve().parents[1] / "pipeline" / "plugins" / "pzsz_admission.py"


def _fencer(id_, surname, first, by, *, estimated=False, aliases=()):
    return {
        "id_fencer": id_,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
        "txt_nationality": "POL",
        "enum_gender": "M",
        "json_name_aliases": list(aliases),
    }


def _starter(name, year):
    return Starter(name, date(year, 6, 1))


def _years(*starters):
    return start_list_years(starters)


# ---------------------------------------------------------------------------
# admit() — one row
# ---------------------------------------------------------------------------


class TestAdmit:
    def test_exact_identity_is_stored(self):
        """PZSZ.ADM.01: one roster fencer with this surname, first name and
        the start list's birth year is stored."""
        roster = [_fencer(101, "WZORCOWY", "Jan", 1971)]
        a = admit("WZORCOWY Jan", years=_years(_starter("Wzorcowy Jan", 1971)), roster=roster)
        assert (a.decision, a.id_fencer, a.birth_year) == (STORED, 101, 1971)

    def test_a_namesake_with_another_birth_year_is_skipped(self):
        """PZSZ.ADM.02: the Poznań case — the start list's junior (2008) is
        not our veteran (1976). Skipped, and the namesake is named."""
        roster = [_fencer(156, "PRÓBNY", "Jakub", 1976)]
        a = admit("PRÓBNY Jakub", years=_years(_starter("Próbny Jakub", 2008)), roster=roster)
        assert (a.decision, a.id_fencer) == (SKIPPED, None)
        assert a.namesakes == ((156, 1976),)
        assert "namesake" in a.reason

    def test_a_name_missing_from_the_start_list_is_skipped(self):
        """PZSZ.ADM.03: no start-list entry, no birth year, no admission."""
        roster = [_fencer(101, "WZORCOWY", "Jan", 1971)]
        a = admit("WZORCOWY Jan", years=_years(_starter("Inny Ktoś", 1971)), roster=roster)
        assert (a.decision, a.id_fencer) == (SKIPPED, None)
        assert "not on the start list" in a.reason

    def test_a_name_twice_on_the_start_list_is_skipped(self):
        """PZSZ.ADM.03: two starters print the same name; which birth year
        belongs to this row cannot be told."""
        roster = [_fencer(101, "WZORCOWY", "Jan", 1971)]
        years = _years(_starter("Wzorcowy Jan", 1971), _starter("WZORCOWY JAN", 2005))
        a = admit("WZORCOWY Jan", years=years, roster=roster)
        assert (a.decision, a.id_fencer) == (SKIPPED, None)
        assert "twice on the start list" in a.reason

    def test_two_roster_fencers_with_the_same_identity_are_skipped(self):
        """PZSZ.ADM.04: two fencers of ours share surname, first name and
        birth year — the row is not guessed onto either."""
        roster = [_fencer(101, "WZORCOWY", "Jan", 1971), _fencer(102, "Wzorcowy", "Jan", 1971)]
        a = admit("WZORCOWY Jan", years=_years(_starter("Wzorcowy Jan", 1971)), roster=roster)
        assert (a.decision, a.id_fencer) == (SKIPPED, None)
        assert "two fencers" in a.reason

    def test_nobody_of_that_name_is_skipped(self):
        """PZSZ.ADM.03: a starter who is not in the fencer table."""
        a = admit("OBCY Adam", years=_years(_starter("Obcy Adam", 1990)), roster=[])
        assert (a.decision, a.id_fencer) == (SKIPPED, None)
        assert "not in the fencer table" in a.reason

    def test_polish_letters_and_case_are_folded(self):
        """PZSZ.ADM.05: ŁĘGOWSKI Paweł on FTL, Łęgowski Paweł on the start
        list and Legowski Pawel in the roster are one identity."""
        roster = [_fencer(103, "Legowski", "Pawel", 1966)]
        a = admit("ŁĘGOWSKI Paweł", years=_years(_starter("Łęgowski Paweł", 1966)), roster=roster)
        assert (a.decision, a.id_fencer) == (STORED, 103)

    def test_an_approved_alias_does_not_count(self):
        """PZSZ.ADM.05 (Q4 A): only the canonical surname and first name."""
        roster = [_fencer(104, "WZORCOWY", "Jan", 1971, aliases=["ALIAS Jan"])]
        a = admit("ALIAS Jan", years=_years(_starter("Alias Jan", 1971)), roster=roster)
        assert (a.decision, a.id_fencer) == (SKIPPED, None)

    def test_an_estimated_roster_year_is_compared_exactly(self):
        """PZSZ.ADM.05 (Q3 A): our estimated 1970 against a printed 1971 is a
        mismatch, skipped and reported as a namesake."""
        roster = [_fencer(105, "WZORCOWY", "Jan", 1970, estimated=True)]
        a = admit("WZORCOWY Jan", years=_years(_starter("Wzorcowy Jan", 1971)), roster=roster)
        assert (a.decision, a.id_fencer) == (SKIPPED, None)
        assert a.namesakes == ((105, 1970),)
        assert "estimated" in a.reason


# ---------------------------------------------------------------------------
# AdmitPzszRoster — the plugin step, and CommitPzszSenior after it
# ---------------------------------------------------------------------------


def _parsed(rows, gender="M"):
    return ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[
            ParsedResult(source_row_id=f"r{place}", fencer_name=name, place=place)
            for name, place in rows
        ],
        parsed_date=date(2026, 10, 4),
        weapon="SABRE",
        gender=gender,
        organizer_hint="PZSz",
        season_end_year=2027,
    )


def _run(parsed, roster, start_list):
    db = MagicMock()
    db.fetch_fencer_db.return_value = roster
    db.find_or_create_tournament.return_value = 501
    ctx = Context()
    pctx = ensure_pctx(
        ctx,
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=2027,
        event_code="PPS1s-2026-2027",
    )
    event = {"id_event": 7, "txt_code": "PPS1s-2026-2027", "enum_type": "PPS"}
    pctx.event = event
    ctx.set("event", event)
    svc = Services(db=db, config={"start_list": start_list})
    for plugin in (AdmitPzszRoster(), CommitPzszSenior()):
        ctx._begin(plugin)
        try:
            plugin.run(ctx, svc)
        finally:
            ctx._end()
    return ctx, db


ROSTER = [
    _fencer(101, "WZORCOWY", "Jan", 1971),
    _fencer(156, "PRÓBNY", "Jakub", 1976),
]
START = [
    _starter("Szybki Adam", 2004),
    _starter("Próbny Jakub", 2008),
    _starter("Wzorcowy Jan", 1971),
]


class TestPluginAndCommit:
    def test_stored_row_keeps_its_place_and_the_whole_field_n(self):
        """PZSZ.ADM.01: the one stored veteran keeps place 3 of 3 and N is
        the whole field, written to one SENIOR tournament."""
        parsed = _parsed([("SZYBKI Adam", 1), ("PRÓBNY Jakub", 2), ("WZORCOWY Jan", 3)])
        _, db = _run(parsed, ROSTER, START)
        db.find_or_create_tournament.assert_called_once()
        assert db.find_or_create_tournament.call_args.args[3] == "SENIOR"
        db.set_tournament_participant_count.assert_called_once_with(501, 3)
        (_, rows), kwargs = db.ingest_results.call_args
        assert [(r["id_fencer"], r["int_place"]) for r in rows] == [(101, 3)]
        assert kwargs["participant_count"] == 3

    def test_the_report_lists_every_skipped_starter_namesakes_first(self):
        """PZSZ.ADM.02: the run report names each skipped row with its
        reason; a namesake comes before a stranger."""
        parsed = _parsed([("SZYBKI Adam", 1), ("PRÓBNY Jakub", 2), ("WZORCOWY Jan", 3)])
        ctx, _ = _run(parsed, ROSTER, START)
        (identity,) = [f for f in ctx.report if f.section == "IDENTITY"]
        skipped = identity.payload["skipped"]
        assert [s["scraped_name"] for s in skipped] == ["PRÓBNY Jakub", "SZYBKI Adam"]
        assert skipped[0]["namesakes"] == [{"id_fencer": 156, "birth_year": 1976}]
        assert skipped[0]["start_list_birth_year"] == 2008

    def test_nothing_is_created_linked_changed_or_queued(self):
        """PZSZ.ADM.06: no fencer, alias, birth-year change or review row,
        whatever the rows."""
        parsed = _parsed([("SZYBKI Adam", 1), ("PRÓBNY Jakub", 2), ("WZORCOWY Jan", 3)])
        ctx, db = _run(parsed, ROSTER, START)
        db.insert_fencer.assert_not_called()
        db.update_fencer_birth_year.assert_not_called()
        db.merge_fencers.assert_not_called()
        db.queue_pzsz_match_review.assert_not_called()
        # An alias is never written through the connector; it travels as a
        # write-back in the IDENTITY report, which must stay empty here.
        (identity,) = [f for f in ctx.report if f.section == "IDENTITY"]
        assert identity.payload["alias_writebacks"] == []
        assert identity.payload["created"] == []

    def test_nobody_matched_writes_nothing(self):
        """PZSZ.ADM.07 (Q2 A): no tournament, no participant count, no
        result — and the run says nothing was written."""
        parsed = _parsed([("SZYBKI Adam", 1), ("PRÓBNY Jakub", 2)])
        ctx, db = _run(parsed, ROSTER, START)
        db.find_or_create_tournament.assert_not_called()
        db.set_tournament_participant_count.assert_not_called()
        db.ingest_results.assert_not_called()
        committed = ctx.get("committed")
        assert committed["persisted"] is False
        assert committed["tournaments"] == []

    def test_a_run_without_a_start_list_refuses(self):
        """PZSZ.ADM.07: without a start list there is no birth year to
        compare, so the step stops rather than skipping everyone."""
        parsed = _parsed([("WZORCOWY Jan", 1)])
        try:
            _run(parsed, ROSTER, None)
        except AssertionError as exc:
            assert "start list" in str(exc)
        else:
            raise AssertionError("AdmitPzszRoster ran without a start list")


class TestIndependence:
    def test_shares_nothing_with_the_evf_admission(self):
        """PZSZ.ADM.08: the PZSz plugin began as a copy of the EVF admission
        and imports nothing from it, so a change on either side cannot alter
        the other."""
        tree = ast.parse(PLUGIN_SOURCE.read_text(encoding="utf-8"))
        imported = {
            node.module
            for node in ast.walk(tree)
            if isinstance(node, ast.ImportFrom) and node.module
        } | {
            alias.name
            for node in ast.walk(tree)
            if isinstance(node, ast.Import)
            for alias in node.names
        }
        assert not any("international_admission" in m for m in imported), imported
