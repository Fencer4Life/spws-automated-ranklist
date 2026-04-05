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

from pipeline.db_connector import create_db_connector
from pipeline.notifications import TelegramNotifier
from pipeline.orchestrator import IngestResult, process_xml_file
from pipeline.storage_handler import unzip_in_memory


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
        return combined
    else:
        xml_bytes = filepath.read_bytes()
        return process_xml_file(
            file_bytes=xml_bytes,
            filename=filepath.name,
            db=db,
            notifier=notifier,
            season_end_year=season_end_year,
            tournament_type=tournament_type,
            dry_run=dry_run,
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest FencingTime XML results")
    parser.add_argument("path", nargs="?", help="Path to .xml or .zip file")
    parser.add_argument("--season-end-year", type=int, required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--tournament-type", default="PPW")
    parser.add_argument("--from-storage", action="store_true",
                        help="Process files from Supabase Storage staging/")
    args = parser.parse_args()

    if args.from_storage:
        from pipeline.storage_handler import StorageHandler
        db = create_db_connector()
        from supabase import create_client
        sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
        storage = StorageHandler(sb)
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

        staging_files = storage.list_staging_files()
        for fpath in staging_files:
            zip_bytes = storage.download_file(fpath)
            xml_files = unzip_in_memory(zip_bytes)
            for fname, xml_bytes in xml_files.items():
                process_xml_file(
                    file_bytes=xml_bytes,
                    filename=fname,
                    db=db,
                    notifier=notifier,
                    season_end_year=args.season_end_year,
                    tournament_type=args.tournament_type,
                )
    elif args.path:
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
    else:
        parser.error("Either path or --from-storage is required")


if __name__ == "__main__":
    main()