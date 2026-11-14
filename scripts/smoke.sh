#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Vince Bono
# Starts the stack and checks the claims the README makes. Used by CI.
set -euo pipefail

MODEL="${MODEL:-llama3.2:3b}"
URL="http://127.0.0.1:${WEBUI_PORT:-3000}"
export MODEL

fail() { docker compose ps -a; docker compose logs --tail 15 open-webui; echo "FAIL: $*"; exit 1; }

wait_for() { # wait_for <seconds> <description> <command...>
  local limit=$1 what=$2; shift 2
  for ((i = 0; i < limit; i += 5)); do "$@" >/dev/null 2>&1 && return 0; sleep 5; done
  fail "timed out waiting for $what"
}

docker compose up -d

wait_for 600 "Open WebUI health" curl -fsS "$URL/health"
wait_for 600 "model $MODEL" sh -c "docker compose exec -T ollama ollama list | grep -q '^$MODEL'"

answer=$(docker compose exec -T ollama ollama run "$MODEL" "Reply with one short sentence.")
[ -n "$answer" ] || fail "model returned nothing"
echo "model answered: $answer"

curl -s --max-time 5 http://127.0.0.1:11434/api/version >/dev/null && fail "Ollama answers on the host's port 11434"

code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/api/v1/chats/")
echo "API without a login: HTTP $code"
[ "$code" = 401 ] || [ "$code" = 403 ] || fail "API answered $code without a login (expected 401 or 403)"

echo "OK: stack is up, model answers, Ollama is not exposed, API needs a login"
