"""
FR-125-FR-129 (RTM): FTL clean-roster seed export (ADR-080).

New module python/pipeline/ftl_seed_export.py — NOT a reuse of export_seed.py
(that's the unrelated ADR-036 whole-DB backup exporter; confirmed 2026-07-04).

Covers the pure, unit-testable core of the exporter:
- canonical name casing (Nom=UPPERCASE, Prenom=Title case)
- (N) category-marker formatting
- mix-all pool interleave ("snake by rank" across the 10 sub-rankings, ADR-080 §2)
- predicted combined DE bracket accumulation (T=4, left-to-right ascending, ADR-080 §3)
- seed file naming convention (ADR-080 §4)
- FIE XML generation (ADR-080 §1): no DateNaissance, no Lateralite, Club="",
  Licence="", canonical Nom/Prenom, (N) marker survives into Prenom.

DB-querying glue (fn_ranking_ppw + tbl_fencer join, tbl_registration query —
every declared registration, no payment filter) is integration-level and
exercised separately against LOCAL.
"""

from __future__ import annotations

import defusedxml.ElementTree as ET

from python.pipeline.ftl_seed_export import (
    FencerEntry,
    build_fie_xml,
    combined_bracket_scope,
    format_prenom_with_marker,
    interleave_mixall,
    predict_combined_brackets,
    seed_filename,
    to_canonical_name,
)


# ---------------------------------------------------------------------------
# Canonical name casing (ADR-080 §1)
# ---------------------------------------------------------------------------
def test_to_canonical_name_basic():
    assert to_canonical_name("Kowalski", "jan") == ("KOWALSKI", "Jan")


def test_to_canonical_name_hyphenated_surname_stays_fully_uppercase():
    assert to_canonical_name("spława-neyman", "maciej") == ("SPŁAWA-NEYMAN", "Maciej")


def test_to_canonical_name_hyphenated_given_name_title_cased_per_segment():
    assert to_canonical_name("nowak", "anna-maria") == ("NOWAK", "Anna-Maria")


def test_to_canonical_name_fixes_legacy_all_caps_given_name():
    # ADR-080: "normalised on export (fixes legacy all-caps given names)"
    assert to_canonical_name("SPŁAWA-NEYMAN", "MACIEJ") == ("SPŁAWA-NEYMAN", "Maciej")


def test_to_canonical_name_trims_whitespace():
    assert to_canonical_name("  Kowalski  ", "  Jan  ") == ("KOWALSKI", "Jan")


# ---------------------------------------------------------------------------
# (N) category marker (ADR-080 §1)
# ---------------------------------------------------------------------------
def test_format_prenom_with_marker():
    assert format_prenom_with_marker("Jan", "2") == "Jan (2)"


def test_format_prenom_with_marker_vcat_zero():
    assert format_prenom_with_marker("Sandra", "0") == "Sandra (0)"


# ---------------------------------------------------------------------------
# Mix-all pool interleave — "snake by rank" (ADR-080 §2)
# ---------------------------------------------------------------------------
def test_interleave_mixall_matches_worked_example_order():
    # Mirrors the ADR-080 §2 worked example shape: FV3 empty (skipped), every
    # other sub-ranking has exactly one rank-1 entry except FV0 which also has
    # a rank-2 entry (seed 10 in the real example).
    sub_rankings = {
        "FV0": [FencerEntry(1, "PECZEK", "Sandra"), FencerEntry(10, "SZMAJDZINSKA", "Katarzyna")],
        "FV1": [FencerEntry(2, "KAMINSKA", "Gabriela")],
        "FV2": [FencerEntry(3, "WASILCZUK", "Beata")],
        "FV3": [],
        "FV4": [FencerEntry(4, "BORKOWSKA", "Halina")],
        "MV0": [FencerEntry(5, "SPLAWA-NEYMAN", "Maciej")],
        "MV1": [FencerEntry(6, "SEKOWSKI", "Maciej")],
        "MV2": [FencerEntry(7, "JENDRYS", "Marek")],
        "MV3": [FencerEntry(8, "KRZEMINSKI", "Mariusz")],
        "MV4": [FencerEntry(9, "SZCZESNY", "Jacek")],
    }
    order = interleave_mixall(sub_rankings)
    ids_in_order = [entry.id_fencer for entry, _vcat_key in order]
    # rank-1 pass: FV0,FV1,FV2,(FV3 skipped),FV4,MV0..MV4 = ids 1,2,3,4,5,6,7,8,9
    # rank-2 pass: only FV0 has a second entry = id 10
    assert ids_in_order == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    assert order[0][1] == "FV0"
    assert order[3][1] == "FV4"  # FV3 correctly skipped, FV4 is 4th not 5th
    assert order[-1][1] == "FV0"  # the rank-2 entry is still tagged with its sub-ranking


def test_interleave_mixall_empty_input():
    assert interleave_mixall({}) == []


def test_interleave_mixall_all_empty_sub_rankings():
    assert interleave_mixall({"FV0": [], "MV0": []}) == []


# ---------------------------------------------------------------------------
# Predicted combined DE brackets — T=4, left-to-right ascending (ADR-080 §3)
# ---------------------------------------------------------------------------
def test_predict_combined_brackets_exact_t_closes_singleton():
    # V0 alone already hits T=4 -> closes on its own; V1..V4 (1 each) accumulate
    # to exactly 4 -> a second bracket. No merging needed, no trailing leftover.
    counts = {"V0": 4, "V1": 1, "V2": 1, "V3": 1, "V4": 1}
    assert predict_combined_brackets(counts, t=4) == [["V0"], ["V1", "V2", "V3", "V4"]]


def test_predict_combined_brackets_skips_empty_categories_for_adjacency():
    # V1 empty -> V0 and V2 become adjacent in the LIVE sequence and may combine.
    counts = {"V0": 1, "V1": 0, "V2": 3, "V3": 0, "V4": 1}
    # V0(1)->1, V2(3)->4 close [V0,V2]; V4(1)->1 trailing, folds into previous.
    assert predict_combined_brackets(counts, t=4) == [["V0", "V2", "V4"]]


def test_predict_combined_brackets_trailing_leftover_folds_into_previous():
    counts = {"V0": 1, "V1": 1, "V2": 1, "V3": 1, "V4": 1}
    # V0..V3 accumulate to 4 and close; V4(1) is a trailing sub-T leftover.
    assert predict_combined_brackets(counts, t=4) == [["V0", "V1", "V2", "V3", "V4"]]


def test_predict_combined_brackets_whole_weapon_gender_under_t_is_one_bracket():
    counts = {"V0": 1, "V2": 1}
    assert predict_combined_brackets(counts, t=4) == [["V0", "V2"]]


def test_predict_combined_brackets_all_empty_returns_no_brackets():
    assert predict_combined_brackets({"V0": 0, "V1": 0}, t=4) == []


# ---------------------------------------------------------------------------
# File naming (ADR-080 §4)
# ---------------------------------------------------------------------------
def test_seed_filename_mixall():
    assert (
        seed_filename("SPWS-2025-2026", "PPW5", "E", "mixall") == "SPWS-2025-2026_PPW5_E_mixall.xml"
    )


def test_seed_filename_single_de_bracket():
    assert seed_filename("SPWS-2025-2026", "PPW5", "E", "M-V2") == "SPWS-2025-2026_PPW5_E_M-V2.xml"


def test_seed_filename_combined_de_bracket():
    assert (
        seed_filename("SPWS-2025-2026", "PPW5", "E", "M-V0V1") == "SPWS-2025-2026_PPW5_E_M-V0V1.xml"
    )


def test_combined_bracket_scope_single_category():
    assert combined_bracket_scope("M", ["V2"]) == "M-V2"


def test_combined_bracket_scope_combined_categories_joined_compact():
    assert combined_bracket_scope("F", ["V3", "V4"]) == "F-V3V4"


# ---------------------------------------------------------------------------
# FIE XML generation (ADR-080 §1)
# ---------------------------------------------------------------------------
def test_build_fie_xml_omits_datenaissance_and_lateralite():
    xml_text = build_fie_xml(
        root_id="spws-ppw-e-mixall",
        weapon_code="E",
        gender_code="M",
        title="SPWS Szpada ELIMINACJE (mix-all) 2025/2026",
        tireurs=[{"id": 1, "nom": "KOWALSKI", "prenom": "Jan (2)", "sexe": "M", "classement": 1}],
    )
    assert "DateNaissance" not in xml_text
    assert "Lateralite" not in xml_text


def test_build_fie_xml_root_attributes():
    xml_text = build_fie_xml(
        root_id="spws-ppw-e-mixall",
        weapon_code="E",
        gender_code="M",
        title="Title",
        tireurs=[],
    )
    root = ET.fromstring(xml_text.split("\n", 2)[-1] if xml_text.startswith("<?xml") else xml_text)
    assert root.tag == "BaseCompetitionIndividuelle"
    assert root.get("Arme") == "E"
    assert root.get("ID") == "spws-ppw-e-mixall"
    assert root.get("Federation") == "POL"
    assert root.get("Date") == ""


def test_build_fie_xml_tireur_attributes_canonical_and_empty_club_licence():
    xml_text = build_fie_xml(
        root_id="x",
        weapon_code="S",
        gender_code="F",
        title="Title",
        tireurs=[{"id": 7, "nom": "NOWAK", "prenom": "Anna (1)", "sexe": "F", "classement": 3}],
    )
    root = ET.fromstring(xml_text.split("\n", 2)[-1] if xml_text.startswith("<?xml") else xml_text)
    tireur = root.find(".//Tireur")
    assert tireur is not None
    assert tireur.get("Nom") == "NOWAK"
    assert tireur.get("Prenom") == "Anna (1)"
    assert tireur.get("Sexe") == "F"
    assert tireur.get("Classement") == "3"
    assert tireur.get("Club") == ""
    assert tireur.get("Licence") == ""
    assert tireur.get("Nation") == "POL"


def test_build_fie_xml_multiple_tireurs_preserve_order():
    xml_text = build_fie_xml(
        root_id="x",
        weapon_code="E",
        gender_code="M",
        title="Title",
        tireurs=[
            {"id": 1, "nom": "AAA", "prenom": "A (0)", "sexe": "M", "classement": 1},
            {"id": 2, "nom": "BBB", "prenom": "B (1)", "sexe": "F", "classement": 2},
        ],
    )
    root = ET.fromstring(xml_text.split("\n", 2)[-1] if xml_text.startswith("<?xml") else xml_text)
    tireurs = root.findall(".//Tireur")
    assert [t.get("Nom") for t in tireurs] == ["AAA", "BBB"]
