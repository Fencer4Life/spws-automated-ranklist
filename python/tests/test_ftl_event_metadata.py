"""Tests for fetch_ftl_event_metadata URL-form handling (ADR-039 rev 2).

Plan test IDs:
  evf.50  fetch_ftl_event_metadata extracts the date from a
          /tournaments/eventSchedule/{uuid} URL (the EVENT URL), not only the
          /events/results/{uuid} form. The self-heal sources dates from the
          event URL, so this form must work.
"""

from __future__ import annotations


class _FakeResp:
    def __init__(self, text, status_code=200):
        self.text = text
        self.status_code = status_code


class _FakeClient:
    """Records the URL it was asked to GET and returns canned HTML."""

    def __init__(self, html):
        self._html = html
        self.requested_url = None

    def get(self, url):
        self.requested_url = url
        return _FakeResp(self._html)


# Mirrors the real FTL eventSchedule page for the Guildford event.
_SCHEDULE_HTML = (
    "<html><head><title>BVF 6 Weapon International 2026</title></head>"
    "<body>January 10, 2026 - January 11, 2026</body></html>"
)


def test_evf50_event_schedule_url_yields_date():
    """evf.50: an eventSchedule event URL is fetched as-is and its date parsed."""
    from python.scrapers.ftl import fetch_ftl_event_metadata

    url = ("https://www.fencingtimelive.com/tournaments/eventSchedule/"
           "E2A7B077F2824DD8A7F2E413B4211296")
    client = _FakeClient(_SCHEDULE_HTML)
    meta = fetch_ftl_event_metadata(url, client)

    assert meta is not None, "eventSchedule URL must yield metadata"
    assert meta["date"] == "2026-01-10", "earliest date on the page"
    # The function must fetch the eventSchedule path, NOT rewrite it to
    # /events/results/ (which would 302 to the login wall for this UUID).
    assert "/tournaments/eventSchedule/" in client.requested_url


def test_evf50_results_url_still_works():
    """evf.50 (regression): the original /events/results/ form still parses."""
    from python.scrapers.ftl import fetch_ftl_event_metadata

    url = ("https://www.fencingtimelive.com/events/results/"
           "220C587A8C854C6C85EB62D26D62F6C9")
    client = _FakeClient(
        "<html><head><title>Men's Epee Category 4</title></head>"
        "<body>January 10, 2026</body></html>"
    )
    meta = fetch_ftl_event_metadata(url, client)
    assert meta is not None
    assert meta["date"] == "2026-01-10"
    assert "/events/results/" in client.requested_url
