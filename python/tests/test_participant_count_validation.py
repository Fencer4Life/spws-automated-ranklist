"""Tests for python/pipeline/participant_count_validation.py — the post-commit
per-tournament participant-count URL validator (ADR-068).

After a commit, for every tournament we re-fetch its url_results, compute the
per-V-cat FTL membership (split by birth_year via vcat_for_age), and compare to
the stored int_participant_count. A per-V-cat mismatch is a HALT-severity
finding (the run fails, the event is flagged); a missing URL or a fetch error
is a WARN (never a silent pass).

This is the layer that catches contamination the pgTAP invariant cannot see
(where the stored result-row count is itself wrong).

Plan IDs C2.1–C2.6.
"""

from __future__ import annotations

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind

SEASON_END = 2026  # 2025-2026 season → V0 age<40 (BY>1986), V1 40-49 (BY 1977-1986)


def _res(name, place, birth_year):
    return ParsedResult(
        source_row_id=f"r:{name}", fencer_name=name, place=place, birth_year=birth_year
    )


def _parsed(results, url):
    return ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=results,
        source_url=url,
        season_end_year=SEASON_END,
    )


class _FakeFetcher:
    """fetch_url(url) -> ParsedTournament. Raises for urls in `errors`."""

    def __init__(self, by_url, errors=()):
        self._by_url = by_url
        self._errors = set(errors)
        self.calls = []

    def fetch_url(self, url):
        self.calls.append(url)
        if url in self._errors:
            raise RuntimeError("boom")
        return self._by_url[url]


def _tourn(code, vcat, url, stored):
    return {
        "txt_code": code,
        "enum_age_category": vcat,
        "url_results": url,
        "int_participant_count": stored,
    }


def _validate(tournaments, fetcher):
    from python.pipeline.participant_count_validation import (
        validate_event_participant_counts,
    )

    return validate_event_participant_counts(
        tournaments,
        fetcher,
        season_end_year=SEASON_END,
    )


# --- C2.1 — correct per-V-cat count passes -------------------------------------
def test_c2_1_match_no_halt():
    url = "https://ftl/A"
    fetcher = _FakeFetcher({url: _parsed([_res("Z", 1, 2000), _res("Y", 2, 1999)], url)})
    findings = _validate([_tourn("T-V0-M-EPEE", "V0", url, 2)], fetcher)
    assert [f for f in findings if f.severity == "halt"] == []


# --- C2.2 — joint-pool SUM inflation is flagged --------------------------------
def test_c2_2_sum_inflation_halts():
    # Shared FTL bracket: 2 V0-age + 1 V1-age. Stored as 3/3 (the bug).
    url = "https://ftl/joint"
    bracket = _parsed([_res("A", 1, 2000), _res("B", 2, 1999), _res("C", 3, 1980)], url)
    fetcher = _FakeFetcher({url: bracket})
    findings = _validate(
        [
            _tourn("T-V0-M-FOIL", "V0", url, 3),  # true V0 = 2
            _tourn("T-V1-M-FOIL", "V1", url, 3),  # true V1 = 1
        ],
        fetcher,
    )
    halts = {f.txt_code: f for f in findings if f.severity == "halt"}
    assert set(halts) == {"T-V0-M-FOIL", "T-V1-M-FOIL"}
    assert halts["T-V0-M-FOIL"].ftl_true == 2 and halts["T-V0-M-FOIL"].stored == 3
    assert halts["T-V1-M-FOIL"].ftl_true == 1 and halts["T-V1-M-FOIL"].stored == 3
    # shared URL fetched once
    assert fetcher.calls.count(url) == 1


# --- C2.2b — correct per-V-cat counts on a shared bracket pass ------------------
def test_c2_2b_per_vcat_correct_passes():
    url = "https://ftl/joint"
    bracket = _parsed([_res("A", 1, 2000), _res("B", 2, 1999), _res("C", 3, 1980)], url)
    fetcher = _FakeFetcher({url: bracket})
    findings = _validate(
        [
            _tourn("T-V0-M-FOIL", "V0", url, 2),
            _tourn("T-V1-M-FOIL", "V1", url, 1),
        ],
        fetcher,
    )
    assert [f for f in findings if f.severity == "halt"] == []


# --- C2.3 — result-row contamination is flagged --------------------------------
def test_c2_3_contamination_halts():
    # Own URL, real bracket has 6 V1 fencers, but stored=10 (contaminated).
    url = "https://ftl/V1F"
    six = [_res(f"F{i}", i, 1980) for i in range(1, 7)]
    fetcher = _FakeFetcher({url: _parsed(six, url)})
    findings = _validate([_tourn("PPW3-V1-F-EPEE", "V1", url, 10)], fetcher)
    halt = [f for f in findings if f.severity == "halt"]
    assert len(halt) == 1
    assert halt[0].ftl_true == 6 and halt[0].stored == 10


# --- C2.4 — missing URL is a WARN (skip), never a halt -------------------------
def test_c2_4_no_url_warns_not_halts():
    fetcher = _FakeFetcher({})
    findings = _validate([_tourn("T-V0-M-EPEE", "V0", None, 5)], fetcher)
    assert [f for f in findings if f.severity == "halt"] == []
    assert any(f.severity == "warn" and f.reason == "no_url" for f in findings)


# --- C2.5 — fetch error is a WARN, never a silent pass -------------------------
def test_c2_5_fetch_error_warns():
    url = "https://ftl/down"
    fetcher = _FakeFetcher({}, errors=[url])
    findings = _validate([_tourn("T-V0-M-EPEE", "V0", url, 5)], fetcher)
    assert [f for f in findings if f.severity == "halt"] == []
    assert any(f.severity == "warn" and f.reason == "fetch_error" for f in findings)


# --- C2.6 — has_halt helper convenience ----------------------------------------
def test_c2_6_has_halt_helper():
    from python.pipeline.participant_count_validation import has_halt

    url = "https://ftl/joint"
    bracket = _parsed([_res("A", 1, 2000), _res("B", 2, 1999), _res("C", 3, 1980)], url)
    fetcher = _FakeFetcher({url: bracket})
    bad = _validate([_tourn("T-V0", "V0", url, 3)], fetcher)
    good = _validate([_tourn("T-V0", "V0", url, 2)], fetcher)
    assert has_halt(bad) is True
    assert has_halt(good) is False
