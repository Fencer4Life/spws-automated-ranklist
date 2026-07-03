"""ADR-077 §5/§7 — CERT → PROD season-skeleton promotion.

Promotes a CHILDLESS season (calendar skeleton: season + events + scoring_config,
no tournaments/results) from CERT to PROD, then optionally mirrors to LOCAL.

This is the single sanctioned CERT→PROD *upward* hop (ADR-036 refined): an empty
calendar carries no results, so promoting it up is safe. The target-side RPC
``fn_promote_season_skeleton`` (migration 20260628000002) does the guarded,
explicit-id insert; this module orchestrates the cross-env read/write like
``promote.py`` (Management API + service role).

Key correctness rule: ``id_prior_event`` and ``id_organizer`` are FKs whose
numeric values DIVERGE between CERT and PROD (the one-time natural-key baseline
left legacy event ids misaligned). They are therefore re-resolved by ``txt_code``
against the TARGET before the payload is sent — copying the raw source id would
mis-link carry-over (the same hazard the export_seed id_prior_event fix closed).
"""

from __future__ import annotations

import argparse
import json
import os
import re
from functools import partial

import httpx

from python.pipeline.promote import _management_query

# Season codes are admin-controlled but flow through a workflow_dispatch input;
# validate the shape before it reaches any SQL string (defense in depth).
_SEASON_CODE_RE = re.compile(r"^SPWS-\d{4}-\d{4}$")


def _validate_season_code(season_code: str) -> str:
    if not _SEASON_CODE_RE.match(season_code or ""):
        raise ValueError(
            f"promote_season: invalid season code {season_code!r} (expected SPWS-YYYY-YYYY)"
        )
    return season_code


def _read_cert_season(cert_query_fn, season_code: str) -> dict:
    rows = cert_query_fn(
        f"SELECT to_jsonb(s) AS j FROM tbl_season s WHERE s.txt_code = '{season_code}'"
    )
    if not rows:
        raise RuntimeError(f"promote_season: season {season_code} not found on CERT")
    j = rows[0]["j"]
    return json.loads(j) if isinstance(j, str) else j


def _assert_childless(cert_query_fn, id_season: int, season_code: str) -> None:
    rows = cert_query_fn(
        "SELECT COUNT(*)::INT AS n FROM tbl_tournament t "
        "JOIN tbl_event e ON e.id_event = t.id_event "
        f"WHERE e.id_season = {id_season}"
    )
    n = int(rows[0]["n"]) if rows else 0
    if n > 0:
        raise RuntimeError(
            f"promote_season: season {season_code} has {n} tournament child(ren) "
            "on CERT — not a childless skeleton; refusing to promote"
        )


def _read_cert_scoring_config(cert_query_fn, id_season: int) -> dict | None:
    rows = cert_query_fn(
        f"SELECT to_jsonb(sc) AS j FROM tbl_scoring_config sc WHERE sc.id_season = {id_season}"
    )
    if not rows:
        return None
    j = rows[0]["j"]
    return json.loads(j) if isinstance(j, str) else j


def _read_cert_events(cert_query_fn, id_season: int) -> list[dict]:
    rows = cert_query_fn(
        "SELECT to_jsonb(e) AS j, "
        "(SELECT pe.txt_code FROM tbl_event pe WHERE pe.id_event = e.id_prior_event) AS prior_code, "
        "(SELECT o.txt_code FROM tbl_organizer o WHERE o.id_organizer = e.id_organizer) AS org_code "
        "FROM tbl_event e "
        f"WHERE e.id_season = {id_season} ORDER BY e.id_event"
    )
    out = []
    for r in rows:
        j = r["j"]
        ev = json.loads(j) if isinstance(j, str) else dict(j)
        ev["_prior_code"] = r.get("prior_code")
        ev["_org_code"] = r.get("org_code")
        out.append(ev)
    return out


def _prod_code_to_id(
    prod_query_fn, table: str, id_col: str, codes: set[str | None]
) -> dict[str, int]:
    """Map txt_code → target id_* for the given table (codes are FK-resolved on PROD)."""
    clean_codes: set[str] = {c for c in codes if c}
    if not clean_codes:
        return {}
    in_list = ", ".join("'" + c.replace("'", "''") + "'" for c in sorted(clean_codes))
    rows = prod_query_fn(
        f"SELECT txt_code, {id_col} AS id FROM {table} WHERE txt_code IN ({in_list})"
    )
    return {r["txt_code"]: int(r["id"]) for r in rows}


def promote_season(
    season_code: str,
    cert_query_fn=None,
    prod_query_fn=None,
    cert_ref: str | None = None,
    prod_ref: str | None = None,
    access_token: str | None = None,
    dry_run: bool = False,
) -> dict:
    """Promote a childless season skeleton CERT → PROD. Returns a summary dict."""
    _validate_season_code(season_code)
    if cert_query_fn is None:
        assert cert_ref is not None and access_token is not None, (
            "promote_season: cert_ref and access_token are required when cert_query_fn is not supplied"
        )
        cert_query_fn = partial(_management_query, cert_ref, access_token)
    if prod_query_fn is None:
        assert prod_ref is not None and access_token is not None, (
            "promote_season: prod_ref and access_token are required when prod_query_fn is not supplied"
        )
        prod_query_fn = partial(_management_query, prod_ref, access_token)

    season = _read_cert_season(cert_query_fn, season_code)
    id_season = int(season["id_season"])

    _assert_childless(cert_query_fn, id_season, season_code)

    # Idempotency: refuse if the season already exists on PROD.
    existing = prod_query_fn(f"SELECT 1 AS x FROM tbl_season WHERE txt_code = '{season_code}'")
    if existing:
        raise RuntimeError(
            f"promote_season: season {season_code} already exists on PROD — refusing "
            "(revert it there first to re-promote)"
        )

    scoring_config = _read_cert_scoring_config(cert_query_fn, id_season)
    events = _read_cert_events(cert_query_fn, id_season)

    # Resolve divergent FKs (id_prior_event, id_organizer) to TARGET ids by code.
    prior_codes = {e.get("_prior_code") for e in events}
    org_codes = {e.get("_org_code") for e in events}
    prior_map = _prod_code_to_id(prod_query_fn, "tbl_event", "id_event", prior_codes)
    org_map = _prod_code_to_id(prod_query_fn, "tbl_organizer", "id_organizer", org_codes)

    clean_events: list[dict] = []
    for e in events:
        prior_code = e.pop("_prior_code", None)
        org_code = e.pop("_org_code", None)
        e["id_prior_event"] = prior_map.get(prior_code) if prior_code else None
        if org_code and org_code in org_map:
            e["id_organizer"] = org_map[org_code]
        clean_events.append(e)

    summary = {
        "season_code": season_code,
        "id_season": id_season,
        "events": len(clean_events),
        "with_prior_link": sum(1 for e in clean_events if e.get("id_prior_event") is not None),
    }
    if dry_run:
        summary["dry_run"] = True
        return summary

    payload = {
        "source_childless": True,
        "season": season,
        "scoring_config": scoring_config,
        "events": clean_events,
    }
    payload_json = json.dumps(payload).replace("'", "''")
    result = prod_query_fn(f"SELECT fn_promote_season_skeleton('{payload_json}'::JSONB) AS r")
    rpc = (result[0].get("r") if result else {}) or {}
    if isinstance(rpc, str):
        rpc = json.loads(rpc)
    summary["rpc"] = rpc
    return summary


def delete_season(
    season_code: str,
    target_query_fn=None,
    target_ref: str | None = None,
    access_token: str | None = None,
) -> dict:
    """Delete a childless, non-active season skeleton on the target env (CERT or PROD)."""
    _validate_season_code(season_code)
    if target_query_fn is None:
        assert target_ref is not None and access_token is not None, (
            "delete_season: target_ref and access_token are required when target_query_fn is not supplied"
        )
        target_query_fn = partial(_management_query, target_ref, access_token)
    rows = target_query_fn(f"SELECT id_season FROM tbl_season WHERE txt_code = '{season_code}'")
    if not rows:
        raise RuntimeError(f"delete_season: season {season_code} not found on target")
    id_season = int(rows[0]["id_season"])
    result = target_query_fn(f"SELECT fn_delete_season_skeleton({id_season}) AS r")
    rpc = (result[0].get("r") if result else {}) or {}
    return json.loads(rpc) if isinstance(rpc, str) else rpc


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Promote/delete a season skeleton CERT→PROD (ADR-077)"
    )
    parser.add_argument("--season", required=True, help="Season code, e.g. SPWS-2026-2027")
    parser.add_argument(
        "--action",
        choices=("promote", "delete"),
        default="promote",
        help="promote: CERT→PROD copy (default). delete: remove from --target.",
    )
    parser.add_argument(
        "--target",
        choices=("PROD", "CERT"),
        default="PROD",
        help="delete target env (default PROD).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Read but don't write")
    args = parser.parse_args()

    access_token = os.environ["SUPABASE_ACCESS_TOKEN"]
    cert_ref = os.environ["SUPABASE_CERT_REF"]
    prod_ref = os.environ["SUPABASE_PROD_REF"]

    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")

    def notify(msg: str) -> None:
        if bot_token and chat_id:
            try:
                httpx.post(
                    f"https://api.telegram.org/bot{bot_token}/sendMessage",
                    data={"chat_id": chat_id, "text": msg, "parse_mode": "HTML"},
                    timeout=10,
                )
            except Exception:  # noqa: BLE001 — notification is best-effort
                pass

    if args.action == "promote":
        result = promote_season(
            args.season,
            cert_ref=cert_ref,
            prod_ref=prod_ref,
            access_token=access_token,
            dry_run=args.dry_run,
        )
        print(json.dumps(result, indent=2))
        if not args.dry_run:
            notify(
                f"✅ Promoted season skeleton <b>{args.season}</b> CERT→PROD: {result.get('rpc')}"
            )
    else:
        ref = prod_ref if args.target == "PROD" else cert_ref
        result = delete_season(args.season, target_ref=ref, access_token=access_token)
        print(json.dumps(result, indent=2))
        notify(f"🗑️ Deleted season skeleton <b>{args.season}</b> on {args.target}: {result}")


if __name__ == "__main__":
    main()
