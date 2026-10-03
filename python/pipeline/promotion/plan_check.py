"""The LOCAL acceptance check for plan mode: plan, then apply, equals a live run
(ADR-108 §6, build step 8).

Two halves, with a LOCAL reset (`./scripts/reset-dev.sh`) between them, so both
start from the same database. Run one event at a time, each from a fresh reset,
as promote starts each event from PROD's state:

    python -m python.pipeline.promotion.plan_check live --events PPW1-2026-2027 --out S.json
    ./scripts/reset-dev.sh
    python -m python.pipeline.promotion.plan_check plan --state S.json [--apply sql]

`live` ingests each event from its FTL URL as `ingest-event.yml` does, notes the
fencers each one created, and saves what the events left in the database. `plan`
plans each event on LOCAL through the recording connector, with the live run's
created fencers, applies the plan with `apply_plan`, and compares the database
with the saved state. `--apply sql` applies through fn_promote_event_apply instead
(build step 9): a dry run, then the apply, with the live run's result fingerprint
and the inputs it started from. Exit 0 means equal, 1 different. An event whose live run
fails has nothing to compare: `plan` reports the live error and what plan mode
does with the event, and exits 3. It refuses any database but LOCAL.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

_LOCAL = re.compile(r"^https?://(127\.0\.0\.1|localhost)(:\d+)?/?")
_SEASON = re.compile(r"-(\d{4})-(\d{4})$")


def _local_db() -> Any:
    url = os.environ.get("SUPABASE_URL", "")
    if not _LOCAL.match(url):
        raise SystemExit(f"refusing: SUPABASE_URL is not LOCAL ({url or 'unset'})")
    from python.pipeline.db_connector import create_db_connector

    return create_db_connector()


def _season_end(event_code: str) -> int:
    m = _SEASON.search(event_code)
    if not m:
        raise SystemExit(f"not a season-qualified event code: {event_code}")
    return int(m.group(2))


def _rows(db: Any, table: str, column: str, values: list) -> list[dict]:
    if not values:
        return []
    out: list[dict] = []
    for i in range(0, len(values), 200):
        chunk = values[i : i + 200]
        out += db._sb.table(table).select("*").in_(column, chunk).execute().data or []
    return out


def _strip(row: dict, keep_ids: tuple[str, ...] = ()) -> dict:
    return {
        k: v
        for k, v in row.items()
        if not k.startswith("ts_") and (not k.startswith("id_") or k in keep_ids)
    }


def snapshot(db: Any, event_codes: list[str]) -> dict:
    """What the events can change, keyed by codes and fencer ids, never by
    generated tournament or result ids."""
    events = db._sb.table("tbl_event").select("*").in_("txt_code", event_codes).execute().data
    by_id = {e["id_event"]: e["txt_code"] for e in events}
    tournaments = _rows(db, "tbl_tournament", "id_event", sorted(by_id))
    codes = {t["id_tournament"]: t["txt_code"] for t in tournaments}
    results = _rows(db, "tbl_result", "id_tournament", sorted(codes))
    fencers = db._sb.table("tbl_fencer").select("*").order("id_fencer").execute().data
    return {
        "events": {e["txt_code"]: _strip(e) for e in events},
        "tournaments": {t["txt_code"]: _strip(t) for t in tournaments},
        "results": sorted(
            (
                {"tournament": codes[r["id_tournament"]], **_strip(r, ("id_fencer",))}
                for r in results
            ),
            key=lambda r: (r["tournament"], r["id_fencer"] or 0, r.get("int_place") or 0),
        ),
        "fencers": {str(f["id_fencer"]): _strip(f) for f in fencers},
    }


def _diff(a: Any, b: Any, path: str = "") -> list[str]:
    if isinstance(a, dict) and isinstance(b, dict):
        out: list[str] = []
        for k in sorted(set(a) | set(b), key=str):
            if k not in a or k not in b:
                out.append(f"{path}/{k}: {'only live' if k in a else 'only applied'}")
            else:
                out += _diff(a[k], b[k], f"{path}/{k}")
        return out
    if isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
        out = []
        for i, (x, y) in enumerate(zip(a, b, strict=True)):
            out += _diff(x, y, f"{path}[{i}]")
        return out
    return [] if a == b else [f"{path}: live {a!r} / applied {b!r}"]


def live(event_codes: list[str], out: Path) -> int:
    from python.pipeline import ingest_cli

    db = _local_db()
    created: dict[str, list[dict]] = {}
    errors: dict[str, str] = {}
    inputs: dict[str, dict] = {}
    fingerprints: dict[str, str] = {}
    for code in event_codes:
        before = {f["id_fencer"] for f in db.fetch_fencer_db()}
        inputs[code] = _rpc(db, "fn_event_input_fingerprint", {"p_event_code": code})["parts"]
        try:
            ingest_cli.ingest_event_from_url(code, _season_end(code), db=db, md_target="none")
        except Exception as e:  # recorded: an event that fails live has nothing to compare
            errors[code] = f"{type(e).__name__}: {e}"
            print(f"live {code}: FAILED {errors[code]}")
        created[code] = [
            {
                "id_fencer": f["id_fencer"],
                "surname": f["txt_surname"],
                "first_name": f["txt_first_name"],
            }
            for f in sorted(db.fetch_fencer_db(), key=lambda f: f["id_fencer"])
            if f["id_fencer"] not in before
        ]
        fingerprints[code] = _rpc(db, "fn_event_result_fingerprint", {"p_event_code": code})
        print(
            f"live {code}: created {len(created[code])} fencer(s); result {fingerprints[code][:12]}"
        )
    state = {
        "events": event_codes,
        "created": created,
        "errors": errors,
        "inputs": inputs,
        "fingerprints": fingerprints,
        "snapshot": snapshot(db, event_codes),
    }
    out.write_text(json.dumps(state, ensure_ascii=False, default=str, indent=1))
    print(f"saved {out}")
    return 0


def _rpc(db: Any, fn: str, params: dict) -> Any:
    return db._sb.rpc(fn, params).execute().data


def _sql_apply(db: Any, plan: Any, state: dict, code: str) -> dict:
    """fn_promote_event_apply as promote calls it: a dry run, which must raise
    PROMOTE_DRY_RUN_OK with the live fingerprint, then the apply."""
    expected = state["fingerprints"][code]
    params = {
        "p_event_code": code,
        "p_plan": json.loads(json.dumps(plan.to_json(), default=str)),
        "p_expected_fingerprint": expected,
        "p_expected_inputs": state["inputs"][code],
        "p_prior_fingerprint": None,
        "p_status": "IN_PROGRESS",
        "p_dry_run": True,
    }
    try:
        _rpc(db, "fn_promote_event_apply", params)
    except Exception as e:
        message = getattr(e, "message", None) or str(e)
        if not message.startswith(f"PROMOTE_DRY_RUN_OK {expected}"):
            raise
        print(f"  dry run: {message[:40]}")
    else:
        raise RuntimeError("the dry run returned instead of raising")
    return _rpc(db, "fn_promote_event_apply", {**params, "p_dry_run": False})


def plan(state_path: Path, apply: str = "python") -> int:
    from python.pipeline.promotion.plan import PlanRefused, apply_plan, plan_event

    db = _local_db()
    state = json.loads(state_path.read_text())
    errors = state.get("errors") or {}
    if errors:
        for code, error in errors.items():
            print(f"LIVE FAILED {code}: {error}")
            event = db.find_event_by_code(code)
            url = (event or {}).get("url_event") or ""
            try:
                p = plan_event(
                    code, _season_end(code), db, url_event=url, created=state["created"][code]
                )
                print(f"  plan mode: {len(p.ops)} operation(s); the apply meets the same error")
            except PlanRefused as e:
                print(f"  plan mode refuses ({e.kind}): {e}")
            except Exception as e:  # the live error again, met while planning
                print(f"  plan mode stops: {type(e).__name__}: {e}")
        return 3
    for code in state["events"]:
        event = db.find_event_by_code(code)
        url = (event or {}).get("url_event") or ""
        p = plan_event(code, _season_end(code), db, url_event=url, created=state["created"][code])
        counts: dict[str, int] = {}
        for op in p.ops:
            counts[op["op"]] = counts.get(op["op"], 0) + 1
        if apply == "sql":
            result = _sql_apply(db, p, state, code)
            print(f"plan {code}: {counts}; applied {result}")
        else:
            refs = apply_plan(p.ops, db)
            print(f"plan {code}: {counts}; {sum(1 for r in refs if r < 0)} new tournament(s)")
    applied = json.loads(json.dumps(snapshot(db, state["events"]), default=str))
    diffs = _diff(state["snapshot"], applied)
    if diffs:
        print(f"DIFFERENT: {len(diffs)} difference(s)")
        for d in diffs[:60]:
            print("  " + d)
        return 1
    print(
        f"EQUAL: {len(state['events'])} event(s), {len(applied['tournaments'])} tournaments, "
        f"{len(applied['results'])} results, {len(applied['fencers'])} fencers"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Plan mode: plan, then apply, equals a live run (LOCAL)."
    )
    sub = ap.add_subparsers(dest="mode", required=True)
    a = sub.add_parser("live")
    a.add_argument("--events", required=True, help="comma-separated exact event codes, in order")
    a.add_argument("--out", required=True, type=Path)
    b = sub.add_parser("plan")
    b.add_argument("--state", required=True, type=Path)
    b.add_argument("--apply", choices=("python", "sql"), default="python")
    args = ap.parse_args(argv)
    if args.mode == "live":
        return live([c.strip() for c in args.events.split(",") if c.strip()], args.out)
    return plan(args.state, args.apply)


if __name__ == "__main__":
    sys.exit(main())
