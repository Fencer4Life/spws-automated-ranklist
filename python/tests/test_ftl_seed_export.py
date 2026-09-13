"""
FR-125-FR-129 (RTM): FTL clean-roster seed export (ADR-080).

New module python/pipeline/ftl_seed_export.py — NOT a reuse of export_seed.py
(that's the unrelated ADR-036 whole-DB backup exporter; confirmed 2026-07-04).

Covers the pure, unit-testable core of the exporter:
- canonical name casing (Nom=UPPERCASE, Prenom=Title case)
- (N) category-marker formatting (mid-name, ADR-080 §1 amended 2026-09-12)
- mix-all pool interleave ("snake by rank" across the 10 sub-rankings, ADR-080 §2)
- predicted combined DE bracket accumulation (T=4, left-to-right ascending, ADR-080 §3)
- seed file naming convention (ADR-080 §4)
- FIE XML generation (ADR-080 §1): no DateNaissance, no Lateralite, Club="",
  Licence="", canonical Nom/Prenom, (N) marker survives into Nom.

DB-querying glue (fn_ranking_ppw + tbl_fencer join, tbl_registration query —
every declared registration, no payment filter) is integration-level and
exercised separately against LOCAL.
"""

from __future__ import annotations

import defusedxml.ElementTree as ET

from python.pipeline.ftl_seed_export import (
    FencerEntry,
    build_fie_xml,
    de_title,
    export_filename,
    format_nom_with_marker,
    interleave_mixall,
    mixall_title,
    roster_title,
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
def test_format_nom_with_marker():
    """Mid-name. Fencing Time renders "Nom Prenom", so this yields
    "KOWALSKI (2) Jan" — the form our own scraper reads back. The previous
    placement produced "KOWALSKI Jan (2)", which it does not match, so our
    seed files did not round-trip through our own pipeline."""
    assert format_nom_with_marker("KOWALSKI", "2") == "KOWALSKI (2)"


def test_format_nom_with_marker_vcat_zero():
    """V0 is a real category, not an absent marker."""
    assert format_nom_with_marker("PĘCZEK", "0") == "PĘCZEK (0)"


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
# File naming and titles (plan §8, replacing ADR-080 §4)
#
# ADR-080 §3's combined-bracket PREDICTION is dropped with this change: we emit
# the maximal split (one DE file per gender × category actually present) and the
# manual tells the organizer to combine in Fencing Time, because we re-split by
# birth year on the way back regardless. Predicting their combining was guessing
# at a decision that is theirs to make, and a wrong guess produced a file whose
# name claimed a category range it did not hold.
#
# Filenames are ASCII/English so they survive any operating system and any
# mail client; the Polish is in the TitreLong, which is what Fencing Time shows.
# Every name states event, weapon, phase, gender and category range — MPW 2026's
# foil mix-all is called "Floret Mężczyzn V3, V4" while holding 25 fencers
# spanning V0-V4 including the women, and ours must not be able to read that way.
# ---------------------------------------------------------------------------
def test_export_filename_mixall_both_genders():
    """X7.1 — the worked example from plan §8."""
    assert (
        export_filename("PPW1-2026-2027", "EPEE", "POOLS-MIXED", "all-categories_W+M")
        == "PPW1-2026-2027_EPEE_POOLS-MIXED_all-categories_W+M.xml"
    )


def test_export_filename_de_bracket():
    """X7.2 — one DE file per gender x category, named for exactly that."""
    assert (
        export_filename("PPW1-2026-2027", "EPEE", "DE", "MEN_V2")
        == "PPW1-2026-2027_EPEE_DE_MEN_V2.xml"
    )


def test_export_filename_roster():
    """X7.3 — the pick-list file, named so nobody imports it as a competition."""
    assert (
        export_filename("PPW1-2026-2027", "EPEE", "ROSTER", "all-known-epee-fencers")
        == "PPW1-2026-2027_EPEE_ROSTER_all-known-epee-fencers.xml"
    )


def test_mixall_title_worked_example():
    """X7.4 — plan §8, verbatim."""
    assert mixall_title("PPW1-2026-2027", "EPEE", ["F", "M"], ["V0", "V1", "V2", "V3", "V4"]) == (
        "SPWS PPW1 2026/27 · SZPADA · ELIMINACJE MIX — kobiety+mężczyźni, V0–V4"
    )


def test_mixall_title_states_the_range_actually_present():
    """X7.5 — the whole point of the rename. A file holding only V2 and V3 men
    must not claim V0-V4, and must not claim women it does not contain."""
    assert mixall_title("PPW1-2026-2027", "SABRE", ["M"], ["V2", "V3"]) == (
        "SPWS PPW1 2026/27 · SZABLA · ELIMINACJE MIX — mężczyźni, V2–V3"
    )


def test_mixall_title_single_category_is_not_written_as_a_range():
    """X7.6 — "V2–V2" would read as a defect."""
    assert mixall_title("PPW1-2026-2027", "FOIL", ["F"], ["V2"]) == (
        "SPWS PPW1 2026/27 · FLORET · ELIMINACJE MIX — kobiety, V2"
    )


def test_de_title_worked_example():
    """X7.7 — plan §8, verbatim."""
    assert de_title("PPW1-2026-2027", "EPEE", "M", "V2") == (
        "SPWS PPW1 2026/27 · SZPADA · DE mężczyźni V2"
    )


def test_de_title_women():
    """X7.8 — genders are never merged in a DE file (ADR-080 §3)."""
    assert de_title("PPW1-2026-2027", "FOIL", "F", "V0") == (
        "SPWS PPW1 2026/27 · FLORET · DE kobiety V0"
    )


def test_roster_title_says_out_loud_it_is_not_a_competition():
    """X7.9 — the roster is a pick-list (FT Guide p.145), and the one file an
    organizer could destroy their event with by importing it as an event."""
    assert roster_title("EPEE") == "SPWS · BAZA ZAWODNIKÓW — szpada (nie importować jako zawody)"


# ---------------------------------------------------------------------------
# FIE XML generation (ADR-080 §1)
# ---------------------------------------------------------------------------
def test_build_fie_xml_omits_datenaissance_and_lateralite():
    xml_text = build_fie_xml(
        root_id="spws-ppw-e-mixall",
        weapon_code="E",
        gender_code="M",
        title="SPWS Szpada ELIMINACJE (mix-all) 2025/2026",
        tireurs=[{"id": 1, "nom": "KOWALSKI (2)", "prenom": "Jan", "sexe": "M", "classement": 1}],
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
        tireurs=[{"id": 7, "nom": "NOWAK (1)", "prenom": "Anna", "sexe": "F", "classement": 3}],
    )
    root = ET.fromstring(xml_text.split("\n", 2)[-1] if xml_text.startswith("<?xml") else xml_text)
    tireur = root.find(".//Tireur")
    assert tireur is not None
    assert tireur.get("Nom") == "NOWAK (1)"
    assert tireur.get("Nom") == "NOWAK (1)"
    assert tireur.get("Prenom") == "Anna"
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
            {"id": 1, "nom": "AAA (0)", "prenom": "A", "sexe": "M", "classement": 1},
            {"id": 2, "nom": "BBB (1)", "prenom": "B", "sexe": "F", "classement": 2},
        ],
    )
    root = ET.fromstring(xml_text.split("\n", 2)[-1] if xml_text.startswith("<?xml") else xml_text)
    tireurs = root.findall(".//Tireur")
    assert [t.get("Nom") for t in tireurs] == ["AAA (0)", "BBB (1)"]
