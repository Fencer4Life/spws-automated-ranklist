"""Render gated pzszerm.pl pages with a real browser engine (ADR-116).

Since 2026-10-06 pzszerm.pl answers a plain HTTP client with a JavaScript
"check" page — ``<p id="pzs-m">`` and no table — that sets a cookie and
reloads to the real page. httpx cannot run that script, so the calendar sync
and the start-list capture started coming back empty. A real browser engine
runs the page's own JavaScript exactly as a person's browser does — no forged
cookie, no pixel replay, no CAPTCHA, no login — and the real content appears.
This module drives headless Chromium through Playwright.

The browser work is isolated behind one seam, ``render(full_url) -> html``,
that performs a single page load. :class:`GatedFetcher` wraps it with the
gate-aware retry (reload again, as a browser would, until the check clears)
and exposes ``fetch(url, params) -> html`` — the contract the PZSz readers
already expect (:func:`pzsz_start_list.read_event_start_lists`, and the
calendar sources). Unit tests inject a fake ``render`` and never launch a
browser; the real Chromium runs only in the scheduled workflow (CI). Playwright
is imported lazily so importing this module needs no browser.

The fetcher never gets past a check it cannot clear: after its tries it returns
the check page unchanged, and the readers' own ``refuse_js_check`` guard
refuses it, so a gated run writes nothing and is simply run again later.
"""

from __future__ import annotations

import time
from collections.abc import Callable, Generator, Mapping
from contextlib import contextmanager
from dataclasses import dataclass
from urllib.parse import urlencode

from python.scrapers.pzsz_start_list import is_js_check

# A browser identical to a person's: the check's script runs the same for it.
DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)

# One render loads a URL once and returns the HTML its JavaScript produced.
RenderPage = Callable[[str], str]


def with_params(url: str, params: Mapping[str, object]) -> str:
    """The URL pzszerm.pl serves for ``fetch(url, params)``. The readers pass
    ``{"id": N}``; the calendar listing passes nothing."""
    if not params:
        return url
    return f"{url}?{urlencode(params)}"


def _default_backoff(attempt: int) -> float:
    """Seconds to wait after a gated try — longer each time, as the proven
    renderer did (2 s, 4 s, …)."""
    return 2.0 * attempt


@dataclass
class GatedFetcher:
    """``fetch(url, params) -> html`` over a one-load ``render``, reloading
    past pzszerm.pl's JavaScript check. ``sleep`` and ``backoff`` are injected
    so tests never wait."""

    render: RenderPage
    max_attempts: int = 6
    sleep: Callable[[float], None] = time.sleep
    backoff: Callable[[int], float] = _default_backoff

    def fetch(self, url: str, params: Mapping[str, object]) -> str:
        full = with_params(url, params)
        html = ""
        for attempt in range(1, self.max_attempts + 1):
            html = self.render(full)
            if not is_js_check(html):
                return html
            if attempt < self.max_attempts:
                self.sleep(self.backoff(attempt))
        return html  # still the check — the reader's refuse_js_check refuses it


@contextmanager
def playwright_render(
    *,
    user_agent: str = DEFAULT_USER_AGENT,
    nav_timeout_ms: int = 30000,
    settle_timeout_ms: int = 12000,
) -> Generator[RenderPage]:
    """A ``render`` bound to one headless Chromium, reused across every page
    fetched in the block. Each load waits for a table (the served pages all
    carry one) so the check's reload has time to complete; a persistent check
    is returned for :class:`GatedFetcher` to retry and the reader to refuse."""
    # playwright is installed only by the browser workflows (pzsz-sync /
    # pzsz-start-lists), not the base CI type-check/pytest job, so to the type
    # checker it is an optional import (cf. graphify in the test suite).
    from playwright import sync_api  # pyright: ignore[reportMissingImports]

    with sync_api.sync_playwright() as pw:
        browser = pw.chromium.launch()
        try:
            context = browser.new_context(user_agent=user_agent, locale="pl-PL")

            def render(full_url: str) -> str:
                page = context.new_page()
                try:
                    page.goto(full_url, wait_until="domcontentloaded", timeout=nav_timeout_ms)
                    try:
                        page.wait_for_selector("table", timeout=settle_timeout_ms)
                    except sync_api.TimeoutError:
                        pass  # gate may persist; GatedFetcher retries, reader refuses
                    return page.content()
                finally:
                    page.close()

            yield render
        finally:
            browser.close()


@contextmanager
def browser_fetch(
    *,
    max_attempts: int = 6,
    _render_factory: Callable[[], RenderPage] | None = None,
    **render_kwargs: object,
) -> Generator[Callable[[str, Mapping[str, object]], str]]:
    """The production entry point: a browser-backed ``fetch(url, params)``.
    Launches one Chromium for the block and reuses it. ``_render_factory`` is a
    test seam that supplies a fake ``render`` without a browser."""
    if _render_factory is not None:
        yield GatedFetcher(render=_render_factory(), max_attempts=max_attempts).fetch
        return
    with playwright_render(**render_kwargs) as render:  # type: ignore[arg-type]
        yield GatedFetcher(render=render, max_attempts=max_attempts).fetch
