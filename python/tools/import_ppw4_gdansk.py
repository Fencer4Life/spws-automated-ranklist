#!/usr/bin/env python3
"""Parse PPW4 Gdańsk FencingTime XML files and generate seed SQL for all categories.

Usage:
    python python/tools/import_ppw4_gdansk.py

Reads XML files from doc/external_files/Sezon_2025-2026/Attachments-Fw_ wyniki Gdańsk/
Matches fencers to IDs in seed_tbl_fencer.sql
Generates/updates SQL seed files in supabase/data/2025_26/
"""

import re
import xml.etree.ElementTree as ET
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
XML_DIR = PROJECT_ROOT / "doc" / "external_files" / "Sezon_2025-2026" / "Attachments-Fw_ wyniki Gdańsk"
SEED_DIR = PROJECT_ROOT / "supabase" / "data" / "2025_26"
FENCER_SQL = PROJECT_ROOT / "supabase" / "seed_tbl_fencer.sql"

# Age category boundaries for 2025-26 season (reference year 2026)
# V0: born 1987+ (under 40), V1: 1977-1986 (40-49), V2: 1967-1976 (50-59)
# V3: 1957-1966 (60-69), V4: 1956 or earlier (70+)
AGE_CATEGORIES = {
    "V0": (1987, 9999),
    "V1": (1977, 1986),
    "V2": (1967, 1976),
    "V3": (1957, 1966),
    "V4": (0, 1956),
}

# XML file → (weapon, gender, categories_list)
# Categories list: if multiple, it's a combined tournament that needs splitting
XML_MAPPING = {
    # Already done: "RESULTS_V40ME_2026-8.xml": ("EPEE", "M", ["V2"]),
    "RESULTS_V50ME_2026-9.xml": ("EPEE", "M", ["V3"]),
    "RESULTS_V60ME_2026-10.xml": ("EPEE", "M", ["V4"]),
    "RESULTS_VABCME_2026-11.xml": ("EPEE", "M", ["V0", "V1"]),
    "RESULTS_V50WE_2026-7.xml": ("EPEE", "F", ["V2"]),
    "RESULTS_VETWE_2026-6.xml": ("EPEE", "F", ["V0", "V1"]),
    "RESULTS_VETMF_2026-4.xml": ("FOIL", "M", ["V0", "V1", "V2"]),
    "RESULTS_V50MF_2026-5.xml": ("FOIL", "M", ["V3", "V4"]),
    "RESULTS_WF_2026-3.xml": ("FOIL", "F", ["V0", "V1", "V2", "V3", "V4"]),
    "RESULTS_VETMS_2026-13.xml": ("SABRE", "M", ["V2"]),
    "RESULTS_V40MS_2026-16.xml": ("SABRE", "M", ["V0", "V1"]),
    "RESULTS_V50MS_2026-14.xml": ("SABRE", "M", ["V3"]),
    "RESULTS_V60MS_2026-15.xml": ("SABRE", "M", ["V4"]),
    "RESULTS_VABCWS_2026-12.xml": ("SABRE", "F", ["V0", "V1", "V2", "V3", "V4"]),
}

# Skip qualification rounds
SKIP_FILES = {"RESULTS_GRVETXE_2026-1.xml", "RESULTS_GRVETXS_2026-2.xml", "RESULTS_XF_2026-0.xml"}

WEAPON_NAME = {"EPEE": "Szpada", "FOIL": "Floret", "SABRE": "Szabla"}
GENDER_NAME = {"M": "M", "F": "K"}


def _normalize(s):
    """Strip diacritics-insensitive: ż→z, ł→l, etc. for fuzzy matching."""
    import unicodedata
    nfkd = unicodedata.normalize("NFKD", s)
    return "".join(c for c in nfkd if not unicodedata.combining(c)).upper()


def _clean_first_name(name):
    """Strip prefixes like '(0) ', '(1) ', '- BOŁDYS ' from malformed first names."""
    # Strip leading "(N) " prefix
    name = re.sub(r'^\(\d+\)\s*', '', name)
    # Strip leading "- SUFFIX " (e.g. "- BOŁDYS Katarzyna" → "Katarzyna")
    name = re.sub(r'^-\s*\S+\s+', '', name)
    # Strip trailing " (kat N)" suffix
    name = re.sub(r'\s*\(kat\s*\d+\)', '', name)
    return name.strip()


# Age category boundaries for 2024-25 season (reference year 2025)
AGE_CATEGORIES_2024_25 = {
    "V0": (1986, 9999),
    "V1": (1976, 1985),
    "V2": (1966, 1975),
    "V3": (1956, 1965),
    "V4": (0, 1955),
}

# Category midpoints — safe estimates that map to the same category in 2025-26
CATEGORY_MIDPOINT = {"V0": 1990, "V1": 1980, "V2": 1970, "V3": 1960, "V4": 1950}


def load_fencer_index():
    """Load fencer surname+first_name → id mapping from seed SQL.

    Builds three indices:
    - exact: (SURNAME, FIRST_NAME) → (id, surname, first_name)
    - normalized: (NORM_SURNAME, NORM_FIRST_NAME) → (id, surname, first_name)
    - norm_birth: NORM_KEY → birth_year (best birth year for any name variant)

    Prefers entries WITH birth year over those without (handles duplicates).
    """
    fencers = {}  # (SURNAME, FIRST_NAME) → (id, surname, first_name)
    fencers_norm = {}  # normalized key for fallback
    norm_birth = {}  # normalized key → birth_year (from any variant)
    with open(FENCER_SQL) as f:
        lines = f.readlines()

    # First pass: collect all entries
    all_entries = []
    for i, line in enumerate(lines):
        m = re.match(r"\s*\('([^']+)',\s*'([^']+)',\s*(\d+|NULL)", line)
        if m:
            surname, first_name = m.group(1), m.group(2)
            fencer_id = i - 8 + 1
            birth_year_str = m.group(3)
            birth_year = int(birth_year_str) if birth_year_str != "NULL" else None
            has_birth = birth_year is not None
            # Clean malformed first names for matching
            clean_fn = _clean_first_name(first_name)
            all_entries.append((surname, first_name, clean_fn, fencer_id, has_birth, birth_year))

    # Insert entries without birth year first, then with — so "with" wins
    for surname, first_name, clean_fn, fencer_id, has_birth, birth_year in sorted(all_entries, key=lambda e: e[4]):
        key = (surname.upper(), first_name.upper())
        fencers[key] = (fencer_id, surname, first_name)
        # Also index by cleaned first name
        clean_key = (surname.upper(), clean_fn.upper())
        if clean_key != key:
            fencers[clean_key] = (fencer_id, surname, first_name)

        # Normalized index (strips diacritics)
        norm_key = (_normalize(surname), _normalize(clean_fn))
        fencers_norm[norm_key] = (fencer_id, surname, first_name)

        # Track best birth year per normalized name
        if birth_year is not None:
            norm_birth[norm_key] = birth_year
            # Also store under original diacritics key
            norm_birth[(_normalize(surname), _normalize(first_name))] = birth_year

    # Build surname-grouped birth year index for fuzzy first-name matching.
    # Handles typos like Urlike/Ulrike, Adrianna/Adriana, Aliaksandr/Aleksander.
    surname_birth = {}  # NORM_SURNAME → [(NORM_FIRST_NAME, birth_year)]
    for (ns, nf), by in norm_birth.items():
        surname_birth.setdefault(ns, []).append((nf, by))

    return fencers, fencers_norm, norm_birth, surname_birth


def load_fencer_birth_years():
    """Load fencer id → birth_year from seed SQL."""
    birth_years = {}
    with open(FENCER_SQL) as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        m = re.match(r"\s*\('([^']+)',\s*'([^']+)',\s*(\d+|NULL)", line)
        if m:
            fencer_id = i - 8 + 1
            birth_year_str = m.group(3)
            if birth_year_str != "NULL":
                birth_years[fencer_id] = int(birth_year_str)

    return birth_years


def scan_seed_categories():
    """Scan 2024-25 seed files to build fencer_id → age_category mapping.

    Returns dict mapping fencer_id → estimated birth year (category midpoint).
    """
    seed_dir_2024 = PROJECT_ROOT / "supabase" / "data" / "2024_25"
    fencer_categories = {}  # fencer_id → category

    for sql_file in sorted(seed_dir_2024.glob("v*_*.sql")):
        # Extract category from filename: v0_m_epee.sql → V0
        cat = sql_file.stem.split("_")[0].upper()
        if cat not in CATEGORY_MIDPOINT:
            continue

        # Extract fencer IDs from result inserts.
        # Format: "INSERT INTO tbl_result ...\nVALUES (\n    51,\n"
        lines = sql_file.read_text().splitlines()
        for i, line in enumerate(lines):
            if 'tbl_result' in line and i + 2 < len(lines):
                m = re.match(r'\s*(\d+)\s*,', lines[i + 2])
                if m:
                    fid = int(m.group(1))
                    if fid not in fencer_categories:
                        fencer_categories[fid] = cat

    # Also scan commented-out UNMATCHED entries for category hints.
    # Format: "-- UNMATCHED (score<80): 'GÓRNA Karolina' place=1"
    unmatched_categories = {}  # (NORM_SURNAME, NORM_FIRST_NAME) → category
    for sql_file in sorted(seed_dir_2024.glob("v*_*.sql")):
        cat = sql_file.stem.split("_")[0].upper()
        if cat not in CATEGORY_MIDPOINT:
            continue
        for line in sql_file.read_text().splitlines():
            m = re.match(r"-- UNMATCHED.*?'(\S+)\s+(.*?)'", line)
            if m:
                norm_key = (_normalize(m.group(1)), _normalize(m.group(2)))
                unmatched_categories[norm_key] = cat

    # Convert to birth year estimates
    birth_estimates = {}
    for fid, cat in fencer_categories.items():
        birth_estimates[fid] = CATEGORY_MIDPOINT[cat]

    return birth_estimates, unmatched_categories


def parse_xml(xml_path):
    """Parse FencingTime XML, return list of (surname, first_name, birth_year, final_place)."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Build tireur ID → info mapping
    tireurs = {}
    for t in root.findall(".//Tireur[@Nom]"):
        tid = t.get("ID")
        nom = t.get("Nom", "")
        prenom = t.get("Prenom", "")
        dob = t.get("DateNaissance", "")
        birth_year = None
        if dob:
            # Format: DD.MM.YYYY
            parts = dob.split(".")
            if len(parts) == 3:
                birth_year = int(parts[2])
        tireurs[tid] = {"surname": nom, "first_name": prenom, "birth_year": birth_year}

    # Get final rankings from PhaseDeTableaux
    results = []
    for phase in root.findall(".//PhaseDeTableaux"):
        for t in phase.findall("Tireur[@RangFinal]"):
            ref = t.get("REF")
            rank = int(t.get("RangFinal"))
            if ref in tireurs:
                info = tireurs[ref]
                results.append({
                    "surname": info["surname"],
                    "first_name": info["first_name"],
                    "birth_year": info["birth_year"],
                    "place": rank,
                })

    results.sort(key=lambda r: r["place"])
    return results


def match_fencer(result, fencer_index, fencer_index_norm):
    """Match a result entry to a fencer ID. Returns (id, matched_name) or None."""
    surname = result["surname"].upper()
    first_name = result["first_name"].upper()

    # Exact match
    key = (surname, first_name)
    if key in fencer_index:
        fid, s, f = fencer_index[key]
        return fid, f"{s} {f}"

    # Normalized match (strips diacritics: ż→z, ł→l, etc.)
    norm_key = (_normalize(result["surname"]), _normalize(result["first_name"]))
    if norm_key in fencer_index_norm:
        fid, s, f = fencer_index_norm[norm_key]
        return fid, f"{s} {f}"

    # Handle "SURNAME - SUFFIX" → "SURNAME-SUFFIX" (spaces around hyphen)
    clean_surname = re.sub(r'\s*-\s*', '-', surname)
    key2 = (clean_surname, first_name)
    if key2 in fencer_index:
        fid, s, f = fencer_index[key2]
        return fid, f"{s} {f}"

    # Normalized with cleaned hyphen
    norm_key2 = (_normalize(clean_surname), _normalize(result["first_name"]))
    if norm_key2 in fencer_index_norm:
        fid, s, f = fencer_index_norm[norm_key2]
        return fid, f"{s} {f}"

    # For compound surnames "A - B" or "A-B", try matching just the first part
    parts = re.split(r'\s*-\s*', surname)
    if len(parts) > 1:
        first_part = parts[0]
        key3 = (first_part, first_name)
        if key3 in fencer_index:
            fid, s, f = fencer_index[key3]
            return fid, f"{s} {f}"
        norm_key3 = (_normalize(first_part), _normalize(result["first_name"]))
        if norm_key3 in fencer_index_norm:
            fid, s, f = fencer_index_norm[norm_key3]
            return fid, f"{s} {f}"

    # Partial match: first 3 chars of first name (exact and normalized surname)
    for (s, f), (fid, sn, fn) in fencer_index.items():
        if s == surname and len(first_name) >= 3 and len(f) >= 3 and f[:3] == first_name[:3]:
            return fid, f"{sn} {fn}"
    # Partial match with normalized surname
    norm_surname = _normalize(result["surname"])
    for (s, f), (fid, sn, fn) in fencer_index_norm.items():
        if s == norm_surname and len(first_name) >= 3 and len(f) >= 3 and f[:3] == _normalize(result["first_name"])[:3]:
            return fid, f"{sn} {fn}"

    return None, f"{result['surname']} {result['first_name']}"


def categorize_fencer(birth_year):
    """Return age category for birth year in 2025-26 season."""
    if birth_year is None:
        return None
    for cat, (low, high) in AGE_CATEGORIES.items():
        if low <= birth_year <= high:
            return cat
    return None


def _edit_distance(a, b):
    """Simple Levenshtein edit distance."""
    if len(a) < len(b):
        return _edit_distance(b, a)
    if len(b) == 0:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a):
        curr = [i + 1]
        for j, cb in enumerate(b):
            curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (0 if ca == cb else 1)))
        prev = curr
    return prev[len(b)]


def resolve_birth_year(fid, result, birth_years, norm_birth, surname_birth,
                       category_estimates, unmatched_categories):
    """Resolve birth year from multiple sources, in priority order.

    1. XML birth year (most authoritative)
    2. Seed file birth year (by fencer ID)
    3. Cross-reference birth year (by normalized name, covers typo variants)
    4. Fuzzy first-name match (same surname, edit distance ≤ 3)
    5. 2024-25 category inference (midpoint of age range)
    6. 2024-25 unmatched comment hints (category from commented-out entries)
    """
    # 1. XML
    if result.get("birth_year"):
        return result["birth_year"], "xml"

    # 2. Seed by ID
    if fid and fid in birth_years:
        return birth_years[fid], "seed"

    # 3. Cross-reference by normalized name
    norm_key = (_normalize(result["surname"]), _normalize(result["first_name"]))
    if norm_key in norm_birth:
        return norm_birth[norm_key], "norm-xref"

    # 4. Fuzzy first-name match within same surname group
    norm_surname = _normalize(result["surname"])
    # Also try with hyphen cleanup for compound surnames
    clean_surname = re.sub(r'\s*-\s*', '-', result["surname"])
    for ns in {norm_surname, _normalize(clean_surname)}:
        if ns in surname_birth:
            norm_fn = _normalize(result["first_name"])
            for stored_fn, by in surname_birth[ns]:
                if _edit_distance(norm_fn, stored_fn) <= 3:
                    return by, "fuzzy-xref"

    # 5. 2024-25 category estimate
    if fid and fid in category_estimates:
        return category_estimates[fid], "cat-est"

    # 6. 2024-25 unmatched comment hints
    norm_key_hint = (_normalize(result["surname"]), _normalize(result["first_name"]))
    if norm_key_hint in unmatched_categories:
        cat = unmatched_categories[norm_key_hint]
        return CATEGORY_MIDPOINT[cat], "unmatched-hint"

    return None, None


def split_combined_results(results, categories, fencer_index, fencer_index_norm,
                           birth_years, norm_birth, surname_birth,
                           category_estimates, unmatched_categories):
    """Split combined tournament results into per-category groups."""
    category_results = {cat: [] for cat in categories}
    unmatched = []

    for r in results:
        fid, name = match_fencer(r, fencer_index, fencer_index_norm)

        # Resolve birth year from all available sources
        birth_year, source = resolve_birth_year(
            fid, r, birth_years, norm_birth, surname_birth,
            category_estimates, unmatched_categories
        )

        cat = categorize_fencer(birth_year)

        if cat and cat in category_results:
            if source and source != "xml":
                print(f"    {name}: birth year {birth_year} (from {source}) → {cat}")
            category_results[cat].append({
                "id_fencer": fid,
                "name": name,
                "place": r["place"],
                "birth_year": birth_year,
            })
        elif cat is None:
            unmatched.append({
                "id_fencer": fid,
                "name": name,
                "place": r["place"],
                "birth_year": birth_year,
            })
        else:
            # Category exists but not in this tournament's expected categories
            print(f"  WARNING: {name} (born {birth_year}) → {cat} not in {categories}")

    # Re-rank within each category by original place
    for cat in category_results:
        entries = sorted(category_results[cat], key=lambda e: e["place"])
        for i, e in enumerate(entries, 1):
            e["category_place"] = i

    return category_results, unmatched


def generate_tournament_sql(weapon, gender, category, entries, participant_count=None):
    """Generate SQL for a single tournament's results."""
    if not entries:
        return ""

    if participant_count is None:
        participant_count = len(entries)

    tc = f"PPW4-{category}-{gender}-{weapon}-2025-2026"
    weapon_pl = WEAPON_NAME[weapon]
    gender_pl = GENDER_NAME[gender]

    lines = []
    lines.append(f"INSERT INTO tbl_tournament (")
    lines.append(f"    id_event, txt_code, txt_name, enum_type,")
    lines.append(f"    enum_weapon, enum_gender, enum_age_category,")
    lines.append(f"    dt_tournament, int_participant_count, url_results,")
    lines.append(f"    enum_import_status")
    lines.append(f") VALUES (")
    lines.append(f"    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'),")
    lines.append(f"    '{tc}',")
    lines.append(f"    'IV Puchar Polski Weteranów — {weapon_pl} {gender_pl}',")
    lines.append(f"    'PPW',")
    lines.append(f"    '{weapon}', '{gender}', '{category}',")
    lines.append(f"    '2026-02-21', {participant_count}, NULL,")
    lines.append(f"    'SCORED'")
    lines.append(f");")

    for e in entries:
        place = e.get("category_place", e["place"])
        if e["id_fencer"] is None:
            lines.append(f"-- UNMATCHED: {e['name']} place={place} (born {e.get('birth_year', '?')})")
            continue
        lines.append(f"INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)")
        lines.append(f"VALUES (")
        lines.append(f"    {e['id_fencer']},")
        lines.append(f"    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{tc}'),")
        lines.append(f"    {place},")
        lines.append(f"    '{e['name']}'")
        lines.append(f");")

    lines.append(f"SELECT fn_calc_tournament_scores(")
    lines.append(f"    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{tc}')")
    lines.append(f");")

    return "\n".join(lines)


def generate_seed_file(weapon, gender, category, tournament_sql):
    """Generate a complete seed SQL file for a category."""
    weapon_lower = weapon.lower()
    gender_lower = gender.lower()
    cat_lower = category.lower()

    filename = f"{cat_lower}_{gender_lower}_{weapon_lower}.sql"
    filepath = SEED_DIR / filename

    header = f"""-- =============================================================================
-- {category} {gender} {weapon} — 2025-2026 Season Data
-- =============================================================================
-- PPW4 (IV Puchar Polski Weteranów, Gdańsk, 2026-02-21)
-- =============================================================================

-- Ensure PPW4 event exists (may already be created by v2_m_epee.sql)
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED', '2026-02-21', 'Gdańsk', 'Polska'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');

"""

    content = header + tournament_sql + "\n"

    return filepath, content


def main():
    print("Loading fencer index...")
    fencer_index, fencer_index_norm, norm_birth, surname_birth = load_fencer_index()
    birth_years = load_fencer_birth_years()
    print(f"  Loaded {len(fencer_index)} fencers, {len(birth_years)} with birth years")
    print(f"  Cross-ref birth years: {len(norm_birth)} normalized names")

    print("Scanning 2024-25 seed files for category-based birth year estimates...")
    category_estimates, unmatched_categories = scan_seed_categories()
    print(f"  Found category data for {len(category_estimates)} fencers, {len(unmatched_categories)} unmatched hints")

    all_unmatched = []
    files_written = []

    for xml_name, (weapon, gender, categories) in sorted(XML_MAPPING.items()):
        xml_path = XML_DIR / xml_name
        if not xml_path.exists():
            print(f"WARNING: {xml_name} not found, skipping")
            continue

        print(f"\nProcessing {xml_name} → {weapon} {gender} {categories}")
        results = parse_xml(xml_path)
        print(f"  {len(results)} fencers in results")

        if len(categories) == 1:
            # Single category — direct mapping
            cat = categories[0]
            entries = []
            for r in results:
                fid, name = match_fencer(r, fencer_index, fencer_index_norm)
                entries.append({
                    "id_fencer": fid,
                    "name": name,
                    "place": r["place"],
                    "category_place": r["place"],
                    "birth_year": r["birth_year"],
                })
                if fid is None:
                    all_unmatched.append((xml_name, name, r.get("birth_year")))

            sql = generate_tournament_sql(weapon, gender, cat, entries)
            filepath, content = generate_seed_file(weapon, gender, cat, sql)

            # Check if file already exists (e.g., v2_m_epee.sql)
            if filepath.exists():
                print(f"  SKIP: {filepath.name} already exists (PPW4 data may already be there)")
                continue

            filepath.write_text(content)
            files_written.append(filepath.name)
            print(f"  Wrote {filepath.name} ({len(entries)} results)")

        else:
            # Combined categories — split by birth year
            cat_results, unmatched = split_combined_results(
                results, categories, fencer_index, fencer_index_norm,
                birth_years, norm_birth, surname_birth,
                category_estimates, unmatched_categories
            )

            for um in unmatched:
                all_unmatched.append((xml_name, um["name"], um.get("birth_year")))

            for cat in categories:
                entries = cat_results[cat]
                if not entries:
                    print(f"  {cat}: no fencers")
                    continue

                for e in entries:
                    if e["id_fencer"] is None:
                        all_unmatched.append((xml_name, e["name"], e.get("birth_year")))

                sql = generate_tournament_sql(weapon, gender, cat, entries)
                filepath, content = generate_seed_file(weapon, gender, cat, sql)

                if filepath.exists():
                    print(f"  SKIP: {filepath.name} already exists")
                    continue

                filepath.write_text(content)
                files_written.append(filepath.name)
                print(f"  Wrote {filepath.name} ({len(entries)} results, {cat})")

    print(f"\n{'='*60}")
    print(f"Files written: {len(files_written)}")
    for f in sorted(files_written):
        print(f"  {f}")

    if all_unmatched:
        print(f"\nUNMATCHED FENCERS ({len(all_unmatched)}):")
        for xml, name, by in all_unmatched:
            print(f"  {xml}: {name} (born {by})")


if __name__ == "__main__":
    main()
