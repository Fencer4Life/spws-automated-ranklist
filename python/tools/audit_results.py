"""
Audit ingested results against source tournament URLs.

Connects to CERT or PROD via Supabase Management API, fetches all
tournaments with url_results in the active season, scrapes each URL,
and compares scraped participants against DB results.

Reports:
  - MISSING: fencer in scraped source but not in DB
  - EXTRA:   fencer in DB but not in scraped source
  - PLACE_MISMATCH: fencer exists but placement differs

Usage:
    python -m python.tools.audit_results --env cert
    python -m python.tools.audit_results --env prod
    python -m python.tools.audit_results --env local
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import httpx

from python.scrapers.base import detect_platform
from python.scrapers.ftl import parse_ftl_json
from python.scrapers.engarde import parse_engarde_html
from python.scrapers.fourfence import parse_fourfence_html


# ---------------------------------------------------------------------------
# Environment configs
# ---------------------------------------------------------------------------
ENVS = {
    "cert": {
        "ref": "sdomfjncmfydlkygzpgw",
        "url": "https://sdomfjncmfydlkygzpgw.supabase.co",
    },
    "prod": {
        "ref": "ywgymtgcyturldazcpmw",
        "url": "https://ywgymtgcyturldazcpmw.supabase.co",
    },
    "local": {
        "ref": None,
        "url": "http://127.0.0.1:54321",
    },
}

SUPABASE_ACCESS_TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
MGMT_API = "https://api.supabase.com/v1/projects"

FTL_DATA_PREFIX = "https://www.fencingtimelive.com/events/results/data/"
FTL_RESULTS_PREFIX = "https://www.fencingtimelive.com/events/results/"


# ---------------------------------------------------------------------------
# DB query helpers
# ---------------------------------------------------------------------------
def query_db(ref: str | None, sql: str) -> list[list]:
    """Execute SQL via Management API (cloud) or docker exec (local)."""
    if ref is None:
        # Local: use docker exec
        import subprocess
        result = subprocess.run(
            ["docker", "exec", "supabase_db_SPWSranklist",
             "psql", "-U", "postgres", "-t", "-A", "-F", "\t", "-c", sql],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            raise RuntimeError(f"Local query failed: {result.stderr}")
        rows = []
        for line in result.stdout.strip().split("\n"):
            if line:
                rows.append(line.split("\t"))
        return rows
    else:
        # Cloud: Management API
        resp = httpx.post(
            f"{MGMT_API}/{ref}/database/query",
            headers={
                "Authorization": f"Bearer {SUPABASE_ACCESS_TOKEN}",
                "Content-Type": "application/json",
            },
            json={"query": sql},
            timeout=30,
        )
        if resp.status_code >= 400:
            raise RuntimeError(f"Management API error: {resp.status_code} {resp.text}")
        data = resp.json()
        # Management API returns list of row-objects
        if not data:
            return []
        keys = list(data[0].keys())
        return [[row[k] for k in keys] for row in data]


def fetch_tournaments_with_urls(ref: str | None) -> list[dict]:
    """Fetch all tournaments in active season that have url_results."""
    sql = """
    SELECT t.txt_code, t.url_results, t.int_participant_count, t.enum_type,
           t.enum_weapon::TEXT, t.enum_gender::TEXT, t.enum_age_category::TEXT,
           e.txt_code AS event_code, e.txt_location
    FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
    WHERE s.bool_active = TRUE
      AND t.url_results IS NOT NULL
      AND e.enum_status IN ('COMPLETED', 'IN_PROGRESS')
    ORDER BY e.txt_code, t.txt_code;
    """
    rows = query_db(ref, sql)
    return [
        {
            "txt_code": r[0], "url_results": r[1],
            "int_participant_count": int(r[2]) if r[2] else 0,
            "enum_type": r[3], "enum_weapon": r[4],
            "enum_gender": r[5], "enum_age_category": r[6],
            "event_code": r[7], "location": r[8],
        }
        for r in rows
    ]


def fetch_db_results(ref: str | None, tournament_code: str) -> list[dict]:
    """Fetch all results for a tournament from DB."""
    sql = f"""
    SELECT f.txt_surname || ' ' || f.txt_first_name AS name,
           r.int_place, r.num_final_score
    FROM tbl_result r
    JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE t.txt_code = '{tournament_code}'
    ORDER BY r.int_place;
    """
    rows = query_db(ref, sql)
    return [
        {"name": r[0], "place": int(r[1]), "score": float(r[2]) if r[2] else 0}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# Scraping
# ---------------------------------------------------------------------------
def scrape_url(url: str) -> list[dict]:
    """Scrape a tournament URL and return standardized results."""
    platform = detect_platform(url)
    if platform == "ftl":
        data_url = url
        if FTL_RESULTS_PREFIX in url and "/data/" not in url:
            uuid = url.split(FTL_RESULTS_PREFIX)[-1].split("?")[0].split("#")[0]
            data_url = f"{FTL_DATA_PREFIX}{uuid}"
        resp = httpx.get(data_url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return parse_ftl_json(resp.json())
    elif platform == "engarde":
        resp = httpx.get(url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return parse_engarde_html(resp.text)
    elif platform == "fourfence":
        resp = httpx.get(url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return parse_fourfence_html(resp.text)
    else:
        raise ValueError(f"Unsupported platform: {url}")


# ---------------------------------------------------------------------------
# Name normalization for comparison
# ---------------------------------------------------------------------------
import re
import unicodedata


# Polish characters that don't decompose via NFKD
_POLISH_MAP = str.maketrans("łŁ", "lL")


def strip_diacritics(s: str) -> str:
    """Remove diacritics: ń→n, ł→l, é→e, å→a, etc."""
    s = s.translate(_POLISH_MAP)
    nfkd = unicodedata.normalize("NFKD", s)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


# FTL age category markers: "SURNAME (2) FirstName" or "SURNAME 2 FirstName"
_AGE_MARKER = re.compile(r"\s*\(\d+\)\s*|\s+\d+\s+(?=[A-Z])")
# Trailing FTL markers: "(1)", "(0)" at end
_TRAILING_MARKER = re.compile(r"\s*\(\d+\)$")
# Trailing single-letter abbreviations: "O.", "W.", "w."
_TRAILING_ABBREV = re.compile(r"\s+[A-Za-z]\.\s*$")
# Hyphen/space normalization in compound surnames
_HYPHEN_SPACE = re.compile(r"\s*[-–]\s*")


def normalize_name(name: str) -> str:
    """Normalize fencer name for comparison.

    Strips diacritics, FTL age markers, extra spaces, and normalizes hyphens.
    """
    s = name.strip()
    # Remove FTL age markers: "(2)", "(0)", standalone digits between name parts
    s = _AGE_MARKER.sub(" ", s)
    s = _TRAILING_MARKER.sub("", s)
    # Remove trailing single-letter abbreviations (FTL: "O.", "w.")
    s = _TRAILING_ABBREV.sub("", s)
    # Normalize hyphens and spaces around them
    s = _HYPHEN_SPACE.sub("-", s)
    # Strip diacritics
    s = strip_diacritics(s)
    # Uppercase and collapse whitespace
    return " ".join(s.upper().split())


def names_match(scraped_name: str, db_name: str) -> bool:
    """Check if two fencer names refer to the same person."""
    s = normalize_name(scraped_name)
    d = normalize_name(db_name)
    if s == d:
        return True
    # Surname match (first token) + first name
    s_parts = s.split()
    d_parts = d.split()
    if not s_parts or not d_parts:
        return False
    # Handle compound surnames: compare first hyphenated part
    s_surname = s_parts[0].split("-")[0]
    d_surname = d_parts[0].split("-")[0]
    if s_surname == d_surname and len(s_parts) > 1 and len(d_parts) > 1:
        s_first = s_parts[-1]
        d_first = d_parts[-1]
        # Exact first name or initial match
        if s_first == d_first or (s_first and d_first and s_first[0] == d_first[0]):
            return True
        # DB has double first name (e.g., "SZKODA MAREK TOMASZ" vs "SZKODA MAREK")
        # Check if scraped first name matches any DB name token after surname
        for dp in d_parts[1:]:
            if s_first == dp:
                return True
    return False


# ---------------------------------------------------------------------------
# Audit logic
# ---------------------------------------------------------------------------
def audit_tournament(ref: str | None, tournament: dict, pol_only: bool = False) -> dict:
    """Compare scraped results against DB for one tournament.

    Returns dict with tournament info and lists of issues.
    """
    code = tournament["txt_code"]
    url = tournament["url_results"]

    try:
        scraped = scrape_url(url)
    except Exception as e:
        return {"code": code, "error": f"Scrape failed: {e}", "issues": []}

    db_results = fetch_db_results(ref, code)

    # Filter to POL fencers only if requested (domestic tournaments always all)
    if pol_only and tournament["enum_type"] in ("PEW", "MEW", "MSW", "PSW"):
        scraped = [r for r in scraped if r.get("country", "") == "POL"]

    issues = []

    # Build lookup maps
    db_by_name = {}
    for r in db_results:
        db_by_name[normalize_name(r["name"])] = r

    scraped_matched = set()
    db_matched = set()

    # Check each scraped fencer against DB
    for sr in scraped:
        sn = normalize_name(sr["fencer_name"])
        matched = False
        for dn, dr in db_by_name.items():
            if names_match(sr["fencer_name"], dr["name"]):
                matched = True
                scraped_matched.add(sn)
                db_matched.add(dn)
                if sr["place"] != dr["place"]:
                    issues.append({
                        "type": "PLACE_MISMATCH",
                        "fencer": sr["fencer_name"],
                        "scraped_place": sr["place"],
                        "db_place": dr["place"],
                    })
                break
        if not matched:
            issues.append({
                "type": "MISSING_IN_DB",
                "fencer": sr["fencer_name"],
                "scraped_place": sr["place"],
                "country": sr.get("country", ""),
            })

    # Check for DB results not in scraped data
    for dn, dr in db_by_name.items():
        if dn not in db_matched:
            issues.append({
                "type": "EXTRA_IN_DB",
                "fencer": dr["name"],
                "db_place": dr["place"],
            })

    return {
        "code": code,
        "event": tournament["event_code"],
        "location": tournament["location"],
        "url": url,
        "scraped_count": len(scraped),
        "db_count": len(db_results),
        "participant_count": tournament["int_participant_count"],
        "issues": issues,
        "error": None,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Audit ingested results against source URLs")
    parser.add_argument("--env", required=True, choices=["cert", "prod", "local"])
    parser.add_argument("--pol-only", action="store_true",
                        help="For international tournaments, only check POL fencers")
    parser.add_argument("--tournament", default=None,
                        help="Audit a single tournament code (default: all)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    env = ENVS[args.env]
    ref = env["ref"]

    print(f"=== Audit: {args.env.upper()} ===", file=sys.stderr)

    if args.tournament:
        # Single tournament mode — fetch its URL from DB
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
        print("No tournaments with URLs found in active season", file=sys.stderr)
        sys.exit(0)

    print(f"Found {len(tournaments)} tournaments with URLs", file=sys.stderr)

    all_results = []
    total_missing = 0
    total_extra = 0
    total_mismatch = 0
    total_errors = 0

    for i, t in enumerate(tournaments, 1):
        print(f"[{i}/{len(tournaments)}] {t['txt_code']} ...", end="", file=sys.stderr)
        result = audit_tournament(ref, t, pol_only=args.pol_only)
        all_results.append(result)

        if result["error"]:
            total_errors += 1
            print(f" ERROR: {result['error']}", file=sys.stderr)
        else:
            missing = sum(1 for x in result["issues"] if x["type"] == "MISSING_IN_DB")
            extra = sum(1 for x in result["issues"] if x["type"] == "EXTRA_IN_DB")
            mismatch = sum(1 for x in result["issues"] if x["type"] == "PLACE_MISMATCH")
            total_missing += missing
            total_extra += extra
            total_mismatch += mismatch

            if result["issues"]:
                print(f" {missing} missing, {extra} extra, {mismatch} mismatches "
                      f"(scraped={result['scraped_count']}, db={result['db_count']})",
                      file=sys.stderr)
            else:
                print(f" OK ({result['db_count']} results)", file=sys.stderr)

        # Rate limit: avoid hammering scraper endpoints
        time.sleep(0.5)

    # Summary
    print(f"\n{'='*60}", file=sys.stderr)
    print(f"AUDIT SUMMARY ({args.env.upper()})", file=sys.stderr)
    print(f"  Tournaments audited: {len(tournaments)}", file=sys.stderr)
    print(f"  Scrape errors:       {total_errors}", file=sys.stderr)
    print(f"  MISSING_IN_DB:       {total_missing}", file=sys.stderr)
    print(f"  EXTRA_IN_DB:         {total_extra}", file=sys.stderr)
    print(f"  PLACE_MISMATCH:      {total_mismatch}", file=sys.stderr)
    if total_missing == 0 and total_extra == 0 and total_mismatch == 0 and total_errors == 0:
        print(f"  RESULT: ALL CLEAR ✓", file=sys.stderr)
    else:
        print(f"  RESULT: ISSUES FOUND", file=sys.stderr)
    print(f"{'='*60}", file=sys.stderr)

    # Detailed output
    if args.json:
        print(json.dumps(all_results, indent=2, ensure_ascii=False))
    else:
        for r in all_results:
            if r["issues"]:
                print(f"\n--- {r['code']} ({r['location']}) ---")
                print(f"    URL: {r['url']}")
                print(f"    Scraped: {r['scraped_count']}  DB: {r['db_count']}  "
                      f"Declared: {r['participant_count']}")
                for issue in r["issues"]:
                    if issue["type"] == "MISSING_IN_DB":
                        print(f"    MISSING: #{issue['scraped_place']} "
                              f"{issue['fencer']} ({issue['country']})")
                    elif issue["type"] == "EXTRA_IN_DB":
                        print(f"    EXTRA:   #{issue['db_place']} {issue['fencer']}")
                    elif issue["type"] == "PLACE_MISMATCH":
                        print(f"    PLACE:   {issue['fencer']} "
                              f"scraped=#{issue['scraped_place']} "
                              f"db=#{issue['db_place']}")


if __name__ == "__main__":
    main()
