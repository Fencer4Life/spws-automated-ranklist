"""Design step 6 — PZSz senior result ingestion (ADR-100).

RTM SS26.PZSZ.01/03/04/06/07/10 (the pipeline/orchestration IDs; the
SQL-reachable ones — 02/05/08/09 — are pgTAP,
supabase/tests/81_pzsz_senior_ingestion.sql).

Reuses the existing FTL parser and orchestration contracts (design §07 item
1) — nothing here parses FTL data a second way. What is new: a third
ResolveFencers intake policy (exact/alias-only, uncertain -> review, never
auto-create) and a SENIOR-shaped commit (one tournament per weapon/gender,
full source field size, original places).
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

from python.matcher.fuzzy_match import MatchResult
from python.pipeline.core.contract import Context, Services
from python.pipeline.db_connector import derive_tourn_type_from_event_code
from python.pipeline.plugins import resolve_fencers as rf
from python.pipeline.plugins.bridge import LEGACY, ensure_pctx
from python.pipeline.plugins.pzsz_commit import CommitPzszSenior
from python.pipeline.stages import _organizer_for_event
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult

# ---------------------------------------------------------------------------
# derive_tourn_type_from_event_code / _organizer_for_event -- pure functions
# ---------------------------------------------------------------------------


class TestPzszCodeRecognition:
    def test_pps_with_round_and_weapon(self):
        assert derive_tourn_type_from_event_code("PPS4e-2025-2026") == "PPS"

    def test_pps_gender_split(self):
        assert derive_tourn_type_from_event_code("PPS4We-2025-2026") == "PPS"

    def test_pps_multi_digit_round(self):
        assert derive_tourn_type_from_event_code("PPS10efs-2026-2027") == "PPS"

    def test_mps_no_round(self):
        assert derive_tourn_type_from_event_code("MPS-2025-2026") == "MPS"

    def test_mps_gender_split_with_weapon(self):
        assert derive_tourn_type_from_event_code("MPSWe-2025-2026") == "MPS"

    def test_pps_without_round_digits_is_unrecognized(self):
        # A round numeral is mandatory for PPS (unlike MPS) -- matches
        # pzsz_calendar.py's own PzszSourceDataError for a nameless round.
        assert derive_tourn_type_from_event_code("PPSe-2025-2026") is None

    def test_organizer_for_pps_event(self):
        assert _organizer_for_event({"txt_code": "PPS4e-2025-2026"}) == "PZSz"

    def test_organizer_for_mps_event(self):
        assert _organizer_for_event({"txt_code": "MPS-2025-2026"}) == "PZSz"


# ---------------------------------------------------------------------------
# ResolveFencers, intake="PZSZ_SENIOR"
# ---------------------------------------------------------------------------


def _result(name, place=1, country="POL"):
    from python.pipeline.ir import ParsedResult

    return ParsedResult(
        source_row_id=f"t:{name}:{place}", fencer_name=name, place=place, fencer_country=country
    )


def _parsed(results, gender="M", weapon="EPEE"):
    from python.pipeline.ir import ParsedTournament, SourceKind

    return ParsedTournament(
        source_kind=SourceKind.FTL,
        results=results,
        parsed_date=date(2026, 9, 1),
        weapon=weapon,
        gender=gender,
        organizer_hint="PZSz",
        season_end_year=2027,
    )


def _fencer(id_, surname, first, by, gender="M"):
    return {
        "id_fencer": id_,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": False,
        "txt_nationality": "POL",
        "enum_gender": gender,
        "json_name_aliases": [],
    }


def _db(fencer_db):
    db = MagicMock()
    db.fetch_fencer_db.return_value = fencer_db
    return db


def _resolve(parsed, fencer_db, *, db=None):
    ctx = Context()
    pctx = ensure_pctx(
        ctx,
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=2027,
        event_code="PPS4e-2026-2027",
    )
    pctx.event = {"txt_code": "PPS4e-2026-2027", "enum_type": "PPS"}
    plugin = rf.ResolveFencers()
    ctx.params = {"intake": "PZSZ_SENIOR"}
    ctx._begin(plugin)
    try:
        plugin.run(ctx, Services(db=db or _db(fencer_db)))
    finally:
        ctx._end()
    return ctx, pctx


class TestPzszSeniorIntake:
    def test_exact_match_auto_links(self):
        """SS26.PZSZ.04 an exact name match auto-links, same as domestic."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1965)]  # veteran, exact name
        ctx, _ = _resolve(_parsed([_result("KOWALSKI Jan")]), fdb)
        (m,) = ctx.get("matches")
        assert (m.id_fencer, m.method) == (101, "AUTO_MATCHED")

    def test_alias_match_auto_links(self):
        """SS26.PZSZ.04 an approved alias also auto-links (Phase A, unchanged)."""
        fencer = _fencer(101, "KOWALSKI", "Jan", 1965)
        fencer["json_name_aliases"] = ["KOWALSKI J."]
        ctx, _ = _resolve(_parsed([_result("KOWALSKI J.")]), [fencer])
        (m,) = ctx.get("matches")
        assert (m.id_fencer, m.method) == (101, "AUTO_MATCHED")

    def test_uncertain_fuzzy_match_is_pending_not_linked(self, monkeypatch):
        """SS26.PZSZ.05 a fuzzy-but-uncertain candidate is PENDING, not linked
        and not created -- id_fencer stays None, the candidate rides along in
        `alternatives` for CommitPzszSenior to queue."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1965)]
        monkeypatch.setattr(
            rf,
            "find_best_match",
            lambda *a, **k: MatchResult(
                scraped_name="KOWAL Jan", id_fencer=101, confidence=60.0, status="PENDING"
            ),
        )
        ctx, _ = _resolve(_parsed([_result("KOWAL Jan")]), fdb)
        (m,) = ctx.get("matches")
        assert m.method == "PENDING"
        assert m.id_fencer is None
        assert m.alternatives == [{"id_fencer": 101, "name": None, "confidence": 60.0}]

    def test_no_candidate_is_excluded_not_created(self, monkeypatch):
        """SS26.PZSZ.06/07 no plausible candidate at all -> EXCLUDED (dropped),
        never AUTO_CREATED -- the opposite of the domestic policy for the same
        shape of row."""
        monkeypatch.setattr(
            rf,
            "find_best_match",
            lambda *a, **k: MatchResult(
                scraped_name="NOBODY Known", id_fencer=None, confidence=0.0, status="UNMATCHED"
            ),
        )
        ctx, pctx = _resolve(_parsed([_result("NOBODY Known")]), [])
        (m,) = ctx.get("matches")
        assert m.method == "EXCLUDED"
        assert m.id_fencer is None
        assert not pctx.created_fencers  # SS26.PZSZ.07: nothing was ever created

    def test_never_auto_creates_even_where_domestic_would(self, monkeypatch):
        """SS26.PZSZ.07, contrastive: the identical PENDING-status match that
        domestic's own test suite (test_resolve_fencers.py) proves creates a
        new fencer must NOT create one under PZSZ_SENIOR intake."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1980)]
        monkeypatch.setattr(
            rf,
            "find_best_match",
            lambda *a, **k: MatchResult(
                scraped_name="KOWAL Jan", id_fencer=101, confidence=80.0, status="PENDING"
            ),
        )
        db = _db(fdb)
        ctx, pctx = _resolve(_parsed([_result("KOWAL Jan")]), fdb, db=db)
        (m,) = ctx.get("matches")
        assert m.method == "PENDING"
        db.insert_fencer.assert_not_called()
        assert not pctx.created_fencers


# ---------------------------------------------------------------------------
# CommitPzszSenior
# ---------------------------------------------------------------------------


def _match(id_fencer, place, name, method="AUTO_MATCHED", conf=100.0, gby=None, alternatives=None):
    return StageMatchResult(
        scraped_name=name,
        place=place,
        id_fencer=id_fencer,
        confidence=conf,
        method=method,
        governed_birth_year=gby,
        alternatives=alternatives or [],
    )


def _commit_ctx(matches, *, event=None, raw_pool_size=None):
    from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind

    ctx = Context()
    ev = event or {"id_event": 7, "txt_code": "PPS4e-2026-2027", "enum_type": "PPS"}
    n = raw_pool_size if raw_pool_size is not None else len(matches)
    parsed_obj = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[
            ParsedResult(source_row_id=f"filler:{i}", fencer_name=f"Filler {i}", place=i + 1)
            for i in range(n)
        ],
        parsed_date=date(2026, 9, 1),
        weapon="EPEE",
        gender="M",
        season_end_year=2027,
    )
    pctx = PipelineContext(
        parsed=parsed_obj, overrides=Overrides(), season_end_year=2027, event_code="PPS4e-2026-2027"
    )
    pctx.event = ev
    pctx.matches = matches
    ctx.data[LEGACY] = pctx
    ctx.data["event"] = ev
    ctx.data["matches"] = matches
    return ctx


def _commit_db():
    db = MagicMock()
    db.find_or_create_tournament.return_value = 501
    db.ingest_results.return_value = {"ok": True}
    db.queue_pzsz_match_review.return_value = 9001
    return db


def _run_commit(ctx, db):
    plugin = CommitPzszSenior()
    ctx._begin(plugin)
    plugin.run(ctx, Services(db=db))
    ctx._end()
    return ctx


class TestCommitPzszSenior:
    def test_one_tournament_labeled_senior(self):
        """SS26.TYPE.06e / the design's own architecture: one SENIOR
        tournament per (weapon, gender), not per V-cat."""
        matches = [_match(101, 34, "KOWALSKI Jan", gby=1965)]
        db = _commit_db()
        _run_commit(_commit_ctx(matches, raw_pool_size=107), db)
        db.find_or_create_tournament.assert_called_once_with(
            7, "EPEE", "M", "SENIOR", "2026-09-01", "PPS", url_results=None
        )

    def test_participant_count_is_full_source_field(self):
        """SS26.PZSZ.02/03 the 34-of-107 invariant: participant_count is the
        full parsed field, set directly and unconditionally -- not the
        written-row count."""
        matches = [_match(101, 34, "KOWALSKI Jan", gby=1965)]
        db = _commit_db()
        _run_commit(_commit_ctx(matches, raw_pool_size=107), db)
        db.set_tournament_participant_count.assert_called_once_with(501, 107)
        _, kwargs = db.ingest_results.call_args
        assert kwargs["participant_count"] == 107

    def test_original_place_never_renumbered(self):
        """SS26.PZSZ.03 place 34 stays 34, never renumbered to a bracket-
        relative rank (no _rerank_places call in this plugin at all)."""
        matches = [_match(101, 34, "KOWALSKI Jan", gby=1965)]
        db = _commit_db()
        _run_commit(_commit_ctx(matches, raw_pool_size=107), db)
        (_, rows), _ = db.ingest_results.call_args
        assert rows[0]["int_place"] == 34

    def test_each_row_carries_its_own_vcat(self):
        """SS26.PZSZ.08 enum_source_age_category is the fencer's own
        season-derived V-cat (2027 - 1965 = 62 -> V3), independent of the
        tournament's SENIOR label."""
        matches = [_match(101, 1, "KOWALSKI Jan", gby=1965)]
        db = _commit_db()
        _run_commit(_commit_ctx(matches), db)
        (_, rows), _ = db.ingest_results.call_args
        assert rows[0]["enum_source_age_category"] == "V3"

    def test_participant_count_set_even_with_zero_matched_rows(self):
        """A bracket where every row is PENDING/EXCLUDED still needs its full
        field size recorded -- fn_ingest_tournament_results refuses an empty
        results array, so ingest_results must never be the only place
        participant_count gets set."""
        matches = [
            _match(
                None,
                1,
                "Uncertain Name",
                method="PENDING",
                alternatives=[{"id_fencer": 9, "name": "X", "confidence": 60.0}],
            )
        ]
        db = _commit_db()
        _run_commit(_commit_ctx(matches, raw_pool_size=107), db)
        db.set_tournament_participant_count.assert_called_once_with(501, 107)
        db.ingest_results.assert_not_called()

    def test_pending_match_is_queued_not_written(self):
        """SS26.PZSZ.05 a PENDING match writes no tbl_result row -- it is
        queued for review with its candidate and confidence carried over."""
        matches = [
            _match(
                None,
                12,
                "Uncertain Name",
                method="PENDING",
                conf=62.5,
                alternatives=[{"id_fencer": 55, "name": "REAL Name", "confidence": 62.5}],
            )
        ]
        db = _commit_db()
        _run_commit(_commit_ctx(matches, raw_pool_size=107), db)
        db.queue_pzsz_match_review.assert_called_once_with(501, "Uncertain Name", 12, 55, 62.5)
        db.ingest_results.assert_not_called()

    def test_excluded_match_is_dropped_entirely(self):
        """A genuine non-match (EXCLUDED) is neither written nor queued."""
        matches = [_match(None, 5, "Nobody Known", method="EXCLUDED")]
        db = _commit_db()
        _run_commit(_commit_ctx(matches, raw_pool_size=107), db)
        db.queue_pzsz_match_review.assert_not_called()
        db.ingest_results.assert_not_called()


# ---------------------------------------------------------------------------
# Flow/Rule registration
# ---------------------------------------------------------------------------


class TestPzszFlowRegistration:
    def test_flow_resolves_to_a_valid_dag(self):
        """SS26.PZSZ.01: the flow exists, is planned from the real rulebook +
        plugin registry (not a test double), and validates as a DAG."""
        from python.pipeline.engine.flows import Flow, FlowParams
        from python.pipeline.engine.rule_engine import RuleEngine
        from python.pipeline.engine.rulebook import PLUGINS, RULEBOOK

        plan = RuleEngine(RULEBOOK, PLUGINS).plan(FlowParams(Flow.INGEST_PZSZ_SENIOR))
        assert plan.names == [
            "ParseSource",
            "ValidateIR",
            "ResolveEvent",
            "ResolveFencers",
            "ValidateCounts",
            "CommitPzszSenior",
        ]

    def test_reuses_the_ftl_parser_not_a_second_one(self):
        """SS26.PZSZ.01: the PZSz flow's ParseSource step is the SAME plugin
        instance INGEST_DOMESTIC uses -- there is no PZSz-specific parser
        anywhere in the registry."""
        from python.pipeline.engine.flows import Flow
        from python.pipeline.engine.rulebook import PLUGINS, RULEBOOK

        domestic_parse = next(
            s for s in RULEBOOK[Flow.INGEST_DOMESTIC].steps if s.plugin == "ParseSource"
        )
        pzsz_parse = next(
            s for s in RULEBOOK[Flow.INGEST_PZSZ_SENIOR].steps if s.plugin == "ParseSource"
        )
        assert domestic_parse.plugin == pzsz_parse.plugin
        assert PLUGINS[domestic_parse.plugin] is PLUGINS[pzsz_parse.plugin]
