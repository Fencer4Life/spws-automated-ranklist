#!/bin/bash
# Build one sheet harness (form-harness or card-harness) from one checkout.
# usage: build_harness.sh <harness dir name> <checkout root> <output dir>
# The harness is copied into <checkout>/frontend/.sheet-harness, built with the
# checkout's own components and node_modules, and the copy removed again.
set -euo pipefail
NAME=$1
SRC_ROOT=$2
OUT=$3
HERE=$(cd "$(dirname "$0")" && pwd)
H="$SRC_ROOT/frontend/.sheet-harness"
rm -rf "$H"
mkdir -p "$H"
cp "$HERE/$NAME/index.html" "$HERE/$NAME/main.ts" "$H/"
cp "$HERE/harness.vite.config.mjs" "$SRC_ROOT/frontend/.sheet-harness.vite.config.mjs"
cd "$SRC_ROOT/frontend"
npx vite build --config .sheet-harness.vite.config.mjs --outDir "$OUT" --emptyOutDir 2>&1 | tail -1
rm -rf "$H" "$SRC_ROOT/frontend/.sheet-harness.vite.config.mjs"
# the organisers' logos the card shows, served beside the harness
cp "$SRC_ROOT"/frontend/public/*-logo.* "$OUT/"
