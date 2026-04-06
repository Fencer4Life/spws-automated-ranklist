"""Fix 2024-25 seed files: replace ASCII scraped-name lookups with correct diacritic names.

The convert_seed_ids.py script used txt_scraped_name (ASCII) for fencer lookups,
but tbl_fencer has Polish diacritics. This script:
1. Parses the old fencer seed (pre-CERT export) to build ID→name mapping
2. Reads the original 2024-25 files from git (with hardcoded IDs)
3. Rewrites them with correct name-based subselects
"""

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SEED_DIR = REPO_ROOT / "supabase" / "data" / "2024_25"
OLD_COMMIT = "030f4f3"  # Last commit before CERT export changed fencer table
SKIP_FILES = {"season_config.sql", "zz_events_metadata.sql"}


def parse_old_fencer_seed(sql_text: str) -> dict[int, tuple[str, str]]:
    """Parse old fencer INSERT to build id→(surname, first_name) mapping.

    IDs are auto-increment starting at 1, assigned in INSERT order.
    """
    # Match each VALUES tuple: ('SURNAME', 'FirstName', year_or_NULL)
    pattern = re.compile(r"\('([^']+)',\s*'([^']+)',\s*(?:\d+|NULL)\)")
    mapping = {}
    fencer_id = 1
    for match in pattern.finditer(sql_text):
        surname = match.group(1).strip()
        first_name = match.group(2).strip()
        mapping[fencer_id] = (surname, first_name)
        fencer_id += 1
    return mapping


def get_old_file(filepath: str) -> str:
    """Get file contents from old git commit."""
    result = subprocess.run(
        ["git", "show", f"{OLD_COMMIT}:{filepath}"],
        capture_output=True, text=True, cwd=REPO_ROOT
    )
    if result.returncode != 0:
        raise RuntimeError(f"git show failed for {filepath}: {result.stderr}")
    return result.stdout


def convert_file(sql_text: str, id_map: dict[int, tuple[str, str]]) -> tuple[str, int]:
    """Convert hardcoded fencer IDs to name-based subselects. Returns (new_sql, count)."""

    # Pattern: matches a bare integer on its own line (the fencer ID in VALUES)
    # Context: appears after "VALUES (\n" and before ",\n    (SELECT id_tournament..."
    # We look for: VALUES (\n    <number>,\n
    pattern = re.compile(
        r"(INSERT INTO tbl_result \(id_fencer, id_tournament, int_place.*?\)\nVALUES \(\n)"
        r"    (\d+),\n"
        r"(    \(SELECT id_tournament)",
        re.DOTALL
    )

    count = 0
    def replacer(m):
        nonlocal count
        fencer_id = int(m.group(2))
        if fencer_id not in id_map:
            print(f"  WARNING: fencer ID {fencer_id} not found in mapping", file=sys.stderr)
            return m.group(0)

        surname, first_name = id_map[fencer_id]
        # Escape single quotes in names
        surname_esc = surname.replace("'", "''")
        first_name_esc = first_name.replace("'", "''")

        count += 1
        return (
            f"{m.group(1)}"
            f"    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = '{surname_esc}' AND txt_first_name = '{first_name_esc}' LIMIT 1),\n"
            f"{m.group(3)}"
        )

    new_sql = pattern.sub(replacer, sql_text)
    return new_sql, count


def main():
    # Step 1: Parse old fencer seed
    old_fencer_sql = get_old_file("supabase/seed_tbl_fencer.sql")
    id_map = parse_old_fencer_seed(old_fencer_sql)
    print(f"Parsed {len(id_map)} fencer ID mappings from old seed")

    # Step 2: Process each 2024-25 file
    total = 0
    for sql_file in sorted(SEED_DIR.glob("*.sql")):
        if sql_file.name in SKIP_FILES:
            continue

        # Get the original file from git (with hardcoded IDs)
        git_path = f"supabase/data/2024_25/{sql_file.name}"
        try:
            original_sql = get_old_file(git_path)
        except RuntimeError:
            print(f"  SKIP {sql_file.name} — not in old commit")
            continue

        new_sql, count = convert_file(original_sql, id_map)

        if count > 0:
            sql_file.write_text(new_sql, encoding="utf-8")
            print(f"  {sql_file.name}: {count} replacements")
            total += count
        else:
            # Write the original back (in case convert_seed_ids.py broke it)
            sql_file.write_text(original_sql, encoding="utf-8")
            print(f"  {sql_file.name}: 0 replacements (restored original)")

    print(f"\nTotal: {total} replacements")


if __name__ == "__main__":
    main()
