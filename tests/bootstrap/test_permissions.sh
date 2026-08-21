#!/usr/bin/env bash
# Milestone 1: every directory/file bootstrap/install.sh creates under the
# data root must be private (0700 for directories, 0600 for files) — this
# tree will hold credentials from Milestone 2 onward (SECURITY.md §3), so
# permissions must be correct from the first bootstrap, not tightened
# later. Runs entirely inside a throwaway temp directory.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/hermes-data"
SYSD="$TMP/systemd"
BIN="$TMP/bin"

bash "$REPO_ROOT/bootstrap/install.sh" \
  --data-root "$DATA" --systemd-dir "$SYSD" --bin-dir "$BIN" --repo-root "$REPO_ROOT" \
  --skip-prereqs --skip-docker --skip-systemd-reload >/tmp/perm_out.$$ 2>&1
STATUS=$?

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

check "$STATUS" "install.sh exits 0"

perm=$(stat -c %a "$DATA")
[ "$perm" = "700" ] && r=0 || r=1
check "$r" "data root $DATA is 0700 (got $perm)"

for d in auth config workspaces tasks logs backup; do
  perm=$(stat -c %a "$DATA/$d" 2>/dev/null)
  [ "$perm" = "700" ] && r=0 || r=1
  check "$r" "$DATA/$d is 0700 (got ${perm:-missing})"
done

perm=$(stat -c %a "$DATA/config/hermes.config.yaml" 2>/dev/null)
[ "$perm" = "600" ] && r=0 || r=1
check "$r" "rendered hermes.config.yaml is 0600 (got ${perm:-missing})"

perm=$(stat -c %a "$DATA/.provenance" 2>/dev/null)
[ "$perm" = "600" ] && r=0 || r=1
check "$r" ".provenance is 0600 (got ${perm:-missing})"

# The installed systemd unit is not credential-bearing and must remain
# world-readable (systemd requires this) — 0644, not 0600.
perm=$(stat -c %a "$SYSD/hermes.service" 2>/dev/null)
[ "$perm" = "644" ] && r=0 || r=1
check "$r" "installed hermes.service is 0644 (got ${perm:-missing})"

# Host launcher wrappers (Milestone 2) are executable, not
# credential-bearing, so 0755 is correct (not 0600).
for launcher in hermes-connect hermes-doctor; do
  perm=$(stat -c %a "$BIN/$launcher" 2>/dev/null)
  [ "$perm" = "755" ] && r=0 || r=1
  check "$r" "installed $launcher launcher is 0755 (got ${perm:-missing})"
done

if [ "$FAIL" -ne 0 ]; then
  cat /tmp/perm_out.$$ >&2
  rm -f /tmp/perm_out.$$
  echo "RESULT: FAIL"
  exit 1
fi
rm -f /tmp/perm_out.$$
echo "RESULT: PASS"
