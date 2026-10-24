"""GATE.01–06 — static checks are hard gates, and they cover the whole tree.

doc/plans/ftl-seed-email-removal-2026-10-24.html § 13 (24 Oct 2026). postgrestools
used to be a per-file reminder, then a preflight gate that `--fast` skipped and
that passed with exit 0 when the database was down: with no connection it
silently drops type checking and plpgsql_check. Ruff and BasedPyright checked
`python/` and four hand-picked scripts, so `scripts/` and `tools/` drifted.
svelte-check ran only in preflight, so CI let a frontend type error through.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
PREFLIGHT = (ROOT / "scripts/preflight.sh").read_text()
GATE = ROOT / "scripts/check-postgrestools.sh"
CI = ROOT / ".github/workflows/ci.yml"
PY_PATHS = "python/ scripts/ tools/"
# The version is read from the config's $schema URL (literal or regex-escaped).
PIN_FROM_CONFIG = re.compile(r"pg-language-server\\?\.com")


def _ci_steps(job: str) -> list[dict[str, str]]:
    return yaml.safe_load(CI.read_text())["jobs"][job]["steps"]


def _pinned_version() -> str:
    config = (ROOT / "postgres-language-server.jsonc").read_text()
    m = re.search(r"pg-language-server\.com/([0-9.]+)/schema\.json", config)
    assert m, "postgres-language-server.jsonc must pin its schema version"
    return m.group(1)


def test_GATE_01_preflight_never_skips_postgrestools():
    assert 'gate "postgrestools' in PREFLIGHT
    assert "bash scripts/check-postgrestools.sh" in PREFLIGHT
    # It sits with the CI gates, before any mode-dependent block, so neither
    # --fast nor --ci-only can drop it; --fast skips pgTAP alone.
    gate_at = PREFLIGHT.index("bash scripts/check-postgrestools.sh")
    assert gate_at < PREFLIGHT.index("if [[ $CI_ONLY -eq 0 ]]")
    fast_blocks = re.findall(r"if \[\[ \$FAST -eq 1 \]\]; then(.*?)fi\n", PREFLIGHT, re.S)
    assert fast_blocks, "the --fast branch must still exist"
    for block in fast_blocks:
        assert "postgrestools" not in block, block


def test_GATE_02_the_gate_proves_the_database_checks_ran():
    script = GATE.read_text()
    assert "--error-on-warnings" in script
    assert "--max-diagnostics=none" in script
    assert "supabase/migrations supabase/tests" in script
    # Positive controls: a planted missing column (type checking), a planted
    # error in a PL/pgSQL body (plpgsql_check) and a pgTAP call (pgTAP in the
    # search path) must each come out as expected, or the gate fails.
    assert "txt_pgt_canary_missing" in script
    assert "plpgsql_check" in script
    assert "plan(1)" in script
    # The pinned version and an exact file count: an upgrade or a config
    # ignore cannot silently change what is checked.
    assert PIN_FROM_CONFIG.search(script)
    assert re.search(r"Checked", script)


def test_GATE_03_ci_runs_the_same_gate_on_the_database_job():
    steps = _ci_steps("test-db")
    runs = [s.get("run", "") for s in steps]
    start = next(i for i, r in enumerate(runs) if "supabase start" in r)
    gate = next(i for i, r in enumerate(runs) if "bash scripts/check-postgrestools.sh" in r)
    install = next(i for i, r in enumerate(runs) if "@postgrestools/postgrestools@" in r)
    assert start < gate and install < gate
    # Installed at exactly the version the config pins.
    assert PIN_FROM_CONFIG.search(runs[install]) or _pinned_version() in runs[install]


def test_GATE_04_ruff_and_basedpyright_cover_all_python():
    runs = " ".join(s.get("run", "") for s in _ci_steps("test-python"))
    assert f"ruff check {PY_PATHS}" in runs
    assert f"ruff format --check {PY_PATHS}" in runs
    assert f"basedpyright {PY_PATHS}" in runs
    assert "PYTOOL_PATHS=(python/ scripts/ tools/)" in PREFLIGHT


def test_GATE_05_svelte_check_warnings_fail_preflight():
    # svelte-check exits 0 on warnings unless told otherwise.
    assert "npm run check -- --fail-on-warnings" in PREFLIGHT
    # It reads tsconfig.json, which now includes both Vite configs: the main
    # one had a type error (its `test` block, TS2769) that nothing checked.
    include = json.loads((ROOT / "frontend/tsconfig.json").read_text())["include"]
    assert "vite.config.ts" in include and "vite.config.ce.ts" in include


def test_GATE_06_ci_runs_svelte_check_with_warnings_as_errors():
    steps = _ci_steps("test-frontend")
    runs = [s.get("run", "") for s in steps]
    install = next(i for i, r in enumerate(runs) if "npm ci" in r)
    check = next(
        (i for i, r in enumerate(runs) if "npm run check -- --fail-on-warnings" in r), None
    )
    assert check is not None, "CI's frontend job must run svelte-check, warnings failing"
    assert install < check
    assert steps[check].get("working-directory") == "frontend"
