"""EVF.CAL.01 — every EVF event with results in a season has an event row.

doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html. The Paris
Criterium 2026 (EVF event 92, 5 July 2026) had results at EVF and no event row
anywhere: the season generator had no entry for it and the EVF calendar sync
never created it. The check compares what EVF scored with our international
events, one event row per EVF event, by date. The comparison is a pure
function; the tool around it only reads.
"""

from __future__ import annotations


def _evf(evf_id, day, *, results=True, name=None):
    return {"evf_id": evf_id, "name": name or f"EVF {evf_id}", "date": day, "has_results": results}


def _ours(code, start, end=None):
    return {"txt_code": code, "dt_start": start, "dt_end": end}


def test_EVF_CAL_01_an_evf_event_with_results_and_no_row_is_reported():
    from python.tools.evf_event_completeness import uncovered_evf_events

    evf = [_evf(91, "2026-05-30"), _evf(92, "2026-07-05", name="Criterium 2026")]
    ours = [_ours("IMEW-2025-2026", "2026-05-29", "2026-06-04")]

    assert [e["evf_id"] for e in uncovered_evf_events(evf, ours)] == [92]


def test_EVF_CAL_01_dates_within_two_days_of_the_event_cover_it():
    from python.tools.evf_event_completeness import uncovered_evf_events

    evf = [_evf(90, "2026-05-02"), _evf(88, "2026-04-20")]
    ours = [_ours("PEW8es-2025-2026", "2026-05-03"), _ours("PEW7ef-2025-2026", "2026-04-18")]

    assert uncovered_evf_events(evf, ours) == []


def test_EVF_CAL_01_an_evf_event_without_results_is_not_reported():
    from python.tools.evf_event_completeness import uncovered_evf_events

    assert uncovered_evf_events([_evf(83, "2026-05-17", results=False)], []) == []


def test_EVF_CAL_01_a_domestic_event_does_not_cover_an_evf_event():
    from python.tools.evf_event_completeness import uncovered_evf_events

    evf = [_evf(92, "2026-07-05")]
    ours = [_ours("PPW5-2025-2026", "2026-07-05"), _ours("MPW-2025-2026", "2026-07-04")]

    assert [e["evf_id"] for e in uncovered_evf_events(evf, ours)] == [92]


def test_EVF_CAL_01_one_row_covers_one_evf_event_of_the_same_weekend():
    from python.tools.evf_event_completeness import uncovered_evf_events

    evf = [_evf(77, "2025-05-03"), _evf(78, "2025-05-04")]
    ours = [_ours("PEW9fs-2024-2025", "2025-05-04")]

    assert [e["evf_id"] for e in uncovered_evf_events(evf, ours)] == [77]
