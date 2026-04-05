"""
Telegram notification hub for the ingestion pipeline.

All pipeline events (routine, warnings, alerts, overdue reminders)
route through TelegramNotifier. Pass bot_token=None for silent mode
(unit tests, dry-run).

Uses send_telegram_alert() from scrapers.base as the low-level sender.
"""

from __future__ import annotations

from scrapers.base import send_telegram_alert


class TelegramNotifier:
    """Pipeline notification hub. 13+ use cases route through here."""

    def __init__(self, bot_token: str | None, chat_id: str | None) -> None:
        self._token = bot_token
        self._chat_id = chat_id

    def _send(self, message: str) -> None:
        if self._token and self._chat_id:
            send_telegram_alert(
                bot_token=self._token,
                chat_id=self._chat_id,
                message=message,
            )

    # --- Core methods ---

    def success(self, message: str) -> None:
        self._send(f"✅ {message}")

    def warning(self, message: str) -> None:
        self._send(f"⚠️ {message}")

    def error(self, message: str) -> None:
        self._send(f"❌ {message}")

    def info(self, message: str) -> None:
        self._send(f"ℹ️ {message}")

    def summary(self, result: object) -> None:
        """Format and send a batch summary from an IngestResult-like object."""
        t_count = len(getattr(result, "tournament_ids", []))
        matched = getattr(result, "matched", 0)
        pending = getattr(result, "pending", 0)
        auto_created = getattr(result, "auto_created", 0)
        skipped = getattr(result, "skipped", 0)
        errors = getattr(result, "errors", [])
        skipped_files = getattr(result, "skipped_files", [])

        lines = [
            f"📊 Ingestion summary: {t_count} tournaments",
            f"  • {matched} matched, {pending} pending, {auto_created} auto-created, {skipped} skipped",
        ]
        if skipped_files:
            lines.append(f"  • {len(skipped_files)} files skipped: {', '.join(skipped_files)}")
        if errors:
            lines.append(f"  • {len(errors)} errors")
        self._send("\n".join(lines))

    # --- Routine notifications ---

    def notify_import_success(self, tournament_info: str, counts: dict) -> None:
        parts = [f"{counts.get('matched', 0)} matched"]
        if counts.get("pending"):
            parts.append(f"{counts['pending']} pending")
        if counts.get("auto_created"):
            parts.append(f"{counts['auto_created']} auto-created")
        self.success(f"{tournament_info} imported. {', '.join(parts)}.")

    def notify_batch_complete(
        self, file_count: int, skip_count: int, tournament_count: int
    ) -> None:
        self.success(
            f"Batch complete: {file_count} files processed, "
            f"{skip_count} skipped, {tournament_count} tournaments imported."
        )

    def notify_files_received(self, email_subject: str, file_count: int) -> None:
        self.info(
            f"New files from spws.weterani@gmail.com: "
            f"{file_count} XMLs extracted from {email_subject}"
        )

    # --- Warning notifications ---

    def notify_identity_review(self, count: int, event_name: str) -> None:
        self.warning(
            f"{count} fencers need identity review from {event_name}. "
            f"Review in Identity Manager."
        )

    def notify_missing_dob(self, count: int, filename: str) -> None:
        self.warning(
            f"{count} fencers without birth date in {filename} — "
            f"can't split by category. Review needed."
        )

    def notify_duplicate_import(self, tournament_info: str) -> None:
        self.warning(
            f"{tournament_info} already imported. Re-import will replace existing results."
        )

    def notify_non_xml_skipped(self, skip_count: int, xml_count: int) -> None:
        self.info(
            f"Skipped {skip_count} non-XML files from archive. "
            f"Processed {xml_count} XML files."
        )

    # --- Alert notifications ---

    def notify_tournament_not_found(
        self,
        weapon: str,
        gender: str,
        category: str,
        date: str,
        event_name: str,
    ) -> None:
        self.error(
            f"No DB tournament for: {weapon} {gender} {category} {date} ({event_name}). "
            f"Create it and re-run."
        )

    def notify_event_missing_tournament(
        self, event_name: str, weapon: str, gender: str, category: str
    ) -> None:
        self.warning(
            f"Event '{event_name}' exists but missing tournament: "
            f"{weapon} {gender} {category}. Create it."
        )

    def notify_unrecognized_xml(self, filename: str) -> None:
        self.error(f"Unrecognized XML file: {filename} — not FTL format.")

    def notify_pipeline_failure(self, error_msg: str) -> None:
        self.error(f"Ingestion failed: {error_msg}")

    # --- Overdue reminders (daily cron) ---

    def notify_overdue_domestic(self, event_name: str, days: int) -> None:
        self.warning(
            f"{event_name} results not received ({days} days overdue). "
            f"Check email or provide URL."
        )

    def notify_overdue_international(self, event_name: str, days: int) -> None:
        self.warning(
            f"{event_name} results not found ({days} days overdue). Provide URL?"
        )
