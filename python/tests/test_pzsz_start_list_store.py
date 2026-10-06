"""PZSz start lists as stored inputs (ADR-112; RTM PZSZ.CAP.01–05).

A start list is captured on a day pzszerm.pl serves it and stored as printed
name and birth year, one insert-only row per version. `MemoryStore` keeps the
database's rule (fn_pzsz_start_list_store, pinned by pgTAP 109.3): a version is
appended only when it differs from the newest one for the same event, weapon
and gender. The pages are the saved fixtures, with synthetic people.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from python.pipeline.promotion.run_record import start_list_sha256
from python.scrapers import pzsz_start_list_store as store_mod
from python.scrapers.pzsz_start_list import PZSZ_EVENT_PAGE, PzszPageError, parse_start_list
from python.scrapers.pzsz_start_list_store import (
    SOURCE_PZSZERM,
    SOURCE_SAVED_PAGE,
    StoredStartListError,
    capture_event_start_lists,
    from_row,
    newest_by_series,
    store_saved_pages,
)

FIXTURES = Path(__file__).parent / "fixtures"
PAGES = {
    ("event", 4588): "pzsz_event_poznan_tournaments.html",
    ("tournament", 10628): "pzsz_start_list_sabre_men.html",
    ("tournament", 10629): "pzsz_start_list_sabre_women.html",
}


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def _fetch(pages: dict[tuple[str, int], str] | None = None):
    pages = pages or {k: _read(v) for k, v in PAGES.items()}

    def fetch(url: str, params: dict) -> str:
        kind = "event" if url == PZSZ_EVENT_PAGE else "tournament"
        return pages[(kind, params["id"])]

    return fetch


class MemoryStore:
    """tbl_pzsz_start_list with fn_pzsz_start_list_store's rule."""

    def __init__(self):
        self.rows: list[dict] = []

    def store(self, payload: dict) -> bool:
        series = [
            r
            for r in self.rows
            if (r["id_pzsz_event"], r["enum_weapon"], r["enum_gender"])
            == (payload["id_pzsz_event"], payload["enum_weapon"], payload["enum_gender"])
        ]
        if series and series[-1]["txt_sha256"] == payload["txt_sha256"]:
            return False
        row = json.loads(json.dumps(payload))
        row["id_pzsz_start_list"] = len(self.rows) + 1
        row["ts_captured"] = f"2026-10-0{len(self.rows) + 1}T06:00:00+00:00"
        self.rows.append(row)
        return True


class TestCapture:
    def test_a_new_version_is_stored(self):
        """PZSZ.CAP.01: both start lists of the event are stored, as printed
        name and birth year in page order, with the hash the run record uses."""
        store = MemoryStore()
        assert capture_event_start_lists(4588, _fetch(), store.store) == 2
        men = next(r for r in store.rows if r["enum_gender"] == "M")
        parsed = parse_start_list(_read(PAGES[("tournament", 10628)]))
        assert (men["id_pzsz_event"], men["id_pzsz_tournament"], men["enum_weapon"]) == (
            4588,
            10628,
            "SABRE",
        )
        assert men["jsonb_starters"] == [[s.name, s.birth_year] for s in parsed]
        assert men["txt_sha256"] == start_list_sha256(parsed)
        assert men["txt_source"] == SOURCE_PZSZERM

    def test_the_same_version_is_not_stored_twice(self):
        """PZSZ.CAP.02: a second capture of unchanged pages stores nothing."""
        store = MemoryStore()
        capture_event_start_lists(4588, _fetch(), store.store)
        assert capture_event_start_lists(4588, _fetch(), store.store) == 0
        assert len(store.rows) == 2

    def test_a_list_that_changes_back_ends_on_the_newest(self):
        """PZSZ.CAP.03: A, then B (a starter withdrew), then A again: three
        versions of the men's list, and the newest is A."""
        pages_a = {k: _read(v) for k, v in PAGES.items()}
        pages_b = dict(pages_a)
        first_starter = parse_start_list(pages_a[("tournament", 10628)])[0]
        pages_b[("tournament", 10628)] = _without_row(
            pages_a[("tournament", 10628)], first_starter.name
        )
        store = MemoryStore()
        for pages in (pages_a, pages_b, pages_a):
            capture_event_start_lists(4588, _fetch(pages), store.store)
        men = [r for r in store.rows if r["enum_gender"] == "M"]
        assert len(men) == 3
        newest = newest_by_series(store.rows)[("SABRE", "M")]
        assert newest.sha256 == start_list_sha256(parse_start_list(pages_a[("tournament", 10628)]))

    def test_a_gated_page_stores_nothing(self):
        """PZSZ.CAP.04: the JavaScript check on any page of the event stores
        nothing, not even the lists already read."""
        pages = {k: _read(v) for k, v in PAGES.items()}
        pages[("tournament", 10629)] = _read("pzsz_js_check.html")
        store = MemoryStore()
        with pytest.raises(PzszPageError, match="JavaScript check"):
            capture_event_start_lists(4588, _fetch(pages), store.store)
        assert store.rows == []


class TestSavedPages:
    def test_saved_pages_are_stored_as_saved_pages(self):
        """PZSZ.CAP.05: pages a person saved from their own browser go through
        the same parsers and are stored with source 'saved page'."""
        store = MemoryStore()
        stored = store_saved_pages(
            4588,
            _read(PAGES[("event", 4588)]),
            {
                10628: _read(PAGES[("tournament", 10628)]),
                10629: _read(PAGES[("tournament", 10629)]),
            },
            store.store,
        )
        assert stored == 2
        assert {r["txt_source"] for r in store.rows} == {SOURCE_SAVED_PAGE}

    def test_a_saved_gate_page_is_refused(self):
        """PZSZ.CAP.05: a saved copy of the JavaScript check is not a start list."""
        store = MemoryStore()
        with pytest.raises(PzszPageError, match="JavaScript check"):
            store_saved_pages(
                4588,
                _read(PAGES[("event", 4588)]),
                {10628: _read(PAGES[("tournament", 10628)]), 10629: _read("pzsz_js_check.html")},
                store.store,
            )
        assert store.rows == []

    def test_a_missing_tournament_page_is_refused(self):
        """PZSZ.CAP.05: every individual tournament of the event needs its page;
        the refusal names the one missing."""
        store = MemoryStore()
        with pytest.raises(PzszPageError, match="10629"):
            store_saved_pages(
                4588,
                _read(PAGES[("event", 4588)]),
                {10628: _read(PAGES[("tournament", 10628)])},
                store.store,
            )
        assert store.rows == []


class TestStoredForm:
    def test_a_row_whose_content_does_not_match_its_hash_is_refused(self):
        """PROMO.REPLAY.31 (the check promote relies on): a stored row is read
        back only when its starters still hash to its recorded hash."""
        store = MemoryStore()
        capture_event_start_lists(4588, _fetch(), store.store)
        row = dict(store.rows[0])
        assert from_row(row).sha256 == row["txt_sha256"]
        row["jsonb_starters"] = [*row["jsonb_starters"][:-1], ["Ktoś Inny", 1999]]
        with pytest.raises(StoredStartListError, match="hash"):
            from_row(row)

    def test_the_management_store_quotes_an_apostrophe(self):
        """PZSZ.CAP.01: a printed name with an apostrophe cannot break the
        statement the daily capture sends."""
        seen: list[str] = []

        def query(ref, token, sql):
            seen.append(sql)
            return [{"r": {"stored": True}}]

        stored = store_mod.ManagementStore("ref", "tok", query=query).store(
            {
                "id_pzsz_event": 4588,
                "id_pzsz_tournament": 10628,
                "enum_weapon": "SABRE",
                "enum_gender": "M",
                "txt_sha256": "a" * 64,
                "jsonb_starters": [["D'Artagnan Karol", 1970]],
                "txt_source": SOURCE_PZSZERM,
            }
        )
        assert stored is True
        assert "D''Artagnan Karol" in seen[0]
        assert seen[0].startswith("SELECT fn_pzsz_start_list_store(")


def _without_row(html: str, name: str) -> str:
    """The page with one start-list row removed."""
    from bs4 import BeautifulSoup

    soup = BeautifulSoup(html, "html.parser")
    for row in soup.find_all("tr"):
        cells = [" ".join(c.get_text(" ").split()) for c in row.find_all(["td", "th"])]
        if len(cells) > 1 and cells[1] == name:
            row.decompose()
            break
    return str(soup)
