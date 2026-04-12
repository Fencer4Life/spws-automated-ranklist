"""
Fix CERT/PROD data gaps by re-ingesting tournaments from source URLs.

For each tournament with a url_results in the active season:
1. Scrape the source URL to get full participant list
2. Compare against DB results
3. Insert missing results + fix participant count
4. Recalculate scores via fn_calc_tournament_scores

Usage:
    python -m python.tools.fix_cert_gaps --env cert --pol-only --dry-run
    python -m python.tools.fix_cert_gaps --env cert --pol-only
    python -m python.tools.fix_cert_gaps --env cert
"""

from __future__ import annotations

import argparse
import json
import sys
import time

import httpx

from python.tools.audit_results import (
    ENVS, SUPABASE_ACCESS_TOKEN, MGMT_API,
    query_db, fetch_tournaments_with_urls, scrape_url, normalize_name, names_match,
)


def fetch_fencer_db(ref: str | None) -> list[dict]:
    """Fetch all fencers from CERT/PROD for matching."""
    sql = """
    SELECT id_fencer, txt_surname, txt_first_name,
           txt_surname || ' ' || txt_first_name AS full_name
    FROM tbl_fencer
    ORDER BY id_fencer;
    """
    rows = query_db(ref, sql)
    return [
        {"id_fencer": int(r[0]), "surname": r[1], "first_name": r[2], "full_name": r[3]}
        for r in rows
    ]


def fetch_db_results_detailed(ref: str | None, tournament_code: str) -> list[dict]:
    """Fetch results with fencer names for a tournament."""
    sql = f"""
    SELECT r.id_result, f.id_fencer,
           f.txt_surname || ' ' || f.txt_first_name AS name,
           r.int_place, r.num_final_score
    FROM tbl_result r
    JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE t.txt_code = '{tournament_code}'
    ORDER BY r.int_place;
    """
    rows = query_db(ref, sql)
    return [
        {"id_result": int(r[0]), "id_fencer": int(r[1]), "name": r[2],
         "place": int(r[3]), "score": float(r[4]) if r[4] else 0}
        for r in rows
    ]


def match_fencer(scraped_name: str, fencer_db: list[dict]) -> int | None:
    """Find fencer ID by name matching. Returns id_fencer or None."""
    sn = normalize_name(scraped_name)
    # Exact match first
    for f in fencer_db:
        if normalize_name(f["full_name"]) == sn:
            return f["id_fencer"]
    # Surname + first initial match
    parts = sn.split()
    if len(parts) >= 2:
        for f in fencer_db:
            fn = normalize_name(f["full_name"])
            fp = fn.split()
            if len(fp) >= 2 and parts[0] == fp[0] and parts[1][0] == fp[1][0]:
                return f["id_fencer"]
    return None


def fix_tournament(
    ref: str | None,
    tournament: dict,
    fencer_db: list[dict],
    pol_only: bool,
    dry_run: bool,
) -> dict:
    """Fix gaps for a single tournament. Returns summary."""
    code = tournament["txt_code"]
    url = tournament["url_results"]

    try:
        scraped = scrape_url(url)
    except Exception as e:
        return {"code": code, "error": str(e), "inserted": 0, "skipped": 0}

    if pol_only and tournament["enum_type"] in ("PEW", "MEW", "MSW", "PSW"):
        scraped = [r for r in scraped if r.get("country", "") == "POL"]

    db_results = fetch_db_results_detailed(ref, code)
    db_names = {normalize_name(r["name"]) for r in db_results}

    # Find missing fencers
    missing = []
    for sr in scraped:
        matched = False
        for dn in db_names:
            if names_match(sr["fencer_name"], dn):
                matched = True
                break
        if not matched:
            fencer_id = match_fencer(sr["fencer_name"], fencer_db)
            missing.append({
                "fencer_name": sr["fencer_name"],
                "place": sr["place"],
                "country": sr.get("country", ""),
                "id_fencer": fencer_id,
            })

    if not missing:
        return {"code": code, "error": None, "inserted": 0, "skipped": 0}

    # Fix participant count
    full_scraped = scrape_url(url) if pol_only else scraped
    actual_count = len(full_scraped) if not pol_only else None

    inserted = 0
    skipped = 0

    for m in missing:
        if m["id_fencer"] is None:
            skipped += 1
            continue

        if dry_run:
            print(f"    DRY: INSERT #{m['place']} {m['fencer_name']} "
                  f"(fencer_id={m['id_fencer']})", file=sys.stderr)
            inserted += 1
            continue

        # Insert the missing result
        sql = f"""
        INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
        SELECT {m['id_fencer']},
               (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{code}'),
               {m['place']},
               NULL
        WHERE NOT EXISTS (
            SELECT 1 FROM tbl_result r
            JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
            WHERE t.txt_code = '{code}' AND r.id_fencer = {m['id_fencer']}
        );
        """
        try:
            query_db(ref, sql)
            inserted += 1
        except Exception as e:
            print(f"    ERROR inserting {m['fencer_name']}: {e}", file=sys.stderr)

    # Update participant count and recalculate scores
    if inserted > 0 and not dry_run:
        # Get total result count for this tournament
        count_sql = f"""
        SELECT COUNT(*) FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        WHERE t.txt_code = '{code}';
        """
        rows = query_db(ref, count_sql)
        new_count = int(rows[0][0]) if rows else 0

        # Update participant count
        update_sql = f"""
        UPDATE tbl_tournament SET int_participant_count = {new_count}
        WHERE txt_code = '{code}';
        """
        query_db(ref, update_sql)

        # Recalculate scores
        score_sql = f"""
        SELECT fn_calc_tournament_scores(
            (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{code}')
        );
        """
        try:
            query_db(ref, score_sql)
        except Exception as e:
            print(f"    WARN: score recalc failed for {code}: {e}", file=sys.stderr)

    return {
        "code": code,
        "error": None,
        "inserted": inserted,
        "skipped": skipped,
        "missing_total": len(missing),
    }


def main():
    parser = argparse.ArgumentParser(description="Fix CERT/PROD data gaps")
    parser.add_argument("--env", required=True, choices=["cert", "prod", "local"])
    parser.add_argument("--pol-only", action="store_true",
                        help="For international tournaments, only fix POL fencers")
    parser.add_argument("--tournament", default=None,
                        help="Fix a single tournament (default: all with URLs)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be fixed without making changes")
    args = parser.parse_args()

    env = ENVS[args.env]
    ref = env["ref"]

    print(f"=== Fix Gaps: {args.env.upper()} {'(DRY RUN)' if args.dry_run else ''} ===",
          file=sys.stderr)

    # Fetch fencer database for matching
    print("Loading fencer database...", file=sys.stderr)
    fencer_db = fetch_fencer_db(ref)
    print(f"  {len(fencer_db)} fencers loaded", file=sys.stderr)

    # Get tournaments to fix
    if args.tournament:
        sql = f"""
        SELECT t.txt_code, t.url_results, t.int_participant_count, t.enum_type,
               t.enum_weapon::TEXT, t.enum_gender::TEXT, t.enum_age_category::TEXT,
               e.txt_code AS event_code, e.txt_location
        FROM tbl_tournament t
        JOIN tbl_event e ON e.id_event = t.id_event
        WHERE t.txt_code = '{args.tournament}';
        """
        rows = query_db(ref, sql)
        if not rows:
            print(f"Tournament {args.tournament} not found", file=sys.stderr)
            sys.exit(1)
        r = rows[0]
        tournaments = [{
            "txt_code": r[0], "url_results": r[1],
            "int_participant_count": int(r[2]) if r[2] else 0,
            "enum_type": r[3], "enum_weapon": r[4],
            "enum_gender": r[5], "enum_age_category": r[6],
            "event_code": r[7], "location": r[8],
        }]
    else:
        tournaments = fetch_tournaments_with_urls(ref)

    if not tournaments:
        print("No tournaments with URLs found", file=sys.stderr)
        sys.exit(0)

    print(f"Processing {len(tournaments)} tournaments...\n", file=sys.stderr)

    total_inserted = 0
    total_skipped = 0
    total_errors = 0

    for i, t in enumerate(tournaments, 1):
        print(f"[{i}/{len(tournaments)}] {t['txt_code']} ...", end="", file=sys.stderr)
        result = fix_tournament(ref, t, fencer_db, args.pol_only, args.dry_run)

        if result["error"]:
            total_errors += 1
            print(f" ERROR: {result['error']}", file=sys.stderr)
        elif result["inserted"] > 0 or result["skipped"] > 0:
            total_inserted += result["inserted"]
            total_skipped += result["skipped"]
            print(f" +{result['inserted']} inserted, {result['skipped']} unmatched "
                  f"(of {result['missing_total']} missing)", file=sys.stderr)
        else:
            print(f" OK", file=sys.stderr)

        time.sleep(0.5)  # Rate limit

    print(f"\n{'='*60}", file=sys.stderr)
    print(f"FIX SUMMARY ({args.env.upper()}) {'DRY RUN' if args.dry_run else ''}",
          file=sys.stderr)
    print(f"  Tournaments processed: {len(tournaments)}", file=sys.stderr)
    print(f"  Results inserted:      {total_inserted}", file=sys.stderr)
    print(f"  Fencers unmatched:     {total_skipped}", file=sys.stderr)
    print(f"  Errors:                {total_errors}", file=sys.stderr)
    print(f"{'='*60}", file=sys.stderr)


if __name__ == "__main__":
    main()
