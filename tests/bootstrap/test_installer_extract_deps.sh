#!/usr/bin/env bash
# Defect repair (Fresh EC2 validation attempts 2-3, 2026-08-21): the
# retry-hardened installer download succeeded, then the pinned installer
# reached Node.js archive extraction and exited 127. Attempt 2 established
# that the minimal Ubuntu image needed tar alongside xz-utils. Attempt 3
# reproduced the remaining failure directly: the extracted Node.js binary
# exited 127 because libatomic.so.1 was absent (`libatomic.so.1 => not
# found`). The required Ubuntu package is libatomic1.
#
# This test proves tar, xz-utils, and libatomic1 are present in the exact
# pre-installer prerequisite stage, and that the existing pin/checksum/
# retry invariants covered by test_dockerfile_pins.sh and
# test_installer_retry.sh remain untouched. Pure static text checks — never
# invokes docker build or apt-get.
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

  echo "$PREREQ_BLOCK" | grep -qE '(^|[[:space:]])libatomic1([[:space:]]|\\|$)' && r=0 || r=1
  check "$r" "prerequisite package list includes libatomic1 (provides libatomic.so.1 required by pinned Node.js)"
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
