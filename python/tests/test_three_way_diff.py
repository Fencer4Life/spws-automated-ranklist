"""
Tests for python/pipeline/three_way_diff.py — Phase 3 (ADR-050) 3-way diff.

Plan IDs P3.D1-P3.D12.

Bucket semantics (locked 2026-05-02 per project_cert_prod_not_baseline.md
— CERT/PROD share LOCAL's drift, so CERT is reference-only, not baseline):

  all-three-agree         Source = CERT = New LOCAL (could be all-correct
                          OR all-share-same-bug; visual scan only)
  new-corrects-cert       Source = New LOCAL ≠ CERT (new pipeline removed
                          a bug CERT had — desired output)
  source-changed-only     New LOCAL = CERT ≠ Source (upstream changed
                          after CERT was captured; new pipeline missed it)
  three-way-disagreement  All three differ (red alert)
"""

from __future__ import annotations

import pytest


# ---------------------------------------------------------------------------
# classify() — 4-bucket classifier
# ---------------------------------------------------------------------------

class TestClassify:
    def test_all_three_agree(self):
        """P3.D1 same fencer at same place across all three → all-three-agree."""
        from python.pipeline.three_way_diff import classify
        s = {"fencer_name": "KOWALSKI Jan", "place": 1, "id_fencer": 42}
        c = {"fencer_name": "KOWALSKI Jan", "place": 1, "id_fencer": 42}
        n = {"fencer_name": "KOWALSKI Jan", "place": 1, "id_fencer": 42}
        assert classify(s, c, n) == "all-three-agree"

    def test_new_corrects_cert(self):
        """P3.D2 Source = New LOCAL ≠ CERT → new-corrects-cert."""
        from python.pipeline.three_way_diff import classify
        s = {"fencer_name": "KOWALSKI Jan", "place": 1, "id_fencer": 42}
        c = {"fencer_name": "WRONG NAME", "place": 1, "id_fencer": 99}      # CERT had a bug
        n = {"fencer_name": "KOWALSKI Jan", "place": 1, "id_fencer": 42}    # new pipeline fixed it
        assert classify(s, c, n) == "new-corrects-cert"

    def test_source_changed_only(self):
        """P3.D3 New LOCAL = CERT ≠ Source → source-changed-only.

        Scenario: upstream now lists a *different fencer* at place 1
        (e.g., result was reassigned after a DSQ). New pipeline did the
        ingest before the upstream change and still has the old fencer,
        same as CERT. Equality is by id_fencer (not by cosmetic name spelling)
        so both 'fencer at this place' values must differ.
        """
        from python.pipeline.three_way_diff import classify
        s = {"fencer_name": "Person A", "place": 1, "id_fencer": 100}  # upstream changed
        c = {"fencer_name": "Person B", "place": 1, "id_fencer": 200}  # CERT (old)
        n = {"fencer_name": "Person B", "place": 1, "id_fencer": 200}  # new (also old)
        assert classify(s, c, n) == "source-changed-only"

    def test_three_way_disagreement(self):
        """P3.D4 all three differ → three-way-disagreement (red alert)."""
        from python.pipeline.three_way_diff import classify
        s = {"fencer_name": "Person A", "place": 1, "id_fencer": 1}
        c = {"fencer_name": "Person B", "place": 1, "id_fencer": 2}
        n = {"fencer_name": "Person C", "place": 1, "id_fencer": 3}
        assert classify(s, c, n) == "three-way-disagreement"

    def test_classify_uses_id_fencer_when_present(self):
        """P3.D5 id_fencer takes precedence over fencer_name for equality."""
        from python.pipeline.three_way_diff import classify
        # Same id_fencer, different name spelling → still equal
        s = {"fencer_name": "KOWALSKI Jan", "place": 1, "id_fencer": 42}
        c = {"fencer_name": "kowalski jan", "place": 1, "id_fencer": 42}
        n = {"fencer_name": "KOWALSKI J.",   "place": 1, "id_fencer": 42}
        assert classify(s, c, n) == "all-three-agree"

    def test_classify_falls_back_to_name_when_no_id(self):
        """P3.D6 falls back to case-insensitive fencer_name when id_fencer missing."""
        from python.pipeline.three_way_diff import classify
        s = {"fencer_name": "KOWALSKI Jan", "place": 1}  # no id_fencer
        c = {"fencer_name": "kowalski jan", "place": 1}
        n = {"fencer_name": "KOWALSKI JAN", "place": 1}
        assert classify(s, c, n) == "all-three-agree"


# ---------------------------------------------------------------------------
# build_diff() — assembles per-place rows from the three sources
# ---------------------------------------------------------------------------

class TestBuildDiff:
    def test_one_row_each_source(self):
        """P3.D7 with one row in each source at place 1 → one DiffRow."""
        from python.pipeline.three_way_diff import build_diff

        source_rows = [{"fencer_name": "X", "place": 1, "id_fencer": 1}]
        cert_rows   = [{"fencer_name": "X", "place": 1, "id_fencer": 1}]
        draft_rows  = [{"fencer_name": "X", "place": 1, "id_fencer": 1}]

        diff = build_diff(source_rows, cert_rows, draft_rows)
        assert len(diff) == 1
        assert diff[0].place == 1
        assert diff[0].bucket == "all-three-agree"

    def test_missing_in_cert_treated_as_new_corrects(self):
        """P3.D8 if CERT has no row at place 5 but Source + New LOCAL do → new-corrects-cert."""
        from python.pipeline.three_way_diff import build_diff

        source_rows = [{"fencer_name": "X", "place": 5, "id_fencer": 1}]
        cert_rows   = []                                                       # CERT missed it
        draft_rows  = [{"fencer_name": "X", "place": 5, "id_fencer": 1}]

        diff = build_diff(source_rows, cert_rows, draft_rows)
        assert len(diff) == 1
        assert diff[0].bucket == "new-corrects-cert"


# ---------------------------------------------------------------------------
# confidence_histogram() — matcher tuning aid
# ---------------------------------------------------------------------------

class TestConfidenceHistogram:
    def test_distributes_into_seven_bins(self):
        """P3.D9 confidence values bucketed into 7 ranges."""
        from python.pipeline.three_way_diff import confidence_histogram
        from python.pipeline.types import StageMatchResult

        matches = [
            StageMatchResult(scraped_name="a", place=1, id_fencer=1,
                             confidence=49.0, method="EXCLUDED"),
            StageMatchResult(scraped_name="b", place=2, id_fencer=2,
                             confidence=55.0, method="PENDING"),
            StageMatchResult(scraped_name="c", place=3, id_fencer=3,
                             confidence=72.0, method="PENDING"),
            StageMatchResult(scraped_name="d", place=4, id_fencer=4,
                             confidence=92.0, method="PENDING"),
            StageMatchResult(scraped_name="e", place=5, id_fencer=5,
                             confidence=99.0, method="AUTO_MATCHED"),
        ]
        h = confidence_histogram(matches)
        assert h["0-50"] == 1
        assert h["50-60"] == 1
        assert h["70-80"] == 1
        assert h["90-95"] == 1
        assert h["95-100"] == 1
        # Empty bins still present (so render is consistent)
        assert "60-70" in h
        assert "80-90" in h


# ---------------------------------------------------------------------------
# render_markdown()
# ---------------------------------------------------------------------------

class TestRenderMarkdown:
    def test_renders_event_code_and_buckets(self):
        """P3.D10 markdown contains event_code header + bucket summary table."""
        from python.pipeline.three_way_diff import (
            DiffRow, confidence_histogram, render_markdown,
        )

        rows = [
            DiffRow(place=1, source={}, cert={}, new_local={}, bucket="all-three-agree"),
            DiffRow(place=2, source={}, cert={}, new_local={}, bucket="new-corrects-cert"),
        ]
        md = render_markdown(
            event_code="PEW3-2025-2026",
            diff_rows=rows,
            histogram=confidence_histogram([]),
        )
        assert "PEW3-2025-2026" in md
        assert "all-three-agree" in md
        assert "new-corrects-cert" in md
        assert "match confidence" in md.lower() or "histogram" in md.lower()

    def test_renders_per_bucket_detail_sections(self):
        """P3.D11 each non-empty bucket rendered as its own section."""
        from python.pipeline.three_way_diff import (
            DiffRow, confidence_histogram, render_markdown,
        )

        rows = [
            DiffRow(place=1, source={"fencer_name": "S1"},
                    cert={"fencer_name": "C1"}, new_local={"fencer_name": "S1"},
                    bucket="new-corrects-cert"),
            DiffRow(place=2, source={"fencer_name": "X"},
                    cert={"fencer_name": "Y"}, new_local={"fencer_name": "Z"},
                    bucket="three-way-disagreement"),
        ]
        md = render_markdown(
            event_code="EVT", diff_rows=rows,
            histogram=confidence_histogram([]),
        )
        # Both bucket detail sections present
        assert md.count("new-corrects-cert") >= 2  # summary + section heading
        assert md.count("three-way-disagreement") >= 2


# ---------------------------------------------------------------------------
# write_diff() — file output
# ---------------------------------------------------------------------------

class TestWriteDiff:
    def test_writes_to_staging_dir(self, tmp_path):
        """P3.D12 write_diff creates doc/staging/<event_code>.diff.md."""
        from python.pipeline.three_way_diff import write_diff

        path = write_diff("PEW3-2025-2026", "# diff content", staging_dir=tmp_path)
        assert path.exists()
        assert path.name == "PEW3-2025-2026.diff.md"
        assert path.read_text() == "# diff content"
