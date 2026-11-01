#!/usr/bin/env python3
"""Fail when a pgTAP file ran a different number of assertions than it planned.

pg_prove still calls such a file ok: on 18 Oct 2026 (CI 39112045045)
supabase/tests/19_phase3_wizard.sql planned 25 tests and ran 5, because assertions made
inside savepoints went uncounted, and CI stayed green on it until the file was fixed on
31 Oct. pgTAP says so in its own diagnostic, "# Looks like you planned N tests but ran
M", and this check fails on every such line. It also fails when pg_prove did not
finish, since then no file can be said to have run its plan.

Usage:  scripts/check_pgtap_plans.py <pg_prove output>
The pgTAP job in ci.yml runs it on `supabase test db | tee pgtap.out`, and
scripts/preflight.sh on the output of its own `supabase test db` gate. The output is
read by scripts/ci_summary.py's parser, the one that writes the run's Summary page.

Plan: doc/plans/ci-test-summaries-2026-11-01.html (F1 A). Test: CISUM.08.
"""

from __future__ import annotations

import sys
from pathlib import Path

from ci_summary import parse_tap


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: check_pgtap_plans.py <pg_prove output>", file=sys.stderr)
        return 2
    try:
        run = parse_tap(Path(argv[0]).read_text(encoding="utf-8", errors="replace"))
    except OSError as error:
        print(f"pgTAP plans: cannot read {argv[0]}: {error}")
        return 1
    if not run.files:
        print(
            "pgTAP plans: pg_prove did not finish (no Files= summary), so no file can be said to have run its plan"
        )
        return 1
    for suite, planned, ran in run.short:
        print(f"  {suite} planned {planned} tests but ran {ran}")
    if run.short:
        print(
            f"pgTAP plans: {len(run.short)} file(s) ran a different number of assertions than planned; pg_prove still calls them ok"
        )
        return 1
    print(f"pgTAP plans: every file ran the tests it planned ({run.files} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
