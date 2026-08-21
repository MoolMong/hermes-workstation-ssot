#!/usr/bin/env bash
# Defect repair (post Fresh-EC2-validation, 2026-08-21): the pinned Hermes
# Agent installer download in docker/Dockerfile failed a real
# `docker compose build --no-cache` twice with HTTP 429 from
# raw.githubusercontent.com (see
# evidence/milestone-2-fresh-ec2/TEST_EVIDENCE.md). The fix adds bounded
# curl --retry/--retry-max-time/--retry-connrefused backoff to that single
# curl invocation only. This test proves the retry options are present,
# bounded (not zero, not unbounded), and that they do not disturb the
# existing download -> checksum-verify -> execute ordering or the pinned
# URL/--commit invariants already covered by test_dockerfile_pins.sh. Pure
# static text/ordering checks — never invokes `docker build` or `curl`.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCKERFILE="$REPO_ROOT/docker/Dockerfile"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

[ -f "$DOCKERFILE" ] && r=0 || r=1
check "$r" "docker/Dockerfile exists"
[ -f "$DOCKERFILE" ] || { echo "RESULT: FAIL"; exit 1; }

# The installer curl line (identified the same way test_dockerfile_pins.sh
# identifies it: the line downloading to /tmp/hermes-install.sh).
INSTALL_CURL_LINE="$(grep -E '^\s*curl .*-o /tmp/hermes-install\.sh' "$DOCKERFILE" | head -n1)"

[ -n "$INSTALL_CURL_LINE" ] && r=0 || r=1
check "$r" "installer curl line found"

if [ -n "$INSTALL_CURL_LINE" ]; then
  echo "$INSTALL_CURL_LINE" | grep -qE -- '--retry[[:space:]]+[0-9]+' && r=0 || r=1
  check "$r" "installer curl line sets --retry <n>"

  retry_n="$(echo "$INSTALL_CURL_LINE" | grep -oE -- '--retry[[:space:]]+[0-9]+' | awk '{print $2}')"
  if [ -n "${retry_n:-}" ]; then
    [ "$retry_n" -ge 1 ] 2>/dev/null && r=0 || r=1
    check "$r" "--retry is nonzero (retries are actually enabled, got $retry_n)"
    [ "$retry_n" -le 10 ] 2>/dev/null && r=0 || r=1
    check "$r" "--retry is bounded, not an unreasonably large/looping count (got $retry_n, expect <= 10)"
  fi

  echo "$INSTALL_CURL_LINE" | grep -qE -- '--retry-max-time[[:space:]]+[0-9]+' && r=0 || r=1
  check "$r" "installer curl line sets --retry-max-time <n> (bounded total retry budget)"

  max_time="$(echo "$INSTALL_CURL_LINE" | grep -oE -- '--retry-max-time[[:space:]]+[0-9]+' | awk '{print $2}')"
  if [ -n "${max_time:-}" ]; then
    [ "$max_time" -ge 1 ] 2>/dev/null && r=0 || r=1
    check "$r" "--retry-max-time is nonzero (got $max_time)"
    [ "$max_time" -le 300 ] 2>/dev/null && r=0 || r=1
    check "$r" "--retry-max-time is bounded to a sane ceiling, not effectively unbounded (got $max_time, expect <= 300)"
  fi

  echo "$INSTALL_CURL_LINE" | grep -qE -- '--retry-connrefused' && r=0 || r=1
  check "$r" "installer curl line sets --retry-connrefused (transient connection-refused network errors are retried too, not only HTTP error codes)"

  # No fixed --retry-delay: curl's own exponential backoff (starting at 1s,
  # doubling per attempt) is what makes the retries "backoff", not a busy
  # fixed-interval retry loop.
  echo "$INSTALL_CURL_LINE" | grep -qE -- '--retry-delay' && r=1 || r=0
  check "$r" "no fixed --retry-delay override (keeps curl's default exponential backoff between attempts)"

  # The pin-derived URL and -f/-s/-S/-L behavior must be untouched by this
  # fix — no weakening of fail-on-error or the pinned, commit-scoped URL.
  echo "$INSTALL_CURL_LINE" | grep -qE -- '-fsSL' && r=0 || r=1
  check "$r" "-fsSL (fail-closed on HTTP error, silent, show-error, follow-redirect) is preserved"

  echo "$INSTALL_CURL_LINE" | grep -qF '"$HERMES_INSTALLER_URL"' && r=0 || r=1
  check "$r" "still downloads from \$HERMES_INSTALLER_URL (the pinned, commit-scoped raw.githubusercontent.com URL) — not weakened to a floating URL"
fi

# Ordering must remain: download (curl) -> checksum verify (sha256sum -c)
# -> execute (bash /tmp/hermes-install.sh). The retry flags must not have
# been added to, or reordered around, the checksum-verify or execute step.
curl_line_no=$(grep -nE '^\s*curl .*-o /tmp/hermes-install\.sh' "$DOCKERFILE" | head -n1 | cut -d: -f1)
verify_line_no=$(grep -nE 'sha256sum -c' "$DOCKERFILE" | head -n1 | cut -d: -f1)
exec_line_no=$(grep -nE '^\s*bash /tmp/hermes-install\.sh' "$DOCKERFILE" | head -n1 | cut -d: -f1)

[ -n "$curl_line_no" ] && [ -n "$verify_line_no" ] && [ -n "$exec_line_no" ] && r=0 || r=1
check "$r" "download, checksum-verify, and execute lines are all still present"

if [ -n "$curl_line_no" ] && [ -n "$verify_line_no" ] && [ -n "$exec_line_no" ]; then
  [ "$curl_line_no" -lt "$verify_line_no" ] && [ "$verify_line_no" -lt "$exec_line_no" ] && r=0 || r=1
  check "$r" "checksum ordering unchanged: download ($curl_line_no) < verify ($verify_line_no) < execute ($exec_line_no)"
fi

# The retry fix must be scoped to the pinned installer download only — the
# GitHub CLI keyring curl (a separate, unrelated download) must not have
# been silently changed by this narrowly-scoped fix.
GH_CURL_LINE="$(grep -E 'curl .*githubcli-archive-keyring\.gpg' "$DOCKERFILE" | head -n1)"
[ -n "$GH_CURL_LINE" ] && r=0 || r=1
check "$r" "unrelated GitHub CLI keyring curl line still present (not touched by this fix)"
if [ -n "$GH_CURL_LINE" ]; then
  echo "$GH_CURL_LINE" | grep -qE -- '--retry' && r=1 || r=0
  check "$r" "GitHub CLI keyring curl line was left unmodified (fix scope stayed on the pinned installer download only)"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
