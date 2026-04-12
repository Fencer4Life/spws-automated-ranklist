"""
Promote active-season data from CERT to PROD.

Syncs: tbl_fencer, tbl_event, tbl_tournament, tbl_result, url_results,
       int_participant_count, and recalculates scores.

Usage:
    python -m python.tools.promote_cert_to_prod --dry-run
    python -m python.tools.promote_cert_to_prod
"""

from __future__ import annotations

import argparse
import sys
import time

from python.tools.audit_results import query_db

CERT_REF = "sdomfjncmfydlkygzpgw"
PROD_REF = "ywgymtgcyturldazcpmw"


def sync_fencers(dry_run: bool) -> int:
    """Copy missing fencers from CERT to PROD."""
    # Get all CERT fencers
    cert_fencers = query_db(CERT_REF, """
    SELECT txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated,
           txt_nationality, enum_gender
    FROM tbl_fencer
    ORDER BY id_fencer
    """)
    prod_fencers = {
        r[0] + "|" + r[1]
        for r in query_db(PROD_REF, "SELECT txt_surname, txt_first_name FROM tbl_fencer")
    }

    inserted = 0
    for f in cert_fencers:
        key = f"{f[0]}|{f[1]}"
        if key not in prod_fencers:
            if dry_run:
                print(f"    DRY: INSERT fencer {f[0]} {f[1]}", file=sys.stderr)
            else:
                birth_year = f"'{f[2]}'" if f[2] else "NULL"
                estimated = f[3] if f[3] is not None else "FALSE"
                nationality = f"'{f[4]}'" if f[4] else "NULL"
                gender = f"'{f[5]}'" if f[5] else "NULL"
                query_db(PROD_REF, f"""
                INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                    bool_birth_year_estimated, txt_nationality, enum_gender)
                VALUES ('{f[0]}', '{f[1]}', {birth_year}, {estimated}, {nationality}, {gender})
                ON CONFLICT DO NOTHING
                """)
            inserted += 1
        else:
            # Update gender from CERT (overwrite PROD with CERT value)
            if f[5] and not dry_run:
                query_db(PROD_REF, f"""
                UPDATE tbl_fencer SET enum_gender = '{f[5]}'
                WHERE txt_surname = '{f[0]}' AND txt_first_name = '{f[1]}'
                  AND (enum_gender IS NULL OR enum_gender != '{f[5]}')
                """)
    return inserted


def sync_events(dry_run: bool) -> int:
    """Copy missing events from CERT to PROD."""
    cert_events = query_db(CERT_REF, """
    SELECT e.txt_code, e.txt_name, e.txt_location, e.txt_country,
           e.dt_start, e.dt_end, e.enum_status, e.url_invitation,
           e.num_entry_fee, e.txt_entry_fee_currency,
           s.txt_code AS season_code
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
    WHERE s.bool_active
    ORDER BY e.txt_code
    """)
    prod_events = {
        r[0] for r in query_db(PROD_REF, """
        SELECT e.txt_code FROM tbl_event e
        JOIN tbl_season s ON s.id_season = e.id_season WHERE s.bool_active
        """)
    }

    inserted = 0
    for e in cert_events:
        if e[0] not in prod_events:
            if dry_run:
                print(f"    DRY: INSERT event {e[0]}", file=sys.stderr)
            else:
                vals = {
                    "txt_code": f"'{e[0]}'",
                    "txt_name": f"'{e[1]}'" if e[1] else "NULL",
                    "txt_location": f"'{e[2]}'" if e[2] else "NULL",
                    "txt_country": f"'{e[3]}'" if e[3] else "NULL",
                    "dt_start": f"'{e[4]}'" if e[4] else "NULL",
                    "dt_end": f"'{e[5]}'" if e[5] else "NULL",
                    "enum_status": f"'{e[6]}'" if e[6] else "'COMPLETED'",
                    "url_invitation": f"'{e[7]}'" if e[7] else "NULL",
                    "num_entry_fee": str(e[8]) if e[8] else "NULL",
                    "txt_entry_fee_currency": f"'{e[9]}'" if e[9] else "NULL",
                }
                query_db(PROD_REF, f"""
                INSERT INTO tbl_event (txt_code, txt_name, txt_location, txt_country,
                    dt_start, dt_end, enum_status, url_invitation, num_entry_fee,
                    txt_entry_fee_currency, id_season, id_organizer)
                VALUES ({vals['txt_code']}, {vals['txt_name']}, {vals['txt_location']},
                    {vals['txt_country']}, {vals['dt_start']}, {vals['dt_end']},
                    {vals['enum_status']}, {vals['url_invitation']}, {vals['num_entry_fee']},
                    {vals['txt_entry_fee_currency']},
                    (SELECT id_season FROM tbl_season WHERE bool_active),
                    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'))
                """)
            inserted += 1
        else:
            # Update event status and metadata from CERT
            if not dry_run:
                query_db(PROD_REF, f"""
                UPDATE tbl_event SET
                    enum_status = '{e[6]}',
                    txt_location = {f"'{e[2]}'" if e[2] else 'NULL'},
                    txt_country = {f"'{e[3]}'" if e[3] else 'NULL'},
                    dt_start = {f"'{e[4]}'" if e[4] else 'NULL'},
                    dt_end = {f"'{e[5]}'" if e[5] else 'NULL'}
                WHERE txt_code = '{e[0]}'
                """)
    return inserted


def sync_tournaments(dry_run: bool) -> int:
    """Copy missing tournaments from CERT to PROD, update participant counts and URLs."""
    cert_tourns = query_db(CERT_REF, """
    SELECT t.txt_code, t.txt_name, t.enum_type::TEXT, t.enum_weapon::TEXT,
           t.enum_gender::TEXT, t.enum_age_category::TEXT, t.dt_tournament,
           t.int_participant_count, t.num_multiplier, t.url_results,
           t.enum_import_status::TEXT, e.txt_code AS event_code
    FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
    WHERE s.bool_active
    ORDER BY t.txt_code
    """)
    prod_tourns = {
        r[0] for r in query_db(PROD_REF, """
        SELECT t.txt_code FROM tbl_tournament t
        JOIN tbl_event e ON e.id_event = t.id_event
        JOIN tbl_season s ON s.id_season = e.id_season WHERE s.bool_active
        """)
    }

    inserted = 0
    updated = 0
    for t in cert_tourns:
        code = t[0]
        if code not in prod_tourns:
            if dry_run:
                print(f"    DRY: INSERT tournament {code}", file=sys.stderr)
            else:
                dt = f"'{t[6]}'" if t[6] else "NULL"
                mult = str(t[8]) if t[8] else "NULL"
                url = f"'{t[9]}'" if t[9] else "NULL"
                query_db(PROD_REF, f"""
                INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
                    enum_weapon, enum_gender, enum_age_category, dt_tournament,
                    int_participant_count, num_multiplier, url_results, enum_import_status)
                VALUES (
                    (SELECT id_event FROM tbl_event WHERE txt_code = '{t[11]}'),
                    '{code}', '{t[1]}', '{t[2]}', '{t[3]}', '{t[4]}', '{t[5]}',
                    {dt}, {t[7]}, {mult}, {url}, '{t[10]}')
                """)
            inserted += 1
        else:
            # Update participant_count and url_results from CERT
            if not dry_run:
                url = f"'{t[9]}'" if t[9] else "NULL"
                query_db(PROD_REF, f"""
                UPDATE tbl_tournament SET
                    int_participant_count = {t[7]},
                    url_results = {url}
                WHERE txt_code = '{code}'
                """)
            updated += 1

    return inserted


def sync_results(dry_run: bool) -> tuple[int, int]:
    """Copy missing results from CERT to PROD, recalculate scores."""
    # Get all CERT results for active season with fencer names
    cert_results = query_db(CERT_REF, """
    SELECT t.txt_code AS tourn_code,
           f.txt_surname, f.txt_first_name,
           r.int_place, r.num_final_score
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
    JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
    WHERE s.bool_active
    ORDER BY t.txt_code, r.int_place
    """)

    # Get PROD results for comparison
    prod_results = set()
    for r in query_db(PROD_REF, """
    SELECT t.txt_code, f.txt_surname, f.txt_first_name
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
    JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
    WHERE s.bool_active
    """):
        prod_results.add(f"{r[0]}|{r[1]}|{r[2]}")

    inserted = 0
    tourns_to_recalc = set()

    for r in cert_results:
        key = f"{r[0]}|{r[1]}|{r[2]}"
        if key not in prod_results:
            if dry_run:
                print(f"    DRY: INSERT result {r[1]} {r[2]} in {r[0]} (#{r[3]})",
                      file=sys.stderr)
            else:
                surname_escaped = r[1].replace("'", "''")
                firstname_escaped = r[2].replace("'", "''")
                try:
                    query_db(PROD_REF, f"""
                    INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
                    SELECT
                        (SELECT id_fencer FROM tbl_fencer
                         WHERE txt_surname = '{surname_escaped}'
                           AND txt_first_name = '{firstname_escaped}' LIMIT 1),
                        (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{r[0]}'),
                        {r[3]}, NULL
                    WHERE NOT EXISTS (
                        SELECT 1 FROM tbl_result res
                        JOIN tbl_tournament tt ON tt.id_tournament = res.id_tournament
                        WHERE tt.txt_code = '{r[0]}'
                          AND res.id_fencer = (SELECT id_fencer FROM tbl_fencer
                              WHERE txt_surname = '{surname_escaped}'
                                AND txt_first_name = '{firstname_escaped}' LIMIT 1)
                    )
                    """)
                except Exception as e:
                    print(f"    WARN: insert failed {r[1]} {r[2]} in {r[0]}: {e}",
                          file=sys.stderr)
                    time.sleep(2)  # Back off on error
                    continue
                tourns_to_recalc.add(r[0])
            inserted += 1
            if inserted % 10 == 0:
                time.sleep(1)  # Rate limit: pause every 10 inserts

    # Recalculate scores for affected tournaments
    recalced = 0
    if not dry_run:
        for code in tourns_to_recalc:
            try:
                query_db(PROD_REF, f"""
                SELECT fn_calc_tournament_scores(
                    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{code}'))
                """)
                recalced += 1
            except Exception as e:
                print(f"    WARN: score recalc failed for {code}: {e}", file=sys.stderr)
            time.sleep(0.2)

    return inserted, recalced


def main():
    parser = argparse.ArgumentParser(description="Promote CERT data to PROD")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    mode = "DRY RUN" if args.dry_run else "LIVE"
    print(f"=== CERT → PROD Promotion ({mode}) ===", file=sys.stderr)

    print(f"\n1. Syncing fencers...", file=sys.stderr)
    n = sync_fencers(args.dry_run)
    print(f"   {n} new fencers", file=sys.stderr)

    print(f"\n2. Syncing events...", file=sys.stderr)
    n = sync_events(args.dry_run)
    print(f"   {n} new events", file=sys.stderr)

    print(f"\n3. Syncing tournaments...", file=sys.stderr)
    n = sync_tournaments(args.dry_run)
    print(f"   {n} new tournaments", file=sys.stderr)

    print(f"\n4. Syncing results...", file=sys.stderr)
    inserted, recalced = sync_results(args.dry_run)
    print(f"   {inserted} new results, {recalced} tournaments rescored", file=sys.stderr)

    # Verify counts
    if not args.dry_run:
        print(f"\n5. Verifying...", file=sys.stderr)
        for table in ['tbl_fencer', 'tbl_event', 'tbl_tournament', 'tbl_result']:
            c = int(query_db(CERT_REF, f"SELECT COUNT(*) FROM {table}")[0][0])
            p = int(query_db(PROD_REF, f"SELECT COUNT(*) FROM {table}")[0][0])
            status = "✓" if c == p else f"DIFF ({c} vs {p})"
            print(f"   {table:20s} {status}", file=sys.stderr)

    print(f"\n=== Done ===", file=sys.stderr)


if __name__ == "__main__":
    main()
