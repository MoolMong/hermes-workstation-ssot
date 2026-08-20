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

exec "$@"
