"""
Layer 5 (combined-pool ingestion fix, 2026-04-30):
unit tests for python.tools.audit_vcat_violations.

Plan test IDs: 5.1–5.4. These pin the shape of the violator summary so the
Layer 6 replay loop consuming `--json --by-tournament` doesn't break when
the underlying view changes.
"""

from __future__ import annotations

from python.tools.audit_vcat_violations import (
    summarise_by_season,
    summarise_by_tournament,
    render_text,
)


_SAMPLE = [
    {
        "id_result": 1, "id_fencer": 100,
        "txt_surname": "KOWAL", "txt_first_name": "Anna",
        "int_birth_year": 1980,
        "tournament_code": "PPW3-V0-F-EPEE-2025-2026",
        "tournament_vcat": "V0", "expected_vcat": "V1",
        "season_end_year": 2026,
        "event_code": "PPW3-2025-2026",
        "season_code": "SPWS-2025-2026",
        "violation_msg": "fn_assert_result_vcat: KOWAL Anna (BY=1980) placed in V0 but expected V1 (tournament PPW3-V0-F-EPEE-2025-2026)",
    },
    {
        "id_result": 2, "id_fencer": 101,
        "txt_surname": "NOWAK", "txt_first_name": "Beata",
        "int_birth_year": 1976,
        "tournament_code": "PPW3-V0-F-EPEE-2025-2026",
        "tournament_vcat": "V0", "expected_vcat": "V2",
        "season_end_year": 2026,
        "event_code": "PPW3-2025-2026",
        "season_code": "SPWS-2025-2026",
        "violation_msg": "...",
    },
    {
        "id_result": 3, "id_fencer": 102,
        "txt_surname": "MŁYNEK", "txt_first_name": "Janusz",
        "int_birth_year": 1954,
        "tournament_code": "GP1-V0-M-EPEE-2023-2024",
        "tournament_vcat": "V0", "expected_vcat": "V4",
        "season_end_year": 2024,
        "event_code": "GP1-2023-2024",
        "season_code": "SPWS-2023-2024",
        "violation_msg": "...",
    },
]


class TestSummariseBySeason:
    """5.1 summarise_by_season counts violators per season_code."""

    def test_counts_by_season(self):
        result = summarise_by_season(_SAMPLE)
        assert result == {"SPWS-2025-2026": 2, "SPWS-2023-2024": 1}

    def test_empty_input(self):
        assert summarise_by_season([]) == {}


class TestSummariseByTournament:
    """5.2 summarise_by_tournament groups by tournament_code; collects the
    distinct expected_vcats per tournament. This is the exact shape the
    Layer 6 replay loop consumes — pin it so renames/restructures break loud."""

    def test_groups_by_tournament_with_distinct_expected_vcats(self):
        result = summarise_by_tournament(_SAMPLE)
        assert len(result) == 2

        # Tournaments are sorted by (season, event, tournament_code).
        gp1 = result[0]
        ppw3 = result[1]

        assert gp1["tournament_code"] == "GP1-V0-M-EPEE-2023-2024"
        assert gp1["count"] == 1
        assert gp1["expected_vcats"] == ["V4"]
        assert gp1["violators"][0]["fencer"] == "MŁYNEK Janusz"

        assert ppw3["tournament_code"] == "PPW3-V0-F-EPEE-2025-2026"
        assert ppw3["count"] == 2
        assert ppw3["expected_vcats"] == ["V1", "V2"]  # sorted
        names = sorted(v["fencer"] for v in ppw3["violators"])
        assert names == ["KOWAL Anna", "NOWAK Beata"]

    def test_empty_input(self):
        assert summarise_by_tournament([]) == []


class TestRenderText:
    """5.3 render_text returns a useful summary when there are violations,
    and an explicit empty-state when there are not."""

    def test_empty_input_explicit(self):
        out = render_text([], by_tournament=False)
        assert "No V-cat violations" in out

    def test_summary_lists_seasons(self):
        out = render_text(_SAMPLE, by_tournament=False)
        assert "V-cat violations: 3" in out
        assert "SPWS-2025-2026: 2 row(s)" in out
        assert "SPWS-2023-2024: 1 row(s)" in out

    def test_by_tournament_lists_each_group(self):
        out = render_text(_SAMPLE, by_tournament=True)
        assert "GP1-V0-M-EPEE-2023-2024" in out
        assert "PPW3-V0-F-EPEE-2025-2026" in out
        assert "expected=V1,V2" in out  # sorted vcats
