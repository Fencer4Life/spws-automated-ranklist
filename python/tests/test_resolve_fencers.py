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
from python.matcher.pipeline import estimate_birth_year, reconciled_birth_year
from python.pipeline.core.contract import Context, Services
from python.pipeline.plugins import resolve_fencers as rf
from python.pipeline.plugins.bridge import ensure_pctx
from python.pipeline.plugins.ingest import DetectCombinedPool, SplitByAge
from python.pipeline.types import Overrides, StageMatchResult

V1_MID = estimate_birth_year("V1", 2026)
V3_MID = estimate_birth_year("V3", 2026)
V1_EDGE = 2026 - 40  # youngest age in V1 band


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


def _parsed(results, category_hint="V1", gender="M", weapon="EPEE"):
    from python.pipeline.ir import ParsedTournament, SourceKind

    return ParsedTournament(
        source_kind=SourceKind.CERT_REF,
        results=results,
        parsed_date=date(2026, 4, 1),
        weapon=weapon,
        gender=gender,
        organizer_hint="SPWS",
        category_hint=category_hint,
        season_end_year=2026,
    )


def _fencer(id_, surname, first, by, gender="M", estimated=False):
    return {
        "id_fencer": id_,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
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

    def test_reconcile_demotion_confirmed_is_noop(self):
        """N3.2 (ADR-056 amend) CONFIRMED BY is promote-only: a bracket V-cat YOUNGER
        than the stored age (demotion V2->V1) must NOT move a confirmed BY — it is
        logged as a conflict and left untouched (admin-only). Age is monotonic."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1970, estimated=False)]  # confirmed, V2
        db = _db(fdb)
        ctx, pctx = _resolve(_parsed([_result("KOWALSKI Jan")]), fdb, db=db)
        (m,) = ctx.get("matches")
        assert m.id_fencer == 101 and m.method == "AUTO_MATCHED"
        assert m.governed_birth_year == 1970  # unchanged
        db.update_fencer_birth_year.assert_not_called()
        assert not pctx.reconciled_fencers
        assert pctx.reconcile_conflicts and pctx.reconcile_conflicts[0]["id_fencer"] == 101

    def test_reconcile_demotion_estimated_allowed(self):
        """N3.2b ESTIMATED BY may move both ways: a demotion (V2->V1) of an estimate
        in a single-gender bracket still corrects to the band midpoint (the bracket
        is now the only age signal -> the least-biased new-fencer estimate)."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1970, estimated=True)]  # estimated, V2
        db = _db(fdb)
        ctx, pctx = _resolve(_parsed([_result("KOWALSKI Jan")]), fdb, db=db)
        (m,) = ctx.get("matches")
        assert m.governed_birth_year == V1_MID
        db.update_fencer_birth_year.assert_called_once_with(101, V1_MID, estimated=True)
        assert pctx.reconciled_fencers and pctx.reconciled_fencers[0]["new_birth_year"] == V1_MID

    def test_mixed_gender_bracket_skips_reconcile(self):
        """N3.2c (ADR-056 amend) a MIXED-gender bracket (>1 fencer gender present)
        never calibrates BY — its V-cat label is untrustworthy. A would-be promotion
        of the cross-gender guest is skipped; her BY is unchanged + logged."""
        # Men's V0 bracket that also contains a woman (cross-gender guest). The woman
        # is estimated V0 (1991) and the bracket label is V0 — but a V1 woman entered
        # as a guest must not be re-stamped V0 from this mislabel-prone bracket.
        woman = _fencer(247, "SAMECKA", "Martyna", 1986, gender="F", estimated=True)  # V1
        man = _fencer(101, "KOWALSKI", "Jan", 1991, gender="M", estimated=True)  # V0
        fdb = [woman, man]
        db = _db(fdb)
        parsed = _parsed(
            [_result("SAMECKA Martyna"), _result("KOWALSKI Jan", place=2)],
            category_hint="V0",
            gender="M",
            weapon="SABRE",
        )
        ctx, pctx = _resolve(parsed, fdb, db=db)
        db.update_fencer_birth_year.assert_not_called()
        assert woman["int_birth_year"] == 1986 and man["int_birth_year"] == 1991
        assert pctx.reconcile_conflicts  # surfaced for the operator

    def test_reconcile_order_independent_across_brackets(self):
        """N3.2d Fixpoint: a woman who is V1 in her own-gender épée bracket and a
        cross-gender guest in a mixed men's sabre V0 bracket settles at V1 (1986)
        regardless of which bracket is ingested first — no oscillation."""
        epee = lambda: _parsed(  # noqa: E731 — women's V1 épée (single-gender)
            [_result("SAMECKA Martyna", place=2)], category_hint="V1", gender="F", weapon="EPEE"
        )
        sabre = lambda: _parsed(  # noqa: E731 — mixed men's sabre V0 (cross-gender guest)
            [_result("SAMECKA Martyna", place=4), _result("KOWALSKI Jan", place=1)],
            category_hint="V0",
            gender="M",
            weapon="SABRE",
        )

        def run(order):
            fdb = [
                _fencer(247, "SAMECKA", "Martyna", 1991, gender="F", estimated=True),  # V0 → promote
                _fencer(101, "KOWALSKI", "Jan", 1991, gender="M", estimated=True),
            ]
            db = _db(fdb)
            for make in order:
                _resolve(make(), fdb, db=db)
            return next(f for f in fdb if f["id_fencer"] == 247)["int_birth_year"]

        assert run([epee, sabre]) == V1_EDGE  # 1986
        assert run([sabre, epee]) == V1_EDGE  # 1986 — order-independent

    def test_reconcile_promotion_to_youngest_edge(self):
        """Promotion (BY-derived V0, bracket V1) corrects to the V1 YOUNGEST edge
        (age 40), not the midpoint — she just crossed the boundary, so the band
        centre would over-age her and prematurely re-promote her next season."""
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1990)]  # age 36 @2026 -> V0, promoted to V1
        db = _db(fdb)
        ctx, pctx = _resolve(_parsed([_result("KOWALSKI Jan")], category_hint="V1"), fdb, db=db)
        (m,) = ctx.get("matches")
        assert m.id_fencer == 101 and m.method == "AUTO_MATCHED"
        assert m.governed_birth_year == V1_EDGE
        db.update_fencer_birth_year.assert_called_once_with(101, V1_EDGE, estimated=True)
        rec = pctx.reconciled_fencers[0]
        assert rec["new_birth_year"] == V1_EDGE
        assert rec["was_confirmed"] is True  # confirmed BY downgraded to estimated, surfaced

    def test_promotion_correction_is_cross_season_stable(self):
        """The youngest-edge correction keeps a freshly-promoted fencer in the new
        band the following season (the midpoint would push her up a category)."""
        from python.pipeline.stages import vcat_for_age

        assert vcat_for_age(2026 - V1_EDGE) == "V1"
        assert vcat_for_age(2031 - V1_EDGE) == "V1"  # still V1 five seasons on
        assert vcat_for_age(2031 - V1_MID) == "V2"  # midpoint would have promoted her


class TestReconciledBirthYearHelper:
    """reconciled_birth_year — the shared correction-target rule (both reconcile sites)."""

    def test_promotion_returns_youngest_edge(self):
        # V0 -> V1 promotion: youngest age in V1 is 40.
        assert reconciled_birth_year("V1", 2026, current_vcat="V0") == 2026 - 40

    def test_demotion_returns_midpoint(self):
        # V2 -> V1 demotion: keep midpoint fallback.
        assert reconciled_birth_year("V1", 2026, current_vcat="V2") == V1_MID

    def test_unknown_current_returns_midpoint(self):
        assert reconciled_birth_year("V1", 2026, current_vcat=None) == V1_MID

    def test_multi_band_promotion_youngest_edge(self):
        # V0 -> V3 (e.g. organizer marker far older): still youngest edge of target.
        assert reconciled_birth_year("V3", 2026, current_vcat="V0") == 2026 - 60


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
        # estimated so the V2->V1 demotion still corrects (Guard 1 only blocks
        # CONFIRMED demotions); the point here is the Phase-A-before-Phase-B ordering.
        fdb = [_fencer(101, "KOWALSKI", "Jan", 1970, estimated=True)]  # wrong BY (V2), bracket V1
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
