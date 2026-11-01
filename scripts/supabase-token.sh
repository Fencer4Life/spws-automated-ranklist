# shellcheck shell=bash
# =============================================================================
# supabase-token.sh — the Supabase Management API token, read by one rule.
#
# Sourced, never run:
#   source "$(dirname "${BASH_SOURCE[0]}")/supabase-token.sh"
#   TOKEN="$(supabase_access_token)"      # the value; "" when there is none
#   export_supabase_access_token          # sets and exports it, for a child
#                                         # that reads it itself (supabase CLI)
#
# The rule is python/supabase_token.py's, and python/tests/test_supabase_token.py
# runs one table of cases through both (ENVTOKEN.01–08):
#   1. the first SUPABASE_ACCESS_TOKEN= line of the checkout's .env, without
#      quotes or carriage returns;
#   2. otherwise the process environment's value.
# CLOUD_SQL_TOKEN_FROM_ENV=1 swaps 1 and 2. SUPABASE_TOKEN_ENV_FILE names a file
# to read instead of .env; python/tests/conftest.py points it at one that does
# not exist, so no test is handed the real token. An argument names the file
# for one call.
#
# .env wins over the environment, the opposite of the usual convention and
# deliberate: a stale SUPABASE_ACCESS_TOKEN in the environment shadowed the good
# value in .env and produced a bare HTTP 401 (2026-08-17 in cloud-sql.sh,
# 2026-11-01 in every Python reader). CI ships no .env and injects the secret
# as an environment variable, so there the environment's value is used.
#
# Bash builtins only: python/tests/test_schema_fingerprint.py runs
# schema-fingerprint.sh with a PATH that holds nothing but stubs. The value is
# returned, never echoed to a log.
# =============================================================================

case "${BASH_SOURCE[0]}" in
  */*) _supabase_token_dir="${BASH_SOURCE[0]%/*}" ;;
  *) _supabase_token_dir="." ;;
esac
_supabase_token_root="$(CDPATH='' cd -- "$_supabase_token_dir/.." && pwd)"
unset _supabase_token_dir

# The first SUPABASE_ACCESS_TOKEN= line's value in file $1, or nothing.
_supabase_token_from_file() {
  local line value=""
  [ -f "$1" ] && [ -r "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == SUPABASE_ACCESS_TOKEN=* ]]; then
      value="${line#SUPABASE_ACCESS_TOKEN=}"
      value="${value//\"/}"
      value="${value//\'/}"
      value="${value//$'\r'/}"
      break
    fi
  done < "$1"
  printf '%s' "$value"
}

# The token, or "" when neither the .env file nor the environment holds one.
supabase_access_token() {
  local env_file="${1:-${SUPABASE_TOKEN_ENV_FILE:-$_supabase_token_root/.env}}"
  local from_file from_env="${SUPABASE_ACCESS_TOKEN:-}"
  from_file="$(_supabase_token_from_file "$env_file")"
  if [ "${CLOUD_SQL_TOKEN_FROM_ENV:-}" = "1" ]; then
    printf '%s' "${from_env:-$from_file}"
  else
    printf '%s' "${from_file:-$from_env}"
  fi
}

# Sets SUPABASE_ACCESS_TOKEN to supabase_access_token's answer and exports it.
export_supabase_access_token() {
  SUPABASE_ACCESS_TOKEN="$(supabase_access_token "$@")"
  export SUPABASE_ACCESS_TOKEN
}
