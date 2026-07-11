"""CERT→PROD reconcile-run report — a human-readable .md log of one reconcile.

Mirrors the per-event scrape/staging log (`md_writer` → `doc/staging/` + the
CERT `staging-reports` bucket), but the subject is a whole reconcile RUN scoped
to a season, not a single event.

Design: **column-agnostic**. The reconciler snapshots each event as a projected
JSONB blob (whole row minus env-local noise, `id_organizer` resolved to a code)
before and after the reconcile, and this module diffs those blobs key-by-key.
So a URL, an entry fee, a registration checkbox — or a column added by a future
migration — appears automatically with zero change here. Only known-noise
columns are excluded; everything else is included by default.

Two diffs feed the report:
  * applied     = PROD-after vs PROD-before  → what this run actually wrote.
  * divergences = CERT vs PROD-after         → fields that still differ because
                  policy left them (admin-owned URLs kept, lifecycle-owned
                  status, or an UNMAPPED new column the reconciler doesn't sync).
"""

from __future__ import annotations

# Env-local / bookkeeping columns that must never read as a "change". Everything
# else (present and future) is diffed. Raw FK ids diverge across environments,
# so they are stripped at the SQL projection and resolved to codes there; listed
# here too as defence-in-depth in case a raw row is diffed directly.
NOISE_FIELDS = frozenset(
    {
        "id_event",
        "id_season",
        "id_organizer",
        "id_prior_event",
        "ts_created",
        "ts_updated",
    }
)


def compute_changes(before: dict[str, dict], after: dict[str, dict]) -> dict[str, list]:
    """Column-agnostic diff of two {txt_code: projected_row} maps.

    Returns ``{"created": [codes], "deleted": [codes], "updated":
    [{code, field, old, new}, ...]}`` — one ``updated`` entry per changed field.
    """
    before_codes = set(before)
    after_codes = set(after)
    created = sorted(after_codes - before_codes)
    deleted = sorted(before_codes - after_codes)

    updated: list[dict] = []
    for code in sorted(before_codes & after_codes):
        b = before[code]
        a = after[code]
        for field in sorted(set(b) | set(a)):
            if field in NOISE_FIELDS:
                continue
            old = b.get(field)
            new = a.get(field)
            if old != new:
                updated.append({"code": code, "field": field, "old": old, "new": new})

    return {"created": created, "deleted": deleted, "updated": updated}


def _cell(value) -> str:
    """Render a JSONB value for a markdown table cell."""
    if value is None or value == "":
        return "(blank)"
    if isinstance(value, list):
        return ", ".join(str(v) for v in value) if value else "(blank)"
    text = str(value).replace("|", "\\|").replace("\n", " ")
    return text if text else "(blank)"


def _created_summary(row: dict) -> str:
    """One-line summary of a newly-created event for the Changes table."""
    parts = []
    for k in ("txt_name", "dt_start", "dt_end", "txt_location", "organizer_code"):
        v = row.get(k)
        if v:
            parts.append(str(v))
    return " · ".join(parts) if parts else "(new event)"


def render_report(
    *,
    season: str,
    timestamp: str,
    cert_ref: str,
    prod_ref: str,
    trigger: str,
    season_guard_ok: bool,
    applied: dict[str, list],
    deleted_evidence: dict[str, str],
    divergences: dict[str, list],
    rpc: dict,
    prod_count: int,
    cert_count: int,
    created_rows: dict[str, dict] | None = None,
) -> str:
    """Render the reconcile-run report as markdown.

    ``applied`` / ``divergences`` are :func:`compute_changes` outputs.
    ``deleted_evidence`` maps a deleted code → the guard evidence string
    (e.g. ``"PLANNED, 0 results"``). ``created_rows`` maps a created code →
    its projected row (for the one-line summary).
    """
    created_rows = created_rows or {}
    lines: list[str] = []
    a = f"# CERT → PROD reconcile — {season}"
    lines.append(a)
    guard = "✓ same season" if season_guard_ok else "✗ SEASON MISMATCH"
    lines.append("")
    lines.append(f"- **Run:** `{timestamp}`  ·  trigger: {trigger}")
    lines.append(f"- **CERT:** `{cert_ref}`  →  **PROD:** `{prod_ref}`")
    lines.append(f"- **Season guard:** {guard}  (CERT `{season}` vs PROD active)")

    total_changes = len(applied["created"]) + len(applied["deleted"]) + len(applied["updated"])
    skipped = rpc.get("delete_skipped") or []

    # ---- Changes applied this run (PROD before → after) ----
    lines.append("")
    lines.append("## Changes applied")
    if total_changes == 0:
        lines.append("")
        lines.append("_No changes — PROD already matched CERT for this season._")
    else:
        lines.append("")
        lines.append("| Event | Field | Old | New |")
        lines.append("|---|---|---|---|")
        for code in applied["created"]:
            lines.append(
                f"| `{code}` | (created) | — | {_cell(_created_summary(created_rows.get(code, {})))} |"
            )
        for code in applied["deleted"]:
            evidence = deleted_evidence.get(code, "removed")
            lines.append(f"| `{code}` | (deleted) | {evidence} | — |")
        for u in applied["updated"]:
            lines.append(
                f"| `{u['code']}` | `{u['field']}` | {_cell(u['old'])} | {_cell(u['new'])} |"
            )

    # ---- Delete-skipped (results-bearing, guard refused) ----
    if skipped:
        lines.append("")
        lines.append("## ⚠ Delete SKIPPED — needs attention")
        lines.append("")
        lines.append(
            "These events are on PROD but absent from CERT, and the guard refused "
            "to delete them because they carry results. Investigate — never "
            "auto-erased."
        )
        lines.append("")
        lines.append("| PROD id_event |")
        lines.append("|---|")
        for x in skipped:
            lines.append(f"| `{x}` |")

    # ---- Divergences not synced (CERT vs PROD-after) ----
    div_total = (
        len(divergences["created"]) + len(divergences["deleted"]) + len(divergences["updated"])
    )
    lines.append("")
    lines.append("## Divergences NOT synced")
    lines.append("")
    lines.append(
        "_Fields where CERT and PROD still differ because policy left them "
        "(admin-owned URLs/fees kept on PROD, lifecycle-owned status, or an "
        "UNMAPPED new column the reconciler does not sync yet)._"
    )
    if div_total == 0:
        lines.append("")
        lines.append("_None — CERT and PROD are fully aligned for synced fields._")
    else:
        lines.append("")
        lines.append("| Event | Field | CERT | PROD |")
        lines.append("|---|---|---|---|")
        for code in divergences["created"]:
            lines.append(f"| `{code}` | (on CERT only) | present | — |")
        for code in divergences["deleted"]:
            lines.append(f"| `{code}` | (on PROD only) | — | present |")
        for u in divergences["updated"]:
            lines.append(
                f"| `{u['code']}` | `{u['field']}` | {_cell(u['new'])} | {_cell(u['old'])} |"
            )

    # ---- Summary ----
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|---|---|")
    lines.append(
        "| RPC | created {created}, updated {updated}, deleted {deleted}, "
        "delete_skipped {n_skip} |".format(
            created=rpc.get("created", 0),
            updated=rpc.get("updated", 0),
            deleted=rpc.get("deleted", 0),
            n_skip=len(skipped),
        )
    )
    converged = "✓" if (prod_count == cert_count and not skipped) else "⚠"
    lines.append(f"| Converged | PROD {prod_count} == CERT {cert_count} {converged} |")

    lines.append("")
    return "\n".join(lines) + "\n"
