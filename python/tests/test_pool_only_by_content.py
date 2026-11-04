"""A pool-only round is known by the content of its results page, never by its
name (the user's rule of 4 Nov 2026; closing plan rev 5, G65 R2).

FencingTimeLive's results page of a listing lists the listing's rounds as
links: ``/pools/scores/{uuid}/{round}`` for a pool round and
``/tableaus/scores/{uuid}/{round}`` for a direct-elimination round. A page with
no tableau round has no DE bouts: it is a pools-only round and is never a
result. One check, ``ftl.has_direct_elimination``, serves both routes.

FTL.DE.01–05 the check; INTL.SCHED.06–07 the international reader.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "python/tests/fixtures/ftl"

TABLEAU = '<a href="/tableaus/scores/E1/9E42">Table of 32</a>'
POOLS = '<a href="/pools/scores/E1/BEFC">Pools</a>'
POOLS_2 = '<a href="/pools/scores/E1/2A3F">Pools, round 2</a>'


def _page(*rounds: str, tail: str = "") -> str:
    return f'<html><body><div class="roundNav">{"".join(rounds)}</div>{tail}</body></html>'


# ---------------------------------------------------------------------------
# FTL.DE — the check
# ---------------------------------------------------------------------------
def test_FTL_DE_01_a_page_with_a_tableau_round_has_a_direct_elimination():
    from python.scrapers.ftl import has_direct_elimination

    assert has_direct_elimination(_page(POOLS, TABLEAU)) is True


def test_FTL_DE_02_a_page_with_pool_rounds_only_has_none():
    from python.scrapers.ftl import has_direct_elimination

    assert has_direct_elimination(_page(POOLS)) is False
    assert has_direct_elimination(_page(POOLS, POOLS_2)) is False
    assert has_direct_elimination(_page()) is False


def test_FTL_DE_03_the_word_alone_is_not_a_round():
    """A page that only mentions a tableau in its text holds no DE round; the
    old word search would have taken it for one."""
    from python.scrapers.ftl import has_direct_elimination

    assert has_direct_elimination(_page(POOLS, tail="<p>No tableau was fenced.</p>")) is False


def test_FTL_DE_04_every_stored_real_page_holds_one():
    from python.scrapers.ftl import has_direct_elimination

    pages = sorted(FIXTURES.glob("results_*.html"))
    assert len(pages) >= 3
    for page in pages:
        assert has_direct_elimination(page.read_text(encoding="utf-8")) is True, page.name


class _Resp:
    def __init__(self, text: str = "", js=None):
        self.text = text
        self._js = js

    def raise_for_status(self) -> None:
        return None

    def json(self):
        return self._js


def test_FTL_DE_05_the_domestic_check_is_the_same_rule():
    """The domestic route's page check (ADR-067, ADR-076) reads the round
    links too: a page naming a tableau in its text without a tableau round is
    pools only."""
    from python.pipeline import ingest_cli

    class _Client:
        def __init__(self, html: str):
            self.html = html
            self.got: list[str] = []

        def get(self, url: str):
            self.got.append(url)
            return _Resp(self.html)

    plain = _Client(_page(POOLS, tail="<p>tableau</p>"))
    assert ingest_cli._ftl_has_direct_elimination(plain, "E1") is False
    assert plain.got == ["https://www.fencingtimelive.com/events/results/E1"]
    assert ingest_cli._ftl_has_direct_elimination(_Client(_page(POOLS, TABLEAU)), "E1") is True


# ---------------------------------------------------------------------------
# INTL.SCHED.06–07 — the international reader
# ---------------------------------------------------------------------------
SCHEDULE = (
    "https://www.fencingtimelive.com/tournaments/eventSchedule/ABCDEF0123456789ABCDEF0123456789"
)
LISTED = [
    {"uuid": "P1", "name": "Vet-50 Women's Epee", "finished": True, "day": "2026-03-07"},
    {"uuid": "E1", "name": "Vet-60 Women's Epee", "finished": True, "day": "2026-03-07"},
    {"uuid": "N1", "name": "Vet-70 Women's Epee", "finished": False, "day": "2026-03-07"},
]
PAGES = {"P1": _page(POOLS, POOLS_2), "E1": _page(POOLS, TABLEAU), "N1": _page(POOLS)}


def _rows(n: int) -> list[dict]:
    return [
        {"id": f"f{p}", "name": f"SURNAME{p} Jan", "place": str(p), "country": "POL"}
        for p in range(1, n + 1)
    ]


class _Client:
    """FTL as the reader sees it: the schedule, each listing's results page, its data."""

    def __init__(self):
        self.got: list[str] = []

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def get(self, url: str):
        self.got.append(url)
        if "eventSchedule" in url:
            return _Resp(text="<schedule/>")
        uuid = url.rsplit("/", 1)[-1]
        if "/events/results/data/" in url:
            return _Resp(js=_rows(8))
        return _Resp(text=PAGES[uuid])


def _read():
    from python.pipeline import international_sources as src

    client = _Client()
    with (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=client),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch(
            "python.tools.scrape_ftl_event_urls.parse_event_schedule",
            return_value=([dict(x) for x in LISTED], []),
        ),
    ):
        return src.read_brackets({"txt_code": "PEW9e-2026-2027"}, [SCHEDULE]), client


def test_INTL_SCHED_06_a_final_listing_without_a_de_round_is_a_pool_round():
    """Its page is read before its data; it is skipped with the reason, its
    data is never fetched, and the skip never holds the event open."""
    from python.pipeline.promotion import lifecycle

    (recs, _kept, skipped), client = _read()
    assert [r["uuid"] for r in recs] == ["E1"]
    pool = next(s for s in skipped if s["uuid"] == "P1")
    assert pool["reason"] == "pool round (no direct elimination round on its results page)"
    assert pool["name"] == "Vet-50 Women's Epee"
    assert pool["url"] == "https://www.fencingtimelive.com/events/results/P1"
    assert not lifecycle.is_not_final(pool["reason"])
    assert "https://www.fencingtimelive.com/events/results/data/P1" not in client.got


def test_INTL_SCHED_07_the_page_is_read_for_final_listings_only():
    """A listing the schedule shows unfinished stays "not final" without a
    request: its DE may simply not have started."""
    (_recs, _kept, skipped), client = _read()
    assert client.got == [
        SCHEDULE,
        "https://www.fencingtimelive.com/events/results/P1",
        "https://www.fencingtimelive.com/events/results/E1",
        "https://www.fencingtimelive.com/events/results/data/E1",
    ]
    not_final = next(s for s in skipped if s["uuid"] == "N1")
    assert not_final["reason"].startswith("not final")


@pytest.mark.parametrize("name", ["Szpada Kobiet V3, V4 - runda grupowa", "Vet-50 Women's Epee"])
def test_INTL_SCHED_06b_the_name_plays_no_part(name):
    """The same page, any name: the content decides."""
    from python.scrapers.ftl import has_direct_elimination

    assert name  # the name is not an input of the check
    assert has_direct_elimination(PAGES["P1"]) is False
    assert has_direct_elimination(PAGES["E1"]) is True
