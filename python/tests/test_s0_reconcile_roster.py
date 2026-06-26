"""
Stage 0 — roster reconciliation (ADR-050 / ADR-056 / ADR-010 / ADR-038).

The first pipeline stage. It runs BEFORE the fuzzy matcher (s6) and does two
mirror jobs per scraped result row, keyed on the row's AUTHORITATIVE V-cat
(bracket category_hint → else FTL `(N)` raw_age_marker → else unknown):

  1. NEW fencer (HIGH-PRECISION exact surname+first+nationality+alias check,
     NOT fuzzy) → create with int_birth_year = MIDPOINT of the bracket V-cat
     band, bool_birth_year_estimated=TRUE. V-cat unknown → NULL BY + flagged.
  2. MATCHED fencer whose stored BY conflicts with the bracket V-cat → correct
     to the band midpoint. Estimated → keep flag. CONFIRMED → also overwrite
     + flip to estimated (downgrade), surfaced loudly.

International rows (PEW/MEW/MSW, ADR-038) are SKIPPED entirely.

Plan-test-IDs: 10.x (Stage-0 roster reconciliation milestone).
"""

from __future__ import annotations

import pytest

from python.pipeline import stages
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.types import Overrides, PipelineContext

# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------


class FakeDB:
    """Minimal DbConnector stand-in for Stage-0 unit tests.

    Persists inserts/updates so re-running the stage exercises idempotence.
    """

    def __init__(self, fencers: list[dict] | None = None) -> None:
        self._fencers = [dict(f) for f in (fencers or [])]
        existing = [f["id_fencer"] for f in self._fencers]
        self._next_id = (max(existing) + 1) if existing else 1
        self.inserted: list[dict] = []
        self.updated: list[dict] = []

    def fetch_fencer_db(self) -> list[dict]:
        return [dict(f) for f in self._fencers]

    def insert_fencer(self, fencer_dict: dict) -> int:
        rec = dict(fencer_dict)
        rec["id_fencer"] = self._next_id
        self._next_id += 1
        self._fencers.append(rec)
        self.inserted.append(rec)
        return rec["id_fencer"]

    def update_fencer_birth_year(
        self, fencer_id: int, birth_year: int, estimated: bool = False
    ) -> None:
        self.updated.append(
            {"id_fencer": fencer_id, "int_birth_year": birth_year, "estimated": estimated}
        )
        for f in self._fencers:
            if f["id_fencer"] == fencer_id:
                f["int_birth_year"] = birth_year
                f["bool_birth_year_estimated"] = estimated


def _fencer(
    id_fencer,
    surname,
    first,
    *,
    by=None,
    estimated=False,
    nationality="PL",
    gender=None,
    aliases=None,
):
    return {
        "id_fencer": id_fencer,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
        "txt_nationality": nationality,
        "enum_gender": gender,
        "json_name_aliases": aliases or [],
    }


def _ctx(
    results,
    *,
    event_code="PPW3-2025-2026",
    category_hint=None,
    gender=None,
    season_end_year=2026,
    source=SourceKind.FTL,
):
    parsed = ParsedTournament(
        source_kind=source,
        results=results,
        category_hint=category_hint,
        gender=gender,
    )
    return PipelineContext(
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=season_end_year,
        event_code=event_code,
    )


def _result(name, place=1, *, country="POL", marker=None, excluded=False):
    return ParsedResult(
        source_row_id=f"t:{name}:{place}",
        fencer_name=name,
        place=place,
        fencer_country=country,
        raw_age_marker=marker,
        bool_excluded=excluded,
    )


# ---------------------------------------------------------------------------
# 10.1  Midpoint table (single source of truth)
# ---------------------------------------------------------------------------


class TestMidpointTable:
    def test_midpoint_anchor_ages(self):
        """10.1.1 — midpoint anchors V0→35..V4→75 (season-relative)."""
        from python.matcher.pipeline import estimate_birth_year

        assert estimate_birth_year("V0", 2026) == 1991
        assert estimate_birth_year("V1", 2026) == 1981
        assert estimate_birth_year("V2", 2026) == 1971
        assert estimate_birth_year("V3", 2026) == 1961
        assert estimate_birth_year("V4", 2026) == 1951


# ---------------------------------------------------------------------------
# 10.2  Authoritative V-cat resolution
# ---------------------------------------------------------------------------


class TestAuthoritativeVcat:
    def test_category_hint_wins(self):
        """10.2.1 — single-cat bracket category_hint is authoritative."""
        ctx = _ctx([_result("X Y", marker="2")], category_hint="V1")
        r = ctx.parsed.results[0]
        assert stages._row_authoritative_vcat(ctx, r) == "V1"

    def test_ftl_marker_when_no_hint(self):
        """10.2.2 — combined pool (no hint) falls back to FTL (N) marker."""
        ctx = _ctx([_result("X Y", marker="3")], category_hint=None)
        r = ctx.parsed.results[0]
        assert stages._row_authoritative_vcat(ctx, r) == "V3"

    def test_marker_zero_is_v0(self):
        """10.2.3 — FTL marker '0' → V0."""
        ctx = _ctx([_result("X Y", marker="0")], category_hint=None)
        assert stages._row_authoritative_vcat(ctx, ctx.parsed.results[0]) == "V0"

    def test_unknown_when_neither(self):
        """10.2.4 — no hint, no marker → None (unknown)."""
        ctx = _ctx([_result("X Y", marker=None)], category_hint=None)
        assert stages._row_authoritative_vcat(ctx, ctx.parsed.results[0]) is None


# ---------------------------------------------------------------------------
# 10.3  New-fencer creation (high-precision, NOT fuzzy)
# ---------------------------------------------------------------------------


class TestCreateNewFencer:
    def test_unknown_foreign_woman_created_not_glued(self):
        """10.3.1 — a genuinely new foreign name is CREATED, not fuzzy-glued
        to the nearest existing Pole (the class-B contamination this fixes)."""
        db = FakeDB([_fencer(1, "BARAN", "Anna", by=1970, nationality="PL", gender="F")])
        # Combined women's pool, unmarked → V-cat unknown.
        ctx = _ctx(
            [_result("RABAB Fatima", country="MAR", marker=None)], category_hint=None, gender="F"
        )
        stages.s0_reconcile_roster(ctx, db)

        assert len(db.inserted) == 1
        created = db.inserted[0]
        assert created["txt_surname"] == "RABAB"
        assert created["txt_first_name"] == "Fatima"
        # V-cat unknown → NULL birth year, still flagged for admin
        assert created["int_birth_year"] is None
        assert len(ctx.created_fencers) == 1
        assert ctx.created_fencers[0]["vcat"] is None

    def test_created_with_marker_gets_midpoint(self):
        """10.3.2 — marked fencer in a combined pool gets the band midpoint BY
        and bool_birth_year_estimated = TRUE."""
        db = FakeDB([])
        ctx = _ctx(
            [_result("NOWAK Jan", country="POL", marker="2")], category_hint=None, gender="M"
        )
        stages.s0_reconcile_roster(ctx, db)
        created = db.inserted[0]
        assert created["int_birth_year"] == 1971  # V2 midpoint, season 2026
        assert created["bool_birth_year_estimated"] is True
        assert created["enum_gender"] == "M"

    def test_single_cat_bracket_uses_hint_midpoint(self):
        """10.3.3 — single-cat bracket: BY = midpoint of category_hint band."""
        db = FakeDB([])
        ctx = _ctx([_result("KOWALSKA Ewa", country="POL")], category_hint="V3", gender="F")
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted[0]["int_birth_year"] == 1961  # V3 midpoint 2026

    def test_exact_existing_not_recreated(self):
        """10.3.4 — exact surname+first match → no creation (high precision)."""
        db = FakeDB([_fencer(1, "NOWAK", "Jan", by=1971, nationality="PL")])
        ctx = _ctx([_result("NOWAK Jan", country="POL", marker="2")], category_hint=None)
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted == []
        assert ctx.created_fencers == []

    def test_alias_match_not_recreated(self):
        """10.3.5 — scraped name equals an existing alias → matched, not created."""
        db = FakeDB(
            [_fencer(1, "SPLAWA-NEYMAN", "Piotr", aliases=["NEYMAN Piotr"], nationality="PL")]
        )
        ctx = _ctx([_result("NEYMAN Piotr", country="POL", marker="2")], category_hint=None)
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted == []

    def test_same_name_different_nationality_created(self):
        """10.3.6 — exact name but a different (known) nationality → treated as
        a different person and created (foreign newcomer who collides on name)."""
        db = FakeDB([_fencer(1, "KOWAL", "Jan", by=1970, nationality="PL")])
        ctx = _ctx([_result("KOWAL Jan", country="UKR", marker="2")], category_hint=None)
        stages.s0_reconcile_roster(ctx, db)
        assert len(db.inserted) == 1
        assert db.inserted[0]["txt_nationality"] == "UKR"

    def test_polish_2letter_vs_3letter_no_duplicate(self):
        """10.3.7 — stored 'PL' vs scraped 'POL' must NOT create a duplicate."""
        db = FakeDB([_fencer(1, "WISNIEWSKI", "Adam", by=1970, nationality="PL")])
        ctx = _ctx([_result("WISNIEWSKI Adam", country="POL", marker="2")], category_hint=None)
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted == []


# ---------------------------------------------------------------------------
# 10.4  Reconciliation of a matched fencer whose BY conflicts
# ---------------------------------------------------------------------------


class TestReconcile:
    def test_estimated_conflict_reestimated_keep_flag(self):
        """10.4.1 — estimated BY younger than the bracket band (PROMOTION) →
        re-estimate to the new band's YOUNGEST edge (just crossed the boundary),
        keep estimated=TRUE."""
        # Stored BY 1991 → age 35 → V0. Bracket says V2 → promotion V0→V2.
        db = FakeDB([_fencer(1, "DABROWSKI", "Marek", by=1991, estimated=True, nationality="PL")])
        ctx = _ctx([_result("DABROWSKI Marek", country="POL")], category_hint="V2")
        stages.s0_reconcile_roster(ctx, db)
        assert len(db.updated) == 1
        assert db.updated[0]["int_birth_year"] == 1976  # V2 youngest edge (age 50)
        assert db.updated[0]["estimated"] is True
        assert len(ctx.reconciled_fencers) == 1
        assert ctx.reconciled_fencers[0]["was_confirmed"] is False
        assert ctx.reconciled_fencers[0]["old_birth_year"] == 1991
        assert ctx.reconciled_fencers[0]["new_birth_year"] == 1976
        assert ctx.reconciled_fencers[0]["anchor"] == "lower edge"

    def test_confirmed_conflict_downgraded_and_flagged(self):
        """10.4.2 — CONFIRMED BY younger than the bracket band (PROMOTION) →
        overwrite to the new band's youngest edge AND flip to estimated
        (downgrade); surfaced via was_confirmed=True."""
        db = FakeDB([_fencer(1, "ZIELINSKI", "Tomasz", by=1991, estimated=False, nationality="PL")])
        ctx = _ctx([_result("ZIELINSKI Tomasz", country="POL")], category_hint="V3")
        stages.s0_reconcile_roster(ctx, db)
        assert db.updated[0]["int_birth_year"] == 1966  # V3 youngest edge (age 60)
        assert db.updated[0]["estimated"] is True  # downgraded
        assert ctx.reconciled_fencers[0]["was_confirmed"] is True
        assert ctx.reconciled_fencers[0]["anchor"] == "lower edge"

    def test_demotion_conflict_uses_midpoint(self):
        """10.4.2b — stored BY OLDER than the bracket band (demotion, rare /
        usually organizer error) → keep the band midpoint as the safe fallback."""
        # Stored 1966 → age 60 → V3. Bracket V1 → demotion V3→V1.
        db = FakeDB([_fencer(1, "STARY", "Jan", by=1966, estimated=False, nationality="PL")])
        ctx = _ctx([_result("STARY Jan", country="POL")], category_hint="V1")
        stages.s0_reconcile_roster(ctx, db)
        assert db.updated[0]["int_birth_year"] == 1981  # V1 midpoint (age 45)
        assert ctx.reconciled_fencers[0]["anchor"] == "band midpoint"

    def test_no_conflict_no_write(self):
        """10.4.3 — stored BY already in the bracket band → no write at all."""
        # Stored 1971 → age 55 → V2. Bracket V2 → no conflict.
        db = FakeDB([_fencer(1, "LIS", "Jan", by=1971, estimated=False, nationality="PL")])
        ctx = _ctx([_result("LIS Jan", country="POL")], category_hint="V2")
        stages.s0_reconcile_roster(ctx, db)
        assert db.updated == []
        assert ctx.reconciled_fencers == []

    def test_null_by_matched_not_reconciled(self):
        """10.4.4 — matched fencer with NULL BY is left for admin (no conflict
        to correct); not written here."""
        db = FakeDB([_fencer(1, "MAJ", "Ola", by=None, nationality="PL")])
        ctx = _ctx([_result("MAJ Ola", country="POL")], category_hint="V2")
        stages.s0_reconcile_roster(ctx, db)
        assert db.updated == []

    def test_unknown_vcat_no_reconcile(self):
        """10.4.5 — matched fencer but bracket V-cat unknown → cannot reconcile."""
        db = FakeDB([_fencer(1, "MAJ", "Ola", by=1991, estimated=True, nationality="PL")])
        ctx = _ctx([_result("MAJ Ola", country="POL", marker=None)], category_hint=None)
        stages.s0_reconcile_roster(ctx, db)
        assert db.updated == []


# ---------------------------------------------------------------------------
# 10.5  International skip (ADR-038)
# ---------------------------------------------------------------------------


class TestInternationalSkip:
    @pytest.mark.parametrize("code", ["PEW63e-2025-2026", "MEW-2025-2026", "MSW-2025-2026"])
    def test_international_event_skipped(self, code):
        """10.5.1 — PEW/MEW/MSW events: no creation, no reconciliation."""
        db = FakeDB([_fencer(1, "SMITH", "John", by=1991, estimated=False, nationality="GBR")])
        ctx = _ctx(
            [_result("BRAND New", country="GBR"), _result("SMITH John", country="GBR")],
            event_code=code,
            category_hint="V2",
        )
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted == []
        assert db.updated == []
        assert ctx.created_fencers == []
        assert ctx.reconciled_fencers == []

    def test_domestic_event_runs(self):
        """10.5.2 — PPW (domestic) event runs normally."""
        db = FakeDB([])
        ctx = _ctx(
            [_result("NEW Person", country="POL")], event_code="PPW3-2025-2026", category_hint="V2"
        )
        stages.s0_reconcile_roster(ctx, db)
        assert len(db.inserted) == 1


# ---------------------------------------------------------------------------
# 10.6  Idempotence + cross-bracket conflict handling
# ---------------------------------------------------------------------------


class TestIdempotenceAndConflicts:
    def test_rerun_no_duplicate_create(self):
        """10.6.1 — re-running the stage does not duplicate created fencers."""
        db = FakeDB([])
        results = [_result("UNIQUE Person", country="POL", marker="2")]
        ctx1 = _ctx(results, category_hint=None)
        stages.s0_reconcile_roster(ctx1, db)
        assert len(db.inserted) == 1
        ctx2 = _ctx([_result("UNIQUE Person", country="POL", marker="2")], category_hint=None)
        stages.s0_reconcile_roster(ctx2, db)
        assert len(db.inserted) == 1  # still 1

    def test_reconcile_idempotent(self):
        """10.6.2 — once BY = band midpoint, a re-run finds no conflict."""
        db = FakeDB([_fencer(1, "REPEAT", "Guy", by=1991, estimated=True, nationality="PL")])
        ctx1 = _ctx([_result("REPEAT Guy", country="POL")], category_hint="V2")
        stages.s0_reconcile_roster(ctx1, db)
        assert len(db.updated) == 1
        ctx2 = _ctx([_result("REPEAT Guy", country="POL")], category_hint="V2")
        stages.s0_reconcile_roster(ctx2, db)
        assert len(db.updated) == 1  # no second write

    def test_cross_bracket_conflict_flagged_not_thrashed(self):
        """10.6.3 — same fencer twice in one run with conflicting V-cats → flag
        the conflict, write at most once (no flip-flop)."""
        db = FakeDB([_fencer(1, "TWICE", "Bob", by=1991, estimated=True, nationality="PL")])
        # Same matched fencer referenced by two rows with different markers.
        ctx = _ctx(
            [
                _result("TWICE Bob", place=1, country="POL", marker="2"),
                _result("TWICE Bob", place=2, country="POL", marker="3"),
            ],
            category_hint=None,
        )
        stages.s0_reconcile_roster(ctx, db)
        # At most one reconcile write for that fencer.
        writes = [u for u in db.updated if u["id_fencer"] == 1]
        assert len(writes) == 1
        assert len(ctx.reconcile_conflicts) == 1


# ---------------------------------------------------------------------------
# 10.7  Excluded rows
# ---------------------------------------------------------------------------


class TestExcludedRows:
    def test_excluded_row_skipped(self):
        """10.7.1 — a parser-excluded row is neither created nor reconciled."""
        db = FakeDB([])
        ctx = _ctx(
            [_result("DROP Me", country="POL", marker="2", excluded=True)], category_hint=None
        )
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted == []


# ---------------------------------------------------------------------------
# 10.8  Orchestrator registration
# ---------------------------------------------------------------------------


class TestOrchestratorRegistration:
    def test_s0_is_first_stage(self):
        """10.8.1 — s0_reconcile_roster is registered FIRST in the dispatcher."""
        from python.pipeline.orchestrator import _STAGE_NAMES

        assert _STAGE_NAMES[0] == "s0_reconcile_roster"


# ---------------------------------------------------------------------------
# 10.9  Staging .md top blocks
# ---------------------------------------------------------------------------


class TestStagingMdSection:
    def _ctx_with(self, **kw):
        ctx = _ctx([], category_hint=None)
        for k, v in kw.items():
            setattr(ctx, k, v)
        return ctx

    def test_created_and_downgrade_blocks_render(self):
        """10.9.1 — both top blocks render, with the loud CONFIRMED-downgrade
        marker."""
        from python.tools.phase5_runner import _format_stage0_section

        ctx = self._ctx_with(
            created_fencers=[
                {
                    "id_fencer": 9,
                    "scraped_name": "RABAB Fatima",
                    "nationality": "MAR",
                    "vcat": None,
                    "birth_year": None,
                    "estimated": False,
                    "source": "FTL",
                }
            ],
            reconciled_fencers=[
                {
                    "id_fencer": 5,
                    "scraped_name": "ZIELINSKI Tomasz",
                    "vcat": "V3",
                    "old_birth_year": 1991,
                    "new_birth_year": 1961,
                    "was_confirmed": True,
                    "source": "FTL",
                }
            ],
        )
        out = "\n".join(_format_stage0_section([("slot", None, ctx, None)]))
        assert "🆕 New fencers created this ingestion" in out
        assert "RABAB Fatima" in out
        assert "Birth years adjusted this ingestion" in out
        assert "was CONFIRMED → downgraded" in out

    def test_empty_when_nothing_happened(self):
        """10.9.2 — no Stage-0 activity → no section (empty list)."""
        from python.tools.phase5_runner import _format_stage0_section

        ctx = self._ctx_with()
        assert _format_stage0_section([("slot", None, ctx, None)]) == []
