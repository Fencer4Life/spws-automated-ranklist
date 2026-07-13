#!/usr/bin/env python3
"""Render retained governance and legacy Markdown into the Editorial HTML standard.

Companion to ``render_adrs.py`` (which owns the ADR archive). This generator reuses that
module's rendering core — markdown-it configuration, heading-id assignment, the table-of-contents
builder and the HTML validator — and applies it to hand-maintained governance Markdown directly
under ``doc/`` plus Markdown physically preserved in ``doc/archive/legacy-2026-07/``. Each source
is rendered to a sibling HTML file carrying ``doc-source`` / ``doc-source-sha256`` provenance.
Local ``.md`` links whose targets belong to this corpus or ``adr/*.md`` are rewritten to HTML.
The generated corpus catalog lives under the dated legacy archive; ``doc/index.html`` is the
hand-maintained current-documentation gateway. See ADR-082.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlsplit

from markdown_it import MarkdownIt
from render_adrs import (
    ROOT,
    DocumentParser,
    assign_heading_ids,
    configured_markdown,
    toc_html,
)

DOC_DIR = ROOT / "doc"
ADR_DIR = DOC_DIR / "adr"
LEGACY_DIR = DOC_DIR / "archive" / "legacy-2026-07"
INDEX_PATH = LEGACY_DIR / "generated-documents.html"
DEK = "Project documentation for the SPWS Automated Ranklist System — generated from the retained Markdown source."


@dataclass(frozen=True)
class Doc:
    source: Path
    title_markdown: str
    title_text: str
    body_markdown: str
    sha256: str

    @property
    def output(self) -> Path:
        return self.source.with_suffix(".html")


def source_paths() -> list[Path]:
    """Governance sources at ``doc/*.md`` plus the explicitly frozen legacy corpus."""
    current = [p for p in DOC_DIR.glob("*.md") if p.is_file()]
    legacy = [p for p in LEGACY_DIR.glob("*.md") if p.is_file()]
    return sorted((*current, *legacy), key=lambda path: path.relative_to(DOC_DIR).as_posix())


def href_from(source: Path, target: Path) -> str:
    """Return a portable relative link from ``source``'s directory to ``target``."""
    return Path(os.path.relpath(target, source.parent)).as_posix()


def corpus_names() -> set[str]:
    """Markdown basenames whose ``.html`` twins exist, for local-link rewriting."""
    docs = {p.name for p in source_paths()}
    adrs = {p.name for p in ADR_DIR.glob("[0-9][0-9][0-9]-*.md")}
    return docs | adrs


def load_docs() -> list[Doc]:
    records: list[Doc] = []
    for source in source_paths():
        raw = source.read_text(encoding="utf-8")
        lines = raw.splitlines()
        heading_index = next((i for i, line in enumerate(lines) if line.startswith("# ")), None)
        if heading_index is None:
            title_md = source.stem
            body = raw
        else:
            title_md = lines[heading_index][2:].strip()
            body = "\n".join(lines[heading_index + 1 :]).strip()
        records.append(
            Doc(
                source=source,
                title_markdown=title_md,
                title_text=title_md,
                body_markdown=body,
                sha256=hashlib.sha256(raw.encode()).hexdigest(),
            )
        )
    return records


def render_doc_body(
    md: MarkdownIt, markdown: str
) -> tuple[str, list[tuple[int, str, str]], dict[str, int]]:
    """Chunk the body into ``section-card`` blocks at each ``##`` (no ADR-specific kicker)."""
    tokens = md.parse(markdown)
    headings = assign_heading_ids(tokens)
    counts = {
        "tables": sum(token.type == "table_open" for token in tokens),
        "fences": sum(token.type in {"fence", "code_block"} for token in tokens),
    }
    h2_indices = [
        i for i, token in enumerate(tokens) if token.type == "heading_open" and token.tag == "h2"
    ]
    if not h2_indices:
        return (
            f'<section class="section-card detail">{md.renderer.render(tokens, md.options, {})}</section>',
            headings,
            counts,
        )
    chunks: list[str] = []
    if h2_indices[0] > 0:
        chunks.append(
            f'<section class="section-card detail">{md.renderer.render(tokens[: h2_indices[0]], md.options, {})}</section>'
        )
    for position, start in enumerate(h2_indices):
        end = h2_indices[position + 1] if position + 1 < len(h2_indices) else len(tokens)
        chunks.append(
            f'<section class="section-card detail">{md.renderer.render(tokens[start:end], md.options, {})}</section>'
        )
    return "\n".join(chunks), headings, counts


def render_doc(md: MarkdownIt, doc: Doc) -> tuple[str, dict[str, int]]:
    body_html, headings, counts = render_doc_body(md, doc.body_markdown)
    line_count = len(doc.source.read_text(encoding="utf-8").splitlines())
    facts = "".join(
        (
            f"<div><dt>Source</dt><dd><code>{html.escape(doc.source.name)}</code></dd></div>",
            f"<div><dt>Length</dt><dd>{line_count} lines</dd></div>",
            "<div><dt>Kind</dt><dd>Project documentation</dd></div>",
        )
    )
    css_href = href_from(doc.output, ADR_DIR / "assets" / "adr.css")
    handbook_href = href_from(doc.output, DOC_DIR / "handbook" / "index.html")
    adr_href = href_from(doc.output, ADR_DIR / "index.html")
    output = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="doc-source" content="{html.escape(doc.source.name)}">
<meta name="doc-source-sha256" content="{doc.sha256}">
<title>{html.escape(doc.title_text)} · SPWS</title>
<link rel="stylesheet" href="{css_href}">
</head>
<body><div class="page">
<header class="mast">
  <div><p class="eyebrow">SPWS · Project Documentation</p><h1>{md.renderInline(doc.title_markdown)}</h1><p class="dek">{DEK}</p></div>
  <aside class="facts" aria-label="Document metadata"><dl>{facts}</dl></aside>
</header>
<div class="layout">
  <nav class="toc" aria-label="Contents"><p class="kicker">On this page</p><ol>{toc_html(headings)}</ol></nav>
  <main>{body_html}</main>
</div>
<nav class="pager" aria-label="Documentation navigation"><a class="registry" href="{handbook_href}">← Current handbook</a><a class="next" href="{adr_href}">ADR registry →</a></nav>
<footer class="foot">Generated from <code>{html.escape(doc.source.name)}</code> · source SHA-256 <code>{doc.sha256}</code></footer>
</div></body></html>"""
    return output, counts


def render_index(docs: list[Doc]) -> str:
    rows = "".join(
        "<tr>"
        f'<td><a href="{html.escape(href_from(INDEX_PATH, doc.output))}">{html.escape(doc.title_text)}</a></td>'
        f"<td>{len(doc.source.read_text(encoding='utf-8').splitlines())} lines</td>"
        f"<td><code>{html.escape(doc.source.name)}</code></td>"
        "</tr>"
        for doc in docs
    )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Generated Legacy Documents · SPWS</title><link rel="stylesheet" href="../../adr/assets/adr.css"><style>
.registry-head{{border-bottom:3px solid var(--navy);padding-bottom:34px}}.registry-head h1{{max-width:22ch}}.stats{{display:flex;flex-wrap:wrap;gap:10px;margin-top:24px}}.stat{{background:var(--card);border:1px solid var(--line);padding:10px 14px;font:700 13px var(--mono)}}.registry-table{{margin-top:42px}}.registry-table table{{min-width:640px}}.registry-table td:first-child{{font-weight:700}}.registry-table td:nth-child(3){{font:600 13px var(--mono);color:var(--muted)}}
</style></head><body><div class="page"><header class="registry-head"><p class="eyebrow">SPWS · Frozen legacy corpus</p><h1>Generated legacy documents</h1><p class="dek">Styled renderings of retained governance and archived Markdown sources. These pages preserve the pre-handbook corpus; they are not the current architecture path.</p><div class="stats"><span class="stat">{len(docs)} documents</span><span class="stat"><a href="../../handbook/index.html">Current handbook →</a></span></div></header><main class="registry-table"><div class="tablewrap"><table><thead><tr><th>Document</th><th>Length</th><th>Source</th></tr></thead><tbody>{rows}</tbody></table></div></main><footer class="foot">Generated by <code>scripts/render_docs.py</code> from retained Markdown sources.</footer></div></body></html>"""


def write_outputs(docs: list[Doc], md: MarkdownIt) -> dict[Path, dict[str, int]]:
    expected: dict[Path, dict[str, int]] = {}
    for doc in docs:
        output, counts = render_doc(md, doc)
        doc.output.write_text(output, encoding="utf-8")
        expected[doc.output] = counts
    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text(render_index(docs), encoding="utf-8")
    return expected


def validate(
    docs: list[Doc], expected_counts: dict[Path, dict[str, int]] | None = None
) -> tuple[list[str], list[str]]:
    """Return (fatal errors, warnings). Staleness/structure is fatal; link/anchor gaps warn."""
    errors: list[str] = []
    warnings: list[str] = []
    for doc in docs:
        if not doc.output.exists():
            errors.append(f"missing {doc.output.relative_to(ROOT)}")
            continue
        parser = DocumentParser()
        try:
            parser.feed(doc.output.read_text(encoding="utf-8"))
            parser.close()
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{doc.output.name}: HTML parse failed: {exc}")
            continue
        if parser.meta.get("doc-source") != doc.source.name:
            errors.append(f"{doc.output.name}: wrong source metadata")
        if parser.meta.get("doc-source-sha256") != doc.sha256:
            errors.append(f"{doc.output.name}: stale source SHA-256")
        if expected_counts:
            counts = expected_counts[doc.output]
            if parser.counts.get("table", 0) != counts["tables"]:
                errors.append(f"{doc.output.name}: table count mismatch")
            if parser.counts.get("pre", 0) < counts["fences"]:
                errors.append(f"{doc.output.name}: fenced-code count mismatch")
        for href in parser.hrefs:
            parts = urlsplit(href)
            if parts.scheme or parts.netloc or href.startswith(("mailto:", "tel:")):
                continue
            if parts.path:
                target = (doc.output.parent / unquote(parts.path)).resolve()
                if not target.exists():
                    warnings.append(f"{doc.output.name}: missing local target {href}")
            elif parts.fragment and parts.fragment not in parser.ids:
                warnings.append(f"{doc.output.name}: missing local anchor #{parts.fragment}")
    if not INDEX_PATH.exists():
        errors.append("missing doc/index.html")
    else:
        index_text = INDEX_PATH.read_text(encoding="utf-8")
        for doc in docs:
            if f'href="{href_from(INDEX_PATH, doc.output)}"' not in index_text:
                errors.append(f"index.html: missing {doc.output.name}")
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check", action="store_true", help="validate generated HTML without writing"
    )
    args = parser.parse_args()
    md = configured_markdown(corpus_names(), link_base=DOC_DIR)
    docs = load_docs()
    if not docs:
        print("No doc sources found", file=sys.stderr)
        return 1
    if args.check:
        expected_counts = {doc.output: render_doc_body(md, doc.body_markdown)[2] for doc in docs}
    else:
        expected_counts = write_outputs(docs, md)
    errors, warnings = validate(docs, expected_counts)
    for warning in warnings:
        print(f"  ! {warning}", file=sys.stderr)
    if errors:
        print("Docs HTML validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    action = "Validated" if args.check else "Rendered and validated"
    print(f"{action} {len(docs)} docs; index: {INDEX_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
