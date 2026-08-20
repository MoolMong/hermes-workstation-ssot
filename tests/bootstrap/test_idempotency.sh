#!/usr/bin/env bash
# Milestone 1: running bootstrap/install.sh twice must converge — no
# duplicated directories, no re-rendered config, no re-copied systemd
# units on the second run, and both runs exit 0. Skips the apt/Docker
# stages so this never touches real host packages. Runs entirely inside a
# throwaway temp directory.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/hermes-data"
SYSD="$TMP/systemd"
ARGS=(--data-root "$DATA" --systemd-dir "$SYSD" --repo-root "$REPO_ROOT" \
      --skip-prereqs --skip-docker --skip-systemd-reload)

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

OUT1="$(bash "$REPO_ROOT/bootstrap/install.sh" "${ARGS[@]}" 2>&1)"; S1=$?
check "$S1" "first run exits 0"

CONFIG_MTIME_1=$(stat -c %Y "$DATA/config/hermes.config.yaml" 2>/dev/null)
UNIT_MTIME_1=$(stat -c %Y "$SYSD/hermes.service" 2>/dev/null)
PROVENANCE_CREATED_1=$(grep '^created_at=' "$DATA/.provenance" 2>/dev/null)

sleep 1
OUT2="$(bash "$REPO_ROOT/bootstrap/install.sh" "${ARGS[@]}" 2>&1)"; S2=$?
check "$S2" "second run exits 0"

echo "$OUT2" | grep -q 'ALREADY: all data directories already present' && r=0 || r=1
check "$r" "second run reports data directories already present (no duplication)"

echo "$OUT2" | grep -q 'ALREADY:.*already rendered' && r=0 || r=1
check "$r" "second run reports rendered config already present (not re-rendered)"

echo "$OUT2" | grep -q 'ALREADY: systemd units already up to date' && r=0 || r=1
check "$r" "second run reports systemd units unchanged (not re-copied)"

CONFIG_MTIME_2=$(stat -c %Y "$DATA/config/hermes.config.yaml" 2>/dev/null)
[ "$CONFIG_MTIME_1" = "$CONFIG_MTIME_2" ] && r=0 || r=1
check "$r" "rendered config file was not rewritten on second run (mtime unchanged)"

UNIT_MTIME_2=$(stat -c %Y "$SYSD/hermes.service" 2>/dev/null)
[ "$UNIT_MTIME_1" = "$UNIT_MTIME_2" ] && r=0 || r=1
check "$r" "systemd unit file was not rewritten on second run (mtime unchanged)"

PROVENANCE_CREATED_2=$(grep '^created_at=' "$DATA/.provenance" 2>/dev/null)
[ "$PROVENANCE_CREATED_1" = "$PROVENANCE_CREATED_2" ] && r=0 || r=1
check "$r" "provenance created_at is preserved across re-runs (not reset)"

DIR_COUNT=$(find "$DATA" -mindepth 1 -maxdepth 1 -type d | wc -l)
[ "$DIR_COUNT" -eq 6 ] && r=0 || r=1
check "$r" "exactly 6 top-level data subdirectories exist after two runs (auth/config/workspaces/tasks/logs/backup, no duplicates)"

if [ "$FAIL" -ne 0 ]; then
  echo "--- run 1 output ---" >&2; echo "$OUT1" >&2
  echo "--- run 2 output ---" >&2; echo "$OUT2" >&2
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
