#!/usr/bin/env python3
"""A CI job's section of the run's Summary page: its checks, its counts, what failed.

A CI run's page showed only its job boxes, so finding the failing test meant opening a
log. Each job in ci.yml ends with a step, `if: always()`, that runs this script and
appends what it prints to $GITHUB_STEP_SUMMARY. It reads only what the tools already
write:

    --check LABEL=OUTCOME   a step's outcome (success, failure, cancelled, skipped)
    --junit FILE            pytest's JUnit XML (`pytest --junitxml=FILE`)
    --tap FILE              pg_prove's output (`supabase test db | tee FILE`)
    --gates FILE            scripts/check-coherence.sh's output

A file that is missing means the step that writes it never ran. The JUnit file is
pytest's own output from an earlier step of the same job, never outside input, and the
standard library's ElementTree fetches no external entity, so no third-party XML parser
is needed in a job that installs nothing. Every text goes through
scripts/github_text.py, as the Release notes do; past BUDGET a list gives names only,
then a count, since GitHub takes at most 1 MiB per step. Vitest writes its own summary
(frontend/vite.config.ts).

Plan: doc/plans/ci-test-summaries-2026-11-01.html (C1–C3 A). Tests: CISUM.01–07.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

from github_text import text

BUDGET = 900_000
MARK = {"success": "✅", "failure": "❌", "cancelled": "⛔"}
SUITE_PATH = re.compile(r"(supabase/tests/\S+\.sql)")
PROGRESS = re.compile(r"^\s*(\S+\.sql) \.+\s*(ok)?\s*$")
FAILED_TEST = re.compile(r'^# Failed test (\d+): "(.*)"\s*$')
PLANNED = re.compile(r"^# Looks like you planned (\d+) tests? but ran (\d+)")
REPORT_ENTRY = re.compile(r"^(\S+\.sql)\s+\(Wstat: .*?Tests: (\d+) Failed: (\d+)\)")
TOTALS = re.compile(r"^Files=(\d+), Tests=(\d+),\s+(\d+) wallclock secs")
GATE = re.compile(r"^--- Gate \d+: (.*?) ---$")
VERDICT = re.compile(r"^\s{2}(PASS|FAIL): (.*)$")


def _check_line(pairs: list[str]) -> str:
    """Each step's outcome, in the order given."""
    items: list[str] = []
    for pair in pairs:
        label, _, outcome = pair.partition("=")
        if outcome in MARK:
            note = " (cancelled)" if outcome == "cancelled" else ""
            items.append(f"{MARK[outcome]} {text(label)}{note}")
        else:
            items.append(f"⏭️ {text(label)} (did not run)")
    return f"<p>{' · '.join(items)}</p>\n\n" if items else ""


def _first_line(message: str) -> str:
    for line in message.splitlines():
        if line.strip():
            return line.strip()[:300]
    return ""


def _number(n: int) -> str:
    return f"{n:,}"


def _rows(rows: list[tuple[str, str]], head: tuple[str, str], budget: int) -> str:
    """A table of (name, detail) rows; past `budget` bytes names only, then a count."""
    out = f"<table><thead><tr><th>{head[0]}</th><th>{head[1]}</th></tr></thead><tbody>\n"
    full = True
    limit = budget + budget // 20
    for index, (name, detail) in enumerate(rows):
        row = (
            f"<tr><td><code>{text(name)}</code></td><td>{text(detail) if full else ''}</td></tr>\n"
        )
        if full and len((out + row).encode("utf-8")) > budget:
            full = False
            out += '<tr><td colspan="2"><i>From here on, ids only: GitHub takes at most 1 MiB per step.</i></td></tr>\n'
            row = f"<tr><td><code>{text(name)}</code></td><td></td></tr>\n"
        if len((out + row).encode("utf-8")) > limit:
            out += f'<tr><td colspan="2"><i>…and {len(rows) - index} more.</i></td></tr>\n'
            break
        out += row
    return out + "</tbody></table>\n\n"


def junit_section(path: Path, label: str, budget: int = BUDGET) -> str:
    if not path.is_file():
        return f"<p>⏭️ {text(label)}: the tests did not run (a step before them stopped)</p>\n\n"
    root = ET.parse(path).getroot()
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
    seconds = sum(float(s.get("time", 0) or 0) for s in suites)
    counts = {"passed": 0, "failed": 0, "error": 0, "skipped": 0}
    failing: list[tuple[str, str]] = []
    for case in root.iter("testcase"):
        test_id = f"{case.get('classname', '')}::{case.get('name', '')}"
        outcome = next((c for c in case if c.tag in ("failure", "error", "skipped")), None)
        if outcome is None:
            counts["passed"] += 1
            continue
        kind = {"failure": "failed", "error": "error", "skipped": "skipped"}[outcome.tag]
        counts[kind] += 1
        if kind != "skipped":
            failing.append((test_id, _first_line(outcome.get("message") or outcome.text or "")))
    parts = []
    if counts["failed"]:
        parts.append(f"{_number(counts['failed'])} failed")
    if counts["error"]:
        parts.append(f"{_number(counts['error'])} error{'s' if counts['error'] > 1 else ''}")
    parts.append(f"{_number(counts['passed'])} passed")
    if counts["skipped"]:
        parts.append(f"{_number(counts['skipped'])} skipped")
    mark = "❌" if failing else "✅"
    out = f"<p>{mark} {text(label)}: {', '.join(parts)} ({seconds:.1f} s)</p>\n\n"
    if failing:
        out += _rows(failing, ("Test", "First error line"), budget)
    return out


@dataclass
class TapRun:
    files: int = 0
    tests: int = 0
    seconds: int = 0
    result: str = ""
    descriptions: dict[str, dict[str, str]] = field(default_factory=dict)
    short: list[tuple[str, int, int]] = field(default_factory=list)
    failed: list[tuple[str, int, int, list[str]]] = field(default_factory=list)


def _suite(path: str) -> str:
    found = SUITE_PATH.search(path)
    return found.group(1) if found else path


def parse_tap(raw: str) -> TapRun:
    run = TapRun()
    current = ""
    in_report = False
    for line in raw.splitlines():
        if line.strip() == "Test Summary Report":
            in_report = True
            continue
        totals = TOTALS.match(line)
        if totals:
            run.files, run.tests, run.seconds = (int(g) for g in totals.groups())
            in_report = False
            continue
        if line.startswith("Result: "):
            run.result = line.partition(": ")[2].strip()
            continue
        if in_report:
            entry = REPORT_ENTRY.match(line.strip())
            if entry:
                run.failed.append(
                    (_suite(entry.group(1)), int(entry.group(2)), int(entry.group(3)), [])
                )
            elif run.failed and line.startswith("  ") and line.strip():
                run.failed[-1][3].append(line.strip())
            continue
        progress = PROGRESS.match(line)
        if progress:
            current = _suite(progress.group(1))
            continue
        failed = FAILED_TEST.match(line)
        if failed and current:
            run.descriptions.setdefault(current, {})[failed.group(1)] = failed.group(2)
            continue
        planned = PLANNED.match(line)
        if planned and current:
            run.short.append((current, int(planned.group(1)), int(planned.group(2))))
    return run


def _numbers(spec: str) -> list[str]:
    """pg_prove's "2, 5-7" as ["2", "5", "6", "7"]."""
    numbers: list[str] = []
    for part in spec.replace(" ", "").split(","):
        low, _, high = part.partition("-")
        if low.isdigit() and high.isdigit():
            numbers += [str(n) for n in range(int(low), int(high) + 1)]
        elif low.isdigit():
            numbers.append(low)
    return numbers


def tap_section(path: Path, label: str, budget: int = BUDGET) -> str:
    if not path.is_file():
        return f"<p>⏭️ {text(label)}: the tests did not run (a step before them stopped)</p>\n\n"
    run = parse_tap(path.read_text(encoding="utf-8", errors="replace"))
    if not run.result:
        return (
            f"<p>❌ {text(label)}: pg_prove stopped before its summary; see the step's log</p>\n\n"
        )
    out = ""
    if run.result == "PASS" and not run.failed and run.short:
        out += (
            f"<p>❌ {text(label)}: {_number(run.tests)} assertions in {_number(run.files)} files passed, "
            f"but {_number(len(run.short))} file(s) ran a different number than planned ({run.seconds} s)</p>\n\n"
        )
    elif run.result == "PASS" and not run.failed:
        out += (
            f"<p>✅ {text(label)}: {_number(run.tests)} assertions in {_number(run.files)} files, "
            f"all passed ({run.seconds} s)</p>\n\n"
        )
    else:
        failed_tests = sum(f[2] for f in run.failed)
        out += (
            f"<p>❌ {text(label)}: {_number(failed_tests)} of {_number(run.tests)} assertions failed, "
            f"in {_number(len(run.failed))} of {_number(run.files)} files ({run.seconds} s)</p>\n\n"
        )
        rows: list[tuple[str, str]] = []
        for suite, tests, _, notes in run.failed:
            details: list[str] = []
            listed = run.descriptions.get(suite, {})
            for note in notes:
                if note.startswith("Failed test"):
                    for number in _numbers(note.partition(":")[2]):
                        description = listed.get(number, "")
                        details.append(
                            f'test {number} of {tests}: "{description}"'
                            if description
                            else f"test {number} of {tests}"
                        )
                else:
                    details.append(note)
            rows.append((suite, "; ".join(details)))
        out += _rows(rows, ("File", "Failed"), budget)
    # pg_prove calls such a file ok; scripts/check_pgtap_plans.py fails it (plan F1 A).
    for suite, planned, ran in run.short:
        out += f"<p>❌ <code>{text(suite)}</code> planned {planned} tests but ran {ran}</p>\n\n"
    return out


def gates_section(path: Path, label: str) -> str:
    if not path.is_file():
        return f"<p>⏭️ {text(label)}: the checks did not run (a step before them stopped)</p>\n\n"
    lines: list[str] = []
    gate = ""
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        heading = GATE.match(line.strip())
        if heading:
            gate = heading.group(1)
            continue
        verdict = VERDICT.match(line)
        if verdict and gate:
            mark = "✅" if verdict.group(1) == "PASS" else "❌"
            lines.append(f"{mark} {text(gate)}: {text(verdict.group(2))}")
            continue
        if line.startswith("    ") and line.strip() and lines and gate:
            lines.append(f"&nbsp;&nbsp;&nbsp;&nbsp;<code>{text(line.strip())}</code>")
    if not lines:
        return f"<p>❌ {text(label)}: no gate result in the output; see the step's log</p>\n\n"
    return "<p>" + "<br>\n".join(lines) + "</p>\n\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="A CI job's section of the run's Summary page.")
    parser.add_argument("--title", required=True)
    parser.add_argument("--check", action="append", default=[], metavar="LABEL=OUTCOME")
    parser.add_argument("--junit", type=Path)
    parser.add_argument("--tap", type=Path)
    parser.add_argument("--gates", type=Path)
    args = parser.parse_args(argv)

    out = f"### {text(args.title)}\n\n" + _check_line(args.check)
    if args.tap:
        out += tap_section(args.tap, "pgTAP")
    if args.junit:
        out += junit_section(args.junit, "pytest")
    if args.gates:
        out += gates_section(args.gates, args.title)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
