#!/usr/bin/env bash
# Milestone 2: no Milestone 3+ functionality may exist yet —
# scripts/runner|monitor|verifier (M3-M5), a second systemd unit (M5), etc.
# (MILESTONES.md sequencing rule; BUILD_DIRECTIVE.md §15).
#
# This supersedes tests/bootstrap/test_no_m2_scope.sh, which asserted that
# bootstrap/connect.sh and bootstrap/doctor.sh did not exist yet — true
# during Milestone 1, no longer true now that Milestone 2 legitimately
# implements them. This is a standing regression check, not a one-time
# Milestone 2 check: it must keep passing at Milestone 2 forever, and
# should be revisited (paths added, not removed) if a later milestone
# legitimately introduces one of these files ahead of this test being
# updated to expect it.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

FORBIDDEN_PATHS=(
  "systemd/hermes-monitor.service"
  "scripts/runner"
  "scripts/monitor"
  "scripts/verifier"
)
for p in "${FORBIDDEN_PATHS[@]}"; do
  [ -e "$p" ] && r=1 || r=0
  check "$r" "M3+ path does not exist yet: $p"
done

# Milestone 2 does legitimately own these now.
for p in bootstrap/connect.sh bootstrap/doctor.sh; do
  [ -e "$p" ] && r=0 || r=1
  check "$r" "M2 path exists: $p"
done

# scripts/ must still be placeholder-only (no milestone before M3 owns it).
entries=$(find scripts -mindepth 1 | sort)
[ "$entries" = "scripts/README.md" ] && r=0 || r=1
check "$r" "scripts/ contains only README.md (M3-M5 not started)"

# Exactly one systemd unit file exists in the repo (hermes.service).
unit_count=$(find systemd -maxdepth 1 -type f -name '*.service' | wc -l)
[ "$unit_count" -eq 1 ] && r=0 || r=1
check "$r" "exactly one systemd unit file exists in systemd/ (found $unit_count)"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
