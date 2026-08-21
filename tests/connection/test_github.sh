#!/usr/bin/env bash
# Milestone 2: GitHub connection — HTTPS + gh CLI credential-helper flow
# (no SSH key management), exact official commands, and the optional
# SSOT-remote-read check never printing the remote URL (an HTTPS remote
# can embed a credential, e.g. https://oauth2:TOKEN@github.com/...).
# Never talks to a real GitHub API.
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
  local data="$1" reporoot="$2"; shift 2
  CALL_LOG="$TMP/call.log" \
  HERMES_DATA_ROOT="$data" \
  HERMES_REPO_ROOT="$reporoot" \
  HERMES_EXEC="" \
  PATH="$FAKEBIN:$PATH" \
  bash "$CONNECT" "$@"
}

# --- Scenario 1: not authenticated -> setup runs the exact login flow -----
DATA1="$TMP/data1"
: > "$TMP/call.log"
export FAKE_GH_AUTH_STATUS_EXIT=1
OUT1="$(run_connect "$DATA1" "$REPO_ROOT" --github 2>&1)"
STATUS1=$?
unset FAKE_GH_AUTH_STATUS_EXIT
[ "$STATUS1" -ne 0 ] && r=0 || r=1
check "$r" "gh auth status failing throughout leaves hermes-connect exit non-zero"
grep -qxF 'gh auth login --hostname github.com --git-protocol https --web' "$TMP/call.log" && r=0 || r=1
check "$r" "github_setup runs exactly: gh auth login --hostname github.com --git-protocol https --web"
grep -qxF 'gh auth setup-git' "$TMP/call.log" && r=0 || r=1
check "$r" "github_setup runs exactly: gh auth setup-git"
grep -qE '^gh --version|ssh-keygen|ssh-add' "$TMP/call.log" && r=1 || r=0
check "$r" "no SSH key management is performed"

perm="$(stat -c %a "$DATA1/auth/github" 2>/dev/null || echo missing)"
[ "$perm" = "700" ] && r=0 || r=1
check "$r" "$DATA1/auth/github is 0700 (got $perm)"

# --- Scenario 2: already authenticated -> validate runs status + api user -
DATA2="$TMP/data2"
: > "$TMP/call.log"
OUT2="$(run_connect "$DATA2" "$REPO_ROOT" --github 2>&1)"
STATUS2=$?
[ "$STATUS2" -eq 0 ] && r=0 || r=1
check "$r" "healthy GitHub integration validates PASS"
echo "$OUT2" | grep -qE '^\[4/4\] GitHub\s+PASS$' && r=0 || r=1
check "$r" "status line reports GitHub PASS"
grep -qxF 'gh auth status --hostname github.com' "$TMP/call.log" && r=0 || r=1
check "$r" "validation runs exactly: gh auth status --hostname github.com"
grep -qxF 'gh api user' "$TMP/call.log" && r=0 || r=1
check "$r" "validation runs exactly: gh api user (authenticated read check)"
grep -qxF 'gh auth login --hostname github.com --git-protocol https --web' "$TMP/call.log" && r=1 || r=0
check "$r" "an already-healthy GitHub integration is not reconfigured"

# --- Scenario 3: optional remote-read check never prints the remote URL ---
GITREPO="$TMP/gitrepo"
mkdir -p "$GITREPO"
git -C "$GITREPO" init -q
SENSITIVE_URL="https://oauth2:super-secret-embedded-token@github.example/owner/repo.git"
git -C "$GITREPO" remote add origin "$SENSITIVE_URL"
: > "$TMP/call.log"
OUT3="$(run_connect "$DATA2" "$GITREPO" --github 2>&1)"
STATUS3=$?
[ "$STATUS3" -eq 0 ] && r=0 || r=1
check "$r" "GitHub check with a remote configured still exits 0 (already healthy)"
echo "$OUT3" | grep -qF "super-secret-embedded-token" && r=1 || r=0
check "$r" "the configured remote URL (which can embed a credential) is never printed"
echo "$OUT3" | grep -qF "$SENSITIVE_URL" && r=1 || r=0
check "$r" "the full remote URL string never appears in hermes-connect output"
echo "$OUT3" | grep -q "github.example" && r=0 || r=1
check "$r" "only the remote host, not the full URL, is reported"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
