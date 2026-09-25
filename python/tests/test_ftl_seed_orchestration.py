"""
FR-125–FR-129 (RTM): FTL seed export — DB-querying orchestration layer (ADR-080).

The pure primitives (canonical name, interleave, bracket prediction, XML) are
covered in test_ftl_seed_export.py. This file covers the orchestration that ties
them to the event's data (ADR-080 §2, resolved 2026-07-05):

- POPULATION = every DECLARED tbl_registration row for the event (no payment
  gate — user 2026-07-04: "the correct list of names which declared intent to
  participate"). ORDERING within each sub-ranking comes from the current-season
  ranking fn_ranking_ppw: matched+ranked registrants seed in rank order,
  unranked ones (new fencers, or matched-but-never-scored) append after, ordered
  by registration timestamp (ts_created) for a deterministic result.
- The (N) marker is derived from the registration's DECLARED birth year (the
  read-only invariant — never tbl_fencer's), via age_split.birth_year_to_vcat.

The thin Supabase glue (FtlSeedExporter) is smoke-tested with a mocked client,
matching the test_draft_store.py convention; full E2E is validated on LOCAL.
"""

from __future__ import annotations

import io
import zipfile
from unittest.mock import MagicMock

import defusedxml.ElementTree as ET

from python.pipeline.ftl_seed_export import (
    assemble_mixall_subrankings,
    build_event_mixall_files,
    build_event_seed_files,
    bundle_seed_zip,
    export_manifest,
    mixall_tireurs,
    mixall_title,
    registration_subranking_key,
    season_pretty,
)

# Season 2025-2026 → season_end_year 2026. Helper for readable birth years.
SEY = 2026


def _reg(idf, sur, first, gender, by, weapons, ts="2026-01-01T00:00:00Z", club=None):
    return {
        "id_fencer": idf,
        "txt_surname": sur,
        "txt_first_name": first,
        "enum_gender": gender,
        "int_birth_year": by,
        "arr_weapons": weapons,
        "ts_created": ts,
        "txt_club": club,
    }


# ---------------------------------------------------------------------------
# registration_subranking_key — declared gender + declared BY → sub-ranking key
# ---------------------------------------------------------------------------
def test_subranking_key_men_v0():
    # 2026 - 1990 = 36 → V0
    assert registration_subranking_key("M", 1990, SEY) == "MV0"


def test_subranking_key_women_v2():
    # 2026 - 1970 = 56 → V2
    assert registration_subranking_key("F", 1970, SEY) == "FV2"


def test_subranking_key_too_young_is_none():
    # 2026 - 2005 = 21 → below V0 (veteran floor is 30) → no key
    assert registration_subranking_key("M", 2005, SEY) is None


# ---------------------------------------------------------------------------
# assemble_mixall_subrankings — population=registrations, order=ranking
# ---------------------------------------------------------------------------
def test_assemble_filters_by_declared_weapon():
    regs = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
        _reg(2, "Nowak", "Piotr", "M", 1990, ["FOIL"]),  # not epee → excluded
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    all_ids = [e.id_fencer for entries in subr.values() for e in entries]
    assert all_ids == [1]


def test_assemble_buckets_by_gender_and_vcat_with_canonical_names():
    regs = [
        _reg(1, "kowalski", "jan", "M", 1990, ["EPEE"]),  # MV0
        _reg(2, "nowak", "ANNA", "F", 1970, ["EPEE"]),  # FV2
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    assert set(subr) == {"MV0", "FV2"}
    assert (subr["MV0"][0].surname, subr["MV0"][0].first_name) == ("KOWALSKI", "Jan")
    assert (subr["FV2"][0].surname, subr["FV2"][0].first_name) == ("NOWAK", "Anna")


def test_assemble_ranked_before_unranked_then_by_ts():
    # Three MV0 epee registrants: id 30 ranked #1, id 10 ranked #2, id None unranked.
    regs = [
        _reg(None, "Zzz", "Unranked", "M", 1990, ["EPEE"], ts="2026-02-01T00:00:00Z"),
        _reg(10, "Bbb", "Second", "M", 1990, ["EPEE"]),
        _reg(30, "Aaa", "First", "M", 1990, ["EPEE"]),
    ]
    rankings = {"MV0": [30, 10]}  # rank order: id 30 first, id 10 second
    subr = assemble_mixall_subrankings(regs, "EPEE", rankings, SEY)
    assert [e.surname for e in subr["MV0"]] == ["AAA", "BBB", "ZZZ"]


def test_assemble_carries_the_true_rank_not_the_position_among_entrants():
    """The rank that reaches the interleave is the fencer's position in the
    WHOLE sub-ranking, not among those who entered. Here ranks 1-3 stayed at
    home and only the 4th-placed fencer registered; she is rank 4, and it is
    interleave_mixall's job to lay her down with the other 4th places rather
    than treat her as a category winner (PPW1 2026, EPEE FV0)."""
    regs = [_reg(44, "Szklar", "Bozena", "F", 1992, ["EPEE"])]
    rankings = {"FV0": [11, 22, 33, 44, 55]}  # she is genuinely 4th of five
    subr = assemble_mixall_subrankings(regs, "EPEE", rankings, SEY)
    assert subr["FV0"][0].rank == 4


def test_assemble_leaves_rank_none_for_a_fencer_with_no_points():
    """None is not rank 0 and not "last": it is the absence of a ranking, which
    is what puts the entry in the unranked tail."""
    regs = [
        _reg(None, "Newcomer", "Ewa", "F", 1992, ["EPEE"]),
        _reg(99, "Matched", "Ola", "F", 1992, ["EPEE"]),  # matched but absent from the ranking
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {"FV0": [11]}, SEY)
    assert [e.rank for e in subr["FV0"]] == [None, None]


def test_assemble_multiple_unranked_ordered_by_ts_created():
    regs = [
        _reg(None, "Later", "B", "M", 1990, ["EPEE"], ts="2026-03-01T00:00:00Z"),
        _reg(None, "Earlier", "A", "M", 1990, ["EPEE"], ts="2026-01-01T00:00:00Z"),
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    assert [e.surname for e in subr["MV0"]] == ["EARLIER", "LATER"]


# ---------------------------------------------------------------------------
# mixall_tireurs — seed order → FIE Tireur dicts
# ---------------------------------------------------------------------------
def test_mixall_tireurs_running_id_sexe_and_marker():
    regs = [
        _reg(1, "Peczek", "Sandra", "F", 1990, ["EPEE"]),  # FV0
        _reg(2, "Kowalski", "Jan", "M", 1970, ["EPEE"]),  # MV2
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    from python.pipeline.ftl_seed_export import interleave_mixall

    tireurs = mixall_tireurs(interleave_mixall(subr))
    # FV0 comes before MV2 in the fixed order → Sandra seed 1, Jan seed 2. The
    # records are then written alphabetically, so Jan comes first on the page
    # while keeping seed 2: element order is presentation, Classement is the
    # seed (ADR-080 §2, amended 2026-09-14).
    assert tireurs[0] == {
        "id": 2,
        "nom": "KOWALSKI (2)",
        "prenom": "Jan",
        "sexe": "M",
        "classement": 2,
    }
    assert tireurs[1] == {
        "id": 1,
        "nom": "PECZEK (0)",
        "prenom": "Sandra",
        "sexe": "F",
        "classement": 1,
    }


def test_mixall_tireurs_no_longer_carries_a_club():
    """ADR-080 amendment (f) is withdrawn (2026-09-24). 41 of PPW1's 90
    registrations declared a club and the free text was already unusable — one
    Poznan club arrived under three spellings, plus a "Wawrszawa" typo. The
    Tireur dict stops carrying one; build_fie_xml still writes the attribute,
    empty, as it did before the field existed."""
    regs = [_reg(1, "Peczek", "Sandra", "F", 1990, ["EPEE"], club="AZS AWFiS Gdańsk")]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    from python.pipeline.ftl_seed_export import interleave_mixall

    tireurs = mixall_tireurs(interleave_mixall(subr))
    assert "club" not in tireurs[0]


# ---------------------------------------------------------------------------
# season_pretty + mixall_title
# ---------------------------------------------------------------------------
def test_season_pretty():
    assert season_pretty("SPWS-2025-2026") == "2025/2026"


def test_mixall_title_polish_weapon_name():
    assert mixall_title("PPW5-2025-2026", "EPEE", ["M"], ["V0"]).startswith(
        "SPWS PPW5 2025/26 · SZPADA · ELIMINACJE MIX"
    )
    assert mixall_title("PPW5-2025-2026", "SABRE", ["M"], ["V0"]).startswith(
        "SPWS PPW5 2025/26 · SZABLA · ELIMINACJE MIX"
    )


# ---------------------------------------------------------------------------
# build_event_mixall_files — one mix-all file per weapon that has registrants
# ---------------------------------------------------------------------------
def test_build_event_mixall_files_one_per_weapon_with_registrants():
    regs = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE", "SABRE"]),
        _reg(2, "Nowak", "Anna", "F", 1970, ["EPEE"]),
    ]
    files = build_event_mixall_files(
        registrations=regs,
        weapons=["EPEE", "FOIL", "SABRE"],
        rankings_by_weapon={},
        event_code="PPW5-2025-2026",
        season_end_year=SEY,
    )
    # EPEE has 2, SABRE has 1, FOIL has 0 → FOIL omitted entirely.
    assert {n for n in files if "POOLS-MIXED" in n} == {
        "PPW5-2025-2026_EPEE_POOLS-MIXED_all-categories_W+M.xml",
        "PPW5-2025-2026_SABRE_POOLS-MIXED_all-categories_M.xml",
    }
    assert not [n for n in files if "FOIL" in n]
    root = ET.fromstring(
        files["PPW5-2025-2026_EPEE_POOLS-MIXED_all-categories_W+M.xml"].split("\n", 2)[-1]
    )
    assert root.get("ID") == "PPW5-2025-2026_EPEE_POOLS-MIXED_all-categories_W+M"
    assert root.get("Arme") == "E"
    assert len(root.findall(".//Tireur")) == 2


def test_build_event_mixall_files_interleave_and_marker_end_to_end():
    regs = [
        _reg(1, "Peczek", "Sandra", "F", 1990, ["EPEE"]),  # FV0
        _reg(2, "Borkowska", "Halina", "F", 1950, ["EPEE"]),  # FV3 (2026-1950=76)... V4
        _reg(3, "Kowalski", "Jan", "M", 1990, ["EPEE"]),  # MV0
    ]
    files = build_event_mixall_files(
        registrations=regs,
        weapons=["EPEE"],
        rankings_by_weapon={},
        event_code="PPW5-2025-2026",
        season_end_year=SEY,
    )
    root = ET.fromstring(
        files["PPW5-2025-2026_EPEE_POOLS-MIXED_all-categories_W+M.xml"].split("\n", 2)[-1]
    )
    tireurs = root.findall(".//Tireur")
    # Fixed order FV0,FV4,MV0 → Sandra(0), Halina(4), Jan(0); running Classement.
    # The marker rides on Nom (ADR-080 §1 amended 2026-09-12): FTL renders
    # "Nom Prenom", so this reads back as "PECZEK (0) Sandra" — the form the
    # scraper matches. It used to sit on Prenom, which did not round-trip.
    # Written alphabetically; the interleave seeds survive in Classement, out of
    # document order (ADR-080 §2, amended 2026-09-14).
    assert [t.get("Nom") for t in tireurs] == ["BORKOWSKA (4)", "KOWALSKI (0)", "PECZEK (0)"]
    assert [t.get("Prenom") for t in tireurs] == ["Halina", "Jan", "Sandra"]
    assert [t.get("Classement") for t in tireurs] == ["2", "3", "1"]


# ---------------------------------------------------------------------------
# bundle_seed_zip
# ---------------------------------------------------------------------------
def test_bundle_seed_zip_roundtrips_files():
    files = {"a.xml": "<a/>", "b.xml": "<b/>"}
    blob = bundle_seed_zip(files)
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        assert set(z.namelist()) == {"a.xml", "b.xml"}
        assert z.read("a.xml").decode() == "<a/>"


# ---------------------------------------------------------------------------
# FtlSeedExporter — thin Supabase glue (mocked client)
# ---------------------------------------------------------------------------
def test_exporter_fetch_registrations_queries_event():
    from python.pipeline.ftl_seed_export_db import FtlSeedExporter

    sb = MagicMock()
    sb.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value.data = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
    ]
    exp = FtlSeedExporter(sb)
    rows = exp.fetch_registrations(42)
    sb.table.assert_called_with("tbl_registration")
    assert rows[0]["txt_surname"] == "Kowalski"


def test_exporter_build_bundle_wires_rankings_and_returns_files():
    from python.pipeline.ftl_seed_export_db import FtlSeedExporter

    sb = MagicMock()
    # registrations: one EPEE man
    sb.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value.data = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
    ]
    # every fn_ranking_ppw rpc returns Jan ranked #1 in his sub-ranking
    sb.rpc.return_value.execute.return_value.data = [
        {"rank": 1, "id_fencer": 1, "fencer_name": "KOWALSKI Jan"},
    ]
    exp = FtlSeedExporter(sb)
    files = exp.build_bundle(
        id_event=42,
        weapons=["EPEE"],
        event_code="PPW5-2025-2026",
        season_end_year=SEY,
        season=None,
    )
    assert "PPW5-2025-2026_EPEE_POOLS-MIXED_all-categories_M.xml" in files
    # rpc was called for the ranking lookups (10 sub-rankings for one weapon)
    assert sb.rpc.call_count >= 1


# ---------------------------------------------------------------------------
# build_event_seed_files — the whole deliverable set, with its manifest
#
# One mix-all per weapon (the seeding order) plus ONE DE FILE PER GENDER x
# CATEGORY PRESENT (plan §1, replacing ADR-080 §3's predicted combining). Six of
# PPW1's 22 DE files hold a single fencer and four hold two; that is deliberate,
# and the manual tells the organizer to combine them in Fencing Time. We re-split
# by birth year when the results come back, so their combining costs us nothing —
# whereas guessing it wrong costs them a file that lies about its own contents.
# ---------------------------------------------------------------------------
def test_seed_files_emit_one_de_per_live_gender_and_category():
    """X7.10 — the maximal split, and nothing for a category nobody entered."""
    regs = [
        _reg(1, "Peczek", "Sandra", "F", 1990, ["EPEE"]),  # FV0
        _reg(2, "Kowalski", "Jan", "M", 1990, ["EPEE"]),  # MV0
        _reg(3, "Nowak", "Piotr", "M", 1970, ["EPEE"]),  # MV2
    ]
    seed = build_event_seed_files(
        registrations=regs,
        weapons=["EPEE"],
        rankings_by_weapon={},
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
    )
    names = {f.filename for f in seed}
    assert names == {
        "PPW1-2026-2027_EPEE_POOLS-MIXED_all-categories_W+M.xml",
        "PPW1-2026-2027_EPEE_DE_WOMEN_V0.xml",
        "PPW1-2026-2027_EPEE_DE_MEN_V0.xml",
        "PPW1-2026-2027_EPEE_DE_MEN_V2.xml",
    }


def test_de_file_holds_only_its_own_gender_and_category_reseeded_from_one():
    """X7.11 — a DE file is a standalone competition: Classement restarts at 1,
    and its root Sexe is the real gender (the mix-all's is nominal)."""
    regs = [
        _reg(1, "Aaa", "First", "M", 1970, ["EPEE"]),
        _reg(2, "Bbb", "Second", "M", 1970, ["EPEE"]),
        _reg(3, "Ccc", "Other", "F", 1970, ["EPEE"]),
    ]
    seed = build_event_seed_files(
        registrations=regs,
        weapons=["EPEE"],
        rankings_by_weapon={"EPEE": {"MV2": [2, 1]}},  # id 2 outranks id 1
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
    )
    de = next(f for f in seed if f.filename.endswith("_DE_MEN_V2.xml"))
    root = ET.fromstring(de.xml.split("\n", 2)[-1])
    assert root.get("Sexe") == "M"
    assert root.get("Arme") == "E"
    tireurs = root.findall(".//Tireur")
    # Alphabetical on the page, seeded in Classement: BBB outranks AAA, so BBB
    # is seed 1 even though AAA is written first.
    assert [t.get("Nom") for t in tireurs] == ["AAA (2)", "BBB (2)"]
    assert [t.get("Classement") for t in tireurs] == ["2", "1"]
    assert [t.get("Sexe") for t in tireurs] == ["M", "M"]


def test_seed_files_skip_a_weapon_nobody_entered():
    """X7.12 — no empty competitions; FTL cannot import one."""
    regs = [_reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"])]
    seed = build_event_seed_files(
        registrations=regs,
        weapons=["EPEE", "FOIL", "SABRE"],
        rankings_by_weapon={},
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
    )
    assert all("FOIL" not in f.filename and "SABRE" not in f.filename for f in seed)


def test_export_manifest_counts_and_import_kind_come_from_the_files_themselves():
    """X7.13 — §9's manifest is generated from the same objects that produced
    the XML, so it cannot drift from what the organizer actually downloaded."""
    regs = [
        _reg(1, "Peczek", "Sandra", "F", 1990, ["EPEE"]),
        _reg(2, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
    ]
    seed = build_event_seed_files(
        registrations=regs,
        weapons=["EPEE"],
        rankings_by_weapon={},
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
    )
    manifest = export_manifest(seed)
    mixall = next(r for r in manifest if r["kind"] == "MIXALL")
    assert mixall["count"] == 2
    assert mixall["import_as"] == "COMPETITION"
    assert mixall["title"].startswith("SPWS PPW1 2026/27 · SZPADA")
    de = [r for r in manifest if r["kind"] == "DE"]
    assert sorted(r["count"] for r in de) == [1, 1]


# ---------------------------------------------------------------------------
# The roster file — the organizer's pick-list (ADR-080 amendment (e))
#
# One per weapon, beside the competitions. Its population is a database
# question, not a function of this event's entry list, so it arrives as rows
# from fn_ftl_roster rather than being derived here. What this layer owns is
# turning those rows into a file that cannot be mistaken for a competition.
# ---------------------------------------------------------------------------
def _roster_row(sur, first, gender, cat, order):
    return {
        "txt_surname": sur,
        "txt_first_name": first,
        "enum_gender": gender,
        "enum_age_category": cat,
        "int_order": order,
    }


def test_seed_files_add_one_roster_per_weapon_when_rows_are_supplied():
    """X7.14 — 25 competition files become 28 for PPW1."""
    regs = [_reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE", "SABRE"])]
    rosters = {
        "EPEE": [_roster_row("Aaa", "Adam", "M", "V2", 1)],
        "SABRE": [_roster_row("Bbb", "Beata", "F", "V1", 1)],
        # FOIL deliberately present in the roster data but absent from the entry
        # list: no competition, so no roster either. A pick-list for a weapon
        # nobody is fencing is one more file to import by mistake.
        "FOIL": [_roster_row("Ccc", "Cezary", "M", "V0", 1)],
    }
    seed = build_event_seed_files(
        registrations=regs,
        weapons=["EPEE", "FOIL", "SABRE"],
        rankings_by_weapon={},
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
        rosters=rosters,
    )
    rosters_out = {f.filename for f in seed if f.kind == "ROSTER"}
    assert rosters_out == {
        "PPW1-2026-2027_EPEE_ROSTER_all-known-epee-fencers.xml",
        "PPW1-2026-2027_SABRE_ROSTER_all-known-sabre-fencers.xml",
    }


def test_roster_file_says_in_its_own_title_not_to_import_it_as_a_competition():
    """X7.15 — the one mistake on this surface that damages an event.

    The filename carries the warning because that is what the organizer reads in
    the file dialog; the title carries it because that is what Fencing Time
    shows once the file is already open.
    """
    seed = build_event_seed_files(
        registrations=[_reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"])],
        weapons=["EPEE"],
        rankings_by_weapon={},
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
        rosters={"EPEE": [_roster_row("Aaa", "Adam", "M", "V2", 1)]},
    )
    roster = next(f for f in seed if f.kind == "ROSTER")
    assert "ROSTER" in roster.filename
    assert roster.title == "SPWS · BAZA ZAWODNIKÓW — szpada (nie importować jako zawody)"
    assert roster.import_as == "PICKLIST"


def test_roster_tireurs_keep_the_marker_and_the_roster_order():
    """X7.16 — a roster entry is read back exactly like a seeded one.

    The marker is not decoration on a pick-list: a fencer ticked in from here
    reaches the results with the same "(N)" the pipeline reads, which is the
    whole reason ticking beats typing.
    """
    seed = build_event_seed_files(
        registrations=[_reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"])],
        weapons=["EPEE"],
        rankings_by_weapon={},
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
        rosters={
            "EPEE": [
                _roster_row("nowak", "anna", "F", "V3", 1),
                _roster_row("ZIELIŃSKI", "PIOTR", "M", "V0", 2),
            ]
        },
    )
    roster = next(f for f in seed if f.kind == "ROSTER")
    root = ET.fromstring(roster.xml.split("\n", 2)[-1])
    tireurs = root.findall(".//Tireur")
    assert [t.get("Nom") for t in tireurs] == ["NOWAK (3)", "ZIELIŃSKI (0)"]
    assert [t.get("Prenom") for t in tireurs] == ["Anna", "Piotr"]
    assert [t.get("Sexe") for t in tireurs] == ["F", "M"]
    assert roster.count == 2


def test_seed_files_without_rosters_are_unchanged():
    """X7.17 — the Telegram delivery path passes no rosters and must not break."""
    seed = build_event_seed_files(
        registrations=[_reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"])],
        weapons=["EPEE"],
        rankings_by_weapon={},
        event_code="PPW1-2026-2027",
        season_end_year=SEY,
    )
    assert [f.kind for f in seed] == ["MIXALL", "DE"]


def test_exporter_carries_total_score_so_a_tier_seeds_by_points():
    """The tier order the ORGANIZER receives must come from points, on this
    path too.

    This is the seam that broke. fetch_weapon_rankings read fn_ranking_ppw and
    kept only id_fencer, throwing total_score away, so every entry reached
    interleave_mixall with points=None and each tier silently fell back to the
    fixed FV0..MV4 sequence — while the browser download page, reading
    num_rank_points off fn_ftl_export_entries, ordered the same tier by points.
    One event, two generators, two different seed orders.

    The byte-for-byte parity test cannot see it: it hands both generators the
    same pre-built entries, so it compares the two halves downstream of the
    place where they disagree. The assertion has to start at the RPC.

    Jan is rank 1 of MV0 on 400 points; Anna is rank 1 of FV0 on 300. Both are
    tier 1. Alphabetically FV0 precedes MV0, so the old code seeded Anna first.
    """
    from python.pipeline.ftl_seed_export_db import FtlSeedExporter

    sb = MagicMock()
    sb.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value.data = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
        _reg(2, "Nowak", "Anna", "F", 1990, ["EPEE"]),
    ]

    def _ranking(_name, params):
        rows = {
            ("M", "V0"): [{"rank": 1, "id_fencer": 1, "total_score": 400.0}],
            ("F", "V0"): [{"rank": 1, "id_fencer": 2, "total_score": 300.0}],
        }.get((params["p_gender"], params["p_category"]), [])
        rpc = MagicMock()
        rpc.execute.return_value.data = rows
        return rpc

    sb.rpc.side_effect = _ranking

    files = FtlSeedExporter(sb).build_bundle(
        id_event=42,
        weapons=["EPEE"],
        event_code="PPW5-2025-2026",
        season_end_year=SEY,
        season=None,
    )
    # By name, not by filename: the suffix records which genders entered
    # (here W+M), and this test is about the order inside the file.
    doc = next(v for k, v in files.items() if "POOLS-MIXED" in k)
    # Nom carries the "(N)" category marker, so key on the surname it starts with.
    seeds = {
        (t.get("Nom") or "").split(" (")[0]: t.get("Classement")
        for t in ET.fromstring(doc).iter("Tireur")
    }
    assert seeds["KOWALSKI"] == "1", "the higher score takes the first seed of the tier"
    assert seeds["NOWAK"] == "2"
