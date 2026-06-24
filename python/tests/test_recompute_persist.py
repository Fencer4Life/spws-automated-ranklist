"""Step C — RECOMPUTE_DOMESTIC live write-back (ADR-072).

Plan IDs N9.1–N9.7. Maps to FR-115 (self-healing recompute). Step A deferred the
recompute Commit (it recorded a `recompute_persist_deferred` marker without
writing). Step C makes `Commit` re-persist the recomputed partition: it groups the
loaded matches by (weapon, gender, governed-V-cat) — an event spans many
weapon/gender brackets, so V-cat alone would wrongly merge weapons — resolves each
bracket's tournament and re-writes it via the atomic RPC, and CLEARS brackets a
birth-year relocation emptied.

DB is mocked here (write contract); the live LOCAL heal is verified separately.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

from python.pipeline.core.contract import Context, Services
from python.pipeline.plugins.bridge import LEGACY
from python.pipeline.plugins.ingest import Commit
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult


def _m(id_fencer, place, by, weapon="EPEE", gender="M"):
    return StageMatchResult(
        scraped_name=str(id_fencer),
        place=place,
        id_fencer=id_fencer,
        confidence=100.0,
        method="AUTO_MATCHED",
        governed_birth_year=by,
        weapon=weapon,
        gender=gender,
        tournament_date=date(2026, 2, 21),
    )


def _db(existing_tournaments=None):
    db = MagicMock()
    db.find_or_create_tournament.side_effect = range(300, 360)
    db.ingest_results.return_value = {"ok": True}
    db.fetch_event_tournaments.return_value = existing_tournaments or []
    return db


def _ctx(matches, *, id_event=7, season=2026, event_code="PPW4-2025-2026"):
    """Recompute-shaped Context: parsed=None, matches carry weapon/gender/BY."""
    ctx = Context()
    pctx = PipelineContext(
        parsed=None, overrides=Overrides(), season_end_year=season, event_code=event_code
    )
    pctx.event = {"id_event": id_event, "txt_code": event_code}
    pctx.matches = matches
    # AssignFinalVcat would have populated vcat_groups; Commit-recompute ignores
    # it (re-partitions from matches), but set it so the shape mirrors the flow.
    pctx.vcat_groups = {}
    ctx.data[LEGACY] = pctx
    ctx.data["event"] = pctx.event
    ctx.data["matches"] = matches
    ctx.data["final_vcats"] = {}
    return ctx


def _run(ctx, db):
    p = Commit()
    ctx._begin(p)
    p.run(ctx, Services(db=db))
    ctx._end()
    return ctx


class TestRecomputePersist:
    def test_partitions_by_weapon_gender_vcat(self):
        """N9.1 epee-M and foil-M of the same V-cat are SEPARATE tournaments —
        weapon/gender are part of the bracket key, not just V-cat."""
        matches = [_m(1, 1, 1980, weapon="EPEE"), _m(2, 1, 1982, weapon="FOIL")]
        db = _db()
        _run(_ctx(matches), db)
        weapons = sorted(c.args[1] for c in db.find_or_create_tournament.call_args_list)
        assert weapons == ["EPEE", "FOIL"]
        assert db.find_or_create_tournament.call_count == 2

    def test_relocates_to_new_vcat_bracket(self):
        """N9.2 a corrected BY (now V3) is written into the V3 bracket; the
        co-bracket V2 fencer stays in V2 — two brackets, own counts."""
        matches = [
            _m(1, 2, 1970, weapon="EPEE"),  # age 56 -> V2
            _m(2, 1, 1960, weapon="EPEE"),
        ]  # age 66 -> V3 (relocated)
        db = _db()
        _run(_ctx(matches), db)
        vcats = {
            c.args[3]: c.kwargs.get("participant_count")
            for c in db.find_or_create_tournament.call_args_list
        }
        assert set(vcats) == {"V2", "V3"}
        # one fencer per bracket -> participant_count 1 each (own count)
        ing = {c.args[0]: c.kwargs["participant_count"] for c in db.ingest_results.call_args_list}
        assert sorted(ing.values()) == [1, 1]

    def test_committed_mode_recompute(self):
        """N9.3 committed reports persisted=True + mode=recompute."""
        db = _db()
        ctx = _run(_ctx([_m(1, 1, 1980)]), db)
        committed = ctx.get("committed")
        assert committed["skipped"] is False
        assert committed["persisted"] is True
        assert committed["mode"] == "recompute"

    def test_clears_emptied_bracket(self):
        """N9.4 a bracket a relocation emptied (existing tournament not in the new
        partition) is cleared via clear_tournament_results."""
        # new partition only writes V3-EPEE-M; the pre-existing V2-EPEE-M (id 99)
        # is now empty and must be cleared.
        matches = [_m(2, 1, 1960, weapon="EPEE")]  # -> V3 only
        db = _db(
            existing_tournaments=[
                {
                    "id_tournament": 99,
                    "enum_weapon": "EPEE",
                    "enum_gender": "M",
                    "enum_age_category": "V2",
                },
            ]
        )
        _run(_ctx(matches), db)
        db.clear_tournament_results.assert_called_once_with(99)

    def test_rewritten_bracket_not_cleared(self):
        """N9.5 a bracket that IS in the new partition is rewritten, never cleared
        (matched by weapon/gender/V-cat, not tournament id)."""
        matches = [_m(2, 1, 1960, weapon="EPEE")]  # -> V3-EPEE-M
        db = _db(
            existing_tournaments=[
                {
                    "id_tournament": 88,
                    "enum_weapon": "EPEE",
                    "enum_gender": "M",
                    "enum_age_category": "V3",
                },
            ]
        )
        _run(_ctx(matches), db)
        db.clear_tournament_results.assert_not_called()

    def test_row_shape_and_status(self):
        """N9.6 recompute rows carry the RPC shape; loaded AUTO_MATCHED stays
        AUTO_MATCHED (the fencer is already FK-linked)."""
        db = _db()
        _run(_ctx([_m(5, 1, 1980)]), db)
        (_, rows), kwargs = db.ingest_results.call_args
        assert rows[0] == {
            "id_fencer": 5,
            "int_place": 1,
            "txt_scraped_name": "5",
            "num_confidence": 100.0,
            "enum_match_status": "AUTO_MATCHED",
        }

    def test_rows_without_governed_by_skipped(self):
        """N9.7 a loaded row with no governed BY can't be placed in a V-cat — it is
        skipped (not crashed); other rows still commit."""
        matches = [_m(1, 1, None), _m(2, 2, 1980)]
        db = _db()
        ctx = _run(_ctx(matches), db)
        # only the BY-known fencer's bracket is written
        assert db.find_or_create_tournament.call_count == 1
        assert ctx.get("committed")["persisted"] is True
