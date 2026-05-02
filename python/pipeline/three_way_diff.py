"""
Phase 3 (ADR-050) 3-way diff — Source / CERT / New LOCAL.

The verification mechanism for the rebuild. For each event being re-ingested
in Phase 5, this module compares three views of the same event's results:

  Source     — what the upstream parser produces NOW (parsed IR)
  CERT       — what cert_ref schema records (frozen snapshot of CERT/PROD;
               note: CERT/PROD share LOCAL's drift per
               project_cert_prod_not_baseline.md — REFERENCE only, not baseline)
  New LOCAL  — what the new pipeline draft tables produce

Per-row classification (4 buckets):
  all-three-agree         — all three match (could be all-correct or all-share-bug)
  new-corrects-cert       — Source = New LOCAL ≠ CERT (new pipeline removed bug)
  source-changed-only     — New LOCAL = CERT ≠ Source (upstream changed; missed)
  three-way-disagreement  — all three differ (red alert)

Plus a confidence-distribution histogram for matcher tuning visibility.
Renders to markdown at doc/staging/<event_code>.diff.md.

Tests: python/tests/test_three_way_diff.py.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Row identity / equality
# ---------------------------------------------------------------------------

def _normalize_name(name: str | None) -> str:
    return (name or "").strip().lower()


def _row_key(row: dict | None) -> tuple[str, int] | None:
    """Stable key for a row: (id_fencer-or-name, place). Returns None if row is None."""
    if row is None:
        return None
    if "id_fencer" in row and row["id_fencer"] is not None:
        return (f"id:{row['id_fencer']}", row.get("place", 0))
    return (f"name:{_normalize_name(row.get('fencer_name'))}", row.get("place", 0))


def _rows_equal(a: dict | None, b: dict | None) -> bool:
    """Two rows are equal iff they have the same _row_key (id-preferred, name-fallback)."""
    return _row_key(a) == _row_key(b)


# ---------------------------------------------------------------------------
# Bucket classifier
# ---------------------------------------------------------------------------

def classify(source: dict | None, cert: dict | None, new_local: dict | None) -> str:
    """Return the 4-bucket label for a single (place) row across the three sources."""
    s_eq_c = _rows_equal(source, cert)
    s_eq_n = _rows_equal(source, new_local)
    c_eq_n = _rows_equal(cert, new_local)

    if s_eq_c and s_eq_n:
        return "all-three-agree"
    if s_eq_n and not s_eq_c:
        return "new-corrects-cert"
    if c_eq_n and not s_eq_c:
        return "source-changed-only"
    return "three-way-disagreement"


# ---------------------------------------------------------------------------
# DiffRow + builder
# ---------------------------------------------------------------------------

@dataclass
class DiffRow:
    """One row in the 3-way diff. place is the join key; sources are dicts or None."""
    place: int
    source: dict | None
    cert: dict | None
    new_local: dict | None
    bucket: str


def build_diff(
    source_rows: list[dict],
    cert_rows: list[dict],
    draft_rows: list[dict],
) -> list[DiffRow]:
    """Build the per-place diff joining the three sources by place."""
    by_place: dict[int, dict[str, Any]] = {}

    for r in source_rows:
        by_place.setdefault(r["place"], {})["source"] = r
    for r in cert_rows:
        by_place.setdefault(r["place"], {})["cert"] = r
    for r in draft_rows:
        by_place.setdefault(r["place"], {})["new_local"] = r

    out: list[DiffRow] = []
    for place in sorted(by_place.keys()):
        triple = by_place[place]
        s = triple.get("source")
        c = triple.get("cert")
        n = triple.get("new_local")
        out.append(DiffRow(
            place=place,
            source=s,
            cert=c,
            new_local=n,
            bucket=classify(s, c, n),
        ))
    return out


# ---------------------------------------------------------------------------
# Confidence histogram
# ---------------------------------------------------------------------------

# Bin edges. A confidence c falls into bin b iff b.lo ≤ c < b.hi.
_HIST_BINS = (
    ("0-50", 0.0, 50.0),
    ("50-60", 50.0, 60.0),
    ("60-70", 60.0, 70.0),
    ("70-80", 70.0, 80.0),
    ("80-90", 80.0, 90.0),
    ("90-95", 90.0, 95.0),
    ("95-100", 95.0, 100.001),  # inclusive of 100
)


def confidence_histogram(matches: list) -> dict[str, int]:
    """Bucket StageMatchResult.confidence values into 7 bins.

    Returns a dict with all bin keys present (zero count if empty), so the
    rendered histogram is consistent across events.
    """
    h: dict[str, int] = {name: 0 for name, _, _ in _HIST_BINS}
    for m in matches:
        c = m.confidence
        for name, lo, hi in _HIST_BINS:
            if lo <= c < hi:
                h[name] += 1
                break
    return h


# ---------------------------------------------------------------------------
# Markdown renderer
# ---------------------------------------------------------------------------

_BUCKET_ORDER = (
    "all-three-agree",
    "new-corrects-cert",
    "source-changed-only",
    "three-way-disagreement",
)


def _row_summary(row: dict | None) -> str:
    """One-line cell text for a row."""
    if row is None:
        return "_(missing)_"
    name = row.get("fencer_name", "?")
    fid = row.get("id_fencer")
    return f"{name} (id={fid})" if fid is not None else name


def render_markdown(
    event_code: str,
    diff_rows: list[DiffRow],
    histogram: dict[str, int],
    *,
    notes: list[str] | None = None,
) -> str:
    """Render the full markdown diff for one event."""
    lines: list[str] = [
        f"# 3-way diff — {event_code}",
        "",
        "Source = parsed IR (current upstream) · "
        "CERT = `cert_ref.tbl_*` (reference only, not baseline) · "
        "New LOCAL = draft tables (new pipeline output)",
        "",
    ]
    if notes:
        for n in notes:
            lines.append(f"> {n}")
        lines.append("")

    # Bucket summary
    lines.append("## Bucket summary")
    lines.append("")
    lines.append("| Bucket | Count |")
    lines.append("|---|---:|")
    counts = {b: 0 for b in _BUCKET_ORDER}
    for r in diff_rows:
        counts[r.bucket] = counts.get(r.bucket, 0) + 1
    for b in _BUCKET_ORDER:
        lines.append(f"| {b} | {counts.get(b, 0)} |")
    lines.append("")

    # Per-bucket detail (skip empty buckets, except agree bucket goes last)
    for b in _BUCKET_ORDER:
        rows = [r for r in diff_rows if r.bucket == b]
        if not rows:
            continue
        lines.append(f"## {b} ({len(rows)})")
        lines.append("")
        lines.append("| Place | Source | CERT | New LOCAL |")
        lines.append("|---:|---|---|---|")
        for r in rows:
            lines.append(
                f"| {r.place} "
                f"| {_row_summary(r.source)} "
                f"| {_row_summary(r.cert)} "
                f"| {_row_summary(r.new_local)} |"
            )
        lines.append("")

    # Match confidence histogram
    lines.append("## Match confidence distribution")
    lines.append("")
    lines.append("| Range | Count |")
    lines.append("|---|---:|")
    for name, _, _ in _HIST_BINS:
        lines.append(f"| {name} | {histogram.get(name, 0)} |")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def _project_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "pyproject.toml").exists():
            return parent
    return here.parent.parent.parent


def write_diff(event_code: str, content: str, staging_dir: Path | None = None) -> Path:
    """Write the markdown diff to <staging_dir>/<event_code>.diff.md.

    Default staging_dir: <project_root>/doc/staging/. Created if missing.
    """
    if staging_dir is None:
        staging_dir = _project_root() / "doc" / "staging"
    staging_dir = Path(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)
    path = staging_dir / f"{event_code}.diff.md"
    path.write_text(content)
    return path
