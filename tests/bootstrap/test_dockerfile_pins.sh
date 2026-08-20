#!/usr/bin/env bash
# Milestone 1: docker/Dockerfile must build the Hermes Agent image from an
# immutable, commit-scoped installer URL, verify the downloaded installer's
# checksum BEFORE executing it, pass the same pinned commit to --commit
# that was used to build the URL, pin the base image by digest, and parse
# both pins from the COPY'd bootstrap/*.pin* files rather than duplicating
# them as hardcoded ARG defaults. Pure static text/ordering checks — never
# invokes `docker build`.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCKERFILE="$REPO_ROOT/docker/Dockerfile"
COMMIT_PIN="$REPO_ROOT/bootstrap/hermes-commit.pin"
SHA_PIN="$REPO_ROOT/bootstrap/hermes-installer.sha256"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

[ -f "$DOCKERFILE" ] && r=0 || r=1
check "$r" "docker/Dockerfile exists"
[ -f "$DOCKERFILE" ] || { echo "RESULT: FAIL"; exit 1; }

# Base image pinned by digest, not a floating tag alone.
grep -qE '^FROM [a-zA-Z0-9_./:-]+@sha256:[0-9a-f]{64}' "$DOCKERFILE" && r=0 || r=1
check "$r" "FROM line pins the base image by @sha256: digest"

# Pins are COPY'd in and parsed, never duplicated as a hardcoded ARG default.
grep -qE '^COPY[[:space:]]+.*bootstrap/hermes-commit\.pin.*bootstrap/hermes-installer\.sha256' "$DOCKERFILE" && r=0 || r=1
check "$r" "Dockerfile COPYs both bootstrap/hermes-commit.pin and bootstrap/hermes-installer.sha256"

arg_count=$(grep -cE '^ARG[[:space:]]' "$DOCKERFILE")
[ "$arg_count" -eq 0 ] && r=0 || r=1
check "$r" "no ARG instruction in Dockerfile (pins are parsed from the COPY'd files, not duplicated as ARG defaults)"

if [ -f "$COMMIT_PIN" ] && [ -f "$SHA_PIN" ]; then
  PIN_COMMIT="$(grep -vE '^\s*#|^\s*$' "$COMMIT_PIN" | head -n1 | tr -d '[:space:]')"
  PIN_SHA="$(grep -vE '^\s*#|^\s*$' "$SHA_PIN" | head -n1 | awk '{print $1}')"

  # The Dockerfile's own executable RUN lines must not hardcode these
  # values a second time — only reference them via the parsed shell vars.
  # (The pin files' own header comments legitimately mention them.)
  grep -qF "$PIN_COMMIT" "$DOCKERFILE" && r=1 || r=0
  check "$r" "pinned commit is not duplicated verbatim in Dockerfile (parsed at build time instead)"

  grep -qF "$PIN_SHA" "$DOCKERFILE" && r=1 || r=0
  check "$r" "pinned installer SHA-256 is not duplicated verbatim in Dockerfile (parsed at build time instead)"
fi

# Immutable, commit-scoped installer URL — derived from the parsed commit
# variable, not a floating branch/tag.
grep -qE 'https://raw\.githubusercontent\.com/NousResearch/hermes-agent/\$\{?HERMES_COMMIT\}?/scripts/install\.sh' "$DOCKERFILE" && r=0 || r=1
check "$r" "installer URL is the commit-scoped raw.githubusercontent.com URL built from \$HERMES_COMMIT"

# --commit is passed the SAME variable used to build the URL above (single
# source of truth for which commit gets fetched vs. which gets checked out).
grep -qE -- '--commit[[:space:]]+"\$HERMES_COMMIT"' "$DOCKERFILE" && r=0 || r=1
check "$r" "--commit is passed \$HERMES_COMMIT (same variable used in the installer URL)"

# Ordering: download, then verify checksum, then execute. A curl-pipe (no
# intermediate file) or verify-after-exec would defeat the checksum gate.
curl_line=$(grep -nE '^\s*curl .*-o /tmp/hermes-install\.sh' "$DOCKERFILE" | head -n1 | cut -d: -f1)
verify_line=$(grep -nE 'sha256sum -c' "$DOCKERFILE" | head -n1 | cut -d: -f1)
exec_line=$(grep -nE '^\s*bash /tmp/hermes-install\.sh' "$DOCKERFILE" | head -n1 | cut -d: -f1)

[ -n "$curl_line" ] && [ -n "$verify_line" ] && [ -n "$exec_line" ] && r=0 || r=1
check "$r" "download, checksum-verify, and execute lines are all present"

if [ -n "$curl_line" ] && [ -n "$verify_line" ] && [ -n "$exec_line" ]; then
  [ "$curl_line" -lt "$verify_line" ] && [ "$verify_line" -lt "$exec_line" ] && r=0 || r=1
  check "$r" "checksum is verified AFTER download and BEFORE execution (line $curl_line < $verify_line < $exec_line)"
fi

# No curl-pipe-to-shell anywhere (defeats the checksum gate entirely).
grep -qE 'curl[^|]*\|\s*(sh|bash)\b' "$DOCKERFILE" && r=1 || r=0
check "$r" "no curl-pipe-to-shell pattern (installer is downloaded to a file, verified, then executed)"

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
