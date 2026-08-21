#!/usr/bin/env bash
# Milestone 1: exactly one Compose service/container, running the Hermes
# gateway process, supervised by systemd rather than Docker's own restart
# policy (BUILD_DIRECTIVE.md §1, §10 — no second orchestrator runtime; and
# ARCHITECTURE.md §6/§9 — exactly one container). Pure static/text checks
# on docker/docker-compose.yml — never invokes the docker binary or a
# daemon, so this is safe to run without Docker runtime access.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE="$REPO_ROOT/docker/docker-compose.yml"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

[ -f "$COMPOSE" ] && r=0 || r=1
check "$r" "docker/docker-compose.yml exists"

if [ -f "$COMPOSE" ]; then
  # Top-level service keys are declared with 2-space indent immediately
  # under the "services:" block (see the file's own formatting).
  service_count=$(awk '
    /^services:/ {in_services=1; next}
    in_services && /^[^[:space:]]/ {in_services=0}
    in_services && /^  [A-Za-z0-9_-]+:/ {print}
  ' "$COMPOSE" | wc -l)
  [ "$service_count" -eq 1 ] && r=0 || r=1
  check "$r" "exactly one service declared under services: (found $service_count)"

  grep -qE '^\s*container_name:\s*hermes\s*$' "$COMPOSE" && r=0 || r=1
  check "$r" "container_name is exactly 'hermes'"

  # Milestone 2 fix: `hermes gateway` alone only prints subcommand help; the
  # gateway must be started with its `run` subcommand
  # (hermes_cli/subcommands/gateway.py) — regression test for that fix.
  grep -qE '^\s*command:\s*\["hermes",\s*"gateway",\s*"run"\]\s*$' "$COMPOSE" && r=0 || r=1
  check "$r" "command runs exactly [\"hermes\", \"gateway\", \"run\"] (not bare \"gateway\", which only prints help)"

  grep -qE '^\s*restart:\s*"no"\s*$' "$COMPOSE" && r=0 || r=1
  check "$r" 'restart is "no" (Docker does not supervise; systemd does, avoiding two overlapping restart policies for one failure)'

  # No second service and no second container_name anywhere in the file.
  container_name_count=$(grep -cE '^\s*container_name:' "$COMPOSE")
  [ "$container_name_count" -eq 1 ] && r=0 || r=1
  check "$r" "exactly one container_name declaration in the file (found $container_name_count)"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
