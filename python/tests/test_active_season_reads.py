"""AS.PY.01 (ADR-031 amendment 2026-10-06): the pipeline reads the computed active season.

``tbl_season.bool_active`` is no longer a stored column: it is a computed field,
the function ``bool_active(tbl_season)``. PostgreSQL resolves ``s.bool_active``
(an alias in front) to that function, but a bare ``bool_active`` in a query on
``tbl_season`` fails with "column bool_active does not exist". The queries the
pipeline sends to CERT and PROD are plain strings, so this guard reads them.
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = sorted(p for p in (ROOT / "python").rglob("*.py") if "tests" not in p.parts)
BARE_SEASON_FLAG = re.compile(r"FROM\s+tbl_season\s+WHERE\s+bool_active", re.IGNORECASE)


def test_no_query_reads_the_season_flag_without_an_alias() -> None:
    """AS.PY.01 — every pipeline query on tbl_season reads ``s.bool_active``, never a bare column."""
    hits = [
        f"{path.relative_to(ROOT)}:{number}"
        for path in SOURCES
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1)
        if BARE_SEASON_FLAG.search(line)
    ]
    assert hits == []
