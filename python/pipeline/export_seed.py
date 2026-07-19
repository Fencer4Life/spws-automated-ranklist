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
AUTO_ID_COLS = {
    "id_fencer",
    "id_season",
    "id_organizer",
    "id_event",
    "id_tournament",
    "id_result",
    "id_scoring_config",
    "id_match_candidate",
}


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
    rows = mgmt_query(
        ref,
        token,
        f"""
    SELECT column_name, data_type, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = '{table}'
    ORDER BY ordinal_position
    """,
    )
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
def fencer_lookup(surname: str, first_name: str, birth_year: int | None) -> str:
    """FK sub-SELECT resolving a fencer by SURNAME + Name + BIRTH YEAR.

    Name alone is not an identity. PROD holds two same-name pairs that are
    different people -- KRAWCZYK Paweł (1954 / 1989) and MŁYNEK Janusz
    (1951 / 1984) -- so a bare `txt_surname = … AND txt_first_name = … LIMIT 1`
    resolves arbitrarily. The seed then binds a result to the wrong person and
    fn_assert_result_vcat (ADR-047) aborts the load on every fresh bootstrap.

    A NULL birth year must compare with IS NULL: `int_birth_year = NULL` is
    never true and would resolve to no row at all, turning a soft ambiguity
    into a hard FK failure for the fencers who have no year on record.

    Governed by the ADR-036 amendment (2026-07-14).
    """
    by = f"int_birth_year = {birth_year}" if birth_year is not None else "int_birth_year IS NULL"
    return (
        f"(SELECT id_fencer FROM tbl_fencer "
        f"WHERE txt_surname = '{esc(surname)}' AND txt_first_name = '{esc(first_name)}' "
        f"AND {by} LIMIT 1)"
    )


def export_monolithic(ref: str, token: str) -> str:
    """Generate complete monolithic SQL dump from remote DB."""

    def q(sql):
        return mgmt_query(ref, token, sql)

    lines: list[str] = []

    lines.append("-- =============================================================================")
    lines.append(f"-- PROD Data Dump — {date.today().isoformat()}")
    lines.append(f"-- Source: {ref}")
    lines.append("-- Schema-driven export (ADR-036) — columns discovered at runtime")
    lines.append("-- =============================================================================")
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
    # id_prior_event is a self-referential FK (carry-over link, migration
    # 20260627000001). It MUST be re-resolved by the prior event's txt_code —
    # emitting the raw integer id corrupts the link on reload, where serial ids
    # are reassigned (the prior event's id differs from the source env's).
    ev_cols_no_fk = [
        c for c in ev_cols if c["name"] not in ("id_season", "id_organizer", "id_prior_event")
    ]
    ev_col_names = [c["name"] for c in ev_cols_no_fk]

    q("SELECT id_season, txt_code FROM tbl_season ORDER BY dt_start")

    ev_select = ", ".join(
        f"e.{c['name']}::TEXT" if c["type"] in ("date", "USER-DEFINED") else f"e.{c['name']}"
        for c in ev_cols_no_fk
    )
    all_events = q(f"""
    SELECT e.id_event, e.id_season, {ev_select},
           s.txt_code AS season_code,
           o.txt_code AS org_code,
           pe.txt_code AS prior_code
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
    JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
    LEFT JOIN tbl_event pe ON pe.id_event = e.id_prior_event
    ORDER BY s.dt_start, e.dt_start, e.txt_code
    """)
    lines.append(f"-- tbl_event ({len(all_events)} rows)")
    for ev in all_events:
        vals = [f"(SELECT id_season FROM tbl_season WHERE txt_code = '{ev['season_code']}')"]
        vals.append(f"(SELECT id_organizer FROM tbl_organizer WHERE txt_code = '{ev['org_code']}')")
        for c in ev_cols_no_fk:
            vals.append(sql_val(ev.get(c["name"]), c["type"]))
        # id_prior_event resolved by the prior event's natural key (txt_code),
        # NULL when the event has no carry-over predecessor. Prior events live
        # in an earlier season so they are always INSERTed before this row.
        prior_code = ev.get("prior_code")
        if prior_code:
            vals.append(f"(SELECT id_event FROM tbl_event WHERE txt_code = '{esc(prior_code)}')")
        else:
            vals.append("NULL")
        insert_cols = ["id_season", "id_organizer"] + ev_col_names + ["id_prior_event"]
        lines.append(
            f"INSERT INTO tbl_event ({', '.join(insert_cols)}) VALUES ({', '.join(vals)});"
        )
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

    # Bulk fetch ALL results with fencer names and tournament codes.
    # Schema-driven: discover all data columns of tbl_result (sans auto-id +
    # FKs which we re-resolve via sub-SELECT). This picks up ADR-056-revision
    # `enum_source_age_category` and any future-added provenance columns —
    # without it, post-revision `fn_assert_result_vcat` falls back to the
    # BY-derived check and rejects rows whose source bracket V-cat differs
    # from BY+season_end_year canonical math (the GP1-V1-SABRE-M case).
    print("  tbl_result (bulk)...", file=sys.stderr)
    r_cols = discover_cols(ref, token, "tbl_result")
    # Skip auto-id + FKs we re-resolve via subquery, and skip score-engine
    # output columns that get recomputed by fn_calc_tournament_scores on
    # post-seed run (avoid drift between exported and recomputed values).
    _R_SKIP = {
        "id_result",
        "id_fencer",
        "id_tournament",
        "num_place_pts",
        "num_de_bonus",
        "num_podium_bonus",
        "num_final_score",
        "ts_points_calc",
    }
    r_cols_data = [c for c in r_cols if c["name"] not in _R_SKIP]
    r_data_select = ", ".join(
        f"r.{c['name']}::TEXT" if c["type"] in ("date", "USER-DEFINED") else f"r.{c['name']}"
        for c in r_cols_data
    )
    all_results = q(f"""
    SELECT t.txt_code AS tourn_code, r.int_place, r.num_final_score,
           f.txt_surname, f.txt_first_name, f.int_birth_year,
           {r_data_select}
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
        # Build INSERT column list: 2 FK sub-SELECTs + every discovered
        # data column (incl. enum_source_age_category for ADR-056 trigger).
        r_insert_cols = ["id_fencer", "id_tournament"] + [c["name"] for c in r_cols_data]
        for r in results_by_tourn.get(t_code, []):
            fencer_sub = fencer_lookup(r["txt_surname"], r["txt_first_name"], r["int_birth_year"])
            tournament_sub = (
                f"(SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{esc(t_code)}')"
            )
            data_vals = [sql_val(r.get(c["name"]), c["type"]) for c in r_cols_data]
            select_cols = ", ".join([fencer_sub, tournament_sub] + data_vals)
            lines.append(
                f"INSERT INTO tbl_result ({', '.join(r_insert_cols)}) "
                f"SELECT {select_cols} "
                f"WHERE NOT EXISTS (SELECT 1 FROM tbl_result "
                f"WHERE id_fencer = {fencer_sub} "
                f"AND id_tournament = {tournament_sub});"
            )
            total_results += 1

    # tbl_match_candidate export removed in Phase 0 (ADR-050).
    # Provenance moves to tbl_result.{txt_scraped_name, num_match_confidence,
    # enum_match_method} and is exported as part of tbl_result rows above.
    # Phase 6 drops the table entirely. Old seed files that still contain
    # COPY tbl_match_candidate sections must be regenerated with this version
    # before being restored — see open risk #6 in the rebuild plan master.

    lines.append(f"\n-- Total: {total_tournaments} tournaments, {total_results} results")
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
    print(f"  Written: {out_path} ({len(sql) // 1024} KB)", file=sys.stderr)

    # Update latest symlink
    latest = os.path.join("supabase", "seed_prod_latest.sql")
    if os.path.islink(latest) or os.path.exists(latest):
        os.remove(latest)
    os.symlink(os.path.basename(out_path), latest)
    print(f"  Symlink: {latest} → {os.path.basename(out_path)}", file=sys.stderr)

    print("Done.", file=sys.stderr)


if __name__ == "__main__":
    main()
