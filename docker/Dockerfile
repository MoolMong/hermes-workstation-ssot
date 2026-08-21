# ============================================================================
# Hermes Workstation SSOT — Hermes Agent image (Milestone 1 base + Milestone
# 2 connection-integration tooling: GitHub CLI, pinned Claude Code CLI)
# ============================================================================
# Minimal, pinned, traceable image. This is the ONLY place in this
# repository that fetches and executes the official Hermes Agent installer.
#
# Single container: this image runs the Hermes Agent as one process,
# started as `hermes gateway` by docker-compose.yml (which also carries
# the container_name `hermes`). There is no second orchestrator runtime
# and no second Hermes container — see ARCHITECTURE.md §9 and
# BUILD_DIRECTIVE.md §1/§10.
#
# Traceability / integrity:
#   - Base image is pinned by digest (immutable), not a floating tag — see
#     the FROM line below for the exact digest and the date it was
#     verified.
#   - bootstrap/hermes-commit.pin and bootstrap/hermes-installer.sha256 are
#     the single source of truth for what gets installed. This Dockerfile
#     COPYs those two files and parses them directly at build time — their
#     values are never duplicated as hardcoded ARG defaults, so there is
#     exactly one place to update either pin.
#   - The installer URL is derived from the pinned commit itself
#     (https://raw.githubusercontent.com/NousResearch/hermes-agent/<pinned
#     commit>/scripts/install.sh). A raw.githubusercontent.com URL scoped
#     to an exact commit is immutable — it can never start silently
#     serving different content the way a floating `main`/latest URL
#     could.
#   - The installer script is downloaded, then verified against the
#     repository-recorded SHA-256 in bootstrap/hermes-installer.sha256
#     BEFORE it is executed. A mismatch fails the build (fail closed).
#   - The installer is told to check out the exact commit recorded in
#     bootstrap/hermes-commit.pin via --commit, not a floating branch.
#
# Secret-free by construction: --skip-setup means the installer never
# prompts for or writes credentials, so nothing secret can enter this
# image's layers. Real credentials live only in the bind-mounted /data
# volume, populated at runtime by `hermes-connect` (Milestone 2), never
# baked into the image.
# ============================================================================

# Verified 2026-08-20: ubuntu:24.04 multi-arch manifest-list digest, read
# directly from Docker Hub (hub.docker.com/_/ubuntu) at that date. Pinning
# by digest, not tag, makes this build reproducible regardless of what the
# `ubuntu:24.04` tag is later repointed to.
FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517

# Prerequisites the installer itself expects to already be present. The
# installer manages uv/Python/Node/ripgrep/ffmpeg on its own.
RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
       git curl xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# bootstrap/hermes-commit.pin and bootstrap/hermes-installer.sha256 are the
# SSOT for what this image installs. They are copied in and parsed below —
# never duplicated as a hardcoded ARG default.
COPY bootstrap/hermes-commit.pin bootstrap/hermes-installer.sha256 /tmp/pins/

# Download, then verify, then execute — never curl-pipe unverified content.
RUN set -eu; \
    HERMES_COMMIT="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' /tmp/pins/hermes-commit.pin | head -n1 | tr -d '[:space:]')"; \
    HERMES_INSTALLER_SHA256="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' /tmp/pins/hermes-installer.sha256 | head -n1 | awk '{print $1}')"; \
    HERMES_INSTALLER_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_COMMIT}/scripts/install.sh"; \
    curl -fsSL -o /tmp/hermes-install.sh "$HERMES_INSTALLER_URL"; \
    echo "$HERMES_INSTALLER_SHA256  /tmp/hermes-install.sh" | sha256sum -c -; \
    bash /tmp/hermes-install.sh \
        --non-interactive \
        --skip-setup \
        --skip-browser \
        --skip-computer-use \
        --commit "$HERMES_COMMIT" \
        --dir /usr/local/lib/hermes-agent \
        --hermes-home /opt/hermes-seed; \
    rm -f /tmp/hermes-install.sh; \
    rm -rf /tmp/pins

# ----------------------------------------------------------------------------
# GitHub CLI — installed via the official apt repository (documented method:
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian-ubuntu-linux-raspberry-pi-os-apt),
# not a third-party script. Used by hermes-connect (Milestone 2) for HTTPS
# `gh auth login` / `gh auth setup-git` — no SSH key management.
# ----------------------------------------------------------------------------
RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends gnupg \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh \
    && rm -rf /var/lib/apt/lists/* \
    && gh --version

# ----------------------------------------------------------------------------
# Claude Code CLI — exact version pin (MILESTONE2_DIRECTIVE.md), installed
# via npm. The Hermes Agent installer above already provisions Node.js for
# its own use (NODE_VERSION pinned in the upstream installer); this reuses
# that npm rather than provisioning a second, possibly conflicting Node
# toolchain. Fails the build (does not silently skip the pin) if npm is not
# on PATH after the Hermes Agent install.
# ----------------------------------------------------------------------------
RUN set -eu; \
    if ! command -v npm >/dev/null 2>&1; then \
        echo "npm not found after Hermes Agent install — cannot install pinned @anthropic-ai/claude-code" >&2; \
        exit 1; \
    fi; \
    npm install -g @anthropic-ai/claude-code@2.1.237; \
    claude --version

# Runtime data root — bind-mounted from host /opt/hermes-data via
# docker-compose.yml. Never populated with real content at build time;
# entrypoint.sh seeds it from /opt/hermes-seed on first run only.
ENV HERMES_HOME=/data
RUN mkdir -p /data && chmod 0700 /data

# Persistent auth locations for Claude Code and GitHub CLI, bind-mounted via
# the same /data volume as HERMES_HOME (host: /opt/hermes-data/auth/claude,
# /opt/hermes-data/auth/github — see SECURITY.md §3). Set only now, after
# every build-time package install above, so those installs still use the
# image's normal build-time HOME rather than this runtime-only path.
# docker/entrypoint.sh creates these directories (0700) on every container
# start, since /data is an empty bind mount until then.
ENV HOME=/data/auth/claude
ENV CLAUDE_CONFIG_DIR=/data/auth/claude
ENV GH_CONFIG_DIR=/data/auth/github/gh
ENV GIT_CONFIG_GLOBAL=/data/auth/github/.gitconfig

COPY docker/entrypoint.sh /usr/local/bin/hermes-entrypoint.sh
RUN chmod +x /usr/local/bin/hermes-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
CMD ["hermes"]
