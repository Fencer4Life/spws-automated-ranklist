"""M3 — ResolveFencers two-phase merge + governed-BY split (ADR-070, design §5.1).

Plan IDs N3.1–N3.9. Maps to FR-113 (ADR-070: merged early auto-resolution, no
human gate) and the governed-BY consumption by DetectCombinedPool/SplitByAge.

Covers the design §10 step-3 test list: exact-link / fuzzy-link / create /
reconcile-BY / two-phase BY settling / split-uses-governed-BY / calibration
(false-link bound via the AUTO_LINK_THRESHOLD policy).
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

from python.matcher.fuzzy_match import MatchResult
from python.matcher.pipeline import estimate_birth_year
from python.pipeline.core.contract import Context, Services
from python.pipeline.plugins import resolve_fencers as rf
from python.pipeline.plugins.bridge import ensure_pctx
from python.pipeline.plugins.ingest import DetectCombinedPool, SplitByAge
from python.pipeline.types import Overrides, StageMatchResult

V1_MID = estimate_birth_year("V1", 2026)
V3_MID = estimate_birth_year("V3", 2026)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _result(name, place=1, country="POL", raw_age_marker=None):
    from python.pipeline.ir import ParsedResult

    return ParsedResult(
        source_row_id=f"t:{name}:{place}",
        fencer_name=name,
        place=place,
        fencer_country=country,
        raw_age_marker=raw_age_marker,
    )


def _parsed(results, category_hint="V1"):
    from python.pipeline.ir import ParsedTournament, SourceKind

    return ParsedTournament(
        source_kind=SourceKind.CERT_REF,
        results=results,
        parsed_date=date(2026, 4, 1),
        weapon="EPEE",
        gender="M",
        organizer_hint="SPWS",
        category_hint=category_hint,
        season_end_year=2026,
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


def _db(fencer_db, next_id=500):
    db = MagicMock()
    db.fetch_fencer_db.return_value = fencer_db
    seq = iter(range(next_id, next_id + 100))
    db.insert_fencer.side_effect = lambda payload: next(seq)
    return db


def _resolve(parsed, fencer_db, *, db=None, config=None, season=2026):
    ctx = Context()
    pctx = ensure_pctx(
        ctx,
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=season,
        event_code="PPW3-2025-2026",
    )
    pctx.event = {"txt_code": "PPW3-2025-2026", "enum_type": "PPW"}
    plugin = rf.ResolveFencers()
    ctx._begin(plugin)
    try:
        plugin.run(ctx, Services(db=db or _db(fencer_db), config=config or {}))
    finally:
        ctx._end()
    return ctx, pctx


# ---------------------------------------------------------------------------
# Phase A — exact + reconcile
# ---------------------------------------------------------------------------


class TestExactAndReconcile:
    def test_exact_link(self):
        """N3.1 a known fencer (exact, BY-consistent) -> AUTO_MATCHED, governed BY."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1980)]  # age 46 @2026 -> V1, consistent
        ctx, _ = _resolve(_parsed([_result("KOWALSKI Jan")]), fdb)
        (m,) = ctx.get("matches")
        assert (m.id_fencer, m.method) == (101, "AUTO_MATCHED")
        assert m.governed_birth_year == 1980

    def test_reconcile_by_to_band_midpoint(self):
        """N3.2 exact match whose stored BY conflicts with the bracket V-cat ->
        reconcile to band midpoint; governed BY is the reconciled value."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1970)]  # age 56 -> V2, conflicts V1 bracket
        db = _db(fdb)
        ctx, pctx = _resolve(_parsed([_result("KOWALSKI Jan")]), fdb, db=db)
        (m,) = ctx.get("matches")
        assert m.id_fencer == 101 and m.method == "AUTO_MATCHED"
        assert m.governed_birth_year == V1_MID
        db.update_fencer_birth_year.assert_called_once_with(101, V1_MID, estimated=True)
        assert pctx.reconciled_fencers and pctx.reconciled_fencers[0]["new_birth_year"] == V1_MID


# ---------------------------------------------------------------------------
# Phase B — fuzzy link-or-create
# ---------------------------------------------------------------------------


class TestFuzzyLinkOrCreate:
    def test_create_on_no_match(self):
        """N3.3 a genuinely new name -> AUTO_CREATED at band-midpoint BY (ADR-020)."""
        ctx, pctx = _resolve(_parsed([_result("ZIELINSKI Nowy")]), [])
        (m,) = ctx.get("matches")
        assert m.method == "AUTO_CREATED" and m.id_fencer == 500
        assert m.governed_birth_year == V1_MID
        assert pctx.created_fencers and pctx.created_fencers[0]["id_fencer"] == 500

    def test_fuzzy_link_above_threshold(self, monkeypatch):
        """N3.4 a high-confidence fuzzy match (AUTO_MATCHED status) -> link + alias."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1980)]
        monkeypatch.setattr(
            rf,
            "find_best_match",
            lambda *a, **k: MatchResult(
                scraped_name="KOWALSKII Jan", id_fencer=101, confidence=97.0, status="AUTO_MATCHED"
            ),
        )
        db = _db(fdb)
        db.update_fencer_aliases = MagicMock()
        ctx, _ = _resolve(_parsed([_result("KOWALSKII Jan")]), fdb, db=db)
        (m,) = ctx.get("matches")
        assert (m.id_fencer, m.method) == (101, "AUTO_MATCHED")
        db.update_fencer_aliases.assert_called_once_with(101, ["KOWALSKII Jan"])

    def test_two_phase_by_settles_before_fuzzy(self, monkeypatch):
        """N3.5 Phase A reconciles the roster BY before Phase B fuzzy reads it."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1970)]  # wrong BY (V2), bracket is V1
        # row1 exact-matches + reconciles to V1 midpoint; row2 fuzzy-links to 101
        monkeypatch.setattr(
            rf,
            "find_best_match",
            lambda *a, **k: MatchResult(
                scraped_name="KOWALSKII Jan", id_fencer=101, confidence=96.0, status="AUTO_MATCHED"
            ),
        )
        ctx, _ = _resolve(_parsed([_result("KOWALSKI Jan", 1), _result("KOWALSKII Jan", 2)]), fdb)
        m_exact, m_fuzzy = ctx.get("matches")
        # both carry the settled (reconciled) BY — Phase A ran before Phase B
        assert m_exact.governed_birth_year == V1_MID
        assert m_fuzzy.governed_birth_year == V1_MID


# ---------------------------------------------------------------------------
# Calibration — the AUTO_LINK_THRESHOLD false-link bound
# ---------------------------------------------------------------------------


class TestCalibration:
    def test_below_threshold_creates_not_links(self, monkeypatch):
        """N3.6 default policy: a PENDING (sub-AUTO) match creates, never links."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1980)]
        monkeypatch.setattr(
            rf,
            "find_best_match",
            lambda *a, **k: MatchResult(
                scraped_name="KOWAL Jan", id_fencer=101, confidence=80.0, status="PENDING"
            ),
        )
        ctx, _ = _resolve(_parsed([_result("KOWAL Jan")]), fdb)
        (m,) = ctx.get("matches")
        assert m.method == "AUTO_CREATED"  # create-over-uncertain-link (ADR-070)
        assert m.id_fencer != 101

    def test_explicit_threshold_override_links(self, monkeypatch):
        """N3.7 an explicit auto_link_threshold recalibrates the link cutoff."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1980)]
        monkeypatch.setattr(
            rf,
            "find_best_match",
            lambda *a, **k: MatchResult(
                scraped_name="KOWAL Jan", id_fencer=101, confidence=80.0, status="PENDING"
            ),
        )
        ctx, _ = _resolve(_parsed([_result("KOWAL Jan")]), fdb, config={"auto_link_threshold": 75})
        (m,) = ctx.get("matches")
        assert (m.id_fencer, m.method) == (101, "AUTO_MATCHED")


# ---------------------------------------------------------------------------
# DetectCombinedPool / SplitByAge consume the GOVERNED birth year
# ---------------------------------------------------------------------------


class TestSplitUsesGovernedBy:
    def _ctx_with_matches(self, matches, season=2026):
        ctx = Context()
        ensure_pctx(ctx, parsed=_parsed([], category_hint=None), season_end_year=season)
        ctx.data["matches"] = matches
        return ctx

    def test_combined_detected_from_governed_by_spread(self):
        """N3.8 combined-ness comes from the governed BY spread, not scraped markers."""
        matches = [
            StageMatchResult("A", 1, 1, 95.0, "AUTO_MATCHED", governed_birth_year=V1_MID),
            StageMatchResult("B", 2, 2, 95.0, "AUTO_MATCHED", governed_birth_year=V3_MID),
        ]
        ctx = self._ctx_with_matches(matches)
        p = DetectCombinedPool()
        ctx._begin(p)
        p.run(ctx, Services())
        ctx._end()
        assert ctx.get("combined") is True

    def test_split_groups_by_governed_by(self):
        """N3.9 SplitByAge groups rows by the V-cat derived from governed BY."""
        matches = [
            StageMatchResult("A", 1, 1, 95.0, "AUTO_MATCHED", governed_birth_year=V1_MID),
            StageMatchResult("B", 2, 2, 95.0, "AUTO_MATCHED", governed_birth_year=V3_MID),
        ]
        ctx = self._ctx_with_matches(matches)
        ctx.data["combined"] = True
        p = SplitByAge()
        assert p.applies(ctx) is True
        ctx._begin(p)
        p.run(ctx, Services())
        ctx._end()
        splits = ctx.get("splits")
        assert set(splits.keys()) == {"V1", "V3"}
        assert splits["V1"][0].scraped_name == "A"
        assert splits["V3"][0].scraped_name == "B"
