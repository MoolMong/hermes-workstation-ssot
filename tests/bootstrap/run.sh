#!/usr/bin/env bash
# Milestone 1 deterministic test runner. Runs a bash -n syntax check over
# every shell script this milestone introduces, then runs every
# tests/bootstrap/test_*.sh in this directory, and prints a pass/fail
# summary. Dependency-free beyond bash + coreutils. Never invokes Docker,
# apt-get install, or systemctl enable/start/daemon-reload against the
# real host — every test below operates inside its own throwaway temp
# directory or a PATH-isolated sandbox.
#
# Exit 0 iff every syntax check and every test script passes.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
TESTS_DIR="$(pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"

FAIL=0
CHECK_COUNT=0

pass() { CHECK_COUNT=$((CHECK_COUNT + 1)); echo "PASS: $1"; }
fail() { CHECK_COUNT=$((CHECK_COUNT + 1)); FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

echo "== Milestone 1 bootstrap test run =="
echo "Repo root: $REPO_ROOT"
echo

echo "-- Syntax checks (bash -n) --"
SYNTAX_TARGETS=(
  "bootstrap/install.sh"
  "docker/entrypoint.sh"
)
for f in "${SYNTAX_TARGETS[@]}"; do
  if bash -n "$REPO_ROOT/$f" 2>/tmp/synerr.$$; then
    pass "bash -n: $f"
  else
    fail "bash -n: $f -- $(cat /tmp/synerr.$$)"
  fi
  rm -f /tmp/synerr.$$
done
for f in "$TESTS_DIR"/test_*.sh; do
  rel="tests/bootstrap/$(basename "$f")"
  if bash -n "$f" 2>/tmp/synerr.$$; then
    pass "bash -n: $rel"
  else
    fail "bash -n: $rel -- $(cat /tmp/synerr.$$)"
  fi
  rm -f /tmp/synerr.$$
done
echo

echo "-- Test scripts --"
TEST_SCRIPTS=("$TESTS_DIR"/test_*.sh)
if [ "${#TEST_SCRIPTS[@]}" -eq 0 ]; then
  fail "no tests/bootstrap/test_*.sh scripts found"
fi
for t in "${TEST_SCRIPTS[@]}"; do
  name="$(basename "$t")"
  echo "  running $name ..."
  if OUT="$(bash "$t" 2>&1)"; then
    if echo "$OUT" | tail -n1 | grep -q '^RESULT: PASS$'; then
      pass "$name"
    else
      fail "$name (exited 0 but did not print RESULT: PASS)"
      echo "$OUT" | sed 's/^/    /'
    fi
  else
    fail "$name (nonzero exit)"
    echo "$OUT" | sed 's/^/    /'
  fi
done
echo

echo "== Summary =="
echo "Checks run: $CHECK_COUNT"
echo "Checks failed: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
