#!/usr/bin/env bash
# Seeds the runtime data volume (/data, bind-mounted to host
# /opt/hermes-data) from the build-time default scaffolding at
# /opt/hermes-seed, but only on first run — never overwrites an existing,
# already-initialized volume. This keeps the image itself credential-free
# (nothing secret is ever baked into /opt/hermes-seed, since the image was
# built with --skip-setup) while still giving a brand-new host volume a
# working default layout on first boot.
set -euo pipefail

if [ -d /opt/hermes-seed ] && [ ! -e /data/.seeded ]; then
  cp -a /opt/hermes-seed/. /data/
  touch /data/.seeded
fi

# Persistent auth directories (Milestone 2 — see docker/Dockerfile's
# CLAUDE_CONFIG_DIR/GH_CONFIG_DIR/GIT_CONFIG_GLOBAL env vars and
# SECURITY.md §3). /data is an empty bind mount until this point, so these
# are (re)ensured on every start, not just first run — idempotent, and
# never overwrites any file already inside them.
mkdir -p /data/auth/claude /data/auth/github/gh
chmod 0700 /data/auth /data/auth/claude /data/auth/github

exec "$@"
