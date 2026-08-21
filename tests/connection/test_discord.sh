#!/usr/bin/env bash
# Milestone 2: Discord connection — config write, allow-list validation
# (refuses allow-all), permissions, and real token validation via a mocked
# Discord API, with the token only ever reaching curl through a 0600
# config file, never argv/stdout/stderr. Never talks to a real Discord API.
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

TOKEN="FAKE.DISCORD.TOKEN.abcdef0123456789"
USER_ID="111111111111111111"

run_connect() {
  local data="$1"; shift
  CALL_LOG="$TMP/call.log" \
  HERMES_DATA_ROOT="$data" \
  HERMES_EXEC="" \
  HERMES_CURL_BIN="$FAKEBIN/curl" \
  PATH="$FAKEBIN:$PATH" \
  bash "$CONNECT" "$@"
}

# --- Scenario 1: valid setup + validate PASS --------------------------------
DATA1="$TMP/data1"
: > "$TMP/call.log"
OUT1="$(printf '%s\n%s\n\n\n' "$TOKEN" "$USER_ID" | run_connect "$DATA1" --discord 2>&1)"
STATUS1=$?
[ "$STATUS1" -eq 0 ] && r=0 || r=1
check "$r" "valid Discord setup+validate exits 0"
echo "$OUT1" | grep -qE '^\[1/4\] Discord\s+PASS$' && r=0 || r=1
check "$r" "status line reports Discord PASS"

perm="$(stat -c %a "$DATA1/.env" 2>/dev/null || echo missing)"
[ "$perm" = "600" ] && r=0 || r=1
check "$r" "$DATA1/.env is 0600 (got $perm)"

grep -q '^DISCORD_BOT_TOKEN=' "$DATA1/.env" 2>/dev/null && r=0 || r=1
check "$r" ".env contains DISCORD_BOT_TOKEN"
grep -q '^DISCORD_ALLOW_ALL_USERS=false$' "$DATA1/.env" 2>/dev/null && r=0 || r=1
check "$r" ".env always writes DISCORD_ALLOW_ALL_USERS=false"

# --- Secret hygiene: token never in connect.sh's own stdout/stderr ---------
echo "$OUT1" | grep -qF "$TOKEN" && r=1 || r=0
check "$r" "the Discord token never appears in hermes-connect's own stdout/stderr"

# --- Secret hygiene: token never passed to curl via argv --------------------
grep -qF "$TOKEN" "$TMP/call.log" && r=1 || r=0
check "$r" "the Discord token never appears in curl's logged argv"

# --- Token reaches curl only via a 0600 config file --------------------------
[ -f "$TMP/captured_curl_cfg" ] && r=0 || r=1
check "$r" "discord_validate_token invoked curl with a -K config file"
if [ -f "$TMP/captured_curl_cfg" ]; then
  grep -qF "Authorization: Bot $TOKEN" "$TMP/captured_curl_cfg" && r=0 || r=1
  check "$r" "the curl config file carries the real token in the Authorization header"
fi

# --- Scenario 2: refuses allow-all (blank users/roles/channels) ------------
DATA2="$TMP/data2"
: > "$TMP/call.log"
OUT2="$(printf '%s\n\n\n\n' "$TOKEN" | run_connect "$DATA2" --discord 2>&1)"
STATUS2=$?
[ "$STATUS2" -ne 0 ] && r=0 || r=1
check "$r" "Discord setup with no allow-list entries fails (refuses allow-all)"
echo "$OUT2" | grep -qi 'refusing to allow-all' && r=0 || r=1
check "$r" "reports refusing an allow-all configuration"
[ -e "$DATA2/.env" ] && r=1 || r=0
check "$r" "no .env is written when allow-list validation fails"

# --- Scenario 3: rejects malformed snowflake ID -----------------------------
DATA3="$TMP/data3"
OUT3="$(printf '%s\nnot-a-snowflake\n\n\n' "$TOKEN" | run_connect "$DATA3" --discord 2>&1)"
STATUS3=$?
[ "$STATUS3" -ne 0 ] && r=0 || r=1
check "$r" "Discord setup with a malformed ID fails"
echo "$OUT3" | grep -qi 'invalid Discord ID list' && r=0 || r=1
check "$r" "reports the invalid Discord ID list"

# --- Scenario 4: token that fails validation reports FAIL + recovery -------
DATA4="$TMP/data4"
export FAKE_CURL_HTTP_CODE=401
OUT4="$(printf '%s\n%s\n\n\n' "$TOKEN" "$USER_ID" | run_connect "$DATA4" --discord 2>&1)"
STATUS4=$?
unset FAKE_CURL_HTTP_CODE
[ "$STATUS4" -ne 0 ] && r=0 || r=1
check "$r" "a token that fails Discord validation makes hermes-connect exit non-zero"
echo "$OUT4" | grep -qE '^\[1/4\] Discord\s+FAIL$' && r=0 || r=1
check "$r" "status line reports Discord FAIL on an invalid token"
echo "$OUT4" | grep -qi 'Suggested action' && r=0 || r=1
check "$r" "a recovery block is printed on Discord FAIL"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
