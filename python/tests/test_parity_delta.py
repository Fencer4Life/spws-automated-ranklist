"""
Plan-test-ID 5.8: parity_delta.py — render delta .md from EVF parity changes.

Pure renderer; no DB calls. Takes a list of ParityChange records and emits
a small .md showing only what changed.

ADR-060 — EVF parity emits delta-only .md (no full.md overwrite).
"""

from __future__ import annotations


def test_parity_delta_empty_returns_none():
    # 5.8.1 — empty change list → None (no .md emitted)
    from python.pipeline.parity_delta import render

    out = render(event_code="EVENT-A", changes=[])
    assert out is None


def test_parity_delta_single_by_correction():
    # 5.8.2 — one fencer BY correction renders one row
    from python.pipeline.parity_delta import ParityChange, render

    out = render(
        event_code="EVENT-A-2024-2025",
        changes=[
            ParityChange(
                kind="fencer",
                target_id=1042,
                target_label="STARK Tony",
                field="int_birth_year",
                before="1974",
                after="1975",
            ),
        ],
        timestamp_iso="2026-06-03T03:45:12+00:00",
    )
    assert out is not None
    md = out.decode("utf-8")
    assert "EVENT-A-2024-2025" in md
    assert "STARK Tony" in md
    assert "1974" in md and "1975" in md
    assert "Fencer corrections" in md
    # Only one section (no result corrections)
    assert "Result corrections" not in md


def test_parity_delta_mixed_sections():
    # 5.8.3 — mixed kinds → both sections present
    from python.pipeline.parity_delta import ParityChange, render

    out = render(
        event_code="EVENT-B",
        changes=[
            ParityChange(
                kind="fencer",
                target_id=1042,
                target_label="STARK Tony",
                field="int_birth_year",
                before="1974",
                after="1975",
            ),
            ParityChange(
                kind="result",
                target_id=412,
                target_label="t#412 / V2 / EPEE / M",
                field="int_place",
                before="7",
                after="5",
                fencer_label="#88 KOWAL Jan",
            ),
        ],
        timestamp_iso="2026-06-04T03:30:00+00:00",
    )
    assert out is not None
    md = out.decode("utf-8")
    assert "Fencer corrections" in md
    assert "Result corrections" in md
    assert "STARK Tony" in md
    assert "KOWAL Jan" in md


def test_parity_delta_includes_summary_count():
    # 5.8.4 — summary line includes count of changes
    from python.pipeline.parity_delta import ParityChange, render

    out = render(
        event_code="X",
        changes=[
            ParityChange(
                kind="fencer", target_id=1, target_label="A", field="f", before="x", after="y"
            ),
            ParityChange(
                kind="fencer", target_id=2, target_label="B", field="f", before="x", after="y"
            ),
            ParityChange(
                kind="fencer", target_id=3, target_label="C", field="f", before="x", after="y"
            ),
        ],
    )
    assert out is not None
    md = out.decode("utf-8")
    assert "3 changes" in md
