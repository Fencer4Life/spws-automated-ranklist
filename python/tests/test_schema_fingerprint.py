"""SCHEMAFP.01–03 (ADR-119 G27): `scripts/schema-fingerprint.sh local` reaches LOCAL
through the Docker Supabase stack.

LOCAL is always the Docker stack, on a developer's machine and in the Release's
build job, which starts it with `supabase start`. The script used to call a
`psql` on the host instead, so on a machine without one it exited 127, and its
own error branch never ran under `set -e`. These tests put stub `docker` and
`psql` executables on a PATH that holds nothing else, so they show which one the
script calls and what it sends, without a database.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "schema-fingerprint.sh"
CONTAINER_ANSWER = "0123456789abcdef0123456789abcdef"


def _stub(bin_dir: Path, name: str, body: str) -> None:
    """An executable that uses shell builtins only: the PATH holds nothing else."""
    path = bin_dir / name
    path.write_text(f"#!/bin/sh\n{body}\n", encoding="utf-8")
    path.chmod(0o755)


def _docker(bin_dir: Path, *, fail: bool = False) -> None:
    log = bin_dir / "docker.calls"
    sql = bin_dir / "docker.stdin"
    _stub(
        bin_dir,
        "docker",
        f'echo "$*" > "{log}"\n'
        f'while IFS= read -r line || [ -n "$line" ]; do printf "%s\\n" "$line" >> "{sql}"; done\n'
        + ('echo "connection refused" >&2\nexit 1' if fail else f"echo {CONTAINER_ANSWER}"),
    )


def _run(bin_dir: Path) -> subprocess.CompletedProcess[str]:
    bash = shutil.which("bash")
    assert bash
    return subprocess.run(
        [bash, str(SCRIPT), "local"],
        env={"PATH": str(bin_dir)},
        capture_output=True,
        text=True,
        timeout=30,
    )


def test_local_mode_asks_the_stacks_database_container(tmp_path: Path) -> None:
    """SCHEMAFP.01 the query goes to the Docker stack's database container and its
    answer is the fingerprint."""
    _docker(tmp_path)
    run = _run(tmp_path)
    assert run.returncode == 0, run.stderr
    assert run.stdout.strip() == CONTAINER_ANSWER
    calls = (tmp_path / "docker.calls").read_text(encoding="utf-8")
    assert calls.startswith("exec -i supabase_db_SPWSranklist psql ")
    assert "WITH func_hash" in (tmp_path / "docker.stdin").read_text(encoding="utf-8")


def test_local_mode_never_calls_a_psql_on_the_host(tmp_path: Path) -> None:
    """SCHEMAFP.02 a host psql, even when there is one, is not LOCAL."""
    _docker(tmp_path)
    _stub(
        tmp_path,
        "psql",
        f'echo called > "{tmp_path / "psql.called"}"\necho ffffffffffffffffffffffffffffffff',
    )
    run = _run(tmp_path)
    assert run.stdout.strip() == CONTAINER_ANSWER
    assert not (tmp_path / "psql.called").exists()


def test_a_failure_says_why(tmp_path: Path) -> None:
    """SCHEMAFP.03 a failure reaches the script's own message and exit 1; it used to
    die under `set -e` with nothing said."""
    _docker(tmp_path, fail=True)
    run = _run(tmp_path)
    assert run.returncode == 1
    assert "ERROR: Failed to compute local fingerprint" in run.stderr
    assert "connection refused" in run.stderr
