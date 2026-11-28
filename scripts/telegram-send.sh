#!/usr/bin/env bash
# Send one Telegram message from a workflow step, and print only the HTTP status.
#
# Usage:  "$GITHUB_WORKSPACE/scripts/telegram-send.sh" [--html] MESSAGE
# Reads TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID from the step's env.
#
# Telegram answers an accepted message with the chat it reached, the chat owner's
# first and last name included. GitHub hides the chat id, a secret, and not the
# name, and this repository's run logs are public. So the answer is never printed:
# an accepted message prints "Telegram: HTTP 200", and a refusal prints the status
# and Telegram's reason, which names no one, so the log still says why a message
# did not arrive (LOG.PRIV.07-08; mailbox errors plan 2026-11-28, E5, D4 B).
#
# curl, not python/telegram.py: some of these steps report a failed setup step, and
# python/telegram.py needs httpx, which such a job may never have installed. As
# before, a refusal by Telegram does not fail the step; a curl that cannot reach
# Telegram does.
set -euo pipefail

parse_mode=()
if [[ "${1:-}" == "--html" ]]; then
  parse_mode=(--data-urlencode "parse_mode=HTML")
  shift
fi
message="${1:?usage: telegram-send.sh [--html] MESSAGE}"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID is not set}"

reply="$(mktemp)"
trap 'rm -f "$reply"' EXIT

status="$(curl -sS -X POST -o "$reply" -w '%{http_code}' \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  ${parse_mode[@]+"${parse_mode[@]}"} \
  --data-urlencode "text=${message}")"

if [[ "$status" == "200" ]]; then
  echo "Telegram: HTTP 200"
else
  echo "Telegram: HTTP ${status}: $(head -c 300 "$reply")" >&2
fi
