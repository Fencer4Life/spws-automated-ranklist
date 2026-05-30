"""
CLI entry point for the ingestion pipeline.

Two ingest modes:

1. **Unified XML ingest (Phase 6, post-ADR-050)** — `ingest_xml_unified()`.
   Routes local XMLs through the same S1-S7 pipeline + DraftStore the URL
   path uses, so url_results lands on every draft row and the joint-pool
   detector inside fn_commit_event_draft fires on commit (ADR-049).

2. **Legacy direct write** — `run_ingest()` → `orchestrator.process_xml_file`.
   Bypasses drafts and joint-pool detection; kept only for backward
   compatibility with `--from-storage` until the storage harness migrates.
   Emits a DeprecationWarning on every call.

Usage:
    # Unified (post-fix) — for a known event_code with url_event populated:
    python -m pipeline.ingest_cli --event-code PPW4-SPWS-2025-2026 \\
        path/to/file1.xml path/to/file2.xml --season-end-year 2026
    # Then commit the draft batch:
    python -m pipeline.ingest_cli --commit-draft <run_id>

    # Legacy direct write (deprecated):
    python -m pipeline.ingest_cli path/to/file.xml --season-end-year 2026
"""

from __future__ import annotations

import argparse
import os
import sys
import uuid
import zipfile
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path

from python.pipeline.db_connector import create_db_connector
from python.pipeline.draft_diff import format_diff
from python.pipeline.draft_store import DraftStore
from python.pipeline.notifications import TelegramNotifier
from python.pipeline.orchestrator import IngestResult, process_xml_file
from python.pipeline.storage_handler import unzip_in_memory


def run_ingest(
    path: str,
    season_end_year: int,
    dry_run: bool = False,
    tournament_type: str = "PPW",
    db=None,
    notifier=None,
) -> IngestResult:
    """Process a local XML file or .zip archive.

    Args:
        path: Path to .xml or .zip file.
        season_end_year: End year of the active season.
        dry_run: If True, skip DB writes.
        tournament_type: Default tournament type for routing.
        db: Optional DbConnector (created from env if None).
        notifier: Optional TelegramNotifier (created from env if None).

    Returns:
        Combined IngestResult.
    """
    if db is None:
        db = create_db_connector()
    if notifier is None:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

    filepath = Path(path)

    if filepath.suffix.lower() == ".zip":
        zip_bytes = filepath.read_bytes()
        xml_files = unzip_in_memory(zip_bytes)
        combined = IngestResult()
        for fname, xml_bytes in xml_files.items():
            r = process_xml_file(
                file_bytes=xml_bytes,
                filename=fname,
                db=db,
                notifier=notifier,
                season_end_year=season_end_year,
                tournament_type=tournament_type,
                dry_run=dry_run,
            )
            combined.tournament_ids.extend(r.tournament_ids)
            combined.matched += r.matched
            combined.pending += r.pending
            combined.auto_created += r.auto_created
            combined.skipped += r.skipped
            combined.errors.extend(r.errors)
            combined.skipped_files.extend(r.skipped_files)
        notifier.summary(combined)
        return combined
    else:
        xml_bytes = filepath.read_bytes()
        r = process_xml_file(
            file_bytes=xml_bytes,
            filename=filepath.name,
            db=db,
            notifier=notifier,
            season_end_year=season_end_year,
            tournament_type=tournament_type,
            dry_run=dry_run,
        )
        notifier.summary(r)
        return r


def ingest_xml_unified(
    path: str | list[str],
    event_code: str,
    season_end_year: int,
    url_event_override: str | None = None,
    db=None,
    notifier=None,
    dry_run: bool = False,
) -> str | None:
    """Unified XML ingest — the post-ADR-050 replacement for `process_xml_file`.

    Looks up the event's `url_event` (from `tbl_event.url_event` unless
    `url_event_override` is given), parses each XML with that URL set as
    `source_url`, runs the S1-S7 pipeline via `run_pipeline`, and
    materializes drafts under a single `run_id` via `DraftStore`.

    The caller commits via `--commit-draft <run_id>`, which routes through
    `fn_commit_event_draft` — the function that sets `bool_joint_pool_split`
    on sibling rows sharing `url_results` and re-sums
    `int_participant_count` to the full pool size (ADR-049). Bypassing this
    path (as `process_xml_file` did) silently leaves V-cat slices like
    35 / 36 fencers instead of the full combined-pool size.

    Args:
        path: One XML path, or a list of XML paths under the same event.
        event_code: Event identifier (e.g. "PPW4-SPWS-2025-2026").
        season_end_year: Active season's end year (e.g. 2026).
        url_event_override: If given, used instead of tbl_event.url_event.
        db: DbConnector (created from env if None).
        notifier: TelegramNotifier (created from env if None).
        dry_run: Parse + pipeline only; do not write drafts.

    Returns:
        run_id (str) if drafts were materialized; None if dry_run.

    Raises:
        ValueError: event_code not found, or no url_event populated.
    """
    # Defer imports so test patches on these symbols are honoured.
    from python.scrapers import fencingtime_xml as _ft_xml
    from python.pipeline.review_cli import ReviewSession

    if db is None:
        db = create_db_connector()
    if notifier is None:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

    event = db.find_event_by_code(event_code)
    if event is None:
        raise ValueError(
            f"Event {event_code!r} not found in tbl_event. "
            f"Populate it first or check the spelling."
        )

    url_event = (
        url_event_override
        or event.get("url_event")
        or event.get("url_results")
    )
    if not url_event:
        raise ValueError(
            f"Event {event_code!r} has no url_event populated. "
            f"Populate it first:\n"
            f"  UPDATE tbl_event SET url_event = '<URL>' "
            f"WHERE txt_code = '{event_code}';"
        )

    paths = [path] if isinstance(path, (str, Path)) else list(path)

    draft_store = DraftStore(db)
    session = ReviewSession(
        event_code=event_code,
        db=db,
        draft_store=draft_store,
        # ReviewSession's prompt/output callables are unused in batch mode —
        # we drive run_iteration directly without going through its
        # interactive loop. Pass safe defaults so nothing blocks on stdin.
        prompt=lambda _msg: "q",
        output=print,
        season_end_year=season_end_year,
        notifier=notifier,
    )
    # Skip URL reachability validation in batch — the operator vouches for
    # the url_event they populated, and the offline batch path may not have
    # network access to FTL's authed endpoint.
    session.skip_url_validation = True

    for p in paths:
        p_str = str(p)
        file_bytes = Path(p_str).read_bytes()
        parsed = _ft_xml.parse(file_bytes, source_url=url_event)

        if dry_run:
            # Run S1-S7 but skip draft writes — useful for diagnostics.
            from python.pipeline.orchestrator import run_pipeline
            from python.pipeline.overrides import load_for_event
            ctx = run_pipeline(
                parsed=parsed,
                overrides=load_for_event(event_code),
                db=db,
                season_end_year=season_end_year,
                event_code=event_code,
            )
            print(
                f"[dry-run] {p_str}: matches={len(ctx.matches)}, "
                f"halted={ctx.halted}, "
                f"halt={(ctx.halt_reason.value if ctx.halt_reason else '-')}"
            )
            continue

        # Pre-check for structural pool-only files — skip cleanly with a
        # log line before the session writes anything. The pipeline would
        # halt on these anyway via s1_validate_ir, but pre-checking lets
        # us avoid noisy halt-state output for an expected-skip.
        if getattr(parsed, "is_pool_only_qualifier", False):
            print(
                f"  {p_str}: SKIPPED (pool-only qualifier — no DE bracket)"
            )
            continue

        ctx, _ = session.run_iteration(parsed)
        print(
            f"  {p_str}: matches={len(ctx.matches)}, halted={ctx.halted}, "
            f"run_id={session.run_id}"
        )

    return session.run_id if not dry_run else None


def _handle_draft_commands(args, notifier) -> bool:
    """Phase 2 (ADR-050) draft-management commands.

    Returns True if a draft command was invoked (caller should exit), False
    otherwise (caller continues with the path/from-storage flow).
    """
    db = create_db_connector()
    store = DraftStore(db)

    if args.list_drafts:
        drafts = store.list_drafts()
        if not drafts:
            print("No outstanding drafts.")
            return True
        print(f"{'run_id':<40}  {'tournaments':>11}  {'results':>7}  first_seen")
        for d in drafts:
            print(
                f"{d['run_id']:<40}  {d['tournament_count']:>11}  "
                f"{d['result_count']:>7}  {d.get('first_seen', '?')}"
            )
        return True

    if args.commit_draft:
        result = store.commit(args.commit_draft)
        n_t = result.get("tournaments_committed", 0)
        n_r = result.get("results_committed", 0)
        if n_t == 0 and n_r == 0:
            # Per Decision D1: zero-count outcome → Telegram warning + exit 1
            notifier.warning(
                f"Commit target {args.commit_draft} not found "
                f"(0 tournaments, 0 results). Run --list-drafts to inspect."
            )
            print(f"⚠ No draft found for run_id {args.commit_draft}")
            sys.exit(1)
        print(
            f"Committed draft {args.commit_draft}: {n_t} tournaments, {n_r} results, "
            f"{result.get('joint_pool_siblings_flagged', 0)} joint-pool siblings flagged."
        )
        return True

    if args.discard_draft:
        result = store.discard(args.discard_draft)
        n_t = result.get("tournaments_discarded", 0)
        n_r = result.get("results_discarded", 0)
        if n_t == 0 and n_r == 0:
            notifier.warning(
                f"Discard target {args.discard_draft} not found "
                f"(0 tournaments, 0 results)."
            )
            print(f"⚠ No draft found for run_id {args.discard_draft}")
            sys.exit(1)
        print(f"Discarded draft {args.discard_draft}: {n_t} tournaments, {n_r} results.")
        return True

    if args.resume_run_id:
        tournaments, results = store.read_drafts(args.resume_run_id)
        if not tournaments and not results:
            print(f"⚠ No draft found for run_id {args.resume_run_id}")
            sys.exit(1)
        # Build a payload that matches the dry-run RPC shape so format_diff
        # can render the same markdown.
        payload = {"tournaments": tournaments, "results": results}
        # Local computation of the rpc_result counts (no RPC call needed).
        rpc_result = {
            "tournaments_would_create": len(tournaments),
            "results_would_create": len(results),
            "joint_pool_sibling_groups": _count_joint_groups(tournaments),
        }
        md = format_diff(
            run_id=args.resume_run_id,
            payload=payload,
            rpc_result=rpc_result,
            event_match=None,
        )
        print(md)
        return True

    return False


def _count_joint_groups(tournaments: list[dict]) -> int:
    """Count distinct (weapon, gender, url_results) groups with ≥2 tournaments."""
    from collections import Counter
    keys = Counter(
        (t.get("enum_weapon"), t.get("enum_gender"), t.get("url_results"))
        for t in tournaments
        if t.get("url_results")
    )
    return sum(1 for count in keys.values() if count >= 2)


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest FencingTime XML results")
    parser.add_argument("path", nargs="*",
                        help="Path(s) to .xml or .zip file(s). With "
                             "--event-code, multiple XMLs land in a single "
                             "draft batch (one run_id).")
    parser.add_argument("--season-end-year", type=int)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--tournament-type", default="PPW")
    parser.add_argument("--from-storage", action="store_true",
                        help="Process files from Supabase Storage staging/ "
                             "(legacy direct-write path; deprecated).")
    parser.add_argument("--event-code", default=None,
                        help="Route XML through the unified pipeline for "
                             "this event_code (recommended). Joint-pool + "
                             "url_results are handled at commit via "
                             "fn_commit_event_draft (ADR-049).")
    parser.add_argument("--url-event", default=None,
                        help="Override tbl_event.url_event for this run "
                             "(used only with --event-code).")
    # Phase 2 (ADR-050) draft-management commands. Mutually exclusive with
    # each other; do not require --season-end-year.
    draft_group = parser.add_mutually_exclusive_group()
    draft_group.add_argument("--commit-draft", metavar="UUID",
                             help="Commit a materialized draft to live tables")
    draft_group.add_argument("--discard-draft", metavar="UUID",
                             help="Discard a materialized draft")
    draft_group.add_argument("--list-drafts", action="store_true",
                             help="List outstanding drafts (run_id, counts, age)")
    draft_group.add_argument("--resume-run-id", metavar="UUID",
                             help="Re-render the markdown diff for an existing draft")
    args = parser.parse_args()

    # Draft commands take precedence and don't need --season-end-year.
    is_draft_cmd = bool(
        args.list_drafts or args.commit_draft or args.discard_draft
        or args.resume_run_id
    )
    if not is_draft_cmd and args.season_end_year is None:
        parser.error("--season-end-year is required unless using a --*-draft / --list-drafts / --resume-run-id flag")

    if is_draft_cmd:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            _handle_draft_commands(args, notifier)
        except SystemExit:
            raise
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
        return

    if args.from_storage:
        from python.pipeline.storage_handler import StorageHandler
        db = create_db_connector()
        from supabase import create_client
        sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
        storage = StorageHandler(sb)
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

        try:
            staging_files = storage.list_staging_files()
            season = f"SPWS-{args.season_end_year - 1}-{args.season_end_year}"
            for fpath in staging_files:
                file_bytes = storage.download_file(fpath)
                fname = Path(fpath).name

                # Handle both .zip and .xml files in staging
                if fname.lower().endswith(".zip"):
                    xml_files = unzip_in_memory(file_bytes)
                elif fname.lower().endswith(".xml"):
                    xml_files = {fname: file_bytes}
                else:
                    continue

                for xname, xml_bytes in xml_files.items():
                    process_xml_file(
                        file_bytes=xml_bytes,
                        filename=xname,
                        db=db,
                        notifier=notifier,
                        season_end_year=args.season_end_year,
                        tournament_type=args.tournament_type,
                    )

            # ADR-025: do NOT auto-delete staging files — admin triggers cleanup via Telegram
            notifier.info(f"{len(staging_files)} file(s) in staging ready for cleanup.")
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
    elif args.event_code:
        # Unified pipeline path (post-ADR-050).
        if not args.path:
            parser.error("--event-code requires at least one XML path")
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            run_id = ingest_xml_unified(
                path=args.path,
                event_code=args.event_code,
                season_end_year=args.season_end_year,
                url_event_override=args.url_event,
                dry_run=args.dry_run,
                notifier=notifier,
            )
            if run_id:
                print(f"Draft batch run_id: {run_id}")
                print(f"Commit with: python -m python.pipeline.ingest_cli "
                      f"--commit-draft {run_id}")
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
    elif args.path:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            # Legacy path: nargs="*" gives a list; take the first element.
            path = args.path[0] if isinstance(args.path, list) else args.path
            result = run_ingest(
                path=path,
                season_end_year=args.season_end_year,
                dry_run=args.dry_run,
                tournament_type=args.tournament_type,
            )
            print(f"Matched: {result.matched}, Pending: {result.pending}, "
                  f"Auto-created: {result.auto_created}, Skipped: {result.skipped}")
            if result.errors:
                print(f"Errors: {result.errors}")
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
    else:
        parser.error("Either path or --from-storage is required")


if __name__ == "__main__":
    main()