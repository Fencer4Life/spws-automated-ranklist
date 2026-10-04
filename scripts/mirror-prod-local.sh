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
# IDS. The seed keeps PROD's fencer ids (ADR-036 §1, ADR-108): the fencer id is
# the same on LOCAL, CERT and PROD. Step 4 compares LOCAL's roster with PROD's,
# id for id, and stops on any difference; registrations then carry PROD's ids.
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

echo "=== 1/5 Exporting PROD (read-only) ==="
SUPABASE_ACCESS_TOKEN="$(read_env SUPABASE_ACCESS_TOKEN)" \
PROD_REF="$(read_env SUPABASE_PROD_REF)" \
.venv/bin/python -c "
import os, sys
sys.argv = ['export_seed', '--ref', os.environ['PROD_REF']]
from python.pipeline.export_seed import main
main()"

echo "=== 2/5 Pointing the seed at ${FRESH} for this reset only ==="
rm -f "$SEED_LINK"
ln -s "$FRESH" "$SEED_LINK"

echo "=== 3/5 Resetting LOCAL ==="
./scripts/reset-dev.sh > /dev/null

echo "=== 4/5 Checking LOCAL's roster against PROD's, id for id ==="
SUPABASE_ACCESS_TOKEN="$(read_env SUPABASE_ACCESS_TOKEN)" \
.venv/bin/python -m python.pipeline.promotion.refresh --target local --mode verify

echo "=== 5/5 Loading registrations ==="
# tbl_registration is deliberately absent from the seed: ADR-079 makes it
# EPHEMERAL — purged once results are ingested and reconciled — so baking real
# declarations into the shared dump would push 57 people's entries into every
# CI run and every developer's machine, permanently. It is fetched here instead,
# with PROD's fencer ids, which step 4 has just shown LOCAL holds.
#
# By the refresh's own copy (ADR-036 §3): every PROD event with entries goes
# through fn_replace_event_registrations with the columns the ingestion reads —
# never the e-mail hash, edit token or consent stamp — and the step fails unless
# each event's registrations part of the input fingerprint then equals PROD's.
# A copy of its own here once left out the club and FTL name, and promote's
# LOCAL rehearsal stopped at input.registrations (3 Oct 2026).
SUPABASE_ACCESS_TOKEN="$(read_env SUPABASE_ACCESS_TOKEN)" \
.venv/bin/python -m python.pipeline.promotion.refresh --target local --mode registrations

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
