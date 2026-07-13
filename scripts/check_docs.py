#!/usr/bin/env python3
"""Validate the canonical HTML handbook and report documentation ownership impact."""

from __future__ import annotations

import argparse
import fnmatch
import json
import subprocess
from dataclasses import dataclass, field
from datetime import date
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
HANDBOOK = ROOT / "doc" / "handbook"
MAP = HANDBOOK / "documentation-map.html"
GATEWAY_PAGES = (
    ROOT / "doc" / "index.html",
    ROOT / "doc" / "governance" / "index.html",
    ROOT / "doc" / "evidence" / "index.html",
    ROOT / "doc" / "rules" / "index.html",
    ROOT / "doc" / "archive" / "legacy-2026-07" / "index.html",
    ROOT / "doc" / "archive" / "legacy-2026-07" / "generated-documents.html",
)
REQUIRED_META = {"doc-id", "doc-status", "doc-type", "doc-owner", "last-verified"}
SUBSYSTEM_SECTIONS = {
    "purpose",
    "boundaries",
    "mental-model",
    "current-flow",
    "invariants",
    "implementation-map",
    "operations",
    "tests",
    "decisions",
    "change-triggers",
}


@dataclass
class Parsed:
    meta: dict[str, str] = field(default_factory=dict)
    ids: set[str] = field(default_factory=set)
    hrefs: list[str] = field(default_factory=list)
    json_blocks: dict[str, str] = field(default_factory=dict)


class Parser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.result = Parsed()
        self._json_id: str | None = None
        self._json_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if value := values.get("id"):
            self.result.ids.add(value)
        if href := values.get("href"):
            self.result.hrefs.append(href)
        if tag == "meta" and values.get("name") and values.get("content") is not None:
            self.result.meta[values["name"] or ""] = values["content"] or ""
        if tag == "script" and values.get("type") == "application/json" and values.get("id"):
            self._json_id = values["id"]
            self._json_parts = []

    def handle_data(self, data: str) -> None:
        if self._json_id:
            self._json_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self._json_id:
            self.result.json_blocks[self._json_id] = "".join(self._json_parts)
            self._json_id = None
            self._json_parts = []


def parse(path: Path) -> Parsed:
    parser = Parser()
    parser.feed(path.read_text(encoding="utf-8"))
    parser.close()
    return parser.result


def pages() -> list[Path]:
    return sorted(path for path in HANDBOOK.rglob("*.html") if path.name != "PAGE_TEMPLATE.html")


def load_map() -> list[dict]:
    if not MAP.exists():
        return []
    raw = parse(MAP).json_blocks.get("documentation-ownership", "[]")
    value = json.loads(raw)
    if not isinstance(value, list):
        raise ValueError("documentation ownership map must be a JSON list")
    return value


def validate() -> list[str]:
    errors: list[str] = []
    parsed_pages: dict[Path, Parsed] = {}
    doc_ids: dict[str, Path] = {}
    ownership = load_map()
    map_paths = {entry.get("path") for entry in ownership if entry.get("status") == "current"}
    for path in pages():
        result = parse(path)
        parsed_pages[path] = result
        rel = path.relative_to(ROOT).as_posix()
        missing = REQUIRED_META - result.meta.keys()
        if missing:
            errors.append(f"{rel}: missing metadata {sorted(missing)}")
        doc_id = result.meta.get("doc-id")
        if doc_id:
            if doc_id in doc_ids:
                errors.append(f"{rel}: duplicate doc-id {doc_id} also used by {doc_ids[doc_id]}")
            doc_ids[doc_id] = path
        status = result.meta.get("doc-status")
        if status not in {"current", "draft", "archived"}:
            errors.append(f"{rel}: invalid doc-status {status!r}")
        verified = result.meta.get("last-verified")
        if verified:
            try:
                date.fromisoformat(verified)
            except ValueError:
                errors.append(f"{rel}: invalid last-verified {verified!r}")
        if status == "current" and rel not in map_paths and path != MAP:
            errors.append(f"{rel}: current page missing from documentation map")
        if result.meta.get("doc-type") == "subsystem":
            absent = SUBSYSTEM_SECTIONS - result.ids
            if absent:
                errors.append(f"{rel}: missing subsystem sections {sorted(absent)}")
        for href in result.hrefs:
            parts = urlsplit(href)
            if parts.scheme or parts.netloc or href.startswith(("mailto:", "tel:")):
                continue
            if parts.path.endswith(".md"):
                errors.append(f"{rel}: canonical handbook link points to Markdown: {href}")
            target = path if not parts.path else (path.parent / unquote(parts.path)).resolve()
            if not target.exists():
                errors.append(f"{rel}: missing link target {href}")
                continue
            if parts.fragment and target.suffix == ".html":
                target_result = parsed_pages.get(target) or parse(target)
                if parts.fragment not in target_result.ids:
                    errors.append(f"{rel}: missing anchor {href}")
        forbidden = (
            "development_history",
            "ingestion_pipeline_NEW_design",
            "ingestion-pipeline-design",
        )
        for href in result.hrefs:
            if any(name in href for name in forbidden):
                errors.append(f"{rel}: canonical page links directly to legacy narrative {href}")
    for entry in ownership:
        path_value = entry.get("path")
        if entry.get("status") == "current" and path_value:
            target = ROOT / path_value
            if not target.exists():
                errors.append(f"documentation map: missing current page {path_value}")
    for path in GATEWAY_PAGES:
        rel = path.relative_to(ROOT).as_posix()
        if not path.exists():
            errors.append(f"missing documentation gateway {rel}")
            continue
        result = parse(path)
        for href in result.hrefs:
            parts = urlsplit(href)
            if parts.scheme or parts.netloc or href.startswith(("mailto:", "tel:")):
                continue
            target = path if not parts.path else (path.parent / unquote(parts.path)).resolve()
            if not target.exists():
                errors.append(f"{rel}: missing link target {href}")
                continue
            if parts.fragment and target.suffix == ".html":
                target_result = parsed_pages.get(target) or parse(target)
                if parts.fragment not in target_result.ids:
                    errors.append(f"{rel}: missing anchor {href}")
    return errors


def changed_files(base: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base, "--"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    return [line for line in result.stdout.splitlines() if line]


def ownership_warnings(base: str) -> list[str]:
    changed = changed_files(base)
    changed_set = set(changed)
    warnings: list[str] = []
    for entry in load_map():
        if entry.get("status") != "current":
            continue
        watched = entry.get("source_globs", [])
        matched = [path for path in changed if any(fnmatch.fnmatch(path, glob) for glob in watched)]
        if matched and entry.get("path") not in changed_set:
            warnings.append(
                f"{entry.get('path')} owns changed sources but was not updated: {', '.join(matched[:5])}"
            )
    return warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--changed-from")
    parser.add_argument("--strict-ownership", action="store_true")
    args = parser.parse_args()
    errors = validate()
    for error in errors:
        print(f"ERROR: {error}")
    warnings = ownership_warnings(args.changed_from) if args.changed_from else []
    for warning in warnings:
        print(f"WARNING: {warning}")
    if errors or (warnings and args.strict_ownership):
        return 1
    print(
        f"Documentation valid: {len(pages())} handbook pages; {len(warnings)} ownership warning(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
