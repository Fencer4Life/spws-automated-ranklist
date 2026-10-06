#!/bin/bash
# Recapture WordPress 768 and 1280 px in English, twice per build, to see whether the
# table bar's differences follow the build or the capture run.
S=/private/tmp/claude-501/-Users-aleks-coding-SPWSranklist/695986ee-c7d8-4901-8d14-a59bc55fc0f9/scratchpad
for run in 1 2; do
  for build in after fixed; do
    for f in wp-768-en wp-1280-en; do
      node "$S/cap/capture-right.mjs" "$S/$build" "$S/shots-bars/$build-$run-$f" "$f" > /dev/null 2>&1
    done
  done
done
python3 - <<'EOF'
import json, pathlib
S = pathlib.Path('/private/tmp/claude-501/-Users-aleks-coding-SPWSranklist/695986ee-c7d8-4901-8d14-a59bc55fc0f9/scratchpad/shots-bars')
for d in sorted(S.iterdir()):
    print(d.name, sorted(json.loads((d / 'meta.json').read_text()).keys())[:2], '...')
EOF
