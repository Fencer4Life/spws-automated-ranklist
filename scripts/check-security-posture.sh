#!/usr/bin/env bash
# =============================================================================
# ADR-083 — verify the deny-by-default security posture of a REMOTE environment.
# =============================================================================
# Usage:  scripts/check-security-posture.sh <project-ref> [label]
# Needs:  SUPABASE_ACCESS_TOKEN in the environment.
#
# Why this exists as well as pgTAP 52.1-52.12.
#
# `supabase test db` runs against LOCAL only, and release.yml's build job is
# skipped entirely by a manual workflow_dispatch:
#
#     if: ${{ github.event_name == 'workflow_dispatch' || ... }}
#            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ unconditional
#
# so a hand-triggered release skips CI and therefore skips pgTAP. That makes
# the standing guard optional in practice. This script closes that route by
# asserting the posture against the ACTUAL deployed database, from inside the
# deploy job, where nothing can be routed around it.
#
# It is also the honest check: pgTAP proves what LOCAL looks like after the
# migrations replay. This proves what CERT/PROD actually look like right now —
# which is the thing that was wrong for four months while LOCAL looked fine.
# =============================================================================

set -euo pipefail

REF="${1:?usage: check-security-posture.sh <project-ref> [label]}"
LABEL="${2:-$REF}"

if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "FAIL: SUPABASE_ACCESS_TOKEN is not set" >&2
  exit 2
fi

# The anon-EXECUTEable allowlist. MUST stay in sync with assertion 52.7 in
# supabase/tests/52_security_posture.sql — that file is the source of truth and
# explains why each name is on it. Two of these are the ADR-079 / FR-122 public
# self-registration path (register.html is served to anonymous visitors); the
# rest are the public ranking and calendar read surface.
read -r -d '' ALLOWLIST <<'EOF' || true
'fn_age_category','fn_compare_carryover_engines','fn_copy_prior_scoring_config',
'fn_create_registration','fn_effective_gender','fn_event_position',
'fn_export_scoring_config','fn_fencer_scores_rolling',
'fn_fencer_scores_rolling_event_code_matching','fn_fencer_scores_rolling_event_fk_matching',
'fn_match_registration_fencer','fn_ranking_kadra','fn_ranking_kadra_event_code_matching',
'fn_ranking_kadra_event_fk_matching','fn_ranking_ppw','fn_ranking_ppw_event_code_matching',
'fn_ranking_ppw_event_fk_matching','fn_season_summary','fn_vcat_violation_msg'
EOF
ALLOWLIST=$(echo "$ALLOWLIST" | tr -d '\n')

SQL="SELECT json_build_object(
  'rls_off', (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
               WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity),
  'anon_write_tables', (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
               WHERE n.nspname='public' AND c.relkind='r'
                 AND (has_table_privilege('anon',c.oid,'INSERT')
                   OR has_table_privilege('anon',c.oid,'UPDATE')
                   OR has_table_privilege('anon',c.oid,'DELETE')
                   OR has_table_privilege('anon',c.oid,'TRUNCATE'))),
  'anon_alias_view', (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
               WHERE n.nspname='public' AND c.relname='vw_fencer_aliases'
                 AND has_table_privilege('anon',c.oid,'SELECT')),
  'anon_default_acl', (SELECT count(*) FROM pg_default_acl d
               JOIN pg_namespace n ON n.oid=d.defaclnamespace
               CROSS JOIN LATERAL aclexplode(d.defaclacl) a
               WHERE n.nspname='public' AND pg_get_userbyid(d.defaclrole)='postgres'
                 AND pg_get_userbyid(a.grantee) IN ('anon','authenticated')),
  'anon_extra_functions', (SELECT coalesce(string_agg(p.proname, ', ' ORDER BY p.proname), '')
               FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
               WHERE n.nspname='public' AND p.prokind='f'
                 AND p.prorettype <> 'trigger'::regtype
                 AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid=p.oid AND d.deptype='e')
                 AND has_function_privilege('anon',p.oid,'EXECUTE')
                 AND p.proname NOT IN ($ALLOWLIST))
) AS posture;"

PAYLOAD=$(python3 -c 'import json,sys;print(json.dumps({"query":sys.stdin.read()}))' <<<"$SQL")

RESP=$(curl -s -X POST \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "https://api.supabase.com/v1/projects/$REF/database/query")

echo "=== ADR-083 security posture: $LABEL ==="

python3 - "$RESP" <<'PYEOF'
import json, sys

try:
    rows = json.loads(sys.argv[1])
except json.JSONDecodeError:
    print(f"FAIL: could not parse Management API response: {sys.argv[1][:300]}")
    sys.exit(2)

if isinstance(rows, dict) and rows.get("message"):
    print(f"FAIL: Management API error: {rows['message']}")
    sys.exit(2)
if not rows:
    print("FAIL: Management API returned no rows")
    sys.exit(2)

p = rows[0]["posture"]
if isinstance(p, str):
    p = json.loads(p)

failures = []

def check(key, label, ok_when_zero=True):
    v = p.get(key)
    good = (v == 0) if ok_when_zero else not v
    status = "PASS" if good else "FAIL"
    print(f"  {status}: {label} = {v!r}")
    if not good:
        failures.append(label)

check("rls_off",           "tables in public with RLS disabled")
check("anon_write_tables", "tables where anon holds INSERT/UPDATE/DELETE/TRUNCATE")
check("anon_alias_view",   "anon SELECT on vw_fencer_aliases")
check("anon_default_acl",  "default privileges granted to anon/authenticated by postgres")
check("anon_extra_functions",
      "anon-EXECUTEable functions outside the 52.7 allowlist", ok_when_zero=False)

print()
if failures:
    print(f"SECURITY POSTURE REGRESSION ({len(failures)}): " + "; ".join(failures))
    sys.exit(1)
print("Security posture OK — deny-by-default holds.")
PYEOF
