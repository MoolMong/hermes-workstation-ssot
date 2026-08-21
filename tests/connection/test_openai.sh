#!/usr/bin/env bash
# Milestone 2: OpenAI/Codex connection — exact grounded official commands
# (`hermes auth add openai-codex --no-browser`, `hermes auth status
# openai-codex`), no fake/mock fallback on failure, already-configured
# provider/model selection through `hermes model`, and a real one-shot
# validation. Never talks to a real OpenAI/Hermes backend.
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

run_connect() {
  local data="$1"; shift
  CALL_LOG="$TMP/call.log" \
  HERMES_DATA_ROOT="$data" \
  HERMES_EXEC="" \
  PATH="$FAKEBIN:$PATH" \
  bash "$CONNECT" "$@"
}

# --- Scenario 1: not yet authenticated -> setup runs the exact add command -
# auth status always fails in this scenario (not configured), so setup
# runs but validate still fails afterward -> overall FAIL, but the exact
# add command must still have been issued.
DATA1="$TMP/data1"
: > "$TMP/call.log"
export FAKE_HERMES_AUTH_STATUS_EXIT=1
OUT1="$(run_connect "$DATA1" --openai 2>&1)"
STATUS1=$?
unset FAKE_HERMES_AUTH_STATUS_EXIT
[ "$STATUS1" -ne 0 ] && r=0 || r=1
check "$r" "OpenAI setup that never validates leaves hermes-connect exit non-zero"
grep -qxF 'hermes auth add openai-codex --no-browser' "$TMP/call.log" && r=0 || r=1
check "$r" "openai_setup runs exactly: hermes auth add openai-codex --no-browser"
grep -qxF 'hermes auth status openai-codex' "$TMP/call.log" && r=0 || r=1
check "$r" "openai validation runs exactly: hermes auth status openai-codex"
grep -qxF 'hermes model' "$TMP/call.log" && r=0 || r=1
check "$r" "openai setup runs the official hermes model provider/model picker"


# --- Scenario 2: already configured and healthy -> setup is skipped -------
DATA2="$TMP/data2"
: > "$TMP/call.log"
OUT2="$(run_connect "$DATA2" --openai 2>&1)"
STATUS2=$?
[ "$STATUS2" -eq 0 ] && r=0 || r=1
check "$r" "OpenAI already-healthy (default fake exits 0) validates PASS"
echo "$OUT2" | grep -qE '^\[2/4\] OpenAI\s+PASS$' && r=0 || r=1
check "$r" "status line reports OpenAI PASS"
grep -qxF 'hermes auth add openai-codex --no-browser' "$TMP/call.log" && r=1 || r=0
check "$r" "already-healthy OpenAI integration is not reconfigured (no auth add call)"
grep -q '^hermes -z ' "$TMP/call.log" && r=0 || r=1
check "$r" "openai validation performs a real Hermes one-shot"

# --- Scenario 3: --reconnect forces setup even when already healthy -------
DATA3="$TMP/data3"
: > "$TMP/call.log"
OUT3="$(run_connect "$DATA3" --openai --reconnect 2>&1)"
STATUS3=$?
[ "$STATUS3" -eq 0 ] && r=0 || r=1
check "$r" "--reconnect on a healthy OpenAI integration still validates PASS"
grep -qxF 'hermes auth add openai-codex --no-browser' "$TMP/call.log" && r=0 || r=1
check "$r" "--reconnect re-runs hermes auth add openai-codex --no-browser"
grep -qxF 'hermes model' "$TMP/call.log" && r=0 || r=1
check "$r" "--reconnect re-runs official provider/model selection"

# --- Scenario 4: auth add fails outright -> no fake/mock fallback ---------
DATA4="$TMP/data4"
: > "$TMP/call.log"
export FAKE_HERMES_AUTH_ADD_EXIT=1
export FAKE_HERMES_AUTH_STATUS_EXIT=1
OUT4="$(run_connect "$DATA4" --openai 2>&1)"
STATUS4=$?
unset FAKE_HERMES_AUTH_ADD_EXIT FAKE_HERMES_AUTH_STATUS_EXIT
[ "$STATUS4" -ne 0 ] && r=0 || r=1
check "$r" "a failing hermes auth add makes hermes-connect exit non-zero"
echo "$OUT4" | grep -qE '^\[2/4\] OpenAI\s+FAIL$' && r=0 || r=1
check "$r" "status line reports OpenAI FAIL, not a fabricated PASS"
[ -e "$DATA4/auth.json" ] && r=1 || r=0
check "$r" "no fake auth.json is fabricated by connect.sh itself on failure"

# --- Scenario 5: auth/model configured but real one-shot fails -> FAIL ------
DATA5="$TMP/data5"
: > "$TMP/call.log"
export FAKE_HERMES_SMOKE_OUTPUT="not the expected reply"
OUT5="$(run_connect "$DATA5" --openai 2>&1)"
STATUS5=$?
unset FAKE_HERMES_SMOKE_OUTPUT
[ "$STATUS5" -ne 0 ] && r=0 || r=1
check "$r" "a failing Hermes provider/model one-shot is not reported as success"
echo "$OUT5" | grep -qE '^\[2/4\] OpenAI\s+FAIL$' && r=0 || r=1
check "$r" "status line reports OpenAI FAIL when real provider/model validation fails"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
