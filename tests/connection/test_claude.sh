#!/usr/bin/env bash
# Milestone 2: Claude Code connection — CLI-availability check, persistent
# credential directory, and the minimal real invocation smoke test
# required by MILESTONE2_DIRECTIVE.md §5 ("a successful login alone is not
# enough"). The pinned CLI's non-destructive `claude auth status` is the
# health check; setup-token and documented auth-login alternatives are the
# supported setup paths. Never talks to a real Anthropic backend.
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

# --- Scenario 1: fresh instance -> setup-token then a real smoke test -----
DATA1="$TMP/data1"
: > "$TMP/call.log"
export FAKE_CLAUDE_CREDENTIAL_DIR="$DATA1/auth/claude"
OUT1="$(run_connect "$DATA1" --claude 2>&1)"
STATUS1=$?
unset FAKE_CLAUDE_CREDENTIAL_DIR
[ "$STATUS1" -eq 0 ] && r=0 || r=1
check "$r" "fresh Claude Code setup+validate exits 0"
echo "$OUT1" | grep -qE '^\[3/4\] Claude Code\s+PASS$' && r=0 || r=1
check "$r" "status line reports Claude Code PASS"
grep -qxF 'claude setup-token' "$TMP/call.log" && r=0 || r=1
check "$r" "claude_setup runs exactly: claude setup-token"
grep -qxF 'claude auth status' "$TMP/call.log" && r=0 || r=1
check "$r" "claude_validate runs exactly: claude auth status"
grep -q '^claude -p ' "$TMP/call.log" && r=0 || r=1
check "$r" "claude_validate performs a real -p invocation (minimal smoke test), not just a status check"
grep -q -- '--max-turns 1' "$TMP/call.log" && r=0 || r=1
check "$r" "the smoke test is bounded to a single turn"

perm="$(stat -c %a "$DATA1/auth/claude" 2>/dev/null || echo missing)"
[ "$perm" = "700" ] && r=0 || r=1
check "$r" "$DATA1/auth/claude is 0700 (got $perm)"

# --- Scenario 2: CLI unavailable -> FAIL, no smoke test attempted ---------
DATA2="$TMP/data2"
: > "$TMP/call.log"
export FAKE_CLAUDE_VERSION_EXIT=1
export FAKE_CLAUDE_SETUP_TOKEN_EXIT=1
OUT2="$(run_connect "$DATA2" --claude 2>&1)"
STATUS2=$?
unset FAKE_CLAUDE_VERSION_EXIT FAKE_CLAUDE_SETUP_TOKEN_EXIT
[ "$STATUS2" -ne 0 ] && r=0 || r=1
check "$r" "an unavailable claude CLI makes hermes-connect exit non-zero"
echo "$OUT2" | grep -qE '^\[3/4\] Claude Code\s+FAIL$' && r=0 || r=1
check "$r" "status line reports Claude Code FAIL when the CLI is unavailable"

# --- Scenario 3: login succeeds but the real smoke test fails -> FAIL -----
# This is the concrete case MILESTONE2_DIRECTIVE.md §5 calls out: a
# successful login alone must not be reported as PASS.
DATA3="$TMP/data3"
: > "$TMP/call.log"
export FAKE_CLAUDE_CREDENTIAL_DIR="$DATA3/auth/claude"
export FAKE_CLAUDE_SMOKE_OUTPUT="not the expected reply"
OUT3="$(run_connect "$DATA3" --claude 2>&1)"
STATUS3=$?
unset FAKE_CLAUDE_CREDENTIAL_DIR FAKE_CLAUDE_SMOKE_OUTPUT
[ "$STATUS3" -ne 0 ] && r=0 || r=1
check "$r" "a successful login with a failing smoke-test reply is not reported as success"
echo "$OUT3" | grep -qE '^\[3/4\] Claude Code\s+FAIL$' && r=0 || r=1
check "$r" "status line reports Claude Code FAIL when the smoke-test reply is wrong"
grep -qxF 'claude setup-token' "$TMP/call.log" && r=0 || r=1
check "$r" "setup-token still ran (login itself succeeded)"

# --- Scenario 4: auth status fails after setup -> FAIL ----------------------
DATA4="$TMP/data4"
: > "$TMP/call.log"
export FAKE_CLAUDE_CREDENTIAL_DIR="$DATA4/auth/claude"
export FAKE_CLAUDE_AUTH_STATUS_EXIT=1
OUT4="$(run_connect "$DATA4" --claude 2>&1)"
STATUS4=$?
unset FAKE_CLAUDE_CREDENTIAL_DIR FAKE_CLAUDE_AUTH_STATUS_EXIT
[ "$STATUS4" -ne 0 ] && r=0 || r=1
check "$r" "a failing claude auth status is not reported as success"
echo "$OUT4" | grep -q -- 'claude auth login --claudeai' && r=0 || r=1
check "$r" "recovery documents the supported claude auth login path"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
