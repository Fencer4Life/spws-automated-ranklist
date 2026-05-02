"""
Standalone Phase 5 staging report generator.

Re-renders `doc/staging/<event_code>.md` from the **current DB state**
WITHOUT re-running the ingestion pipeline. Use it when:

* You fixed something in the FencerAliasManager UI and want to confirm
  the ❌ count dropped before sign-off.
* You committed an event and want a "post-commit" snapshot.
* The previous staging .md got out of date.

Usage:
    python -m python.tools.phase5_report --event-code GP1-2023-2024
    python -m python.tools.phase5_report --event-code GP1-2023-2024 \
        --run-id <uuid>            # override which run_id to read
    python -m python.tools.phase5_report --event-code GP1-2023-2024 \
        --staging-dir doc/staging  # override output dir

The format matches the runner's auto-generated `.md` exactly because
both use `phase5_runner._multi_summary_md`. No new templates.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from python.pipeline.db_connector import create_db_connector


def _latest_run_id_for_event(db, event_code: str) -> str | None:
    """Find the most recent draft run_id for the named event.

    Reads `tbl_tournament_draft` rows whose txt_code starts with the
    event code (drafts encode `<EVENT>-<V>-<W>-<G>`), picks the highest
    id_tournament_draft, returns its txt_run_id. None if no drafts.
    """
    sb = db._sb
    resp = (
        sb.table("tbl_tournament_draft")
        .select("id_tournament_draft, txt_run_id, txt_code")
        .like("txt_code", f"{event_code}-%")
        .order("id_tournament_draft", desc=True)
        .limit(1)
        .execute()
    )
    if not resp.data:
        return None
    return resp.data[0]["txt_run_id"]


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Re-render Phase 5 staging .md from DB only (no re-ingest)."
    )
    p.add_argument(
        "--event-code", required=True,
        help="Event txt_code (e.g. GP1-2023-2024) — must already exist in tbl_event.",
    )
    p.add_argument(
        "--run-id", default=None,
        help="Override which draft run_id to read. Defaults to the most "
             "recent draft for the event.",
    )
    p.add_argument(
        "--staging-dir", default="doc/staging",
        help="Where to write the .md (default: doc/staging).",
    )
    args = p.parse_args(argv)

    db = create_db_connector()

    # Defer the heavy import so --help is fast.
    from python.tools.phase5_runner import (
        _fetch_event_meta, _multi_summary_md,
    )

    event_meta = _fetch_event_meta(db, args.event_code)
    if event_meta is None:
        print(
            f"❌ event {args.event_code} not found in tbl_event",
            file=sys.stderr,
        )
        return 1

    run_id = args.run_id or _latest_run_id_for_event(db, args.event_code)
    if run_id is None:
        # Still useful — produce a "live" report from committed tournaments.
        print(
            f"⚠ no draft run_id for {args.event_code}; rendering "
            "committed-only report",
            file=sys.stderr,
        )

    # No ctxs (DB-only). The renderer falls back gracefully — the
    # alias-pending section reads from `tbl_result_draft` via
    # `derive_pending_from_run_id`, the tournaments section reads
    # tbl_tournament / tbl_tournament_draft directly.
    md = _multi_summary_md(
        args.event_code, event_meta, ctxs=[], db=db,
        pool_brackets=None, pool_warnings=None,
        run_id=run_id,
        url_check_results={},
    )
    out_path = Path(args.staging_dir) / f"{args.event_code}.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(md, encoding="utf-8")
    print(f"→ Wrote {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
