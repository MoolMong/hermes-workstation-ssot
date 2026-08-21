#!/usr/bin/env bash
# Milestone 2: image-readiness gate — hermes-doctor must refuse to declare
# the instance image-safe while any credential/session path is populated,
# and must declare it PASS when none are. Also cross-checks that
# connect-common.sh's credential_paths() (the single source of truth used
# by both hermes-connect's "already configured" detection and
# hermes-doctor's image-readiness check) matches what SECURITY.md §3
# documents, so the two cannot silently drift apart.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCTOR="$REPO_ROOT/bootstrap/doctor.sh"
# shellcheck source=tests/connection/lib_fakebin.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib_fakebin.sh"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKEBIN="$TMP/fakebin"
make_fakebin "$FAKEBIN"
make_fake_curl "$FAKEBIN" "$TMP/captured_curl_cfg"

run_doctor() {
  local data="$1" sysd="$2"
  CALL_LOG="$TMP/call.log" \
  HERMES_DATA_ROOT="$data" \
  HERMES_SYSTEMD_DIR="$sysd" \
  HERMES_COMPOSE_FILE="$REPO_ROOT/docker/docker-compose.yml" \
  HERMES_CURL_BIN="$FAKEBIN/curl" \
  PATH="$FAKEBIN:$PATH" \
  bash "$DOCTOR"
}

# --- Scenario 1: nothing populated -> Image readiness PASS -----------------
export FAKE_HERMES_AUTH_STATUS_EXIT=1
export FAKE_GH_AUTH_STATUS_EXIT=1
DATA1="$TMP/data1"; SYSD1="$TMP/sysd1"
mkdir -p "$DATA1" "$SYSD1"
OUT1="$(run_doctor "$DATA1" "$SYSD1" 2>&1)"
echo "$OUT1" | grep -qE '^Image readiness\s+PASS' && r=0 || r=1
check "$r" "an unpopulated data root reports Image readiness PASS"

# --- Scenario 2: each individually-populated credential path -> FAIL ------
for path_rel in ".env" "auth.json" "auth/claude/.credentials.json" "auth/github/gh/hosts.yml"; do
  DATA="$TMP/data-$path_rel-only"
  DATA="${DATA//\//_}"
  DATA="$TMP/$DATA"
  SYSD="$TMP/sysd-$path_rel"
  SYSD="${SYSD// /_}"
  mkdir -p "$DATA" "$SYSD"
  mkdir -p "$(dirname "$DATA/$path_rel")"
  echo "placeholder" > "$DATA/$path_rel"
  OUT="$(run_doctor "$DATA" "$SYSD" 2>&1)"
  echo "$OUT" | grep -qE '^Image readiness\s+FAIL' && r=0 || r=1
  check "$r" "a populated $path_rel alone makes Image readiness report FAIL"
done
unset FAKE_HERMES_AUTH_STATUS_EXIT FAKE_GH_AUTH_STATUS_EXIT

# --- Cross-check: credential_paths() matches SECURITY.md §3 ----------------
# shellcheck disable=SC1090
CRED_PATHS="$(
  HERMES_DATA_ROOT=/opt/hermes-data bash -c '
    SCRIPT_DIR="'"$REPO_ROOT"'/bootstrap"
    HERMES_TOOL_NAME=test
    source "$SCRIPT_DIR/connect-common.sh" 2>/dev/null || true
    credential_paths
  ' 2>/dev/null || true
)"
[ -n "$CRED_PATHS" ] && r=0 || r=1
check "$r" "credential_paths() produced a non-empty path list"

MISSING=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  grep -qF "$p" "$REPO_ROOT/SECURITY.md" || { echo "  not documented in SECURITY.md: $p"; MISSING=1; }
done <<< "$CRED_PATHS"
[ "$MISSING" -eq 0 ] && r=0 || r=1
check "$r" "every path in credential_paths() is documented in SECURITY.md §3"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
