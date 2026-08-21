#!/usr/bin/env bash
# ============================================================================
# Shared fake-binary factory for tests/connection/test_*.sh. Sourced, never
# executed directly. Not itself a test — no RESULT: PASS/FAIL line, and
# tests/connection/run.sh does not run it as a test_*.sh script.
#
# Every fake here logs its own invocation to "$CALL_LOG" (one line, "name
# arg1 arg2 ..."), so a test can assert the exact official command a
# connect.sh/doctor.sh code path ran, and can assert a mutating subcommand
# was NOT called (read-only checks). Behavior/exit codes are controlled by
# env vars so each test can drive PASS/FAIL/missing scenarios without
# touching any real Docker/GitHub/Anthropic/Discord service.
# ============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "lib_fakebin.sh is a helper — source it from a tests/connection/test_*.sh script" >&2
  exit 2
fi

# make_fakebin DIR — populate DIR with fake hermes/claude/gh/docker/
# systemctl/systemd-analyze/git executables. Caller is responsible for
# prepending DIR to PATH and setting CALL_LOG before invoking anything.
make_fakebin() {
  local dir="$1"
  mkdir -p "$dir"

  cat > "$dir/hermes" <<'EOF'
#!/usr/bin/env bash
echo "hermes $*" >> "$CALL_LOG"
case "$1 $2 $3" in
  "auth status openai-codex") exit "${FAKE_HERMES_AUTH_STATUS_EXIT:-0}" ;;
  "auth add openai-codex") exit "${FAKE_HERMES_AUTH_ADD_EXIT:-0}" ;;
esac
case "$1 $2" in
  "gateway status") exit "${FAKE_HERMES_GATEWAY_STATUS_EXIT:-0}" ;;
esac
if [ "$1" = "model" ]; then exit "${FAKE_HERMES_MODEL_EXIT:-0}"; fi
if [ "$1" = "-z" ]; then
  echo "${FAKE_HERMES_SMOKE_OUTPUT:-OK}"
  exit "${FAKE_HERMES_SMOKE_EXIT:-0}"
fi
echo "fake hermes: unhandled invocation: $*" >&2
exit 1
EOF

  cat > "$dir/claude" <<'EOF'
#!/usr/bin/env bash
echo "claude $*" >> "$CALL_LOG"
case "$1" in
  --version)
    echo "${FAKE_CLAUDE_VERSION_OUTPUT:-2.1.237 (Claude Code)}"
    exit "${FAKE_CLAUDE_VERSION_EXIT:-0}" ;;
  setup-token)
    # A real `claude setup-token` persists credential state under
    # CLAUDE_CONFIG_DIR/HOME (here: FAKE_CLAUDE_CREDENTIAL_DIR, simulating
    # the container's bind-mounted /data/auth/claude). Simulate that side
    # effect on success so path_populated() sees the same real-world state
    # a live run would produce.
    if [ "${FAKE_CLAUDE_SETUP_TOKEN_EXIT:-0}" = "0" ] && [ -n "${FAKE_CLAUDE_CREDENTIAL_DIR:-}" ]; then
      mkdir -p "$FAKE_CLAUDE_CREDENTIAL_DIR"
      echo "fake-credential" > "$FAKE_CLAUDE_CREDENTIAL_DIR/.credentials.json"
    fi
    exit "${FAKE_CLAUDE_SETUP_TOKEN_EXIT:-0}" ;;
  auth)
    if [ "${2:-}" = "status" ]; then
      if [ -n "${FAKE_CLAUDE_AUTH_STATUS_EXIT+x}" ]; then
        exit "$FAKE_CLAUDE_AUTH_STATUS_EXIT"
      fi
      if [ -n "${FAKE_CLAUDE_CREDENTIAL_DIR:-}" ]; then
        [ -n "$(find "$FAKE_CLAUDE_CREDENTIAL_DIR" -mindepth 1 -print -quit 2>/dev/null)" ] && exit 0 || exit 1
      fi
      exit 0
    fi
    if [ "${2:-}" = "login" ]; then
      exit "${FAKE_CLAUDE_AUTH_LOGIN_EXIT:-0}"
    fi
    ;;
  -p)
    echo "${FAKE_CLAUDE_SMOKE_OUTPUT:-OK}"
    exit "${FAKE_CLAUDE_SMOKE_EXIT:-0}" ;;
esac
echo "fake claude: unhandled invocation: $*" >&2
exit 1
EOF

  cat > "$dir/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$CALL_LOG"
case "$1 $2" in
  "auth status") exit "${FAKE_GH_AUTH_STATUS_EXIT:-0}" ;;
  "api user") exit "${FAKE_GH_API_USER_EXIT:-0}" ;;
  "auth login") exit "${FAKE_GH_AUTH_LOGIN_EXIT:-0}" ;;
  "auth setup-git") exit "${FAKE_GH_AUTH_SETUP_GIT_EXIT:-0}" ;;
esac
echo "fake gh: unhandled invocation: $*" >&2
exit 1
EOF

  # Fake docker: only used (a) as the default run_in_container transport
  # (`docker compose ... run --rm --no-deps hermes ...`) and (b) by
  # doctor.sh's `docker info` / `docker compose ... config` / `... ps`
  # read-only probes. Never actually talks to a Docker daemon.
  cat > "$dir/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$CALL_LOG"
if [ "$1" = "info" ]; then
  exit "${FAKE_DOCKER_INFO_EXIT:-0}"
fi
if [ "$1" = "compose" ]; then
  shift
  # drop "-f <file>"
  args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -f) shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  case "${args[0]:-}" in
    version) exit "${FAKE_DOCKER_COMPOSE_VERSION_EXIT:-0}" ;;
    config) exit "${FAKE_DOCKER_COMPOSE_CONFIG_EXIT:-0}" ;;
    ps) exit "${FAKE_DOCKER_COMPOSE_PS_EXIT:-1}" ;;
    run)
      # args: run --rm --no-deps hermes <the real command...>
      shift_count=0
      for a in "${args[@]}"; do
        shift_count=$((shift_count + 1))
        [ "$a" = "hermes" ] && break
      done
      real=("${args[@]:$shift_count}")
      exec "${real[0]}" "${real[@]:1}"
      ;;
  esac
fi
echo "fake docker: unhandled invocation: $*" >&2
exit 1
EOF

  cat > "$dir/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >> "$CALL_LOG"
[ "$1" = "is-active" ] && exit "${FAKE_SYSTEMCTL_IS_ACTIVE_EXIT:-1}"
echo "fake systemctl: unhandled invocation: $*" >&2
exit 1
EOF

  cat > "$dir/systemd-analyze" <<'EOF'
#!/usr/bin/env bash
echo "systemd-analyze $*" >> "$CALL_LOG"
[ "$1" = "verify" ] && exit "${FAKE_SYSTEMD_ANALYZE_VERIFY_EXIT:-0}"
exit 1
EOF

  chmod +x "$dir"/hermes "$dir"/claude "$dir"/gh "$dir"/docker "$dir"/systemctl "$dir"/systemd-analyze
}

# make_fake_curl DIR CAPTURE_FILE — a fake curl standing in for the real
# `curl -sS -o body -w '%{http_code}' -K cfg` invocation in
# discord_validate_token (connect-common.sh). Copies the -K config file to
# CAPTURE_FILE so a test can inspect it directly (permissions, exact
# header) without ever relying on stdout/stderr, which is exactly what
# discord_validate_token itself never puts the token in.
make_fake_curl() {
  local dir="$1" capture="$2"
  mkdir -p "$dir"
  cat > "$dir/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "\$CALL_LOG"
o="" cfg=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) o="\$2"; shift 2 ;;
    -K) cfg="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "\$cfg" ] && cp "\$cfg" "$capture"
[ -n "\$o" ] && : > "\$o"
printf '%s' "\${FAKE_CURL_HTTP_CODE:-200}"
exit "\${FAKE_CURL_EXIT:-0}"
EOF
  chmod +x "$dir/curl"
}
