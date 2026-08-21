#!/usr/bin/env bash
# ============================================================================
# Shared helpers for bootstrap/connect.sh (hermes-connect) and
# bootstrap/doctor.sh (hermes-doctor). Sourced, never executed directly.
#
# No credential value is ever printed, echoed, or logged by anything in this
# file — see SECURITY.md §2. Every external-tool invocation goes through
# run_in_container() so tests can redirect it at fake binaries instead of
# skipping/mocking the calling logic itself.
# ============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "connect-common.sh is a library — source it from connect.sh or doctor.sh, do not run it directly" >&2
  exit 2
fi

REPO_ROOT="${HERMES_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DATA_ROOT="${HERMES_DATA_ROOT:-/opt/hermes-data}"
COMPOSE_FILE="${HERMES_COMPOSE_FILE:-$REPO_ROOT/docker/docker-compose.yml}"

# ----------------------------------------------------------------------------
# run_in_container: how a command that only exists inside the Hermes Agent
# image (hermes, claude, gh — see docker/Dockerfile) gets invoked from the
# host. Default is an ephemeral `docker compose run` against the same
# image/volumes/env as the real service — it does not require the persistent
# service to already be running, and never touches its supervision state
# (systemd/hermes.service is never enabled/started by this repository except
# where the operator explicitly does so — see bootstrap/install.sh).
#
# HERMES_EXEC lets tests (and advanced operators) redirect every such call
# elsewhere — e.g. HERMES_EXEC="" plus fake hermes/claude/gh binaries earlier
# on PATH — so the calling logic in connect.sh/doctor.sh runs for real
# against those fakes rather than being skipped.
# ----------------------------------------------------------------------------
if [ -n "${HERMES_EXEC+set}" ]; then
  # shellcheck disable=SC2206
  HERMES_EXEC_ARR=(${HERMES_EXEC})
else
  HERMES_EXEC_ARR=(docker compose -f "$COMPOSE_FILE" run --rm --no-deps hermes)
fi

run_in_container() {
  "${HERMES_EXEC_ARR[@]}" "$@"
}

# ----------------------------------------------------------------------------
# Discord snowflake ID validation (15-20 decimal digits covers the platform's
# ID range over its lifetime; rejects obviously non-numeric input).
# ----------------------------------------------------------------------------
is_snowflake() {
  [[ "$1" =~ ^[0-9]{15,20}$ ]]
}

# Comma-separated list of snowflakes: 0 (valid) iff non-empty and every
# entry validates; never partially accepts a malformed list.
validate_snowflake_list() {
  local list="$1" id ids=()
  [ -n "$list" ] || return 1
  IFS=',' read -r -a ids <<< "$list"
  [ "${#ids[@]}" -gt 0 ] || return 1
  for id in "${ids[@]}"; do
    id="$(printf '%s' "$id" | tr -d '[:space:]')"
    is_snowflake "$id" || return 1
  done
  return 0
}

# ----------------------------------------------------------------------------
# Atomic, restrictively-permissioned file write. Never leaves a partially
# written file visible at $dest — write to a sibling temp file, chmod, then
# rename (rename is atomic on the same filesystem).
# ----------------------------------------------------------------------------
atomic_write() {
  local dest="$1" content="$2" mode="${3:-0600}" tmp
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp "${dest}.tmp.XXXXXX")"
  printf '%s' "$content" > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$dest"
}

# Set (or replace) KEY=VALUE in a .env-style file atomically, preserving
# every other existing line. Never prints the value to stdout/stderr/logs.
env_file_set() {
  local file="$1" key="$2" value="$3" tmp existing=""
  [ -f "$file" ] && existing="$(cat "$file")"
  tmp="$(printf '%s\n' "$existing" | grep -vE "^${key}=" || true)"
  tmp="$(printf '%s\n%s=%s' "$tmp" "$key" "$value" | sed '/^$/d')"
  atomic_write "$file" "$tmp"$'\n' 0600
}

env_file_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  grep -E "^${key}=" "$file" 2>/dev/null | tail -n1 | cut -d= -f2-
}

# ----------------------------------------------------------------------------
# Discord bot self-identity check (GET /users/@me). The token is passed to
# curl only via a 0600 --config file's `header` directive, never as an argv
# token and never written to any log — see SECURITY.md §2 and
# MILESTONE2_DIRECTIVE.md §3.
# ----------------------------------------------------------------------------
DISCORD_API_BASE="${HERMES_DISCORD_API_BASE:-https://discord.com/api/v10}"

discord_validate_token() {
  local token="$1" tmp cfg body http_code rc
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  cfg="$tmp/curl.cfg"
  body="$tmp/body"
  {
    printf 'header = "Authorization: Bot %s"\n' "$token"
    printf 'silent\n'
    printf 'show-error\n'
    printf 'url = "%s/users/@me"\n' "$DISCORD_API_BASE"
  } > "$cfg"
  chmod 600 "$cfg"
  http_code="$("${CURL_BIN:-curl}" -sS -o "$body" -w '%{http_code}' -K "$cfg" 2>"$tmp/err" || true)"
  rc=1
  [ "$http_code" = "200" ] && rc=0
  echo "$http_code"
  return $rc
}

# ----------------------------------------------------------------------------
# Output helpers. Total/index formatting matches the UX in
# MILESTONE2_DIRECTIVE.md / BUILD_DIRECTIVE.md §6.
# ----------------------------------------------------------------------------
status_line() {
  printf '[%s/%s] %-14s %s\n' "$1" "$2" "$3" "$4"
}

log()  { printf '[%s] %s\n' "${HERMES_TOOL_NAME:-hermes}" "$1"; }
warn() { printf '[%s] WARN: %s\n' "${HERMES_TOOL_NAME:-hermes}" "$1" >&2; }
err()  { printf '[%s] ERROR: %s\n' "${HERMES_TOOL_NAME:-hermes}" "$1" >&2; }

# ----------------------------------------------------------------------------
# Credential-bearing paths, per SECURITY.md §3. Single source of truth so
# hermes-doctor's image-readiness check and hermes-connect's "already
# configured" detection never drift apart.
# ----------------------------------------------------------------------------
credential_paths() {
  cat <<EOF
$DATA_ROOT/.env
$DATA_ROOT/auth.json
$DATA_ROOT/auth/claude
$DATA_ROOT/auth/github
EOF
}

path_populated() {
  local p="$1"
  if [ -f "$p" ]; then
    [ -s "$p" ]
  elif [ -d "$p" ]; then
    [ -n "$(find "$p" -mindepth 1 -print -quit 2>/dev/null)" ]
  else
    return 1
  fi
}
