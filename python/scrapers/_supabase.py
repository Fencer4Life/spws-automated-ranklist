"""
Shared Supabase and Telegram access for the scheduled scrapers.

Extracted verbatim from evf_sync.py, which is where these three grew and where
they were the only copy. A second scheduled scraper (pzsz_sync.py) needs exactly
the same three behaviours, and had two bad options without this module: import
evf_sync and drag in the whole FTL authentication chain with it, or duplicate the
retry logic and let the two copies drift.

WHY NOT python/tools/_backends.py. That module exists and speaks to the same
Management API, but it is framed for one-shot operator tools and has no retry at
all. A workflow that runs unattended on a cron at 06:00 needs the
retry-on-429/503 that lives here — the difference between a transient rate limit
and a red run nobody is awake to see.

Nothing here is PZSz-specific or EVF-specific.
"""

from __future__ import annotations

import time
from collections.abc import Callable

import httpx


def _management_query(ref: str, token: str, sql: str) -> list[dict]:
    """Execute SQL via Supabase Management API with retry."""
    for attempt in range(3):
        try:
            resp = httpx.post(
                f"https://api.supabase.com/v1/projects/{ref}/database/query",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"query": sql},
                timeout=60,
            )
            if resp.status_code in (429, 503):
                time.sleep(3 * (attempt + 1))
                continue
            if resp.status_code >= 400:
                raise RuntimeError(f"Management API error ({resp.status_code}): {resp.text[:200]}")
            return resp.json()
        except httpx.ReadTimeout:
            time.sleep(3 * (attempt + 1))
    raise RuntimeError("Management API: max retries exceeded")


def _telegram(bot_token: str, chat_id: str, msg: str) -> None:
    """Send Telegram notification."""
    if not bot_token or not chat_id:
        print(f"[Telegram] {msg}")
        return
    httpx.post(
        f"https://api.telegram.org/bot{bot_token}/sendMessage",
        data={"chat_id": chat_id, "text": msg, "parse_mode": "HTML"},
        timeout=10,
    )


def _get_active_season(
    ref: str,
    token: str,
    query: Callable[[str, str, str], list[dict]] | None = None,
) -> dict | None:
    """Get active season from CERT.

    `query` exists so a caller can supply its OWN module-level
    `_management_query` rather than this module's. That is not decoration: the
    EVF tests patch `evf_sync._management_query` and expect every query the sync
    issues to go through the patch. Resolving the callable here, at call time,
    keeps that seam exactly where it was before this module existed.
    """
    rows = (query or _management_query)(
        ref,
        token,
        "SELECT txt_code, dt_start::TEXT, dt_end::TEXT, id_season "
        "FROM tbl_season WHERE bool_active = TRUE",
    )
    return rows[0] if rows else None
