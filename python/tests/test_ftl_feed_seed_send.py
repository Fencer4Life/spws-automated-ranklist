"""FTLDEL-PY acceptance tests for organizer seed delivery (ADR-080 §5)."""

from __future__ import annotations

import io
import smtplib
import zipfile
from datetime import date, timedelta
from email.message import EmailMessage
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from python.matcher.fuzzy_match import canonicalize_scraped_name
from python.pipeline.ftl_feed_seed_send import (
    build_seed_email,
    send_seed_to_organizer,
    send_via_gmail_smtp,
    sweep_deadlines,
)
from python.pipeline.ftl_seed_export import format_prenom_with_marker


def _db() -> MagicMock:
    db = MagicMock()
    db._sb = MagicMock()
    db.find_event_by_code.return_value = {
        "id_event": 42,
        "id_season": 7,
        "txt_code": "PPW5-2025-2026",
        "arr_weapons": ["EPEE"],
        "txt_organizer_email": "organizer@example.org",
        "ts_ftl_sent": None,
    }
    db.find_season_by_id.return_value = {
        "id_season": 7,
        "txt_code": "SPWS-2025-2026",
        "dt_end": "2026-06-30",
    }
    db.mark_ftl_sent.return_value = "2026-07-13T20:00:00+00:00"
    return db


def test_build_seed_email_contract_and_zip_attachment():
    """FTLDEL-PY-01: headers and ZIP attachment preserve the exact bytes."""
    payload = b"PK\x03\x04seed"

    msg = build_seed_email(
        "spws@example.com",
        "organizer@example.org",
        "PPW5-2025-2026",
        payload,
        "PPW5-seed.zip",
    )

    assert msg["From"] == "spws@example.com"
    assert msg["To"] == "organizer@example.org"
    assert "PPW5-2025-2026" in str(msg["Subject"])
    attachments = list(msg.iter_attachments())
    assert len(attachments) == 1
    assert attachments[0].get_filename() == "PPW5-seed.zip"
    assert attachments[0].get_content_type() == "application/zip"
    assert attachments[0].get_payload(decode=True) == payload


@pytest.mark.parametrize("address", ["", "not-an-email", "a@example.org\nBcc: leak@example.org"])
def test_build_seed_email_rejects_invalid_recipient(address: str):
    """FTLDEL-PY-05: invalid/header-injection recipients fail closed."""
    with pytest.raises(ValueError, match="email address"):
        build_seed_email("spws@example.com", address, "PPW5", b"zip", "seed.zip")


def test_send_via_gmail_uses_ssl_then_login_and_send(monkeypatch: pytest.MonkeyPatch):
    """FTLDEL-PY-02: authentication happens only inside SMTP_SSL."""
    smtp = MagicMock()
    smtp.__enter__.return_value = smtp
    smtp.send_message.return_value = {}
    smtp_ssl = MagicMock(return_value=smtp)
    monkeypatch.setattr("python.pipeline.ftl_feed_seed_send.smtplib.SMTP_SSL", smtp_ssl)
    msg = EmailMessage()
    msg["From"] = "spws@example.com"
    msg["To"] = "organizer@example.org"

    send_via_gmail_smtp(msg, "spws@example.com", "app-password")

    assert smtp_ssl.call_args.args == ("smtp.gmail.com", 465)
    assert smtp_ssl.call_args.kwargs["context"].check_hostname is True
    assert smtp_ssl.call_args.kwargs["timeout"] == 30
    smtp.login.assert_called_once_with("spws@example.com", "app-password")
    smtp.send_message.assert_called_once_with(msg)


def test_send_via_gmail_rejected_recipient_is_failure(monkeypatch: pytest.MonkeyPatch):
    """FTLDEL-PY-02: a non-empty refusal map is not SMTP acceptance."""
    smtp = MagicMock()
    smtp.__enter__.return_value = smtp
    smtp.send_message.return_value = {"organizer@example.org": (550, b"rejected")}
    monkeypatch.setattr(
        "python.pipeline.ftl_feed_seed_send.smtplib.SMTP_SSL", MagicMock(return_value=smtp)
    )
    msg = EmailMessage()
    msg["From"] = "spws@example.com"
    msg["To"] = "organizer@example.org"

    with pytest.raises(smtplib.SMTPRecipientsRefused):
        send_via_gmail_smtp(msg, "spws@example.com", "app-password")


def test_send_builds_nonempty_bundle_then_sends_then_stamps(
    monkeypatch: pytest.MonkeyPatch,
):
    """FTLDEL-PY-03: live orchestration sends the fresh bundle before stamping."""
    db = _db()
    exporter = MagicMock()
    exporter.build_bundle.return_value = {"SPWS_PPW5_E_mixall.xml": "<seed/>"}
    exporter_cls = MagicMock(return_value=exporter)
    smtp_sender = MagicMock()
    monkeypatch.setattr("python.pipeline.ftl_feed_seed_send.FtlSeedExporter", exporter_cls)
    monkeypatch.setattr("python.pipeline.ftl_feed_seed_send.send_via_gmail_smtp", smtp_sender)

    result = send_seed_to_organizer(
        db,
        "PPW5-2025-2026",
        "cert",
        dry_run=False,
        send_telegram=False,
        smtp_user="spws@example.com",
        app_password="app-password",
    )

    exporter_cls.assert_called_once_with(db._sb)
    smtp_sender.assert_called_once()
    sent_msg = smtp_sender.call_args.args[0]
    attachment = next(sent_msg.iter_attachments()).get_payload(decode=True)
    with zipfile.ZipFile(io.BytesIO(attachment)) as archive:
        assert archive.namelist() == ["SPWS_PPW5_E_mixall.xml"]
    db.mark_ftl_sent.assert_called_once_with("PPW5-2025-2026")
    assert result.sent is True
    assert result.stamped_at == "2026-07-13T20:00:00+00:00"
    assert result.filenames == ("SPWS_PPW5_E_mixall.xml",)


def test_dry_run_masks_recipient_and_never_sends_or_stamps(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
):
    """FTLDEL-PY-04: LOCAL rehearsal exposes no full address and has no writes."""
    db = _db()
    exporter = MagicMock()
    exporter.build_bundle.return_value = {"seed.xml": "<seed/>"}
    monkeypatch.setattr(
        "python.pipeline.ftl_feed_seed_send.FtlSeedExporter", MagicMock(return_value=exporter)
    )
    smtp_sender = MagicMock()
    monkeypatch.setattr("python.pipeline.ftl_feed_seed_send.send_via_gmail_smtp", smtp_sender)

    result = send_seed_to_organizer(
        db,
        "PPW5-2025-2026",
        "local",
        dry_run=True,
        send_telegram=False,
    )

    output = capsys.readouterr().out
    assert "organizer@example.org" not in output
    assert "o***@example.org" in output
    smtp_sender.assert_not_called()
    db.mark_ftl_sent.assert_not_called()
    assert result.sent is False


def test_missing_email_and_empty_bundle_fail_without_send(monkeypatch: pytest.MonkeyPatch):
    """FTLDEL-PY-05: metadata/bundle guards run before SMTP."""
    db = _db()
    db.find_event_by_code.return_value["txt_organizer_email"] = ""
    with pytest.raises(ValueError, match="organizer email"):
        send_seed_to_organizer(db, "PPW5-2025-2026", "cert", dry_run=True)

    db = _db()
    exporter = MagicMock()
    exporter.build_bundle.return_value = {}
    monkeypatch.setattr(
        "python.pipeline.ftl_feed_seed_send.FtlSeedExporter", MagicMock(return_value=exporter)
    )
    with pytest.raises(ValueError, match="empty seed bundle"):
        send_seed_to_organizer(db, "PPW5-2025-2026", "cert", dry_run=True)
    db.mark_ftl_sent.assert_not_called()


def test_sweep_selects_only_due_live_unstamped_events(monkeypatch: pytest.MonkeyPatch):
    """FTLDEL-PY-06: deadline automation filters unsafe/ineligible candidates."""
    today = date.today()
    due = (today - timedelta(days=1)).isoformat()
    future = (today + timedelta(days=1)).isoformat()
    db = MagicMock()
    db.list_ftl_delivery_candidates.return_value = [
        {
            "txt_code": "DUE",
            "dt_registration_deadline": due,
            "dt_start": future,
            "dt_end": future,
            "enum_status": "SCHEDULED",
            "txt_organizer_email": "a@b.pl",
        },
        {
            "txt_code": "FUTURE",
            "dt_registration_deadline": future,
            "dt_start": future,
            "dt_end": future,
            "enum_status": "SCHEDULED",
            "txt_organizer_email": "a@b.pl",
        },
        {
            "txt_code": "CANCELLED",
            "dt_registration_deadline": due,
            "dt_start": future,
            "dt_end": future,
            "enum_status": "CANCELLED",
            "txt_organizer_email": "a@b.pl",
        },
        {
            "txt_code": "PAST",
            "dt_registration_deadline": due,
            "dt_start": due,
            "dt_end": due,
            "enum_status": "SCHEDULED",
            "txt_organizer_email": "a@b.pl",
        },
        {
            "txt_code": "NOEMAIL",
            "dt_registration_deadline": due,
            "dt_start": future,
            "dt_end": future,
            "enum_status": "SCHEDULED",
            "txt_organizer_email": None,
        },
    ]
    send = MagicMock(return_value=SimpleNamespace(event_code="DUE", sent=True))
    monkeypatch.setattr("python.pipeline.ftl_feed_seed_send.send_seed_to_organizer", send)

    results = sweep_deadlines(db, "prod", send_telegram=True, today=today)

    assert [r.event_code for r in results] == ["DUE"]
    send.assert_called_once()
    assert send.call_args.args[1:3] == ("DUE", "prod")


def test_sweep_skips_empty_bundle_and_continues(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
):
    """FTLDEL-PY-06: an empty event does not block later eligible deliveries."""
    today = date.today()
    due = (today - timedelta(days=1)).isoformat()
    future = (today + timedelta(days=1)).isoformat()
    db = MagicMock()
    db.list_ftl_delivery_candidates.return_value = [
        {
            "txt_code": "EMPTY",
            "dt_registration_deadline": due,
            "dt_start": future,
            "dt_end": future,
            "enum_status": "SCHEDULED",
            "txt_organizer_email": "empty@example.org",
        },
        {
            "txt_code": "READY",
            "dt_registration_deadline": due,
            "dt_start": future,
            "dt_end": future,
            "enum_status": "SCHEDULED",
            "txt_organizer_email": "ready@example.org",
        },
    ]
    delivered = SimpleNamespace(event_code="READY", sent=True)
    send = MagicMock(
        side_effect=[ValueError("event 'EMPTY' produced an empty seed bundle"), delivered]
    )
    monkeypatch.setattr("python.pipeline.ftl_feed_seed_send.send_seed_to_organizer", send)

    results = sweep_deadlines(db, "prod", today=today)

    assert results == [delivered]
    assert send.call_count == 2
    assert "Skipping EMPTY: empty seed bundle" in capsys.readouterr().out


def test_generated_marker_roundtrips_to_canonical_scraped_name():
    """FTLDEL-PY-07: exporter and matcher agree across their graph boundary."""
    prenom = format_prenom_with_marker("Martyna", "1")
    assert canonicalize_scraped_name(f"SAMECKA-NACZYŃSKA {prenom}") == ("SAMECKA-NACZYŃSKA Martyna")
