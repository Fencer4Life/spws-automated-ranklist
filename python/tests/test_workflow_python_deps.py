"""WFDEPS.01 — every workflow job installs the packages its Python code imports.

A job that runs `python -m python.<module>` must `pip install` every third-party package
that module imports (anywhere in it, since its main runs) and every package the in-repo
modules it pulls in import when they load. A missing one fails only when the job runs:
scrape-tournament.yml never installed `supabase`, which its write path imports, and
promote.yml once lacked `bs4`. Imports inside a function of a pulled-in module, and
imports guarded by `except ImportError`, are not counted: they run only on some paths.
"""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
PIP_NAME = {"bs4": "beautifulsoup4", "yaml": "pyyaml"}
# Installed with another package (pip resolves them as its dependencies).
PROVIDED_BY = {
    "postgrest": "supabase",
    "gotrue": "supabase",
    "storage3": "supabase",
    "realtime": "supabase",
    "supafunc": "supabase",
}


def _module_file(module: str) -> Path | None:
    base = ROOT / module.replace(".", "/")
    for candidate in (base.with_suffix(".py"), base / "__init__.py"):
        if candidate.exists():
            return candidate
    return None


def _load_time(tree: ast.Module) -> list[ast.AST]:
    nodes: list[ast.AST] = []
    stack: list[ast.AST] = list(tree.body)
    while stack:
        node = stack.pop()
        nodes.append(node)
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            stack.extend(ast.iter_child_nodes(node))
    return nodes


def _imports(path: Path, entry: bool) -> tuple[set[str], set[str]]:
    """In-repo modules and third-party top-level names this file imports."""
    tree = ast.parse(path.read_text(encoding="utf-8"))
    guarded: set[int] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Try) and any(
            isinstance(h.type, ast.Name) and h.type.id in ("ImportError", "ModuleNotFoundError")
            for h in node.handlers
        ):
            guarded |= {id(n) for stmt in node.body for n in ast.walk(stmt)}
    local: set[str] = set()
    third: set[str] = set()
    for node in list(ast.walk(tree)) if entry else _load_time(tree):
        if id(node) in guarded:
            continue
        names: list[str] = []
        if isinstance(node, ast.Import):
            names = [alias.name for alias in node.names]
        elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
            names = [node.module, *(f"{node.module}.{alias.name}" for alias in node.names)]
        for name in names:
            top = name.split(".")[0]
            if top == "python":
                if _module_file(name):
                    local.add(name)
            elif top not in sys.stdlib_module_names and top != "__future__":
                third.add(top)
    return local, third


def _needed(entry: str) -> set[str]:
    seen: set[str] = set()
    todo = [entry]
    third: set[str] = set()
    while todo:
        module = todo.pop()
        if module in seen:
            continue
        seen.add(module)
        parts = module.split(".")
        todo += [".".join(parts[:i]) for i in range(1, len(parts))]
        path = _module_file(module)
        if path:
            local, names = _imports(path, entry=module == entry)
            third |= names
            todo += sorted(local - seen)
    return {PROVIDED_BY.get(n, PIP_NAME.get(n, n)).lower() for n in third}


def _jobs() -> list[tuple[str, str, list[str], set[str]]]:
    jobs: list[tuple[str, str, list[str], set[str]]] = []
    for path in sorted(WORKFLOWS.glob("*.yml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8"))
        for name, job in (spec.get("jobs") or {}).items():
            runs = "\n".join(step.get("run", "") for step in job.get("steps") or [])
            modules = sorted(set(re.findall(r"python3? -m (python\.[\w.]+)", runs)))
            installed = {
                w.lower()
                for m in re.finditer(r"pip install ([^\n]+)", runs)
                for w in m.group(1).split()
                if not w.startswith("-")
            }
            if modules:
                jobs.append((path.name, name, modules, installed))
    return jobs


def test_WFDEPS_01_every_job_installs_what_its_python_imports():
    jobs = _jobs()
    assert len(jobs) >= 15
    missing = {
        f"{file}:{job}": sorted(set().union(*(_needed(m) for m in modules)) - installed)
        for file, job, modules, installed in jobs
    }
    assert {k: v for k, v in missing.items() if v} == {}
