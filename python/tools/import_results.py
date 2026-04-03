"""
Result importer — reads ODS Tournaments tab, dispatches to parsers, generates SQL.

Reads the staging spreadsheet's Tournaments tab and for each tournament:
- If source_file points to an Excel/XML file → parse via file_import
- If result_url is set → (future) use scraper
- If import_status is LOST/EMPTY → skip

Outputs per-category SQL files with INSERT statements.

CLI:
    python python/tools/import_results.py --ods PATH [--season SEASON] [--dry-run] [--output-dir DIR]
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class TournamentSpec:
    """Parsed tournament row from the staging spreadsheet."""

    tournament_code: str
    event_code: str
    event_prefix: str
    season_code: str
    weapon: str
    gender: str
    age_cat: str
    tournament_type: str
    source_file: str
    result_url: str
    import_status: str


# Statuses that mean "no data available"
_SKIP_STATUSES = {"LOST", "EMPTY"}


def _cell_text(cell) -> str:
    """Extract text content from an ODF TableCell."""
    from odf.text import P

    paras = cell.getElementsByType(P)
    if paras:
        return "".join(
            node.data if hasattr(node, "data") else str(node)
            for p in paras
            for node in p.childNodes
            if hasattr(node, "data")
        )
    return ""


def read_tournaments_from_ods(
    ods_path: Path | str,
    season_filter: str | None = None,
) -> list[TournamentSpec]:
    """Read Tournaments tab from ODS → list[TournamentSpec].

    Args:
        ods_path: Path to the staging spreadsheet.
        season_filter: If set, only return rows matching this season_code.
    """
    from odf.opendocument import load
    from odf.table import Table, TableRow, TableCell

    doc = load(str(ods_path))
    tables = doc.getElementsByType(Table)

    # Find Tournaments tab
    tourn_table = None
    for t in tables:
        if t.getAttribute("name") == "Tournaments":
            tourn_table = t
            break

    if tourn_table is None:
        raise ValueError("No 'Tournaments' tab found in spreadsheet")

    rows = tourn_table.getElementsByType(TableRow)
    if len(rows) < 2:
        return []

    # Header row (row 0) — read column names
    header_cells = rows[0].getElementsByType(TableCell)
    headers = [_cell_text(c) for c in header_cells]

    # Map column names to indices
    col_map = {name: i for i, name in enumerate(headers) if name}

    specs = []
    for row in rows[1:]:
        cells = row.getElementsByType(TableCell)
        if not cells:
            continue

        def get(col_name: str) -> str:
            idx = col_map.get(col_name)
            if idx is None or idx >= len(cells):
                return ""
            return _cell_text(cells[idx])

        season = get("season_code")
        if not season:
            continue
        if season_filter and season != season_filter:
            continue

        # tournament_code and event_code are formula cells —
        # compute from components (formulas may not have cached values)
        event_prefix = get("event_prefix")
        weapon = get("weapon")
        gender = get("gender")
        age_cat = get("age_cat")
        tournament_code = (
            f"{event_prefix}-{age_cat}-{gender}-{weapon}-{season}"
        )
        event_code = f"{event_prefix}-{season}"

        specs.append(TournamentSpec(
            tournament_code=tournament_code,
            event_code=event_code,
            event_prefix=event_prefix,
            season_code=season,
            weapon=weapon,
            gender=gender,
            age_cat=age_cat,
            tournament_type=get("type"),
            source_file=get("source_file"),
            result_url=get("result_url"),
            import_status=get("import_status"),
        ))

    return specs


def extract_results(
    spec: TournamentSpec,
    base_dir: Path,
) -> list[dict] | None:
    """Extract results for a tournament from its source.

    Returns:
        list[dict] with fencer_name/place/country, or None if skipped.
    """
    if spec.import_status in _SKIP_STATUSES:
        return None

    if spec.source_file:
        source_path = base_dir / spec.source_file
        if not source_path.exists():
            return None
        from scrapers.file_import import parse_file

        file_bytes = source_path.read_bytes()
        return parse_file(file_bytes, spec.source_file)

    # Future: handle result_url via scrapers
    if spec.result_url:
        return None

    return None


def _parse_fencer_name(fencer_name: str) -> tuple[str, str]:
    """Split 'SURNAME FirstName' into (surname, first_name)."""
    parts = fencer_name.strip().split(None, 1)
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[1]


def _sql_escape(value: str) -> str:
    """Escape single quotes for SQL string literals."""
    return value.replace("'", "''")


def generate_tournament_sql(
    spec: TournamentSpec,
    results: list[dict],
) -> str:
    """Generate SQL INSERT statements for one tournament's results.

    Returns:
        SQL string with INSERT INTO tbl_result + fn_calc_tournament_scores call.
    """
    lines = []
    lines.append(f"-- Tournament: {spec.tournament_code}")
    if spec.source_file:
        lines.append(f"-- Source: {spec.source_file}")
    lines.append("")

    if not results:
        lines.append("-- No results to import")
        return "\n".join(lines)

    # Build INSERT statement
    lines.append("INSERT INTO tbl_result (id_tournament, id_fencer, int_place) VALUES")

    value_lines = []
    for r in results:
        surname, first_name = _parse_fencer_name(r["fencer_name"])
        surname_esc = _sql_escape(surname)
        first_name_esc = _sql_escape(first_name)
        tournament_code_esc = _sql_escape(spec.tournament_code)

        tourn_subquery = (
            f"(SELECT id_tournament FROM tbl_tournament "
            f"WHERE txt_code = '{tournament_code_esc}')"
        )

        if first_name:
            fencer_subquery = (
                f"(SELECT id_fencer FROM tbl_fencer "
                f"WHERE txt_surname = '{surname_esc}' "
                f"AND txt_first_name = '{first_name_esc}')"
            )
        else:
            fencer_subquery = (
                f"(SELECT id_fencer FROM tbl_fencer "
                f"WHERE txt_surname = '{surname_esc}')"
            )

        value_lines.append(
            f"  ({tourn_subquery},\n"
            f"   {fencer_subquery}, {r['place']})"
        )

    lines.append(",\n".join(value_lines) + ";")
    lines.append("")
    lines.append(
        f"SELECT fn_calc_tournament_scores('{_sql_escape(spec.tournament_code)}');"
    )

    return "\n".join(lines)


def write_category_sql(
    specs_with_results: list[tuple[TournamentSpec, list[dict]]],
    output_dir: Path,
) -> list[Path]:
    """Write per-category SQL files.

    Groups tournaments by (season, weapon, gender, age_cat) and writes
    one SQL file per group.

    Returns:
        List of written file paths.
    """
    # Group by category key
    groups: dict[tuple[str, str, str, str], list[tuple[TournamentSpec, list[dict]]]] = {}
    for spec, results in specs_with_results:
        key = (spec.season_code, spec.weapon, spec.gender, spec.age_cat)
        groups.setdefault(key, []).append((spec, results))

    written = []
    for (season, weapon, gender, age_cat), items in groups.items():
        season_dir = output_dir / season
        season_dir.mkdir(parents=True, exist_ok=True)
        filename = f"{weapon}_{gender}_{age_cat}.sql"
        filepath = season_dir / filename

        sql_parts = []
        for spec, results in items:
            sql_parts.append(generate_tournament_sql(spec, results))

        filepath.write_text("\n\n".join(sql_parts) + "\n")
        written.append(filepath)

    return written


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import tournament results from staging spreadsheet.",
    )
    parser.add_argument(
        "--ods", type=Path, required=True,
        help="Path to staging spreadsheet (.ods)",
    )
    parser.add_argument(
        "--season", type=str, default=None,
        help="Filter to specific season (e.g., SPWS-2024-2025)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print summary without writing files",
    )
    parser.add_argument(
        "--output-dir", type=Path, default=Path("supabase/data"),
        help="Output directory for SQL files (default: supabase/data)",
    )
    args = parser.parse_args()

    specs = read_tournaments_from_ods(args.ods, season_filter=args.season)
    print(f"Found {len(specs)} tournament(s)")

    if args.dry_run:
        for spec in specs:
            status = spec.import_status
            source = spec.source_file or spec.result_url or "(no source)"
            print(f"  {spec.tournament_code}  status={status}  source={source}")
        print(f"\nDry run — no files written.")
        return

    # Extract results and write SQL
    specs_with_results = []
    skipped = 0
    errors = 0
    for spec in specs:
        results = extract_results(spec, base_dir=args.ods.parent)
        if results is None:
            skipped += 1
            continue
        specs_with_results.append((spec, results))

    if specs_with_results:
        written = write_category_sql(specs_with_results, args.output_dir)
        for path in written:
            print(f"  Wrote {path}")

    print(
        f"\nDone: {len(specs_with_results)} imported, "
        f"{skipped} skipped, {errors} errors"
    )


if __name__ == "__main__":
    main()
