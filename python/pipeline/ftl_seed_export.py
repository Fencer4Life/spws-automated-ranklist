"""
FTL clean-roster seed export (ADR-080).

Generates FIE-XML <BaseCompetitionIndividuelle> seed files (one per competition:
one mix-all pool per weapon + one per predicted DE bracket) from every
DECLARED registration — this system does not track payment completion
digitally (corrected 2026-07-04; see ADR-079 Section 4), only displays
bank-transfer info so the fencer can pay correctly; the organizer verifies
payment in person at the venue, before the competition starts — for
on-demand delivery to the event organizer (ADR-079/080, spec Section 5.2).

This is a NEW module — NOT a reuse of python/pipeline/export_seed.py, which is
the unrelated ADR-036 whole-database backup exporter (confirmed 2026-07-04;
that module also owns the `export-seed` Telegram command, hence this
subsystem's Telegram trigger is named `send <code> participants` instead).

Reuses python/pipeline/age_split.py's birth_year_to_vcat/split_combined_results
conventions and python/matcher/fuzzy_match.py's canonicalize_scraped_name
approach to name cleanup, but implements the export-side (not scrape-side)
canonical casing rule itself.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass

# Fixed round-robin order for the mix-all pool interleave (ADR-080 Section 2).
MIXALL_SUBRANKING_ORDER = (
    "FV0", "FV1", "FV2", "FV3", "FV4",
    "MV0", "MV1", "MV2", "MV3", "MV4",
)

# Age categories in ascending order, for combined-DE-bracket accumulation
# (ADR-080 Section 3).
VCAT_ORDER = ("V0", "V1", "V2", "V3", "V4")


@dataclass
class FencerEntry:
    id_fencer: int
    surname: str
    first_name: str


def to_canonical_name(surname: str, first_name: str) -> tuple[str, str]:
    """Canonical seed/entry-list/ranklist name form (ADR-080 Section 1):
    surname in UPPERCASE, given name in Title case. Fixes legacy all-caps
    given names on export."""
    return surname.strip().upper(), first_name.strip().title()


def format_prenom_with_marker(first_name_canon: str, vcat_digit: str) -> str:
    """Appends the (N) age-category marker to the given name (ADR-080 Section 1)."""
    return f"{first_name_canon} ({vcat_digit})"


def interleave_mixall(
    sub_rankings: dict[str, list[FencerEntry]],
) -> list[tuple[FencerEntry, str]]:
    """Round-robin ("snake by rank") interleave across the 10 domestic
    sub-rankings in the fixed FV0..FV4,MV0..MV4 order (ADR-080 Section 2).

    Lays down the 1st-placed fencer of every LIVE sub-ranking (in fixed
    order, empties skipped), then every 2nd-placed fencer, and so on.
    Returns (fencer, sub_ranking_key) pairs in seed order; the caller derives
    Sexe from the key's F/M prefix and the (N) marker from its trailing digit.
    """
    max_len = max((len(entries) for entries in sub_rankings.values()), default=0)
    result: list[tuple[FencerEntry, str]] = []
    for rank_idx in range(max_len):
        for key in MIXALL_SUBRANKING_ORDER:
            entries = sub_rankings.get(key, [])
            if rank_idx < len(entries):
                result.append((entries[rank_idx], key))
    return result


def predict_combined_brackets(vcat_counts: dict[str, int], t: int = 4) -> list[list[str]]:
    """Predicts combined DE brackets for one weapon x gender (ADR-080 Section 3;
    genders are never merged — call this once per weapon x gender).

    Order V0->V4, skip empty categories, accumulate left-to-right; close a
    bracket once its running count >= t; fold a trailing sub-t bracket into
    the previous one (or make it the sole bracket if none precede it).
    """
    live = [cat for cat in VCAT_ORDER if vcat_counts.get(cat, 0) > 0]

    brackets: list[list[str]] = []
    current: list[str] = []
    current_count = 0
    for cat in live:
        current.append(cat)
        current_count += vcat_counts[cat]
        if current_count >= t:
            brackets.append(current)
            current = []
            current_count = 0

    if current:
        if brackets:
            brackets[-1].extend(current)
        else:
            brackets.append(current)

    return brackets


def combined_bracket_scope(gender_code: str, vcats: list[str]) -> str:
    """Builds the DE-bracket scope token for the filename, e.g. ("M", ["V2"])
    -> "M-V2", ("F", ["V3","V4"]) -> "F-V3V4" (ADR-080 Section 4)."""
    return f"{gender_code}-{''.join(vcats)}"


def seed_filename(season_code: str, event_code_stem: str, weapon_code: str, scope: str) -> str:
    """<season>_<eventcode>_<weapon>_<scope>.xml (ADR-080 Section 4)."""
    return f"{season_code}_{event_code_stem}_{weapon_code}_{scope}.xml"


def build_fie_xml(
    root_id: str,
    weapon_code: str,
    gender_code: str,
    title: str,
    tireurs: list[dict],
    date_fichier_xml: str = "",
) -> str:
    """Builds one FIE <BaseCompetitionIndividuelle> XML document (ADR-080
    Section 1). No DateNaissance (FTL infers/enforces an age category from it
    otherwise; the authoritative BY lives only in tbl_registration). No
    Lateralite (FTL accepts import without it). Club/Licence always "" (not
    collected). Matches the validated reference files in
    doc/external_files/FTL_SRC/.
    """
    root = ET.Element(
        "BaseCompetitionIndividuelle",
        {
            "Championnat": "SPWS",
            "ID": root_id,
            "Arme": weapon_code,
            "Sexe": gender_code,
            "Domaine": "N",
            "Federation": "POL",
            "Categorie": "V",
            "TitreLong": title,
            "Date": "",
            "DateFichierXML": date_fichier_xml,
        },
    )
    tireurs_el = ET.SubElement(root, "Tireurs")
    for t in tireurs:
        ET.SubElement(
            tireurs_el,
            "Tireur",
            {
                "ID": str(t["id"]),
                "Nom": t["nom"],
                "Prenom": t["prenom"],
                "Sexe": t["sexe"],
                "Club": "",
                "Nation": "POL",
                "Licence": "",
                "Statut": "N",
                "Classement": str(t["classement"]),
            },
        )

    body = ET.tostring(root, encoding="unicode")
    return f'<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE BaseCompetitionIndividuelle>\n{body}'
