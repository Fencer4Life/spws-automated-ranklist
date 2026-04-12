"""
Schema-driven monolithic PROD export (ADR-036).

Generates a single timestamped SQL file that recreates all data.
Discovers columns at runtime — future-proof.

Usage:
    python -m python.pipeline.export_seed --ref ywgymtgcyturldazcpmw
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import date

import httpx


# ---------------------------------------------------------------------------
# Management API
# ---------------------------------------------------------------------------
def mgmt_query(ref: str, token: str, sql: str) -> list[dict]:
    url = f"https://api.supabase.com/v1/projects/{ref}/database/query"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    for attempt in range(3):
        try:
            resp = httpx.post(url, headers=headers, json={"query": sql}, timeout=60)
        except httpx.ReadTimeout:
            if attempt < 2:
                time.sleep(3 * (attempt + 1))
                continue
            raise
        if resp.status_code in (401, 429, 503):
            time.sleep(5 * (attempt + 1))
            continue
        if resp.status_code >= 400:
            raise RuntimeError(f"API error ({resp.status_code}): {resp.text[:300]}")
        return resp.json()
    raise RuntimeError("Management API: max retries exceeded")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
SKIP_COLS = {"ts_created", "ts_updated"}
AUTO_ID_COLS = {"id_fencer", "id_season", "id_organizer", "id_event", "id_tournament",
                "id_result", "id_scoring_config", "id_match_candidate"}


def esc(s: str | None) -> str:
    if s is None:
        return "NULL"
    return s.replace("'", "''")


def sql_val(val, dtype: str) -> str:
    if val is None:
        return "NULL"
    if dtype in ("integer", "smallint", "numeric", "bigint", "real", "double precision"):
        return str(val)
    if dtype == "boolean":
        return "TRUE" if val else "FALSE"
    if dtype == "jsonb":
        return f"'{esc(json.dumps(val))}'"
    if dtype == "ARRAY":
        if isinstance(val, list):
            els = ", ".join(f"'{esc(str(e))}'" for e in val)
            return f"ARRAY[{els}]" if els else "ARRAY[]::TEXT[]"
        return f"'{esc(str(val))}'"
    return f"'{esc(str(val))}'"


def discover_cols(ref: str, token: str, table: str) -> list[dict]:
    """Get all data columns (excluding auto-generated)."""
    rows = mgmt_query(ref, token, f"""
    SELECT column_name, data_type, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = '{table}'
    ORDER BY ordinal_position
    """)
    cols = []
    for r in rows:
        name = r["column_name"]
        if name in SKIP_COLS:
            continue
        default = r.get("column_default") or ""
        if "nextval" in default:
            continue
        cols.append({"name": name, "type": r["data_type"]})
    return cols


def select_expr(cols: list[dict]) -> str:
    """Build SELECT expression with casts for special types."""
    parts = []
    for c in cols:
        if c["type"] in ("date", "timestamp with time zone", "timestamp without time zone"):
            parts.append(f"{c['name']}::TEXT")
        elif c["type"] == "USER-DEFINED":
            parts.append(f"{c['name']}::TEXT")
        else:
            parts.append(c["name"])
    return ", ".join(parts)


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
def export_monolithic(ref: str, token: str) -> str:
    """Generate complete monolithic SQL dump from remote DB."""
    q = lambda sql: mgmt_query(ref, token, sql)
    lines: list[str] = []

    lines.append(f"-- =============================================================================")
    lines.append(f"-- PROD Data Dump — {date.today().isoformat()}")
    lines.append(f"-- Source: {ref}")
    lines.append(f"-- Schema-driven export (ADR-036) — columns discovered at runtime")
    lines.append(f"-- =============================================================================")
    lines.append("")

    # --- tbl_season ---
    print("  tbl_season...", file=sys.stderr)
    cols = discover_cols(ref, token, "tbl_season")
    col_names = [c["name"] for c in cols]
    rows = q(f"SELECT {select_expr(cols)} FROM tbl_season ORDER BY dt_start")
    lines.append(f"-- tbl_season ({len(rows)} rows)")
    for r in rows:
        vals = ", ".join(sql_val(r.get(c["name"]), c["type"]) for c in cols)
        lines.append(f"INSERT INTO tbl_season ({', '.join(col_names)}) VALUES ({vals});")
    lines.append("")

    # --- tbl_organizer ---
    print("  tbl_organizer...", file=sys.stderr)
    cols = discover_cols(ref, token, "tbl_organizer")
    col_names = [c["name"] for c in cols]
    rows = q(f"SELECT {select_expr(cols)} FROM tbl_organizer ORDER BY txt_code")
    lines.append(f"-- tbl_organizer ({len(rows)} rows)")
    for r in rows:
        vals = ", ".join(sql_val(r.get(c["name"]), c["type"]) for c in cols)
        lines.append(f"INSERT INTO tbl_organizer ({', '.join(col_names)}) VALUES ({vals});")
    lines.append("")

    # --- tbl_scoring_config (UPDATE after trigger-created defaults) ---
    print("  tbl_scoring_config...", file=sys.stderr)
    sc_cols = discover_cols(ref, token, "tbl_scoring_config")
    sc_cols_no_id = [c for c in sc_cols if c["name"] != "id_season"]
    sc_select = ", ".join(
        f"sc.{c['name']}::TEXT" if c["type"] in ("date", "USER-DEFINED") else f"sc.{c['name']}"
        for c in sc_cols
    )
    rows = q(f"""
    SELECT {sc_select}, s.txt_code AS season_code
    FROM tbl_scoring_config sc
    JOIN tbl_season s ON s.id_season = sc.id_season
    ORDER BY s.dt_start
    """)
    lines.append(f"-- tbl_scoring_config ({len(rows)} rows, via UPDATE)")
    for r in rows:
        sets = []
        for c in sc_cols_no_id:
            v = r.get(c["name"])
            if v is not None:
                sets.append(f"{c['name']} = {sql_val(v, c['type'])}")
        if sets:
            lines.append(
                f"UPDATE tbl_scoring_config SET {', '.join(sets)} "
                f"WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = '{r['season_code']}');"
            )
    lines.append("")

    # --- tbl_fencer ---
    print("  tbl_fencer...", file=sys.stderr)
    cols = discover_cols(ref, token, "tbl_fencer")
    col_names = [c["name"] for c in cols]
    rows = q(f"SELECT {select_expr(cols)} FROM tbl_fencer ORDER BY txt_surname, txt_first_name")
    lines.append(f"-- tbl_fencer ({len(rows)} rows)")
    vals_list = []
    for r in rows:
        vals = ", ".join(sql_val(r.get(c["name"]), c["type"]) for c in cols)
        vals_list.append(f"  ({vals})")
    lines.append(f"INSERT INTO tbl_fencer ({', '.join(col_names)}) VALUES")
    lines.append(",\n".join(vals_list) + ";")
    lines.append("")

    # --- tbl_event (per season) ---
    print("  tbl_event...", file=sys.stderr)
    ev_cols = discover_cols(ref, token, "tbl_event")
    ev_cols_no_fk = [c for c in ev_cols if c["name"] not in ("id_season", "id_organizer")]
    ev_col_names = [c["name"] for c in ev_cols_no_fk]

    seasons = q("SELECT id_season, txt_code FROM tbl_season ORDER BY dt_start")

    all_events = q(f"""
    SELECT e.id_event, e.id_season, {', '.join(f'e.{c["name"]}::TEXT' if c['type'] in ('date','USER-DEFINED') else f'e.{c["name"]}' for c in ev_cols_no_fk)},
           s.txt_code AS season_code,
           o.txt_code AS org_code
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
    JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
    ORDER BY s.dt_start, e.dt_start, e.txt_code
    """)
    lines.append(f"-- tbl_event ({len(all_events)} rows)")
    for ev in all_events:
        vals = [f"(SELECT id_season FROM tbl_season WHERE txt_code = '{ev['season_code']}')"]
        vals.append(f"(SELECT id_organizer FROM tbl_organizer WHERE txt_code = '{ev['org_code']}')")
        for c in ev_cols_no_fk:
            vals.append(sql_val(ev.get(c["name"]), c["type"]))
        insert_cols = ["id_season", "id_organizer"] + ev_col_names
        lines.append(f"INSERT INTO tbl_event ({', '.join(insert_cols)}) VALUES ({', '.join(vals)});")
    lines.append("")

    # --- tbl_tournament + tbl_result (bulk queries) ---
    print("  tbl_tournament (bulk)...", file=sys.stderr)
    t_cols = discover_cols(ref, token, "tbl_tournament")
    t_cols_no_fk = [c for c in t_cols if c["name"] != "id_event"]
    t_col_names = [c["name"] for c in t_cols_no_fk]

    # Bulk fetch ALL tournaments with event code
    t_select = ", ".join(
        f"t.{c['name']}::TEXT" if c["type"] in ("date", "USER-DEFINED") else f"t.{c['name']}"
        for c in t_cols_no_fk
    )
    all_tournaments = q(f"""
    SELECT t.id_tournament, e.txt_code AS event_code, {t_select}
    FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event
    ORDER BY e.txt_code, t.txt_code
    """)

    # Bulk fetch ALL results with fencer names and tournament codes
    print("  tbl_result (bulk)...", file=sys.stderr)
    all_results = q("""
    SELECT t.txt_code AS tourn_code, r.int_place, r.num_final_score,
           f.txt_surname, f.txt_first_name
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
    ORDER BY t.txt_code, r.int_place
    """)

    # Index results by tournament code
    results_by_tourn: dict[str, list[dict]] = {}
    for r in all_results:
        results_by_tourn.setdefault(r["tourn_code"], []).append(r)

    # Generate SQL
    total_tournaments = 0
    total_results = 0
    seen_tourn_codes: set[str] = set()
    current_event = ""

    for t in all_tournaments:
        ev_code = t["event_code"]
        t_code = t["txt_code"]

        # Skip duplicate tournament codes (same code under different events)
        if t_code in seen_tourn_codes:
            continue
        seen_tourn_codes.add(t_code)

        if ev_code != current_event:
            current_event = ev_code
            lines.append(f"\n-- {ev_code}")

        t_vals = [f"(SELECT id_event FROM tbl_event WHERE txt_code = '{esc(ev_code)}')"]
        for c in t_cols_no_fk:
            t_vals.append(sql_val(t.get(c["name"]), c["type"]))
        insert_cols = ["id_event"] + t_col_names
        lines.append(
            f"INSERT INTO tbl_tournament ({', '.join(insert_cols)}) "
            f"SELECT {', '.join(t_vals)} "
            f"WHERE NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE txt_code = '{esc(t_code)}');"
        )
        total_tournaments += 1

        # Results for this tournament
        for r in results_by_tourn.get(t_code, []):
            surname = esc(r["txt_surname"])
            first_name = esc(r["txt_first_name"])
            score = str(r["num_final_score"]) if r["num_final_score"] is not None else "NULL"
            lines.append(
                f"INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score) "
                f"SELECT "
                f"(SELECT id_fencer FROM tbl_fencer WHERE txt_surname = '{surname}' AND txt_first_name = '{first_name}' LIMIT 1), "
                f"(SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{esc(t_code)}'), "
                f"{r['int_place']}, {score} "
                f"WHERE NOT EXISTS (SELECT 1 FROM tbl_result WHERE id_fencer = "
                f"(SELECT id_fencer FROM tbl_fencer WHERE txt_surname = '{surname}' AND txt_first_name = '{first_name}' LIMIT 1) "
                f"AND id_tournament = (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{esc(t_code)}'));"
            )
            total_results += 1

    # --- tbl_match_candidate (bulk) ---
    print("  tbl_match_candidate (bulk)...", file=sys.stderr)
    all_mc = q("""
    SELECT mc.txt_scraped_name, mc.num_confidence, mc.enum_status::TEXT,
           mc.txt_admin_note,
           f.txt_surname AS fencer_surname, f.txt_first_name AS fencer_first,
           t.txt_code AS tourn_code, r.int_place
    FROM tbl_match_candidate mc
    JOIN tbl_result r ON r.id_result = mc.id_result
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    LEFT JOIN tbl_fencer f ON f.id_fencer = mc.id_fencer
    ORDER BY mc.id_match
    """)
    total_mc = 0
    if all_mc:
        lines.append(f"\n-- tbl_match_candidate ({len(all_mc)} rows)")
        for mc in all_mc:
            scraped = esc(mc["txt_scraped_name"])
            conf = str(mc["num_confidence"]) if mc["num_confidence"] is not None else "NULL"
            status = mc["enum_status"]
            note = f"'{esc(mc['txt_admin_note'])}'" if mc.get("txt_admin_note") else "NULL"
            t_code = esc(mc["tourn_code"])
            place = mc["int_place"]

            # Reconstruct id_result via tournament code + fencer + place
            fencer_surname = esc(mc.get("fencer_surname") or "")
            fencer_first = esc(mc.get("fencer_first") or "")

            # id_fencer subselect (NULL if no fencer linked)
            if mc.get("fencer_surname"):
                fencer_sel = f"(SELECT id_fencer FROM tbl_fencer WHERE txt_surname = '{fencer_surname}' AND txt_first_name = '{fencer_first}' LIMIT 1)"
            else:
                fencer_sel = "NULL"

            # id_result subselect via tournament + place + fencer
            result_sel = (
                f"(SELECT r.id_result FROM tbl_result r "
                f"JOIN tbl_tournament t ON t.id_tournament = r.id_tournament "
                f"WHERE t.txt_code = '{t_code}' AND r.int_place = {place} "
                f"AND r.id_fencer = {fencer_sel} LIMIT 1)"
            )

            lines.append(
                f"INSERT INTO tbl_match_candidate (id_result, id_fencer, txt_scraped_name, num_confidence, enum_status, txt_admin_note) "
                f"SELECT {result_sel}, {fencer_sel}, '{scraped}', {conf}, '{status}'::enum_match_status, {note} "
                f"WHERE {result_sel} IS NOT NULL;"
            )
            total_mc += 1

    lines.append(f"\n-- Total: {total_tournaments} tournaments, {total_results} results, {total_mc} match candidates")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Monolithic PROD export (ADR-036)")
    parser.add_argument("--ref", required=True, help="Supabase project ref")
    parser.add_argument("--output", default=None, help="Output file (default: timestamped)")
    args = parser.parse_args()

    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not token:
        print("ERROR: SUPABASE_ACCESS_TOKEN not set", file=sys.stderr)
        sys.exit(1)

    stamp = date.today().isoformat()
    out_path = args.output or os.path.join("supabase", f"seed_prod_{stamp}.sql")

    print(f"Exporting {args.ref} → {out_path}", file=sys.stderr)
    sql = export_monolithic(args.ref, token)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(sql)
    print(f"  Written: {out_path} ({len(sql)//1024} KB)", file=sys.stderr)

    # Update latest symlink
    latest = os.path.join("supabase", "seed_prod_latest.sql")
    if os.path.islink(latest) or os.path.exists(latest):
        os.remove(latest)
    os.symlink(os.path.basename(out_path), latest)
    print(f"  Symlink: {latest} → {os.path.basename(out_path)}", file=sys.stderr)

    print("Done.", file=sys.stderr)


if __name__ == "__main__":
    main()
