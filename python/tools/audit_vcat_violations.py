"""
Layer 5 (combined-pool ingestion fix, 2026-04-30):
admin tool for V-cat / birth-year disagreements.

Reads vw_vcat_violation and surfaces every tbl_result row whose tournament's
enum_age_category disagrees with fn_age_category(BY, season_end_year).

Used as:
  - Daily/weekly admin sweep (CLI summary).
  - Input for Layer 6 replay loop (--json, grouped by tournament).

Targets LOCAL via PostgREST (default) or CERT/PROD via Supabase Management API
when --remote=cert|prod is supplied (requires SUPABASE_ACCESS_TOKEN).

Examples:
  python -m python.tools.audit_vcat_violations
  python -m python.tools.audit_vcat_violations --by-tournament
  python -m python.tools.audit_vcat_violations --json --remote cert
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict

import httpx


CERT_REF = "sdomfjncmfydlkygzpgw"
PROD_REF = "ywgymtgcyturldazcpmw"


def fetch_violations_postgrest(supabase_url: str, headers: dict) -> list[dict]:
    """Fetch every row from vw_vcat_violation via PostgREST (LOCAL path)."""
    resp = httpx.get(
        f"{supabase_url}/rest/v1/vw_vcat_violation"
        f"?select=*&order=season_code.desc,event_code.asc,tournament_code.asc",
        headers=headers,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def fetch_violations_management(ref: str, token: str) -> list[dict]:
    """Fetch every row from vw_vcat_violation via Supabase Management API
    (CERT/PROD path). Cloudflare blocks Python-urllib User-Agents, so we
    spoof curl/8.7.1 — the same trick the rest of the cross-env tooling uses.
    """
    resp = httpx.post(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "curl/8.7.1",
        },
        json={"query": "SELECT * FROM vw_vcat_violation "
                       "ORDER BY season_code DESC, event_code ASC, tournament_code ASC"},
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()


def summarise_by_season(rows: list[dict]) -> dict[str, int]:
    """Count violators per season_code."""
    out: dict[str, int] = defaultdict(int)
    for r in rows:
        out[r["season_code"]] += 1
    return dict(out)


def summarise_by_tournament(rows: list[dict]) -> list[dict]:
    """Group violators by tournament_code with summary counts.

    Returns a list of {tournament_code, season_code, event_code,
    tournament_vcat, expected_vcats, count, violators[]}.
    """
    groups: dict[str, dict] = {}
    for r in rows:
        key = r["tournament_code"]
        g = groups.setdefault(key, {
            "tournament_code": key,
            "season_code": r["season_code"],
            "event_code": r["event_code"],
            "tournament_vcat": r["tournament_vcat"],
            "expected_vcats": set(),
            "count": 0,
            "violators": [],
        })
        g["expected_vcats"].add(r["expected_vcat"])
        g["count"] += 1
        g["violators"].append({
            "id_result": r["id_result"],
            "id_fencer": r["id_fencer"],
            "fencer": f"{r['txt_surname']} {r['txt_first_name']}",
            "birth_year": r["int_birth_year"],
            "expected_vcat": r["expected_vcat"],
        })
    out = []
    for g in groups.values():
        g["expected_vcats"] = sorted(g["expected_vcats"])
        out.append(g)
    out.sort(key=lambda x: (x["season_code"], x["event_code"], x["tournament_code"]))
    return out


def render_text(rows: list[dict], by_tournament: bool) -> str:
    if not rows:
        return "No V-cat violations found.\n"

    lines: list[str] = []
    lines.append(f"V-cat violations: {len(rows)}\n")
    by_season = summarise_by_season(rows)
    lines.append("By season:")
    for season in sorted(by_season.keys()):
        lines.append(f"  {season}: {by_season[season]} row(s)")
    lines.append("")

    if by_tournament:
        groups = summarise_by_tournament(rows)
        lines.append(f"By tournament ({len(groups)} groups):")
        for g in groups:
            lines.append(
                f"  {g['tournament_code']}  "
                f"(tour V-cat={g['tournament_vcat']}, expected={','.join(g['expected_vcats'])}, "
                f"n={g['count']})"
            )
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--remote", choices=["local", "cert", "prod"], default="local")
    p.add_argument("--json", action="store_true",
                   help="Emit JSON instead of text. Combine with --by-tournament for "
                        "the shape Layer 6 replay consumes.")
    p.add_argument("--by-tournament", action="store_true",
                   help="Group violators by tournament_code instead of listing them.")
    p.add_argument("--supabase-url", default=None)
    p.add_argument("--supabase-key", default=None)
    args = p.parse_args()

    if args.remote == "local":
        url = args.supabase_url or os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
        key = args.supabase_key or os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
        if not key:
            print("ERROR: SUPABASE_SERVICE_ROLE_KEY required for --remote local",
                  file=sys.stderr)
            return 1
        headers = {"apikey": key, "Authorization": f"Bearer {key}"}
        rows = fetch_violations_postgrest(url, headers)
    else:
        ref = CERT_REF if args.remote == "cert" else PROD_REF
        token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
        if not token:
            tf = os.path.expanduser("~/.supabase_token")
            if os.path.exists(tf):
                with open(tf) as f:
                    token = f.read().strip()
        if not token:
            print("ERROR: SUPABASE_ACCESS_TOKEN required for --remote cert|prod",
                  file=sys.stderr)
            return 1
        rows = fetch_violations_management(ref, token)

    if args.json:
        if args.by_tournament:
            print(json.dumps(summarise_by_tournament(rows), indent=2, ensure_ascii=False))
        else:
            print(json.dumps(rows, indent=2, ensure_ascii=False))
    else:
        print(render_text(rows, args.by_tournament))

    return 0


if __name__ == "__main__":
    sys.exit(main())
