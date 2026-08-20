#!/usr/bin/env bash
# Milestone 1: install.sh's package stages (prerequisites, Docker) must
# fail closed on an unsupported host or without root, and only ever
# install via the Ubuntu/Debian apt-get path — never silently report
# DONE/ALREADY without actually verifying the resulting state. Exercised
# by hiding apt-get/dpkg/docker from PATH (a stand-in for a non-apt host)
# and, separately, by relying on this test runner's own non-root UID.
# Never invokes real apt-get/dpkg install — only tests the guard clauses.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

# --- fakebin: every real binary except apt-get/dpkg/docker -----------------
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
for dir in /usr/bin /bin; do
  [ -d "$dir" ] || continue
  for b in "$dir"/*; do
    name="$(basename "$b")"
    case "$name" in
      apt-get|dpkg|docker) continue ;;
    esac
    [ -x "$b" ] && [ ! -e "$FAKEBIN/$name" ] && ln -sf "$b" "$FAKEBIN/$name"
  done
done
FAKE_PATH="$FAKEBIN"

run_isolated() {
  # $@ = extra install.sh args
  local data="$TMP/data-$RANDOM" sysd="$TMP/sysd-$RANDOM"
  PATH="$FAKE_PATH" bash "$REPO_ROOT/bootstrap/install.sh" \
    --data-root "$data" --systemd-dir "$sysd" --repo-root "$REPO_ROOT" \
    --skip-systemd-reload "$@" 2>&1
}

# --- Part A: prerequisites stage, apt-get absent from PATH ------------------
OUT_A="$(run_isolated --skip-docker --skip-systemd)"
STATUS_A=$?
[ "$STATUS_A" -ne 0 ] && r=0 || r=1
check "$r" "prereqs stage exits non-zero when apt-get is unavailable (got $STATUS_A)"
echo "$OUT_A" | grep -qi 'apt-get not found' && r=0 || r=1
check "$r" "prereqs stage reports 'apt-get not found' (fail-closed, not a silent skip)"

# --- Part B: Docker stage, apt-get and docker both absent from PATH --------
OUT_B="$(run_isolated --skip-prereqs --skip-systemd)"
STATUS_B=$?
[ "$STATUS_B" -ne 0 ] && r=0 || r=1
check "$r" "Docker stage exits non-zero when apt-get and docker are unavailable (got $STATUS_B)"
echo "$OUT_B" | grep -qi 'apt-get not found' && r=0 || r=1
check "$r" "Docker stage reports 'apt-get not found' (fail-closed, not a silent skip)"

# --- Part C: non-root guard --------------------------------------------------
# This test process itself must be non-root for this assertion to be
# meaningful; skip (not fail) if run as root (e.g. some CI containers).
if [ "$(id -u)" -ne 0 ]; then
  FAKEBIN_APT="$TMP/fakebin-apt"
  mkdir -p "$FAKEBIN_APT"
  for f in "$FAKEBIN"/*; do ln -sf "$f" "$FAKEBIN_APT/$(basename "$f")"; done
  cat > "$FAKEBIN_APT/apt-get" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$FAKEBIN_APT/apt-get"
  cat > "$FAKEBIN_APT/dpkg" <<'EOF'
#!/bin/sh
# Always report "not installed" so check_prereqs treats every package as
# missing and proceeds to the root check.
exit 1
EOF
  chmod +x "$FAKEBIN_APT/dpkg"

  data="$TMP/data-root-guard" sysd="$TMP/sysd-root-guard"
  OUT_C="$(PATH="$FAKEBIN_APT" bash "$REPO_ROOT/bootstrap/install.sh" \
    --data-root "$data" --systemd-dir "$sysd" --repo-root "$REPO_ROOT" \
    --skip-docker --skip-systemd --skip-systemd-reload 2>&1)"
  STATUS_C=$?
  [ "$STATUS_C" -ne 0 ] && r=0 || r=1
  check "$r" "prereqs stage exits non-zero when not running as root (got $STATUS_C)"
  echo "$OUT_C" | grep -qi 'not running as root' && r=0 || r=1
  check "$r" "prereqs stage reports 'not running as root' (fail-closed, not a silent skip)"
else
  echo "SKIP: non-root guard test (this test process is running as root)"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "--- Part A output ---" >&2; echo "$OUT_A" >&2
  echo "--- Part B output ---" >&2; echo "$OUT_B" >&2
  [ -n "${OUT_C:-}" ] && { echo "--- Part C output ---" >&2; echo "$OUT_C" >&2; }
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
