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

import io
import re
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass

from python.pipeline.age_split import birth_year_to_vcat

# Fixed round-robin order for the mix-all pool interleave (ADR-080 Section 2).
MIXALL_SUBRANKING_ORDER = (
    "FV0",
    "FV1",
    "FV2",
    "FV3",
    "FV4",
    "MV0",
    "MV1",
    "MV2",
    "MV3",
    "MV4",
)

# Age categories in ascending order, for combined-DE-bracket accumulation
# (ADR-080 Section 3).
VCAT_ORDER = ("V0", "V1", "V2", "V3", "V4")

# arr_weapons enum values → FIE Arme code (filename + XML) and Polish name (title).
WEAPON_FIE_CODE = {"EPEE": "E", "FOIL": "F", "SABRE": "S"}
WEAPON_PL_NAME = {"EPEE": "Szpada", "FOIL": "Floret", "SABRE": "Szabla"}


@dataclass
class FencerEntry:
    id_fencer: int | None
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


# ===========================================================================
# DB-querying orchestration layer (ADR-080 §2; invocation/population resolved
# 2026-07-05). PURE functions — the population is the declared registrations,
# the ordering comes from the season ranking. The thin Supabase glue that
# actually fetches these lives in ftl_seed_export_db.py so this module stays
# dependency-free and fully unit-testable.
# ===========================================================================


def registration_subranking_key(gender: str, birth_year: int, season_end_year: int) -> str | None:
    """Map a registration's DECLARED (gender, birth year) to its mix-all
    sub-ranking key ("FV0".."MV4"), or None if the declared BY falls outside
    the veteran range (age < 30).

    The V-cat comes from the DECLARED birth year (ADR-079 read-only invariant —
    never tbl_fencer's), via the single-source-of-truth age_split.birth_year_to_vcat.
    """
    vcat = birth_year_to_vcat(birth_year, season_end_year)
    if vcat is None:
        return None
    return f"{gender}{vcat}"


def assemble_mixall_subrankings(
    registrations: list[dict],
    weapon: str,
    rankings: dict[str, list[int]],
    season_end_year: int,
) -> dict[str, list[FencerEntry]]:
    """Group one weapon's declared registrants into the 10 mix-all sub-rankings,
    ordered as the interleave expects (ADR-080 §2).

    POPULATION: every registration that declared `weapon` (no payment gate).
    ORDERING within a sub-ranking: matched+ranked registrants first, in the
    order of the season ranking `rankings[key]` (a list of id_fencer from
    fn_ranking_ppw); unranked registrants (id_fencer NULL, or matched but absent
    from the ranking) appended after, by registration timestamp (ts_created).

    `registrations` rows carry: id_fencer, txt_surname, txt_first_name,
    enum_gender ('M'/'F'), int_birth_year, arr_weapons (list of enum values),
    ts_created. Names are canonicalised on the way in (ADR-080 §1).
    """
    buckets: dict[str, list[dict]] = {}
    for reg in registrations:
        if weapon not in (reg.get("arr_weapons") or []):
            continue
        key = registration_subranking_key(
            reg["enum_gender"], reg["int_birth_year"], season_end_year
        )
        if key is None:
            continue
        buckets.setdefault(key, []).append(reg)

    out: dict[str, list[FencerEntry]] = {}
    for key, regs in buckets.items():
        rank_order = rankings.get(key, [])

        def _sort_key(reg: dict, _rank_order: list[int] = rank_order) -> tuple[int, int, str]:
            idf = reg.get("id_fencer")
            if idf is not None and idf in _rank_order:
                return (0, _rank_order.index(idf), "")
            return (1, 0, reg.get("ts_created") or "")

        ordered = sorted(regs, key=_sort_key)
        out[key] = [
            FencerEntry(
                reg.get("id_fencer"), *to_canonical_name(reg["txt_surname"], reg["txt_first_name"])
            )
            for reg in ordered
        ]
    return out


def mixall_tireurs(
    seed_order: list[tuple[FencerEntry, str]],
) -> list[dict]:
    """Turn an interleave_mixall result into FIE <Tireur> dicts (ADR-080 §1/§2).

    Seed position (1..N) is both the Tireur `ID` and `Classement` (matches the
    validated reference file, which uses a running id == seed). `Sexe` is the
    sub-ranking key's F/M prefix; the `(N)` marker is its trailing V-cat digit —
    both already encoded in the key that interleave_mixall pairs with each entry.
    """
    tireurs: list[dict] = []
    for seed, (entry, key) in enumerate(seed_order, start=1):
        tireurs.append(
            {
                "id": seed,
                "nom": entry.surname,
                "prenom": format_prenom_with_marker(entry.first_name, key[-1]),
                "sexe": key[0],
                "classement": seed,
            }
        )
    return tireurs


def season_pretty(season_code: str) -> str:
    """'SPWS-2025-2026' → '2025/2026' (the human season label in the FTL title)."""
    years = re.findall(r"\d{4}", season_code)
    if len(years) >= 2:
        return f"{years[-2]}/{years[-1]}"
    return season_code


def mixall_title(weapon: str, season_code: str) -> str:
    """FTL TitreLong for a weapon's mix-all pool, e.g.
    'SPWS Szpada ELIMINACJE (mix-all) 2025/2026' (matches the reference file)."""
    return f"SPWS {WEAPON_PL_NAME[weapon]} ELIMINACJE (mix-all) {season_pretty(season_code)}"


def build_event_mixall_files(
    registrations: list[dict],
    weapons: list[str],
    rankings_by_weapon: dict[str, dict[str, list[int]]],
    season_code: str,
    event_code_stem: str,
    season_end_year: int,
    date_fichier_xml: str = "",
) -> dict[str, str]:
    """Build the mix-all seed XML for every weapon that has registrants
    (ADR-080 §1/§2/§4). Returns {filename: xml_text}. A weapon with zero
    declared registrants is omitted (no empty file).

    `weapons` are the event's weapon enum values (e.g. ['EPEE','FOIL','SABRE']);
    `rankings_by_weapon[weapon][subkey]` is the season ranking's id_fencer order
    for that weapon×gender×category (fn_ranking_ppw), used only for ordering.
    """
    files: dict[str, str] = {}
    for weapon in weapons:
        weapon_code = WEAPON_FIE_CODE[weapon]
        sub_rankings = assemble_mixall_subrankings(
            registrations, weapon, rankings_by_weapon.get(weapon, {}), season_end_year
        )
        seed_order = interleave_mixall(sub_rankings)
        if not seed_order:
            continue
        tireurs = mixall_tireurs(seed_order)
        filename = seed_filename(season_code, event_code_stem, weapon_code, "mixall")
        root_id = filename[:-4]  # ADR-080 §4: root ID = filename stem
        files[filename] = build_fie_xml(
            root_id=root_id,
            weapon_code=weapon_code,
            gender_code="M",  # nominal root Sexe; per-Tireur Sexe carries the real gender
            title=mixall_title(weapon, season_code),
            tireurs=tireurs,
            date_fichier_xml=date_fichier_xml,
        )
    return files


def bundle_seed_zip(files: dict[str, str]) -> bytes:
    """Bundle {filename: xml_text} into a single .zip (bytes) for delivery to
    the organizer (ADR-080 §5, Phase 4 send_seed_to_organizer)."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for name, content in files.items():
            zf.writestr(name, content)
    return buf.getvalue()
