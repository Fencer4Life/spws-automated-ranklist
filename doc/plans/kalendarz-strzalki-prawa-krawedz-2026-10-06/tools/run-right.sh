#!/bin/bash
# Capture the approved build, the fixed build, and the approved build again (noise floor).
S=/private/tmp/claude-501/-Users-aleks-coding-SPWSranklist/695986ee-c7d8-4901-8d14-a59bc55fc0f9/scratchpad
node "$S/cap/capture-right.mjs" "$S/after" "$S/shots-right/approved" > "$S/shots-right-approved.log" 2>&1
node "$S/cap/capture-right.mjs" "$S/fixed" "$S/shots-right/fixed" > "$S/shots-right-fixed.log" 2>&1
node "$S/cap/capture-right.mjs" "$S/after" "$S/shots-right/approved2" > "$S/shots-right-approved2.log" 2>&1
tail -n 1 "$S/shots-right-approved.log" "$S/shots-right-fixed.log" "$S/shots-right-approved2.log"
