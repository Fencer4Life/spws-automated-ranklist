"""EVF.PTS.01 — committed Polish results of an EVF event against EVF's own points.

EVF's results API (ADR-028) publishes each fencer's place, the category's
entry count and the points EVF awarded. An EVF event is scored by EVF's rules
(ADR-066 amendment, 2026-10-02), so every committed result must carry EVF's N
and EVF's points. The comparison is a pure function; the tool around it only
reads.
"""

from __future__ import annotations


def _ours(**kw):
    row = {"w": "FOIL", "g": "F", "v": "V1", "n": 4, "p": 3, "surname": "LIPKOWSKA", "pts": 15.93}
    row.update(kw)
    return row


def _evf(**kw):
    row = {"w": "FOIL", "g": "F", "v": "V1", "n": 4, "p": 3, "surname": "LIPKOWSKA", "pts": 15.9306}
    row.update(kw)
    return row


def test_EVF_PTS_01_equal_points_and_n_match():
    from python.tools.compare_evf_points import compare_with_evf

    out = compare_with_evf([_ours()], [_evf(), _evf(surname="SULLIVAN")])
    assert out == {"matched": 1, "mismatched": [], "missing": []}


def test_EVF_PTS_01_surname_matches_without_polish_letters():
    from python.tools.compare_evf_points import compare_with_evf

    out = compare_with_evf([_ours(surname="KOŃCZYŁO")], [_evf(surname="KONCZYLO")])
    assert out["matched"] == 1


def test_EVF_PTS_01_different_points_or_n_are_reported():
    from python.tools.compare_evf_points import compare_with_evf

    out = compare_with_evf(
        [_ours(pts=59.0), _ours(surname="OWCZAREK", n=1, p=1, pts=5.33)],
        [_evf(), _evf(surname="OWCZAREK", n=3, p=1, pts=5.33)],
    )
    assert out["matched"] == 0
    assert [m["surname"] for m in out["mismatched"]] == ["LIPKOWSKA", "OWCZAREK"]


def test_EVF_PTS_01_a_result_evf_does_not_list_is_missing():
    from python.tools.compare_evf_points import compare_with_evf

    out = compare_with_evf([_ours(surname="DROBCZYK")], [_evf()])
    assert out["missing"] == [_ours(surname="DROBCZYK")]
