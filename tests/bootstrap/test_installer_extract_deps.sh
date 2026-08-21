#!/usr/bin/env bash
# Defect repair (Fresh EC2 validation attempt 2, 2026-08-21): a real
# `docker compose build --no-cache` got past the retry-hardened installer
# download (see test_installer_retry.sh), then failed exit 127 immediately
# after "Downloading node-v26.7.0-linux-x64.tar.xz" / "Extracting to
# ~/.hermes/node/..." — the pinned Hermes Agent installer shells out to
# `tar` (it calls `tar xf`/`tar xzf` on the archives it downloads), but the
# Dockerfile's pre-installer prerequisite package stage installed
# xz-utils without tar. xz-utils alone provides `xz`/`unxz`, not `tar`
# itself. The fix adds the `tar` package to that same apt-get install line.
# This test proves both `tar` and `xz-utils` are present in that exact
# pre-installer prerequisite stage, and that the existing pin/checksum/
# retry invariants covered by test_dockerfile_pins.sh and
# test_installer_retry.sh are untouched. Pure static text checks — never
# invokes `docker build`, `apt-get`, or `tar`.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCKERFILE="$REPO_ROOT/docker/Dockerfile"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

[ -f "$DOCKERFILE" ] && r=0 || r=1
check "$r" "docker/Dockerfile exists"
[ -f "$DOCKERFILE" ] || { echo "RESULT: FAIL"; exit 1; }

# The prerequisite apt-get install line that must run BEFORE the pinned
# installer is downloaded/executed (identified the same way
# test_dockerfile_pins.sh/test_installer_retry.sh identify the installer
# curl/exec lines: by searching for the known, stable install invocation).
# The package names themselves are on the following continuation line, so
# both lines are inspected together.
PREREQ_LINE_NO=$(grep -nE 'apt-get install .*--no-install-recommends' "$DOCKERFILE" | head -n1 | cut -d: -f1)
[ -n "$PREREQ_LINE_NO" ] && r=0 || r=1
check "$r" "pre-installer prerequisite apt-get install line found"

if [ -n "$PREREQ_LINE_NO" ]; then
  PREREQ_BLOCK="$(sed -n "${PREREQ_LINE_NO},$((PREREQ_LINE_NO + 1))p" "$DOCKERFILE")"

  echo "$PREREQ_BLOCK" | grep -qE '(^|[[:space:]])tar([[:space:]]|\\|$)' && r=0 || r=1
  check "$r" "prerequisite package list includes tar (installer extracts downloaded archives with it)"

  echo "$PREREQ_BLOCK" | grep -qE '(^|[[:space:]])xz-utils([[:space:]]|\\|$)' && r=0 || r=1
  check "$r" "prerequisite package list includes xz-utils (still present, not removed by this fix)"
fi

exec_line_no=$(grep -nE '^\s*bash /tmp/hermes-install\.sh' "$DOCKERFILE" | head -n1 | cut -d: -f1)
[ -n "$exec_line_no" ] && r=0 || r=1
check "$r" "pinned installer execute line found"

if [ -n "$PREREQ_LINE_NO" ] && [ -n "$exec_line_no" ]; then
  [ "$PREREQ_LINE_NO" -lt "$exec_line_no" ] && r=0 || r=1
  check "$r" "prerequisite package stage (line $PREREQ_LINE_NO) runs before the pinned installer executes (line $exec_line_no)"
fi

# This fix must be scoped to the prerequisite package list only — the
# retry-hardened installer curl invocation (test_installer_retry.sh) must
# still carry its bounded retry/backoff flags, untouched by this change.
INSTALL_CURL_LINE="$(grep -E '^\s*curl .*-o /tmp/hermes-install\.sh' "$DOCKERFILE" | head -n1)"
[ -n "$INSTALL_CURL_LINE" ] && r=0 || r=1
check "$r" "installer curl line still present"
if [ -n "$INSTALL_CURL_LINE" ]; then
  echo "$INSTALL_CURL_LINE" | grep -qE -- '--retry[[:space:]]+[0-9]+' && r=0 || r=1
  check "$r" "installer curl line retry policy from the prior repair is unaffected by this fix"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
