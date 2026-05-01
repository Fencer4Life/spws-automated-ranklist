#!/usr/bin/env bash
# load-cert-ref.sh — Populate cert_ref.* from public.* (Phase 0, ADR-050).
#
# WHEN TO RUN
#   Once, immediately after `bash scripts/reset-dev.sh` at rebuild start.
#   At that moment public.tbl_* is a faithful PROD snapshot from
#   seed_prod_<latest>.sql, so a public → cert_ref copy gives us the
#   read-only baseline the rebuild's 3-way diff (Phase 3) needs.
#
# WHAT IT DOES
#   1. Verifies the cert_ref schema exists (added by Phase 0 migration)
#   2. TRUNCATEs cert_ref tables (idempotent — running twice won't blow up)
#   3. Copies the column-intersection of public.tbl_* into cert_ref.tbl_*
#      for: tbl_fencer, tbl_event, tbl_tournament, tbl_result
#   4. Reports row counts
#
# WHAT IT DOES NOT DO
#   * Touch public.* — read-only on the source side
#   * Run against CERT or PROD — LOCAL only (uses docker exec)
#   * Refresh sequence state — cert_ref tables have plain INT PKs
#
# After this script, cert_ref.* is frozen for the rebuild lifetime.
# Phase 6 drops the cert_ref schema entirely after LOCAL→CERT→PROD
# promotion completes.

set -euo pipefail

CONTAINER="supabase_db_SPWSranklist"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "ERROR: ${CONTAINER} is not running. Run 'supabase start' first."
  exit 1
fi

psql_q() {
  docker exec "${CONTAINER}" psql -U postgres -t -A -c "$1"
}

psql_run() {
  docker exec -i "${CONTAINER}" psql -U postgres -v ON_ERROR_STOP=1
}

echo "=== load-cert-ref.sh — populate cert_ref schema from public ==="
echo ""

# 1. Verify schema exists
if ! psql_q "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'cert_ref'" | grep -qx "1"; then
  echo "ERROR: cert_ref schema not found. Did the Phase 0 migration apply?"
  echo "Run: bash scripts/reset-dev.sh"
  exit 1
fi

# 2. Pre-flight: warn if cert_ref already populated
EXISTING=$(psql_q "SELECT COUNT(*) FROM cert_ref.tbl_event")
if [ "${EXISTING}" -gt 0 ]; then
  echo "NOTICE: cert_ref.tbl_event already has ${EXISTING} rows."
  echo "        This run will TRUNCATE and reload from public.*."
  echo ""
fi

# 3. Copy public → cert_ref (column-intersection only)
#    Use TRUNCATE ... CASCADE so order doesn't matter and re-runs are clean.
echo "--- Copying public → cert_ref ---"
psql_run <<'SQL'
BEGIN;

TRUNCATE TABLE
  cert_ref.tbl_fencer,
  cert_ref.tbl_event,
  cert_ref.tbl_tournament,
  cert_ref.tbl_result
RESTART IDENTITY;

-- tbl_fencer
INSERT INTO cert_ref.tbl_fencer (
  id_fencer, txt_surname, txt_first_name, int_birth_year,
  txt_club, txt_nationality, json_name_aliases,
  ts_created, ts_updated, bool_birth_year_estimated, enum_gender
)
SELECT
  id_fencer, txt_surname, txt_first_name, int_birth_year,
  txt_club, txt_nationality, json_name_aliases,
  ts_created, ts_updated, bool_birth_year_estimated, enum_gender::TEXT
FROM public.tbl_fencer;

-- tbl_event
INSERT INTO cert_ref.tbl_event (
  id_event, txt_code, txt_name, id_season, id_organizer, txt_location,
  dt_start, dt_end, url_event, enum_status, ts_created, ts_updated,
  txt_country, txt_venue_address, url_invitation,
  num_entry_fee, txt_entry_fee_currency, arr_weapons,
  url_registration, dt_registration_deadline,
  url_event_2, url_event_3, url_event_4, url_event_5,
  id_prior_event, id_evf_event, txt_source_status
)
SELECT
  id_event, txt_code, txt_name, id_season, id_organizer, txt_location,
  dt_start, dt_end, url_event, enum_status::TEXT, ts_created, ts_updated,
  txt_country, txt_venue_address, url_invitation,
  num_entry_fee, txt_entry_fee_currency,
  -- arr_weapons is enum_weapon_type[] in public; cast each element to TEXT
  CASE WHEN arr_weapons IS NULL THEN NULL ELSE arr_weapons::TEXT[] END,
  url_registration, dt_registration_deadline,
  url_event_2, url_event_3, url_event_4, url_event_5,
  id_prior_event, id_evf_event, txt_source_status::TEXT
FROM public.tbl_event;

-- tbl_tournament
INSERT INTO cert_ref.tbl_tournament (
  id_tournament, id_event, txt_code, txt_name, enum_type, num_multiplier,
  dt_tournament, int_participant_count, enum_weapon, enum_gender,
  enum_age_category, url_results, enum_import_status,
  txt_import_status_reason, ts_created, ts_updated,
  id_evf_competition, bool_joint_pool_split
)
SELECT
  id_tournament, id_event, txt_code, txt_name, enum_type::TEXT, num_multiplier,
  dt_tournament, int_participant_count, enum_weapon::TEXT, enum_gender::TEXT,
  enum_age_category::TEXT, url_results, enum_import_status::TEXT,
  txt_import_status_reason, ts_created, ts_updated,
  id_evf_competition, bool_joint_pool_split
FROM public.tbl_tournament;

-- tbl_result
INSERT INTO cert_ref.tbl_result (
  id_result, id_fencer, id_tournament, int_place,
  enum_fencer_age_category, txt_cross_cat,
  num_place_pts, num_de_bonus, num_podium_bonus, num_final_score,
  ts_points_calc, ts_created, ts_updated,
  txt_scraped_name, num_match_confidence, enum_match_method
)
SELECT
  id_result, id_fencer, id_tournament, int_place,
  enum_fencer_age_category::TEXT, txt_cross_cat,
  num_place_pts, num_de_bonus, num_podium_bonus, num_final_score,
  ts_points_calc, ts_created, ts_updated,
  txt_scraped_name, num_match_confidence, enum_match_method::TEXT
FROM public.tbl_result;

COMMIT;
SQL

echo ""
echo "--- cert_ref counts ---"
psql_q "SELECT 'tbl_fencer:     ' || COUNT(*) FROM cert_ref.tbl_fencer"
psql_q "SELECT 'tbl_event:      ' || COUNT(*) FROM cert_ref.tbl_event"
psql_q "SELECT 'tbl_tournament: ' || COUNT(*) FROM cert_ref.tbl_tournament"
psql_q "SELECT 'tbl_result:     ' || COUNT(*) FROM cert_ref.tbl_result"
echo ""
echo "=== Done. cert_ref schema is read-only for the rebuild lifetime. ==="
