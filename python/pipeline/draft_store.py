"""
DraftStore — Phase 2 (ADR-050) scratch state access layer.

Wraps a Supabase REST client to read/write the Phase 2 draft tables and
invoke the three new RPCs:
  - fn_commit_event_draft(p_run_id UUID)  → JSONB
  - fn_discard_event_draft(p_run_id UUID) → JSONB
  - fn_dry_run_event_draft(p_drafts JSONB) → JSONB

Locked decisions (conversation 2026-05-01):
  D1  --dry-run = no DB writes; Python computes diff from in-memory IR
  D2  RPCs return JSONB with counts; never throw on missing run_id
  D5  All txn boundaries inside SQL; no psycopg2 at runtime — every call
      here goes through the existing Supabase REST client.

Resumability comes from the persisted draft tables: write_tournament_drafts()
+ write_result_drafts() under a stable run_id, then later (possibly in a
fresh process) read_drafts(run_id) reloads the state and commit() / discard()
acts on it.

Plan: doc/plans/rebuild/p2-drafts.md.
Tests: python/tests/test_draft_store.py.
"""

from __future__ import annotations


class DraftStore:
    """Read/write/commit/discard ingest drafts identified by run_id (UUID)."""

    def __init__(self, db_or_supabase) -> None:
        """Accept either a DbConnector (uses .._sb) or a raw supabase client."""
        if hasattr(db_or_supabase, "_sb"):
            self._sb = db_or_supabase._sb
        else:
            self._sb = db_or_supabase

    # -----------------------------------------------------------------------
    # Write
    # -----------------------------------------------------------------------

    def write_tournament_drafts(self, tournaments: list[dict], run_id: str) -> list[int]:
        """Bulk-insert tournament drafts. Returns list of id_tournament_draft.

        Each row in `tournaments` must conform to tbl_tournament_draft columns
        (excluding id_tournament_draft and txt_run_id, which are filled here).
        """
        rows = [{**t, "txt_run_id": run_id} for t in tournaments]
        resp = self._sb.table("tbl_tournament_draft").insert(rows).execute()
        return [row["id_tournament_draft"] for row in resp.data]

    def write_result_drafts(self, results: list[dict], run_id: str) -> int:
        """Bulk-insert result drafts. Returns count inserted."""
        rows = [{**r, "txt_run_id": run_id} for r in results]
        resp = self._sb.table("tbl_result_draft").insert(rows).execute()
        return len(resp.data)

    # -----------------------------------------------------------------------
    # Read
    # -----------------------------------------------------------------------

    def read_drafts(self, run_id: str) -> tuple[list[dict], list[dict]]:
        """Return (tournament_drafts, result_drafts) for run_id.

        Returns ([], []) if the run_id has no drafts (no exception).
        Resumable across processes — the run_id is the only state.
        """
        tournaments = (
            self._sb.table("tbl_tournament_draft")
            .select("*")
            .eq("txt_run_id", run_id)
            .execute()
            .data
        ) or []
        results = (
            self._sb.table("tbl_result_draft")
            .select("*")
            .eq("txt_run_id", run_id)
            .execute()
            .data
        ) or []
        return tournaments, results

    def list_drafts(self) -> list[dict]:
        """Return one entry per run_id with counts + first-seen timestamp.

        Aggregates in Python because Supabase REST doesn't support GROUP BY
        directly. Drafts are operator-scale (1-10 outstanding at most), so
        a full table scan + Python aggregation is acceptable.

        Each entry: {run_id, tournament_count, result_count, first_seen}.
        """
        tour_rows = (
            self._sb.table("tbl_tournament_draft")
            .select("txt_run_id, ts_created")
            .execute()
            .data
        ) or []
        res_rows = (
            self._sb.table("tbl_result_draft").select("txt_run_id").execute().data
        ) or []

        agg: dict[str, dict] = {}
        for r in tour_rows:
            rid = r["txt_run_id"]
            entry = agg.setdefault(
                rid, {"run_id": rid, "tournament_count": 0, "result_count": 0,
                      "first_seen": r["ts_created"]}
            )
            entry["tournament_count"] += 1
            if r["ts_created"] < entry["first_seen"]:
                entry["first_seen"] = r["ts_created"]
        for r in res_rows:
            rid = r["txt_run_id"]
            entry = agg.setdefault(
                rid, {"run_id": rid, "tournament_count": 0, "result_count": 0,
                      "first_seen": None}
            )
            entry["result_count"] += 1

        return sorted(agg.values(), key=lambda e: e.get("first_seen") or "")

    # -----------------------------------------------------------------------
    # RPC wrappers
    # -----------------------------------------------------------------------

    def commit(self, run_id: str) -> dict:
        """Call fn_commit_event_draft(run_id). Returns JSONB result as dict.

        Per Decision D2: never raises on unknown run_id — returns
        {tournaments_committed: 0, ...} which the CLI inspects to decide
        whether to warn via Telegram.
        """
        return self._sb.rpc("fn_commit_event_draft", {"p_run_id": run_id}).execute().data

    def discard(self, run_id: str) -> dict:
        """Call fn_discard_event_draft(run_id). Returns JSONB result as dict."""
        return self._sb.rpc("fn_discard_event_draft", {"p_run_id": run_id}).execute().data

    def dry_run(self, payload: dict) -> dict:
        """Call fn_dry_run_event_draft(payload). NEVER touches live or draft
        tables (per Decision D1). Returns counts + joint-pool detection from
        the in-memory IR payload.
        """
        return self._sb.rpc("fn_dry_run_event_draft", {"p_drafts": payload}).execute().data
