"""ROUTE.ORG — the results route reads its organizers from one registry (ADR-119 §2, D13 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, gap G9. Before
this, five places matched event-code prefixes on their own (the organizer, the
tournament type, the international check, the FIE flag, the daily close), and
the organizer guess disagreed with the stored one for IMEW, IMSW, PSW and DMEW.
`python/pipeline/organizers.py` now holds every organizer on the route, its
route class and its code families; nothing else matches a prefix. A new
organizer is one entry there.

  ROUTE.ORG.01  every code family keeps its tournament type and gets its true organizer;
  ROUTE.ORG.02  the registry agrees with every organizer and event of the PROD seed;
  ROUTE.ORG.03  an unregistered family is refused by name before anything is read;
  ROUTE.ORG.04  a fifth organizer is ingested and planned with no change outside the registry;
  ROUTE.ORG.05  the daily close selects by the registry;
  ROUTE.ORG.06  the FIE flag and every type set read the registry, and no module
                under python/ matches a code prefix or writes an organizer by hand;
  ROUTE.ORG.07  the post-commit hooks take the registry's organizer;
  ROUTE.ORG.08  the weapon-rename exception asks the registry for a PEW event;
  ROUTE.ORG.09  the matcher's domestic branch reads the registry;
  ROUTE.ORG.10  the minimum helper routes as the database does (not a registry fact);
  ROUTE.ORG.11  the staging tool takes the registry's organizer;
  ROUTE.ORG.12  the domestic fencer scan counts every SPWS family, GP included;
  ROUTE.ORG.13  the handbook's organizer and family tables list exactly the registry.

ROUTE.ORG.07–12 close the gaps the audit of 31 Oct 2026 found after release 1's
first cut (plan §03, G10–G13).
"""

from __future__ import annotations

import re
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "supabase" / "seed_prod_latest.sql"

#       code                   type    organizer  route
PINS = [
    ("PPW1-2026-2027", "PPW", "SPWS", "domestic"),
    ("PPW12-2026-2027", "PPW", "SPWS", "domestic"),
    ("MPW-2026-2027", "MPW", "SPWS", "domestic"),
    ("PPS1s-2026-2027", "PPS", "PZSz", "roster"),
    ("PPS2Wefs-2026-2027", "PPS", "PZSz", "roster"),
    ("MPS-2026-2027", "MPS", "PZSz", "roster"),
    ("MPSMe-2026-2027", "MPS", "PZSz", "roster"),
    ("PEW2efs-2026-2027", "PEW", "EVF", "international"),
    ("PEW10e-2026-2027", "PEW", "EVF", "international"),
    ("MEW-2026-2027", "MEW", "EVF", "international"),
    ("IMEW-2026-2027", "MEW", "EVF", "international"),
    ("DMEW-2025-2026", "MPW", "EVF", None),  # the team championship: never ingested
    ("MSW-2026-2027", "MSW", "FIE", "international"),
    ("IMSW-2025-2026", "MSW", "FIE", "international"),
    ("PSW-2026-2027", "PSW", "FIE", "international"),
    ("GP1-2023-2024", "PPW", "SPWS", None),  # a closed season's Grand Prix: never ingested
    ("GP8-2023-2024", "PPW", "SPWS", None),
]
NOT_ON_THE_ROUTE = [
    "VFC-2023-2024",
    "GPW1-2023-2024",
    "PS-2024-2025",
    "PPW-2026-2027",
    "PEWx-2026-2027",
    "",
]


@pytest.mark.parametrize(("code", "ttype", "organizer", "route"), PINS)
def test_ROUTE_ORG_01_every_family_keeps_its_type_and_gets_its_true_organizer(
    code, ttype, organizer, route
):
    from python.pipeline import organizers
    from python.pipeline.db_connector import derive_tourn_type_from_event_code
    from python.pipeline.stages import _is_international_intake, _organizer_for_event

    assert organizers.tournament_type(code) == ttype
    assert derive_tourn_type_from_event_code(code) == ttype
    assert organizers.organizer_of(code) == organizer
    assert _organizer_for_event({"txt_code": code}) == organizer
    assert organizers.route_of(code) == route
    assert _is_international_intake({"txt_code": code}) is (route == organizers.INTERNATIONAL)


@pytest.mark.parametrize("code", NOT_ON_THE_ROUTE)
def test_ROUTE_ORG_01b_a_code_of_no_registered_family_has_no_type_organizer_or_route(code):
    from python.pipeline import organizers
    from python.pipeline.db_connector import derive_tourn_type_from_event_code
    from python.pipeline.stages import _organizer_for_event

    assert organizers.tournament_type(code) is None
    assert derive_tourn_type_from_event_code(code) is None
    assert _organizer_for_event({"txt_code": code}) == "UNKNOWN"
    assert organizers.route_of(code) is None


def _seed_events() -> list[tuple[str, str]]:
    text = SEED.read_text(encoding="utf-8")
    return re.findall(
        r"INSERT INTO tbl_event \([^)]*\) VALUES \(.*?WHERE txt_code = '[^']*'\), "
        r"\(SELECT id_organizer FROM tbl_organizer WHERE txt_code = '([^']*)'\), '([^']*)'",
        text,
    )


def test_ROUTE_ORG_02_the_registry_agrees_with_the_prod_seed():
    """Every organizer PROD holds is registered; every PROD event of a registered
    family belongs to the organizer the registry names. The one unregistered
    code is VFC-2023-2024: an event row with no bracket, whose type nothing
    stored records and whose organizer the 2023/24 importers disagree on, so
    the registry names nothing for it rather than guess."""
    from python.pipeline import organizers

    text = SEED.read_text(encoding="utf-8")
    held = set(re.findall(r"INSERT INTO tbl_organizer \([^)]*\) VALUES \('([^']+)'", text))
    assert held == set(organizers.ORGANIZERS), held
    events = _seed_events()
    assert len(events) > 100
    unregistered = set()
    for stored, code in events:
        family = organizers.family_of(code)
        if family is None:
            unregistered.add(code)
            continue
        assert family.organizer == stored, (code, stored, family.organizer)
    assert unregistered == {"VFC-2023-2024"}, unregistered


def test_ROUTE_ORG_03_an_unregistered_family_is_refused_by_name_before_anything_is_read():
    from python.pipeline import ingest_cli

    db = MagicMock()
    db.find_event_by_code.return_value = {
        "id_event": 9,
        "txt_code": "USW1-2026-2027",
        "url_event": "https://www.fencingtimelive.com/tournaments/eventSchedule/AB12",
    }
    with (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client") as ftl,
        patch("python.pipeline.international_sources.read_brackets") as read,
        pytest.raises(ValueError, match=r"USW1-2026-2027.*organizers\.py"),
    ):
        ingest_cli.ingest_event_from_url(
            event_code="USW1-2026-2027", season_end_year=2027, db=db, record_run="cert"
        )
    ftl.assert_not_called()
    read.assert_not_called()
    db.open_ingest_run.assert_not_called()


def test_ROUTE_ORG_04_a_fifth_organizer_needs_nothing_outside_the_registry():
    """A fixture federation, "XVF", with its own code family XVC: it is
    international and not FIE-like. Registered, its event is ingested through
    the international driver with its own organizer label, and promote's plan
    takes the same driver; nothing else knows it."""
    from python.pipeline import ingest_cli, organizers
    from python.pipeline.engine.flows import Flow
    from python.pipeline.promotion import plan as pl
    from python.tests.test_route_international import _committed, _recs

    fifth = organizers.Organizer("XVF", "A fixture veterans federation", organizers.INTERNATIONAL)
    family = organizers.Family("XVC", r"XVC[0-9]+", "PEW", "XVF")
    with (
        patch.dict(organizers.ORGANIZERS, {"XVF": fifth}),
        patch.object(organizers, "FAMILIES", (*organizers.FAMILIES, family)),
    ):
        assert organizers.route_of("XVC1-2026-2027") == organizers.INTERNATIONAL
        assert not organizers.fie_like_type("PEW")
        db = MagicMock()
        db.find_event_by_code.return_value = {
            "id_event": 70,
            "txt_code": "XVC1-2026-2027",
            "url_event": "https://www.fencingtimelive.com/tournaments/eventSchedule/US01",
            "dt_start": "2026-11-07",
            "dt_end": "2026-11-08",
        }
        db.open_ingest_run.return_value = 9
        db.finish_ingest_run.return_value = {}
        flow = MagicMock(side_effect=_committed)
        kept = [
            {"uuid": "A1", "name": "x", "finished": True},
            {"uuid": "A2", "name": "y", "finished": True},
        ]
        with (
            patch(
                "python.pipeline.international_sources.read_brackets",
                return_value=(_recs(), kept, []),
            ),
            patch("python.pipeline.ingest_cli._run_parsed_through_flow", side_effect=flow),
            patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None),
            patch("python.pipeline.ingest_cli._after_event_run"),
        ):
            ingest_cli.ingest_event_from_url(
                event_code="XVC1-2026-2027",
                season_end_year=2027,
                db=db,
                replace=True,
                record_run="cert",
            )
        assert flow.call_count == 2
        for call in flow.call_args_list:
            assert call.kwargs["flow"] == Flow.INGEST_INTERNATIONAL
            assert call.args[0].organizer_hint == "XVF"

        prod = MagicMock()
        prod.find_event_by_code.return_value = {
            **db.find_event_by_code.return_value,
            "url_event": None,
        }
        with patch("python.pipeline.ingest_cli._ingest_event_rounds", return_value=[]) as rounds:
            pl.plan_event(
                "XVC1-2026-2027",
                2027,
                prod,
                url_event="https://www.fencingtimelive.com/tournaments/eventSchedule/US01",
                created=[],
                sources=[
                    {
                        "slot": "url_event",
                        "url": "https://www.fencingtimelive.com/tournaments/eventSchedule/US01",
                    }
                ],
            )
        assert rounds.call_args.kwargs["sources"] is not None


def test_ROUTE_ORG_05_the_daily_close_selects_by_the_registry():
    from python.pipeline import organizers
    from python.pipeline.promotion import close

    regex = close.route_code_regex()
    for code, _t, _o, route in PINS:
        assert bool(re.match(regex, code)) is (route is not None), code
    for code in NOT_ON_THE_ROUTE:
        assert not re.match(regex, code), code
    transport = MagicMock()
    transport.fetch_json.return_value = []
    close.SqlEnv("cert", transport).events_to_close(__import__("datetime").date(2026, 11, 2))
    sql = transport.fetch_json.call_args.args[0]
    assert f"e.txt_code ~ '{regex}'" in sql
    family = organizers.Family("XVC", r"XVC[0-9]+", "PEW", "XVF")
    fifth = organizers.Organizer("XVF", "fixture", organizers.INTERNATIONAL)
    with (
        patch.dict(organizers.ORGANIZERS, {"XVF": fifth}),
        patch.object(organizers, "FAMILIES", (*organizers.FAMILIES, family)),
    ):
        assert re.match(close.route_code_regex(), "XVC1-2026-2027")


def test_ROUTE_ORG_06_the_fie_flag_and_every_type_set_read_the_registry():
    from python.matcher import pipeline as matcher
    from python.pipeline import organizers
    from python.pipeline.international_admission import FIE_TYPES, is_fie_type
    from python.pipeline.joined_brackets import INTERNATIONAL_TYPES

    assert FIE_TYPES == frozenset({"MSW", "PSW"}) == organizers.fie_like_types()
    assert is_fie_type("MSW") and is_fie_type("psw") and not is_fie_type("PEW")
    assert not is_fie_type(None)
    assert (
        INTERNATIONAL_TYPES
        == frozenset({"PEW", "MEW", "MSW", "PSW"})
        == organizers.international_types()
    )
    assert set(matcher.INTERNATIONAL_TYPES) == set(INTERNATIONAL_TYPES)
    found = []
    for path in sorted((ROOT / "python").rglob("*.py")):
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith("python/tests/") or rel == "python/pipeline/organizers.py":
            continue
        text = path.read_text(encoding="utf-8")
        for label, pattern in HAND_WRITTEN:
            if re.search(pattern, text) and (rel, label) not in OTHER_FACTS:
                found.append((rel, label))
    assert found == [], found


# What only the registry may state, and how a module states it by hand.
HAND_WRITTEN = [
    ("prefix match", r"startswith\(\(?\"(PPW|MPW|PEW|MEW|MSW|PSW|PPS|MPS|IMEW|IMSW|DMEW|GP|PS)\""),
    ("organizer by hand", r"\"(SPWS|EVF|FIE|PZSz)\"\s+if\s"),
    ("domestic types", r"[\(\{\[]\"PPW\", \"MPW\"[\)\}\]]"),
    ("international types", r"[\(\{\[]\"PEW\", \"MEW\", \"MSW\""),
    ("a family no event has", r"\"GPW\""),
    ("alternation codes", r"IMSW\)"),
]
# Sets that look like the registry's and state another fact, each with its owner.
OTHER_FACTS = {
    # ADR-066's minimum routing: {PPW, MPW, PSW} take the domestic minimum and
    # {PEW, MEW, MSW} the EVF one; pgTAP SS26.TYPE.02 pins it (ROUTE.ORG.10).
    ("python/scrapers/base.py", "international types"),
    # The tournament types EVF's results API scores (ADR-028), not the route's.
    ("python/tools/evf_event_completeness.py", "international types"),
}


@pytest.mark.parametrize(
    ("code", "organizer"),
    [(c, o) for c, _t, o, _r in PINS] + [(c, "UNKNOWN") for c in NOT_ON_THE_ROUTE],
)
def test_ROUTE_ORG_07_the_post_commit_hooks_take_the_registry_organizer(code, organizer):
    """The EVF parity gate runs for EVF's events. It guessed by prefix and read
    IMEW, DMEW, IMSW, PSW and the PZSz families as UNKNOWN (G10)."""
    from python.pipeline.commit_lifecycle import _organizer_code

    assert _organizer_code({"txt_code": code}) == organizer
    assert _organizer_code({"txt_code": code, "txt_organizer_code": "fie"}) == "FIE"


@pytest.mark.parametrize(
    ("code", "pew"),
    [
        ("PEW3-2025-2026", True),
        ("PEW10efs-2026-2027", True),
        ("PEWx-2026-2027", False),
        ("PEW-2026-2027", False),
        ("MEW-2026-2027", False),
        ("", False),
    ],
)
def test_ROUTE_ORG_08_the_weapon_rename_exception_asks_the_registry(code, pew):
    """ADR-046's weapon-rename exception holds for the PEW family only; a code
    that merely starts with PEW is no PEW event (G10)."""
    from python.pipeline.url_validation import _is_pew

    assert _is_pew({"txt_code": code}) is pew


def test_ROUTE_ORG_09_the_matcher_domestic_branch_reads_the_registry():
    from python.matcher import pipeline as matcher
    from python.pipeline import orchestrator, organizers

    assert organizers.domestic_types() == frozenset({"PPW", "MPW"})
    assert isinstance(matcher.DOMESTIC_TYPES, frozenset)
    assert matcher.DOMESTIC_TYPES == organizers.domestic_types()
    assert orchestrator.DOMESTIC_TYPES is matcher.DOMESTIC_TYPES


def test_ROUTE_ORG_10_the_minimum_helper_routes_as_the_database_does():
    """Not a registry fact. ADR-066 routes PSW to the domestic minimum and
    PEW, MEW and MSW to the EVF one, and the database holds it per type
    (pgTAP SS26.TYPE.02); the helper agrees with it, not with the route."""
    from python.scrapers.base import check_min_participants

    sql = (ROOT / "supabase" / "tests" / "80_season_scoring_contract.sql").read_text(
        encoding="utf-8"
    )
    assert "{PPW,MPW,PSW}->ppw and {PEW,MEW,MSW}->evf" in sql
    for ttype in ("PEW", "MEW", "MSW"):
        assert check_min_participants(2, ttype, min_evf=3, min_ppw=1)["rejected"], ttype
    for ttype in ("PPW", "MPW", "PSW", "PPS", "MPS"):
        assert not check_min_participants(2, ttype, min_evf=3, min_ppw=1)["rejected"], ttype


@pytest.mark.parametrize(
    ("prefix", "organizer"),
    [
        ("PPW1", "SPWS"),
        ("GP3", "SPWS"),
        ("MPW", "SPWS"),
        ("PEW2", "EVF"),
        ("IMEW", "EVF"),
        ("MSW", "FIE"),
        ("IMSW", "FIE"),
        ("PSW", "FIE"),
        ("PPS1s", "PZSz"),
        ("VFC", "UNKNOWN"),
        ("PS", "UNKNOWN"),
    ],
)
def test_ROUTE_ORG_11_the_staging_tool_takes_the_registry_organizer(prefix, organizer):
    """The staging tool wrote IMEW, the PZSz families and VFC under SPWS (G12)."""
    from python.tools.staging_spreadsheet import _organizer_code

    assert _organizer_code(prefix) == organizer


def test_ROUTE_ORG_12_the_domestic_fencer_scan_counts_every_spws_family(tmp_path):
    """ADR-019 keeps the fencers with a domestic start. The scan looked for
    "GPW", a code no file holds, and missed every 2023/24 Grand Prix (G13)."""
    from python.tools.sort_and_clean_fencers import scan_ppw_mpw_fencer_ids

    rows = [
        (12, "GP1-V2-M-EPEE-2023-2024"),
        (13, "PEW1-V2-M-EPEE-2024-2025"),
        (14, "PPW3-V1-F-FOIL-2025-2026"),
        (15, "DMEW-V2-M-SABRE-2025-2026"),
        (16, "MPW-V0-M-EPEE-2024-2025"),
        (17, "IMSW-V3-M-EPEE-2024-2025"),
    ]
    text = "\n".join(
        "INSERT INTO tbl_result (id_fencer, id_tournament, int_place)\nVALUES (\n"
        f"    {fid},\n"
        f"    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{code}'),\n"
        "    1);"
        for fid, code in rows
    )
    (tmp_path / "v2_m_epee.sql").write_text(text, encoding="utf-8")
    assert scan_ppw_mpw_fencer_ids(tmp_path) == {12, 14, 16}


def test_ROUTE_ORG_13_the_handbook_tables_list_exactly_the_registry():
    """doc/handbook/reference/organizers-and-engines.html carries the registry
    for readers; it may not drift from organizers.py (ENGINE.03 pins its
    engine table the same way)."""
    from python.pipeline import organizers

    page = (ROOT / "doc/handbook/reference/organizers-and-engines.html").read_text(encoding="utf-8")
    orgs = re.search(r'<table id="organizers">(.*?)</table>', page, re.S)
    assert orgs, "the handbook page has no organizer table"
    listed = re.findall(
        r'<tr data-organizer="([A-Za-z]+)" data-route="([a-z]+)" data-fie-like="(yes|no)"',
        orgs.group(1),
    )
    assert sorted(listed) == sorted(
        (o.code, o.route, "yes" if o.fie_like else "no") for o in organizers.ORGANIZERS.values()
    )
    families = re.search(r'<table id="families">(.*?)</table>', page, re.S)
    assert families, "the handbook page has no family table"
    rows = re.findall(
        r'<tr data-family="([A-Z]+)" data-type="([A-Z]+)" '
        r'data-organizer="([A-Za-z]+)" data-route="([a-z]+)"',
        families.group(1),
    )
    assert sorted(rows) == sorted(
        (f.name, f.tournament_type, f.organizer, organizers.route_of_family(f) or "none")
        for f in organizers.FAMILIES
    )
