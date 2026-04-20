"""
Shared utilities for all scraper modules.

- Result format definition
- URL dispatcher
- Retry logic with exponential backoff
- Telegram alerting
- Validation and idempotency helpers
- Minimum participant threshold check
"""

from __future__ import annotations

import asyncio
import re

import httpx


def detect_platform(url: str) -> str:
    """Detect which fencing platform a URL belongs to.

    Returns one of: 'ftl', 'engarde', 'fourfence'.
    Raises ValueError for unknown URLs.
    """
    url_lower = url.lower()
    if "fencingtimelive.com" in url_lower:
        return "ftl"
    if "engarde-service.com" in url_lower:
        return "engarde"
    if "4fence.it" in url_lower:
        return "fourfence"
    if "dartagnan.live" in url_lower:
        return "dartagnan"
    raise ValueError(f"Unsupported platform URL: {url}")


def prepare_result_rows(
    parsed: list[dict], tournament_id: int
) -> list[dict]:
    """Convert parsed scraper results into DB-ready rows.

    Each row has: id_tournament, int_place, fencer_name, country,
    and num_final_score=None (scoring happens later).
    """
    rows = []
    for r in parsed:
        rows.append({
            "id_tournament": tournament_id,
            "int_place": r["place"],
            "place": r["place"],
            "fencer_name": r["fencer_name"],
            "country": r.get("country"),
            "num_final_score": None,
        })
    return rows


def filter_existing_results(
    parsed: list[dict], existing_names: set[str]
) -> list[dict]:
    """Filter out results for fencers already imported (idempotency)."""
    return [r for r in parsed if r["fencer_name"] not in existing_names]


def check_min_participants(
    participant_count: int,
    tournament_type: str,
    min_evf: int = 5,
    min_ppw: int = 1,
) -> dict:
    """Check if a tournament meets the minimum participant threshold.

    EVF tournaments (PEW, MEW, MSW) require min_evf participants.
    Domestic tournaments (PPW, MPW) require min_ppw participants.
    """
    evf_types = {"PEW", "MEW", "MSW"}
    if tournament_type in evf_types:
        minimum = min_evf
    else:
        minimum = min_ppw

    if participant_count < minimum:
        return {
            "rejected": True,
            "reason": (
                f"Participant count {participant_count} below minimum "
                f"{minimum} for {tournament_type} tournaments"
            ),
        }
    return {"rejected": False, "reason": ""}


def validate_parse_results(results: list[dict], source_url: str) -> None:
    """Validate that parse results are complete. Raises ValueError if not."""
    if not results:
        raise ValueError(
            f"No results found from {source_url}. "
            "Import aborted — incomplete or empty data."
        )
    for i, r in enumerate(results):
        if "place" not in r:
            raise ValueError(
                f"Result {i} from {source_url} is missing 'place'. "
                "Import aborted — incomplete data."
            )
        if "fencer_name" not in r or not r["fencer_name"]:
            raise ValueError(
                f"Result {i} from {source_url} is missing 'fencer_name'. "
                "Import aborted — incomplete data."
            )


async def fetch_with_retry(
    fetch_fn,
    url: str,
    max_retries: int = 3,
    base_delay: float = 2.0,
) -> str:
    """Fetch a URL with exponential backoff retry on transient failures.

    fetch_fn: async callable(url) -> str
    Retries up to max_retries times with delays: base_delay^1, base_delay^2, ...
    """
    last_error = None
    for attempt in range(1, max_retries + 1):
        try:
            return await fetch_fn(url)
        except (ConnectionError, httpx.ConnectError, httpx.TimeoutException) as e:
            last_error = e
            if attempt < max_retries:
                delay = base_delay ** attempt
                await asyncio.sleep(delay)
    raise last_error  # type: ignore[misc]


def send_telegram_alert(
    bot_token: str, chat_id: str, message: str, error: str | None = None
) -> None:
    """Send an alert to a Telegram chat via Bot API."""
    text = f"*SPWS Scraper Alert*\n{message}"
    if error:
        text += f"\n```\n{error}\n```"

    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "Markdown",
    }

    with httpx.Client() as client:
        client.post(url, json=payload)
