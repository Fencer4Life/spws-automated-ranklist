#!/usr/bin/env bash
# =============================================================================
# scripts/snapshot-events.sh — refresh supabase/seed_event_snapshot.sql from
# the LOCAL DB's current tbl_season + tbl_event + tbl_fencer state.
# =============================================================================
# Use this whenever the operator has manually cleaned up the operator-mutable
# tables (event dates, event codes, season ranges, fencer BYs, alias arrays)
# and wants those changes to survive the next ./scripts/reset-dev.sh.
#
# Output is idempotent (INSERT ... ON CONFLICT DO UPDATE), so the snapshot can
# be loaded over the baseline PROD seed without conflict — every row in the
# snapshot wins (post-seed_prod_latest.sql, pre-migrations-finished).
#
# This script does NOT touch CERT or PROD — it only reads from LOCAL.
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "❌ .env not found in repo root — refusing to read DB without explicit config" >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a; source .env; set +a

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_KEY:-}" ]]; then
  echo "❌ SUPABASE_URL or SUPABASE_KEY missing from .env" >&2
  exit 1
fi

# Refuse to run against anything other than localhost — we don't want
# accidental snapshots of CERT/PROD into the LOCAL seed.
if [[ "$SUPABASE_URL" != *"127.0.0.1"* && "$SUPABASE_URL" != *"localhost"* ]]; then
  echo "❌ refusing to snapshot from non-LOCAL DB ($SUPABASE_URL)" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .venv/bin/activate

python - <<'PYEOF'
"""Read tbl_season + tbl_event + tbl_fencer from LOCAL and emit idempotent SQL.

Why these three: the operator's manual curation work (BY corrections, alias
edits, event-code renames, season-range adjustments) lives in these tables.
Drafts (tbl_*_draft) are ephemeral by design. Tournaments + results are
authoritative-from-source and rebuilt by the ingestion pipeline."""
from python.pipeline.db_connector import create_db_connector
from datetime import datetime, UTC
import json

# Columns whose Postgres type is enum_*[] need an explicit cast on the
# array literal — Postgres won't auto-coerce text[] → enum[].
ARRAY_CASTS = {
    "arr_weapons": "::enum_weapon_type[]",
}

def sqlit(v, col=None):
    if v is None: return 'NULL'
    if isinstance(v, bool): return 'TRUE' if v else 'FALSE'
    if isinstance(v, (int, float)): return str(v)
    if isinstance(v, list):
        # JSONB array (e.g. json_name_aliases) vs text[] (e.g. arr_weapons).
        # Both come back as Python list from supabase-py; disambiguate by
        # the column-name → cast map.
        if col in ARRAY_CASTS:
            inner = ','.join("'" + str(x).replace("'","''") + "'" for x in v)
            return f"ARRAY[{inner}]{ARRAY_CASTS[col]}"
        # Default: render as JSONB literal (correct for json_*aliases columns
        # — fixes the legacy seed-export bug where these were emitted as a
        # postgres-array literal text-cast to JSONB, producing the
        # "{\"WOJTAS Bogdan\"}" string-of-array corruption that bug 5.15 had
        # to repair).
        return f"'{json.dumps(v).replace(chr(39), chr(39)+chr(39))}'::jsonb"
    if isinstance(v, dict):
        return f"'{json.dumps(v).replace(chr(39), chr(39)+chr(39))}'::jsonb"
    s = str(v).replace("'", "''")
    return f"'{s}'"

def emit_table(out, table, rows, pk):
    if not rows: return
    out.append(f"-- ========== {table} ({len(rows)} rows) ==========")
    cols_all = sorted(rows[0].keys())
    for r in rows:
        cols = [c for c in cols_all if r.get(c) is not None]
        vals = [sqlit(r[c], c) for c in cols]
        updates = ', '.join(f"{c}=EXCLUDED.{c}" for c in cols if c != pk)
        out.append(
            f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join(vals)})\n"
            f"  ON CONFLICT ({pk}) DO UPDATE SET {updates};"
        )
    out.append("")

def fetch_all(sb, table, order_col):
    """Paginated fetch — supabase-py default page caps at 1000, tbl_fencer
    has 300+ rows so we stay under one page, but page anyway for safety
    against future growth."""
    out = []
    start = 0
    while True:
        page = (sb.table(table).select('*').order(order_col)
                .range(start, start + 999).execute().data)
        if not page: break
        out.extend(page)
        if len(page) < 1000: break
        start += 1000
    return out

db = create_db_connector()
sb = db._sb
seasons = fetch_all(sb, 'tbl_season', 'id_season')
events  = fetch_all(sb, 'tbl_event',  'id_event')
fencers = fetch_all(sb, 'tbl_fencer', 'id_fencer')

out = [
    "-- Snapshot of tbl_season + tbl_event + tbl_fencer from LOCAL DB",
    f"-- Generated: {datetime.now(UTC).isoformat()}",
    f"-- Counts: {len(seasons)} seasons, {len(events)} events, {len(fencers)} fencers",
    "-- Idempotent: uses INSERT ... ON CONFLICT DO UPDATE",
    "-- Loaded by supabase/config.toml [db.seed].sql_paths after seed_prod_latest.sql",
    "-- Regenerate via: bash scripts/snapshot-events.sh",
    "",
    "BEGIN;",
    "",
]
emit_table(out, 'tbl_season', seasons, 'id_season')
emit_table(out, 'tbl_event',  events,  'id_event')
emit_table(out, 'tbl_fencer', fencers, 'id_fencer')

out.append("-- Reset sequences past the snapshot so future inserts don't collide")
out.append(
    "SELECT setval(pg_get_serial_sequence('tbl_season', 'id_season'),"
    " (SELECT COALESCE(MAX(id_season),1) FROM tbl_season));"
)
out.append(
    "SELECT setval(pg_get_serial_sequence('tbl_event', 'id_event'),"
    " (SELECT COALESCE(MAX(id_event),1) FROM tbl_event));"
)
out.append(
    "SELECT setval(pg_get_serial_sequence('tbl_fencer', 'id_fencer'),"
    " (SELECT COALESCE(MAX(id_fencer),1) FROM tbl_fencer));"
)
out.append("")
out.append("COMMIT;")

text = "\n".join(out)
with open('supabase/seed_event_snapshot.sql', 'w') as f:
    f.write(text)
print(f"✓ Wrote supabase/seed_event_snapshot.sql ({len(text)} bytes, "
      f"{len(seasons)} seasons, {len(events)} events, {len(fencers)} fencers)")
PYEOF
