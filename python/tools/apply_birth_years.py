#!/usr/bin/env python3
"""Apply inferred birth years to seed_tbl_fencer.sql.

Reads infer_birth_years.py logic and updates NULL birth years in-place.
Adds source comments: -- CONFIRMED or -- ESTIMATED.

Usage:
    python python/tools/apply_birth_years.py --dry-run   # preview changes
    python python/tools/apply_birth_years.py             # apply changes
"""

import re
import sys
from pathlib import Path

# Reuse inference logic
sys.path.insert(0, str(Path(__file__).parent))
from infer_birth_years import (
    SEED_FENCER_PATH,
    DATA_DIR,
    parse_fencers,
    scan_tournament_observations,
    infer_birth_year_range,
)


def main():
    dry_run = "--dry-run" in sys.argv

    fencers = parse_fencers(SEED_FENCER_PATH)
    observations = scan_tournament_observations(DATA_DIR)

    # Build line_num → (year, source_comment) mapping
    updates: dict[int, tuple[int, str]] = {}

    for fid, f in sorted(fencers.items()):
        if f["birth_year"] is not None:
            continue
        obs = observations.get(fid, [])
        if not obs:
            continue

        min_yr, max_yr, source = infer_birth_year_range(obs)

        if source == "conflict":
            continue

        if source == "crossing" and min_yr == max_yr:
            updates[f["line_num"]] = (min_yr, "CONFIRMED from category crossing")
        elif min_yr is not None and max_yr is not None:
            midpoint = (min_yr + max_yr) // 2
            categories = set(cat for _, cat in obs)
            cat_str = "/".join(sorted(categories))
            updates[f["line_num"]] = (midpoint, f"ESTIMATED from {cat_str} (range {min_yr}-{max_yr})")

    if dry_run:
        print(f"=== DRY RUN: {len(updates)} birth years to update ===\n")

    # Apply updates to seed file
    text = SEED_FENCER_PATH.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    changes = 0

    for line_num, (year, comment) in sorted(updates.items()):
        idx = line_num - 1
        line = lines[idx]

        # Replace NULL with year, add comment
        new_line = line.rstrip("\n").rstrip()

        # Handle existing comment
        if " -- " in new_line:
            new_line = new_line[: new_line.index(" -- ")]

        # Replace NULL with year value
        new_line = re.sub(r"\bNULL\b", str(year), new_line)
        new_line = f"{new_line} -- {comment}\n"

        if dry_run:
            print(f"  line {line_num}: {line.strip()}")
            print(f"       → {new_line.strip()}\n")
        else:
            lines[idx] = new_line
            changes += 1

    if not dry_run:
        SEED_FENCER_PATH.write_text("".join(lines), encoding="utf-8")
        print(f"Updated {changes} birth years in {SEED_FENCER_PATH.name}")
    else:
        print(f"\nRe-run without --dry-run to apply {len(updates)} changes.")


if __name__ == "__main__":
    main()