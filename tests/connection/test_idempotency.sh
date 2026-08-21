#!/usr/bin/env bash
# Milestone 2: hermes-connect is idempotent — a second run against an
# already-healthy install skips every setup step (no re-prompting, no
# duplicated config lines), and --reconnect is the only way to force
# reconfiguration. Never talks to any real external service.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONNECT="$REPO_ROOT/bootstrap/connect.sh"
# shellcheck source=tests/connection/lib_fakebin.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib_fakebin.sh"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKEBIN="$TMP/fakebin"
make_fakebin "$FAKEBIN"
make_fake_curl "$FAKEBIN" "$TMP/captured_curl_cfg"

DATA="$TMP/data"
TOKEN="FAKE.DISCORD.TOKEN.idempotency"
USER_ID="222222222222222222"

run_connect() {
  CALL_LOG="$TMP/call.log" \
  HERMES_DATA_ROOT="$DATA" \
  HERMES_EXEC="" \
  HERMES_CURL_BIN="$FAKEBIN/curl" \
  PATH="$FAKEBIN:$PATH" \
  bash "$CONNECT" "$@"
}

# First run: all four integrations from scratch.
: > "$TMP/call.log"
export FAKE_CLAUDE_CREDENTIAL_DIR="$DATA/auth/claude"
OUT_FIRST="$(printf '%s\n%s\n\n\n' "$TOKEN" "$USER_ID" | run_connect)"
STATUS_FIRST=$?
unset FAKE_CLAUDE_CREDENTIAL_DIR
[ "$STATUS_FIRST" -eq 0 ] && r=0 || r=1
check "$r" "first full hermes-connect run exits 0"
echo "$OUT_FIRST" | grep -q "All connections are ready." && r=0 || r=1
check "$r" "first run reports all connections ready"

# Second run against the now-healthy install: no setup call should fire
# for any integration, and no prompt is needed (no stdin provided).
: > "$TMP/call.log"
OUT_SECOND="$(run_connect </dev/null)"
STATUS_SECOND=$?
[ "$STATUS_SECOND" -eq 0 ] && r=0 || r=1
check "$r" "second hermes-connect run (no stdin needed) exits 0"
echo "$OUT_SECOND" | grep -q "All connections are ready." && r=0 || r=1
check "$r" "second run again reports all connections ready"

grep -qxF 'hermes auth add openai-codex --no-browser' "$TMP/call.log" && r=1 || r=0
check "$r" "second run does not re-run hermes auth add openai-codex"
grep -qxF 'claude setup-token' "$TMP/call.log" && r=1 || r=0
check "$r" "second run does not re-run claude setup-token"
grep -qxF 'gh auth login --hostname github.com --git-protocol https --web' "$TMP/call.log" && r=1 || r=0
check "$r" "second run does not re-run gh auth login"

token_count=$(grep -c '^DISCORD_BOT_TOKEN=' "$DATA/.env")
[ "$token_count" -eq 1 ] && r=0 || r=1
check "$r" "DISCORD_BOT_TOKEN appears exactly once in .env after two runs (got $token_count)"

# --reconnect forces every integration through setup again.
: > "$TMP/call.log"
export FAKE_CLAUDE_CREDENTIAL_DIR="$DATA/auth/claude"
OUT_RECONNECT="$(printf '%s\n%s\n\n\n' "$TOKEN" "$USER_ID" | run_connect --reconnect)"
STATUS_RECONNECT=$?
unset FAKE_CLAUDE_CREDENTIAL_DIR
[ "$STATUS_RECONNECT" -eq 0 ] && r=0 || r=1
check "$r" "--reconnect run exits 0"
grep -qxF 'hermes auth add openai-codex --no-browser' "$TMP/call.log" && r=0 || r=1
check "$r" "--reconnect does re-run hermes auth add openai-codex"
grep -qxF 'claude setup-token' "$TMP/call.log" && r=0 || r=1
check "$r" "--reconnect does re-run claude setup-token"

token_count2=$(grep -c '^DISCORD_BOT_TOKEN=' "$DATA/.env")
[ "$token_count2" -eq 1 ] && r=0 || r=1
check "$r" "DISCORD_BOT_TOKEN still appears exactly once after --reconnect (got $token_count2, no duplicated lines)"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
