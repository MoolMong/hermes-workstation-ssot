#!/usr/bin/env bash
# Milestone 2: hermes-doctor is read-only, byte-for-byte — it must never
# write, create, delete, chmod, start, stop, or enable anything, even when
# it finds a problem (e.g. wrong permissions). It has no --fix flag by
# design. Verified by snapshotting a populated fake install (files,
# permissions, and content checksums) before and after a full doctor run,
# and by asserting none of the mocked external tools ever received a
# mutating subcommand.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCTOR="$REPO_ROOT/bootstrap/doctor.sh"
# shellcheck source=tests/connection/lib_fakebin.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib_fakebin.sh"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKEBIN="$TMP/fakebin"
make_fakebin "$FAKEBIN"
make_fake_curl "$FAKEBIN" "$TMP/captured_curl_cfg"

DATA="$TMP/data"
SYSD="$TMP/systemd"
mkdir -p "$DATA"/{auth,config,workspaces,tasks,logs,backup} "$SYSD"
chmod 0700 "$DATA"/{auth,config,workspaces,tasks,logs,backup}
# Deliberately WRONG permissions on one file, to prove doctor reports it
# (WARNING) without silently correcting it.
printf 'DISCORD_BOT_TOKEN=deadbeef\n' > "$DATA/.env"
chmod 0644 "$DATA/.env"
printf 'model: {}\n' > "$DATA/config.yaml"
chmod 0600 "$DATA/config.yaml"
cp "$REPO_ROOT/systemd/hermes.service" "$SYSD/hermes.service"
chmod 0644 "$SYSD/hermes.service"

# Snapshot: relative path -> "perm:sha256"
snapshot() {
  find "$DATA" "$SYSD" -type f | sort | while IFS= read -r f; do
    printf '%s %s %s\n' "$f" "$(stat -c %a "$f")" "$(sha256sum "$f" | cut -d' ' -f1)"
  done
}
find_list() { find "$DATA" "$SYSD" | sort; }

BEFORE_SNAPSHOT="$(snapshot)"
BEFORE_LIST="$(find_list)"

: > "$TMP/call.log"
OUT="$(CALL_LOG="$TMP/call.log" \
  HERMES_DATA_ROOT="$DATA" \
  HERMES_SYSTEMD_DIR="$SYSD" \
  HERMES_COMPOSE_FILE="$REPO_ROOT/docker/docker-compose.yml" \
  HERMES_CURL_BIN="$FAKEBIN/curl" \
  PATH="$FAKEBIN:$PATH" \
  bash "$DOCTOR" 2>&1)"
STATUS=$?

AFTER_SNAPSHOT="$(snapshot)"
AFTER_LIST="$(find_list)"

[ "$BEFORE_SNAPSHOT" = "$AFTER_SNAPSHOT" ] && r=0 || r=1
check "$r" "no file under \$DATA_ROOT or the systemd dir changed content or permissions"
[ "$BEFORE_LIST" = "$AFTER_LIST" ] && r=0 || r=1
check "$r" "no file was created or deleted under \$DATA_ROOT or the systemd dir"

perm="$(stat -c %a "$DATA/.env")"
[ "$perm" = "644" ] && r=0 || r=1
check "$r" "the deliberately-wrong 0644 .env permission was left untouched (got $perm)"
echo "$OUT" | grep -qi 'WARNING' && r=0 || r=1
check "$r" "doctor reports the wrong permission as a WARNING instead of silently fixing it"

# doctor.sh has no --fix flag (a byte-for-byte read-only tool never needs
# one negotiated away later).
HELP_OUT="$(bash "$DOCTOR" --help 2>&1)"
echo "$HELP_OUT" | grep -qi -- '--fix' && r=1 || r=0
check "$r" "--help does not mention any --fix flag"
bash "$DOCTOR" --fix >/tmp/doctor_fix_out.$$ 2>&1
FIX_STATUS=$?
[ "$FIX_STATUS" -ne 0 ] && r=0 || r=1
check "$r" "passing --fix is rejected (unknown argument), not silently accepted"
rm -f /tmp/doctor_fix_out.$$

# No mocked external tool ever received a mutating subcommand. `docker
# compose run --rm` (an ephemeral one-off container, the run_in_container
# transport) is expected and fine — it is not a persistent second
# service; `up`/`pull`/a bare (non-compose) `docker run` would be.
grep -qE '^docker compose .*\bup\b' "$TMP/call.log" && r=1 || r=0
check "$r" "doctor never invokes docker compose up (no persistent second service)"
grep -qE '^docker compose .*\bpull\b' "$TMP/call.log" && r=1 || r=0
check "$r" "doctor never invokes docker compose pull"
grep -qE '^docker run\b' "$TMP/call.log" && r=1 || r=0
check "$r" "doctor never invokes a bare (non-compose) docker run"
grep -qE '^docker compose .*run --rm --no-deps hermes\b' "$TMP/call.log" && r=0 || r=1
check "$r" "read-only probes inside the Hermes image go through the ephemeral 'docker compose run --rm' transport, not a persistent container"
grep -qE '^systemctl (enable|start|stop|restart|daemon-reload)\b' "$TMP/call.log" && r=1 || r=0
check "$r" "doctor never invokes systemctl enable/start/stop/restart/daemon-reload"
grep -qE '^gh auth login\b' "$TMP/call.log" && r=1 || r=0
check "$r" "doctor never invokes gh auth login"
grep -qE '^hermes auth add\b' "$TMP/call.log" && r=1 || r=0
check "$r" "doctor never invokes hermes auth add"
grep -qE '^claude setup-token\b' "$TMP/call.log" && r=1 || r=0
check "$r" "doctor never invokes claude setup-token"

if [ "$FAIL" -ne 0 ]; then
  echo "--- doctor output ---" >&2
  echo "$OUT" >&2
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
