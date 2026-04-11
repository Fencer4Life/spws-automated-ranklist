#!/usr/bin/env python3
"""Remove duplicate fencer rows from seed_tbl_fencer.sql and remap all ID references.

Removes specified fencer lines and adjusts all fencer ID references in
supabase/data/**/*.sql files to account for the shifted auto-increment IDs.

Usage:
    python python/tools/remove_duplicate_fencers.py --dry-run   # preview changes
    python python/tools/remove_duplicate_fencers.py             # apply changes
"""

import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SEED_FENCER_PATH = PROJECT_ROOT / "supabase" / "seed_tbl_fencer.sql"
DATA_DIR = PROJECT_ROOT / "supabase" / "data"

# Lines to remove from seed_tbl_fencer.sql (1-based line numbers)
# These must be in ascending order.
# Line 295: ('GAWLE', 'Katarzyna (kat 1)', 1989) — duplicate of GAWLE Katarzyna id=63
# Line 356: ('SPŁAWA-NEYMAN', '(0) MACIEJ', 1981) — duplicate of SPŁAWA-NEYMAN MACIEJ id=349
# Line 363: ('SZEPIETOWSKI', 'Rafał (kat 0)', 1979) — duplicate of SZEPIETOWSKI Rafał id=222
# Line 365: ('SZMAJDZIŃSKA', '- BOŁDYS Katarzyna', 1992) — duplicate of SZMAJDZIŃSKA Katarzyna id=358
# Line 367: ('SZMELC', '(0) Łukasz', 1981) — duplicate of SZMELC Łukasz id=360
# Line 372: ('TECŁAW', '(1) Robert', 1991) — duplicate of TECŁAW Robert id=232
# Line 379: ('ZAJĄC', '(1) Michał', 1991) — duplicate of ZAJĄC Michał id=263
LINES_TO_REMOVE = [295, 356, 363, 365, 367, 372, 379]


def compute_id_remap(lines_to_remove: list[int], first_data_line: int = 9) -> dict[int, int]:
    """Compute old_id → new_id mapping after removing specified lines.

    first_data_line: line number of the first VALUES entry (id=1).
    """
    # Convert line numbers to fencer IDs
    removed_ids = [line - first_data_line + 1 for line in lines_to_remove]
    removed_set = set(removed_ids)

    # Find max possible ID (generous upper bound)
    max_id = max(removed_ids) + 200
    remap = {}
    shift = 0
    for old_id in range(1, max_id + 1):
        if old_id in removed_set:
            shift += 1
            remap[old_id] = None  # deleted
        else:
            new_id = old_id - shift
            if new_id != old_id:
                remap[old_id] = new_id

    return remap


def remap_seed_data_files(data_dir: Path, remap: dict[int, int | None], dry_run: bool) -> int:
    """Update fencer ID references in all seed SQL data files.

    Returns total number of replacements made.
    """
    # Pattern matches fencer ID in INSERT INTO tbl_result blocks:
    # "VALUES (\n    <id>,"
    # The ID is on its own line, indented, followed by a comma.
    id_line_pattern = re.compile(r"^(\s+)(\d+)(,\s*)$")

    total_replacements = 0
    files_modified = 0

    for sql_file in sorted(data_dir.rglob("*.sql")):
        if sql_file.name.startswith("zz_"):
            continue

        lines = sql_file.read_text(encoding="utf-8").splitlines(keepends=True)
        modified = False
        new_lines = []

        i = 0
        while i < len(lines):
            line = lines[i]

            # Check if previous line(s) contain INSERT INTO tbl_result ... VALUES (
            # The fencer ID is typically 2 lines after "INSERT INTO tbl_result"
            if i >= 2 and "tbl_result" in lines[i - 2]:
                m = id_line_pattern.match(line)
                if m:
                    indent, id_str, suffix = m.groups()
                    old_id = int(id_str)
                    if old_id in remap:
                        new_id = remap[old_id]
                        if new_id is None:
                            print(f"  ERROR: {sql_file.name}:{i+1} references deleted fencer id={old_id}")
                        else:
                            if dry_run:
                                print(f"  {sql_file.name}:{i+1}  id {old_id} → {new_id}")
                            new_lines.append(f"{indent}{new_id}{suffix}")
                            modified = True
                            total_replacements += 1
                            i += 1
                            continue

            new_lines.append(line)
            i += 1

        if modified and not dry_run:
            sql_file.write_text("".join(new_lines), encoding="utf-8")
            files_modified += 1

    return total_replacements


def remove_seed_lines(seed_path: Path, lines_to_remove: list[int], dry_run: bool):
    """Remove specified lines from seed_tbl_fencer.sql, handling trailing comma."""
    text = seed_path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    # Convert to 0-based indices
    remove_indices = set(ln - 1 for ln in lines_to_remove)

    for idx in sorted(remove_indices):
        line = lines[idx].rstrip("\n")
        print(f"  Removing line {idx+1}: {line.strip()}")

    if dry_run:
        return

    new_lines = []
    for i, line in enumerate(lines):
        if i in remove_indices:
            continue
        new_lines.append(line)

    # Fix trailing comma on the last VALUES entry (should end with ';' not ',')
    # Find the last non-empty line that looks like a VALUES tuple
    for i in range(len(new_lines) - 1, -1, -1):
        stripped = new_lines[i].rstrip()
        if stripped.endswith("),"):
            # This is the last entry — change trailing comma to semicolon
            new_lines[i] = new_lines[i].rstrip().rstrip(",") + ";\n"
            break
        elif stripped.endswith(");"):
            break  # already correct

    seed_path.write_text("".join(new_lines), encoding="utf-8")


def main():
    dry_run = "--dry-run" in sys.argv

    if dry_run:
        print("=== DRY RUN (no files will be modified) ===\n")
    else:
        print("=== APPLYING CHANGES ===\n")

    # Step 1: Compute remap
    remap = compute_id_remap(LINES_TO_REMOVE)
    removed_ids = [ln - 8 for ln in LINES_TO_REMOVE]
    print(f"Removing fencer IDs: {removed_ids}")
    print(f"IDs that need remapping: {sum(1 for v in remap.values() if v is not None)}")

    # Step 2: Remap data files
    print(f"\nRemapping fencer IDs in {DATA_DIR}...")
    total = remap_seed_data_files(DATA_DIR, remap, dry_run)
    print(f"  Total replacements: {total}")

    # Step 3: Remove lines from seed file
    print(f"\nRemoving lines from {SEED_FENCER_PATH.name}...")
    remove_seed_lines(SEED_FENCER_PATH, LINES_TO_REMOVE, dry_run)

    # Step 4: Update fencer count in header comment
    if not dry_run:
        text = SEED_FENCER_PATH.read_text(encoding="utf-8")
        old_count = len(LINES_TO_REMOVE)
        # Update "378 SPWS members" → "376 SPWS members" (or whatever the count was)
        text = re.sub(
            r"(\d+) SPWS members",
            lambda m: f"{int(m.group(1)) - old_count} SPWS members",
            text,
            count=1,
        )
        SEED_FENCER_PATH.write_text(text, encoding="utf-8")

    print(f"\nDone! Removed {len(LINES_TO_REMOVE)} duplicate fencers.")
    if dry_run:
        print("\nRe-run without --dry-run to apply changes.")


if __name__ == "__main__":
    main()