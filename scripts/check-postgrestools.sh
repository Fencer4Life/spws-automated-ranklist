#!/usr/bin/env bash
# Hard postgrestools gate: zero findings, and proof that the checks really ran.
#
# WHY IT IS SHAPED LIKE THIS. With no database connection, postgrestools drops
# type checking and plpgsql_check without a word and exits 0 (seen 2026-10-24),
# so "postgrestools passed" proves nothing on its own. This script therefore:
#   1. requires the exact version the config's $schema pins;
#   2. runs three positive controls, each of which must come out as expected:
#      a missing column must be reported by type checking, an error in a
#      PL/pgSQL body must be reported by plpgsql_check, and a pgTAP call must
#      resolve (pgTAP and plpgsql_check come from supabase/seed_dev_tooling.sql);
#   3. checks every migration newer than the config's `migrations.after` and
#      every pgTAP file with warnings as errors, and requires the number of
#      files checked to equal the number on disk, so a config ignore cannot
#      quietly shrink what is checked.
# A finding the checker cannot avoid carries an inline `-- pgt-ignore…: <reason>`;
# an unused suppression is itself a warning. See .claude/skills/plpgsql-check.
#
# Used by scripts/preflight.sh (never skipped) and .github/workflows/ci.yml.
# Needs the local Supabase stack: ./scripts/reset-dev.sh.

set -uo pipefail
cd "$(dirname "$0")/.."

CONFIG=postgres-language-server.jsonc
fail() {
  echo "postgrestools gate: FAIL — $*" >&2
  exit 1
}

want=$(sed -n 's#.*pg-language-server\.com/\([0-9.]*\)/schema\.json.*#\1#p' "$CONFIG")
[[ -n "$want" ]] || fail "$CONFIG does not pin a version in \$schema"
command -v postgrestools >/dev/null 2>&1 \
  || fail "postgrestools is not installed: npm install -g @postgrestools/postgrestools@$want"
have=$(postgrestools --version 2>/dev/null | sed -n 's/^Version: //p')
[[ "$have" == "$want" ]] || fail "postgrestools $have is installed; $CONFIG pins $want"

# ---- 2. positive controls ---------------------------------------------------
canary=$(mktemp -d)
trap 'rm -rf "$canary"' EXIT
printf 'SELECT txt_pgt_canary_missing FROM tbl_event;\n' >"$canary/typecheck.sql"
cat >"$canary/plpgsql.sql" <<'SQL'
CREATE OR REPLACE FUNCTION fn_pgt_canary() RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
  RETURN (SELECT count(txt_pgt_canary_missing)::INT FROM tbl_event);
END;
$$;
SQL
printf "SELECT plan(1);\nSELECT ok(true, 'canary');\n" >"$canary/pgtap.sql"

probe=$(postgrestools check --colors=off --max-diagnostics=none \
  "$canary/typecheck.sql" "$canary/plpgsql.sql" "$canary/pgtap.sql" 2>&1)
grep -Eq 'typecheck\.sql:[0-9]+:[0-9]+ typecheck' <<<"$probe" \
  || fail "type checking did not run: is LOCAL Supabase up on the configured port? (./scripts/reset-dev.sh)"
grep -Eq 'plpgsql\.sql:[0-9]+:[0-9]+ plpgsql_check' <<<"$probe" \
  || fail "plpgsql_check did not run: the extension is missing or cannot load its library (a stale version after a CLI change: python scripts/check_supabase_cli.py names it and its update; a missing one comes from supabase/seed_dev_tooling.sql via ./scripts/reset-dev.sh)"
if grep -Eq 'pgtap\.sql:[0-9]+:[0-9]+ ' <<<"$probe"; then
  echo "$probe" >&2
  fail "pgTAP calls do not resolve: pgTAP is missing from the extensions schema (./scripts/reset-dev.sh)"
fi

# ---- 3. the real check -------------------------------------------------------
after=$(sed -n 's/.*"after": *\([0-9]*\).*/\1/p' "$CONFIG")
[[ -n "$after" ]] || fail "$CONFIG has no migrations.after"
expected=$(find supabase/tests -maxdepth 1 -name '*.sql' | wc -l)
for f in supabase/migrations/*.sql; do
  version=$(basename "$f" | cut -d_ -f1)
  if [[ "$version" =~ ^[0-9]+$ ]] && ((version > after)); then
    expected=$((expected + 1))
  fi
done

out=$(postgrestools check --colors=off --error-on-warnings --max-diagnostics=none \
  supabase/migrations supabase/tests 2>&1)
rc=$?
echo "$out"
[[ $rc -eq 0 ]] || fail "findings above (warnings count)"
checked=$(sed -n 's/^Checked \([0-9]*\) files\{0,1\} .*/\1/p' <<<"$out")
[[ "$checked" == "$expected" ]] \
  || fail "checked ${checked:-0} files, expected $expected (every pgTAP file + every migration after $after)"

echo "postgrestools gate: PASS — $checked files, 0 findings; type checking, plpgsql_check and pgTAP proven live"
