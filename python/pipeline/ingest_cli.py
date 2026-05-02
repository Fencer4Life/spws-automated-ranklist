"""
CLI entry point for the ingestion pipeline.

Usage:
    python -m pipeline.ingest_cli path/to/file.xml --season-end-year 2026
    python -m pipeline.ingest_cli path/to/archive.zip --season-end-year 2026 --dry-run
    python -m pipeline.ingest_cli --from-storage --season-end-year 2026
"""

from __future__ import annotations

import argparse
import os
import sys
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
    parser.add_argument("path", nargs="?", help="Path to .xml or .zip file")
    parser.add_argument("--season-end-year", type=int)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--tournament-type", default="PPW")
    parser.add_argument("--from-storage", action="store_true",
                        help="Process files from Supabase Storage staging/")
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
    elif args.path:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            result = run_ingest(
                path=args.path,
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