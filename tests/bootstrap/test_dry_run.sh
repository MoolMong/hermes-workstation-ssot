#!/usr/bin/env bash
# Milestone 1: bootstrap/install.sh --dry-run must make zero filesystem
# changes anywhere it is pointed, and must exit 0. Runs entirely inside a
# throwaway temp directory — never touches the real host.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/hermes-data"
SYSD="$TMP/systemd"
BIN="$TMP/bin"

OUT="$(bash "$REPO_ROOT/bootstrap/install.sh" --dry-run \
  --data-root "$DATA" --systemd-dir "$SYSD" --bin-dir "$BIN" --repo-root "$REPO_ROOT" 2>&1)"
STATUS=$?

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

check "$STATUS" "install.sh --dry-run exits 0"

[ -e "$DATA" ] && r=1 || r=0
check "$r" "dry-run does not create data root ($DATA)"

[ -e "$SYSD" ] && r=1 || r=0
check "$r" "dry-run does not create systemd dir ($SYSD)"

[ -e "$BIN" ] && r=1 || r=0
check "$r" "dry-run does not create bin dir ($BIN)"

echo "$OUT" | grep -q '\[dry-run\]' && r=0 || r=1
check "$r" "dry-run output announces planned actions with [dry-run] markers"

echo "$OUT" | grep -qi 'create.*hermes-data' && r=0 || r=1
check "$r" "dry-run output describes the data-directory stage"

echo "$OUT" | grep -qi 'render.*hermes.config.yaml' && r=0 || r=1
check "$r" "dry-run output describes the config-render stage"

echo "$OUT" | grep -qi 'hermes-connect.*hermes-doctor' && r=0 || r=1
check "$r" "dry-run output describes the host-launcher stage"

if [ "$FAIL" -ne 0 ]; then
  echo "$OUT" >&2
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
