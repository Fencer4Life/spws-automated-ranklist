"""WP.REL.01 — the release fills each published page with its host's environment.

ADR-109 (FR-151); plan doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html
§03, §05. github.io is CERT and WordPress is PROD, so the Release workflow injects:

- index.html: both pairs (CERT to work on, PROD for the read-only promotion state);
- the root calculator and annex (github.io): CERT only;
- their embed/ copies (framed on WordPress): PROD only;
- register.html: PROD only, as today (fencers hold links to it).

A guard step then fails the build if an embed/ copy carries the CERT pair.

These tests RUN the workflow's own injection script and guard script, taken from
release.yml, against throwaway copies of the files, with the secrets replaced by
markers. `sed -i` differs between GNU (CI) and BSD (macOS), so a small shim on
PATH applies the workflow's `sed -i 's|…|…|' FILE…` lines the same way on both.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import textwrap
from pathlib import Path
from typing import Any

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/release.yml"
FRONTEND = ROOT / "frontend"

SECRETS = {
    "SUPABASE_CERT_URL": "https://cert-marker.supabase.co",
    "SUPABASE_CERT_ANON_KEY": "cert-anon-marker",
    "SUPABASE_PROD_URL": "https://prod-marker.supabase.co",
    "SUPABASE_PROD_ANON_KEY": "prod-anon-marker",
}
CERT = (SECRETS["SUPABASE_CERT_URL"], SECRETS["SUPABASE_CERT_ANON_KEY"])
PROD = (SECRETS["SUPABASE_PROD_URL"], SECRETS["SUPABASE_PROD_ANON_KEY"])
NONE = ("", "")

ROOT_DOCS = ("public/kalkulator-punktow.html", "public/tabela-punktacji.html")
EMBED_DOCS = ("public/embed/kalkulator-punktow.html", "public/embed/tabela-punktacji.html")

SED_SHIM = textwrap.dedent(
    """\
    #!/usr/bin/env python3
    # Applies `sed -i 's|PATTERN|REPLACEMENT|' FILE...` the way GNU sed does:
    # the first match on each line, no flags.
    import re, sys
    args = sys.argv[1:]
    assert args and args[0] == "-i", args
    expr, files = args[1], args[2:]
    assert expr.startswith("s|") and expr.endswith("|"), expr
    pattern, replacement = expr[2:-1].split("|")
    for name in files:
        with open(name, encoding="utf-8") as fh:
            lines = fh.read().split("\\n")
        lines = [re.sub(pattern, lambda _m: replacement, line, count=1) for line in lines]
        with open(name, "w", encoding="utf-8") as fh:
            fh.write("\\n".join(lines))
    """
)


def _build_steps() -> list[dict[str, Any]]:
    workflow = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    for job in workflow["jobs"].values():
        steps = job.get("steps", [])
        if any("Build frontend" == s.get("name") for s in steps):
            return steps
    raise AssertionError("release.yml has no job with a 'Build frontend' step")


def _with_markers(script: str) -> str:
    def secret(match: re.Match[str]) -> str:
        return SECRETS.get(match.group(1), f"UNKNOWN-{match.group(1)}")

    return re.sub(r"\$\{\{\s*secrets\.([A-Z0-9_]+)\s*\}\}", secret, script)


def _run(script: str, cwd: Path, shim_dir: Path) -> subprocess.CompletedProcess[str]:
    env = {**os.environ, "PATH": f"{shim_dir}{os.pathsep}{os.environ['PATH']}"}
    return subprocess.run(
        ["bash", "-e", "-c", _with_markers(script)],
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
    )


@pytest.fixture
def shim(tmp_path: Path) -> Path:
    shim_dir = tmp_path / "shim"
    shim_dir.mkdir()
    sed = shim_dir / "sed"
    sed.write_text(SED_SHIM, encoding="utf-8")
    sed.chmod(0o755)
    return shim_dir


def _env_pair(html: str, prefix: str) -> tuple[str, str]:
    """(url, key) from either the custom-element attributes or the #spws-env div."""
    url = re.search(rf'{prefix}-url="([^"]*)"', html)
    key = re.search(rf'{prefix}-key="([^"]*)"', html)
    assert url and key, f"no {prefix}-url/-key attributes"
    return url.group(1), key.group(1)


@pytest.fixture
def injected(tmp_path: Path, shim: Path) -> Path:
    """A throwaway frontend/ after the workflow's injection steps ran over it."""
    work = tmp_path / "frontend"
    for rel in ("index.html", "register.html", *ROOT_DOCS):
        (work / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(FRONTEND / rel, work / rel)
    # The embed/ copies are generated (WP.DOC.03); if they are not there yet, a
    # root copy stands in — the injection works on the #spws-env attributes only.
    for rel, stand_in in zip(EMBED_DOCS, ROOT_DOCS, strict=True):
        (work / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(
            FRONTEND / rel if (FRONTEND / rel).is_file() else FRONTEND / stand_in, work / rel
        )

    ran = 0
    for step in _build_steps():
        if step.get("name") == "Build frontend":
            break
        run = step.get("run", "")
        if "sed -i" in run and step.get("working-directory") == "frontend":
            result = _run(run, work, shim)
            assert result.returncode == 0, result.stderr
            ran += 1
    assert ran >= 1, "no injection step before 'Build frontend'"
    return work


def test_wp_rel_01_index_keeps_both_pairs(injected: Path) -> None:
    """WP.REL.01 — github.io works on CERT and reads PROD for the promotion state."""
    html = (injected / "index.html").read_text(encoding="utf-8")
    assert _env_pair(html, "supabase-cert") == CERT
    assert _env_pair(html, "supabase-prod") == PROD


@pytest.mark.parametrize("rel", ROOT_DOCS)
def test_wp_rel_01_root_documents_are_cert(injected: Path, rel: str) -> None:
    """WP.REL.01 — the github.io calculator and annex are CERT copies (ADR-109)."""
    html = (injected / rel).read_text(encoding="utf-8")
    assert _env_pair(html, "data-supabase-cert") == CERT
    assert _env_pair(html, "data-supabase-prod") == NONE


@pytest.mark.parametrize("rel", EMBED_DOCS)
def test_wp_rel_01_embed_documents_are_prod(injected: Path, rel: str) -> None:
    """WP.REL.01 — the copies WordPress frames are PROD copies, and only PROD."""
    html = (injected / rel).read_text(encoding="utf-8")
    assert _env_pair(html, "data-supabase-cert") == NONE
    assert _env_pair(html, "data-supabase-prod") == PROD


def test_wp_rel_01_register_stays_prod_only(injected: Path) -> None:
    """WP.REL.01 — register.html keeps exactly one environment: PROD (ADR-079 §6)."""
    html = (injected / "register.html").read_text(encoding="utf-8")
    assert _env_pair(html, "supabase-cert") == NONE
    assert _env_pair(html, "supabase-prod") == PROD


def _guard_step() -> dict[str, Any]:
    names = [s.get("name", "") for s in _build_steps()]
    build = names.index("Build frontend")
    guards = [s for s in _build_steps()[build:] if "dist/embed" in s.get("run", "")]
    assert len(guards) == 1, "exactly one step after the build must guard frontend/dist/embed/"
    return guards[0]


def _run_guard(tmp_path: Path, shim: Path, embed_html: str) -> subprocess.CompletedProcess[str]:
    step = _guard_step()
    repo = tmp_path / "repo"
    dist_embed = repo / "frontend/dist/embed"
    dist_embed.mkdir(parents=True)
    for name in ("kalkulator-punktow.html", "tabela-punktacji.html"):
        (dist_embed / name).write_text(embed_html, encoding="utf-8")
    cwd = repo / step["working-directory"] if step.get("working-directory") else repo
    return _run(step["run"], cwd, shim)


def test_wp_rel_01_guard_fails_an_embed_copy_with_cert(tmp_path: Path, shim: Path) -> None:
    """WP.REL.01 — the guard stops a release whose embed/ copy carries the CERT pair."""
    bad = (
        f'<div id="spws-env" hidden data-supabase-cert-url="{CERT[0]}" data-supabase-cert-key="{CERT[1]}" '
        f'data-supabase-prod-url="{PROD[0]}" data-supabase-prod-key="{PROD[1]}"></div>'
    )
    assert _run_guard(tmp_path, shim, bad).returncode != 0


def test_wp_rel_01_guard_passes_a_prod_only_embed_copy(tmp_path: Path, shim: Path) -> None:
    """WP.REL.01 — and lets a correct PROD-only copy through."""
    good = (
        '<div id="spws-env" hidden data-supabase-cert-url="" data-supabase-cert-key="" '
        f'data-supabase-prod-url="{PROD[0]}" data-supabase-prod-key="{PROD[1]}"></div>'
    )
    result = _run_guard(tmp_path, shim, good)
    assert result.returncode == 0, result.stdout + result.stderr
