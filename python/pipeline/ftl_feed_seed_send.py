"""Generate and deliver an event's current FTL mix-all seed bundle (ADR-080 §5).

Delivery is intentionally at-least-once: manual and Telegram calls are deliberate
re-sends, while the deadline sweep only selects events whose ``ts_ftl_sent`` is
NULL. SMTP acceptance happens before the database stamp, so an ambiguous partial
failure can lead to a duplicate retry; exact-once email is not claimed.
"""

from __future__ import annotations

import argparse
import os
import re
import smtplib
import ssl
from dataclasses import dataclass
from datetime import date
from email.headerregistry import Address
from email.message import EmailMessage

from python.pipeline.db_connector import create_db_connector
from python.pipeline.ftl_seed_export import bundle_seed_zip
from python.pipeline.ftl_seed_export_db import FtlSeedExporter
from python.pipeline.notifications import TelegramNotifier

_EVENT_SEASON_SUFFIX = re.compile(r"-\d{4}-\d{4}$")
_INELIGIBLE_SWEEP_STATUSES = {"CANCELLED", "COMPLETED"}


@dataclass(frozen=True)
class DeliveryResult:
    """Safe-to-report result; recipient is always masked."""

    event_code: str
    recipient_masked: str
    filenames: tuple[str, ...]
    sent: bool
    stamped_at: str | None = None


def _validated_address(value: str, label: str) -> str:
    raw = value.strip()
    if not raw or "\r" in raw or "\n" in raw:
        raise ValueError(f"invalid {label} email address")
    try:
        address = Address(addr_spec=raw)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"invalid {label} email address") from exc
    if not address.username or not address.domain or str(address) != raw:
        raise ValueError(f"invalid {label} email address")
    return raw


def _mask_email(value: str) -> str:
    local, separator, domain = value.partition("@")
    if not separator:
        return "***"
    return f"{local[:1]}***@{domain}"


def build_seed_email(
    from_addr: str,
    to_addr: str,
    event_code: str,
    zip_bytes: bytes,
    filename: str,
) -> EmailMessage:
    """Build the bilingual organizer message with one in-memory ZIP attachment."""
    sender = _validated_address(from_addr, "sender")
    recipient = _validated_address(to_addr, "recipient")
    if not zip_bytes:
        raise ValueError("empty ZIP attachment")
    if not filename or "/" in filename or "\\" in filename:
        raise ValueError("invalid ZIP filename")

    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = recipient
    msg["Subject"] = f"SPWS – pliki startowe FTL – {event_code}"
    msg.set_content(
        "Dzień dobry,\n\n"
        f"w załączniku znajdują się aktualne pliki startowe FTL dla {event_code}. "
        "Pakiet wygenerowano z deklaracji uczestników zapisanych w SPWS.\n\n"
        "Hello,\n\n"
        f"Attached is the current FTL seed bundle for {event_code}, generated from "
        "the participant declarations recorded in SPWS.\n"
    )
    msg.add_attachment(zip_bytes, maintype="application", subtype="zip", filename=filename)
    return msg


def send_via_gmail_smtp(msg: EmailMessage, smtp_user: str, app_password: str) -> None:
    """Authenticate only inside a certificate-verifying implicit-TLS connection."""
    user = _validated_address(smtp_user, "sender")
    if str(msg.get("From", "")) != user:
        raise ValueError("message From must match SMTP user")
    if not app_password:
        raise ValueError("Gmail app password is required")

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context, timeout=30) as smtp:
        smtp.login(user, app_password)
        refused = smtp.send_message(msg)
    if refused:
        raise smtplib.SMTPRecipientsRefused(refused)


def resolve_event_meta(db, event_code: str, target: str) -> dict:
    """Resolve the existing event/season contracts into exporter arguments."""
    if target not in {"local", "cert", "prod"}:
        raise ValueError("target must be local, cert, or prod")
    event = db.find_event_by_code(event_code)
    if not event:
        raise ValueError(f"event {event_code!r} not found")
    recipient = str(event.get("txt_organizer_email") or "").strip()
    if not recipient:
        raise ValueError(f"event {event_code!r} has no organizer email")
    recipient = _validated_address(recipient, "organizer")
    weapons = list(event.get("arr_weapons") or [])
    if not weapons:
        raise ValueError(f"event {event_code!r} has no declared weapons")

    season = db.find_season_by_id(event["id_season"])
    if not season:
        raise ValueError(f"season {event['id_season']!r} not found")
    season_end = date.fromisoformat(str(season["dt_end"])[:10])
    event_stem = _EVENT_SEASON_SUFFIX.sub("", event["txt_code"])
    return {
        **event,
        "txt_organizer_email": recipient,
        "weapons": weapons,
        "season_code": season["txt_code"],
        "season_end_year": season_end.year,
        "event_code_stem": event_stem,
        "target": target,
    }


def _notify_success(event_code: str, target: str, filenames: tuple[str, ...]) -> None:
    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
    )
    try:
        notifier.success(
            f"FTL seed delivered: {event_code} ({target.upper()}), {len(filenames)} file(s)"
        )
    except Exception as exc:  # notification must not turn a successful send into a retry
        print(f"Warning: Telegram confirmation failed ({type(exc).__name__})")


def send_seed_to_organizer(
    db,
    event_code: str,
    target: str,
    *,
    dry_run: bool = False,
    send_telegram: bool = False,
    smtp_user: str | None = None,
    app_password: str | None = None,
) -> DeliveryResult:
    """Generate the fresh mix-all bundle, optionally send it, then stamp success."""
    meta = resolve_event_meta(db, event_code, target)
    exporter = FtlSeedExporter(db._sb)
    files = exporter.build_bundle(
        id_event=meta["id_event"],
        weapons=meta["weapons"],
        season_code=meta["season_code"],
        event_code_stem=meta["event_code_stem"],
        season_end_year=meta["season_end_year"],
        season=meta["id_season"],
    )
    if not files:
        raise ValueError(f"event {event_code!r} produced an empty seed bundle")
    filenames = tuple(sorted(files))
    zip_bytes = bundle_seed_zip({name: files[name] for name in filenames})
    masked = _mask_email(meta["txt_organizer_email"])
    filename = f"{meta['season_code']}_{meta['event_code_stem']}_FTL_seed.zip"

    if dry_run:
        print(f"DRY RUN {event_code} -> {masked}; {len(filenames)} file(s): {', '.join(filenames)}")
        return DeliveryResult(event_code, masked, filenames, sent=False)

    if smtp_user is None or app_password is None:
        raise ValueError("SPWS Gmail credentials are required for a live send")
    msg = build_seed_email(smtp_user, meta["txt_organizer_email"], event_code, zip_bytes, filename)
    send_via_gmail_smtp(msg, smtp_user, app_password)
    stamped_at = db.mark_ftl_sent(event_code)
    if send_telegram:
        _notify_success(event_code, target, filenames)
    return DeliveryResult(event_code, masked, filenames, sent=True, stamped_at=stamped_at)


def sweep_deadlines(
    db,
    target: str,
    *,
    send_telegram: bool = False,
    today: date | None = None,
    smtp_user: str | None = None,
    app_password: str | None = None,
) -> list[DeliveryResult]:
    """Send eligible, still-live events after their registration cutoff date."""
    current_date = today or date.today()
    results: list[DeliveryResult] = []
    for event in db.list_ftl_delivery_candidates():
        cutoff_raw = event.get("dt_registration_deadline") or event.get("dt_start")
        end_raw = event.get("dt_end") or event.get("dt_start")
        if not cutoff_raw or not end_raw or not event.get("txt_organizer_email"):
            continue
        cutoff = date.fromisoformat(str(cutoff_raw)[:10])
        event_end = date.fromisoformat(str(end_raw)[:10])
        if cutoff >= current_date or event_end < current_date:
            continue
        if event.get("enum_status") in _INELIGIBLE_SWEEP_STATUSES:
            continue
        try:
            result = send_seed_to_organizer(
                db,
                event["txt_code"],
                target,
                dry_run=False,
                send_telegram=send_telegram,
                smtp_user=smtp_user,
                app_password=app_password,
            )
        except ValueError as exc:
            if "empty seed bundle" not in str(exc):
                raise
            print(f"Skipping {event['txt_code']}: empty seed bundle")
            continue
        results.append(result)
    return results


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--event-code")
    action.add_argument("--sweep-deadlines", action="store_true")
    parser.add_argument("--target", choices=("local", "cert", "prod"), required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--send-telegram", action="store_true")
    return parser


def main() -> int:
    args = _parser().parse_args()
    if args.sweep_deadlines and args.dry_run:
        raise SystemExit("--dry-run is supported only with --event-code")
    if args.target == "local" and not args.dry_run:
        raise SystemExit("LOCAL delivery is dry-run only")

    db = create_db_connector()
    smtp_user = None if args.dry_run else os.environ["SPWS_GMAIL_USER"]
    app_password = None if args.dry_run else os.environ["SPWS_GMAIL_APP_PASSWORD"]
    if args.sweep_deadlines:
        results = sweep_deadlines(
            db,
            args.target,
            send_telegram=args.send_telegram,
            smtp_user=smtp_user,
            app_password=app_password,
        )
        print(f"Deadline sweep delivered {len(results)} event(s)")
    else:
        send_seed_to_organizer(
            db,
            args.event_code,
            args.target,
            dry_run=args.dry_run,
            send_telegram=args.send_telegram,
            smtp_user=smtp_user,
            app_password=app_password,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
