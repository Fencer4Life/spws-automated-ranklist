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
    assemble_mixall_subrankings,
    build_event_mixall_files,
    build_fie_xml,
    de_title,
    export_filename,
    format_nom_with_marker,
    interleave_mixall,
    mixall_tireurs,
    mixall_title,
    polish_sort_key,
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
        "FV0": [
            FencerEntry(1, "PECZEK", "Sandra", rank=1),
            FencerEntry(10, "SZMAJDZINSKA", "Katarzyna", rank=2),
        ],
        "FV1": [FencerEntry(2, "KAMINSKA", "Gabriela", rank=1)],
        "FV2": [FencerEntry(3, "WASILCZUK", "Beata", rank=1)],
        "FV3": [],
        "FV4": [FencerEntry(4, "BORKOWSKA", "Halina", rank=1)],
        "MV0": [FencerEntry(5, "SPLAWA-NEYMAN", "Maciej", rank=1)],
        "MV1": [FencerEntry(6, "SEKOWSKI", "Maciej", rank=1)],
        "MV2": [FencerEntry(7, "JENDRYS", "Marek", rank=1)],
        "MV3": [FencerEntry(8, "KRZEMINSKI", "Mariusz", rank=1)],
        "MV4": [FencerEntry(9, "SZCZESNY", "Jacek", rank=1)],
    }
    order = interleave_mixall(sub_rankings)
    ids_in_order = [entry.id_fencer for entry, _vcat_key in order]
    # rank-1 pass: FV0,FV1,FV2,(FV3 skipped),FV4,MV0..MV4 = ids 1,2,3,4,5,6,7,8,9
    # rank-2 pass: only FV0 has a second entry = id 10
    assert ids_in_order == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    assert order[0][1] == "FV0"
    assert order[3][1] == "FV4"  # FV3 correctly skipped, FV4 is 4th not 5th
    assert order[-1][1] == "FV0"  # the rank-2 entry is still tagged with its sub-ranking


def test_interleave_mixall_tiers_on_the_true_rank_not_the_position():
    """PPW1 2026, EPEE. SZKLAR is 4th on the FV0 ranklist; ranks 1-3 did not
    enter. The old code compacted the registered fencers to a dense 1..N, so she
    became FV0's "index 1" and was seeded ahead of every genuine category
    winner. The tier is the rank the fencers actually hold: a true 1st is laid
    down in the first pass, and SZKLAR appears with the rest of the 4th places.
    """
    sub_rankings = {
        "FV0": [FencerEntry(1, "SZKLAR", "Bozena", rank=4)],
        "FV1": [FencerEntry(2, "KAMINSKA", "Gabriela", rank=1)],
        "MV1": [FencerEntry(3, "SEKOWSKI", "Maciej", rank=1)],
        "MV2": [FencerEntry(4, "JENDRYS", "Marek", rank=2)],
    }
    order = interleave_mixall(sub_rankings)
    assert [e.id_fencer for e, _ in order] == [2, 3, 4, 1]
    # A bucket whose lowest real rank is 4 first appears in the 4th pass; the
    # empty tiers above it simply produce nothing.
    assert order[-1][1] == "FV0"


def test_interleave_mixall_puts_every_unranked_fencer_after_every_ranked_one():
    """A fencer with no points is not a category winner. They used to be
    interleaved as if they held the next rank in their bucket."""
    sub_rankings = {
        "FV0": [FencerEntry(1, "RANKED", "Anna", rank=9), FencerEntry(2, "NEW", "Ewa")],
        "MV0": [FencerEntry(3, "ALSONEW", "Jan"), FencerEntry(4, "TOPMAN", "Adam", rank=1)],
    }
    order = interleave_mixall(sub_rankings)
    assert [e.id_fencer for e, _ in order] == [4, 1, 2, 3]


def test_interleave_mixall_keeps_tied_ranks_in_list_order():
    """fn_ranking_ppw can return two fencers on the same score, so a tier may
    hold more than one entry per bucket. Stable, or two downloads of the same
    entry list disagree."""
    sub_rankings = {"MV1": [FencerEntry(1, "A", "A", rank=3), FencerEntry(2, "B", "B", rank=3)]}
    assert [e.id_fencer for e, _ in interleave_mixall(sub_rankings)] == [1, 2]


def test_interleave_mixall_orders_a_tier_by_points_not_by_category():
    """Within a tier the order is ranking points, descending, across all ten
    sub-rankings (2026-09-26).

    Before this, the order inside a tier was the fixed FV0..MV4 sequence, so a
    woman took the first seed of every tier because "F" sorts before "M", and V0
    led the women because "0" sorts before "1". Neither was earned. Measured on
    PPW1 EPEE, tier 1 was KAMINSKA(FV1) first on 363.20 while SEKOWSKI(MV1) sat
    fifth on 435.96.
    """
    sub_rankings = {
        "FV1": [FencerEntry(1, "KAMINSKA", "Gabriela", rank=1, points=363.20)],
        "FV2": [FencerEntry(2, "WASILCZUK", "Beata", rank=1, points=320.70)],
        "FV4": [FencerEntry(3, "BORKOWSKA", "Halina", rank=1, points=156.95)],
        "MV0": [FencerEntry(4, "SPLAWA-NEYMAN", "Maciej", rank=1, points=319.07)],
        "MV1": [FencerEntry(5, "SEKOWSKI", "Maciej", rank=1, points=435.96)],
        "MV2": [FencerEntry(6, "JENDRYS", "Marek", rank=1, points=389.99)],
        "MV3": [FencerEntry(7, "KRZEMINSKI", "Mariusz", rank=1, points=422.84)],
    }
    assert [e.id_fencer for e, _ in interleave_mixall(sub_rankings)] == [5, 7, 6, 1, 2, 4, 3]


def test_interleave_mixall_breaks_equal_points_on_the_fixed_category_order():
    """The sort must be TOTAL: fn_ranking_ppw gives two fencers on the same
    score the same rank, so exact ties are real. Two downloads of one entry list
    that disagree would be impossible to reconcile against the organizer's
    software. The old fixed order survives as the tie-break.
    """
    sub_rankings = {
        "MV2": [FencerEntry(3, "CCC", "Three", rank=1, points=100.00)],
        "FV0": [FencerEntry(1, "AAA", "One", rank=1, points=100.00)],
        "MV0": [FencerEntry(2, "BBB", "Two", rank=1, points=100.00)],
    }
    assert [e.id_fencer for e, _ in interleave_mixall(sub_rankings)] == [1, 2, 3]


def test_interleave_mixall_points_never_decide_which_tier():
    """Points order WITHIN a tier; they must never leak into WHICH tier.

    A rank-2 fencer holding more points than a rank-1 fencer of another
    sub-ranking still seeds behind them — the small-field category winner leads
    their tier, which is the whole point of seeding by rank rather than by score.
    """
    sub_rankings = {
        "FV4": [FencerEntry(1, "SMALLFIELD", "Winner", rank=1, points=10.00)],
        "MV1": [FencerEntry(2, "BIGFIELD", "Runnerup", rank=2, points=999.00)],
    }
    assert [e.id_fencer for e, _ in interleave_mixall(sub_rankings)] == [1, 2]


def test_interleave_mixall_unranked_tail_ignores_points():
    """An unranked fencer has no points to sort on, so the tail keeps the fixed
    bucket order and list order it always had."""
    sub_rankings = {
        "MV1": [FencerEntry(3, "CCC", "Three", rank=None, points=None)],
        "FV0": [FencerEntry(1, "AAA", "One", rank=None, points=None)],
        "FV2": [FencerEntry(2, "BBB", "Two", rank=None, points=None)],
    }
    assert [e.id_fencer for e, _ in interleave_mixall(sub_rankings)] == [1, 2, 3]


def test_interleave_mixall_empty_input():
    assert interleave_mixall({}) == []


def test_interleave_mixall_all_empty_sub_rankings():
    assert interleave_mixall({"FV0": [], "MV0": []}) == []


# ---------------------------------------------------------------------------
# Polish collation — the same assertions as the TypeScript twin's collation
# block (frontend/tests/ftlSeedExport.test.ts, X8.30-X8.37).
#
# The browser has Intl.Collator and this module does not, so neither side may
# use one: the alphabet is written out in both files and agrees by construction.
# ---------------------------------------------------------------------------
def _sorted_pl(names: list[str]) -> list[str]:
    return sorted(names, key=polish_sort_key)


def test_polish_sort_key_puts_l_stroke_between_l_and_m():
    # A code-point sort returns Lis, Maj, Łuczak — the defect EntryList.svelte
    # documents at :127-130 and works around with a collator.
    assert _sorted_pl(["Maj", "Łuczak", "Lis"]) == ["Lis", "Łuczak", "Maj"]


def test_polish_sort_key_puts_o_acute_between_o_and_p_and_z_dot_last():
    assert _sorted_pl(["Paw", "Ósemka", "Olek"]) == ["Olek", "Ósemka", "Paw"]
    assert _sorted_pl(["Żak", "Zych", "Źródło"]) == ["Zych", "Źródło", "Żak"]


def test_polish_sort_key_orders_the_whole_alphabet():
    letters = list("aąbcćdeęfghijklłmnńoópqrsśtuvwxyzźż")
    assert _sorted_pl(list(reversed(letters))) == letters


def test_polish_sort_key_is_case_insensitive():
    # The seeded roster is upper-case but the registration form takes free text,
    # so a lower-case surname must file with its peers rather than after them.
    assert _sorted_pl(["kowalski", "KOWALCZYK"]) == ["KOWALCZYK", "kowalski"]


def test_polish_sort_key_sorts_hyphen_and_apostrophe_before_any_letter():
    assert _sorted_pl(["Spławacz", "Spława-Neyman"]) == ["Spława-Neyman", "Spławacz"]
    assert _sorted_pl(["O'Neill", "Onacki"]) == ["O'Neill", "Onacki"]


def test_polish_sort_key_sorts_an_unknown_letter_after_the_polish_alphabet():
    # A foreign entrant's name must land somewhere deterministic rather than
    # colliding with a Polish letter.
    assert _sorted_pl(["Žukov", "Zych"]) == ["Zych", "Žukov"]


# ---------------------------------------------------------------------------
# mixall_tireurs — seed numbering, then alphabetical output
# ---------------------------------------------------------------------------
def _entry(surname: str, first_name: str) -> FencerEntry:
    return FencerEntry(id_fencer=None, surname=surname, first_name=first_name)


def test_mixall_tireurs_numbers_by_seed_then_writes_alphabetically():
    tireurs = mixall_tireurs(
        [
            (_entry("ŻAK", "Adam"), "MV0"),
            (_entry("LIS", "Ewa"), "FV1"),
            (_entry("ŁUCZAK", "Jan"), "MV2"),
        ]
    )
    assert [t["nom"] for t in tireurs] == ["LIS (1)", "ŁUCZAK (2)", "ŻAK (0)"]
    # Seed 1 went to ŻAK and stays with ŻAK.
    assert [t["classement"] for t in tireurs] == [2, 3, 1]
    assert [t["id"] for t in tireurs] == [2, 3, 1]


def test_mixall_tireurs_breaks_a_tie_on_given_name_then_on_seed_order():
    tireurs = mixall_tireurs(
        [
            (_entry("NOWAK", "Piotr"), "MV0"),
            (_entry("NOWAK", "Anna"), "FV0"),
            # Same person twice by name: the stable sort keeps the earlier seed
            # first, so two identical registrations still produce one
            # deterministic file.
            (_entry("NOWAK", "Anna"), "FV2"),
        ]
    )
    assert [(t["nom"], t["classement"]) for t in tireurs] == [
        ("NOWAK (0)", 2),
        ("NOWAK (2)", 3),
        ("NOWAK (0)", 1),
    ]


def test_mixall_tireurs_orders_on_the_surname_not_the_marked_nom():
    # The (N) marker is appended after the key is taken; sorting on the
    # formatted nom would interleave categories instead of names.
    tireurs = mixall_tireurs(
        [(_entry("NOWAKOWSKI", "Jan"), "MV0"), (_entry("NOWAK", "Jan"), "MV4")]
    )
    assert [t["nom"] for t in tireurs] == ["NOWAK (4)", "NOWAKOWSKI (0)"]


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
    # No "club" key at all — matches a roster-derived Tireur dict, which never
    # carries one. Club must still render "" rather than raise.
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
    assert tireur.get("Prenom") == "Anna"
    assert tireur.get("Sexe") == "F"
    assert tireur.get("Classement") == "3"
    assert tireur.get("Club") == ""
    assert tireur.get("Licence") == ""
    assert tireur.get("Nation") == "POL"


def test_build_fie_xml_tireur_club_is_always_empty():
    """ADR-080 amendment (f) withdrawn 2026-09-24. A club supplied by a caller
    is ignored rather than emitted: the declared values were free text and one
    Poznan club reached us under three spellings. The ATTRIBUTE survives, empty
    — the validated FIE reference files carry it."""
    xml_text = build_fie_xml(
        root_id="x",
        weapon_code="S",
        gender_code="F",
        title="Title",
        tireurs=[
            {
                "id": 7,
                "nom": "NOWAK (1)",
                "prenom": "Anna",
                "sexe": "F",
                "classement": 3,
                "club": "AZS AWFiS Gdańsk",
            }
        ],
    )
    root = ET.fromstring(xml_text.split("\n", 2)[-1] if xml_text.startswith("<?xml") else xml_text)
    tireur = root.find(".//Tireur")
    assert tireur is not None
    assert tireur.get("Club") == ""


def test_build_fie_xml_tireur_renders_none_club_as_empty_string():
    # A FencerEntry with no declared club carries club=None (the dataclass
    # default), and mixall_tireurs passes that straight into the dict — must
    # not render the literal string "None".
    xml_text = build_fie_xml(
        root_id="x",
        weapon_code="S",
        gender_code="F",
        title="Title",
        tireurs=[
            {
                "id": 7,
                "nom": "NOWAK (1)",
                "prenom": "Anna",
                "sexe": "F",
                "classement": 3,
                "club": None,
            }
        ],
    )
    root = ET.fromstring(xml_text.split("\n", 2)[-1] if xml_text.startswith("<?xml") else xml_text)
    tireur = root.find(".//Tireur")
    assert tireur is not None
    assert tireur.get("Club") == ""


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


def test_assemble_mixall_subrankings_carries_the_points_through():
    """The orchestration must reach the interleave with points, or the two
    generators disagree about the same event.

    fetch_weapon_rankings kept only id_fencer and threw total_score away, so
    every FencerEntry arrived with points=None, every tier fell back to the
    fixed category order, and the Python path (ftl-seed.yml -> Telegram
    delivery) produced a different seed order from the browser download page —
    which reads num_rank_points straight off the projection. The byte-parity
    test cannot see this: it feeds both generators the same entries.
    """
    regs = [
        {
            "id_fencer": 7,
            "txt_surname": "SEKOWSKI",
            "txt_first_name": "Maciej",
            "enum_gender": "M",
            "int_birth_year": 1980,
            "arr_weapons": ["EPEE"],
            "ts_created": "2026-09-01T00:00:00Z",
        },
    ]
    sub = assemble_mixall_subrankings(
        regs,
        "EPEE",
        {"MV1": [7]},
        2027,
        scores={"MV1": {7: 435.96}},
    )
    assert sub["MV1"][0].points == 435.96


def test_build_event_seed_files_orders_a_tier_by_points_end_to_end():
    """The whole Python path, registrations in and seed order out."""
    regs = [
        # FV1 rank 1 on fewer points than MV1's rank 1. Under the old fixed
        # order she led the tier because 'F' sorts before 'M'.
        {
            "id_fencer": 1,
            "txt_surname": "KAMINSKA",
            "txt_first_name": "Gabriela",
            "enum_gender": "F",
            "int_birth_year": 1982,
            "arr_weapons": ["EPEE"],
            "ts_created": "2026-09-01T00:00:00Z",
        },
        {
            "id_fencer": 2,
            "txt_surname": "SEKOWSKI",
            "txt_first_name": "Maciej",
            "enum_gender": "M",
            "int_birth_year": 1982,
            "arr_weapons": ["EPEE"],
            "ts_created": "2026-09-02T00:00:00Z",
        },
    ]
    files = build_event_mixall_files(
        registrations=regs,
        weapons=["EPEE"],
        rankings_by_weapon={"EPEE": {"FV1": [1], "MV1": [2]}},
        event_code="PPW1-2026-2027",
        season_end_year=2027,
        scores_by_weapon={"EPEE": {"FV1": {1: 363.20}, "MV1": {2: 435.96}}},
    )
    doc = next(iter(files.values()))
    # Classement 1 belongs to the higher score, whatever the category letter.
    tireurs = {t.get("Nom"): t.get("Classement") for t in ET.fromstring(doc).iter("Tireur")}
    assert tireurs["SEKOWSKI (1)"] == "1"
    assert tireurs["KAMINSKA (1)"] == "2"
