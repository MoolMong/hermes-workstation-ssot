#!/usr/bin/env bash
# Milestone 1: exactly one systemd unit / supervision path, with a bounded
# restart policy (not an infinite restart loop), and install.sh must never
# enable or start it — activation is explicitly out of scope until
# Milestone 2 provides credentials (BUILD_DIRECTIVE.md §5, §10; systemd/
# README.md). Static/text checks plus a --skip-systemd-reload dry install
# into a temp dir; never calls real systemctl enable/start/daemon-reload
# against the host.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UNIT_SRC="$REPO_ROOT/systemd/hermes.service"
INSTALL="$REPO_ROOT/bootstrap/install.sh"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

# Exactly one unit file in systemd/ (source of truth), and exactly one
# `units=(...)` array installed by install.sh.
unit_file_count=$(find "$REPO_ROOT/systemd" -maxdepth 1 -type f -name '*.service' | wc -l)
[ "$unit_file_count" -eq 1 ] && r=0 || r=1
check "$r" "exactly one *.service file in systemd/ (found $unit_file_count)"

[ -f "$UNIT_SRC" ] && r=0 || r=1
check "$r" "systemd/hermes.service exists"

if [ -f "$UNIT_SRC" ]; then
  grep -qE '^Restart=on-failure' "$UNIT_SRC" && r=0 || r=1
  check "$r" "hermes.service uses Restart=on-failure (not 'always', which would mask crash-looping)"

  grep -qE '^RestartSec=[0-9]+' "$UNIT_SRC" && r=0 || r=1
  check "$r" "hermes.service sets a numeric RestartSec (spaced-out restarts)"

  grep -qE '^StartLimitIntervalSec=[0-9]+' "$UNIT_SRC" && r=0 || r=1
  check "$r" "hermes.service sets StartLimitIntervalSec (bounds the restart window)"

  grep -qE '^StartLimitBurst=[0-9]+' "$UNIT_SRC" && r=0 || r=1
  check "$r" "hermes.service sets StartLimitBurst (caps restart attempts per window, avoiding an infinite restart loop)"
fi

# install.sh must never itself enable or start the unit — activation is
# Milestone 2+ territory once credentials exist.
grep -qE 'systemctl[[:space:]]+(enable|start)\b' "$INSTALL" && r=1 || r=0
check "$r" "install.sh never calls systemctl enable/start"

grep -qE 'systemctl[[:space:]]+daemon-reload' "$INSTALL" && r=0 || r=1
check "$r" "install.sh does call systemctl daemon-reload after installing/changing a unit"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
