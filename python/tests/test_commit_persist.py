"""Step A — make `Commit` actually persist per V-cat bracket (ADR-014/022/049).

Plan IDs N7.1–N7.8. Maps to FR-112 (the Commit Mutator) + BR-6 (atomic, idempotent
re-import). Until now `Commit.run` called `db.ingest_results(pctx)` with the wrong
arguments and only "passed" because tests used a MagicMock DB — no row ever reached
`tbl_result`. These tests pin the REAL RPC contract: per V-cat bracket, resolve/create
the tournament and call `fn_ingest_tournament_results` via
`db.ingest_results(tournament_id, rows, participant_count)`.

The DB is mocked here (RPC-argument contract); the live LOCAL end-to-end write is
exercised separately (Step A acceptance, live pgTAP/manual).
"""
from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline.core.contract import Context, Services
from python.pipeline.plugins.bridge import LEGACY
from python.pipeline.plugins.ingest import Commit
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _match(id_fencer, place, name, method="AUTO_MATCHED", conf=100.0):
    return StageMatchResult(
        scraped_name=name, place=place, id_fencer=id_fencer,
        confidence=conf, method=method,
    )


def _db():
    db = MagicMock()
    # find_or_create_tournament returns a distinct id per V-cat so tests can
    # assert each ingest_results call is keyed to its own tournament.
    db.find_or_create_tournament.side_effect = [201, 202, 203, 204]
    db.ingest_results.return_value = {"ok": True}
    return db


def _ctx(final_vcats, *, parsed=True, event=None, skip=False, dropped=None):
    """Build a Context wired the way the flow hands it to Commit:
    public keys (matches/final_vcats/event) + the bridged `_legacy` pctx."""
    ctx = Context()
    ev = event or {"id_event": 7, "txt_code": "PPW3-2025-2026", "enum_type": "PPW"}
    parsed_obj = None
    if parsed:
        from python.pipeline.ir import ParsedTournament, SourceKind
        parsed_obj = ParsedTournament(
            source_kind=SourceKind.FENCINGTIME_XML, results=[],
            parsed_date=date(2026, 4, 1), weapon="EPEE", gender="M",
            category_hint="V1", season_end_year=2026,
        )
    pctx = PipelineContext(
        parsed=parsed_obj, overrides=Overrides(), season_end_year=2026,
        event_code="PPW3-2025-2026",
    )
    pctx.event = ev
    pctx.vcat_groups = final_vcats
    all_matches = [m for ms in final_vcats.values() for m in ms]
    pctx.matches = all_matches
    ctx.data[LEGACY] = pctx
    ctx.data["event"] = ev
    ctx.data["matches"] = all_matches
    ctx.data["final_vcats"] = final_vcats
    if skip:
        ctx.data["_skip_commit"] = True
        ctx.data["_dropped_brackets"] = dropped or []
    return ctx


def _run(ctx, db):
    plugin = Commit()
    ctx._begin(plugin)
    plugin.run(ctx, Services(db=db))
    ctx._end()
    return ctx


# ---------------------------------------------------------------------------
# Per-bracket persistence — the RPC contract
# ---------------------------------------------------------------------------

class TestPerBracketPersist:
    def test_one_tournament_per_vcat(self):
        """N7.1 a single-V-cat bracket -> find_or_create_tournament once with the
        event/weapon/gender/V-cat/date/type drawn from the parsed source."""
        fv = {"V1": [_match(101, 1, "KOWALSKI Jan"), _match(102, 2, "NOWAK Adam")]}
        db = _db()
        _run(_ctx(fv), db)
        db.find_or_create_tournament.assert_called_once_with(
            7, "EPEE", "M", "V1", "2026-04-01", "PPW", url_results=None)

    def test_ingest_rows_shape_and_count(self):
        """N7.2 ingest_results gets RPC-shaped rows + the bracket's OWN count as
        participant_count (ADR-049 amend: per-V-cat, never the summed pool)."""
        fv = {"V1": [_match(101, 1, "KOWALSKI Jan"), _match(102, 2, "NOWAK Adam")]}
        db = _db()
        _run(_ctx(fv), db)
        (tid, rows), kwargs = db.ingest_results.call_args
        assert tid == 201
        assert kwargs["participant_count"] == 2
        assert rows == [
            {"id_fencer": 101, "int_place": 1, "txt_scraped_name": "KOWALSKI Jan",
             "num_confidence": 100.0, "enum_match_status": "AUTO_MATCHED"},
            {"id_fencer": 102, "int_place": 2, "txt_scraped_name": "NOWAK Adam",
             "num_confidence": 100.0, "enum_match_status": "AUTO_MATCHED"},
        ]

    def test_method_maps_to_legacy_status(self):
        """N7.3 the new provenance vocabulary maps to the legacy enum_match_status
        the RPC casts (AUTO_CREATED->NEW_FENCER), or fn_ingest's enum cast fails."""
        fv = {"V1": [_match(101, 1, "NEW Person", method="AUTO_CREATED", conf=0.0)]}
        db = _db()
        _run(_ctx(fv), db)
        (_, rows), _ = db.ingest_results.call_args
        assert rows[0]["enum_match_status"] == "NEW_FENCER"

    def test_excluded_rows_not_persisted(self):
        """N7.4 EXCLUDED / unassigned (id_fencer is None) rows never reach the RPC."""
        fv = {"V1": [_match(101, 1, "KOWALSKI Jan"),
                     _match(None, 2, "FOREIGN Guest", method="EXCLUDED")]}
        db = _db()
        _run(_ctx(fv), db)
        (_, rows), kwargs = db.ingest_results.call_args
        assert [r["id_fencer"] for r in rows] == [101]
        assert kwargs["participant_count"] == 1

    def test_combined_pool_two_brackets_own_counts(self):
        """N7.5 a combined pool -> one tournament per V-cat, each scored on its OWN
        field size (ADR-049 amend), not the 3-fencer physical pool."""
        fv = {
            "V1": [_match(101, 1, "A A"), _match(102, 3, "B B")],
            "V3": [_match(103, 2, "C C")],
        }
        db = _db()
        _run(_ctx(fv), db)
        assert db.find_or_create_tournament.call_count == 2
        # map tournament_id (find_or_create return) -> V-cat (its 4th arg) ...
        vcat_of = {ret: c.args[3] for c, ret in
                   zip(db.find_or_create_tournament.call_args_list, [201, 202])}
        # ... then tournament_id -> participant_count from the ingest calls.
        counts = {vcat_of[c.args[0]]: c.kwargs["participant_count"]
                  for c in db.ingest_results.call_args_list}
        assert counts == {"V1": 2, "V3": 1}


# ---------------------------------------------------------------------------
# committed payload + remediation short-circuit
# ---------------------------------------------------------------------------

class TestCommittedPayload:
    def test_reports_persisted_tournaments(self):
        """N7.6 committed records persisted=True + the per-bracket tournament ids."""
        fv = {"V1": [_match(101, 1, "A A")], "V2": [_match(102, 1, "B B")]}
        db = _db()
        ctx = _run(_ctx(fv), db)
        committed = ctx.get("committed")
        assert committed["skipped"] is False
        assert committed["persisted"] is True
        assert {t["vcat"] for t in committed["tournaments"]} == {"V1", "V2"}

    def test_skip_commit_short_circuits(self):
        """N7.7 the `_skip_commit` remediation marker -> no DB writes, skipped=True."""
        fv = {"V1": [_match(101, 1, "A A")]}
        db = _db()
        ctx = _run(_ctx(fv, skip=True, dropped=["V0"]), db)
        db.find_or_create_tournament.assert_not_called()
        db.ingest_results.assert_not_called()
        assert ctx.get("committed") == {"skipped": True, "dropped": ["V0"]}

    def test_recompute_routes_to_recompute_path(self):
        """N7.8 RECOMPUTE (parsed=None) routes to the recompute write-back path
        (mode=recompute, Step C — see test_recompute_persist.py for its behavior),
        NOT the INGEST per-final_vcats loop. With matches carrying no governed BY
        there is nothing to place, so no rows are written, but it is not skipped."""
        fv = {"V1": [_match(101, 1, "1")]}  # _match sets no governed_birth_year
        db = _db()
        ctx = _run(_ctx(fv, parsed=False), db)
        db.ingest_results.assert_not_called()
        committed = ctx.get("committed")
        assert committed["skipped"] is False
        assert committed["mode"] == "recompute"


# ---------------------------------------------------------------------------
# N13.2 — commit_cats allow-set (overlap-clobber fix): a listing writes only the
# categories it was kept for; the rest are recorded as held (set-aside duplicate).
# ---------------------------------------------------------------------------

class TestCommitCatsAllowSet:
    def test_filters_to_commit_cats(self):
        """N13.2 with ctx.params['commit_cats'] present, Commit persists only those
        age-categories and records the rest as held (not written)."""
        fv = {"V0": [_match(101, 1, "A A")],
              "V1": [_match(102, 1, "B B")],
              "V2": [_match(103, 1, "C C")]}
        db = _db()
        ctx = _ctx(fv)
        ctx.params = {"commit_cats": {"V0", "V2"}}
        _run(ctx, db)
        assert db.find_or_create_tournament.call_count == 2          # V0, V2 only
        committed = ctx.get("committed")
        assert {t["vcat"] for t in committed["tournaments"]} == {"V0", "V2"}
        assert committed["held"] == ["V1"]                           # set-aside, not written

    def test_absent_commit_cats_writes_all(self):
        """N13.2 with no commit_cats (file/XML path), Commit writes every V-cat — unchanged."""
        fv = {"V0": [_match(101, 1, "A A")], "V1": [_match(102, 1, "B B")]}
        db = _db()
        ctx = _run(_ctx(fv), db)
        assert db.find_or_create_tournament.call_count == 2
        assert ctx.get("committed").get("held", []) == []
