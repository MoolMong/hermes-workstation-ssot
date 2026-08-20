#!/usr/bin/env bash
# Milestone 1: every file bootstrap/install.sh writes must be traceable
# back to this repository (BUILD_DIRECTIVE.md §7) — a provenance header on
# rendered/installed text files, and a .provenance record for the data
# root itself naming the exact repo commit and pinned Hermes commit used.
# Runs entirely inside a throwaway temp directory.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/hermes-data"
SYSD="$TMP/systemd"
PIN_COMMIT="$(grep -vE '^\s*#|^\s*$' "$REPO_ROOT/bootstrap/hermes-commit.pin" | head -n1 | tr -d '[:space:]')"

bash "$REPO_ROOT/bootstrap/install.sh" \
  --data-root "$DATA" --systemd-dir "$SYSD" --repo-root "$REPO_ROOT" \
  --skip-prereqs --skip-docker --skip-systemd-reload >/tmp/prov_out.$$ 2>&1
STATUS=$?

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

check "$STATUS" "install.sh exits 0"

PROV="$DATA/.provenance"
[ -f "$PROV" ] && r=0 || r=1
check "$r" ".provenance file exists at $DATA/.provenance"

if [ -f "$PROV" ]; then
  perm=$(stat -c %a "$PROV")
  [ "$perm" = "600" ] && r=0 || r=1
  check "$r" ".provenance has safe permissions (600, got $perm)"

  grep -q "^hermes_pin_commit=$PIN_COMMIT\$" "$PROV" && r=0 || r=1
  check "$r" ".provenance records the correct pinned Hermes commit ($PIN_COMMIT)"

  grep -qE '^ssot_repo_commit=[0-9a-f]{7,40}$|^ssot_repo_commit=unknown$' "$PROV" && r=0 || r=1
  check "$r" ".provenance records a repo commit (or 'unknown' if git is unavailable)"

  grep -q "^bootstrap_script=$REPO_ROOT/bootstrap/install.sh\$" "$PROV" && r=0 || r=1
  check "$r" ".provenance records the exact bootstrap script path used"

  grep -qE 'BOT_TOKEN|OAUTH|API_KEY|SECRET' "$PROV" && r=1 || r=0
  check "$r" ".provenance contains no credential-shaped field names"
fi

UNIT="$SYSD/hermes.service"
grep -q 'Installed by bootstrap/install.sh from systemd/hermes.service' "$UNIT" && r=0 || r=1
check "$r" "installed hermes.service carries a provenance header"

grep -q "repo commit" "$UNIT" && r=0 || r=1
check "$r" "installed hermes.service provenance header names a repo commit"

grep -q '@@' "$UNIT" && r=1 || r=0
check "$r" "installed hermes.service has no unsubstituted @@placeholder@@ markers"

[ -e "$SYSD/hermes-gateway.service" ] && r=1 || r=0
check "$r" "no hermes-gateway.service is installed (exactly one systemd unit)"

if [ "$FAIL" -ne 0 ]; then
  cat /tmp/prov_out.$$ >&2
  rm -f /tmp/prov_out.$$
  echo "RESULT: FAIL"
  exit 1
fi
rm -f /tmp/prov_out.$$
echo "RESULT: PASS"
