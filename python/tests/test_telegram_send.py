"""TG.01–07 — a Telegram message either arrives or the run log says why not.

Telegram refuses a message whose formatting it cannot parse with HTTP 400 "can't
parse entities": an HTML message holding a tag it does not know (a traceback's
``<module>``, a Cloudflare error page quoted in an exception), a legacy-Markdown
message with a lone ``_``. The senders never read the reply. Two pipeline messages
were refused every time they were sent: ``notify_evf_promoted`` ("promoted to
EVF_PUBLISHED") and ``notify_event_commit`` on a PEW cascade ("txt_code → …").
``python/telegram.py`` reads the reply, sends a refused formatting again as plain
text, and prints any other refusal to stderr with Telegram's reason.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import httpx
import pytest

from python.telegram import LIMIT, plain, send_message

ROOT = Path(__file__).resolve().parents[2]
PARSE_ERROR = {
    "ok": False,
    "error_code": 400,
    "description": "Bad Request: can't parse entities: Can't find end of the entity starting at byte offset 31",
}


class FakePost:
    """Records each call and answers with the next queued response."""

    def __init__(self, *responses: httpx.Response | Exception) -> None:
        self.responses = list(responses)
        self.calls: list[dict[str, Any]] = []

    def __call__(self, url: str, **kwargs: Any) -> httpx.Response:
        self.calls.append({"url": url, **kwargs})
        answer = self.responses.pop(0)
        if isinstance(answer, Exception):
            raise answer
        return answer


def _ok() -> httpx.Response:
    return httpx.Response(200, json={"ok": True, "result": {}})


def test_TG_01_an_accepted_message_is_sent_once_with_its_formatting() -> None:
    post = FakePost(_ok())
    assert send_message("tok", "42", "<b>done</b>", post=post) is True
    assert len(post.calls) == 1
    assert post.calls[0]["data"] == {"chat_id": "42", "text": "<b>done</b>", "parse_mode": "HTML"}


def test_TG_02_refused_formatting_is_sent_again_as_plain_text(
    capsys: pytest.CaptureFixture[str],
) -> None:
    post = FakePost(httpx.Response(400, json=PARSE_ERROR), _ok())
    text = "❌ <b>capture failed</b>\nRuntimeError: Management API error (502): <html><body>Bad gateway</body></html> &amp; more"
    assert send_message("tok", "42", text, post=post) is True
    retry = post.calls[1]["data"]
    assert "parse_mode" not in retry
    assert retry["text"].startswith("❌ capture failed\nRuntimeError: Management API error (502):")
    assert "<b>" not in retry["text"] and "& more" in retry["text"]
    assert "can't parse entities" in capsys.readouterr().err


def test_TG_03_a_markdown_message_with_a_lone_underscore_still_arrives() -> None:
    post = FakePost(httpx.Response(400, json=PARSE_ERROR), _ok())
    text = "*SPWS Scraper Alert*\nℹ️ PEW7-2025-2026: EVF parity passed — promoted to EVF_PUBLISHED."
    assert send_message("tok", "42", text, parse_mode="Markdown", post=post) is True
    assert post.calls[1]["data"] == {"chat_id": "42", "text": text}


def test_TG_04_any_other_refusal_is_reported_and_not_retried(
    capsys: pytest.CaptureFixture[str],
) -> None:
    post = FakePost(
        httpx.Response(400, json={"ok": False, "description": "Bad Request: chat not found"})
    )
    assert send_message("tok", "42", "hello", post=post) is False
    assert len(post.calls) == 1
    assert "chat not found" in capsys.readouterr().err


def test_TG_05_a_network_failure_never_breaks_the_run(capsys: pytest.CaptureFixture[str]) -> None:
    post = FakePost(httpx.ConnectError("boom for bot tok-secret"))
    assert send_message("tok-secret", "42", "hello", post=post) is False
    err = capsys.readouterr().err
    assert "boom" in err and "tok-secret" not in err


def test_TG_06_a_message_is_cut_to_telegrams_limit() -> None:
    post = FakePost(_ok())
    assert send_message("tok", "42", "x" * (LIMIT + 50), parse_mode=None, post=post) is True
    assert len(post.calls[0]["data"]["text"]) == LIMIT
    assert plain("a &lt;b&gt; <i>c</i>", "HTML") == "a <b> c"


def test_TG_07_every_message_sender_goes_through_python_telegram() -> None:
    """Only python/telegram.py posts to sendMessage (sendDocument raises on refusal)."""
    senders = [
        str(p.relative_to(ROOT))
        for p in sorted((ROOT / "python").rglob("*.py"))
        if "tests" not in p.parts
        and p.name != "telegram.py"
        and "sendMessage" in p.read_text(encoding="utf-8")
        and "api.telegram.org" in p.read_text(encoding="utf-8")
    ]
    assert senders == []
