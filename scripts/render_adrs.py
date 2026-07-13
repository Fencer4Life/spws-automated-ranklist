#!/usr/bin/env python3
"""Render the Markdown ADR archive into the official Editorial HTML standard."""

from __future__ import annotations

import argparse
import hashlib
import html
import re
import sys
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, cast
from urllib.parse import unquote, urlsplit, urlunsplit

from markdown_it import MarkdownIt
from markdown_it.token import Token

ROOT = Path(__file__).resolve().parents[1]
ADR_DIR = ROOT / "doc" / "adr"
TEMPLATE_PATH = ADR_DIR / "ADR_TEMPLATE.html"
INDEX_PATH = ADR_DIR / "index.html"
GENERATED_MARKER = '<meta name="adr-source" content="'
TITLE_RE = re.compile(r"^#\s+ADR[- ]?(\d+)\s*[:—-]\s*(.+?)\s*$")
FIELD_NAMES = "Status|Date|Source|Scope|Decision|Supersedes|Amends|Resolved"


@dataclass(frozen=True)
class Adr:
    source: Path
    number: int
    title_markdown: str
    title_text: str
    status_markdown: str
    date_markdown: str
    intro_markdown: str
    body_markdown: str
    sha256: str

    @property
    def output(self) -> Path:
        return self.source.with_suffix(".html")

    @property
    def label(self) -> str:
        return f"ADR-{self.number:03d}"


class DocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: set[str] = set()
        self.hrefs: list[str] = []
        self.meta: dict[str, str] = {}
        self.counts: dict[str, int] = {}

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if value := values.get("id"):
            self.ids.add(value)
        if href := values.get("href"):
            self.hrefs.append(href)
        name = values.get("name")
        content = values.get("content")
        if tag == "meta" and isinstance(name, str) and content is not None:
            self.meta[name] = content
        self.counts[tag] = self.counts.get(tag, 0) + 1


def source_paths() -> list[Path]:
    paths = [p for p in ADR_DIR.glob("[0-9][0-9][0-9]-*.md") if p.is_file()]
    return sorted(paths, key=lambda path: (int(path.name[:3]), path.name))


def plain_inline(md: MarkdownIt, value: str) -> str:
    tokens = md.parseInline(value)
    pieces: list[str] = []

    def collect(items: list[Token]) -> None:
        for token in items:
            if token.type in {"text", "code_inline"}:
                pieces.append(token.content)
            elif token.type in {"softbreak", "hardbreak"}:
                pieces.append(" ")
            elif token.children:
                collect(token.children)

    collect(tokens)
    return "".join(pieces).strip()


def extract_field(intro: str, field: str) -> str:
    pattern = re.compile(
        rf"\*\*{re.escape(field)}:\*\*\s*(.*?)"
        rf"(?=(?:\s+|\n)\*\*(?:{FIELD_NAMES}):\*\*|\n\s*\n|\Z)",
        re.DOTALL,
    )
    match = pattern.search(intro)
    return re.sub(r"\s+", " ", match.group(1)).strip() if match else "Not recorded"


def load_adrs(md: MarkdownIt) -> list[Adr]:
    records: list[Adr] = []
    for source in source_paths():
        raw = source.read_text(encoding="utf-8")
        lines = raw.splitlines()
        heading_index = next((i for i, line in enumerate(lines) if line.startswith("# ")), None)
        if heading_index is None:
            raise ValueError(f"{source}: missing ADR title")
        match = TITLE_RE.match(lines[heading_index])
        if not match:
            raise ValueError(f"{source}: unsupported ADR title: {lines[heading_index]!r}")
        body_start = next(
            (i for i in range(heading_index + 1, len(lines)) if lines[i].startswith("## ")),
            len(lines),
        )
        intro = "\n".join(lines[heading_index + 1 : body_start]).strip()
        body = "\n".join(lines[body_start:]).strip()
        title_md = match.group(2).strip()
        records.append(
            Adr(
                source=source,
                number=int(match.group(1)),
                title_markdown=title_md,
                title_text=plain_inline(md, title_md),
                status_markdown=extract_field(intro, "Status"),
                date_markdown=extract_field(intro, "Date"),
                intro_markdown=intro,
                body_markdown=body,
                sha256=hashlib.sha256(raw.encode()).hexdigest(),
            )
        )
    return records


def slugify(value: str, used: set[str]) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.casefold()).strip("-") or "section"
    base = slug
    suffix = 2
    while slug in used:
        slug = f"{base}-{suffix}"
        suffix += 1
    used.add(slug)
    return slug


def section_kind(title: str) -> str:
    key = title.casefold()
    for candidate in (
        "context",
        "decision",
        "consequences",
        "alternatives",
        "rejected",
        "tests",
        "validation",
    ):
        if candidate in key:
            return candidate
    return "detail"


def rewrite_adr_href(href: str, adr_markdown_names: set[str], link_base: Path) -> str:
    parts = urlsplit(href)
    decoded_path = unquote(parts.path)
    if Path(decoded_path).name in adr_markdown_names:
        new_path = str(Path(parts.path).with_suffix(".html"))
        return urlunsplit((parts.scheme, parts.netloc, new_path, parts.query, parts.fragment))
    if parts.path.startswith("../") and not (link_base / unquote(parts.path)).resolve().exists():
        root_relative = (ROOT / unquote(parts.path[3:])).resolve()
        if root_relative.exists():
            return urlunsplit(
                (parts.scheme, parts.netloc, f"../{parts.path}", parts.query, parts.fragment)
            )
    return href


def configured_markdown(adr_markdown_names: set[str], link_base: Path = ADR_DIR) -> MarkdownIt:
    md = MarkdownIt("commonmark", {"html": True}).enable("table").enable("strikethrough")
    renderer = cast(Any, md.renderer)

    def link_open(tokens: list[Token], idx: int, options, env) -> str:
        href = tokens[idx].attrGet("href")
        if isinstance(href, str):
            tokens[idx].attrSet("href", rewrite_adr_href(href, adr_markdown_names, link_base))
        return renderer.renderToken(tokens, idx, options, env)

    def table_open(tokens: list[Token], idx: int, options, env) -> str:
        return '<div class="tablewrap"><table>\n'

    def table_close(tokens: list[Token], idx: int, options, env) -> str:
        return "</table></div>\n"

    renderer.rules["link_open"] = link_open
    renderer.rules["table_open"] = table_open
    renderer.rules["table_close"] = table_close
    return md


def assign_heading_ids(tokens: list[Token]) -> list[tuple[int, str, str]]:
    used: set[str] = set()
    headings: list[tuple[int, str, str]] = []
    for index, token in enumerate(tokens):
        if token.type != "heading_open" or index + 1 >= len(tokens):
            continue
        level = int(token.tag[1])
        title = tokens[index + 1].content
        anchor = slugify(title, used)
        token.attrSet("id", anchor)
        headings.append((level, title, anchor))
    return headings


def render_body(
    md: MarkdownIt, markdown: str
) -> tuple[str, list[tuple[int, str, str]], dict[str, int]]:
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
        title = tokens[start + 1].content
        kind = section_kind(title)
        kicker = html.escape("Decision record" if kind == "detail" else kind)
        chunks.append(
            f'<section class="section-card adr-section {kind}"><p class="kicker">{kicker}</p>'
            f"{md.renderer.render(tokens[start:end], md.options, {})}</section>"
        )
    return "\n".join(chunks), headings, counts


def status_class(value: str) -> str:
    lowered = plain_inline(configured_markdown(set()), value).casefold()
    for status in ("accepted", "implemented", "proposed", "deferred", "superseded"):
        if status in lowered:
            return status
    return ""


def fact(label: str, value_html: str, css_class: str = "") -> str:
    return f'<div><dt>{html.escape(label)}</dt><dd class="{css_class}">{value_html}</dd></div>'


def toc_html(headings: list[tuple[int, str, str]]) -> str:
    return "".join(
        f'<li class="depth-{level}"><a href="#{html.escape(anchor)}">{html.escape(title)}</a></li>'
        for level, title, anchor in headings
        if 2 <= level <= 4
    )


def pager_link(record: Adr | None, css_class: str, prefix: str) -> str:
    if record is None:
        return f'<span class="{css_class}"></span>'
    return (
        f'<a class="{css_class}" href="{record.output.name}">{html.escape(prefix)} '
        f"{record.label}: {html.escape(record.title_text)}</a>"
    )


def render_adr(
    template: str, md: MarkdownIt, adr: Adr, previous: Adr | None, following: Adr | None
) -> tuple[str, dict[str, int]]:
    body_html, headings, source_counts = render_body(md, adr.body_markdown)
    intro_html = md.render(adr.intro_markdown) if adr.intro_markdown else ""
    status_html = md.renderInline(adr.status_markdown)
    date_html = md.renderInline(adr.date_markdown)
    facts = "".join(
        (
            fact("Status", status_html, status_class(adr.status_markdown)),
            fact("Date", date_html),
            fact("Source", f"<code>{html.escape(adr.source.name)}</code>"),
            fact("Length", f"{len(adr.source.read_text(encoding='utf-8').splitlines())} lines"),
        )
    )
    values = {
        "@@SOURCE_FILE@@": adr.source.name,
        "@@SOURCE_SHA256@@": adr.sha256,
        "@@ADR_LABEL@@": adr.label,
        "@@ADR_NUMBER@@": f"{adr.number:03d}",
        "@@TITLE_TEXT@@": html.escape(adr.title_text),
        "@@TITLE_HTML@@": md.renderInline(adr.title_markdown),
        "@@DEK_HTML@@": "Official architecture decision record for the SPWS Automated Ranklist System.",
        "@@FACTS_HTML@@": facts,
        "@@SOURCE_NOTE_HTML@@": f'<div class="source-note">{intro_html}</div>'
        if intro_html
        else "",
        "@@TOC_HTML@@": toc_html(headings),
        "@@BODY_HTML@@": body_html,
        "@@PREVIOUS_HTML@@": pager_link(previous, "previous", "←"),
        "@@NEXT_HTML@@": pager_link(following, "next", "→"),
    }
    output = template
    for marker, value in values.items():
        output = output.replace(marker, value)
    if "@@" in output:
        raise ValueError(f"{adr.source}: unresolved template marker")
    return output, source_counts


def render_index(adrs: list[Adr], md: MarkdownIt) -> str:
    rows = []
    for adr in reversed(adrs):
        rows.append(
            "<tr>"
            f'<td><a href="{adr.output.name}">{adr.label}</a></td>'
            f"<td>{html.escape(adr.title_text)}</td>"
            f'<td class="status {status_class(adr.status_markdown)}">{md.renderInline(adr.status_markdown)}</td>'
            f"<td>{md.renderInline(adr.date_markdown)}</td>"
            "</tr>"
        )
    accepted = sum("accepted" in plain_inline(md, adr.status_markdown).casefold() for adr in adrs)
    proposed = sum("proposed" in plain_inline(md, adr.status_markdown).casefold() for adr in adrs)
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SPWS Architecture Decision Register</title><link rel="stylesheet" href="assets/adr.css"><style>
.registry-head{{border-bottom:3px solid var(--navy);padding-bottom:34px}}.registry-head h1{{max-width:20ch}}.stats{{display:flex;flex-wrap:wrap;gap:10px;margin-top:24px}}.stat{{background:var(--card);border:1px solid var(--line);padding:10px 14px;font:700 13px var(--mono)}}.registry-table{{margin-top:42px}}.registry-table table{{min-width:800px}}.registry-table td:first-child{{font:750 13px var(--mono);white-space:nowrap}}.registry-table td:nth-child(2){{font-weight:700}}.status{{font-size:14px}}.status.accepted,.status.implemented{{color:var(--green)}}.status.proposed,.status.deferred{{color:var(--amber)}}.status.superseded{{color:var(--coral)}}
</style></head><body><div class="page"><header class="registry-head"><p class="eyebrow">SPWS · Architecture</p><h1>Decision register</h1><p class="dek">The official, navigable record of architectural decisions for the SPWS Automated Ranklist System.</p><div class="stats"><span class="stat">{len(adrs)} records</span><span class="stat">{accepted} accepted</span><span class="stat">{proposed} proposed</span><span class="stat">Newest: {adrs[-1].label}</span></div></header><main class="registry-table"><div class="tablewrap"><table><thead><tr><th>ADR</th><th>Decision</th><th>Status</th><th>Date</th></tr></thead><tbody>{"".join(rows)}</tbody></table></div></main><footer class="foot">Generated by <code>scripts/render_adrs.py</code> from retained Markdown sources.</footer></div></body></html>"""


def write_outputs(adrs: list[Adr], md: MarkdownIt) -> dict[Path, dict[str, int]]:
    template = TEMPLATE_PATH.read_text(encoding="utf-8")
    expected: dict[Path, dict[str, int]] = {}
    for index, adr in enumerate(adrs):
        previous = adrs[index - 1] if index else None
        following = adrs[index + 1] if index + 1 < len(adrs) else None
        output, counts = render_adr(template, md, adr, previous, following)
        adr.output.write_text(output, encoding="utf-8")
        expected[adr.output] = counts
    INDEX_PATH.write_text(render_index(adrs, md), encoding="utf-8")
    return expected


def validate(
    adrs: list[Adr], expected_counts: dict[Path, dict[str, int]] | None = None
) -> list[str]:
    errors: list[str] = []
    expected_names = {adr.output.name for adr in adrs}
    for adr in adrs:
        if not adr.output.exists():
            errors.append(f"missing {adr.output.relative_to(ROOT)}")
            continue
        parser = DocumentParser()
        try:
            parser.feed(adr.output.read_text(encoding="utf-8"))
            parser.close()
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{adr.output.name}: HTML parse failed: {exc}")
            continue
        if parser.meta.get("adr-source") != adr.source.name:
            errors.append(f"{adr.output.name}: wrong source metadata")
        if parser.meta.get("adr-source-sha256") != adr.sha256:
            errors.append(f"{adr.output.name}: stale source SHA-256")
        if expected_counts:
            counts = expected_counts[adr.output]
            if parser.counts.get("table", 0) != counts["tables"]:
                errors.append(f"{adr.output.name}: table count mismatch")
            if parser.counts.get("pre", 0) < counts["fences"]:
                errors.append(f"{adr.output.name}: fenced-code count mismatch")
        for href in parser.hrefs:
            parts = urlsplit(href)
            if parts.scheme or parts.netloc or href.startswith(("mailto:", "tel:")):
                continue
            if parts.path:
                target = (adr.output.parent / unquote(parts.path)).resolve()
                if not target.exists():
                    errors.append(f"{adr.output.name}: missing local target {href}")
                    continue
            if not parts.path and parts.fragment and parts.fragment not in parser.ids:
                errors.append(f"{adr.output.name}: missing local anchor #{parts.fragment}")
    if not INDEX_PATH.exists():
        errors.append("missing doc/adr/index.html")
    else:
        index_text = INDEX_PATH.read_text(encoding="utf-8")
        for adr in adrs:
            if f'href="{adr.output.name}"' not in index_text:
                errors.append(f"index.html: missing {adr.output.name}")
    generated = {path.name for path in ADR_DIR.glob("[0-9][0-9][0-9]-*.html")}
    extras = sorted(generated - expected_names)
    if extras:
        errors.append(f"orphan generated ADR files: {', '.join(extras)}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check", action="store_true", help="validate generated HTML without writing"
    )
    args = parser.parse_args()
    names = {path.name for path in source_paths()}
    md = configured_markdown(names)
    adrs = load_adrs(md)
    if not adrs:
        print("No ADR sources found", file=sys.stderr)
        return 1
    if args.check:
        expected_counts = {adr.output: render_body(md, adr.body_markdown)[2] for adr in adrs}
    else:
        expected_counts = write_outputs(adrs, md)
    errors = validate(adrs, expected_counts)
    if errors:
        print("ADR HTML validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    action = "Validated" if args.check else "Rendered and validated"
    print(f"{action} {len(adrs)} ADRs; index: {INDEX_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
