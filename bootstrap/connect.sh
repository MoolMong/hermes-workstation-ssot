#!/usr/bin/env bash
# ============================================================================
# hermes-connect — Hermes Workstation SSOT connection UX (Milestone 2)
# ============================================================================
# Interactively connects THIS host to the operator's own Discord, OpenAI/
# Codex, Claude Code, and GitHub accounts. Detects already-healthy
# integrations and skips them unless --reconnect is given; guides the user
# only through missing/failed integrations; validates every integration
# immediately after configuration; never echoes or logs a secret value.
#
# Grounded against the real upstream Hermes Agent CLI (pinned by
# bootstrap/hermes-commit.pin, see docker/Dockerfile) rather than guessed:
#   - `hermes auth add openai-codex --no-browser` / `hermes auth status
#     openai-codex` are real subcommands (hermes_cli/subcommands/auth.py).
#   - The Discord platform plugin reads DISCORD_BOT_TOKEN, DISCORD_ALLOWED_
#     USERS, DISCORD_ALLOWED_ROLES, DISCORD_ALLOWED_CHANNELS, and
#     DISCORD_ALLOW_ALL_USERS from environment (plugins/platforms/discord/
#     plugin.yaml) — hermes itself auto-loads $HERMES_HOME/.env at startup
#     (hermes_cli/env_loader.py), so writing these into $HERMES_HOME/.env is
#     the same file the upstream tool would write via its own wizard.
#   - $HERMES_HOME/{config.yaml,.env,auth.json} are the exact three official
#     persistence files (hermes_cli/config.py, hermes_cli/auth.py), bind-
#     mounted from host `/opt/hermes-data` (HERMES_HOME=/data, see
#     docker/Dockerfile) — this is the "official persistence" referenced by
#     MILESTONE2_DIRECTIVE.md.
#
# This script never handles the Docker/systemd host bootstrap (Milestone 1,
# bootstrap/install.sh) and never implements Runner/Monitor/Verifier
# (Milestone 3+). See MILESTONES.md.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bootstrap/connect-common.sh
source "$SCRIPT_DIR/connect-common.sh"
HERMES_TOOL_NAME="hermes-connect"

RECONNECT=false
TARGETS=()
CURL_BIN="${HERMES_CURL_BIN:-curl}"

usage() {
  cat <<'EOF'
Usage: hermes-connect [--discord] [--openai] [--claude] [--github] [--reconnect] [--help]

Interactively connects this host to your own Discord, OpenAI/Codex, Claude
Code, and GitHub accounts. With no integration flag, runs all four in
order. Already-healthy integrations are detected and skipped unless
--reconnect is given.

Options:
  --discord      Configure/validate only the Discord integration.
  --openai       Configure/validate only the OpenAI/Codex integration.
  --claude       Configure/validate only the Claude Code integration.
  --github       Configure/validate only the GitHub integration.
  --reconnect    Force reconfiguration even if an integration currently
                 validates as healthy.
  -h, --help     Show this help and exit.

Never echoes or logs a secret value. Credentials are written only to the
documented persistent paths — see SECURITY.md §3.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --discord) TARGETS+=(discord); shift ;;
    --openai) TARGETS+=(openai); shift ;;
    --claude) TARGETS+=(claude); shift ;;
    --github) TARGETS+=(github); shift ;;
    --reconnect) RECONNECT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  TARGETS=(discord openai claude github)
fi

declare -A LABEL=([discord]="Discord" [openai]="OpenAI" [claude]="Claude Code" [github]="GitHub")
declare -A INDEX=([discord]=1 [openai]=2 [claude]=3 [github]=4)
declare -A RESULT=()

# ----------------------------------------------------------------------------
# Discord
# ----------------------------------------------------------------------------
discord_configured() {
  local token
  token="$(env_file_get "$DATA_ROOT/.env" DISCORD_BOT_TOKEN 2>/dev/null || true)"
  [ -n "$token" ] || return 1
  local allow_all
  allow_all="$(env_file_get "$DATA_ROOT/.env" DISCORD_ALLOW_ALL_USERS 2>/dev/null || true)"
  [ "$allow_all" = "true" ] && return 1
  local users roles channels
  users="$(env_file_get "$DATA_ROOT/.env" DISCORD_ALLOWED_USERS 2>/dev/null || true)"
  roles="$(env_file_get "$DATA_ROOT/.env" DISCORD_ALLOWED_ROLES 2>/dev/null || true)"
  channels="$(env_file_get "$DATA_ROOT/.env" DISCORD_ALLOWED_CHANNELS 2>/dev/null || true)"
  [ -n "$users$roles$channels" ] || return 1
  return 0
}

discord_validate() {
  local token http_code
  token="$(env_file_get "$DATA_ROOT/.env" DISCORD_BOT_TOKEN 2>/dev/null || true)"
  [ -n "$token" ] || return 1
  http_code="$(discord_validate_token "$token")"
  [ "$http_code" = "200" ]
}

discord_setup() {
  log "Discord setup — https://discord.com/developers/applications"
  log "You will need: a bot token, and at least one of a user ID, role ID,"
  log "or channel ID to allow (never all users — an explicit allow-list is"
  log "required)."

  local token users roles channels
  read -r -s -p "Discord bot token (input hidden): " token; echo
  if [ -z "$token" ]; then
    err "no token entered — aborting Discord setup"
    return 1
  fi

  read -r -p "Allowed user IDs (comma-separated, blank if none): " users
  read -r -p "Allowed role IDs (comma-separated, blank if none): " roles
  read -r -p "Allowed channel IDs (comma-separated, blank if none): " channels

  if [ -z "$users$roles$channels" ]; then
    err "at least one of allowed user/role/channel IDs is required — refusing to allow-all"
    return 1
  fi
  for pair in "users:$users" "roles:$roles" "channels:$channels"; do
    local name="${pair%%:*}" val="${pair#*:}"
    if [ -n "$val" ] && ! validate_snowflake_list "$val"; then
      err "invalid Discord ID list for $name — each ID must be 15-20 digits: $val"
      return 1
    fi
  done

  env_file_set "$DATA_ROOT/.env" DISCORD_BOT_TOKEN "$token"
  [ -n "$users" ] && env_file_set "$DATA_ROOT/.env" DISCORD_ALLOWED_USERS "$users"
  [ -n "$roles" ] && env_file_set "$DATA_ROOT/.env" DISCORD_ALLOWED_ROLES "$roles"
  [ -n "$channels" ] && env_file_set "$DATA_ROOT/.env" DISCORD_ALLOWED_CHANNELS "$channels"
  # Never allow-all, ever — even if a stale value exists from before.
  env_file_set "$DATA_ROOT/.env" DISCORD_ALLOW_ALL_USERS "false"
  chmod 0600 "$DATA_ROOT/.env" 2>/dev/null || true
  return 0
}

discord_recovery() {
  cat <<'EOF'
Issue:
Discord connection unavailable or not yet configured.

Suggested action:
Run: hermes-connect --discord
Prerequisites: a Discord bot application/token
(https://discord.com/developers/applications) and at least one of an
allowed user ID, role ID, or channel ID.
EOF
}

# ----------------------------------------------------------------------------
# OpenAI / Codex — the provider Hermes uses, via the hermes CLI's own
# credential manager (hermes_cli/subcommands/auth.py). Exact commands per
# MILESTONE2_DIRECTIVE.md §4: `hermes auth add openai-codex --no-browser`
# and `hermes auth status openai-codex`.
# ----------------------------------------------------------------------------
openai_configured() {
  run_in_container hermes auth status openai-codex >/dev/null 2>&1
}

openai_validate() {
  run_in_container hermes auth status openai-codex >/dev/null 2>&1 || return 1
  # Validate the provider/model selected by the official `hermes model`
  # flow with the pinned CLI's one-shot interface. Do not hard-code a model:
  # the picker uses the provider's currently offered models.
  local out
  out="$(run_in_container hermes -z "Reply with exactly: OK" 2>/dev/null)" || return 1
  [[ "$out" == *OK* ]]
}

openai_setup() {
  log "OpenAI/Codex setup — hermes auth add openai-codex --no-browser"
  log "Follow the printed authentication instructions (no browser will be"
  log "opened automatically on this host)."
  if ! run_in_container hermes auth add openai-codex --no-browser; then
    err "hermes auth add openai-codex failed — no fake/fallback credential is written"
    return 1
  fi
  log "Select OpenAI Codex and one of the models offered by the official Hermes model picker."
  if ! run_in_container hermes model; then
    err "hermes model provider/model setup failed — no provider or model fallback is selected"
    return 1
  fi
  return 0
}

openai_recovery() {
  cat <<'EOF'
Issue:
OpenAI/Codex authentication is missing or invalid.

Suggested action:
Run: hermes-connect --openai
This runs `hermes auth add openai-codex --no-browser` inside the Hermes
Agent runtime, opens the official `hermes model` provider/model picker, and
then re-checks auth plus a real Hermes one-shot. There is no fake/mock
provider or hard-coded model fallback — a real failure is reported as FAIL.
EOF
}

# ----------------------------------------------------------------------------
# Claude Code — persistent HOME/CLAUDE_CONFIG_DIR under
# /opt/hermes-data/auth/claude (see docker/Dockerfile ENV, docker-
# compose.yml). The pinned Claude Code CLI provides `claude auth status`;
# setup-token and auth login are supported interactive login paths.
# ----------------------------------------------------------------------------
claude_configured() {
  run_in_container claude --version >/dev/null 2>&1 || return 1
  run_in_container claude auth status >/dev/null 2>&1
}

claude_validate() {
  run_in_container claude --version >/dev/null 2>&1 || return 1
  run_in_container claude auth status >/dev/null 2>&1 || return 1
  # Minimal real smoke test: a successful login alone is not sufficient
  # (MILESTONE2_DIRECTIVE.md §5) — confirm a real minimal invocation works.
  local out
  out="$(run_in_container claude -p "Reply with exactly: OK" --max-turns 1 2>/dev/null)" || return 1
  [[ "$out" == *OK* ]]
}

claude_setup() {
  log "Claude Code setup"
  mkdir -p "$DATA_ROOT/auth/claude" 2>/dev/null || true
  chmod 0700 "$DATA_ROOT/auth/claude" 2>/dev/null || true
  log "Attempting: claude setup-token (interactive, generates a long-lived"
  log "token suitable for this headless host)."
  if ! run_in_container claude setup-token; then
    err "claude setup-token failed."
    err "Alternatives: 'claude auth login --claudeai', '--console', or '--sso' inside the container."
    return 1
  fi
  return 0
}

claude_recovery() {
  cat <<'EOF'
Issue:
Claude Code is not authenticated, or a minimal real invocation failed.

Suggested action:
Run: hermes-connect --claude
Or manually: docker compose run --rm -it hermes claude setup-token
Or use the supported login command with the appropriate billing/identity
path: `claude auth login --claudeai`, `--console`, or `--sso`.
EOF
}

# ----------------------------------------------------------------------------
# GitHub — HTTPS + gh CLI credential helper. Persistent GH_CONFIG_DIR /
# GIT_CONFIG_GLOBAL under /opt/hermes-data/auth/github. No SSH key
# management.
# ----------------------------------------------------------------------------
github_configured() {
  run_in_container gh auth status --hostname github.com >/dev/null 2>&1
}

github_validate() {
  run_in_container gh auth status --hostname github.com >/dev/null 2>&1 || return 1
  run_in_container gh api user >/dev/null 2>&1
}

github_setup() {
  log "GitHub setup — gh auth login (HTTPS)"
  mkdir -p "$DATA_ROOT/auth/github" 2>/dev/null || true
  chmod 0700 "$DATA_ROOT/auth/github" 2>/dev/null || true
  if ! run_in_container gh auth login --hostname github.com --git-protocol https --web; then
    err "gh auth login failed"
    return 1
  fi
  if ! run_in_container gh auth setup-git; then
    err "gh auth setup-git failed"
    return 1
  fi
  return 0
}

github_recovery() {
  cat <<'EOF'
Issue:
GitHub CLI is not authenticated.

Suggested action:
Run: hermes-connect --github
Or manually: docker compose run --rm -it hermes gh auth login --hostname github.com --git-protocol https --web
No SSH key management is performed — HTTPS + the gh credential helper only.
EOF
}

# ----------------------------------------------------------------------------
# Optional, best-effort: read the SSOT repository's own configured remote
# (never a hardcoded owner-specific URL, so the repo stays generic/shareable —
# CLAUDE.md "Existing Factory/EC2" / MILESTONE2_DIRECTIVE.md §3).
#
# The remote URL itself is never logged: an HTTPS remote can embed a
# credential (e.g. `https://oauth2:TOKEN@github.com/...`), so only its host
# is shown, never the full URL — see SECURITY.md §2 (never log secret
# values) and MILESTONE2_DIRECTIVE.md ("avoid exposing optional remote
# URLs").
# ----------------------------------------------------------------------------
github_optional_remote_check() {
  local origin host
  origin="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
  [ -n "$origin" ] || { log "no git remote 'origin' configured for this checkout — skipping optional remote-read check"; return 0; }
  host="$(printf '%s' "$origin" | sed -E 's#^[a-zA-Z]+://([^/@]*@)?##; s#[:/].*$##')"
  if run_in_container git ls-remote "$origin" >/dev/null 2>&1; then
    log "optional SSOT remote-read check: PASS (host: $host)"
  else
    warn "optional SSOT remote-read check: could not read remote at host $host (non-fatal)"
  fi
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
echo "Hermes Workstation Connection Setup"
echo

OVERALL=0
for name in "${TARGETS[@]}"; do
  idx="${INDEX[$name]}"
  label="${LABEL[$name]}"
  need_setup=false

  if "${name}_configured" && ! $RECONNECT; then
    if "${name}_validate"; then
      status_line "$idx" 4 "$label" "PASS"
      RESULT[$name]=PASS
      continue
    else
      need_setup=true
    fi
  else
    need_setup=true
  fi

  if $need_setup; then
    "${name}_setup" || true
    if "${name}_validate"; then
      status_line "$idx" 4 "$label" "PASS"
      RESULT[$name]=PASS
    else
      status_line "$idx" 4 "$label" "FAIL"
      RESULT[$name]=FAIL
      OVERALL=1
    fi
  fi
done

if [[ " ${TARGETS[*]} " == *" github "* ]] && [ "${RESULT[github]:-}" = "PASS" ]; then
  github_optional_remote_check
fi

echo
if [ "$OVERALL" -eq 0 ]; then
  echo "All connections are ready."
else
  for name in "${TARGETS[@]}"; do
    if [ "${RESULT[$name]:-}" = "FAIL" ]; then
      echo
      "${name}_recovery"
    fi
  done
fi

exit "$OVERALL"
