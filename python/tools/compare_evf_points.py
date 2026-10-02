"""
Compare an EVF event's committed Polish results with EVF's own points. Reads only.

doc/plans/evf-events-follow-evf-category-rule-2026-10-02.html. An EVF event is
scored by EVF's rules (ADR-066 amendment), so every committed result carries
the N and the points EVF published for it (ADR-028 results API). A result EVF
does not list, or one whose N or points differ, is reported and the exit code
is 1.

    python -m python.tools.compare_evf_points --event-code PEW6efs-2025-2026 --evf-event-id 87

Tests: python/tests/test_compare_evf_points.py (EVF.PTS.01).
"""

from __future__ import annotations

import argparse
import sys

from python.matcher.fuzzy_match import fold_diacritics

POINTS_TOLERANCE = 0.01
_WEAPON_GENDER = {
    "MF": ("FOIL", "M"),
    "ME": ("EPEE", "M"),
    "MS": ("SABRE", "M"),
    "WF": ("FOIL", "F"),
    "WE": ("EPEE", "F"),
    "WS": ("SABRE", "F"),
}


def _key(row: dict) -> tuple:
    return (row["w"], row["g"], row["v"], int(row["p"]), fold_diacritics(row["surname"]).upper())


def compare_with_evf(ours: list[dict], evf: list[dict]) -> dict:
    """Match each committed row to EVF's row of the same category, place and
    surname (Polish letters folded) and compare N and points.

    Rows are dicts with w, g, v, n, p, surname and pts. Returns the number
    matched, the rows whose N or points differ, and the rows EVF does not list.
    """
    by_key = {_key(r): r for r in evf}
    out: dict = {"matched": 0, "mismatched": [], "missing": []}
    for row in ours:
        theirs = by_key.get(_key(row))
        if theirs is None:
            out["missing"].append(row)
        elif (
            int(theirs["n"]) == int(row["n"])
            and abs(float(theirs["pts"]) - float(row["pts"])) <= POINTS_TOLERANCE
        ):
            out["matched"] += 1
        else:
            out["mismatched"].append(
                {**row, "evf_n": theirs["n"], "evf_pts": round(float(theirs["pts"]), 2)}
            )
    return out


def read_committed(sb, event_code: str) -> list[dict]:
    event = (
        sb.table("tbl_event").select("id_event").eq("txt_code", event_code).single().execute().data
    )
    tournaments = (
        sb.table("tbl_tournament")
        .select("id_tournament, enum_weapon, enum_gender, enum_age_category, int_participant_count")
        .eq("id_event", event["id_event"])
        .execute()
        .data
    )
    by_id = {t["id_tournament"]: t for t in tournaments}
    results = (
        sb.table("tbl_result")
        .select("id_tournament, int_place, num_final_score, tbl_fencer(txt_surname)")
        .in_("id_tournament", list(by_id))
        .execute()
        .data
    )
    return [
        {
            "w": by_id[r["id_tournament"]]["enum_weapon"],
            "g": by_id[r["id_tournament"]]["enum_gender"],
            "v": by_id[r["id_tournament"]]["enum_age_category"],
            "n": by_id[r["id_tournament"]]["int_participant_count"],
            "p": r["int_place"],
            "surname": r["tbl_fencer"]["txt_surname"],
            "pts": r["num_final_score"],
        }
        for r in results
    ]


def read_evf(evf_event_id: int) -> list[dict]:
    from python.scrapers.evf_results import EvfApiClient

    client = EvfApiClient()
    client.connect()
    try:
        rows = []
        for comp in client.get_competitions(evf_event_id):
            w, g = _WEAPON_GENDER[comp["weapon"]["abbr"]]
            v = f"V{comp['category']['abbr']}"
            for r in client.get_results(comp["id"]):
                rows.append(
                    {
                        "w": w,
                        "g": g,
                        "v": v,
                        "n": r["entry"],
                        "p": r["place"],
                        "surname": r["fencer_surname"],
                        "pts": r["total_points"],
                    }
                )
        return rows
    finally:
        client.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--event-code", required=True)
    parser.add_argument("--evf-event-id", type=int, required=True)
    args = parser.parse_args(argv)

    from python.pipeline.db_connector import create_db_connector

    ours = read_committed(create_db_connector()._sb, args.event_code)
    out = compare_with_evf(ours, read_evf(args.evf_event_id))
    print(f"{args.event_code}: {out['matched']} of {len(ours)} results carry EVF's N and points")
    for m in out["mismatched"]:
        print(
            f"  differs: {m['surname']} {m['v']} {m['g']} {m['w']} {m['p']}/{m['n']} {m['pts']} — EVF {m['p']}/{m['evf_n']} {m['evf_pts']}"
        )
    for m in out["missing"]:
        print(
            f"  not in EVF's results: {m['surname']} {m['v']} {m['g']} {m['w']} {m['p']}/{m['n']}"
        )
    return 0 if not out["mismatched"] and not out["missing"] else 1


if __name__ == "__main__":
    sys.exit(main())
