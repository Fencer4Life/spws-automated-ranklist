"""CISUM.01–07 — every CI run's Summary page shows each job's results and names what failed.

A CI run's page showed four job boxes and their times. On 18 Oct 2026 (CI 39112045045)
the one failing pgTAP assertion, test 2 of 03_views_api.sql, was a line in a 997-line
log. Plan doc/plans/ci-test-summaries-2026-11-01.html (C1–C4 A, NFR-17):
scripts/ci_summary.py turns what each tool already writes (pytest's JUnit file,
pg_prove's output, the coherence gates' lines, each step's outcome) into the job's
section of the Summary page, escaped by the helper the Release notes use
(scripts/github_text.py). Vitest writes its own summary, pinned in its config.

The fixtures follow each tool's real format, pg_prove's as 18 Oct's red run printed
it; the workflow tests read ci.yml and frontend/vite.config.ts.
"""

from __future__ import annotations

import importlib.util
import re
import subprocess
import sys
from pathlib import Path
from types import ModuleType
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "scripts"
SUMMARY = SCRIPTS / "ci_summary.py"
CI = ROOT / ".github" / "workflows" / "ci.yml"
VITE_CONFIG = ROOT / "frontend" / "vite.config.ts"
MIB = 1024 * 1024
RUNNER = "/home/runner/work/spws-automated-ranklist/spws-automated-ranklist"

JUNIT_RED = """<?xml version="1.0" encoding="utf-8"?>
<testsuites name="pytest tests"><testsuite name="pytest" errors="1" failures="1"
skipped="1" tests="5" time="52.70" timestamp="2026-11-01T10:00:00" hostname="runner">
<testcase classname="python.tests.test_a" name="test_passes" time="0.01" />
<testcase classname="python.tests.test_a" name="test_also_passes" time="0.01" />
<testcase classname="python.tests.test_b" name="test_skipped" time="0.0">
<skipped type="pytest.skip" message="SUPABASE_ACCESS_TOKEN not set">skip</skipped></testcase>
<testcase classname="python.tests.test_c" name="test_fails[case-1]" time="0.2">
<failure message="AssertionError: assert 'x' in out&#10;second line">traceback</failure></testcase>
<testcase classname="python.tests.test_d" name="test_errors" time="0.0">
<error message="failed on setup with &quot;Management API error: 401&quot;">trace</error></testcase>
</testsuite></testsuites>
"""

JUNIT_GREEN = """<?xml version="1.0" encoding="utf-8"?>
<testsuites name="pytest tests"><testsuite name="pytest" errors="0" failures="0"
skipped="0" tests="3" time="1.04">
<testcase classname="python.tests.test_a" name="test_one" time="0.3" />
<testcase classname="python.tests.test_a" name="test_two" time="0.3" />
<testcase classname="python.tests.test_a" name="test_three" time="0.4" />
</testsuite></testsuites>
"""

# pg_prove ends a failing file's progress line, and its result line, with a space.
TAP_RED = f"""{RUNNER}/supabase/tests/01_database_foundation.sql .................. ok
{RUNNER}/supabase/tests/03_views_api.sql ..............................\x20
# Failed test 2: "5.1b vw_score has all required columns"
# Looks like you failed 1 test of 27
Failed 1/27 subtests\x20
{RUNNER}/supabase/tests/19_phase3_wizard.sql ..........................\x20
# Looks like you planned 25 tests but ran 5
ok
{RUNNER}/supabase/tests/41_sql_error.sql ..............................\x20
psql:supabase/tests/41_sql_error.sql:12: ERROR:  relation "tbl_missing" does not exist
Dubious, test returned 3 (wstat 768, 0x300)
All 5 subtests passed\x20
{RUNNER}/supabase/tests/99_seed_load_fencers.sql ...................... ok

Test Summary Report
-------------------
{RUNNER}/supabase/tests/03_views_api.sql                            (Wstat: 0 Tests: 27 Failed: 1)
  Failed test:  2
{RUNNER}/supabase/tests/41_sql_error.sql                            (Wstat: 768 (exited 3) Tests: 5 Failed: 0)
  Non-zero exit status: 3
  Parse errors: Bad plan.  You planned 25 tests but ran 5.
Files=112, Tests=1468,  9 wallclock secs ( 0.27 usr  0.14 sys +  0.70 cusr  0.44 csys =  1.55 CPU)
Result: FAIL
"""

TAP_GREEN = f"""{RUNNER}/supabase/tests/01_database_foundation.sql .................. ok
{RUNNER}/supabase/tests/99_seed_load_fencers.sql ...................... ok
All tests successful.
Files=124, Tests=1619,  8 wallclock secs ( 0.24 usr  0.10 sys +  0.74 cusr  0.28 csys =  1.36 CPU)
Result: PASS
"""

GATES = """=== Coherence checks ===
--- Gate 1: Version sync (pyproject.toml vs package.json) ---
  PASS: Both at v0.1.0

--- Gate 2: ADR file count vs spec Appendix C ---
  FAIL: 117 ADR files != 116 spec rows

--- Gate 3: pgTAP assertion count ---
  PASS: 1619 assertions match documented total

--- Gate 4: Migration ↔ documentation sync ---
  FAIL: migration(s) changed since 0123456789ab without a specification, ADR, governance or handbook change:
    supabase/migrations/20261101000001_x.sql
::error::Migration changed without a specification, ADR, governance or handbook update

=== Summary: 2 error(s) ===
FAILED — fix coherence errors before merging.
"""


def _summary(tmp_path: Path, *args: str, files: dict[str, str] | None = None) -> str:
    for name, content in (files or {}).items():
        (tmp_path / name).write_text(content, encoding="utf-8")
    completed = subprocess.run(
        [sys.executable, str(SUMMARY), *args],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    return completed.stdout


def _module(name: str) -> ModuleType:
    if str(SCRIPTS) not in sys.path:
        sys.path.insert(0, str(SCRIPTS))
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


# ─── pytest's JUnit file ─────────────────────────────────────────────


def test_CISUM_01_a_red_junit_file_names_each_failing_test(tmp_path: Path) -> None:
    out = _summary(
        tmp_path, "--title", "pytest", "--junit", "pytest.xml", files={"pytest.xml": JUNIT_RED}
    )
    assert "### pytest" in out
    assert "❌ pytest: 1 failed, 1 error, 2 passed, 1 skipped (52.7 s)" in out
    assert "<code>python.tests.test_c::test_fails[case-1]</code>" in out
    assert "AssertionError: assert 'x' in out" in out
    assert "second line" not in out and "traceback" not in out
    assert "<code>python.tests.test_d::test_errors</code>" in out
    assert 'failed on setup with "Management API error: 401"' in out
    assert "test_passes" not in out and "test_skipped" not in out


def test_CISUM_01_a_green_junit_file_gives_counts_only(tmp_path: Path) -> None:
    out = _summary(
        tmp_path, "--title", "pytest", "--junit", "pytest.xml", files={"pytest.xml": JUNIT_GREEN}
    )
    assert "✅ pytest: 3 passed (1.0 s)" in out
    assert "<table>" not in out


# ─── pg_prove's output ───────────────────────────────────────────────


def test_CISUM_02_a_red_pgtap_run_lists_each_failed_file(tmp_path: Path) -> None:
    out = _summary(tmp_path, "--title", "pgTAP", "--tap", "pgtap.out", files={"pgtap.out": TAP_RED})
    assert "❌ pgTAP: 1 of 1,468 assertions failed, in 2 of 112 files (9 s)" in out
    assert "<code>supabase/tests/03_views_api.sql</code>" in out
    assert 'test 2 of 27: "5.1b vw_score has all required columns"' in out
    assert "<code>supabase/tests/41_sql_error.sql</code>" in out
    assert "Non-zero exit status: 3" in out and "Bad plan." in out
    assert RUNNER not in out
    assert "01_database_foundation" not in out


def test_CISUM_02_a_file_that_ran_fewer_tests_than_planned_is_shown(tmp_path: Path) -> None:
    """pg_prove calls such a file ok; the summary says what pgTAP said, as a failure
    since plan F1 A made it one (CISUM.08)."""
    out = _summary(tmp_path, "--title", "pgTAP", "--tap", "pgtap.out", files={"pgtap.out": TAP_RED})
    assert "❌ <code>supabase/tests/19_phase3_wizard.sql</code> planned 25 tests but ran 5" in out


def test_CISUM_02_a_green_pgtap_run_shows_no_table(tmp_path: Path) -> None:
    out = _summary(
        tmp_path, "--title", "pgTAP", "--tap", "pgtap.out", files={"pgtap.out": TAP_GREEN}
    )
    assert "✅ pgTAP: 1,619 assertions in 124 files, all passed (8 s)" in out
    assert "<table>" not in out and "⚠️" not in out


# ─── Step outcomes, the coherence gates, and tests that never ran ────


def test_CISUM_03_steps_become_lines_in_order(tmp_path: Path) -> None:
    out = _summary(
        tmp_path,
        "--title", "pytest",
        "--check", "Ruff=success",
        "--check", "BasedPyright=failure",
        "--check", "check_docs=skipped",
        "--check", "Rendered docs=cancelled",
        "--junit", "pytest.xml",
    )  # fmt: skip
    ruff, pyright, docs = (
        out.index("✅ Ruff"),
        out.index("❌ BasedPyright"),
        out.index("check_docs"),
    )
    assert ruff < pyright < docs
    assert "⏭️ check_docs (did not run)" in out
    assert "⛔ Rendered docs (cancelled)" in out
    assert "⏭️ pytest: the tests did not run (a step before them stopped)" in out


def test_CISUM_03_each_coherence_gate_with_its_message(tmp_path: Path) -> None:
    out = _summary(
        tmp_path, "--title", "Coherence", "--gates", "coherence.out", files={"coherence.out": GATES}
    )
    assert "✅ Version sync (pyproject.toml vs package.json): Both at v0.1.0" in out
    assert "❌ ADR file count vs spec Appendix C: 117 ADR files != 116 spec rows" in out
    assert "supabase/migrations/20261101000001_x.sql" in out
    assert "::error::" not in out and "FAILED —" not in out
    assert out.index("Version sync") < out.index("Migration")


# ─── Plain text, through the helper the Release notes share ──────────


def test_CISUM_04_ids_and_messages_reach_github_as_plain_text(tmp_path: Path) -> None:
    junit = JUNIT_GREEN.replace(
        '<testcase classname="python.tests.test_a" name="test_one" time="0.3" />',
        '<testcase classname="python.tests.test_a" name="test_one[&lt;a&gt;&amp;@b#12]" time="0.3">'
        '<failure message="see #12 for @owner &lt;tag&gt; &amp; more">x</failure></testcase>',
    )
    out = _summary(
        tmp_path, "--title", "pytest", "--junit", "pytest.xml", files={"pytest.xml": junit}
    )
    assert "@" not in out
    assert re.search(r"(?<!&)#\d", out) is None
    assert "&lt;tag&gt; &amp; more" in out
    assert "<tag>" not in out


def test_CISUM_04_one_helper_escapes_both_pages() -> None:
    for page in ("ci_summary", "release_notes"):
        assert _module(page).text.__module__ == "github_text", page


# ─── GitHub's 1 MiB per step ─────────────────────────────────────────


def test_CISUM_05_three_thousand_failures_stay_under_one_mib(tmp_path: Path) -> None:
    cases = "".join(
        f'<testcase classname="python.tests.test_many" name="test_{n:04d}" time="0.1">'
        f'<failure message="AssertionError: {"x" * 400}">t</failure></testcase>'
        for n in range(3000)
    )
    junit = (
        '<?xml version="1.0" encoding="utf-8"?><testsuites><testsuite name="pytest" '
        f'errors="0" failures="3000" skipped="0" tests="3000" time="9.0">{cases}</testsuite></testsuites>'
    )
    out = _summary(
        tmp_path, "--title", "pytest", "--junit", "pytest.xml", files={"pytest.xml": junit}
    )
    assert len(out.encode("utf-8")) < MIB
    named = sum(f"test_{n:04d}</code>" in out for n in range(3000))
    more = re.search(r"and (\d+) more", out)
    assert named + (int(more.group(1)) if more else 0) == 3000
    assert "ids only" in out


# ─── ci.yml and the Vitest config ────────────────────────────────────


def _jobs() -> dict[str, Any]:
    return yaml.safe_load(CI.read_text(encoding="utf-8"))["jobs"]


def test_CISUM_06_every_ci_job_ends_with_its_summary_section() -> None:
    spec = yaml.safe_load(CI.read_text(encoding="utf-8"))
    assert spec["permissions"] == {"contents": "read"}
    for name, job in spec["jobs"].items():
        assert "permissions" not in job, name
        last = job["steps"][-1]
        assert "always()" in str(last.get("if", "")), name
        run = str(last.get("run", ""))
        assert "scripts/ci_summary.py" in run and '>> "$GITHUB_STEP_SUMMARY"' in run, name
        assert "${{" not in run, f"{name}: values reach the summary through env: only"
        for step in job["steps"]:
            if "| tee" in str(step.get("run", "")):
                assert step.get("shell") == "bash", f"{name}: {step.get('name')} needs pipefail"


def test_CISUM_06_pytest_writes_its_junit_file() -> None:
    steps = _jobs()["test-python"]["steps"]
    pytest_steps = [s for s in steps if str(s.get("run", "")).startswith("pytest")]
    assert len(pytest_steps) == 1
    assert "--junitxml=pytest.xml" in pytest_steps[0]["run"]


def test_CISUM_07_vitest_keeps_its_job_summary_on_github_actions() -> None:
    config = VITE_CONFIG.read_text(encoding="utf-8")
    assert "process.env.GITHUB_ACTIONS === 'true'" in config
    assert re.search(
        r"reporters:\s*\[\s*'default',\s*\[\s*'github-actions',\s*\{\s*jobSummary:\s*\{\s*enabled:\s*true\s*\}",
        config,
    ), "the reporters must be the default one plus github-actions with jobSummary on"


# ─── A pgTAP file that ran short of its plan fails (plan F1 A) ───────


PLANS = SCRIPTS / "check_pgtap_plans.py"
PREFLIGHT = SCRIPTS / "preflight.sh"


def _plans(tmp_path: Path, output: str) -> subprocess.CompletedProcess[str]:
    (tmp_path / "pgtap.out").write_text(output, encoding="utf-8")
    return subprocess.run(
        [sys.executable, str(PLANS), "pgtap.out"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        timeout=60,
    )


def test_CISUM_08_a_file_that_ran_short_of_its_plan_fails(tmp_path: Path) -> None:
    """18 Oct 2026: 19_phase3_wizard.sql planned 25 and ran 5, and pg_prove said ok."""
    completed = _plans(tmp_path, TAP_RED)
    assert completed.returncode == 1, completed.stdout + completed.stderr
    assert "supabase/tests/19_phase3_wizard.sql planned 25 tests but ran 5" in completed.stdout


def test_CISUM_08_every_file_that_ran_its_plan_passes(tmp_path: Path) -> None:
    completed = _plans(tmp_path, TAP_GREEN)
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "124 files" in completed.stdout


def test_CISUM_08_output_without_pg_proves_summary_fails(tmp_path: Path) -> None:
    """No summary means pg_prove did not finish: no file can be said to have run its plan."""
    completed = _plans(tmp_path, TAP_GREEN.split("All tests successful.")[0])
    assert completed.returncode == 1
    assert "did not finish" in completed.stdout


def test_CISUM_08_ci_runs_the_check_after_the_tests_and_before_the_summary() -> None:
    steps = _jobs()["test-db"]["steps"]
    runs = [str(s.get("run", "")) for s in steps]
    tests = next(i for i, r in enumerate(runs) if r.startswith("supabase test db"))
    check = next(i for i, r in enumerate(runs) if "scripts/check_pgtap_plans.py pgtap.out" in r)
    assert tests < check < len(steps) - 1
    assert "if" not in steps[check], "the check runs only after the tests passed"
    summary_env = steps[-1].get("env", {})
    assert f"steps.{steps[check]['id']}.outcome" in str(summary_env)


def test_CISUM_08_preflight_runs_the_check_on_its_pgtap_output() -> None:
    preflight = PREFLIGHT.read_text(encoding="utf-8")
    tests = preflight.index('gate "supabase test db (CI)"')
    check = preflight.index("scripts/check_pgtap_plans.py")
    assert tests < check
    assert 'gate "pgTAP plans all ran (CI)"' in preflight
