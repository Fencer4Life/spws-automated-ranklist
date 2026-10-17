"""ADM.ID / NAT.EVID — an international row is admitted by identity.

ADR-106 §1–§2 (decided 2 Oct 2026). For an international event each source row
is decided once, by one module that every ingestion path calls:

1. Identity: the matcher's AUTO_MATCHED (surname, first given name, a birth
   year that fits the category; MATCH.ID) to a fencer who has a PPW or MPW
   result in any season. Stored, whatever country the source prints.
2. Otherwise a row printed POL is PENDING, never stored automatically.
3. Everything else is rejected, never PENDING.

The printed federation is kept as the result's evidence (NAT.EVID.01),
folded to three letters.
"""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.types import Overrides, PipelineContext


def _f(fid, sur, first, by):
    return {
        "id_fencer": fid,
        "txt_surname": sur,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": False,
        "json_name_aliases": None,
        "enum_gender": "M",
        "txt_nationality": "PL",
    }


# V1 men's épée, season 2025/26: born 1977–1986 fits.
ROSTER = [
    _f(124, "KULKA", "Dawid", 1979),  # SPWS starter, entered for Ireland
    _f(90, "BOBUSIA", "Jarosław", 1985),  # SPWS starter, page without a country
    _f(7, "KOLLAR", "Gabriel", 1980),  # never started at SPWS
    _f(8, "GOLA", "Maciej", 1983),  # a Pole, never started at SPWS
    _f(9, "KOWALCZYK", "Piotr", 1981),  # SPWS starter, namesake target
]
STARTERS = {124, 90, 9}

# (scraped name, printed country) → (decision, id_fencer)
CASES = [
    ("KULKA Dawid", "IRL", "STORED", 124),
    ("BOBUSIA Jaroslaw", None, "STORED", 90),
    ("KOLLAR Gabriel", "SVK", "REJECTED", None),
    ("GOLA Maciej", "POL", "PENDING", 8),
    ("NOWAK Szymon", "POL", "PENDING", None),
    ("KOLCZONAY Judit", "HUN", "REJECTED", None),
]


def _admit(name, country):
    from python.pipeline.international_admission import admit

    return admit(
        name,
        country,
        category="V1",
        season_end_year=2026,
        roster=ROSTER,
        spws_starters=STARTERS,
    )


def test_ADM_ID_01_an_identity_match_with_an_spws_start_is_stored_whatever_the_country():
    """KULKA Dawid, printed IRL, five SPWS results: stored."""
    a = _admit("KULKA Dawid", "IRL")
    assert (a.decision, a.id_fencer, a.entered_for) == ("STORED", 124, "IRL")


def test_ADM_ID_02_a_page_without_a_country_stores_by_identity():
    """BOBUSIA Jarosław on a page headed Club (no country), written without
    Polish letters: stored; no federation is recorded."""
    a = _admit("BOBUSIA Jaroslaw", None)
    assert (a.decision, a.id_fencer, a.entered_for) == ("STORED", 90, None)


def test_ADM_ID_03_no_spws_start_and_a_foreign_country_is_rejected():
    """KOLLAR Gabriel matches by identity but has never started at SPWS, and
    he entered for Slovakia: rejected."""
    a = _admit("KOLLAR Gabriel", "SVK")
    assert (a.decision, a.id_fencer) == ("REJECTED", None)


def test_ADM_ID_04_no_spws_start_and_printed_pol_is_pending():
    """GOLA Maciej matches by identity, printed POL, never started at SPWS:
    PENDING, carrying the fencer as the candidate; never stored."""
    a = _admit("GOLA Maciej", "POL")
    assert (a.decision, a.id_fencer, a.entered_for) == ("PENDING", 8, "POL")


def test_ADM_ID_05_printed_pol_without_identity_is_pending_with_or_without_a_candidate():
    """A Pole the roster does not know is PENDING without a candidate; a
    near match is PENDING with one ("PL" folds to POL)."""
    unknown = _admit("NOWAK Szymon", "POL")
    assert (unknown.decision, unknown.id_fencer) == ("PENDING", None)
    near = _admit("GOLA Mateusz", "PL")
    assert (near.decision, near.id_fencer, near.entered_for) == ("PENDING", 8, "POL")


def test_ADM_ID_06_a_foreign_or_blank_row_without_identity_is_rejected_never_pending():
    """ADR-038's queue flood: a Hungarian "KOLCZONAY Judit" near a Polish
    roster name, or a blank-country stranger, is rejected, not PENDING."""
    assert _admit("KOLCZONAY Judit", "HUN").decision == "REJECTED"
    assert _admit("SMITH John", None).decision == "REJECTED"


def test_ADM_ID_10_identity_is_surname_first_name_and_age_category_exactly():
    """Identity is SURNAME, first given name and age category (the user, 2 Oct
    2026), not a fuzzy score. "GOLA Marcin" scores 95 against GOLA Maciej and a
    one-letter typo "KOWALCZYK Pjotr" scores 95 against KOWALCZYK Piotr; neither
    is the same person: the first is PENDING (printed POL), the second
    rejected. A second given name in the source, a compound surname and
    folded Polish letters still match; two fencers who both fit, a birth year
    outside the category, or an unknown birth year do not."""
    from python.pipeline.international_admission import admit, identity_matches

    assert _admit("GOLA Marcin", "POL").decision == "PENDING"
    assert _admit("KOWALCZYK Pjotr", "GER").decision == "REJECTED"
    roster = [
        _f(1, "CARRILLO AYALA", "Andres", 1981),
        _f(2, "KORONA", "Przemysław Jan", 1976),
        _f(3, "NOWAK", "Jan", 1980),
        _f(4, "NOWAK", "Jan", 1984),
        _f(5, "LIS", "Ewa", None),
    ]
    assert identity_matches("CARRILLO AYALA Andres Marcel", "V1", 2026, roster) == [1]
    assert identity_matches("KORONA Przemyslaw", "V2", 2026, roster) == [2]
    assert identity_matches("KORONA Przemyslaw", "V1", 2024, roster) == [
        2
    ]  # 1976 in V1 for 2023/24
    assert identity_matches("KORONA Przemyslaw", "V3", 2026, roster) == []
    assert identity_matches("NOWAK Jan", "V1", 2026, roster) == [3, 4]
    assert identity_matches("LIS Ewa", "V2", 2026, roster) == []
    two = admit(
        "NOWAK Jan", "POL", category="V1", season_end_year=2026, roster=roster, spws_starters={3, 4}
    )
    assert (two.decision, two.reason) == ("PENDING", "two roster fencers fit")


@pytest.mark.parametrize(
    "country, expected",
    [("PL", "POL"), (" pol ", "POL"), ("", None), ("Poland", None), ("IR1", None)],
)
def test_NAT_EVID_01_the_printed_federation_is_folded(country, expected):
    """The evidence is the three-letter code the source printed: "PL" and
    " pol " fold to POL; an empty cell, or anything that is not three letters
    ("Poland"), is no federation (the stored column admits three letters only)."""
    from python.pipeline.international_admission import fold_federation

    assert fold_federation(country) == expected


# ---------------------------------------------------------------------------
# ADM.ID.07 — every path gives the same three decisions
# ---------------------------------------------------------------------------


def _rows():
    return [
        ParsedResult(source_row_id=f"t:{n}", fencer_name=n, place=i, fencer_country=c)
        for i, (n, c, _d, _f) in enumerate(CASES, start=1)
    ]


def _pctx(code="PEW1efs-2025-2026"):
    parsed = ParsedTournament(
        source_kind=SourceKind.ENGARDE,
        results=_rows(),
        raw_pool_size=len(CASES),
        weapon="EPEE",
        gender="M",
        category_hint="V1",
        season_end_year=2026,
    )
    ctx = PipelineContext(parsed=parsed, overrides=Overrides(), season_end_year=2026)
    ctx.event = {"id_event": 1, "txt_code": code}
    return ctx


def _db():
    db = MagicMock()
    db.fetch_fencer_db.return_value = ROSTER
    db.fetch_spws_starter_ids.return_value = STARTERS
    return db


EXPECTED = {
    "KULKA Dawid": ("STORED", 124),
    "BOBUSIA Jaroslaw": ("STORED", 90),
    "GOLA Maciej": ("PENDING", 8),
    "NOWAK Szymon": ("PENDING", None),
}
EXPECTED_REJECTED = {"KOLLAR Gabriel", "KOLCZONAY Judit"}


def _decisions_from_ctx(ctx):
    got = {
        m.scraped_name: ("STORED" if m.method == "AUTO_MATCHED" else m.method, m.id_fencer)
        for m in ctx.matches
    }
    return got, {d["name"] for d in ctx.rejected}


def test_ADM_ID_07_s6_resolve_identity():
    from python.pipeline.stages import s6_resolve_identity

    ctx = _pctx()
    s6_resolve_identity(ctx, _db())
    assert _decisions_from_ctx(ctx) == (EXPECTED, EXPECTED_REJECTED)
    entered = {m.scraped_name: m.entered_for for m in ctx.matches}
    assert entered["KULKA Dawid"] == "IRL"
    assert entered["BOBUSIA Jaroslaw"] is None


def test_ADM_ID_07_resolve_fencers():
    from python.pipeline.core.contract import Context, Services
    from python.pipeline.plugins.bridge import LEGACY
    from python.pipeline.plugins.resolve_fencers import ResolveFencers

    pctx = _pctx()
    ctx = Context()
    ctx.data[LEGACY] = pctx
    ctx.data["parsed"] = pctx.parsed
    ctx.data["event"] = pctx.event
    db = _db()
    plugin = ResolveFencers()
    ctx._begin(plugin)
    plugin.run(ctx, Services(db=db))
    ctx._end()
    assert _decisions_from_ctx(pctx) == (EXPECTED, EXPECTED_REJECTED)
    db.insert_fencer.assert_not_called()


def test_ADM_ID_07_resolve_tournament_results():
    from python.matcher.pipeline import resolve_tournament_results

    names = [n for n, *_ in CASES]
    res = resolve_tournament_results(
        names,
        ROSTER,
        "PEW",
        "V1",
        2026,
        scraped_countries=[c for _n, c, *_ in CASES],
        spws_starters=STARTERS,
    )
    got = {
        m.scraped_name: ("STORED" if m.status == "AUTO_MATCHED" else m.status, m.id_fencer)
        for m in res.matched
    }
    assert (got, set(res.skipped)) == (EXPECTED, EXPECTED_REJECTED)
    assert res.auto_created == []


def test_ADM_ID_07_evf_sync(monkeypatch):
    """The daily EVF sync stores only the admitted rows; the PENDING ones are
    returned for its report, never ingested."""
    import python.scrapers.evf_sync as sync

    def fake_query(_ref, _token, sql):
        if "fn_spws_starter_ids" in sql:
            return [{"ids": sorted(STARTERS)}]
        return ROSTER

    monkeypatch.setattr(sync, "_management_query", fake_query)
    evf_rows = [
        {
            "fencer_name": n,
            "place": i,
            "country": c or "",
            "weapon": "EPEE",
            "gender": "M",
            "category": "V1",
        }
        for i, (n, c, _d, _f) in enumerate(CASES, start=1)
    ]
    stored, pending = sync._match_against_spws("ref", "tok", evf_rows, season_end_year=2026)
    assert {r["fencer_name"]: r["spws_id"] for r in stored} == {
        "KULKA Dawid": 124,
        "BOBUSIA Jaroslaw": 90,
    }
    assert {r["fencer_name"] for r in pending} == {"GOLA Maciej", "NOWAK Szymon"}
    assert stored[0]["entered_for"] == "IRL"


def test_ADM_ID_12_a_named_override_links_each_environment_s_own_fencer():
    """ADM.ID.12 an override identity entry that names the fencer (surname,
    first name, birth year) links the row to the id that fencer has in the
    roster the run reads, so one committed file serves LOCAL, CERT and PROD;
    it reaches a rejected row too ("LYNCH Patrick", IRL, roster LYNCH Pat)."""
    from python.pipeline.stages import s6_resolve_identity
    from python.pipeline.types import IdentityOverride

    def run(lynch_id):
        roster = ROSTER + [_f(lynch_id, "LYNCH", "Pat", 1980)]
        ctx = _pctx()
        ctx.parsed.results.append(
            ParsedResult(
                source_row_id="t:L", fencer_name="LYNCH Patrick", place=7, fencer_country="IRL"
            )
        )
        ctx.overrides = Overrides(
            identity=[
                IdentityOverride(
                    scraped_name="LYNCH Patrick",
                    fencer={"surname": "LYNCH", "first_name": "Pat", "birth_year": 1980},
                )
            ]
        )
        db = MagicMock()
        db.fetch_fencer_db.return_value = roster
        db.fetch_spws_starter_ids.return_value = STARTERS
        s6_resolve_identity(ctx, db)
        return {m.scraped_name: (m.id_fencer, m.entered_for) for m in ctx.matches}["LYNCH Patrick"]

    assert run(284) == (284, "IRL")
    assert run(174) == (174, "IRL")


# ---------------------------------------------------------------------------
# ADM.FIE — FIE events (MSW, PSW, the IMSW code): ADR-106 amendment, 17 Oct 2026
# ---------------------------------------------------------------------------
# A row printed POL that is exactly one roster fencer is stored without a PPW
# or MPW start; a user-confirmed, unrevoked alias counts as identity (D9 A: a
# merely recorded alias does not, because the stage-time flush records every
# pair). EVF events (PEW, MEW, IMEW) keep ADR-106 §1 unchanged (ADM_ID_04 above).


def _fa(fid, sur, first, by, aliases=None, confirmed=None, revoked=None):
    f = _f(fid, sur, first, by)
    f["json_name_aliases"] = aliases
    f["json_user_confirmed_aliases"] = confirmed or []
    f["json_revoked_aliases"] = revoked or []
    return f


# V1, season 2026/27: born 1977–1987 fits (the season's end year or the year before).
FIE_ROSTER = [
    _fa(367, "SZUMIELEWICZ", "Paweł", 1986),  # added by an admin migration, no SPWS start
    _fa(174, "LYNCH", "Pat", 1980, aliases=["LYNCH Patrick"], confirmed=["LYNCH Patrick"]),
    _fa(76, "GERTSMAN", "Alex", 1980, aliases=["GERTSMAN Alexandr"]),  # recorded, not confirmed
    _fa(
        77,
        "KARMAN",
        "Irene",
        1980,
        aliases=["KARMAN Iren"],
        confirmed=["KARMAN Iren"],
        revoked=["KARMAN Iren"],
    ),
    _fa(8, "GOLA", "Maciej", 1983),  # no SPWS start
    _fa(30, "NOWAK", "Jan", 1980),
    _fa(31, "NOWAK", "Jan", 1984),
]
FIE_STARTERS = {174, 76, 77}


def _admit_fie(name, country, ttype="MSW", category="V1"):
    from python.pipeline.international_admission import admit

    return admit(
        name,
        country,
        category=category,
        season_end_year=2027,
        roster=FIE_ROSTER,
        spws_starters=FIE_STARTERS,
        tournament_type=ttype,
    )


def test_ADM_FIE_01_a_pole_in_the_fencer_table_is_stored_at_the_worlds_without_an_spws_start():
    """ADM.FIE.01 SZUMIELEWICZ Paweł, printed POL at the Worlds, is exactly one
    roster fencer and has no PPW or MPW result: stored."""
    a = _admit_fie("SZUMIELEWICZ Pawel", "POL")
    assert (a.decision, a.id_fencer, a.entered_for, a.reason) == (
        "STORED",
        367,
        "POL",
        "identity, entered by POL at an FIE event",
    )


@pytest.mark.parametrize(
    "ttype, expected",
    [
        ("MSW", "STORED"),
        ("PSW", "STORED"),
        ("PEW", "PENDING"),
        ("MEW", "PENDING"),
        (None, "PENDING"),
    ],
)
def test_ADM_FIE_02_only_fie_types_store_a_pole_without_an_spws_start(ttype, expected):
    """ADM.FIE.02 MSW and PSW store the row; the EVF types keep ADM_ID_04
    (PENDING), and so does a call that names no type."""
    assert _admit_fie("SZUMIELEWICZ Pawel", "POL", ttype=ttype).decision == expected


def test_ADM_FIE_03_a_pole_not_in_the_fencer_table_stays_pending():
    """ADM.FIE.03 printed POL, no identity: PENDING, never stored (D2 A). With
    no near name it carries no candidate; near a roster name it carries the
    matcher's guess, still PENDING."""
    a = _admit_fie("ZIELINSKI Bartosz", "POL")
    assert (a.decision, a.id_fencer) == ("PENDING", None)
    near = _admit_fie("NOWAK Szymon", "POL")
    assert (near.decision, near.id_fencer) == ("PENDING", 30)


def test_ADM_FIE_04_a_birth_year_outside_the_category_stays_pending():
    """ADM.FIE.04 SZUMIELEWICZ (1986) in a V3 bracket fits neither year: PENDING."""
    assert _admit_fie("SZUMIELEWICZ Pawel", "POL", category="V3").decision == "PENDING"


def test_ADM_FIE_05_two_namesakes_who_fit_stay_pending():
    """ADM.FIE.05 two roster fencers NOWAK Jan both fit V1: PENDING."""
    a = _admit_fie("NOWAK Jan", "POL")
    assert (a.decision, a.reason) == ("PENDING", "two roster fencers fit")


def test_ADM_FIE_06_a_foreign_flag_still_needs_an_spws_start():
    """ADM.FIE.06 GOLA Maciej matches by identity, has no SPWS start and is
    printed CZE: rejected, as under ADR-106 §1."""
    assert _admit_fie("GOLA Maciej", "CZE").decision == "REJECTED"


def test_ADM_FIE_07_a_user_confirmed_alias_is_identity_at_an_fie_event_only():
    """ADM.FIE.07 "LYNCH Patrick" (IRL) is the user-confirmed alias of LYNCH
    Pat, an SPWS starter born 1980: stored at the Worlds; at an EVF event the
    alias does not count and the row is rejected."""
    a = _admit_fie("LYNCH Patrick", "IRL")
    assert (a.decision, a.id_fencer, a.entered_for) == ("STORED", 174, "IRL")
    assert _admit_fie("LYNCH Patrick", "IRL", ttype="PEW").decision == "REJECTED"


def test_ADM_FIE_08_a_merely_recorded_or_a_revoked_alias_is_never_identity():
    """ADM.FIE.08 "GERTSMAN Alexandr" is recorded but not user-confirmed, and
    "KARMAN Iren" is confirmed but revoked: both rejected (D9 A)."""
    assert _admit_fie("GERTSMAN Alexandr", "ISR").decision == "REJECTED"
    assert _admit_fie("KARMAN Iren", "HUN").decision == "REJECTED"


def test_ADM_FIE_11_an_override_linked_pair_is_recorded_as_user_confirmed_at_sign_off():
    """ADM.FIE.11 at sign-off each alias pair the event's override file links
    (an identity entry naming that fencer) is recorded as the fencer's
    user-confirmed alias, so later FIE events match it without an override; a
    pair the file does not link, or links to another fencer, is not (D9 A)."""
    from python.pipeline.alias_writeback import PendingAlias
    from python.pipeline.types import IdentityOverride, Overrides
    from python.tools.phase5_runner import _confirm_override_linked_pairs

    overrides = Overrides(
        identity=[
            IdentityOverride("LYNCH Patrick", id_fencer=174),
            IdentityOverride("KARMAN Iren", id_fencer=119),
            IdentityOverride("GERTSMAN Alexandr", id_fencer=999),
        ]
    )
    pending = [
        PendingAlias(174, "LYNCH Patrick", "LYNCH Pat", "✓", "different first names"),
        PendingAlias(119, "KARMAN Iren", "KARMAN Irene", "✓", "typo"),
        PendingAlias(76, "GERTSMAN Alexandr", "GERTSMAN Alex", "❌", "different first names"),
        PendingAlias(5, "SEKOWSKI Maciej", "SĘKOWSKI Maciej", "✓", "diacritic fold"),
    ]
    db = MagicMock()
    assert _confirm_override_linked_pairs(db, pending, overrides) == 2
    assert [c.args for c in db.confirm_fencer_alias.call_args_list] == [
        (174, "LYNCH Patrick"),
        (119, "KARMAN Iren"),
    ]


def test_ADM_FIE_12_the_pipeline_roster_carries_the_confirmed_and_revoked_aliases():
    """ADM.FIE.12 the roster every ingestion path reads (fetch_fencer_db) holds
    json_user_confirmed_aliases and json_revoked_aliases, which the FIE alias
    identity needs."""
    from python.pipeline.db_connector import DbConnector

    sb = MagicMock()
    DbConnector(sb).fetch_fencer_db()
    cols = sb.table.return_value.select.call_args.args[0]
    assert "json_user_confirmed_aliases" in cols and "json_revoked_aliases" in cols


FIE_CASES = [
    ("SZUMIELEWICZ Pawel", "POL"),
    ("LYNCH Patrick", "IRL"),
    ("ZIELINSKI Bartosz", "POL"),
    ("GOLA Maciej", "CZE"),
]
FIE_EXPECTED = {
    "SZUMIELEWICZ Pawel": ("STORED", 367),
    "LYNCH Patrick": ("STORED", 174),
    "ZIELINSKI Bartosz": ("PENDING", None),
}


def _fie_pctx(code):
    parsed = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[
            ParsedResult(source_row_id=f"f:{n}", fencer_name=n, place=i, fencer_country=c)
            for i, (n, c) in enumerate(FIE_CASES, start=1)
        ],
        raw_pool_size=62,
        weapon="FOIL",
        gender="M",
        category_hint="V1",
        season_end_year=2027,
    )
    ctx = PipelineContext(parsed=parsed, overrides=Overrides(), season_end_year=2027)
    ctx.event = {"id_event": 77, "txt_code": code}
    return ctx


def _fie_db():
    db = MagicMock()
    db.fetch_fencer_db.return_value = FIE_ROSTER
    db.fetch_spws_starter_ids.return_value = FIE_STARTERS
    return db


@pytest.mark.parametrize("code", ["MSW-2026-2027", "IMSW-2026-2027"])
def test_ADM_FIE_09_every_path_decides_an_fie_row_the_same(code):
    """ADM.FIE.09 s6_resolve_identity, ResolveFencers and
    resolve_tournament_results decide an MSW row identically (the IMSW code
    too), and none creates a fencer."""
    from python.matcher.pipeline import resolve_tournament_results
    from python.pipeline.core.contract import Context, Services
    from python.pipeline.plugins.bridge import LEGACY
    from python.pipeline.plugins.resolve_fencers import ResolveFencers
    from python.pipeline.stages import s6_resolve_identity

    ctx = _fie_pctx(code)
    db = _fie_db()
    s6_resolve_identity(ctx, db)
    assert _decisions_from_ctx(ctx) == (FIE_EXPECTED, {"GOLA Maciej"})
    db.insert_fencer.assert_not_called()

    pctx = _fie_pctx(code)
    pc = Context()
    pc.data[LEGACY] = pctx
    pc.data["parsed"] = pctx.parsed
    pc.data["event"] = pctx.event
    db = _fie_db()
    plugin = ResolveFencers()
    pc._begin(plugin)
    plugin.run(pc, Services(db=db))
    pc._end()
    assert _decisions_from_ctx(pctx) == (FIE_EXPECTED, {"GOLA Maciej"})
    db.insert_fencer.assert_not_called()

    res = resolve_tournament_results(
        [n for n, _c in FIE_CASES],
        FIE_ROSTER,
        "MSW",
        "V1",
        2027,
        scraped_countries=[c for _n, c in FIE_CASES],
        spws_starters=FIE_STARTERS,
    )
    got = {
        m.scraped_name: ("STORED" if m.status == "AUTO_MATCHED" else m.status, m.id_fencer)
        for m in res.matched
    }
    assert (got, set(res.skipped)) == (FIE_EXPECTED, {"GOLA Maciej"})
    assert res.auto_created == []
