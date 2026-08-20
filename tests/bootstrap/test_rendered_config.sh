#!/usr/bin/env bash
# Milestone 1: the config rendered by bootstrap/install.sh must correctly
# substitute data_root, must never introduce a real-looking secret, and
# must leave every field that only hermes-connect (Milestone 2) is allowed
# to fill (REPLACE_ME markers) untouched. Runs entirely inside a throwaway
# temp directory.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/hermes-data"
SYSD="$TMP/systemd"

bash "$REPO_ROOT/bootstrap/install.sh" \
  --data-root "$DATA" --systemd-dir "$SYSD" --repo-root "$REPO_ROOT" \
  --skip-prereqs --skip-docker --skip-systemd-reload >/tmp/render_out.$$ 2>&1
STATUS=$?
RENDERED="$DATA/config/hermes.config.yaml"

FAIL=0
check() { if [ "$1" -ne 0 ]; then echo "FAIL: $2"; FAIL=1; else echo "PASS: $2"; fi; }

check "$STATUS" "install.sh exits 0"

[ -f "$RENDERED" ] && r=0 || r=1
check "$r" "rendered config file exists at $RENDERED"

grep -q "^data_root: $DATA\$" "$RENDERED" && r=0 || r=1
check "$r" "data_root correctly substituted with the actual data root"

grep -q '^max_repair_attempts: REPLACE_ME$' "$RENDERED" && r=0 || r=1
check "$r" "max_repair_attempts left as REPLACE_ME (not fabricated by M1)"

grep -q '^max_task_retries: REPLACE_ME$' "$RENDERED" && r=0 || r=1
check "$r" "max_task_retries left as REPLACE_ME (not fabricated by M1)"

grep -q 'guild_id: REPLACE_ME' "$RENDERED" && r=0 || r=1
check "$r" "discord.guild_id left as REPLACE_ME (Milestone 2 territory)"

grep -q 'Installed by bootstrap/install.sh from config/hermes.config.example.yaml' "$RENDERED" && r=0 || r=1
check "$r" "rendered file carries a provenance header pointing back to its source"

# Excludes: the REPLACE_ME marker; git-commit-hash-shaped hex strings
# (the provenance header's "repo commit <sha>" — a public commit id, not
# a secret) and the literal "unknown" fallback; the data root path; and
# the template/rendered filenames that legitimately appear in the
# template's own descriptive comments.
suspicious=$(grep -oE '[A-Za-z0-9_./-]{25,}' "$RENDERED" \
  | grep -v '^REPLACE_ME$' \
  | grep -vE '^[0-9a-f]{7,40}$' \
  | grep -vE '^unknown$' \
  | grep -vE "^($DATA|/opt/hermes-data|config/hermes\.config\.example\.yaml|config/hermes\.config\.yaml|Installed|bootstrap/install\.sh)" \
  || true)
[ -z "$suspicious" ] && r=0 || r=1
check "$r" "no real-looking secret strings introduced by rendering: ${suspicious:-none}"

if [ "$FAIL" -ne 0 ]; then
  cat /tmp/render_out.$$ >&2
  rm -f /tmp/render_out.$$
  echo "RESULT: FAIL"
  exit 1
fi
rm -f /tmp/render_out.$$
echo "RESULT: PASS"
