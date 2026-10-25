"""FETOOL.00-05 — the front end's packages, read from frontend/package-lock.json.

T2 A, T1 A, T3 A and X1 A on doc/plans/frontend-toolchain-warnings-and-audit-2026-10-25.html
(25 Oct 2026). `npm audit` reported 15 findings, two of them critical, and every CI run
printed `npm warn deprecated whatwg-encoding@3.1.1`. The test runner (Vitest 1.6, jsdom 24)
and the build tools (Vite 5, vite-plugin-svelte 4) moved to current majors together:
Vitest 4, the first release without the critical tinypool, needs Vite 6 or later.

FETOOL.01 holds the lockfile outside every range those advisories named. A package with
no advisory of its own (vite-node, the Svelte plugin, its inspector) was flagged only
for a dependency, which the table covers. A later advisory is read from `npm audit` and
added here.

FETOOL.03 is why jsdom stops at 29 and Vitest at 4: jsdom 30 needs Node ^24.15.0 and
Vitest 5 leaves out Node 25. Each engine range must accept the first release of the
Node line the workflows set up (WFNODE.01), so a minor Node update can never break CI.

FETOOL.04: npm's last xlsx is 0.18.5, inside both SheetJS advisories. SheetJS publishes
its fixed releases only on its own CDN; the lockfile pins the tarball by its sha512.

FETOOL.05: frontend/scripts/build-scoring-pages.mjs imported esbuild, which package.json
never declared; Vite 5 happened to install it, Vite 8 does not, and the preflight gate
"published pages match scoring.ts" failed. Every package a script imports is declared.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
FRONTEND = ROOT / "frontend"
WORKFLOWS = ROOT / ".github" / "workflows"

# Package -> (first affected, first fixed): the union of its own advisories in
# `npm audit`, 25 Oct 2026.
ADVISORY_RANGES = {
    "vitest": ("0.0.0", "3.2.6"),  # GHSA-5xrq-8626-4rwp, critical
    "tinypool": ("0.0.0", "2.1.2"),  # GHSA-85c8-ppgw-ccpr, GHSA-5gmw-xhrv-c9v3, critical
    "vite": ("0.0.0", "6.4.4"),  # GHSA-fx2h-pf6j-xcff, GHSA-587h-7wmj-h5pm and six more
    "esbuild": ("0.0.0", "0.25.0"),  # GHSA-67mh-4wv8-2f99
    "svelte": ("0.0.0", "5.55.7"),  # GHSA-rcqx-6q8c-2c42 and three more
    "devalue": ("0.0.0", "5.9.3"),  # GHSA-j22f-vq7h-c4qm and nine more
    "postcss": ("0.0.0", "8.5.23"),  # GHSA-6g55-p6wh-862q and three more
    "nanoid": ("0.0.0", "3.3.18"),  # GHSA-2v37-7h3g-55p8 and two more
    "source-map-js": ("1.0.0", "1.2.2"),  # GHSA-68fv-2mgg-jv7q
    "form-data": ("4.0.0", "4.0.6"),  # GHSA-hmw2-7cc7-3qxx
    "ws": ("8.0.0", "8.21.0"),  # GHSA-96hv-2xvq-fx4p, GHSA-58qx-3vcg-4xpx
    "xlsx": ("0.0.0", "0.20.2"),  # GHSA-4r6h-8v6p-xvw6, GHSA-5pgg-2g8v-p4x9
}

SHEETJS_XLSX = "https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz"


def _packages() -> dict[str, dict]:
    lock = json.loads((FRONTEND / "package-lock.json").read_text(encoding="utf-8"))
    return {path: entry for path, entry in lock["packages"].items() if path}


def _name(path: str) -> str:
    return path.rsplit("node_modules/", 1)[1]


def _version(text: str) -> tuple[int, int, int, int]:
    """(major, minor, patch, 0 for a prerelease else 1); missing parts are 0."""
    core, _, pre = text.strip().lstrip("v").partition("-")
    parts = [int(p) for p in core.split(".") if p not in ("", "x", "*")]
    major, minor, patch = (parts + [0, 0, 0])[:3]
    return (major, minor, patch, 0 if pre else 1)


def _satisfies(version: str, spec: str) -> bool:
    """npm's range grammar as the lockfile's `engines` use it: ||, comparators, ^ and ~."""
    v = _version(version)
    for alternative in spec.split("||"):
        tokens = re.sub(r"(>=|<=|>|<|=|\^|~)\s+", r"\1", alternative).split()
        if all(_comparator(v, token) for token in tokens):
            return True
    return False


def _comparator(v: tuple[int, int, int, int], token: str) -> bool:
    if token in ("*", "x"):
        return True
    op = next((o for o in (">=", "<=", ">", "<", "=", "^", "~") if token.startswith(o)), "")
    bound_text = token[len(op) :]
    given = len(
        [p for p in bound_text.lstrip("v").split("-")[0].split(".") if p not in ("", "x", "*")]
    )
    low = _version(bound_text)
    if op == ">=":
        return v >= low
    if op == ">":
        return v > low
    if op == "<=":
        return v <= low
    if op == "<":
        return v < low
    if op == "^":
        major, minor, patch, _ = low
        high = (
            (major + 1, 0, 0, 0)
            if major
            else (0, minor + 1, 0, 0)
            if minor
            else (0, 0, patch + 1, 0)
        )
        return low <= v < high
    if op == "~" or given < 3:
        major, minor, _, _ = low
        high = (major, minor + 1, 0, 0) if op == "~" or given == 2 else (major + 1, 0, 0, 0)
        return low <= v < high
    return v[:3] == low[:3]


def _ci_node_line() -> str:
    lines = {
        str((step.get("with") or {}).get("node-version"))
        for path in sorted(WORKFLOWS.glob("*.yml"))
        for job in (yaml.safe_load(path.read_text(encoding="utf-8")).get("jobs") or {}).values()
        for step in job.get("steps") or []
        if str(step.get("uses", "")).startswith("actions/setup-node@")
    }
    assert len(lines) == 1, lines
    return lines.pop()


def test_FETOOL_00_the_range_reader_reads_npm_ranges():
    assert _satisfies("24.0.0", "^20.19.0 || ^22.13.0 || >=24.0.0")
    assert not _satisfies("24.0.0", "^22.22.2 || ^24.15.0 || >=26.0.0")
    assert not _satisfies("25.0.0", "^22.12.0 || ^24.0.0 || >=26.0.0")
    assert _satisfies("24.0.0", ">= 14.16.0") and _satisfies("24.0.0", ">=v12.22.7")
    assert not _satisfies("24.0.0", "^18.0.0 || ^20.0.0") and _satisfies("20.3.0", "^20")
    assert (
        _satisfies("24.0.0", "*")
        and not _satisfies("3.0.0", "~2.1")
        and _satisfies("2.1.9", "~2.1")
    )
    assert _version("4.0.0-beta.19") < _version("4.0.0") < _version("4.0.1")


def test_FETOOL_01_no_package_is_in_a_range_npm_audit_reported():
    offenders = [
        f"{path}@{entry.get('version')}"
        for path, entry in _packages().items()
        if _name(path) in ADVISORY_RANGES
        and _version(ADVISORY_RANGES[_name(path)][0])
        <= _version(str(entry.get("version")))
        < _version(ADVISORY_RANGES[_name(path)][1])
    ]
    assert offenders == []


def test_FETOOL_02_no_whatwg_encoding_which_npm_reports_as_deprecated():
    assert [path for path in _packages() if _name(path) == "whatwg-encoding"] == []


def test_FETOOL_03_every_engine_range_accepts_the_node_line_ci_sets_up():
    node = f"{_ci_node_line()}.0.0"
    offenders = [
        f"{path}: {entry['engines']['node']}"
        for path, entry in _packages().items()
        if isinstance(entry.get("engines"), dict)
        and "node" in entry["engines"]
        and not _satisfies(node, entry["engines"]["node"])
    ]
    assert offenders == []


def test_FETOOL_04_xlsx_comes_from_sheetjs_pinned_by_its_hash():
    manifest = json.loads((FRONTEND / "package.json").read_text(encoding="utf-8"))
    assert manifest["dependencies"]["xlsx"] == SHEETJS_XLSX
    entry = _packages()["node_modules/xlsx"]
    assert entry["resolved"] == SHEETJS_XLSX
    assert str(entry.get("integrity", "")).startswith("sha512-")
    assert entry["version"] == "0.20.3"


def test_FETOOL_05_every_package_a_frontend_script_imports_is_declared():
    manifest = json.loads((FRONTEND / "package.json").read_text(encoding="utf-8"))
    declared = set(manifest.get("dependencies", {})) | set(manifest.get("devDependencies", {}))
    imported = {
        match.group(1)
        for script in sorted((FRONTEND / "scripts").glob("*.mjs"))
        for match in re.finditer(
            r"""(?:from|import)\s*\(?\s*['"]((?:@[\w.-]+/)?[\w.-]+)[^'"]*['"]""",
            script.read_text(encoding="utf-8"),
        )
        if not match.group(1).startswith("node")
    }
    assert imported - declared == set()
