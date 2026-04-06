"""
Full-season seed export from CERT (ADR-027).

Reads entire active season from CERT via Management API.
Generates seed SQL files matching the existing format in supabase/data/{season}/.

Usage:
    python -m python.pipeline.export_seed --cert-ref <ref>
"""

from __future__ import annotations

import argparse
import os
import sys

import httpx


def _management_query(ref: str, access_token: str, sql: str) -> list[dict]:
    """Execute SQL via Supabase Management API with retry."""
    import time

    url = f"https://api.supabase.com/v1/projects/{ref}/database/query"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    payload = {"query": sql}

    for attempt in range(3):
        try:
            resp = httpx.post(url, headers=headers, json=payload, timeout=60)
        except httpx.ReadTimeout:
            if attempt < 2:
                time.sleep(3 * (attempt + 1))
                continue
            raise

        if resp.status_code in (429, 503):
            time.sleep(3 * (attempt + 1))
            continue
        if resp.status_code >= 400:
            raise RuntimeError(f"Management API error ({resp.status_code}): {resp.text}")
        return resp.json()

    raise RuntimeError("Management API: max retries exceeded")


def _esc(s: str) -> str:
    """Escape single quotes for SQL."""
    return s.replace("'", "''") if s else ""


def export_fencer_seed(
    query_fn=None,
    cert_ref: str | None = None,
    access_token: str | None = None,
) -> str:
    """Export full tbl_fencer as seed SQL."""
    if query_fn is None:
        query_fn = lambda sql: _management_query(cert_ref, access_token, sql)

    rows = query_fn(
        "SELECT txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated "
        "FROM tbl_fencer ORDER BY txt_surname, txt_first_name"
    )

    lines = [
        "-- Master Fencer List — tbl_fencer",
        f"-- {len(rows)} fencers — auto-exported from CERT (ADR-027)",
        "-- Auto-loaded via config.toml sql_paths glob after seed.sql",
        "",
        "INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated) VALUES",
    ]

    value_lines = []
    for r in rows:
        surname = _esc(r["txt_surname"])
        first_name = _esc(r["txt_first_name"])
        by = r["int_birth_year"]
        estimated = r.get("bool_birth_year_estimated", False)
        by_str = str(by) if by else "NULL"
        est_str = "TRUE" if estimated else "FALSE"
        comment = " -- ESTIMATED" if estimated else ""
        value_lines.append((f"    ('{surname}', '{first_name}', {by_str}, {est_str})", comment))

    # Build VALUES with commas before comments to avoid breaking SQL
    parts = []
    for i, (val, comment) in enumerate(value_lines):
        sep = "," if i < len(value_lines) - 1 else ";"
        parts.append(f"{val}{sep}{comment}")
    lines.append("\n".join(parts))
    return "\n".join(lines) + "\n"


def export_full_season(
    season_code: str,
    query_fn=None,
    cert_ref: str | None = None,
    access_token: str | None = None,
) -> dict[str, str]:
    """Export full season as per-category SQL files + zz_events_metadata.sql.

    Returns dict mapping filename → SQL content.
    """
    if query_fn is None:
        query_fn = lambda sql: _management_query(cert_ref, access_token, sql)

    # Fetch all events in this season
    events = query_fn(
        f"SELECT id_event, txt_code, txt_name, txt_location, txt_country, "
        f"dt_start::TEXT, dt_end::TEXT, url_event, url_invitation, "
        f"num_entry_fee, txt_entry_fee_currency, enum_status::TEXT "
        f"FROM tbl_event WHERE id_season = "
        f"(SELECT id_season FROM tbl_season WHERE txt_code = '{season_code}') "
        f"ORDER BY dt_start, txt_code"
    )

    # Fetch tournaments per event, results per tournament
    category_files: dict[str, list[str]] = {}
    metadata_lines: list[str] = []

    for event in events:
        event_code = event["txt_code"]
        event_name = _esc(event["txt_name"])
        event_id = event["id_event"]

        # Event metadata for zz_events_metadata.sql
        metadata_lines.append(f"\n-- ---- {event_code} ----")
        metadata_lines.append(
            f"INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)\n"
            f"SELECT '{event_code}', '{event_name}',\n"
            f"    (SELECT id_season FROM tbl_season WHERE txt_code = '{season_code}'),\n"
            f"    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),\n"
            f"    '{event['enum_status']}'\n"
            f"WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = '{event_code}');"
        )

        # Event enrichment
        updates = []
        if event.get("txt_location"):
            updates.append(f"    txt_location = '{_esc(event['txt_location'])}'")
        if event.get("txt_country"):
            updates.append(f"    txt_country = '{_esc(event['txt_country'])}'")
        if event.get("dt_start"):
            updates.append(f"    dt_start = '{event['dt_start']}'")
        if event.get("dt_end"):
            updates.append(f"    dt_end = '{event['dt_end']}'")
        if event.get("url_event"):
            updates.append(f"    url_event = '{_esc(event['url_event'])}'")
        if event.get("url_invitation"):
            updates.append(f"    url_invitation = '{_esc(event['url_invitation'])}'")
        if event.get("num_entry_fee"):
            updates.append(f"    num_entry_fee = {event['num_entry_fee']}")
        if event.get("txt_entry_fee_currency"):
            updates.append(f"    txt_entry_fee_currency = '{event['txt_entry_fee_currency']}'")

        if updates:
            metadata_lines.append(
                f"UPDATE tbl_event SET\n"
                + ",\n".join(updates) + "\n"
                f"WHERE txt_code = '{event_code}';"
            )

        # Fetch tournaments
        tournaments = query_fn(
            f"SELECT id_tournament, txt_code, txt_name, enum_type::TEXT, "
            f"enum_weapon::TEXT, enum_gender::TEXT, enum_age_category::TEXT, "
            f"dt_tournament::TEXT, int_participant_count, url_results, "
            f"enum_import_status::TEXT "
            f"FROM tbl_tournament WHERE id_event = {event_id} ORDER BY txt_code"
        )

        for tourn in tournaments:
            tourn_code = tourn["txt_code"]

            # Fetch results first — skip empty tournaments (0 results)
            results = query_fn(
                f"SELECT r.int_place, r.num_final_score, f.txt_surname, f.txt_first_name "
                f"FROM tbl_result r "
                f"JOIN tbl_fencer f ON r.id_fencer = f.id_fencer "
                f"WHERE r.id_tournament = {tourn['id_tournament']} "
                f"ORDER BY r.int_place"
            )
            if not results:
                continue

            cat = tourn["enum_age_category"].lower()
            gender = tourn["enum_gender"].lower()
            weapon = tourn["enum_weapon"].lower()
            filename = f"{cat}_{gender}_{weapon}.sql"
            tourn_name = _esc(tourn.get("txt_name") or event_name)

            lines = category_files.setdefault(filename, [])

            # Event INSERT (idempotent)
            lines.append(f"\n-- ---- {event_code}: {event_name} ----")
            lines.append(
                f"INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)\n"
                f"SELECT\n"
                f"    '{event_code}',\n"
                f"    '{event_name}',\n"
                f"    '{_esc(event.get('txt_location') or '')}',\n"
                f"    (SELECT id_season FROM tbl_season WHERE txt_code = '{season_code}'),\n"
                f"    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),\n"
                f"    '{event['enum_status']}'\n"
                f"WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = '{event_code}');"
            )

            # Tournament INSERT
            dt = tourn["dt_tournament"] or "NULL"
            dt_sql = f"'{dt}'" if dt != "NULL" else "NULL"
            lines.append(
                f"INSERT INTO tbl_tournament (\n"
                f"    id_event, txt_code, txt_name, enum_type,\n"
                f"    enum_weapon, enum_gender, enum_age_category,\n"
                f"    dt_tournament, int_participant_count, url_results,\n"
                f"    enum_import_status\n"
                f") VALUES (\n"
                f"    (SELECT id_event FROM tbl_event WHERE txt_code = '{event_code}'),\n"
                f"    '{tourn_code}',\n"
                f"    '{tourn_name}',\n"
                f"    '{tourn['enum_type']}',\n"
                f"    '{tourn['enum_weapon']}', '{tourn['enum_gender']}', '{tourn['enum_age_category']}',\n"
                f"    {dt_sql}, {tourn['int_participant_count'] or 0}, NULL,\n"
                f"    'SCORED'\n"
                f");"
            )

            for r in results:
                surname = _esc(r["txt_surname"])
                first_name = _esc(r["txt_first_name"])
                place = r["int_place"]
                score = r["num_final_score"]
                score_sql = str(score) if score is not None else "NULL"
                scraped = f"{surname} {first_name}"
                lines.append(
                    f"INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)\n"
                    f"VALUES (\n"
                    f"    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = '{surname}' AND txt_first_name = '{first_name}' LIMIT 1),\n"
                    f"    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{tourn_code}'),\n"
                    f"    {place}, {score_sql}\n"
                    f"); -- {scraped}"
                )

    # Build final SQL files
    result: dict[str, str] = {}
    season_short = season_code.replace("SPWS-", "")

    for filename, lines in category_files.items():
        cat_label = filename.replace(".sql", "").upper().replace("_", " ")
        header = (
            f"-- =========================================================================\n"
            f"-- Season {season_short} — {cat_label} — auto-exported from CERT (ADR-027)\n"
            f"-- Auto-loaded by supabase db reset via config.toml sql_paths glob.\n"
            f"-- =========================================================================\n"
        )
        result[filename] = header + "\n".join(lines) + "\n"

    # zz_events_metadata.sql
    if metadata_lines:
        meta_header = (
            f"-- =========================================================================\n"
            f"-- Season {season_short} — Events Metadata — auto-exported from CERT (ADR-027)\n"
            f"-- =========================================================================\n"
        )
        result["zz_events_metadata.sql"] = meta_header + "\n".join(metadata_lines) + "\n"

    return result


def write_seed_files(file_map: dict[str, str], base_dir: str) -> list[str]:
    """Write seed SQL files to disk. Overwrites existing files.

    Returns list of file paths written.
    """
    os.makedirs(base_dir, exist_ok=True)
    written = []
    for filename, content in file_map.items():
        filepath = os.path.join(base_dir, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        written.append(filepath)
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description="Export full-season seed from CERT")
    parser.add_argument("--cert-ref", required=True, help="CERT Supabase project ref")
    parser.add_argument("--season", default="SPWS-2025-2026", help="Season code")
    args = parser.parse_args()

    access_token = os.environ["SUPABASE_ACCESS_TOKEN"]

    print(f"Exporting season {args.season} from CERT ({args.cert_ref})...")

    # Export fencer seed
    fencer_sql = export_fencer_seed(cert_ref=args.cert_ref, access_token=access_token)
    fencer_path = os.path.join("supabase", "seed_tbl_fencer.sql")
    with open(fencer_path, "w", encoding="utf-8") as f:
        f.write(fencer_sql)
    print(f"  {fencer_path}")

    # Export season data
    season_dir = args.season.replace("SPWS-", "").replace("-", "_")
    base_dir = os.path.join("supabase", "data", season_dir)
    files = export_full_season(
        season_code=args.season,
        cert_ref=args.cert_ref,
        access_token=access_token,
    )
    written = write_seed_files(files, base_dir)
    for p in written:
        print(f"  {p}")

    print(f"Done: {len(written) + 1} files exported.")


if __name__ == "__main__":
    main()
