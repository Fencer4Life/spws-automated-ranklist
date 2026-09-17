#!/usr/bin/env python3
"""Index the SPWS documentation corpus into Meilisearch for search over MCP.

Why this exists rather than an off-the-shelf loader: every hand-written page in
this repository carries its full stylesheet inline. `doc/plans` alone holds
roughly 330 KB of CSS, and indexing the raw markup would put `--surface-2` and
`prefers-color-scheme` into the search index and poison every result. So the
HTML is reduced to text here, split on its own headings, and posted with the
path, page title and heading as separate fields.

Scope follows `doc/claude/graph-analysis.md`: archived narratives are never
current-behaviour evidence, so `doc/archive/` is excluded exactly as
`.graphifyignore` excludes it from the knowledge graph. ADRs are indexed from
their Markdown sources only — the HTML twins are generated duplicates, and
indexing both would double every hit.

Usage:
    python3 tools/docs-search/ingest.py            # index everything in scope
    python3 tools/docs-search/ingest.py --dry-run  # report what would be sent
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from html.parser import HTMLParser
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ENV_FILE = Path(__file__).resolve().parent / ".env"
MEILI_URL = "http://127.0.0.1:7700"
INDEX = "spws_docs"

# One heading section per chunk, split further at paragraph boundaries when a
# section runs long, so a hit points at a readable passage rather than a page.
MAX_CHARS = 2000
BATCH = 300

# (kind, directory, glob). Order only affects reporting.
SOURCES: list[tuple[str, str, str]] = [
    ("handbook", "doc/handbook", "**/*.html"),
    ("governance", "doc/governance", "**/*.html"),
    ("adr", "doc/adr", "**/*.md"),
    ("plan", "doc/plans", "**/*.html"),
    ("evidence", "doc/evidence", "**/*.html"),
    # Agent procedures. Referenced from CLAUDE.md but not loaded into context,
    # so they are worth finding by content rather than by remembering the path.
    ("procedure", "doc/claude", "**/*.md"),
]

# Words that carry no signal in a documentation query, in both languages the
# corpus uses. Meilisearch's leading ranking rule counts how many query words a
# document matched, so without this a question phrased as a sentence is decided
# by its grammar rather than by its subject.
STOP_WORDS = [
    # English
    "a", "an", "and", "are", "as", "at", "be", "but", "by", "did", "do", "does",
    "for", "from", "has", "have", "how", "i", "if", "in", "is", "it", "its",
    "must", "no", "not", "of", "on", "or", "our", "should", "so", "than", "that",
    "the", "then", "there", "they", "this", "to", "was", "we", "were", "what",
    "when", "where", "which", "who", "why", "will", "with", "would", "you",
    # Polish
    "aby", "ale", "albo", "bez", "by", "czy", "dla", "do", "gdy", "gdzie", "i",
    "ich", "ile", "jak", "jest", "już", "kiedy", "który", "która", "które",
    "lub", "ma", "na", "nie", "o", "od", "po", "przez", "się", "tak", "te",
    "tego", "to", "w", "we", "za", "ze", "że",
]

EXCLUDE_PARTS = {"archive"}
# Templates and scaffolding: real filenames, placeholder content. Indexing them
# puts "One-sentence purpose and mental model" into results for every query.
EXCLUDE_NAMES = {"PAGE_TEMPLATE.html", "TEMPLATE.md", "TEMPLATE.html"}
SKIP_TAGS = {"style", "script", "noscript", "svg", "template"}
HEADING_TAGS = {"h1", "h2", "h3", "h4"}


# Meilisearch folds ordinary accents (é → e) but not letters that are their own
# character rather than a decorated base: Ł does not decompose to L, so a search
# for "Lomianki" misses "Łomianki" entirely. Verified 2026-09-16: 12 hits with
# the diacritic, 0 without. Every chunk therefore also carries a folded copy of
# its text, which is what makes an unaccented query work.
_FOLD = str.maketrans({
    "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
    "ó": "o", "ś": "s", "ź": "z", "ż": "z",
    "Ą": "A", "Ć": "C", "Ę": "E", "Ł": "L", "Ń": "N",
    "Ó": "O", "Ś": "S", "Ź": "Z", "Ż": "Z",
})


def fold(text: str) -> str:
    """Polish letters reduced to ASCII, then any remaining accents stripped."""
    folded = text.translate(_FOLD)
    decomposed = unicodedata.normalize("NFKD", folded)
    return "".join(c for c in decomposed if not unicodedata.combining(c))


@dataclass
class Chunk:
    id: str
    path: str
    kind: str
    title: str
    heading: str
    text: str
    folded: str
    order: int


class TextExtractor(HTMLParser):
    """Collect visible text, tracking the most recent heading.

    Emits (heading, text) segments: a new segment starts at every h1-h4, which
    is how these documents are actually organised.
    """

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title = ""
        self.segments: list[tuple[str, list[str]]] = [("", [])]
        self._skip_depth = 0
        self._in_title = False
        self._heading_tag: str | None = None
        self._heading_buf: list[str] = []

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag in SKIP_TAGS:
            self._skip_depth += 1
        elif tag == "title":
            self._in_title = True
        elif tag in HEADING_TAGS:
            self._heading_tag = tag
            self._heading_buf = []

    def handle_endtag(self, tag: str) -> None:
        if tag in SKIP_TAGS:
            self._skip_depth = max(0, self._skip_depth - 1)
        elif tag == "title":
            self._in_title = False
        elif tag == self._heading_tag:
            heading = _squash(" ".join(self._heading_buf))
            self.segments.append((heading, []))
            self._heading_tag = None
            self._heading_buf = []

    def handle_data(self, data: str) -> None:
        if self._skip_depth:
            return
        if self._in_title:
            self.title += data
        elif self._heading_tag:
            self._heading_buf.append(data)
        elif data.strip():
            self.segments[-1][1].append(data)


def _squash(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _hard_wrap(text: str) -> list[str]:
    """Last-resort split on word boundaries.

    Needed for pages that are one long table: they carry no sentence
    punctuation, so the sentence splitter returns a single huge piece.
    """
    out: list[str] = []
    buf = ""
    for word in text.split(" "):
        if buf and len(buf) + len(word) + 1 > MAX_CHARS:
            out.append(buf)
            buf = word
        else:
            buf = f"{buf} {word}".strip()
    if buf:
        out.append(buf)
    return out


def _split_long(text: str) -> list[str]:
    """Split an over-long section at sentence, then word, boundaries."""
    if len(text) <= MAX_CHARS:
        return [text]
    out: list[str] = []
    buf = ""
    for piece in re.split(r"(?<=[.!?])\s+", text):
        if buf and len(buf) + len(piece) + 1 > MAX_CHARS:
            out.append(buf)
            buf = piece
        else:
            buf = f"{buf} {piece}".strip()
    if buf:
        out.append(buf)
    return [part for chunk in out for part in _hard_wrap(chunk)]


def html_segments(raw: str) -> tuple[str, list[tuple[str, str]]]:
    parser = TextExtractor()
    parser.feed(raw)
    parser.close()
    segments = [
        (heading, _squash(" ".join(body)))
        for heading, body in parser.segments
        if _squash(" ".join(body)) or heading
    ]
    return _squash(parser.title), segments


def md_segments(raw: str) -> tuple[str, list[tuple[str, str]]]:
    """Split Markdown on ATX headings; the first h1 becomes the title."""
    title = ""
    segments: list[tuple[str, str]] = []
    heading = ""
    body: list[str] = []
    in_fence = False
    for line in raw.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        m = None if in_fence else re.match(r"^(#{1,4})\s+(.*)$", line)
        if m:
            text = _squash(" ".join(body))
            if text or heading:
                segments.append((heading, text))
            heading = _squash(m.group(2))
            body = []
            if not title and len(m.group(1)) == 1:
                title = heading
        else:
            body.append(line)
    text = _squash(" ".join(body))
    if text or heading:
        segments.append((heading, text))
    return title, segments


def in_scope(path: Path) -> bool:
    return (
        not EXCLUDE_PARTS.intersection(path.parts)
        and path.name not in EXCLUDE_NAMES
    )


def collect() -> list[Chunk]:
    chunks: list[Chunk] = []
    for kind, directory, pattern in SOURCES:
        root = REPO / directory
        if not root.exists():
            print(f"  ! {directory} missing, skipped", file=sys.stderr)
            continue
        for file in sorted(root.glob(pattern)):
            if not file.is_file() or not in_scope(file.relative_to(REPO)):
                continue
            raw = file.read_text(encoding="utf-8", errors="replace")
            rel = str(file.relative_to(REPO))
            title, segments = (
                md_segments(raw) if file.suffix == ".md" else html_segments(raw)
            )
            title = title or file.stem
            order = 0
            for heading, text in segments:
                if not text:
                    continue
                for part in _split_long(text):
                    if len(part) < 40 and not heading:
                        continue
                    digest = hashlib.sha1(
                        f"{rel}:{order}".encode()
                    ).hexdigest()[:20]
                    chunks.append(
                        Chunk(
                            id=digest,
                            path=rel,
                            kind=kind,
                            title=title,
                            heading=heading,
                            text=part,
                            folded=fold(f"{title} {heading} {part}"),
                            order=order,
                        )
                    )
                    order += 1
    return chunks


def master_key() -> str:
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("MEILI_MASTER_KEY="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"MEILI_MASTER_KEY not found in {ENV_FILE}")


def request(method: str, path: str, key: str, payload=None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{MEILI_URL}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        raise SystemExit(
            f"{method} {path} failed: {exc.code} {exc.read().decode('utf-8')[:400]}"
        ) from exc
    return json.loads(body) if body else {}


def await_task(task_uid: int, key: str, label: str) -> None:
    for _ in range(120):
        task = request("GET", f"/tasks/{task_uid}", key)
        status = task.get("status")
        if status == "succeeded":
            return
        if status == "failed":
            raise SystemExit(f"{label} failed: {task.get('error')}")
        time.sleep(0.5)
    raise SystemExit(f"{label} did not finish in time")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="report, send nothing")
    args = ap.parse_args()

    print("Collecting …")
    chunks = collect()
    by_kind: dict[str, int] = {}
    files: set[str] = set()
    for chunk in chunks:
        by_kind[chunk.kind] = by_kind.get(chunk.kind, 0) + 1
        files.add(chunk.path)
    total_chars = sum(len(c.text) for c in chunks)
    print(f"  {len(files)} files → {len(chunks)} chunks, {total_chars // 1024} KB of text")
    for kind, count in sorted(by_kind.items()):
        print(f"    {kind:11} {count:5} chunks")

    if args.dry_run:
        widest = max(chunks, key=lambda c: len(c.text))
        print(f"\n  longest chunk: {len(widest.text)} chars in {widest.path}")
        print(f"  sample: {chunks[0].path} · {chunks[0].heading!r}")
        print(f"          {chunks[0].text[:160]}…")
        return

    key = master_key()
    print("\nConfiguring index …")
    task = request("PATCH", f"/indexes/{INDEX}/settings", key, {
        # `folded` last: it only decides matches an accented query
        # would have missed, and never outranks a real hit.
        "searchableAttributes": ["title", "heading", "text", "folded"],
        "filterableAttributes": ["kind", "path"],
        "sortableAttributes": ["order"],
        "displayedAttributes": ["path", "kind", "title", "heading", "text", "order"],
        # One hit per document, not one per chunk. A long section splits into
        # several chunks that share a heading, and without this the same page
        # fills the whole result list.
        "distinctAttribute": "path",
        # Measured 2026-09-16: asked as a sentence, "when must I re-index the
        # documentation search" ranked an unrelated handover at 0.86 and missed
        # the page that defines the rule, while the keywords "re-index
        # documentation" scored it 0.99. Meilisearch's first ranking rule counts
        # matched query words, so "when", "must", "I" and "the" were deciding
        # the outcome. Excluding them makes a question behave like its keywords.
        "stopWords": STOP_WORDS,
    })
    await_task(task["taskUid"], key, "settings")

    print(f"Posting {len(chunks)} chunks …")
    for start in range(0, len(chunks), BATCH):
        batch = [asdict(c) for c in chunks[start:start + BATCH]]
        task = request("PUT", f"/indexes/{INDEX}/documents", key, batch)
        await_task(task["taskUid"], key, f"batch at {start}")
        print(f"  {min(start + BATCH, len(chunks))}/{len(chunks)}")

    stats = request("GET", f"/indexes/{INDEX}/stats", key)
    print(f"\nIndexed. {stats.get('numberOfDocuments')} documents in '{INDEX}'.")


if __name__ == "__main__":
    main()
