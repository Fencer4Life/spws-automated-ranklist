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
from python.pipeline.vcat_marker import format_marker

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

# Age categories in ascending order — the axis the DE files split on.
VCAT_ORDER = ("V0", "V1", "V2", "V3", "V4")

# arr_weapons enum values → FIE Arme code (XML) and Polish name (TitreLong).
WEAPON_FIE_CODE = {"EPEE": "E", "FOIL": "F", "SABRE": "S"}
WEAPON_PL_NAME = {"EPEE": "Szpada", "FOIL": "Floret", "SABRE": "Szabla"}

# Polish words used in the TitreLong, which is the only string Fencing Time
# shows the operator. Filenames stay ASCII/English (plan §8).
GENDER_PL = {"F": "kobiety", "M": "mężczyźni"}
GENDER_FILE_TOKEN = {"F": "WOMEN", "M": "MEN"}

# What the organizer is meant to DO with each file — the manifest's key column,
# and the reason the roster is named "…do not import as a competition".
IMPORT_AS = {"MIXALL": "COMPETITION", "DE": "COMPETITION", "ROSTER": "PICKLIST"}


@dataclass
class FencerEntry:
    id_fencer: int | None
    surname: str
    first_name: str


@dataclass
class SeedFile:
    """One generated file plus the facts the §9 manifest needs about it.

    The manifest is built from these objects rather than re-queried, so the
    count the organizer reads next to a filename is by construction the number
    of <Tireur> elements inside that exact file.
    """

    filename: str
    xml: str
    kind: str  # MIXALL | DE | ROSTER
    weapon: str
    title: str
    count: int

    @property
    def import_as(self) -> str:
        return IMPORT_AS[self.kind]


def to_canonical_name(surname: str, first_name: str) -> tuple[str, str]:
    """Canonical seed/entry-list/ranklist name form (ADR-080 Section 1):
    surname in UPPERCASE, given name in Title case. Fixes legacy all-caps
    given names on export."""
    return surname.strip().upper(), first_name.strip().title()


def format_nom_with_marker(surname_canon: str, vcat_digit: str) -> str:
    """The surname carrying its (N) age-category marker (ADR-080 §1, amended
    2026-09-12).

    MID-NAME, not appended to the given name. Fencing Time renders the entry as
    "Nom Prenom", so this produces "KAMIŃSKA (1) Gabriela" — which is the form
    our own scraper reads, and the form every one of MPW 2026's 20 events uses
    in the wild. The previous placement ("Gabriela (1)") produced
    "KAMIŃSKA Gabriela (1)", which `split_name_marker` does not match: our seed
    files did not round-trip through our own pipeline, and only organizer-typed
    files did. The reader still accepts the old suffix form so historical
    events keep parsing.
    """
    return format_marker(surname_canon, vcat_digit)


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


def event_stem_and_season(event_code: str) -> tuple[str, str]:
    """'PPW1-2026-2027' → ('PPW1', '2026/27') — the two halves the TitreLong
    needs. An event code carrying no season suffix yields an empty season."""
    m = re.match(r"^(.*?)-(\d{4})-(\d{4})$", event_code)
    if not m:
        return event_code, ""
    return m.group(1), f"{m.group(2)}/{m.group(3)[-2:]}"


def _title_prefix(event_code: str) -> str:
    stem, season = event_stem_and_season(event_code)
    return f"SPWS {stem} {season}".rstrip()


def _vcat_range(vcats: list[str]) -> str:
    """['V0','V2','V4'] → 'V0–V4'; ['V2'] → 'V2'.

    An en dash, and never 'V2–V2' — a title that reads like a defect gets
    treated like one.
    """
    live = [c for c in VCAT_ORDER if c in set(vcats)]
    if not live:
        return ""
    return live[0] if len(live) == 1 else f"{live[0]}–{live[-1]}"


def export_filename(event_code: str, weapon: str, phase: str, scope: str) -> str:
    """<event>_<WEAPON>_<PHASE>_<scope>.xml (plan §8, replacing ADR-080 §4).

    ASCII and English throughout: these names travel by e-mail, through
    WordPress and onto a Windows machine at the venue. Every one states the
    event, the weapon, the phase, the gender and the category range, so a file
    can never be imported into the wrong bracket by a name that under-describes
    it — which is exactly how MPW 2026's "Floret Mężczyzn V3, V4" came to hold
    25 fencers spanning V0-V4 including the women.
    """
    return f"{event_code}_{weapon}_{phase}_{scope}.xml"


def mixall_scope(genders: list[str]) -> str:
    """The mix-all's filename scope: every category, and whichever genders
    actually entered ('W+M', 'W' or 'M')."""
    tokens = [g for g in ("F", "M") if g in set(genders)]
    gender_part = "+".join("W" if g == "F" else "M" for g in tokens) or "none"
    return f"all-categories_{gender_part}"


def mixall_title(event_code: str, weapon: str, genders: list[str], vcats: list[str]) -> str:
    """'SPWS PPW1 2026/27 · SZPADA · ELIMINACJE MIX — kobiety+mężczyźni, V0–V4'."""
    live = [g for g in ("F", "M") if g in set(genders)]
    gender_phrase = "+".join(GENDER_PL[g] for g in live)
    return (
        f"{_title_prefix(event_code)} · {WEAPON_PL_NAME[weapon].upper()} · "
        f"ELIMINACJE MIX — {gender_phrase}, {_vcat_range(vcats)}"
    )


def de_scope(gender: str, vcat: str) -> str:
    """'MEN_V2' — one DE file per gender × category, never merged."""
    return f"{GENDER_FILE_TOKEN[gender]}_{vcat}"


def de_title(event_code: str, weapon: str, gender: str, vcat: str) -> str:
    """'SPWS PPW1 2026/27 · SZPADA · DE mężczyźni V2'."""
    return (
        f"{_title_prefix(event_code)} · {WEAPON_PL_NAME[weapon].upper()} · "
        f"DE {GENDER_PL[gender]} {vcat}"
    )


def roster_scope(weapon: str) -> str:
    return f"all-known-{weapon.lower()}-fencers"


def roster_title(weapon: str) -> str:
    """The pick-list file. Its title carries the warning because the title is
    what Fencing Time displays once it is open — by then a wrong import has
    already happened, so the filename carries it too."""
    return f"SPWS · BAZA ZAWODNIKÓW — {WEAPON_PL_NAME[weapon].lower()} (nie importować jako zawody)"


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
                "nom": format_nom_with_marker(entry.surname, key[-1]),
                "prenom": entry.first_name,
                "sexe": key[0],
                "classement": seed,
            }
        )
    return tireurs


def season_pretty(season_code: str) -> str:
    """'SPWS-2025-2026' → '2025/2026' (the long season label; the FTL titles use
    the short '2025/26' form from event_stem_and_season)."""
    years = re.findall(r"\d{4}", season_code)
    if len(years) >= 2:
        return f"{years[-2]}/{years[-1]}"
    return season_code


def _weapon_seed_file(
    sub_rankings: dict[str, list[FencerEntry]],
    weapon: str,
    event_code: str,
    date_fichier_xml: str,
) -> SeedFile | None:
    """The weapon's mix-all pool: every registrant, interleaved by rank across
    the live sub-rankings (ADR-080 §2). None when nobody entered this weapon."""
    seed_order = interleave_mixall(sub_rankings)
    if not seed_order:
        return None
    live_keys = [k for k in MIXALL_SUBRANKING_ORDER if sub_rankings.get(k)]
    genders = [k[0] for k in live_keys]
    vcats = [k[1:] for k in live_keys]
    scope = mixall_scope(genders)
    filename = export_filename(event_code, weapon, "POOLS-MIXED", scope)
    title = mixall_title(event_code, weapon, genders, vcats)
    tireurs = mixall_tireurs(seed_order)
    return SeedFile(
        filename=filename,
        xml=build_fie_xml(
            root_id=filename[:-4],  # root ID = filename stem
            weapon_code=WEAPON_FIE_CODE[weapon],
            gender_code="M",  # nominal root Sexe; per-Tireur Sexe carries the real one
            title=title,
            tireurs=tireurs,
            date_fichier_xml=date_fichier_xml,
        ),
        kind="MIXALL",
        weapon=weapon,
        title=title,
        count=len(tireurs),
    )


def _de_seed_files(
    sub_rankings: dict[str, list[FencerEntry]],
    weapon: str,
    event_code: str,
    date_fichier_xml: str,
) -> list[SeedFile]:
    """One direct-elimination file per gender × category that actually has
    entrants — the MAXIMAL split (plan §1, replacing ADR-080 §3's prediction).

    Each is a standalone competition, so its Classement restarts at 1 and its
    root Sexe is the real gender. The (N) marker still rides on every Nom even
    though the file's own name states the category: the marker is how we read
    the results back, and the organizer is explicitly told to leave it alone.
    """
    files: list[SeedFile] = []
    for key in MIXALL_SUBRANKING_ORDER:
        entries = sub_rankings.get(key) or []
        if not entries:
            continue
        gender, vcat = key[0], key[1:]
        filename = export_filename(event_code, weapon, "DE", de_scope(gender, vcat))
        title = de_title(event_code, weapon, gender, vcat)
        tireurs = mixall_tireurs([(entry, key) for entry in entries])
        files.append(
            SeedFile(
                filename=filename,
                xml=build_fie_xml(
                    root_id=filename[:-4],
                    weapon_code=WEAPON_FIE_CODE[weapon],
                    gender_code=gender,
                    title=title,
                    tireurs=tireurs,
                    date_fichier_xml=date_fichier_xml,
                ),
                kind="DE",
                weapon=weapon,
                title=title,
                count=len(tireurs),
            )
        )
    return files


def _roster_seed_file(
    rows: list[dict],
    weapon: str,
    event_code: str,
    date_fichier_xml: str,
) -> SeedFile | None:
    """The organizer's pick-list for one weapon (ADR-080 amendment (e)).

    `rows` come from fn_ftl_roster and are already suppressed and ordered: every
    fencer with any result in this weapon, full history, all nationalities, minus
    those this event's entry list already accounts for. Alphabetical, because it
    is a list somebody scrolls looking for a name.

    The (N) marker rides on these names exactly as it does on a seeded entry. A
    pick-list has no seeding to speak of, but a fencer ticked in from here comes
    back on the results carrying the category digit the pipeline reads — which is
    the entire reason ticking is better than typing.
    """
    if not rows:
        return None
    filename = export_filename(event_code, weapon, "ROSTER", roster_scope(weapon))
    title = roster_title(weapon)
    entries = sorted(rows, key=lambda r: r["int_order"])
    tireurs = mixall_tireurs(
        [
            (
                FencerEntry(None, *to_canonical_name(r["txt_surname"], r["txt_first_name"])),
                f"{r['enum_gender']}{r['enum_age_category']}",
            )
            for r in entries
        ]
    )
    return SeedFile(
        filename=filename,
        xml=build_fie_xml(
            root_id=filename[:-4],
            weapon_code=WEAPON_FIE_CODE[weapon],
            # Nominal, as on the mix-all: a roster is every gender at once, and
            # each Tireur carries its own.
            gender_code="M",
            title=title,
            tireurs=tireurs,
            date_fichier_xml=date_fichier_xml,
        ),
        kind="ROSTER",
        weapon=weapon,
        title=title,
        count=len(tireurs),
    )


def build_event_seed_files(
    registrations: list[dict],
    weapons: list[str],
    rankings_by_weapon: dict[str, dict[str, list[int]]],
    event_code: str,
    season_end_year: int,
    date_fichier_xml: str = "",
    rosters: dict[str, list[dict]] | None = None,
) -> list[SeedFile]:
    """The event's whole file set: one mix-all per weapon with registrants, one
    DE file per gender × category present in it, and — when `rosters` carries
    rows for that weapon — one pick-list.

    `event_code` is tbl_event.txt_code in full ('PPW1-2026-2027') — it is the
    filename prefix and the source of the title's event and season.

    `rosters` is {weapon: rows from fn_ftl_roster}. It is optional because the
    population is a database question rather than a function of this event's
    registrations, and because the Telegram delivery path has never sent one. A
    weapon with no registrants gets no roster either: a pick-list for a weapon
    nobody is fencing is one more file to import by mistake.
    """
    out: list[SeedFile] = []
    for weapon in weapons:
        sub_rankings = assemble_mixall_subrankings(
            registrations, weapon, rankings_by_weapon.get(weapon, {}), season_end_year
        )
        mixall = _weapon_seed_file(sub_rankings, weapon, event_code, date_fichier_xml)
        if mixall is None:
            continue
        out.append(mixall)
        out.extend(_de_seed_files(sub_rankings, weapon, event_code, date_fichier_xml))

        roster = _roster_seed_file(
            (rosters or {}).get(weapon) or [], weapon, event_code, date_fichier_xml
        )
        if roster is not None:
            out.append(roster)
    return out


def export_manifest(files: list[SeedFile]) -> list[dict]:
    """§9's "what you are downloading" table, generated from the files
    themselves so the counts cannot drift from their contents."""
    return [
        {
            "filename": f.filename,
            "kind": f.kind,
            "weapon": f.weapon,
            "title": f.title,
            "count": f.count,
            "import_as": f.import_as,
        }
        for f in files
    ]


def build_event_mixall_files(
    registrations: list[dict],
    weapons: list[str],
    rankings_by_weapon: dict[str, dict[str, list[int]]],
    event_code: str,
    season_end_year: int,
    date_fichier_xml: str = "",
) -> dict[str, str]:
    """{filename: xml} for the whole competition file set — the shape the
    Telegram delivery path and the .zip bundler consume."""
    return {
        f.filename: f.xml
        for f in build_event_seed_files(
            registrations=registrations,
            weapons=weapons,
            rankings_by_weapon=rankings_by_weapon,
            event_code=event_code,
            season_end_year=season_end_year,
            date_fichier_xml=date_fichier_xml,
        )
    }


def bundle_seed_zip(files: dict[str, str]) -> bytes:
    """Bundle {filename: xml_text} into a single .zip (bytes) for delivery to
    the organizer (ADR-080 §5, Phase 4 send_seed_to_organizer)."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for name, content in files.items():
            zf.writestr(name, content)
    return buf.getvalue()
