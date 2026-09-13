#!/usr/bin/env bash
# =============================================================================
# mirror-prod-local.sh — rebuild LOCAL as a faithful copy of PROD.
#
# Usage:  ./scripts/mirror-prod-local.sh
#
# WHY THIS EXISTS. Testing identity resolution against invented fixtures proves
# the logic; it does not prove the logic meets the data. The interesting cases
# on PROD are not the ones anyone would invent — two people who share a name and
# a spelling, nine fencers carried with no birth year at all, a registrant whose
# surname and given name arrived in each other's boxes.
#
# WHAT LOCAL IS WITHOUT IT. Not PROD, and not in a way anyone would notice by
# looking. `supabase db reset` runs every migration BEFORE the seed, and three
# data migrations add fencers by hand; on an empty table their own WHERE NOT
# EXISTS guards pass, so the seed then inserted the same people a second time.
# That left LOCAL with 385 fencers against PROD's 367 and SEVENTEEN same-name
# pairs against PROD's two — and same-name pairs are precisely the input that
# makes identity resolution ambiguous. Every local test of duplicate-name
# behaviour was running against a table PROD does not have. Fixed in
# export_seed.py (2026-09-12); this script is how you confirm it stayed fixed.
#
# WHAT IT DOES NOT TOUCH. The committed seed_prod_latest.sql pointer, which
# drives CI's fresh bootstrap. The symlink is repointed for the duration of the
# reset and restored before the script exits, so the working tree ends where it
# started and a mirror never silently becomes a CI change.
#
# READS PROD, WRITES ONLY LOCAL. No statement here modifies the cloud.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

SEED_LINK="supabase/seed_prod_latest.sql"
ORIGINAL_TARGET="$(readlink "$SEED_LINK")"
STAMP="$(date +%Y-%m-%d)"
FRESH="seed_prod_${STAMP}.sql"

restore_symlink() {
  if [ -n "${ORIGINAL_TARGET:-}" ] && [ "$(readlink "$SEED_LINK" || true)" != "$ORIGINAL_TARGET" ]; then
    rm -f "$SEED_LINK"
    ln -s "$ORIGINAL_TARGET" "$SEED_LINK"
    echo "Restored ${SEED_LINK} -> ${ORIGINAL_TARGET}"
  fi
}
# Restore on ANY exit, including a failed reset. Leaving the pointer moved is
# the one way this script could turn a local experiment into a CI change.
trap restore_symlink EXIT

# Credentials live in .env and are never echoed. .env is read in preference to
# the shell environment on purpose: a stale exported SUPABASE_ACCESS_TOKEN
# shadows the good value and produces a bare 401 that reads exactly like an
# expired credential (see the cloud-db-ops skill's "phantom 401").
read_env() { grep -E "^$1=" .env | cut -d= -f2- | tr -d '"'\''' ; }

echo "=== 1/4 Exporting PROD (read-only) ==="
SUPABASE_ACCESS_TOKEN="$(read_env SUPABASE_ACCESS_TOKEN)" \
PROD_REF="$(read_env SUPABASE_PROD_REF)" \
.venv/bin/python -c "
import os, sys
sys.argv = ['export_seed', '--ref', os.environ['PROD_REF']]
from python.pipeline.export_seed import main
main()"

echo "=== 2/4 Pointing the seed at ${FRESH} for this reset only ==="
rm -f "$SEED_LINK"
ln -s "$FRESH" "$SEED_LINK"

echo "=== 3/4 Resetting LOCAL ==="
./scripts/reset-dev.sh > /dev/null

echo "=== 4/4 Loading registrations ==="
# tbl_registration is deliberately absent from the seed: ADR-079 makes it
# EPHEMERAL — purged once results are ingested and reconciled — so baking real
# declarations into the shared dump would push 57 people's entries into every
# CI run and every developer's machine, permanently. It is fetched here instead,
# resolved by NATURAL KEY rather than id, because the surrogate ids differ
# between environments (the seed does not preserve them).
FIXTURE="$(mktemp -t spws_regs)"
trap 'rm -f "$FIXTURE"; restore_symlink' EXIT

env -u SUPABASE_ACCESS_TOKEN scripts/cloud-sql.sh prod "
SELECT string_agg(stmt, E'\n' ORDER BY stmt) FROM (
SELECT 'INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons, txt_consent_version) SELECT (SELECT id_event FROM tbl_event WHERE txt_code='
 || quote_literal(e.txt_code) || '), '
 || CASE WHEN f.id_fencer IS NULL THEN 'NULL' ELSE
      '(SELECT id_fencer FROM tbl_fencer WHERE upper(btrim(txt_surname))=upper(btrim(' || quote_literal(f.txt_surname)
      || ')) AND upper(btrim(txt_first_name))=upper(btrim(' || quote_literal(f.txt_first_name) || ')) AND int_birth_year IS NOT DISTINCT FROM '
      || COALESCE(f.int_birth_year::text,'NULL') || ')' END || ', '
 || quote_literal(r.txt_surname) || ', ' || quote_literal(r.txt_first_name) || ', '
 || quote_literal(r.enum_gender::text) || '::enum_gender_type, ' || r.int_birth_year || ', '
 || quote_literal(r.arr_weapons::text) || '::enum_weapon_type[], ' || quote_literal(COALESCE(r.txt_consent_version,'v1.0')) || ';' AS stmt
FROM tbl_registration r
JOIN tbl_event e ON e.id_event = r.id_event
LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
) s;" \
 | .venv/bin/python -c "
import json, sys
print(json.load(sys.stdin)[0]['string_agg'] or '')" > "$FIXTURE"

docker exec -i supabase_db_SPWSranklist psql -U postgres -d postgres -q < "$FIXTURE"

echo ""
echo "=== LOCAL now mirrors PROD ==="
docker exec supabase_db_SPWSranklist psql -U postgres -d postgres -At -c "
SELECT 'fencers          = '||count(*)
  ||'  (null BY '||count(*) FILTER (WHERE int_birth_year IS NULL)
  ||', estimated '||count(*) FILTER (WHERE bool_birth_year_estimated)||')' FROM tbl_fencer;
SELECT 'same-name pairs  = '||count(*)||'   <- PROD has 2; more than that means the seed duplicated rows'
  FROM (SELECT 1 FROM tbl_fencer
         GROUP BY upper(btrim(txt_surname)), upper(btrim(txt_first_name))
        HAVING count(*) > 1) d;
SELECT 'registrations    = '||count(*) FROM tbl_registration;"

echo ""
echo "NOTE: six calendar/event pgTAP files are calibrated against the older seed"
echo "      snapshot and fail on current PROD data (19, 54, 56, 63, 67, 74)."
echo "      Every registration and identity test passes. See the 2026-09-12 report."
