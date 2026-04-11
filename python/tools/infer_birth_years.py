#!/usr/bin/env python3
"""Infer birth years for fencers with NULL birth year using category-crossing logic.

Scans seed_tbl_fencer.sql and all season data SQL files to:
1. Map each fencer to their tournament category observations across seasons.
2. For category-crossing fencers, pin the exact birth year from the intersection.
3. For single-category fencers, estimate birth year as the category midpoint.
4. Detect diacritic duplicates (Polish ąćęłńóśźż vs ASCII equivalents).

Usage:
    python python/tools/infer_birth_years.py
"""

import re
import unicodedata
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SEED_FENCER_PATH = PROJECT_ROOT / "supabase" / "seed_tbl_fencer.sql"
DATA_DIR = PROJECT_ROOT / "supabase" / "data"

# Season directory → season end year (from EXTRACT(YEAR FROM dt_end))
SEASON_END_YEAR = {
    "2023_24": 2024,
    "2024_25": 2025,
    "2025_26": 2026,
}

# Category → (min_age, max_age) — age = season_end_year - birth_year
CATEGORY_AGE_RANGE = {
    "V0": (30, 39),
    "V1": (40, 49),
    "V2": (50, 59),
    "V3": (60, 69),
    "V4": (70, 120),  # open-ended
}


def strip_diacritics(s: str) -> str:
    """Strip Polish diacritics to ASCII equivalent."""
    # Manual mapping for Polish-specific chars
    POLISH_MAP = str.maketrans({
        "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
        "ó": "o", "ś": "s", "ź": "z", "ż": "z",
        "Ą": "A", "Ć": "C", "Ę": "E", "Ł": "L", "Ń": "N",
        "Ó": "O", "Ś": "S", "Ź": "Z", "Ż": "Z",
    })
    return s.translate(POLISH_MAP)


def parse_fencers(path: Path) -> dict[int, dict]:
    """Parse seed_tbl_fencer.sql → {id: {surname, first_name, birth_year, line_num}}."""
    text = path.read_text(encoding="utf-8")
    fencers = {}
    # Match each VALUES tuple line
    pattern = re.compile(
        r"\('([^']+)',\s+'([^']+)',\s+(NULL|\d+)\)"
    )
    fencer_id = 0
    for line_num, line in enumerate(text.splitlines(), 1):
        m = pattern.search(line)
        if m:
            fencer_id += 1
            surname, first_name, by_str = m.groups()
            birth_year = None if by_str == "NULL" else int(by_str)
            fencers[fencer_id] = {
                "surname": surname,
                "first_name": first_name,
                "birth_year": birth_year,
                "line_num": line_num,
            }
    return fencers


def scan_tournament_observations(data_dir: Path) -> dict[int, list[tuple[int, str]]]:
    """Scan all seed SQL files → {fencer_id: [(season_end_year, category), ...]}."""
    observations: dict[int, list[tuple[int, str]]] = {}

    # Pattern to extract fencer_id from INSERT INTO tbl_result blocks
    # Format: INSERT INTO tbl_result (...)\nVALUES (\n    <id>,
    result_pattern = re.compile(
        r"INSERT INTO tbl_result.*?VALUES\s*\(\s*(\d+),", re.DOTALL
    )
    # Pattern to extract category from tournament code in same block
    # Tournament code format: PPW1-V2-M-EPEE-2024-2025
    tournament_pattern = re.compile(
        r"txt_code = '([^']+)'"
    )

    for season_dir in sorted(data_dir.iterdir()):
        if not season_dir.is_dir():
            continue
        season_key = season_dir.name
        if season_key not in SEASON_END_YEAR:
            continue
        end_year = SEASON_END_YEAR[season_key]

        # Extract category from filename: v2_m_epee.sql → V2
        for sql_file in sorted(season_dir.glob("*.sql")):
            fname = sql_file.name
            if fname.startswith("zz_"):
                continue
            # Parse category from filename: v0_f_epee.sql → V0
            cat_match = re.match(r"(v\d)_", fname)
            if not cat_match:
                continue
            file_category = cat_match.group(1).upper()

            text = sql_file.read_text(encoding="utf-8")
            # Find all fencer IDs in result inserts
            for m in result_pattern.finditer(text):
                fencer_id = int(m.group(1))
                if fencer_id not in observations:
                    observations[fencer_id] = []
                observations[fencer_id].append((end_year, file_category))

    # Deduplicate observations per fencer
    for fid in observations:
        observations[fid] = list(set(observations[fid]))

    return observations


def infer_birth_year_range(obs: list[tuple[int, str]]) -> tuple[int | None, int | None, str]:
    """Given observations [(end_year, category)], compute birth year range.

    Returns (min_year, max_year, source) where source is 'crossing' or 'single'.
    """
    if not obs:
        return None, None, "none"

    min_year = -9999
    max_year = 9999

    for end_year, category in obs:
        if category not in CATEGORY_AGE_RANGE:
            continue
        min_age, max_age = CATEGORY_AGE_RANGE[category]
        # birth_year = end_year - age
        obs_max = end_year - min_age  # youngest possible
        obs_min = end_year - max_age  # oldest possible
        min_year = max(min_year, obs_min)
        max_year = min(max_year, obs_max)

    if min_year > max_year:
        return None, None, "conflict"

    categories = set(cat for _, cat in obs)
    source = "crossing" if len(categories) > 1 else "single"
    return min_year, max_year, source


def detect_diacritic_duplicates(fencers: dict[int, dict]) -> list[tuple[int, int]]:
    """Find fencer pairs that match when Polish diacritics are stripped."""
    # Build normalized name → list of (id, has_diacritics)
    norm_index: dict[tuple[str, str], list[int]] = {}
    for fid, f in fencers.items():
        norm_key = (
            strip_diacritics(f["surname"]).upper(),
            strip_diacritics(f["first_name"]).upper(),
        )
        if norm_key not in norm_index:
            norm_index[norm_key] = []
        norm_index[norm_key].append(fid)

    duplicates = []
    for norm_key, ids in norm_index.items():
        if len(ids) > 1:
            duplicates.append(tuple(sorted(ids)))

    return duplicates


def main():
    print("=" * 70)
    print("Birth Year Inference from Category Crossing")
    print("=" * 70)

    fencers = parse_fencers(SEED_FENCER_PATH)
    print(f"\nParsed {len(fencers)} fencers from seed_tbl_fencer.sql")

    null_count = sum(1 for f in fencers.values() if f["birth_year"] is None)
    print(f"  {null_count} fencers with NULL birth year")

    observations = scan_tournament_observations(DATA_DIR)
    print(f"  {len(observations)} fencers have tournament results")

    # --- Diacritic duplicates ---
    print("\n" + "=" * 70)
    print("DIACRITIC DUPLICATES")
    print("=" * 70)
    duplicates = detect_diacritic_duplicates(fencers)
    if not duplicates:
        print("  None found.")
    for dup_ids in duplicates:
        for fid in dup_ids:
            f = fencers[fid]
            obs_count = len(observations.get(fid, []))
            print(f"  id={fid:>3} line={f['line_num']:>3}  {f['surname']:25} {f['first_name']:15} "
                  f"birth={f['birth_year'] or 'NULL':>5}  results={obs_count}")
        # Recommend keeping the one with birth year / more results
        print()

    # --- Birth year inference ---
    print("=" * 70)
    print("BIRTH YEAR INFERENCE")
    print("=" * 70)

    confirmed = []   # exact birth year from crossing
    estimated = []    # midpoint from single category
    conflicts = []    # contradictory observations

    for fid, f in sorted(fencers.items()):
        if f["birth_year"] is not None:
            continue
        obs = observations.get(fid, [])
        if not obs:
            continue

        min_yr, max_yr, source = infer_birth_year_range(obs)

        if source == "conflict":
            conflicts.append((fid, f, obs))
        elif source == "crossing" and min_yr == max_yr:
            confirmed.append((fid, f, min_yr, obs))
        elif min_yr is not None and max_yr is not None:
            midpoint = (min_yr + max_yr) // 2
            categories = set(cat for _, cat in obs)
            cat_str = "/".join(sorted(categories))
            estimated.append((fid, f, midpoint, cat_str, min_yr, max_yr))

    print(f"\n  CONFIRMED (exact, from category crossing): {len(confirmed)}")
    for fid, f, year, obs in confirmed:
        cats = " + ".join(f"{cat}@{yr}" for yr, cat in sorted(set(obs)))
        print(f"    id={fid:>3} line={f['line_num']:>3}  {f['surname']:25} {f['first_name']:15} → {year}  ({cats})")

    print(f"\n  ESTIMATED (midpoint, single category): {len(estimated)}")
    for fid, f, midpoint, cat_str, min_yr, max_yr in estimated:
        print(f"    id={fid:>3} line={f['line_num']:>3}  {f['surname']:25} {f['first_name']:15} → {midpoint}  "
              f"({cat_str}, range {min_yr}-{max_yr})")

    if conflicts:
        print(f"\n  CONFLICTS (contradictory observations): {len(conflicts)}")
        for fid, f, obs in conflicts:
            print(f"    id={fid:>3} line={f['line_num']:>3}  {f['surname']:25} {f['first_name']:15}  obs={obs}")

    # --- Summary ---
    total_inferred = len(confirmed) + len(estimated)
    remaining_null = null_count - total_inferred
    print(f"\n{'=' * 70}")
    print(f"SUMMARY")
    print(f"  Total NULL birth years: {null_count}")
    print(f"  Confirmed (crossing):   {len(confirmed)}")
    print(f"  Estimated (midpoint):   {len(estimated)}")
    print(f"  Conflicts:              {len(conflicts)}")
    print(f"  Still unknown:          {remaining_null}")
    print(f"  Diacritic duplicates:   {len(duplicates)}")
    print(f"{'=' * 70}")

    # --- Generate SQL-style output for seed file updates ---
    if confirmed or estimated:
        print(f"\n{'=' * 70}")
        print("SEED FILE UPDATES (copy these into seed_tbl_fencer.sql)")
        print(f"{'=' * 70}")
        for fid, f, year, obs in confirmed:
            print(f"  line {f['line_num']:>3}: NULL → {year}  -- CONFIRMED from category crossing")
        for fid, f, midpoint, cat_str, min_yr, max_yr in estimated:
            print(f"  line {f['line_num']:>3}: NULL → {midpoint}  -- ESTIMATED from {cat_str} category (range {min_yr}-{max_yr})")


if __name__ == "__main__":
    main()