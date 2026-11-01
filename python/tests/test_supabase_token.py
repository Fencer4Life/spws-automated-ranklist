"""Every Supabase token reader takes the checkout's .env before the environment.

A stale SUPABASE_ACCESS_TOKEN in a session's environment shadowed the good value in
.env. scripts/cloud-sql.sh and scripts/mirror-prod-local.sh read .env; every Python
reader and six other shell scripts took the environment's value, so the Management
API answered 401 (1 Nov 2026: python/tests/test_prod_mirror.py failed on it in
preflight). python/supabase_token.py and scripts/supabase-token.sh now keep the one
rule, and one table of cases runs through both. ENVTOKEN.01–08.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from python import supabase_token

ROOT = Path(__file__).resolve().parents[2]
NAME = "SUPABASE_ACCESS_TOKEN"
MODULE = ROOT / "python" / "supabase_token.py"
HELPER = ROOT / "scripts" / "supabase-token.sh"
SWITCHES = (NAME, "CLOUD_SQL_TOKEN_FROM_ENV", "SUPABASE_TOKEN_ENV_FILE")

# (case, .env text or None for no file, the environment's value or None, CI switch, expected)
CASES = [
    ("env file wins", f"{NAME}=from-file\n", "from-env", False, "from-file"),
    ("no key in the file", "OTHER=1\n", "from-env", False, "from-env"),
    ("no file", None, "from-env", False, "from-env"),
    ("no environment value", f"{NAME}=from-file\n", None, False, "from-file"),
    ("neither", None, None, False, ""),
    ("empty in the file", f"{NAME}=\n", "from-env", False, "from-env"),
    ("double quotes and CRLF", NAME + '="from-file"\r\n', "from-env", False, "from-file"),
    ("single quotes, no newline", NAME + "='from-file'", None, False, "from-file"),
    (
        "first line wins, look-alikes ignored",
        f"#{NAME}=commented\nX_{NAME}=other\n {NAME}=indented\n{NAME}=first\n{NAME}=second\n",
        None,
        False,
        "first",
    ),
    ("CI switch: the environment wins", f"{NAME}=from-file\n", "from-env", True, "from-env"),
    ("CI switch, no environment value", f"{NAME}=from-file\n", None, True, "from-file"),
]
IDS = [case[0] for case in CASES]


def _env_file(folder: Path, text: str | None) -> Path:
    path = folder / "token.env"
    if text is not None:
        path.write_text(text, encoding="utf-8", newline="")
    return path


def _environment(value: str | None, ci_switch: bool, **extra: str) -> dict[str, str]:
    """This process's environment without the token or its switches, then the case's."""
    env = {k: v for k, v in os.environ.items() if k not in SWITCHES}
    if value is not None:
        env[NAME] = value
    if ci_switch:
        env["CLOUD_SQL_TOKEN_FROM_ENV"] = "1"
    env.update(extra)
    return env


def _shell(script: str, *args: str, env: dict[str, str]) -> str:
    bash = shutil.which("bash")
    assert bash
    run = subprocess.run(
        [bash, "-c", script, "_", *args], env=env, capture_output=True, text=True, check=False
    )
    assert run.returncode == 0, run.stderr
    return run.stdout


@pytest.mark.parametrize(("case", "text", "value", "ci_switch", "expected"), CASES, ids=IDS)
def test_ENVTOKEN_01_python_reader_takes_the_env_file_first(
    case: str,
    text: str | None,
    value: str | None,
    ci_switch: bool,
    expected: str,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """ENVTOKEN.01 python/supabase_token.py: .env, then the environment; the CI
    switch inverts it."""
    for name in SWITCHES:
        monkeypatch.delenv(name, raising=False)
    if value is not None:
        monkeypatch.setenv(NAME, value)
    if ci_switch:
        monkeypatch.setenv("CLOUD_SQL_TOKEN_FROM_ENV", "1")
    found = supabase_token.supabase_access_token(_env_file(tmp_path, text))
    assert found == expected, case


@pytest.mark.parametrize(("case", "text", "value", "ci_switch", "expected"), CASES, ids=IDS)
def test_ENVTOKEN_02_shell_helper_keeps_the_same_rule(
    case: str, text: str | None, value: str | None, ci_switch: bool, expected: str, tmp_path: Path
) -> None:
    """ENVTOKEN.02 scripts/supabase-token.sh answers every case as the Python reader
    does, and its export function sets the variable for a child process."""
    env = _environment(value, ci_switch)
    path = str(_env_file(tmp_path, text))
    read = 'source "$1"; supabase_access_token "$2"'
    assert _shell(read, str(HELPER), path, env=env) == expected, case
    child = 'printf %s "${SUPABASE_ACCESS_TOKEN:-}"'
    exported = f'source "$1"; export_supabase_access_token "$2"; bash -c \'{child}\''
    assert _shell(exported, str(HELPER), path, env=env) == expected, f"{case} (exported)"


def test_ENVTOKEN_03_with_no_argument_each_reads_the_env_at_its_own_checkout_root(
    tmp_path: Path,
) -> None:
    """ENVTOKEN.03 by default both read the .env one folder above their own file:
    python/../.env and scripts/../.env, the checkout's own."""
    (tmp_path / "python").mkdir()
    (tmp_path / "scripts").mkdir()
    shutil.copy(MODULE, tmp_path / "python" / MODULE.name)
    shutil.copy(HELPER, tmp_path / "scripts" / HELPER.name)
    (tmp_path / ".env").write_text(f"{NAME}=from-checkout\n", encoding="utf-8")
    env = _environment("from-env", False)
    python = subprocess.run(
        [
            sys.executable,
            "-I",
            "-c",
            "import runpy, sys; "
            "print(runpy.run_path(sys.argv[1])['supabase_access_token'](), end='')",
            str(tmp_path / "python" / MODULE.name),
        ],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert python.returncode == 0, python.stderr
    assert python.stdout == "from-checkout"
    shell = 'source "$1"; supabase_access_token'
    assert _shell(shell, str(tmp_path / "scripts" / HELPER.name), env=env) == "from-checkout"


def test_ENVTOKEN_04_a_named_env_file_replaces_the_checkouts(tmp_path: Path) -> None:
    """ENVTOKEN.04 SUPABASE_TOKEN_ENV_FILE names the file both read instead of .env
    (the tests' isolation, conftest.py); an explicit argument still comes first."""
    named = tmp_path / "named.env"
    named.write_text(f"{NAME}=from-named\n", encoding="utf-8")
    env = _environment("from-env", False, SUPABASE_TOKEN_ENV_FILE=str(named))
    code = (
        "import sys; sys.path.insert(0, sys.argv[1]); "
        "from python.supabase_token import supabase_access_token; "
        "print(supabase_access_token(), end='')"
    )
    run = subprocess.run(
        [sys.executable, "-c", code, str(ROOT)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert run.returncode == 0, run.stderr
    assert run.stdout == "from-named"
    assert _shell('source "$1"; supabase_access_token', str(HELPER), env=env) == "from-named"
    explicit = _env_file(tmp_path, f"{NAME}=from-argument\n")
    read = 'source "$1"; supabase_access_token "$2"'
    assert _shell(read, str(HELPER), str(explicit), env=env) == "from-argument"


DIRECT = re.compile(
    r"""(?:environ\s*(?:\.get\s*\(|\[)|getenv\s*\()\s*["']SUPABASE_ACCESS_TOKEN["']"""
)
SOURCED = re.compile(r"^[ \t]*(?:source|\.)[ \t]+[^\n#]*supabase-token\.sh", re.MULTILINE)


def test_ENVTOKEN_05_no_python_module_reads_the_token_from_the_environment() -> None:
    """ENVTOKEN.05 only python/supabase_token.py reads SUPABASE_ACCESS_TOKEN; every
    other module, test or tool calls it."""
    readers = [
        str(p.relative_to(ROOT))
        for folder in ("python", "scripts", "tools")
        for p in sorted((ROOT / folder).rglob("*.py"))
        if p != MODULE and DIRECT.search(p.read_text(encoding="utf-8"))
    ]
    assert readers == []


def test_ENVTOKEN_06_every_shell_reader_sources_the_helper() -> None:
    """ENVTOKEN.06 a script under scripts/ that uses the token outside its comments,
    by name or through the helper's functions, sources scripts/supabase-token.sh."""
    readers = [
        p
        for p in sorted((ROOT / "scripts").rglob("*.sh"))
        if p != HELPER
        and any(
            (NAME in line or "supabase_access_token" in line) and not line.lstrip().startswith("#")
            for line in p.read_text(encoding="utf-8").splitlines()
        )
    ]
    assert len(readers) >= 8, [str(p.relative_to(ROOT)) for p in readers]
    missing = [
        str(p.relative_to(ROOT))
        for p in readers
        if not SOURCED.search(p.read_text(encoding="utf-8"))
    ]
    assert missing == []


def test_ENVTOKEN_07_no_test_is_handed_the_checkouts_token(monkeypatch: pytest.MonkeyPatch) -> None:
    """ENVTOKEN.07 inside a test both readers, and every process the test starts,
    read a .env that does not exist (conftest.py), so a test that removes the token
    gets none rather than the real one."""
    monkeypatch.delenv(NAME, raising=False)
    monkeypatch.delenv("CLOUD_SQL_TOKEN_FROM_ENV", raising=False)
    # Booleans, so a failure never prints the token it was handed.
    python_handed = bool(supabase_token.supabase_access_token())
    assert not python_handed
    named = os.environ.get("SUPABASE_TOKEN_ENV_FILE", "")
    assert named and not Path(named).exists()
    shell_handed = bool(
        _shell('source "$1"; supabase_access_token', str(HELPER), env=dict(os.environ))
    )
    assert not shell_handed


def test_ENVTOKEN_08_the_mirror_check_sends_the_env_file_token(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ENVTOKEN.08 audit_results.query_db, which the LOCAL = PROD check uses, sends
    .env's token, read when it queries, not the environment's."""
    from python.tools import audit_results

    monkeypatch.setenv("SUPABASE_TOKEN_ENV_FILE", str(_env_file(tmp_path, f"{NAME}=from-file\n")))
    monkeypatch.setenv(NAME, "from-env")
    sent: dict[str, str] = {}

    class Reply:
        status_code = 200
        text = ""

        @staticmethod
        def json() -> list[dict[str, int]]:
            return [{"n": 1}]

    def post(_url: str, *, headers: dict[str, str], **_kwargs: object) -> Reply:
        sent.update(headers)
        return Reply()

    monkeypatch.setattr(audit_results.httpx, "post", post)
    assert audit_results.query_db("ref", "SELECT 1") == [[1]]
    # A boolean, so a failure never prints the token that was sent instead.
    sent_the_files = sent.get("Authorization") == "Bearer from-file"
    assert sent_the_files
