"""ADR-077 §5/§7 — CERT → PROD season-skeleton promotion (slimmed, reconciler amendment).

Promotes a CHILDLESS season's season row + scoring_config (NOT events — event
Create/Update/Delete is now owned entirely by promote.py's promote_calendar
reconciler, run separately) from CERT to PROD, then optionally mirrors to LOCAL.

This is the single sanctioned CERT→PROD *upward* hop for the season shell
(ADR-036 refined): an empty calendar carries no results, so promoting the
season bootstrap up is safe. The target-side RPC ``fn_promote_season_skeleton``
(migration 20260628000002, slimmed by 20260711000001) does the guarded,
explicit-id insert; this module orchestrates the cross-env read/write like
``promote.py`` (Management API + service role).
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


def promote_season(
    season_code: str,
    cert_query_fn=None,
    prod_query_fn=None,
    cert_ref: str | None = None,
    prod_ref: str | None = None,
    access_token: str | None = None,
    dry_run: bool = False,
    force_late_bootstrap: bool = False,
) -> dict:
    """Promote a childless season skeleton CERT → PROD. Returns a summary dict.

    ``force_late_bootstrap`` skips the childless check (``_assert_childless``).
    Use only for the late-bootstrap case: PROD was never given this season's
    row (e.g. the sync pipeline was broken across the rollover), CERT has
    since accumulated real tournament children, and event data itself is
    NOT part of this payload -- ``fn_promote_season_skeleton`` only ever
    writes the season + scoring_config rows; events are always owned
    separately by ``promote.py``'s ``promote_calendar`` reconciler
    (``fn_mirror_events_to_prod``), which will populate them on its next run
    once this season row exists on both envs. The childless check exists to
    catch an operator naming a season as a childless FIRST-time bootstrap
    when it isn't one; it is not itself protecting event data, since this
    function never touches events regardless. Live use: 2026-07-14, PROD
    stuck on SPWS-2025-2026 while CERT had already rolled to
    SPWS-2026-2027 with 62 tournament children, because the EVF sync
    workflow's calendar-promote guard (correctly) refuses to reconcile
    events across an active-season mismatch -- this is the one sanctioned
    way to clear that mismatch after the fact.
    """
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

    if force_late_bootstrap:
        print(
            f"  WARNING: --force-late-bootstrap set -- skipping childless check for "
            f"{season_code}. Only the season + scoring_config rows are copied; "
            f"events are never part of this payload."
        )
    else:
        _assert_childless(cert_query_fn, id_season, season_code)

    # Idempotency: refuse if the season already exists on PROD.
    existing = prod_query_fn(f"SELECT 1 AS x FROM tbl_season WHERE txt_code = '{season_code}'")
    if existing:
        raise RuntimeError(
            f"promote_season: season {season_code} already exists on PROD — refusing "
            "(revert it there first to re-promote)"
        )

    scoring_config = _read_cert_scoring_config(cert_query_fn, id_season)

    summary = {
        "season_code": season_code,
        "id_season": id_season,
    }
    if dry_run:
        summary["dry_run"] = True
        return summary

    # Events are NOT promoted here — event C/U/D is owned entirely by
    # promote.py's promote_calendar reconciler, run separately (and it will
    # populate this season's events on its next run, since bool_active on
    # both envs is what puts a season in its scope).
    #
    # source_childless is always True here, including under
    # force_late_bootstrap: fn_promote_season_skeleton (SQL) hard-requires it
    # to proceed at all and has NO other behavior keyed on it -- its own
    # events-insert branch is driven solely by whether this payload contains
    # an "events" key, which it never does. So the flag is accurate about
    # THIS PAYLOAD's content (no events, always), even under
    # force_late_bootstrap where it is not accurate about CERT's actual
    # tbl_tournament child count. Do not "fix" this to reflect real
    # childless-ness -- False makes the RPC refuse unconditionally.
    payload = {
        "source_childless": True,
        "season": season,
        "scoring_config": scoring_config,
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
    parser.add_argument(
        "--force-late-bootstrap",
        action="store_true",
        help=(
            "Skip the childless check. Only for late-bootstrapping a season "
            "onto PROD after CERT has already accumulated real tournament "
            "children -- events are never part of this payload, see "
            "promote_season()'s docstring."
        ),
    )
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
            force_late_bootstrap=args.force_late_bootstrap,
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
