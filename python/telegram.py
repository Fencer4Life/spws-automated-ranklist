"""Send a Telegram message, and know whether it arrived.

Every Telegram message sender under python/ goes through ``send_message``
(python/tests/test_telegram_send.py TG.07). Telegram refuses a message whose
formatting it cannot parse with HTTP 400 "can't parse entities": an HTML message
holding a tag it does not know (a traceback's ``<module>``, an error page quoted in
an exception), a legacy-Markdown message with a lone ``_`` (``EVF_PUBLISHED``,
``txt_code``). The senders never read the reply, so such an alert was lost without
trace. Now a refused formatting is sent again as plain text, and any other refusal
is printed to stderr with Telegram's reason. Nothing here raises: an alert never
breaks the run that sends it.
"""

from __future__ import annotations

import html
import re
import sys
from collections.abc import Callable

import httpx

API = "https://api.telegram.org/bot{token}/sendMessage"
LIMIT = 4096  # Telegram's longest message, in characters
_HTML_TAG = re.compile(
    r"</?(?:b|strong|i|em|u|ins|s|strike|del|code|pre|tg-spoiler|span|a|blockquote)(?:\s[^>]*)?>",
    re.IGNORECASE,
)

Post = Callable[..., httpx.Response]


def plain(text: str, parse_mode: str | None) -> str:
    """The text as Telegram would have shown it, without the markup it refused."""
    if parse_mode and parse_mode.upper() == "HTML":
        return html.unescape(_HTML_TAG.sub("", text))
    return text


def _reason(resp: httpx.Response) -> str:
    try:
        body: object = resp.json()
    except ValueError:
        return resp.text[:200]
    if isinstance(body, dict):
        description = body.get("description")
        if description:
            return str(description)
    return resp.text[:200]


def send_message(
    bot_token: str,
    chat_id: str,
    text: str,
    *,
    parse_mode: str | None = "HTML",
    timeout: float = 10.0,
    post: Post | None = None,
) -> bool:
    """Send ``text``; return whether Telegram accepted it, in its formatting or as plain text."""
    send = post or httpx.post
    url = API.format(token=bot_token)
    data = {"chat_id": chat_id, "text": text[:LIMIT]}
    if parse_mode:
        data["parse_mode"] = parse_mode
    try:
        resp = send(url, data=data, timeout=timeout)
        if resp.status_code == 200:
            return True
        reason = _reason(resp)
        if parse_mode and resp.status_code == 400 and "parse" in reason.lower():
            print(
                f"[Telegram] formatting refused ({reason}); sending it as plain text",
                file=sys.stderr,
            )
            resp = send(
                url,
                data={"chat_id": chat_id, "text": plain(text, parse_mode)[:LIMIT]},
                timeout=timeout,
            )
            if resp.status_code == 200:
                return True
            reason = _reason(resp)
        print(
            f"[Telegram] not delivered ({resp.status_code}: {reason}): {text[:200]}",
            file=sys.stderr,
        )
    except Exception as exc:  # noqa: BLE001 -- an alert must never break the run that sends it
        detail = f"{type(exc).__name__}: {exc}".replace(bot_token, "***") if bot_token else str(exc)
        print(f"[Telegram] not delivered ({detail}): {text[:200]}", file=sys.stderr)
    return False
