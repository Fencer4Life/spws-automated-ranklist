#!/usr/bin/env bash
# =============================================================================
# scripts/snapshot-events.sh — refresh supabase/seed_event_snapshot.sql from
# the LOCAL DB's current tbl_event + tbl_season state.
# =============================================================================
# Use this whenever the operator has manually cleaned up tbl_event or tbl_season
# (e.g. fixed event dates, renamed event codes, adjusted season ranges) and
# wants those changes to survive the next ./scripts/reset-dev.sh.
#
# Output is idempotent (INSERT … ON CONFLICT DO UPDATE), so the snapshot can
# be loaded over the baseline PROD seed without conflict.
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
"""Read tbl_season + tbl_event from LOCAL DB and emit an idempotent SQL seed."""
from python.pipeline.db_connector import create_db_connector
from datetime import datetime, UTC

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
        inner = ','.join("'" + str(x).replace("'","''") + "'" for x in v)
        cast = ARRAY_CASTS.get(col, "")
        return f"ARRAY[{inner}]{cast}"
    s = str(v).replace("'", "''")
    return f"'{s}'"

db = create_db_connector()
sb = db._sb
seasons = sb.table('tbl_season').select('*').order('id_season').execute().data or []
events   = sb.table('tbl_event').select('*').order('id_event').execute().data or []

out = [
    "-- Snapshot of tbl_season + tbl_event from LOCAL DB",
    f"-- Generated: {datetime.now(UTC).isoformat()}",
    "-- Idempotent: uses INSERT ... ON CONFLICT DO UPDATE",
    "-- Loaded by supabase/config.toml [db.seed].sql_paths after seed_prod_latest.sql",
    "-- Regenerate via: bash scripts/snapshot-events.sh",
    "",
    "BEGIN;",
    "",
    "-- ========== tbl_season ==========",
]
season_cols = sorted(seasons[0].keys()) if seasons else []
for s in seasons:
    cols = [c for c in season_cols if s.get(c) is not None]
    vals = [sqlit(s[c], c) for c in cols]
    updates = ', '.join(f"{c}=EXCLUDED.{c}" for c in cols if c != 'id_season')
    out.append(
        f"INSERT INTO tbl_season ({', '.join(cols)}) VALUES ({', '.join(vals)})\n"
        f"  ON CONFLICT (id_season) DO UPDATE SET {updates};"
    )
out.append("")
out.append("-- ========== tbl_event ==========")
event_cols = sorted(events[0].keys()) if events else []
for e in events:
    cols = [c for c in event_cols if e.get(c) is not None]
    vals = [sqlit(e[c], c) for c in cols]
    updates = ', '.join(f"{c}=EXCLUDED.{c}" for c in cols if c != 'id_event')
    out.append(
        f"INSERT INTO tbl_event ({', '.join(cols)}) VALUES ({', '.join(vals)})\n"
        f"  ON CONFLICT (id_event) DO UPDATE SET {updates};"
    )
out.append("")
out.append("-- Reset sequences past the snapshot")
out.append(
    "SELECT setval(pg_get_serial_sequence('tbl_event', 'id_event'),"
    " (SELECT COALESCE(MAX(id_event),1) FROM tbl_event));"
)
out.append(
    "SELECT setval(pg_get_serial_sequence('tbl_season', 'id_season'),"
    " (SELECT COALESCE(MAX(id_season),1) FROM tbl_season));"
)
out.append("")
out.append("COMMIT;")

text = "\n".join(out)
with open('supabase/seed_event_snapshot.sql', 'w') as f:
    f.write(text)
print(f"✓ Wrote supabase/seed_event_snapshot.sql ({len(text)} bytes, "
      f"{len(seasons)} seasons, {len(events)} events)")
PYEOF
