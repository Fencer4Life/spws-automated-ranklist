"""
generate_season_seed.py
-----------------------
Reads reference/SZPADA-2-2024-2025.xlsx and generates
supabase/data/season_2024_25.sql with real tournament and result data
for the SPWS 2024/25 season (Male Epee V2 scope).

Run: python python/tools/generate_season_seed.py
"""

import re
import sys
import math
from pathlib import Path
from datetime import date, datetime

import openpyxl
import psycopg2
from rapidfuzz import fuzz

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
XLSX_PATH = Path("reference/SZPADA-2-2024-2025.xlsx")
OUT_PATH   = Path("supabase/data/season_2024_25.sql")

DB_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"

# Map sheet name → (tournament_type, event_code_prefix, human_name)
SHEET_MAP = {
    "PP1":  ("PPW", "PP1",  "I Puchar Polski Weteranów — Szpada M"),
    "PP2":  ("PPW", "PP2",  "II Puchar Polski Weteranów — Szpada M"),
    "PP3":  ("PPW", "PP3",  "III Puchar Polski Weteranów — Szpada M"),
    "GP7":  ("PPW", "GP7",  "Grand Prix — Szpada M (runda 7)"),
    "GP8":  ("PPW", "GP8",  "Grand Prix — Szpada M (runda 8)"),
    "MPW":  ("MPW", "MPW",  "Mistrzostwa Polski Weteranów — Szpada M"),
    "PEW1": ("PEW", "PEW1", "EVF Grand Prix 1 — Budapeszt"),
    "PEW2": ("PEW", "PEW2", "EVF Grand Prix 2 — Madryt"),
    "PEW7": ("PEW", "PEW7", "EVF Grand Prix 7 — Terni"),
    "PEW8": ("PEW", "PEW8", "EVF Grand Prix 8 — Guildford"),
    "PEW9": ("PEW", "PEW9", "EVF Grand Prix 9 — Sztokholm"),
    "PEW10":("PEW", "PEW10","EVF Grand Prix 10 — Graz"),
    "PEW11":("PEW", "PEW11","EVF Grand Prix 11 — Gdańsk"),
    "PEW12":("PEW", "PEW12","EVF Grand Prix 12 — Ateny"),
    "IMEW": ("MEW", "IMEW", "Indywidualne Mistrzostwa Europy Weteranów — Thionville"),
}

MATCH_THRESHOLD = 80  # minimum fuzzy score to accept a match

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def sq(s):
    """Escape single quotes for SQL."""
    if s is None:
        return "NULL"
    return "'" + str(s).replace("'", "''") + "'"


def parse_date(raw) -> str | None:
    """Return ISO date string from various date formats in the Excel."""
    if raw is None:
        return None
    if isinstance(raw, (datetime, date)):
        return raw.strftime("%Y-%m-%d")
    s = str(raw).strip()
    # "DD.MM.YYYY"
    m = re.match(r"(\d{1,2})\.(\d{2})\.(\d{4})", s)
    if m:
        d, mo, y = m.groups()
        return f"{y}-{mo.zfill(2)}-{d.zfill(2)}"
    # "D-D.MM.YYYY" multi-day event
    m = re.match(r"(\d{1,2})-\d{1,2}\.(\d{2})\.(\d{4})", s)
    if m:
        d, mo, y = m.groups()
        return f"{y}-{mo.zfill(2)}-{d.zfill(2)}"
    # bare year
    m = re.match(r"^(\d{4})$", s)
    if m:
        return f"{s}-01-01"
    return None


def normalize_name(name: str) -> str:
    """Uppercase + strip extra whitespace."""
    return " ".join(name.upper().split())


def fuzzy_match(name: str, fencers: list[tuple]) -> tuple | None:
    """
    Return (id_fencer, fencer_name, score) or None.
    fencers: list of (id, txt_surname, txt_first_name, aliases)
    Checks aliases first (exact, case-insensitive), then fuzzy on full name.
    """
    norm = normalize_name(name)
    # 1. Alias exact match
    for fid, surname, first, aliases in fencers:
        for alias in aliases:
            if normalize_name(alias) == norm:
                return (fid, f"{surname} {first}", 100)
    # 2. Fuzzy match on full name
    best_score = 0
    best_fencer = None
    for fid, surname, first, aliases in fencers:
        full = f"{surname} {first}"
        score = fuzz.token_sort_ratio(norm, full.upper())
        if score > best_score:
            best_score = score
            best_fencer = (fid, f"{surname} {first}")
    if best_score >= MATCH_THRESHOLD:
        return (*best_fencer, best_score)
    return None


def load_fencers(conn) -> list[tuple]:
    """Return list of (id, surname, first_name, aliases_list)."""
    cur = conn.cursor()
    cur.execute("""
        SELECT id_fencer, txt_surname, txt_first_name,
               COALESCE(json_name_aliases::text, '[]')
          FROM tbl_fencer
         ORDER BY id_fencer
    """)
    rows = []
    for fid, surname, first, aliases_json in cur.fetchall():
        import json
        aliases = json.loads(aliases_json)
        rows.append((fid, surname, first, aliases))
    return rows


# ---------------------------------------------------------------------------
# Extract tournament data from one Excel sheet
# ---------------------------------------------------------------------------

def extract_sheet(wb_data, wb_links, sheet_name: str) -> dict:
    """Return dict with tournament metadata and result rows."""
    ws_d = wb_data[sheet_name]
    ws_l = wb_links[sheet_name]

    location = ws_d.cell(2, 3).value
    date_raw  = ws_d.cell(3, 3).value
    n         = ws_d.cell(2, 8).value   # participant count

    url = None
    hl  = ws_l.cell(2, 3).hyperlink
    if hl:
        url = hl.target

    results = []
    for r in range(6, ws_d.max_row + 1):
        name  = ws_d.cell(r, 3).value
        place = ws_d.cell(r, 8).value
        if not name or name in ("x", "X", ""):
            continue
        if not isinstance(place, int):
            continue
        results.append({"name": str(name).strip(), "place": place})

    return {
        "location": location,
        "date":     parse_date(date_raw),
        "n":        n if isinstance(n, int) else None,
        "url":      url,
        "results":  results,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print(f"Reading {XLSX_PATH} ...")
    wb_data  = openpyxl.load_workbook(XLSX_PATH, data_only=True)
    wb_links = openpyxl.load_workbook(XLSX_PATH)  # for hyperlinks

    print(f"Connecting to DB ...")
    conn = psycopg2.connect(DB_URL)
    fencers = load_fencers(conn)
    print(f"  Loaded {len(fencers)} fencers from DB")
    conn.close()

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    lines = []
    lines += [
        "-- =========================================================================",
        "-- Season 2024/25 real data — generated from SZPADA-2-2024-2025.xlsx",
        "-- Run AFTER seed.sql (which creates the season and organizers).",
        "-- =========================================================================",
        "",
        "-- Expand season start to cover EVF rounds from Dec 2023 / early 2024",
        "UPDATE tbl_season",
        "   SET dt_start = '2023-06-01'",
        " WHERE txt_code = 'SPWS-2024-2025';",
        "",
        "-- Remove the placeholder sample event/tournament from seed.sql",
        "DELETE FROM tbl_tournament",
        " WHERE txt_code = 'PPW1-V2-M-EPEE-2025';",
        "DELETE FROM tbl_event",
        " WHERE txt_code = 'PPW1-KRAKOW-2025';",
        "",
    ]

    total_matched   = 0
    total_unmatched = 0
    tournament_codes = []

    for sheet_name, (ttype, code, human_name) in SHEET_MAP.items():
        if sheet_name not in wb_data.sheetnames:
            print(f"  SKIP {sheet_name}: not found in workbook")
            continue

        data = extract_sheet(wb_data, wb_links, sheet_name)
        loc  = data["location"] or "?"
        dt   = data["date"]
        n    = data["n"]
        url  = data["url"]

        # Skip tournaments with N=0 (e.g. PEW10 Graz — no participants)
        if n == 0:
            print(f"  SKIP {sheet_name}: N=0 (no participants)")
            lines += [
                f"-- SKIP {sheet_name} ({human_name}): N=0 — tournament had no participants",
                "",
            ]
            continue

        event_code = f"{code}-2024-2025"
        tourn_code = f"{code}-V2-M-EPEE-2024-2025"
        tournament_codes.append(tourn_code)

        dt_sql   = sq(dt)
        url_sql  = sq(url)
        loc_sql  = sq(loc)

        organizer = "'EVF'" if ttype in ("PEW", "MEW") else "(SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS')"
        organizer_raw = "EVF" if ttype in ("PEW", "MEW") else "SPWS"

        lines += [
            f"-- ---- {sheet_name}: {human_name} ----",
            f"INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)",
            f"VALUES (",
            f"    {sq(event_code)},",
            f"    {sq(human_name)},",
            f"    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),",
            f"    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = {sq(organizer_raw)}),",
            f"    'COMPLETED'",
            f");",
            f"INSERT INTO tbl_tournament (",
            f"    id_event, txt_code, txt_name, enum_type,",
            f"    enum_weapon, enum_gender, enum_age_category,",
            f"    dt_tournament, int_participant_count, url_results,",
            f"    enum_import_status",
            f") VALUES (",
            f"    (SELECT id_event FROM tbl_event WHERE txt_code = {sq(event_code)}),",
            f"    {sq(tourn_code)},",
            f"    {sq(human_name)},",
            f"    '{ttype}',",
            f"    'EPEE', 'M', 'V2',",
            f"    {dt_sql}, {n}, {url_sql},",
            f"    'SCORED'",
            f");",
        ]

        matched_in_tournament = 0
        unmatched_in_tournament = 0

        for row in data["results"]:
            name  = row["name"]
            place = row["place"]
            match = fuzzy_match(name, fencers)

            if match:
                fid, matched_name, score = match
                matched_in_tournament += 1
                lines += [
                    f"INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)",
                    f"VALUES (",
                    f"    {fid},",
                    f"    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = {sq(tourn_code)}),",
                    f"    {place},",
                    f"    {sq(name)}",
                    f"); -- matched: {matched_name} (score={score})",
                ]
            else:
                unmatched_in_tournament += 1
                lines += [
                    f"-- UNMATCHED (score<{MATCH_THRESHOLD}): {sq(name)} place={place}",
                ]

        total_matched   += matched_in_tournament
        total_unmatched += unmatched_in_tournament
        print(f"  {sheet_name}: N={n}, results={len(data['results'])}, matched={matched_in_tournament}, unmatched={unmatched_in_tournament}")

        lines += [
            f"-- Compute scores for {tourn_code}",
            f"SELECT fn_calc_tournament_scores(",
            f"    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = {sq(tourn_code)})",
            f");",
            "",
        ]

    lines += [
        "-- Summary",
        f"-- Total results matched:   {total_matched}",
        f"-- Total results unmatched: {total_unmatched}",
        "",
    ]

    sql = "\n".join(lines)
    OUT_PATH.write_text(sql, encoding="utf-8")
    print(f"\nWrote {OUT_PATH}")
    print(f"Total matched: {total_matched}, unmatched: {total_unmatched}")


if __name__ == "__main__":
    main()
