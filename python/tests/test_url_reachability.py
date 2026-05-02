"""
Tests for python/pipeline/url_reachability.py — Phase 5 follow-up.

Plan IDs P5.UR1-P5.UR9.

The validator runs BEFORE we save tournament drafts so a defective
url_results value never reaches tbl_tournament. Failure modes covered:
  * URL_FORMAT — /events/results/data/<UUID> is JSON, never browsable
  * REDIRECTED_TO_LOGIN — FTL serves HTTP 200 + login wall to anon requests
  * HTTP_ERROR — 404 / 5xx
  * UNREACHABLE — network exception
  * NO_RESULTS_INDICATOR — body has no <table id="resultList"> marker
"""

from __future__ import annotations

import pytest


VALID_FTL_RESULTS_HTML = """
<!doctype html><html><head>
<meta property="og:url" content="https://www.fencingtimelive.com/events/results/AAAA1111BBBB2222CCCC3333DDDD4444" />
<title>Fencing Time Live — Results</title></head><body>
<table id="resultList" class="table" data-url="/events/results/data/AAAA1111BBBB2222CCCC3333DDDD4444"></table>
</body></html>
"""

LOGIN_WALL_HTML = """
<!doctype html><html><head>
<meta property="og:url" content="https://www.fencingtimelive.com/account/login" />
<title>Fencing Time Live</title></head><body>Please log in.</body></html>
"""


# 5.UR1 — URL with /events/results/data/ is rejected without a fetch
def test_data_endpoint_rejected_format():
    from python.pipeline.url_reachability import check_results_url

    called = {"n": 0}

    def fake_fetch(url):
        called["n"] += 1
        return 200, VALID_FTL_RESULTS_HTML

    r = check_results_url(
        "https://www.fencingtimelive.com/events/results/data/AAAA1111BBBB2222CCCC3333DDDD4444",
        http_get=fake_fetch,
    )
    assert r.ok is False
    assert r.reason == "INVALID_FORMAT"
    assert called["n"] == 0  # We never even fetch — format check is cheap


# 5.UR2 — empty URL fails fast
def test_empty_url_rejected():
    from python.pipeline.url_reachability import check_results_url

    r = check_results_url("", http_get=lambda u: (200, ""))
    assert r.ok is False
    assert r.reason == "INVALID_FORMAT"


# 5.UR3 — valid FTL URL with results indicator → OK
def test_ftl_human_url_with_results_table_passes():
    from python.pipeline.url_reachability import check_results_url

    r = check_results_url(
        "https://www.fencingtimelive.com/events/results/AAAA1111BBBB2222CCCC3333DDDD4444",
        http_get=lambda u: (200, VALID_FTL_RESULTS_HTML),
    )
    assert r.ok is True
    assert r.reason == "OK"
    assert r.status_code == 200


# 5.UR4 — FTL login wall (200 OK + og:url=/account/login) → REDIRECTED_TO_LOGIN
def test_ftl_login_wall_detected():
    from python.pipeline.url_reachability import check_results_url

    r = check_results_url(
        "https://www.fencingtimelive.com/events/results/AAAA1111BBBB2222CCCC3333DDDD4444",
        http_get=lambda u: (200, LOGIN_WALL_HTML),
    )
    assert r.ok is False
    assert r.reason == "REDIRECTED_TO_LOGIN"
    assert "/account/login" in (r.evidence or "")


# 5.UR5 — 404 → HTTP_ERROR
def test_404_is_http_error():
    from python.pipeline.url_reachability import check_results_url

    r = check_results_url(
        "https://www.fencingtimelive.com/events/results/AAAA1111BBBB2222CCCC3333DDDD4444",
        http_get=lambda u: (404, ""),
    )
    assert r.ok is False
    assert r.reason == "HTTP_ERROR"
    assert r.status_code == 404


# 5.UR6 — 500 → HTTP_ERROR
def test_500_is_http_error():
    from python.pipeline.url_reachability import check_results_url

    r = check_results_url(
        "https://www.fencingtimelive.com/events/results/AAAA1111BBBB2222CCCC3333DDDD4444",
        http_get=lambda u: (500, ""),
    )
    assert r.ok is False
    assert r.reason == "HTTP_ERROR"
    assert r.status_code == 500


# 5.UR7 — network exception → UNREACHABLE
def test_network_exception_unreachable():
    from python.pipeline.url_reachability import check_results_url

    def boom(url):
        raise ConnectionError("DNS failed")

    r = check_results_url(
        "https://www.fencingtimelive.com/events/results/AAAA1111BBBB2222CCCC3333DDDD4444",
        http_get=boom,
    )
    assert r.ok is False
    assert r.reason == "UNREACHABLE"
    assert "DNS failed" in (r.evidence or "")


# 5.UR8 — FTL URL returning 200 but body lacks results-table → NO_RESULTS_INDICATOR
def test_ftl_url_no_results_indicator():
    from python.pipeline.url_reachability import check_results_url

    bare = (
        '<!doctype html><html><head>'
        '<meta property="og:url" content="https://www.fencingtimelive.com/events/results/X" />'
        '</head><body>nothing here</body></html>'
    )
    r = check_results_url(
        "https://www.fencingtimelive.com/events/results/AAAA1111BBBB2222CCCC3333DDDD4444",
        http_get=lambda u: (200, bare),
    )
    assert r.ok is False
    assert r.reason == "NO_RESULTS_INDICATOR"


# 5.UR9 — non-FTL host (engarde, etc.) — passes on 200 even without indicator,
# because we don't know each platform's results-page anatomy. Only HTTP status
# is enforced for non-FTL.
def test_non_ftl_url_passes_on_200():
    from python.pipeline.url_reachability import check_results_url

    r = check_results_url(
        "https://engarde-service.com/some/path",
        http_get=lambda u: (200, "<html>any body</html>"),
    )
    assert r.ok is True
    assert r.reason == "OK"


# 5.UR10 — URL-shape helpers
class TestURLShapeHelpers:
    def test_is_ftl_human_url_accepts_canonical_form(self):
        from python.pipeline.url_reachability import is_ftl_human_url

        assert is_ftl_human_url(
            "https://www.fencingtimelive.com/events/results/22488366AC2E4DA9A7A7828054EB230C"
        )
        assert is_ftl_human_url(
            "https://fencingtimelive.com/events/results/22488366AC2E4DA9A7A7828054EB230C"
        )

    def test_is_ftl_human_url_rejects_data_form(self):
        from python.pipeline.url_reachability import is_ftl_human_url

        assert not is_ftl_human_url(
            "https://www.fencingtimelive.com/events/results/data/22488366AC2E4DA9A7A7828054EB230C"
        )

    def test_is_ftl_data_url_detects_data_form(self):
        from python.pipeline.url_reachability import is_ftl_data_url

        assert is_ftl_data_url(
            "https://www.fencingtimelive.com/events/results/data/22488366AC2E4DA9A7A7828054EB230C"
        )
        assert not is_ftl_data_url(
            "https://www.fencingtimelive.com/events/results/22488366AC2E4DA9A7A7828054EB230C"
        )
