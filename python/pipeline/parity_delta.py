"""
EVF parity delta renderer (ADR-060).

Builds a small .md from a list of ParityChange records produced by the daily
EVF parity sweep (evf_parity_sweep.py). The .md is uploaded to Storage at
staging-reports/{event_code}/deltas/{ts}.md and Telegrammed to the operator
(via TelegramNotifier.send_staging_report kind='delta').

Empty change list → returns None (no .md, no Telegram). Per ADR-060: silent
on no-op sweeps.

Plan-test-ID 5.8.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Literal


@dataclass
class ParityChange:
    """One row of EVF→DB drift correction.

    kind: 'fencer' (mutation on tbl_fencer) or 'result' (mutation on tbl_result).
    target_id / target_label: id + human-readable label of the affected row.
    field: column name being changed.
    before / after: stringified old / new value (use TEXT for legibility).
    fencer_label: optional, used in result-corrections rows to name the fencer.
    """

    kind: Literal["fencer", "result"]
    target_id: int
    target_label: str
    field: str
    before: str
    after: str
    fencer_label: str | None = None


def render(
    event_code: str,
    changes: list[ParityChange],
    *,
    timestamp_iso: str | None = None,
) -> bytes | None:
    """Render a delta .md from changes. Returns None on empty input."""
    if not changes:
        return None

    ts = timestamp_iso or datetime.now(timezone.utc).isoformat(timespec="seconds")

    lines: list[str] = []
    lines.append(f"# EVF parity delta — {event_code}")
    lines.append(f"_Sweep: {ts} · {len(changes)} changes applied_")
    lines.append("")

    fencer_changes = [c for c in changes if c.kind == "fencer"]
    result_changes = [c for c in changes if c.kind == "result"]

    if fencer_changes:
        lines.append("## Fencer corrections")
        lines.append("| Fencer | Field | Before | After |")
        lines.append("|---|---|---|---|")
        for c in fencer_changes:
            lines.append(
                f"| #{c.target_id} {c.target_label} | {c.field} | {c.before} | {c.after} |"
            )
        lines.append("")

    if result_changes:
        lines.append("## Result corrections")
        lines.append("| Tournament | Fencer | Field | Before | After |")
        lines.append("|---|---|---|---|---|")
        for c in result_changes:
            fencer = c.fencer_label or "?"
            lines.append(
                f"| {c.target_label} | {fencer} | {c.field} | {c.before} | {c.after} |"
            )
        lines.append("")

    lines.append(
        "_All changes auto-applied via the EVF parity sweep. "
        "Tournament scoring re-run for affected tournaments._"
    )

    return ("\n".join(lines) + "\n").encode("utf-8")
