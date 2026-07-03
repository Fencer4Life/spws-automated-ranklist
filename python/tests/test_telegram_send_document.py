"""
Plan-test-ID 5.9: TelegramNotifier.send_document — multipart .md upload.

Verifies the new send_document method on TelegramNotifier (notifications.py)
that POSTs multipart/form-data to https://api.telegram.org/bot<token>/sendDocument.

Also verifies the higher-level send_staging_report wrapper.

ADR-059 — Telegram document delivery. Null-safe per ADR-061 (LOCAL).
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest


def test_send_document_posts_multipart_form_data():
    # 5.9.1 — POST goes to https://api.telegram.org/bot<TOKEN>/sendDocument
    # with multipart files=document and form data chat_id + caption
    from python.pipeline.notifications import TelegramNotifier

    notif = TelegramNotifier(bot_token="ABC", chat_id="123")
    with patch("python.pipeline.notifications.httpx") as mock_httpx:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"ok": True, "result": {"message_id": 1}}
        mock_resp.raise_for_status = MagicMock()
        mock_httpx.post.return_value = mock_resp

        notif.send_document(
            file_bytes=b"# foo\n",
            filename="EVENT-A-full.md",
            caption="📄 EVENT-A · full",
        )

        mock_httpx.post.assert_called_once()
        url = mock_httpx.post.call_args.args[0]
        assert "https://api.telegram.org/botABC/sendDocument" == url
        kwargs = mock_httpx.post.call_args.kwargs
        # 'files' carries the document
        assert "files" in kwargs
        assert "document" in kwargs["files"]
        fname, fbytes, mime = kwargs["files"]["document"]
        assert fname == "EVENT-A-full.md"
        assert fbytes == b"# foo\n"
        assert mime == "text/markdown"
        # 'data' carries chat_id + caption
        assert "data" in kwargs
        assert kwargs["data"]["chat_id"] == "123"
        assert kwargs["data"]["caption"] == "📄 EVENT-A · full"


def test_send_document_skipped_when_no_token():
    # 5.9.2 — null-safe: returns {'skipped': True} when no token
    from python.pipeline.notifications import TelegramNotifier

    notif = TelegramNotifier(bot_token=None, chat_id="123")
    with patch("python.pipeline.notifications.httpx") as mock_httpx:
        result = notif.send_document(b"x", "x.md", "caption")
        assert result == {"skipped": True, "reason": "no token/chat_id"}
        mock_httpx.post.assert_not_called()


def test_send_document_skipped_when_no_chat_id():
    # 5.9.3 — null-safe: returns {'skipped': True} when no chat_id
    from python.pipeline.notifications import TelegramNotifier

    notif = TelegramNotifier(bot_token="ABC", chat_id=None)
    with patch("python.pipeline.notifications.httpx") as mock_httpx:
        result = notif.send_document(b"x", "x.md", "caption")
        assert result == {"skipped": True, "reason": "no token/chat_id"}
        mock_httpx.post.assert_not_called()


def test_send_staging_report_full_caption_format():
    # 5.9.4 — send_staging_report builds caption with kind + extras
    from python.pipeline.notifications import TelegramNotifier

    notif = TelegramNotifier(bot_token="ABC", chat_id="123")
    with patch.object(notif, "send_document") as mock_send:
        mock_send.return_value = {"ok": True}
        notif.send_staging_report(
            event_code="EVENT-A-2024-2025",
            md_bytes=b"# foo\n",
            kind="full",
            extras={"tournament_count": 6, "pending_aliases": 47},
        )
        mock_send.assert_called_once()
        args, kwargs = mock_send.call_args
        # Filename: <event_code>-full.md
        # The first arg is positional bytes, second is filename
        # Check via args[0]/args[1] or kwargs
        # Actual signature: send_document(file_bytes, filename, caption)
        if args:
            file_bytes_arg = args[0]
            filename_arg = args[1]
            caption_arg = args[2]
        else:
            file_bytes_arg = kwargs["file_bytes"]
            filename_arg = kwargs["filename"]
            caption_arg = kwargs["caption"]
        assert file_bytes_arg == b"# foo\n"
        assert filename_arg == "EVENT-A-2024-2025-full.md"
        # Caption includes event_code, kind, extras
        assert "EVENT-A-2024-2025" in caption_arg
        assert "full" in caption_arg
        assert "6" in caption_arg
        assert "47" in caption_arg


def test_send_staging_report_delta_filename_includes_timestamp():
    # 5.9.5 — kind='delta' filename includes timestamp suffix
    from python.pipeline.notifications import TelegramNotifier

    notif = TelegramNotifier(bot_token="ABC", chat_id="123")
    with patch.object(notif, "send_document") as mock_send:
        mock_send.return_value = {"ok": True}
        notif.send_staging_report(
            event_code="EVENT-A",
            md_bytes=b"# delta\n",
            kind="delta",
            extras={"changes": 3, "timestamp": "20260603_034512"},
        )
        args, kwargs = mock_send.call_args
        filename_arg = args[1] if args else kwargs["filename"]
        caption_arg = args[2] if args else kwargs["caption"]
        assert "EVENT-A-delta-20260603_034512.md" == filename_arg
        assert "delta" in caption_arg
        assert "3 changes" in caption_arg or "3" in caption_arg


def test_send_staging_report_invalid_kind_raises():
    # 5.9.6 — kind must be 'full' or 'delta'
    from python.pipeline.notifications import TelegramNotifier

    notif = TelegramNotifier(bot_token="ABC", chat_id="123")
    with pytest.raises(ValueError, match="kind"):
        notif.send_staging_report(
            event_code="X",
            md_bytes=b"x",
            kind="bogus",  # pyright: ignore[reportArgumentType] — intentionally invalid, proves rejection
            extras={},
        )
