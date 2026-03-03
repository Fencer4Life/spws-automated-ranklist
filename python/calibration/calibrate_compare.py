"""
Compare DB scoring output against Excel reference.

Usage:
  python -m python.calibration.calibrate_compare --season 1 --excel reference/SZPADA-2-2024-2025.xlsx
"""

import argparse
import json
import os
from pathlib import Path

import openpyxl
from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

sb = create_client(SUPABASE_URL, SUPABASE_KEY) if SUPABASE_URL and SUPABASE_KEY else None


def load_excel_scores(excel_path: Path, sheet_name: str = "Ranking") -> dict:
    """
    Parse the reference Excel file and return a dict of
    {fencer_name: {tournament_code: final_score, ...}, ...}
    """
    wb = openpyxl.load_workbook(excel_path, data_only=True)
    ws = wb[sheet_name]
    scores = {}
    for row in ws.iter_rows(min_row=2, values_only=True):
        name = row[0]
        if not name:
            continue
        scores[name] = {
            "total": row[-1],
        }
    wb.close()
    return scores


def load_db_scores(season_id: int) -> dict:
    """Fetch scored results from DB via vw_score."""
    result = sb.table("vw_score").select("*").eq("id_season", season_id).execute()
    scores = {}
    for row in result.data:
        name = f"{row['txt_surname']} {row['txt_first_name']}"
        if name not in scores:
            scores[name] = {}
        scores[name][row["txt_code"]] = float(row["num_final_score"])
    return scores


def compare(excel_scores: dict, db_scores: dict, tolerance: float = 0.01) -> None:
    """Compare Excel vs DB scores and report mismatches."""
    mismatches = []
    for name, excel_data in excel_scores.items():
        db_data = db_scores.get(name, {})
        if not db_data:
            mismatches.append({"fencer": name, "issue": "MISSING_IN_DB"})
            continue
        for key, excel_val in excel_data.items():
            db_val = db_data.get(key)
            if db_val is None:
                mismatches.append({"fencer": name, "tournament": key, "issue": "MISSING_SCORE"})
            elif excel_val is not None and abs(float(excel_val) - db_val) > tolerance:
                mismatches.append({
                    "fencer": name,
                    "tournament": key,
                    "excel": excel_val,
                    "db": db_val,
                    "diff": round(float(excel_val) - db_val, 4),
                })

    if not mismatches:
        print("All scores match within tolerance! 0 mismatches found.")
    else:
        print(f"{len(mismatches)} mismatches found:")
        for m in mismatches:
            print(f"  {json.dumps(m)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compare DB scores vs Excel reference")
    parser.add_argument("--season", type=int, required=True)
    parser.add_argument("--excel", type=Path, required=True)
    parser.add_argument("--sheet", default="Ranking")
    parser.add_argument("--tolerance", type=float, default=0.01)
    args = parser.parse_args()

    excel = load_excel_scores(args.excel, args.sheet)
    db = load_db_scores(args.season)
    compare(excel, db, args.tolerance)
