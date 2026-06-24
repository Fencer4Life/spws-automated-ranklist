"""M4 — RECOMPUTE_DOMESTIC + source retention (ADR-072).

Plan IDs N4.1–N4.6. Maps to FR-115 (self-healing recompute: re-derive V-cats +
re-score the affected EVENT from stored FK-linked results, no source/no re-match;
event-granular; boundary-crossing BY re-partitions) and FR-117 (source retention).
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline import run as run_module
from python.pipeline.core.contract import Context, Outcome, Services
from python.pipeline.engine.flows import Flow, FlowParams
from python.pipeline.plugins.recompute import LoadCommitted


def _db(event_results, by_map=None):
    db = MagicMock()
    db.fetch_event_results.return_value = event_results
    db.fetch_birth_years_batch.return_value = by_map or {
        r["id_fencer"]: r["int_birth_year"] for r in event_results
    }
    db.ingest_results.return_value = {"ok": True}
    return db


def _recompute(db, id_event=7, season=2026):
    cfg = {
        "id_event": id_event,
        "season_end_year": season,
        "event": {"id_event": id_event, "txt_code": "PPW4-2025-2026"},
    }
    return run_module.run_flow(
        FlowParams(Flow.RECOMPUTE_DOMESTIC, id_event=id_event), svc=Services(db=db, config=cfg)
    )


# ---------------------------------------------------------------------------
# LoadCommitted
# ---------------------------------------------------------------------------


class TestLoadCommitted:
    def test_builds_matches_from_stored_rows(self):
        """N4.1 LoadCommitted turns stored FK rows into matches w/ governed BY."""
        rows = [
            {"id_fencer": 1, "place": 1, "int_birth_year": 1980},
            {"id_fencer": 2, "place": 2, "int_birth_year": 1960},
        ]
        ctx = Context()
        p = LoadCommitted()
        ctx._begin(p)
        p.run(
            ctx,
            Services(
                db=_db(rows),
                config={
                    "id_event": 7,
                    "season_end_year": 2026,
                    "event": {"id_event": 7, "txt_code": "PPW4-2025-2026"},
                },
            ),
        )
        ctx._end()
        matches = ctx.get("matches")
        assert [(m.id_fencer, m.governed_birth_year, m.place) for m in matches] == [
            (1, 1980, 1),
            (2, 1960, 2),
        ]
        assert ctx.get("event")["txt_code"] == "PPW4-2025-2026"

    def test_aborts_without_id_event(self):
        """N4.1b no target event -> Abort (cannot recompute nothing)."""
        from python.pipeline.core.contract import Abort

        ctx = Context()
        p = LoadCommitted()
        ctx._begin(p)
        with pytest.raises(Abort):
            p.run(ctx, Services(db=_db([]), config={}))
        ctx._end()


# ---------------------------------------------------------------------------
# RECOMPUTE_DOMESTIC flow
# ---------------------------------------------------------------------------


class TestRecomputeFlow:
    def test_repartitions_by_governed_by(self):
        """N4.2 the flow re-derives V-cats from the corrected BY + reaches Commit."""
        rows = [
            {"id_fencer": 1, "place": 1, "int_birth_year": 1980},  # 46 -> V1
            {"id_fencer": 2, "place": 2, "int_birth_year": 1960},
        ]  # 66 -> V3
        ctx = _recompute(_db(rows))
        fv = ctx.get("final_vcats")
        assert set(fv.keys()) == {"V1", "V3"}
        assert ctx.trace.outcome_of("Commit") == Outcome.RAN
        assert ctx.get("committed")["skipped"] is False

    def test_validate_counts_robust_without_source(self):
        """N4.3 ValidateCounts skips source/URL checks on recompute, no spurious fault."""
        rows = [
            {"id_fencer": 1, "place": 1, "int_birth_year": 1980},
            {"id_fencer": 2, "place": 2, "int_birth_year": 1960},
        ]
        ctx = _recompute(_db(rows))
        assert ctx.trace.outcome_of("ValidateCounts") == Outcome.RAN
        assert ctx.faults == []

    def test_boundary_crossing_by_repartitions(self):
        """N4.4 a BY that now resolves to V3 lands the result in the V3 bracket."""
        rows = [{"id_fencer": 2, "place": 1, "int_birth_year": 1960}]  # was V2 (1970), now V3
        ctx = _recompute(_db(rows))
        fv = ctx.get("final_vcats")
        assert "V3" in fv and "V2" not in fv
        assert fv["V3"][0].id_fencer == 2

    def test_recompute_twice_equals_once(self):
        """N4.5 idempotence — recomputing twice yields the same partition."""
        rows = [
            {"id_fencer": 1, "place": 1, "int_birth_year": 1980},
            {"id_fencer": 2, "place": 2, "int_birth_year": 1960},
        ]
        db = _db(rows)
        a = _recompute(db).get("final_vcats")
        b = _recompute(db).get("final_vcats")

        def norm(fv):
            return {k: sorted(m.id_fencer for m in v) for k, v in fv.items()}

        assert norm(a) == norm(b)


# ---------------------------------------------------------------------------
# Source retention (BR-13 / FR-117)
# ---------------------------------------------------------------------------


class TestSourceRetention:
    def test_parse_source_retains_artifact_path(self):
        """N4.6 ParseSource stamps source_artifact_path so a dead-URL event can be
        re-ingested from retained bytes (source=retained)."""
        from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
        from python.pipeline.plugins.ingest import ParseSource

        parsed = ParsedTournament(
            source_kind=SourceKind.CERT_REF,
            results=[ParsedResult("t:1", "KOWALSKI Jan", 1, fencer_country="POL")],
            parsed_date=date(2026, 4, 1),
            weapon="EPEE",
            gender="M",
            organizer_hint="SPWS",
            category_hint="V1",
            season_end_year=2026,
        )
        ctx = Context()
        p = ParseSource()
        ctx._begin(p)
        p.run(
            ctx,
            Services(
                config={
                    "parsed": parsed,
                    "source": "retained",
                    "source_artifact_path": "/retained/ppw4.xml",
                    "season_end_year": 2026,
                    "event_code": "PPW4-2025-2026",
                }
            ),
        )
        ctx._end()
        assert parsed.source_artifact_path == "/retained/ppw4.xml"
        assert ctx.get("parsed") is parsed
