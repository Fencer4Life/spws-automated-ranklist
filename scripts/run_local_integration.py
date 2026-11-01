"""Run the pipeline's LOCAL-database tests against the running LOCAL stack (ADR-119 G20).

`python/tests/test_pipeline_integration.py` (P3.INT) drives the old pipeline,
`run_pipeline`, and the draft store against a real database. CI's pytest job has
no database and skips the file, and so did preflight's pytest gate, which is how
the tests went on failing unseen after the active season moved on. This gate
runs that file against LOCAL.

LOCAL's API address and service key come from `supabase status -o env` and go
only into this process's environment, for the tests. Both of the CLI's streams
are captured and never printed: the CLI writes keys to them.

Passes only when every test in the file ran and passed. A skipped test fails the
gate, since a skip is what hid them before.

Usage: python scripts/run_local_integration.py
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TESTS = "python/tests/test_pipeline_integration.py"


def _local_stack() -> dict[str, str]:
    """LOCAL's API address and service key, read from the running stack."""
    status = subprocess.run(
        ["supabase", "status", "-o", "env"],
        capture_output=True,
        text=True,
        timeout=120,
        cwd=ROOT,
    )
    values = dict(re.findall(r'^([A-Z_]+)="?([^"\n]*)"?$', status.stdout, re.M))
    url, key = values.get("API_URL"), values.get("SERVICE_ROLE_KEY")
    if status.returncode != 0 or not url or not key:
        sys.exit("LOCAL's stack is not running or gave no API address and service key.")
    return {"SUPABASE_URL": url, "SUPABASE_KEY": key}


class _Tally:
    """The run's outcomes by kind, as pytest's own summary counts them."""

    def __init__(self) -> None:
        self.counts: dict[str, int] = {}

    def pytest_terminal_summary(self, terminalreporter: Any) -> None:
        self.counts = {k: len(v) for k, v in terminalreporter.stats.items() if k}


def main() -> int:
    os.chdir(ROOT)
    os.environ.update(_local_stack())
    import pytest

    tally = _Tally()
    code = pytest.main([TESTS, "-q", "-rs"], plugins=[tally])
    passed, failed, errors, skipped = (
        tally.counts.get(k, 0) for k in ("passed", "failed", "error", "skipped")
    )
    print(f"{TESTS}: {passed} passed, {failed} failed, {errors} errors, {skipped} skipped")
    return 0 if code == 0 and passed and not (failed or errors or skipped) else 1


if __name__ == "__main__":
    sys.exit(main())
