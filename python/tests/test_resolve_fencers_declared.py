"""DECL.RF.01–05 — ResolveFencers uses the birth year declared at registration.

`ingest-event.yml` (INGEST_DOMESTIC) identifies fencers in `ResolveFencers`,
which never read `tbl_registration`: only the older Stage 0 path did (ADR-056
amendment of 2026-09-25). On PPW1-2026-2027 that meant 13 PROD entrants created
at a band midpoint although each had declared a year, and confirmed years moved
by a bracket whatever the fencer declared. The rule is now the same on both
paths (decision D5 A, 3 Oct 2026):

  - a new fencer takes the declared year, confirmed, when it fits the bracket;
    otherwise the band midpoint, estimated, and a `declared_vs_bracket` conflict;
  - a matched fencer's move goes through `reconcile_fencer_birth_year` with the
    declaration, the policy Stage 0 already uses;
  - a name with registrations under two different years is dropped (namesakes).
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

from python.matcher.pipeline import estimate_birth_year
from python.pipeline.core.contract import Context, Services
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.plugins import resolve_fencers as rf
from python.pipeline.plugins.bridge import ensure_pctx
from python.pipeline.types import Overrides

SEASON_END = 2027
EVENT = "PPW1-2026-2027"


def _result(name, place=1):
    return ParsedResult(
        source_row_id=f"t:{name}:{place}", fencer_name=name, place=place, fencer_country="POL"
    )


def _parsed(results, category_hint):
    return ParsedTournament(
        source_kind=SourceKind.FTL,
        results=results,
        parsed_date=date(2026, 9, 26),
        weapon="EPEE",
        gender="M",
        organizer_hint="SPWS",
        category_hint=category_hint,
        season_end_year=SEASON_END,
    )


def _fencer(id_, surname, first, by, *, estimated=False):
    return {
        "id_fencer": id_,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
        "txt_nationality": "POL",
        "enum_gender": "M",
        "json_name_aliases": [],
    }


def _reg(surname, first, by):
    return {"txt_surname": surname, "txt_first_name": first, "int_birth_year": by}


def _db(fencers, registrations):
    db = MagicMock()
    db.fetch_fencer_db.return_value = [dict(f) for f in fencers]
    db.fetch_registration_birth_years.return_value = [dict(r) for r in registrations]
    seq = iter(range(900, 1000))
    db.insert_fencer.side_effect = lambda payload: next(seq)
    return db


def _resolve(parsed, db):
    ctx = Context()
    pctx = ensure_pctx(
        ctx, parsed=parsed, overrides=Overrides(), season_end_year=SEASON_END, event_code=EVENT
    )
    pctx.event = {"txt_code": EVENT, "enum_type": "PPW"}
    plugin = rf.ResolveFencers()
    ctx._begin(plugin)
    try:
        plugin.run(ctx, Services(db=db, config={}))
    finally:
        ctx._end()
    return ctx, pctx


def _inserted(db):
    return [c.args[0] for c in db.insert_fencer.call_args_list]


def test_new_entrant_takes_the_declared_year_confirmed():
    """DECL.RF.01 declared 1975, fenced V2 (52 in 2027): created 1975, confirmed."""
    db = _db([], [_reg("NOWAK", "Adam", 1975)])
    ctx, _ = _resolve(_parsed([_result("NOWAK Adam")], "V2"), db)
    (payload,) = _inserted(db)
    assert payload["int_birth_year"] == 1975
    assert payload["bool_birth_year_estimated"] is False
    (m,) = ctx.get("matches")
    assert m.method == "AUTO_CREATED"
    assert m.governed_birth_year == 1975


def test_declared_year_contradicting_the_bracket_takes_neither():
    """DECL.RF.02 declared 1993 (V0) but fenced V2: midpoint, estimated, reported."""
    db = _db([], [_reg("NOWAK", "Adam", 1993)])
    _, pctx = _resolve(_parsed([_result("NOWAK Adam")], "V2"), db)
    (payload,) = _inserted(db)
    assert payload["int_birth_year"] == estimate_birth_year("V2", SEASON_END)
    assert payload["bool_birth_year_estimated"] is True
    assert [c["reason"] for c in pctx.reconcile_conflicts] == ["declared_vs_bracket"]


def test_no_registration_keeps_the_midpoint():
    """DECL.RF.03 unchanged without a registration."""
    db = _db([], [])
    _resolve(_parsed([_result("NOWAK Adam")], "V2"), db)
    (payload,) = _inserted(db)
    assert payload["int_birth_year"] == estimate_birth_year("V2", SEASON_END)
    assert payload["bool_birth_year_estimated"] is True


def test_a_move_uses_the_declared_year():
    """DECL.RF.04 STANISŁAWSKI Albert stored 1991 (V0), fenced V1, declared 1985:
    written 1985 confirmed, not the bracket's 1987 estimated."""
    db = _db([_fencer(72, "STANISŁAWSKI", "Albert", 1991)], [_reg("STANISŁAWSKI", "Albert", 1985)])
    ctx, _ = _resolve(_parsed([_result("STANISŁAWSKI Albert")], "V1"), db)
    db.update_fencer_birth_year.assert_called_once_with(72, 1985, estimated=False)
    (m,) = ctx.get("matches")
    assert (m.id_fencer, m.governed_birth_year) == (72, 1985)


def test_two_registrations_under_one_name_are_not_used():
    """DECL.RF.05 two registrations with different years: no pick, midpoint."""
    db = _db([], [_reg("NOWAK", "Adam", 1975), _reg("NOWAK", "Adam", 1971)])
    _resolve(_parsed([_result("NOWAK Adam")], "V2"), db)
    (payload,) = _inserted(db)
    assert payload["int_birth_year"] == estimate_birth_year("V2", SEASON_END)
    assert payload["bool_birth_year_estimated"] is True


def test_report_shows_the_declared_year_against_the_bracket():
    """DECL.RF.06 the staging report names the declared year and the bracket,
    never an empty fencer id."""
    from python.pipeline.plugins.staging_formatter import _render_reconciled

    db = _db([], [_reg("NOWAK", "Adam", 1993)])
    _, pctx = _resolve(_parsed([_result("NOWAK Adam")], "V2"), db)
    text = _render_reconciled({"reconciled": [], "conflicts": pctx.reconcile_conflicts})
    assert "NOWAK Adam" in text and "1993" in text and "V2" in text
    assert "#None" not in text
    assert pctx.reconcile_conflicts[0]["source"] == "FTL"


def test_report_shows_a_declared_move_as_confirmed():
    """DECL.RF.07 a year taken from the registration is written confirmed, and
    the report says so: no "estimated", no "downgraded"."""
    from python.pipeline.plugins.staging_formatter import _render_reconciled

    db = _db([_fencer(72, "STANISŁAWSKI", "Albert", 1991)], [_reg("STANISŁAWSKI", "Albert", 1985)])
    _, pctx = _resolve(_parsed([_result("STANISŁAWSKI Albert")], "V1"), db)
    text = _render_reconciled({"reconciled": pctx.reconciled_fencers, "conflicts": []})
    row = next(line for line in text.splitlines() if "STANISŁAWSKI" in line)
    assert "| 1985 | confirmed |" in row
    assert "declared at registration" in row
    assert "estimated" not in row and "downgraded" not in row
