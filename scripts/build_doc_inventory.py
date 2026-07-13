#!/usr/bin/env python3
"""Build the HTML freeze inventory for the documentation migration."""

from __future__ import annotations

import argparse
import hashlib
import html
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "doc"
OUTPUT = DOC / "governance" / "documentation-inventory.html"


@dataclass(frozen=True)
class Item:
    path: Path
    category: str
    destination: str
    reason: str
    size: int
    digest: str


def classify(path: Path) -> tuple[str, str, str]:
    rel = path.relative_to(ROOT).as_posix()
    name = path.name
    suffix = path.suffix.casefold()
    if name in {".DS_Store"} or name.startswith(".~lock"):
        return "noise", "remove/ignore", "Editor or operating-system artifact"
    if rel.startswith("doc/handbook/"):
        return "canonical", "keep in handbook", "Current-system human documentation"
    if rel.startswith("doc/adr/"):
        return "decision", "keep in adr", "Architecture decision record or ADR presentation asset"
    if rel.startswith("doc/rules/"):
        return "governance", "keep in rules", "Formal business rule"
    if rel.startswith("doc/plans/") or rel.startswith("doc/backlog/"):
        return "work", "doc/work or archive/plans", "Active or completed implementation planning"
    if rel.startswith("doc/archive/"):
        return "archive", "keep in archive", "Already classified as historical"
    if rel.startswith("doc/claude/"):
        return (
            "agent-guidance",
            "AGENTS/skills + governance",
            "Agent-oriented instructions mixed with developer facts",
        )
    if rel.startswith(
        (
            "doc/staging/",
            "doc/audits/",
            "doc/external_files/",
            "doc/mockups/",
            "doc/assets/",
            "doc/staging_overrides/",
            "doc/gas/",
        )
    ):
        return (
            "evidence",
            "doc/evidence",
            "Operational, design, audit, source, or generated evidence",
        )
    if name.startswith("development_history"):
        return (
            "legacy-candidate",
            "archive/history",
            "Chronological history, not current-system guidance",
        )
    if name.startswith(("ingestion-pipeline-design", "ingestion_pipeline_NEW_design")):
        return (
            "legacy-candidate",
            "archive/designs",
            "Historical/proposed design to reconcile into current architecture",
        )
    if name.startswith("Project Specification") or name.startswith("requirements-traceability"):
        return "governance", "doc/governance", "Requirements and traceability authority"
    if name.startswith("cicd-operations-manual") or name.startswith("telegram-ingest-command"):
        return (
            "migration-source",
            "handbook/operations + reference",
            "Current facts must be split by ownership",
        )
    if name == "index.html":
        return "gateway", "replace after handbook parity", "Current documentation entrypoint"
    if suffix in {".md", ".html"}:
        return (
            "unclassified-doc",
            "manual review",
            "Human-facing document outside an established area",
        )
    return "evidence", "doc/evidence", "Non-document artifact retained for evidence"


def collect() -> list[Item]:
    items: list[Item] = []
    for path in sorted(
        p for p in DOC.rglob("*") if p.is_file() and p.resolve() != OUTPUT.resolve()
    ):
        category, destination, reason = classify(path)
        data = path.read_bytes()
        items.append(
            Item(
                path=path,
                category=category,
                destination=destination,
                reason=reason,
                size=len(data),
                digest=hashlib.sha256(data).hexdigest(),
            )
        )
    return items


def render(items: list[Item]) -> str:
    counts = Counter(item.category for item in items)
    rows = []
    for item in items:
        rel = item.path.relative_to(ROOT).as_posix()
        rows.append(
            f'<tr data-category="{html.escape(item.category)}">'
            f"<td><code>{html.escape(rel)}</code></td>"
            f'<td><span class="chip {html.escape(item.category)}">{html.escape(item.category)}</span></td>'
            f"<td>{html.escape(item.destination)}</td>"
            f"<td>{html.escape(item.reason)}</td>"
            f"<td>{item.size:,}</td>"
            f"<td><code>{item.digest[:12]}</code></td>"
            "</tr>"
        )
    cards = "".join(
        f'<div class="stat"><strong>{count}</strong><span>{html.escape(category)}</span></div>'
        for category, count in sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))
    )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="doc-id" content="GOV-DOC-INVENTORY"><meta name="doc-status" content="current"><meta name="doc-type" content="migration-manifest"><meta name="last-verified" content="2026-07-12"><title>Documentation Freeze Inventory</title><link rel="stylesheet" href="../adr/assets/adr.css"><style>
.head{{border-bottom:3px solid var(--navy);padding-bottom:30px}}.stats{{display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:10px;margin:28px 0}}.stat{{background:var(--card);border:1px solid var(--line);padding:14px}}.stat strong{{display:block;font:800 25px var(--serif)}}.stat span{{font:700 11px var(--mono);text-transform:uppercase;color:var(--muted)}}.inventory table{{min-width:1100px}}.inventory td:first-child{{max-width:360px;overflow-wrap:anywhere}}.inventory td:nth-child(5){{text-align:right;font-variant-numeric:tabular-nums}}.chip{{font:750 10px var(--mono);text-transform:uppercase;padding:4px 7px;border-radius:4px;background:var(--blue);color:var(--navy)}}.chip.archive,.chip.legacy-candidate{{background:var(--coral-soft);color:var(--coral)}}.chip.evidence{{background:var(--amber-soft);color:var(--amber)}}.chip.canonical,.chip.decision,.chip.governance{{background:var(--green-soft);color:var(--green)}}
</style></head><body><div class="page"><header class="head"><p class="eyebrow">Documentation rebuild · Phase 1</p><h1>Freeze inventory</h1><p class="dek">A byte-level inventory and initial disposition for every file in <code>doc/</code> before migration. SHA prefixes provide a stable freeze reference; this manifest does not move or reinterpret source material.</p><div class="stats">{cards}</div></header><main><section><p class="kicker">Disposition policy</p><h2>{len(items)} files classified</h2><p>Canonical and governance material is retained or decomposed. Work is separated from current truth. Evidence remains available but leaves the newcomer path. Legacy candidates are archived only after replacement coverage is proven.</p><div class="tablewrap inventory"><table><thead><tr><th>Path</th><th>Class</th><th>Destination</th><th>Reason</th><th>Bytes</th><th>SHA-256</th></tr></thead><tbody>{"".join(rows)}</tbody></table></div></section></main><footer class="foot">Generated by <code>scripts/build_doc_inventory.py</code>. Freeze date: 12 July 2026.</footer></div></body></html>"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = render(collect())
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != rendered:
            print(f"stale inventory: {OUTPUT.relative_to(ROOT)}")
            return 1
        print(f"Inventory current: {OUTPUT.relative_to(ROOT)}")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(rendered, encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
