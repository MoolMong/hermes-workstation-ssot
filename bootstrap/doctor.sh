#!/usr/bin/env bash
# ============================================================================
# hermes-doctor — Hermes Workstation SSOT read-only diagnostics (Milestone 2)
# ============================================================================
# Read-only by default and always: this script never writes, creates,
# deletes, starts, stops, enables, or mutates anything. It only inspects
# host/Docker/systemd state and runs non-mutating status/read commands
# (hermes auth status, claude --version, gh auth status, gh api user, a GET
# to Discord's API). There is no --fix flag in this implementation — a
# byte-for-byte read-only tool never needs one negotiated away later
# (BUILD_DIRECTIVE.md §6, MILESTONE2_DIRECTIVE.md §7).
#
# Output distinguishes PASS / FAIL / NOT_CONFIGURED / NOT_RUNNING / BLOCKED /
# WARNING per check, then an actionable Issue/Suggested-action block for
# every non-PASS result.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bootstrap/connect-common.sh
source "$SCRIPT_DIR/connect-common.sh"
HERMES_TOOL_NAME="hermes-doctor"

SYSTEMD_DIR="${HERMES_SYSTEMD_DIR:-/etc/systemd/system}"
CURL_BIN="${HERMES_CURL_BIN:-curl}"

usage() {
  cat <<'EOF'
Usage: hermes-doctor [--help]

Read-only diagnostics for the Hermes Workstation. Never mutates
configuration. Checks Docker, the Hermes service/gateway, each connection
integration (Discord/OpenAI/Claude Code/GitHub), required directories and
permissions, the systemd unit, disk space, the installed SSOT version, and
whether this instance is safe to turn into a shareable image.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
elif [ $# -gt 0 ]; then
  err "unknown argument: $1"
  usage >&2
  exit 2
fi

ISSUES=()          # "Label|Suggested action" for the closing report
FAIL_COUNT=0

report() {
  local label="$1" status="$2" detail="${3:-}"
  printf '%-16s %-14s %s\n' "$label" "$status" "$detail"
  case "$status" in
    FAIL|BLOCKED) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac
}

issue() {
  ISSUES+=("$1|$2")
}

echo "Hermes Workstation Doctor"
echo

# ----------------------------------------------------------------------------
# Required OS commands
# ----------------------------------------------------------------------------
missing_cmds=()
for c in docker git curl; do
  command -v "$c" >/dev/null 2>&1 || missing_cmds+=("$c")
done
if [ "${#missing_cmds[@]}" -eq 0 ]; then
  report "OS commands" PASS "docker, git, curl present"
else
  report "OS commands" FAIL "missing: ${missing_cmds[*]}"
  issue "OS commands" "Install missing command(s): ${missing_cmds[*]} (see bootstrap/install.sh prerequisites stage)"
fi

# ----------------------------------------------------------------------------
# Docker + Compose
# ----------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  report "Docker" FAIL "docker not installed"
  issue "Docker" "Run: bash bootstrap/install.sh"
elif docker info >/dev/null 2>&1; then
  report "Docker" PASS "daemon reachable"
else
  report "Docker" BLOCKED "docker installed but daemon not reachable (permissions? not running?)"
  issue "Docker" "Ensure the Docker daemon is running and this user can reach it (e.g. docker group membership)"
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  report "Compose" PASS "docker compose available"
else
  report "Compose" FAIL "docker compose not available"
  issue "Compose" "Run: bash bootstrap/install.sh"
fi

# ----------------------------------------------------------------------------
# Hermes service definition + container/gateway runtime state
# ----------------------------------------------------------------------------
if [ -f "$COMPOSE_FILE" ] && command -v docker >/dev/null 2>&1 && \
    docker compose -f "$COMPOSE_FILE" config >/dev/null 2>&1; then
  report "Hermes service" PASS "docker-compose.yml present and valid"
else
  report "Hermes service" FAIL "docker-compose.yml missing or invalid: $COMPOSE_FILE"
  issue "Hermes service" "Check docker/docker-compose.yml exists and is well-formed"
fi

GATEWAY_RUNNING=false
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  state="$(docker compose -f "$COMPOSE_FILE" ps --status running --format '{{.Name}}' hermes 2>/dev/null || true)"
  if [ -n "$state" ]; then
    GATEWAY_RUNNING=true
    report "Hermes container" PASS "running"
  else
    report "Hermes container" NOT_RUNNING "not started (systemd never auto-starts it — see systemd/hermes.service)"
  fi
else
  report "Hermes container" BLOCKED "cannot query — Docker daemon not reachable"
fi

if $GATEWAY_RUNNING; then
  if run_in_container hermes gateway status >/dev/null 2>&1; then
    report "Gateway" PASS "hermes gateway status OK"
  else
    report "Gateway" FAIL "hermes gateway status reported a problem"
    issue "Gateway" "Inspect logs: docker compose -f docker/docker-compose.yml logs hermes"
  fi
else
  report "Gateway" NOT_RUNNING "Hermes container is not running"
fi

# ----------------------------------------------------------------------------
# Discord
# ----------------------------------------------------------------------------
discord_token="$(env_file_get "$DATA_ROOT/.env" DISCORD_BOT_TOKEN 2>/dev/null || true)"
if [ -z "$discord_token" ]; then
  report "Discord" NOT_CONFIGURED "no DISCORD_BOT_TOKEN in $DATA_ROOT/.env"
  issue "Discord" "Run: hermes-connect --discord"
else
  http_code="$(discord_validate_token "$discord_token" 2>/dev/null || true)"
  if [ "$http_code" = "200" ]; then
    report "Discord" PASS "token validates against /users/@me"
  else
    report "Discord" FAIL "token did not validate (HTTP $http_code)"
    issue "Discord" "Run: hermes-connect --discord --reconnect"
  fi
fi

# ----------------------------------------------------------------------------
# OpenAI / Codex
# ----------------------------------------------------------------------------
if run_in_container hermes auth status openai-codex >/dev/null 2>&1; then
  report "OpenAI" PASS "hermes auth status openai-codex OK"
else
  report "OpenAI" NOT_CONFIGURED "hermes auth status openai-codex failed"
  issue "OpenAI" "Run: hermes-connect --openai"
fi

# ----------------------------------------------------------------------------
# Claude Code
# ----------------------------------------------------------------------------
if ! run_in_container claude --version >/dev/null 2>&1; then
  report "Claude Code" BLOCKED "claude CLI not available in the Hermes Agent image"
  issue "Claude Code" "Rebuild the image (docker/Dockerfile pins @anthropic-ai/claude-code)"
elif ! run_in_container claude auth status >/dev/null 2>&1; then
  report "Claude Code" NOT_CONFIGURED "claude auth status failed"
  issue "Claude Code" "Run: hermes-connect --claude"
else
  report "Claude Code" PASS "CLI available and claude auth status OK"
fi

# ----------------------------------------------------------------------------
# GitHub
# ----------------------------------------------------------------------------
if run_in_container gh auth status --hostname github.com >/dev/null 2>&1; then
  report "GitHub" PASS "gh auth status OK"
else
  report "GitHub" NOT_CONFIGURED "gh auth status failed"
  issue "GitHub" "Run: hermes-connect --github"
fi

# ----------------------------------------------------------------------------
# Required persistent directories + permissions
# ----------------------------------------------------------------------------
dirs_ok=true
for d in auth config workspaces tasks logs backup; do
  p="$DATA_ROOT/$d"
  if [ ! -d "$p" ]; then
    dirs_ok=false
    report "Directory: $d" FAIL "missing: $p"
    issue "Directory: $d" "Run: bash bootstrap/install.sh"
    continue
  fi
  perm="$(stat -c %a "$p" 2>/dev/null || echo '?')"
  if [ "$perm" != "700" ]; then
    dirs_ok=false
    report "Directory: $d" WARNING "expected 0700, got $perm: $p"
    issue "Directory: $d" "chmod 0700 $p"
  fi
done
$dirs_ok && report "Directories/permissions" PASS "all data-root subdirectories present at 0700"

for f in "$DATA_ROOT/.env" "$DATA_ROOT/config.yaml" "$DATA_ROOT/auth.json"; do
  [ -e "$f" ] || continue
  perm="$(stat -c %a "$f" 2>/dev/null || echo '?')"
  if [ "$perm" != "600" ]; then
    report "Permissions: $(basename "$f")" WARNING "expected 0600, got $perm: $f"
    issue "Permissions: $(basename "$f")" "chmod 0600 $f"
  fi
done

# ----------------------------------------------------------------------------
# systemd unit validity/status
# ----------------------------------------------------------------------------
UNIT_PATH="$SYSTEMD_DIR/hermes.service"
if [ ! -f "$UNIT_PATH" ]; then
  report "systemd unit" NOT_CONFIGURED "not installed: $UNIT_PATH"
  issue "systemd unit" "Run: bash bootstrap/install.sh"
else
  if command -v systemd-analyze >/dev/null 2>&1; then
    if systemd-analyze verify "$UNIT_PATH" >/dev/null 2>&1; then
      report "systemd unit" PASS "installed and valid: $UNIT_PATH"
    else
      report "systemd unit" FAIL "installed but failed validation: $UNIT_PATH"
      issue "systemd unit" "Inspect: systemd-analyze verify $UNIT_PATH"
    fi
  else
    report "systemd unit" PASS "installed (systemd-analyze unavailable to verify): $UNIT_PATH"
  fi
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active hermes.service >/dev/null 2>&1; then
    report "systemd service" PASS "active"
  else
    report "systemd service" NOT_RUNNING "not started (never auto-enabled/started by this repository)"
  fi
fi

# ----------------------------------------------------------------------------
# Disk space
# ----------------------------------------------------------------------------
if [ -d "$DATA_ROOT" ]; then
  avail_pct="$(df -P "$DATA_ROOT" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print 100-$5}')"
  if [ -n "$avail_pct" ]; then
    if [ "$avail_pct" -lt 10 ]; then
      report "Disk" FAIL "only ${avail_pct}% free on $DATA_ROOT's filesystem"
      issue "Disk" "Free up space on the filesystem backing $DATA_ROOT"
    elif [ "$avail_pct" -lt 20 ]; then
      report "Disk" WARNING "${avail_pct}% free on $DATA_ROOT's filesystem"
    else
      report "Disk" PASS "${avail_pct}% free on $DATA_ROOT's filesystem"
    fi
  else
    report "Disk" WARNING "could not determine free space for $DATA_ROOT"
  fi
else
  report "Disk" NOT_CONFIGURED "$DATA_ROOT does not exist yet"
fi

# ----------------------------------------------------------------------------
# Installed SSOT version / commit
# ----------------------------------------------------------------------------
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  commit="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  dirty=""
  git -C "$REPO_ROOT" diff --quiet 2>/dev/null || dirty=" (working tree dirty)"
  report "SSOT version" PASS "commit $commit$dirty"
else
  report "SSOT version" WARNING "not a git checkout — cannot determine commit"
fi

# ----------------------------------------------------------------------------
# Image readiness — refuses to declare the instance image-safe if any known
# credential/session path (SECURITY.md §3) is populated. Read-only: this
# only reports, it never deletes anything.
# ----------------------------------------------------------------------------
populated=()
while IFS= read -r p; do
  [ -n "$p" ] || continue
  path_populated "$p" && populated+=("$p")
done < <(credential_paths)

if [ "${#populated[@]}" -eq 0 ]; then
  report "Image readiness" PASS "no known credential/session path is populated"
else
  report "Image readiness" FAIL "credential/session state present: ${populated[*]}"
  issue "Image readiness" "This instance is NOT safe to convert into a shareable image/AMI while these paths are populated: ${populated[*]}"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
if [ "${#ISSUES[@]}" -gt 0 ]; then
  for entry in "${ISSUES[@]}"; do
    label="${entry%%|*}"
    action="${entry#*|}"
    echo
    echo "Issue:"
    echo "$label"
    echo
    echo "Suggested action:"
    echo "$action"
  done
fi

exit "$([ "$FAIL_COUNT" -eq 0 ] && echo 0 || echo 1)"
