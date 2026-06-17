"""StagingFormatter — the terminal shaper of the staging report (ADR-075).

Option B: every plugin serializes its own contribution to the `report` channel as
it runs (see `Context.add_report` / `BasePlugin.report`); this ONE plugin shapes the
accumulated fragments into the per-event human-review files at the end:

  - `doc/staging/<EVENT>.<ts>.md`       — the full ingestion summary, rendered from
    `STAGING_TEMPLATE` (an ordered section spec — the "template"; no Jinja dep in repo).
  - `doc/staging/<EVENT>.<ts>.diff.md`  — the 3-way diff (Source / CERT / New LOCAL) +
    confidence histogram, reusing `three_way_diff` verbatim.

It is the ONLY plugin that touches the filesystem. It is informational/post-commit
(ADR-074: no drafts, no blocking gate) and runs at EVENT scope — fired once by the
CLI after the bracket loop with `_bracket_reports` seeded (the per-bracket POST_COMMIT
the reactor fires has no `_bracket_reports`, so `applies` returns False there).

The timestamp stem (one per run, shared by both files) lets the operator keep and
compare reruns of the same event.
"""
from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

from python.pipeline.core.contract import Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin


# ---------------------------------------------------------------------------
# Section ids — the report-fragment vocabulary plugins emit into (ADR-075).
# ---------------------------------------------------------------------------

class Section:
    SOURCE = "SOURCE"
    EVENT = "EVENT"
    IDENTITY = "IDENTITY"
    STRUCTURE = "STRUCTURE"
    VALIDATION = "VALIDATION"
    COMMIT = "COMMIT"
    REACTION = "REACTION"


def _utc_stamp() -> str:
    """Sortable, colon-free UTC stamp: YYYYMMDD-HHMMSSZ (lexical == chronological)."""
    return datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")


def _group(frags) -> dict[str, list]:
    out: dict[str, list] = {}
    for f in frags:
        out.setdefault(f.section, []).append(f)
    return out


def _all_matches(grouped) -> list[dict]:
    return [m for f in grouped.get(Section.IDENTITY, []) for m in f.payload.get("matches", [])]


# ---------------------------------------------------------------------------
# Section renderers — each shapes one slice of the merged fragments.
# Signature: renderer(grouped, event_code) -> markdown body (str).
# ---------------------------------------------------------------------------

def _render_header(g, event_code) -> str:
    ev = g.get(Section.EVENT, [])
    p = ev[0].payload if ev else {}
    lines = [
        "| Field | Value |", "|---|---|",
        f"| Code | {p.get('txt_code', event_code)} |",
        f"| Name | {p.get('txt_name', '_n/a_')} |",
        f"| id_event | {p.get('id_event', '_n/a_')} |",
        f"| Start | {p.get('dt_start', '_n/a_')} |",
        "",
        "### Source brackets ingested", "",
        "| Weapon | Gender | Category | Rows |", "|---|---|---|---:|",
    ]
    for f in g.get(Section.SOURCE, []):
        s = f.payload
        lines.append(f"| {s.get('weapon', '?')} | {s.get('gender', '?')} "
                     f"| {s.get('category_hint', '?')} | {s.get('n_rows', 0)} |")
    return "\n".join(lines)


def _render_created(g, event_code) -> str:
    created = [c for f in g.get(Section.IDENTITY, []) for c in f.payload.get("created", [])]
    if not created:
        return "_No new fencers created._"
    lines = ["| Name | id_fencer | V-cat | Birth year | Estimated |",
             "|---|---:|---|---:|---|"]
    for c in created:
        lines.append(f"| {c.get('scraped_name', '?')} | {c.get('id_fencer', '?')} "
                     f"| {c.get('vcat', '?')} | {c.get('birth_year', '_null_')} "
                     f"| {'yes' if c.get('estimated') else 'no'} |")
    return "\n".join(lines)


def _render_reconciled(g, event_code) -> str:
    rec = [r for f in g.get(Section.IDENTITY, []) for r in f.payload.get("reconciled", [])]
    conf = [c for f in g.get(Section.IDENTITY, []) for c in f.payload.get("conflicts", [])]
    if not rec and not conf:
        return "_No birth-year reconciliations._"
    lines: list[str] = []
    if rec:
        lines += ["| Name | id_fencer | V-cat | Old BY | New BY | Was confirmed |",
                  "|---|---:|---|---:|---:|---|"]
        for r in rec:
            lines.append(f"| {r.get('scraped_name', '?')} | {r.get('id_fencer', '?')} "
                         f"| {r.get('vcat', '?')} | {r.get('old_birth_year', '_null_')} "
                         f"| {r.get('new_birth_year', '?')} "
                         f"| {'yes' if r.get('was_confirmed') else 'no'} |")
    if conf:
        lines += ["", "**Unresolved conflicts (same fencer, two V-cats):**"]
        for c in conf:
            lines.append(f"- {c.get('scraped_name', '?')} (id={c.get('id_fencer', '?')}): "
                         f"{c.get('first_vcat')} vs {c.get('second_vcat')}")
    return "\n".join(lines)


def _render_matches(g, event_code) -> str:
    matches = _all_matches(g)
    if not matches:
        return "_No matches._"
    by_method: dict[str, int] = {}
    for m in matches:
        by_method[m.get("method", "?")] = by_method.get(m.get("method", "?"), 0) + 1
    lines = ["| Method | Count |", "|---|---:|"]
    for method in sorted(by_method):
        lines.append(f"| {method} | {by_method[method]} |")
    lines.append(f"| **Total** | **{len(matches)}** |")
    return "\n".join(lines)


def _render_estimated_by(g, event_code) -> str:
    matches = _all_matches(g)
    null_by = [m for m in matches if m.get("governed_birth_year") is None]
    if not null_by:
        return "_All resolved fencers have a governed birth year._"
    lines = [f"{len(null_by)} fencer(s) with NULL/unresolved governed birth year:", ""]
    for m in null_by:
        lines.append(f"- {m.get('scraped_name', '?')} "
                     f"(id={m.get('id_fencer')}, method={m.get('method')})")
    return "\n".join(lines)


def _render_committed(g, event_code) -> str:
    rows = []
    skipped_any = False
    for f in g.get(Section.COMMIT, []):
        p = f.payload
        if p.get("skipped"):
            skipped_any = True
        rows += p.get("tournaments", []) or []
    if not rows:
        return "_No tournaments committed._" + (" (bracket(s) skipped)" if skipped_any else "")
    lines = ["| V-cat | Weapon | Gender | id_tournament | Results |",
             "|---|---|---|---:|---:|"]
    for t in rows:
        lines.append(f"| {t.get('vcat', '?')} | {t.get('weapon', '-')} "
                     f"| {t.get('gender', '-')} | {t.get('id_tournament', '?')} "
                     f"| {t.get('n', '?')} |")
    return "\n".join(lines)


def _render_validation(g, event_code) -> str:
    lines: list[str] = []
    for f in g.get(Section.VALIDATION, []):
        p = f.payload
        check = p.get("check")
        if check == "pool_round":
            lines.append(f"- pool_round: {'DETECTED' if p.get('is_pool_round') else 'no'} "
                         f"({f.plugin})")
        elif check == "count":
            flags = [k for k in ("below_min", "count_mismatch") if p.get(k)]
            lines.append(f"- count: {'OK' if not flags else ', '.join(flags)}")
        elif check == "participant_count":
            lines.append(f"- participant_count: expected={p.get('expected')} "
                         f"actual={p.get('actual')}")
        elif check == "ir":
            lines.append(f"- ir: {'ok' if p.get('ok') else 'INVALID'}")
    skips = g.get("_schedule_skips", [])
    if skips:
        lines.append("")
        lines.append("**Schedule-level skips (never ingested):**")
        for s in skips:
            lines.append(f"- {s.get('name', '?')} "
                         f"({s.get('weapon', '?')}) — {s.get('reason', '?')}")
    return "\n".join(lines) if lines else "_No validation notes._"


def _render_signoff(g, event_code) -> str:
    return ("- [ ] New fencers verified\n"
            "- [ ] Birth-year reconciliations verified\n"
            "- [ ] Committed tournaments match the source\n"
            "- [ ] Validation notes reviewed\n\n"
            "_Informational only (ADR-074): the pipeline already committed live; "
            "fix via the alias UI / master-data edit and re-run to self-heal._")


# The TEMPLATE — ordered (heading, renderer). Mirrors the OLD _multi_summary_md
# section order so the prior staging .md is the parity bar.
STAGING_TEMPLATE = [
    ("## Event", _render_header),
    ("## New fencers created", _render_created),
    ("## Birth-year reconciliations", _render_reconciled),
    ("## Fencer matching", _render_matches),
    ("## NULL / estimated birth year", _render_estimated_by),
    ("## Committed tournaments", _render_committed),
    ("## Pool rounds / counts", _render_validation),
    ("## Sign-off", _render_signoff),
]


def render_staging_md(event_code: str, frags, schedule_skips, stamp: str) -> str:
    grouped = _group(frags)
    grouped["_schedule_skips"] = schedule_skips or []
    lines = [f"# Staging report — {event_code}", "", f"_Generated {stamp} (UTC)_", ""]
    for heading, renderer in STAGING_TEMPLATE:
        lines.append(heading)
        lines.append("")
        lines.append(renderer(grouped, event_code))
        lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# The plugin
# ---------------------------------------------------------------------------

class StagingFormatter(BasePlugin):
    name = "StagingFormatter"
    kind = PluginKind.MUTATOR
    reads = frozenset({"event"})
    effects = frozenset({"docs"})

    def applies(self, ctx: Context) -> bool:
        return ctx.get("_bracket_reports") is not None

    def run(self, ctx: Context, svc: Services) -> None:
        reports = ctx.get("_bracket_reports") or []
        frags = [f for report in reports for f in report]
        event = ctx.get("event") or {}
        event_code = event.get("txt_code") or ctx.params.get("event_code") or "EVENT"
        staging_dir = (svc.config or {}).get("staging_dir")
        stamp = _utc_stamp()

        # --- the .md (template) ---
        from python.pipeline.md_writer import write_for_event
        md = render_staging_md(event_code, frags, ctx.get("_schedule_skips"), stamp)
        write_for_event(event_code, md, target="local",
                        staging_dir=staging_dir, timestamp=stamp)

        # --- the .diff.md (3-way diff, reused verbatim) ---
        from python.pipeline.three_way_diff import (
            build_diff, confidence_histogram, render_markdown, write_diff,
        )
        grouped = _group(frags)
        matches = _all_matches(grouped)
        source_rows = [{"fencer_name": m["scraped_name"], "place": m["place"]}
                       for m in matches]
        new_rows = [{"fencer_name": m["scraped_name"], "place": m["place"],
                     "id_fencer": m["id_fencer"]} for m in matches]
        db = svc.db
        cert_rows = (db.fetch_cert_rows_for_event(event_code)
                     if db is not None and hasattr(db, "fetch_cert_rows_for_event")
                     else [])
        diff_rows = build_diff(source_rows, cert_rows, new_rows)
        hist = confidence_histogram(
            [SimpleNamespace(confidence=m.get("confidence") or 0.0) for m in matches])
        diff_md = render_markdown(
            event_code, diff_rows, hist,
            notes=["Aggregated across all brackets; rows joined by place "
                   "(ADR-075 informational diff)."])
        from pathlib import Path
        write_diff(event_code, diff_md,
                   Path(staging_dir) if staging_dir else None, timestamp=stamp)

        self.report(ctx, Section.REACTION, staging_md=True, staging_diff=True,
                    timestamp=stamp)
