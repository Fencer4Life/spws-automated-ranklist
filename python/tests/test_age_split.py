"""
Layer 3 (combined-pool ingestion fix, 2026-04-29):
unit coverage for python.pipeline.age_split.

Two surfaces:
  1. birth_year_to_vcat — pure helper with V-cat boundary cases.
  2. split_combined_results — exercised on FTL-shaped rows (no DOB on the
     row, only name + place + country). This is the exact shape that
     produced the 162-group corruption: when the splitter was missing,
     the FTL rows fell straight into a single tournament regardless of
     V-cat. With the splitter in place + a fencer DB lookup, FTL data
     splits correctly.

Plan test IDs: 9.310 (helper), 9.311 (FTL-shape splitter).
"""

from python.pipeline.age_split import (
    birth_year_to_vcat,
    split_combined_results,
)


class TestBirthYearToVcat:
    """9.310 birth_year_to_vcat returns the right V-cat for each boundary."""

    def test_v0_lower_bound(self):
        # age 30 → V0 (lowest age in V0 range)
        assert birth_year_to_vcat(1996, 2026) == "V0"

    def test_v0_upper_bound(self):
        # age 39 → V0
        assert birth_year_to_vcat(1987, 2026) == "V0"

    def test_v1_lower_bound(self):
        # age 40 → V1
        assert birth_year_to_vcat(1986, 2026) == "V1"

    def test_v2_lower_bound(self):
        # age 50 → V2
        assert birth_year_to_vcat(1976, 2026) == "V2"

    def test_v3_lower_bound(self):
        # age 60 → V3
        assert birth_year_to_vcat(1966, 2026) == "V3"

    def test_v4_lower_bound(self):
        # age 70 → V4
        assert birth_year_to_vcat(1956, 2026) == "V4"

    def test_v4_extreme(self):
        # age 116 → V4 (no upper bound)
        assert birth_year_to_vcat(1910, 2026) == "V4"

    def test_under_30_returns_none(self):
        # age 25 → not a veteran, returns None
        assert birth_year_to_vcat(2001, 2026) is None

    def test_null_birth_year_returns_none(self):
        assert birth_year_to_vcat(None, 2026) is None

    def test_season_end_year_matters(self):
        # Same BY in two different seasons — different V-cat.
        assert birth_year_to_vcat(1976, 2025) == "V1"  # age 49
        assert birth_year_to_vcat(1976, 2026) == "V2"  # age 50


class TestSplitOnFtlShapedRows:
    """9.311 splitter handles FTL-shaped rows (no DOB on row).

    FTL JSON / Engarde HTML / 4Fence / Dartagnan all give us name + place
    only. BY must come from the master fencer DB. This was the missing
    piece in every non-XML path — the splitter is the fix.
    """

    def test_splits_combined_v0v1_by_db_lookup(self):
        # Combined V0+V1 women's epee pool; admin pasted the URL onto two
        # tournament rows (V0 + V1). Pre-fix: every fencer placed in both
        # tournaments. Post-fix: splitter slices by BY.
        ftl_rows = [
            {"fencer_name": "KOWAL Anna",     "place": 1, "country": "POL"},
            {"fencer_name": "NOWAK Beata",    "place": 2, "country": "POL"},
            {"fencer_name": "KOWALSKA Cyryla", "place": 3, "country": "POL"},
            {"fencer_name": "MAZUR Dorota",   "place": 4, "country": "POL"},
        ]
        fencer_db = [
            {"txt_surname": "KOWAL", "txt_first_name": "Anna",
             "int_birth_year": 1990},  # V0
            {"txt_surname": "NOWAK", "txt_first_name": "Beata",
             "int_birth_year": 1980},  # V1
            {"txt_surname": "KOWALSKA", "txt_first_name": "Cyryla",
             "int_birth_year": 1992},  # V0
            {"txt_surname": "MAZUR", "txt_first_name": "Dorota",
             "int_birth_year": 1978},  # V1
        ]

        split = split_combined_results(
            ftl_rows,
            categories=["V0", "V1"],
            fencer_db=fencer_db,
            season_end_year=2026,
        )

        v0_names = [r["fencer_name"] for r in split.buckets["V0"]]
        v1_names = [r["fencer_name"] for r in split.buckets["V1"]]
        assert v0_names == ["KOWAL Anna", "KOWALSKA Cyryla"]
        assert v1_names == ["NOWAK Beata", "MAZUR Dorota"]
        # Re-ranked 1..N within each bucket
        assert [r["place"] for r in split.buckets["V0"]] == [1, 2]
        assert [r["place"] for r in split.buckets["V1"]] == [1, 2]
        # Everyone resolved
        assert split.unresolved == []

    def test_unresolved_falls_into_lowest_cat(self):
        # FTL row whose name doesn't appear in fencer_db → assigned to
        # the lowest category as a placeholder, AND added to unresolved
        # so admin can review (ADR-024).
        ftl_rows = [
            {"fencer_name": "GHOST Unknown", "place": 1, "country": "POL"},
        ]
        split = split_combined_results(
            ftl_rows,
            categories=["V1", "V2"],
            fencer_db=[],
            season_end_year=2026,
        )
        assert [r["fencer_name"] for r in split.buckets["V1"]] == ["GHOST Unknown"]
        assert split.buckets["V2"] == []
        assert [r["fencer_name"] for r in split.unresolved] == ["GHOST Unknown"]

    def test_dob_on_row_overrides_db(self):
        # When the source provides DOB on the row (e.g. EVF API), use it
        # in preference to the DB lookup.
        ftl_rows = [
            {"fencer_name": "KOWAL Anna", "place": 1, "country": "POL",
             "birth_date": "1990-05-12"},  # V0
        ]
        fencer_db = [
            {"txt_surname": "KOWAL", "txt_first_name": "Anna",
             "int_birth_year": 1980},  # would be V1 — but DOB on row wins
        ]
        split = split_combined_results(
            ftl_rows,
            categories=["V0", "V1"],
            fencer_db=fencer_db,
            season_end_year=2026,
        )
        assert [r["fencer_name"] for r in split.buckets["V0"]] == ["KOWAL Anna"]
        assert split.buckets["V1"] == []
