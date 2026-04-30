"""
Export LOCAL Supabase data using the same schema-driven monolithic format
as export_seed.py (ADR-036). Replaces Management API with docker exec psql.

Usage:
    python -m python.pipeline.export_seed_local
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import date

# Import the formatting helpers from the cloud exporter — they're pure.
from python.pipeline import export_seed
from python.pipeline.export_seed import export_monolithic, mgmt_query as _real_mgmt


def _pg_array_literal(items: list) -> str:
    """Render a Python list as a PG array text literal, e.g. ['EPEE','FOIL'] → '{EPEE,FOIL}'.

    Same shape Management API returns, so sql_val falls into the implicit-cast
    branch (no `ARRAY[...]` text[] mismatch with enum-typed columns).
    """
    if not items:
        return "{}"
    quoted = []
    for it in items:
        s = str(it)
        if any(c in s for c in ', "{}\\'):
            s = '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
        quoted.append(s)
    return "{" + ",".join(quoted) + "}"


def _normalise_arrays(rows: list[dict]) -> list[dict]:
    """Convert any list-valued cells back to PG-array-text format so
    export_seed.sql_val routes through the implicit-cast path."""
    for r in rows:
        for k, v in list(r.items()):
            if isinstance(v, list):
                r[k] = _pg_array_literal(v)
    return rows


def docker_query(_ref, _token, sql: str) -> list[dict]:
    """Run SQL against LOCAL via docker exec psql, return list of dicts.

    Uses psql's tuples-only JSON aggregation so we get the exact same shape
    Management API returns: list[dict].
    """
    # Wrap the user query in a JSON aggregator so output is one JSON line.
    wrapped = f"SELECT COALESCE(json_agg(t), '[]'::json) FROM ({sql}) t"
    result = subprocess.run(
        [
            "docker", "exec", "-i", "supabase_db_SPWSranklist",
            "psql", "-U", "postgres", "-d", "postgres",
            "-A", "-t", "-c", wrapped,
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"psql error: {result.stderr[:300]}\nQUERY: {sql[:200]}")
    return _normalise_arrays(json.loads(result.stdout.strip() or "[]"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Export LOCAL Supabase data")
    parser.add_argument("--output", default=None)
    args = parser.parse_args()

    # Patch the mgmt_query the formatter uses.
    export_seed.mgmt_query = docker_query

    # Patch discover_cols to additionally skip id_prior_event for tbl_event —
    # FK to other tbl_event rows whose ids change after TRUNCATE RESTART
    # IDENTITY. We rely on fn_backfill_id_prior_event() post-seed.
    _real_discover = export_seed.discover_cols
    def _patched(ref, token, table):
        cols = _real_discover(ref, token, table)
        if table == "tbl_event":
            cols = [c for c in cols if c["name"] != "id_prior_event"]
        return cols
    export_seed.discover_cols = _patched

    stamp = date.today().isoformat()
    out_path = args.output or os.path.join("supabase", f"seed_local_{stamp}.sql")

    print(f"Exporting LOCAL → {out_path}", file=sys.stderr)
    sql = export_monolithic("local", "")  # ref/token unused with patched mgmt_query
    # Append id_prior_event backfill at the end so carry-over chains restore
    # automatically on the target env.
    sql += "\n-- Restore id_prior_event FKs (rule-based; ADR-006)\nSELECT fn_backfill_id_prior_event();\n"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(sql)
    print(f"  Written: {out_path} ({len(sql)//1024} KB)", file=sys.stderr)


if __name__ == "__main__":
    main()
