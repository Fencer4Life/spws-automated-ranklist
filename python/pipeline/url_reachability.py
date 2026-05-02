"""
Live reachability validator for tournament `url_results` URLs.

Phase 5 (post-Joint-fix follow-up): the human-friendly results URL we save
to `tbl_tournament.url_results` MUST actually open a results page in a
browser. The previous defect was storing the FTL JSON data endpoint
(`/events/results/data/<UUID>`) which is not browsable. A second class of
defect — invisible to a HEAD check — is FTL serving HTTP 200 with the
LOGIN WALL when accessed anonymously. The HTML body's `og:url` meta tag
redirects to `/account/login` even though the status code lies.

This validator authenticates against FTL when needed (re-using the
existing `python.scrapers.ftl_auth.get_authed_ftl_client`), follows
redirects, and inspects the response body for two failure modes:

  * Domain redirect to `/account/login` → REDIRECTED_TO_LOGIN
  * 404 / 403 / 5xx                       → HTTP_ERROR
  * Network failure / timeout             → UNREACHABLE

A passing result confirms (a) the URL fetches to a real results page and
(b) the body contains a results-table indicator.

The validator is called from `ReviewSession` BEFORE writing tournament
drafts, so we never persist a `url_results` that doesn't open in a
browser.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Callable, Optional


@dataclass
class URLCheckResult:
    """Outcome of a live URL reachability check.

    Attributes:
        url: The URL that was checked (input).
        ok: True iff the URL fetched to a real results page.
        reason: Short stable code: OK, REDIRECTED_TO_LOGIN, HTTP_ERROR,
                UNREACHABLE, NO_RESULTS_INDICATOR, INVALID_FORMAT.
        status_code: HTTP status (None if request failed before status).
        evidence: One-line excerpt explaining the verdict (og:url meta,
                  exception message, etc.).
    """
    url: str
    ok: bool
    reason: str
    status_code: Optional[int] = None
    evidence: Optional[str] = None


# ── URL-format regexes ──────────────────────────────────────────────────────

# FTL human-friendly results URL: /events/results/<32-hex-UUID>
# (the JSON data endpoint is /events/results/data/<UUID> — that is the
# defect we explicitly reject below).
FTL_HUMAN_URL_RE = re.compile(
    r"^https?://(?:www\.)?fencingtimelive\.com/events/results/[A-F0-9]{32}/?$",
    re.IGNORECASE,
)

FTL_DATA_URL_RE = re.compile(
    r"/events/results/data/[A-F0-9]{32}",
    re.IGNORECASE,
)


def is_ftl_human_url(url: str) -> bool:
    """True iff `url` is the human-friendly FTL results URL form.

    This is the URL we want to STORE in tbl_tournament.url_results.
    """
    return bool(url) and bool(FTL_HUMAN_URL_RE.match(url))


def is_ftl_data_url(url: str) -> bool:
    """True iff `url` points at the FTL JSON data endpoint.

    This URL form must NEVER appear in tbl_tournament.url_results — it
    returns JSON, not HTML, and 404s in a browser.
    """
    return bool(url) and bool(FTL_DATA_URL_RE.search(url))


def _extract_og_url(html: str) -> Optional[str]:
    """Pull `<meta property="og:url" content="…">` out of an HTML body.

    FTL's login-wall response has og:url pointing at /account/login —
    that is the signal we use to detect "200 OK but not actually a
    results page".
    """
    m = re.search(
        r'<meta[^>]+property=["\']og:url["\'][^>]+content=["\']([^"\']+)["\']',
        html,
        re.IGNORECASE,
    )
    return m.group(1) if m else None


def _has_results_indicator(html: str) -> bool:
    """True iff the HTML body contains an indicator of a real results page.

    FTL results pages embed a `<table id="resultList"…>` with
    `data-url="/events/results/data/<UUID>"`. The login wall does not.
    """
    if 'id="resultList"' in html:
        return True
    if "/events/results/data/" in html:
        return True
    return False


# ── Main validator ─────────────────────────────────────────────────────────


def check_results_url(
    url: str,
    *,
    http_get: Optional[Callable[[str], "tuple[int, str]"]] = None,
) -> URLCheckResult:
    """Validate a results URL by fetching it and inspecting the response.

    Args:
        url: The candidate `url_results` value.
        http_get: A callable `url -> (status_code, body)`. If omitted, an
            authed FTL client is used for FTL URLs and `httpx` for others.
            Tests inject a fake to avoid network.

    Returns:
        URLCheckResult with `ok=True` iff the URL points at a real,
        browsable results page.
    """
    if not url:
        return URLCheckResult(
            url=url, ok=False, reason="INVALID_FORMAT",
            evidence="empty URL",
        )

    # Cheap format check first — never let `/events/results/data/<UUID>`
    # through, even if the server returns 200 (it returns JSON, the user
    # clicks it and gets gibberish).
    if is_ftl_data_url(url):
        return URLCheckResult(
            url=url, ok=False, reason="INVALID_FORMAT",
            evidence="URL points at FTL JSON data endpoint, not the human-friendly results page",
        )

    fetch = http_get or _default_fetch_for_url(url)
    try:
        status, body = fetch(url)
    except Exception as exc:  # noqa: BLE001
        return URLCheckResult(
            url=url, ok=False, reason="UNREACHABLE",
            evidence=f"{type(exc).__name__}: {exc}",
        )

    if status >= 400:
        return URLCheckResult(
            url=url, ok=False, reason="HTTP_ERROR",
            status_code=status,
            evidence=f"HTTP {status}",
        )
    if status >= 300:
        # We follow redirects in `fetch`, so getting here means a redirect
        # the client refused to follow. Treat as failure.
        return URLCheckResult(
            url=url, ok=False, reason="HTTP_ERROR",
            status_code=status,
            evidence=f"HTTP {status} (unfollowed redirect)",
        )

    # FTL serves HTTP 200 + login-wall HTML to anonymous requests. Detect
    # via the og:url meta tag pointing at /account/login.
    og = _extract_og_url(body) or ""
    if "/account/login" in og.lower():
        return URLCheckResult(
            url=url, ok=False, reason="REDIRECTED_TO_LOGIN",
            status_code=status,
            evidence=f"og:url={og}",
        )

    # FTL human-friendly URL must contain the results-table indicator.
    # (We don't enforce this for non-FTL URLs since other platforms have
    # different page structures.)
    if "fencingtimelive.com" in url and not _has_results_indicator(body):
        return URLCheckResult(
            url=url, ok=False, reason="NO_RESULTS_INDICATOR",
            status_code=status,
            evidence="response has no <table id='resultList'> or /events/results/data/ marker",
        )

    return URLCheckResult(
        url=url, ok=True, reason="OK",
        status_code=status,
        evidence=og or None,
    )


# ── Default HTTP fetcher (authed for FTL, plain for everything else) ───────


def _default_fetch_for_url(url: str) -> Callable[[str], "tuple[int, str]"]:
    """Pick a sensible default fetcher per URL host.

    FTL pages have required login since 2026-04, so we wrap the existing
    authed FTL client. Non-FTL hosts use a plain httpx GET.
    """
    if "fencingtimelive.com" in url:
        return _authed_ftl_fetch
    return _plain_fetch


def _authed_ftl_fetch(url: str) -> "tuple[int, str]":
    """Fetch via authed FTL session (cookie-based login)."""
    from python.scrapers.ftl_auth import get_authed_ftl_client
    with get_authed_ftl_client() as client:
        resp = client.get(url, follow_redirects=True)
        return resp.status_code, resp.text


def _plain_fetch(url: str) -> "tuple[int, str]":
    """Fetch via plain httpx (no auth) for non-FTL hosts."""
    import httpx
    with httpx.Client(follow_redirects=True, timeout=15.0) as client:
        resp = client.get(url)
        return resp.status_code, resp.text
