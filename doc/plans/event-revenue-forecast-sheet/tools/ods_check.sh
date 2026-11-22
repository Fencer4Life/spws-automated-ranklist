#!/usr/bin/env bash
# FR-176 — the proof by LibreOffice (not CI: LibreOffice is not there).
# Builds sample .ods files from invented data, lets LibreOffice recalculate and
# print them, and compares every recalculated total with the model.
#   bash ods_check.sh [outDir]      outDir defaults to a fresh temporary folder
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
OUT="${1:-$(mktemp -d)}"
SOFFICE=/Applications/LibreOffice.app/Contents/MacOS/soffice
mkdir -p "$OUT/xlsx" "$OUT/pdf"
"$ROOT/frontend/node_modules/.bin/esbuild" "$HERE/make_sample.ts" --bundle --platform=node --format=cjs --outfile="$OUT/make_sample.cjs" --log-level=warning
node "$OUT/make_sample.cjs" "$OUT"
node "$HERE/ods_variants.cjs" "$OUT"
PROFILE="file://$OUT/lo-profile"
# A fresh LibreOffice profile that recalculates every ODF file on load (the
# default keeps the stored values, which would prove nothing about formulas).
mkdir -p "$OUT/lo-profile/user"
cat > "$OUT/lo-profile/user/registrymodifications.xcu" <<'XCU'
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<item oor:path="/org.openoffice.Office.Calc/Formula/Load"><prop oor:name="ODFRecalcMode" oor:op="fuse"><value>0</value></prop></item>
<item oor:path="/org.openoffice.Office.Calc/Formula/Load"><prop oor:name="OOXMLRecalcMode" oor:op="fuse"><value>0</value></prop></item>
</oor:items>
XCU
for f in "$OUT"/*-poison.ods; do
  "$SOFFICE" -env:UserInstallation="$PROFILE" --headless --convert-to xlsx --outdir "$OUT/xlsx" "$f" >/dev/null 2>&1
done
for f in "$OUT"/*-forecast.ods "$OUT"/*-entries.ods; do
  "$SOFFICE" -env:UserInstallation="$PROFILE" --headless --convert-to pdf --outdir "$OUT/pdf" "$f" >/dev/null 2>&1
done
node "$HERE/ods_check.cjs" "$OUT"
echo "files in $OUT"
# The page's print beside the file's (change plan rev 2): needs a CE build.
if [ -n "${DIST_CE:-}" ]; then
  node "$HERE/print_check.cjs" "$ROOT/frontend" "$OUT" "$DIST_CE"
  "$ROOT/.venv/bin/python" "$HERE/print_check.py" "$OUT"
fi
