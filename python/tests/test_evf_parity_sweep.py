"""EVFCHK.01–07 — the daily EVF parity check reads EVF's results and writes nothing.

ADR-053 amendment of 2026-10-25 (P5 A on the W2 sign-off sheet). The sweep used to
fetch each event's url_event, the organiser's page, as EVF results, so it compared
nothing; and making it promote as designed would overwrite PROD scores outside
promote, against ADR-113 §8. It now reads EVF's results API, pairs each PROD event
with the EVF event that starts within three days of it, compares every PROD result
with EVF's N and points (compare_evf_points, EVF.PTS.01) and reports on Telegram.
These replace P4.SW.1–6, which pinned the promote, the annotations and the old fetch.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path
from types import SimpleNamespace

from python.pipeline.evf_parity_sweep import pair_evf_event, run_check
from python.tools.compare_evf_points import read_committed

MODULE = Path(__file__).resolve().parents[1] / "pipeline" / "evf_parity_sweep.py"

EVENT = {
    "id_event": 501,
    "txt_code": "PEW2efs-2026-2027",
    "dt_start": "2026-10-31",
    "dt_end": "2026-11-01",
}
OURS = [
    {"w": "EPEE", "g": "M", "v": "V2", "n": 12, "p": 3, "surname": "KOWALSKI", "pts": 50.0},
    {"w": "FOIL", "g": "F", "v": "V1", "n": 9, "p": 1, "surname": "ŻAK", "pts": 64.0},
]
EVF = [
    {"w": "EPEE", "g": "M", "v": "V2", "n": 12, "p": 3, "surname": "Kowalski", "pts": 50.0},
    {"w": "FOIL", "g": "F", "v": "V1", "n": 9, "p": 1, "surname": "Zak", "pts": 64.0},
    {"w": "FOIL", "g": "F", "v": "V1", "n": 9, "p": 2, "surname": "Muller", "pts": 55.0},
]


class _Db:
    """Read methods only: any write the check attempted would raise."""

    def __init__(self, events: list[dict], results: dict[str, list[dict]]):
        self._events = events
        self._results = results

    def evf_events_pending_parity(self, max_age_days: int) -> list[dict]:
        return self._events

    def evf_results_for_check(self, event_code: str) -> list[dict]:
        return self._results.get(event_code, [])


class _Notifier:
    def __init__(self) -> None:
        self.infos: list[str] = []
        self.warnings: list[str] = []

    def info(self, message: str) -> None:
        self.infos.append(message)

    def warning(self, message: str) -> None:
        self.warnings.append(message)


def _evf_event(
    evf_id: int, starts: str, has_results: bool = True, weapons: list[str] | None = None
) -> dict:
    return {
        "evf_id": evf_id,
        "date": starts,
        "has_results": has_results,
        "name": f"Event {evf_id}",
        "weapons": weapons or ["FOIL", "EPEE", "SABRE"],
    }


def _run(events, results, evf_events, evf_rows, *, today=date(2026, 11, 5), stop=30):
    notifier = _Notifier()
    reads: list[int] = []
    discovered: list[tuple[str, str]] = []

    def discover(start: str, end: str) -> list[dict]:
        discovered.append((start, end))
        return evf_events

    def read_evf(evf_id: int) -> list[dict]:
        reads.append(evf_id)
        rows = evf_rows[evf_id]
        if isinstance(rows, Exception):
            raise rows
        return rows

    counters = run_check(
        db=_Db(events, results),
        discover=discover,
        read_evf=read_evf,
        notifier=notifier,
        max_age_days=60,
        evf_empty_stop_days=stop,
        today=today,
    )
    return counters, notifier, reads, discovered


def test_EVFCHK_01_an_event_carrying_evfs_n_and_points_matches():
    counters, notifier, reads, _ = _run(
        [EVENT], {EVENT["txt_code"]: OURS}, [_evf_event(101, "2026-10-31")], {101: EVF}
    )
    assert (counters.checked, counters.matched, counters.differ) == (1, 1, 0)
    assert reads == [101]
    assert notifier.warnings == []
    assert "1 match EVF" in notifier.infos[-1]
    assert counters.errors == []


def test_EVFCHK_02_every_difference_is_named_and_nothing_is_written():
    evf = [dict(EVF[0], pts=48.0), EVF[2]]  # KOWALSKI's points differ; ŻAK not listed
    counters, notifier, _, _ = _run(
        [EVENT], {EVENT["txt_code"]: OURS}, [_evf_event(101, "2026-10-31")], {101: evf}
    )
    assert (counters.matched, counters.differ) == (0, 1)
    assert counters.errors == []  # _Db has no write method: a write would be an error
    [message] = notifier.warnings
    assert "PEW2efs-2026-2027" in message and "0 of 2" in message
    assert "KOWALSKI" in message and "48.0" in message
    assert "ŻAK" in message and "not in EVF's results" in message


def test_EVFCHK_03_nothing_to_compare_is_counted_not_read():
    later = dict(EVENT, id_event=502, txt_code="PEW3ef-2026-2027", dt_start="2026-11-14")
    later["dt_end"] = "2026-11-15"
    counters, notifier, reads, discovered = _run(
        [EVENT, later],
        {EVENT["txt_code"]: OURS},  # PEW3 has no results on PROD
        [_evf_event(101, "2026-10-31", has_results=False)],  # EVF has published nothing
        {},
        today=date(2026, 12, 2),  # 31 days after PEW2's end
    )
    assert (counters.no_results, counters.empty, counters.matched) == (1, 1, 0)
    assert reads == []
    assert len(discovered) == 1  # the season is listed once per run
    assert "PEW2efs-2026-2027" in notifier.infos[-1] and "30 days" in notifier.infos[-1]


def test_EVFCHK_04_the_evf_event_is_the_one_starting_within_three_days():
    assert pair_evf_event(date(2026, 10, 31), [_evf_event(101, "2026-11-03")]) == (101, None)
    assert pair_evf_event(date(2026, 10, 31), [_evf_event(101, "2026-11-04")]) == (None, None)
    evf_id, ambiguous = pair_evf_event(
        date(2026, 10, 31), [_evf_event(101, "2026-10-30"), _evf_event(102, "2026-11-01")]
    )
    assert evf_id is None and ambiguous == [101, 102]
    counters, notifier, reads, _ = _run(
        [EVENT],
        {EVENT["txt_code"]: OURS},
        [_evf_event(101, "2026-10-30"), _evf_event(102, "2026-11-01")],
        {},
    )
    assert counters.ambiguous == 1 and reads == []
    assert "101" in notifier.infos[-1] and "102" in notifier.infos[-1]


def test_EVFCHK_08_a_championship_evf_dates_by_its_last_day_pairs():
    """EVF dates the European Championships 2025 (Plovdiv, 28 May–1 Jun) by their
    last day, four days after our start; every result matched once paired (D1, P7 A)."""
    plovdiv = [_evf_event(67, "2025-06-01")]
    assert pair_evf_event(date(2025, 5, 28), plovdiv, our_end=date(2025, 6, 1)) == (67, None)
    assert pair_evf_event(
        date(2025, 5, 28), [_evf_event(67, "2025-06-05")], our_end=date(2025, 6, 1)
    ) == (
        None,
        None,
    )
    champs = dict(EVENT, txt_code="IMEW-2026-2027", dt_start="2026-10-27", dt_end="2026-10-31")
    counters, _, reads, discovered = _run(
        [champs], {"IMEW-2026-2027": OURS}, [_evf_event(101, "2026-10-31")], {101: EVF}
    )
    assert (counters.matched, counters.ambiguous) == (1, 0)
    assert reads == [101]
    assert discovered == [("2026-10-24", "2026-11-03")]  # through the last day + three


def test_EVFCHK_09_two_evf_events_on_one_day_pair_by_weapon():
    """6 Apr 2024: EVF held an épée event (62) and a sabre event (63); PEW13e and
    PEW14s each pair with the one in their weapon (D1, P7 A)."""
    epee, sabre = (
        _evf_event(62, "2024-04-06", weapons=["EPEE"]),
        _evf_event(63, "2024-04-06", weapons=["SABRE"]),
    )
    assert pair_evf_event(date(2024, 4, 6), [epee, sabre], weapons={"EPEE"}) == (62, None)
    assert pair_evf_event(date(2024, 4, 6), [epee, sabre], weapons={"SABRE"}) == (63, None)
    both = _evf_event(64, "2024-04-06", weapons=["EPEE", "SABRE"])
    assert pair_evf_event(date(2024, 4, 6), [epee, both], weapons={"EPEE"}) == (None, [62, 64])
    counters, _, reads, _ = _run(
        [EVENT],
        {EVENT["txt_code"]: OURS},  # épée and foil results
        [
            _evf_event(101, "2026-10-31", weapons=["SABRE"]),
            _evf_event(102, "2026-10-31", weapons=["EPEE", "FOIL"]),
        ],
        {102: EVF},
    )
    assert (counters.matched, counters.ambiguous) == (1, 0)
    assert reads == [102]


def test_EVFCHK_10_a_fencer_evf_lists_without_a_place_is_evfs_count_not_ours():
    """Dublin 2026: EVF lists RUSEV at place 9999, without a place, and counts him
    in N (12). N counts placed fencers only (11), so the points differ by EVF's count
    alone: named as such, not as a difference of ours (D1, P7 A)."""
    ours = [{"w": "EPEE", "g": "M", "v": "V1", "n": 11, "p": 3, "surname": "KORONA", "pts": 54.22}]
    evf = [
        {"w": "EPEE", "g": "M", "v": "V1", "n": 12, "p": 3, "surname": "Korona", "pts": 55.2047},
        {"w": "EPEE", "g": "M", "v": "V1", "n": 12, "p": 9999, "surname": "Rusev", "pts": 1},
    ] + [
        {"w": "EPEE", "g": "M", "v": "V1", "n": 12, "p": p, "surname": f"X{p}", "pts": 1}
        for p in (1, 2, 3, 5, 5, 7, 8, 9, 10, 11)
    ]
    counters, notifier, _, _ = _run(
        [EVENT], {EVENT["txt_code"]: ours}, [_evf_event(101, "2026-10-31")], {101: evf}
    )
    assert (counters.matched, counters.differ, counters.evf_unplaced) == (0, 0, 1)
    assert notifier.warnings == []
    summary = notifier.infos[-1]
    assert "1 differ only because EVF counts an unplaced fencer" in summary
    assert "PEW2efs-2026-2027" in summary and "Rusev" in summary

    # a real difference elsewhere in the event still warns, and names EVF's count too
    ours_more = ours + [
        {"w": "FOIL", "g": "F", "v": "V1", "n": 9, "p": 1, "surname": "ŻAK", "pts": 60.0}
    ]
    evf_more = evf + [
        {"w": "FOIL", "g": "F", "v": "V1", "n": 9, "p": 1, "surname": "Zak", "pts": 64.0}
    ]
    counters, notifier, _, _ = _run(
        [EVENT], {EVENT["txt_code"]: ours_more}, [_evf_event(101, "2026-10-31")], {101: evf_more}
    )
    assert (counters.differ, counters.evf_unplaced) == (1, 0)
    [message] = notifier.warnings
    assert "ŻAK" in message and "EVF counts an unplaced fencer" in message and "Rusev" in message
    assert "KORONA" not in message.split("EVF counts")[0]  # not listed as ours

    # our N short of EVF's placed fencers is still ours
    counters, notifier, _, _ = _run(
        [EVENT],
        {EVENT["txt_code"]: [dict(ours[0], n=10)]},
        [_evf_event(101, "2026-10-31")],
        {101: evf},
    )
    assert (counters.differ, counters.evf_unplaced) == (1, 0)
    assert "KORONA" in notifier.warnings[0]


def test_EVFCHK_05_a_failed_read_is_an_error_and_the_summary_still_goes():
    counters, notifier, _, _ = _run(
        [EVENT],
        {EVENT["txt_code"]: OURS},
        [_evf_event(101, "2026-10-31")],
        {101: RuntimeError("EVF API 503")},
    )
    assert counters.errors == ["PEW2efs-2026-2027: EVF API 503"]
    assert "1 could not be read" in notifier.infos[-1]


def test_EVFCHK_06_the_check_calls_no_writing_function():
    source = MODULE.read_text(encoding="utf-8")
    for writer in ("promote_evf_published", "annotate_parity_fail", "update_event_parity_notes"):
        assert writer not in source
    for call in (".rpc(", ".insert(", ".update(", ".upsert(", ".delete("):
        assert call not in source


class _Query:
    def __init__(self, rows: list[dict]):
        self._rows: object = rows

    def select(self, *_: object) -> _Query:
        return self

    def eq(self, *_: object) -> _Query:
        return self

    def in_(self, *_: object) -> _Query:
        return self

    def single(self) -> _Query:
        self._rows = self._rows[0]  # type: ignore[index]
        return self

    def execute(self) -> SimpleNamespace:
        return SimpleNamespace(data=self._rows)


class _Sb:
    def __init__(self, tables: dict[str, list[dict]]):
        self._tables = tables
        self.read: list[str] = []

    def table(self, name: str) -> _Query:
        self.read.append(name)
        return _Query(self._tables[name])


def test_EVFCHK_07_an_event_without_tournaments_has_no_results_to_compare():
    """Most EVF events the check selects have not been held yet; one without a
    tournament holds no result, and its results are not queried by an empty list."""
    sb = _Sb({"tbl_event": [{"id_event": 501}], "tbl_tournament": [], "tbl_result": []})
    assert read_committed(sb, "PEW2efs-2026-2027") == []
    assert "tbl_result" not in sb.read
