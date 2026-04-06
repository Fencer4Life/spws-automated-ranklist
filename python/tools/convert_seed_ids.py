#!/usr/bin/env python3
"""Convert hardcoded fencer IDs in 2024-25 seed SQL files to name-based subselect lookups.

Transforms:
    VALUES (
        311,
        (SELECT id_tournament ...),
        3,
        'ZIELIŃSKI Dariusz'
    ); -- matched: ...

Into:
    VALUES (
        (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz' LIMIT 1),
        (SELECT id_tournament ...),
        3,
        'ZIELIŃSKI Dariusz'
    ); -- matched: ...
"""

import re
from pathlib import Path

SEED_DIR = Path(__file__).resolve().parents[2] / "supabase" / "data" / "2024_25"
SKIP_FILES = {"season_config.sql", "zz_events_metadata.sql"}


def parse_scraped_name(name: str) -> tuple[str, str]:
    """Split 'SURNAME FirstName' into (surname, first_name).

    Surname is everything up to the last space, first name is the rest.
    """
    parts = name.rsplit(" ", 1)
    if len(parts) == 2:
        return parts[0], parts[1]
    # Fallback: single-word name
    return parts[0], ""


def sql_escape(s: str) -> str:
    """Escape single quotes for SQL string literals."""
    return s.replace("'", "''")


def convert_file(path: Path) -> int:
    """Convert one SQL file. Returns number of replacements made."""
    text = path.read_text(encoding="utf-8")

    # Pattern: match the numeric ID line inside a tbl_result INSERT VALUES block.
    # We look for the pattern:
    #   VALUES (\n    <numeric_id>,\n    (SELECT id_tournament ...
    # and later in the same block:
    #   'SCRAPED NAME'\n);
    #
    # Strategy: match the full VALUES(...); block for tbl_result inserts and replace.

    # This regex matches the entire INSERT INTO tbl_result ... VALUES (...); block
    pattern = re.compile(
        r"(INSERT INTO tbl_result \(id_fencer, id_tournament, int_place, txt_scraped_name\)\s*"
        r"VALUES \(\s*)"           # group 1: INSERT preamble up to first value
        r"\d+"                      # the numeric fencer ID to replace
        r"(,\s*"                   # group 2: comma after ID
        r"\(SELECT id_tournament[^)]+\),\s*"  # tournament subselect
        r"\d+,\s*"                 # int_place
        r"'([^']*(?:''[^']*)*)')" # group 3: txt_scraped_name content (handles escaped quotes)
        r"(\s*\))"                 # group 4: closing paren
        , re.DOTALL
    )

    count = 0

    def replacer(m: re.Match) -> str:
        nonlocal count
        count += 1
        preamble = m.group(1)
        rest = m.group(2)
        scraped_name = m.group(3).replace("''", "'")  # unescape for parsing
        closing = m.group(4)

        surname, first_name = parse_scraped_name(scraped_name)
        subselect = (
            f"(SELECT id_fencer FROM tbl_fencer "
            f"WHERE txt_surname = '{sql_escape(surname)}' "
            f"AND txt_first_name = '{sql_escape(first_name)}' LIMIT 1)"
        )
        return f"{preamble}{subselect}{rest}{closing}"

    new_text = pattern.sub(replacer, text)
    if count > 0:
        path.write_text(new_text, encoding="utf-8")
    return count


def main() -> None:
    total = 0
    files_changed = 0
    for sql_file in sorted(SEED_DIR.glob("*.sql")):
        if sql_file.name in SKIP_FILES:
            continue
        n = convert_file(sql_file)
        if n > 0:
            files_changed += 1
            total += n
            print(f"  {sql_file.name}: {n} replacements")
    print(f"\nDone: {total} replacements across {files_changed} files.")


if __name__ == "__main__":
    main()
