#!/bin/bash
# Build the event-form harness from one checkout.
# usage: build_form.sh <checkout root> <output dir>
# The harness is copied into <checkout>/frontend/.sheet-harness, built with the
# checkout's own components and node_modules, and the copy removed again.
set -euo pipefail
SRC_ROOT=$1
OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
H="$SRC_ROOT/frontend/.sheet-harness"
rm -rf "$H"
mkdir -p "$H"
cp "$HERE/form-harness/index.html" "$HERE/form-harness/main.ts" "$H/"
cp "$HERE/form-harness/vite.config.mjs" "$SRC_ROOT/frontend/.sheet-harness.vite.config.mjs"
cd "$SRC_ROOT/frontend"
npx vite build --config .sheet-harness.vite.config.mjs --outDir "$OUT" --emptyOutDir 2>&1 | tail -1
rm -rf "$H" "$SRC_ROOT/frontend/.sheet-harness.vite.config.mjs"
