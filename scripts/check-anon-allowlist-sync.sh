#!/usr/bin/env bash
# The anon-EXECUTEable allowlist exists in two files that must agree:
#
#   supabase/tests/52_security_posture.sql   — the source of truth, with the
#                                              justification for every name
#   scripts/check-security-posture.sh        — the copy the deploy job asserts
#                                              against the REAL CERT/PROD db
#
# They drifted on 2026-09-12: 52.7 gained the identity block and the FTL export
# page, the deploy copy did not. pgTAP stayed green through the whole of CI,
# because pgTAP only ever reads 52.7. The disagreement surfaced at deploy time,
# failing CERT's posture check and blocking the PROD job — the gate did its job,
# but a two-minute local check is a better place to find it than a half-finished
# release.
#
# This compares the two sets and fails on any difference.
set -uo pipefail
cd "$(dirname "$0")/.."

names() {  # every 'fn_...' quoted name in a file, one per line, sorted unique
  grep -oE "'fn_[a-z0-9_]+'" "$1" | tr -d "'" | sort -u
}

# 52.7's allowlist is the ARRAY[...] immediately preceding the assertion label
# '52.7: the anon-EXECUTEable function set equals the documented allowlist'.
# Slice the file at that label and take the names from the tail above it, so
# fn_ names used by OTHER assertions in the same file are not swept in.
PGTAP=$(awk '/anon-EXECUTEable function set equals/{exit} {print}' \
  supabase/tests/52_security_posture.sql | tail -140 | grep -oE "'fn_[a-z0-9_]+'" | tr -d "'" | sort -u)
DEPLOY=$(awk '/^read -r -d/,/^EOF$/' scripts/check-security-posture.sh \
  | grep -oE "'fn_[a-z0-9_]+'" | tr -d "'" | sort -u)

if [ "$PGTAP" = "$DEPLOY" ]; then
  echo "  PASS: anon allowlist identical in 52.7 and check-security-posture.sh ($(echo "$PGTAP" | wc -l | tr -d ' ') names)"
  exit 0
fi

echo "  FAIL: the anon allowlist differs between its two copies." >&2
echo "" >&2
echo "  In 52.7 but NOT in scripts/check-security-posture.sh (deploy would REJECT these):" >&2
comm -23 <(echo "$PGTAP") <(echo "$DEPLOY") | sed 's/^/    /' >&2
echo "  In scripts/check-security-posture.sh but NOT in 52.7 (silently permitted at deploy):" >&2
comm -13 <(echo "$PGTAP") <(echo "$DEPLOY") | sed 's/^/    /' >&2
exit 1
