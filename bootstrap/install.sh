#!/usr/bin/env bash
# ============================================================================
# Hermes Workstation SSOT — base host bootstrap (Milestone 1)
# ============================================================================
# Fresh-EC2-Linux base bootstrap for the Hermes/Runner/Monitor/Verifier
# workstation. This script prepares the HOST: prerequisites, the Docker
# engine, the secret-free /opt/hermes-data directory tree, non-secret
# rendered configuration, and systemd supervision units.
#
# It does NOT install the Hermes Agent itself — that happens inside the
# Docker image (see docker/Dockerfile), which downloads the official
# installer, verifies it against bootstrap/hermes-installer.sha256, and
# checks out the commit pinned in bootstrap/hermes-commit.pin. Keeping that
# logic in the image build (not here) keeps this script host-only and keeps
# the image itself the single reproducible, traceable build artifact.
#
# Idempotent: safe to re-run. Every stage checks existing state before
# mutating and reports ALREADY / DONE / SKIPPED / DRY-RUN / WARN per stage.
#
# Every file this script writes carries a provenance comment pointing back
# to its source in this repository, per BUILD_DIRECTIVE.md §7 ("Every
# installed file or service must be traceable back to the repository").
#
# This script never handles credentials. Milestone 2 (`hermes-connect`)
# populates auth/*. See SECURITY.md §3.
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults (all overridable — required for safe testing in temp directories,
# and for real hosts that want a non-default layout).
# ---------------------------------------------------------------------------
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="${HERMES_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

DATA_ROOT="${HERMES_DATA_ROOT:-/opt/hermes-data}"
SYSTEMD_DIR="${HERMES_SYSTEMD_DIR:-/etc/systemd/system}"
PIN_COMMIT_FILE="$REPO_ROOT/bootstrap/hermes-commit.pin"
PIN_COMMIT="${HERMES_PIN_COMMIT:-}"

DRY_RUN=false
SKIP_PREREQS=false
SKIP_DOCKER=false
SKIP_SYSTEMD=false
SKIP_SYSTEMD_RELOAD=false

APT_PACKAGES=(git curl xz-utils ca-certificates)

# Deterministic package-set fallback for the Docker engine + compose
# command. Ubuntu 24.04 hosts may not carry docker-compose-plugin
# depending on which repos are enabled; docker-compose-v2 is the
# supported alternate package name for the same `docker compose` CLI.
# Each entry is tried in order; the first that installs cleanly wins, and
# the actual `docker` / `docker compose` commands are verified afterward
# (see check_docker) rather than trusting apt's exit code alone.
DOCKER_PACKAGE_SETS=(
  "docker.io docker-compose-plugin"
  "docker.io docker-compose-v2"
)

STAGE_COUNT=0

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log()      { printf '[install] %s\n' "$1"; }
log_done() { STAGE_COUNT=$((STAGE_COUNT + 1)); printf '[install] DONE: %s\n' "$1"; }
log_skip() { STAGE_COUNT=$((STAGE_COUNT + 1)); printf '[install] ALREADY: %s\n' "$1"; }
log_dry()  { STAGE_COUNT=$((STAGE_COUNT + 1)); printf '[install] [dry-run] would: %s\n' "$1"; }
log_err()  { printf '[install] ERROR: %s\n' "$1" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bootstrap/install.sh [options]

Idempotent base bootstrap for a Hermes Workstation host. Prepares the OS
prerequisites, Docker engine, /opt/hermes-data directory tree, non-secret
rendered config, and systemd supervision units. Does not install the
Hermes Agent itself (that is built into the Docker image) and never
handles credentials (Milestone 2 does).

Options:
  --dry-run              Print planned actions; make no filesystem,
                          package, or systemd changes.
  --data-root PATH        Override the data root (default: /opt/hermes-data)
  --systemd-dir PATH       Override the systemd unit install dir
                          (default: /etc/systemd/system)
  --repo-root PATH         Override the repository root used as the source
                          of truth for units/config (default: detected)
  --commit SHA             Override the pinned Hermes commit (default: read
                          from bootstrap/hermes-commit.pin)
  --skip-prereqs           Skip the git/curl/xz-utils apt-get stage
  --skip-docker            Skip the Docker engine check/install stage
  --skip-systemd            Skip installing systemd unit files entirely
  --skip-systemd-reload      Install unit files but skip `systemctl
                          daemon-reload` (used by tests without a real
                          systemd instance)
  -h, --help                Show this help and exit

Every stage is idempotent: re-running this script converges to the same
state and does not duplicate or corrupt existing data.
EOF
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --data-root) DATA_ROOT="$2"; shift 2 ;;
    --systemd-dir) SYSTEMD_DIR="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --commit) PIN_COMMIT="$2"; shift 2 ;;
    --skip-prereqs) SKIP_PREREQS=true; shift ;;
    --skip-docker) SKIP_DOCKER=true; shift ;;
    --skip-systemd) SKIP_SYSTEMD=true; shift ;;
    --skip-systemd-reload) SKIP_SYSTEMD_RELOAD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_err "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

if [ -z "$PIN_COMMIT" ]; then
  if [ -f "$PIN_COMMIT_FILE" ]; then
    PIN_COMMIT="$(grep -vE '^\s*#|^\s*$' "$PIN_COMMIT_FILE" | head -n1 | tr -d '[:space:]')"
  else
    log_err "no --commit given and $PIN_COMMIT_FILE not found"
    exit 2
  fi
fi

REPO_COMMIT="unknown"
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  REPO_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

provenance_header() {
  # $1 = comment prefix (e.g. "#"), $2 = source path relative to repo root
  printf '%s Installed by bootstrap/install.sh from %s (repo commit %s) on %s.\n%s Do not edit in place — edit the source in the repository and re-run install.sh.\n' \
    "$1" "$2" "$REPO_COMMIT" "$TIMESTAMP" "$1"
}

# ---------------------------------------------------------------------------
# Stage: prerequisites (git, curl, xz-utils, ca-certificates)
#
# Fail-closed by design: a missing apt-get, missing root, a failed
# install, or a package that still isn't detected after "successful"
# install must abort the bootstrap with a nonzero exit. This script never
# reports a stage as done/skipped when the underlying state was not
# actually verified — a WARN-and-continue here would let a broken host
# silently pass as bootstrapped.
# ---------------------------------------------------------------------------
check_prereqs() {
  if [ "$SKIP_PREREQS" = true ]; then
    log "skipping prerequisites stage (--skip-prereqs)"
    return 0
  fi

  local missing=()
  for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    log_skip "prerequisites already installed: ${APT_PACKAGES[*]}"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "apt-get install -y ${missing[*]}"
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    log_err "apt-get not found — this bootstrap supports Ubuntu/Debian (apt) hosts only; cannot install: ${missing[*]}"
    exit 1
  fi

  if [ "$(id -u)" -ne 0 ]; then
    log_err "not running as root — cannot install missing prerequisites (${missing[*]}); re-run as root/sudo"
    exit 1
  fi

  if ! DEBIAN_FRONTEND=noninteractive apt-get update -qq; then
    log_err "apt-get update failed"
    exit 1
  fi
  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"; then
    log_err "apt-get install failed for: ${missing[*]}"
    exit 1
  fi

  # Post-install detection: verify, do not trust apt's exit code alone.
  local still_missing=()
  for pkg in "${missing[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || still_missing+=("$pkg")
  done
  if [ "${#still_missing[@]}" -gt 0 ]; then
    log_err "post-install detection failed: still missing after apt-get install: ${still_missing[*]}"
    exit 1
  fi

  log_done "installed prerequisites: ${missing[*]}"
}

# ---------------------------------------------------------------------------
# Stage: Docker engine + compose command
#
# Same fail-closed contract as check_prereqs, plus a deterministic
# supported-alternatives package strategy (see DOCKER_PACKAGE_SETS above)
# and an explicit post-install verification of the actual `docker` /
# `docker compose` commands this repository depends on.
# ---------------------------------------------------------------------------
check_docker() {
  if [ "$SKIP_DOCKER" = true ]; then
    log "skipping Docker stage (--skip-docker)"
    return 0
  fi

  local have_docker=false have_compose=false
  command -v docker >/dev/null 2>&1 && have_docker=true
  if $have_docker && docker compose version >/dev/null 2>&1; then
    have_compose=true
  fi

  if $have_docker && $have_compose; then
    log_skip "Docker engine and compose already present (verified: docker compose version)"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "install Docker engine + compose (tries in order: ${DOCKER_PACKAGE_SETS[*]}), then verify docker + docker compose commands"
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    log_err "apt-get not found — this bootstrap supports Ubuntu/Debian (apt) hosts only; cannot install Docker"
    exit 1
  fi

  if [ "$(id -u)" -ne 0 ]; then
    log_err "not running as root — cannot install Docker; re-run as root/sudo"
    exit 1
  fi

  if ! DEBIAN_FRONTEND=noninteractive apt-get update -qq; then
    log_err "apt-get update failed"
    exit 1
  fi

  local installed_set=""
  for pkg_set in "${DOCKER_PACKAGE_SETS[@]}"; do
    # shellcheck disable=SC2206
    local pkgs=($pkg_set)
    if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}" 2>/dev/null; then
      installed_set="$pkg_set"
      break
    fi
  done

  if [ -z "$installed_set" ]; then
    log_err "failed to install Docker via any supported package set: ${DOCKER_PACKAGE_SETS[*]}"
    exit 1
  fi

  # Post-install detection: a package manager reporting success is not
  # sufficient evidence — verify the exact commands this repository uses.
  if ! command -v docker >/dev/null 2>&1; then
    log_err "post-install detection failed: 'docker' not found after installing ($installed_set)"
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    log_err "post-install detection failed: 'docker compose version' did not succeed after installing ($installed_set)"
    exit 1
  fi

  log_done "installed Docker via ($installed_set); verified docker + docker compose commands"
}

# ---------------------------------------------------------------------------
# Stage: /opt/hermes-data directory tree (secret-free, safe permissions)
# ---------------------------------------------------------------------------
setup_data_dir() {
  local subdirs=(auth config workspaces tasks logs backup)
  local created=() existing=()

  if [ "$DRY_RUN" = true ]; then
    for d in "${subdirs[@]}"; do
      if [ -d "$DATA_ROOT/$d" ]; then existing+=("$d"); else created+=("$d"); fi
    done
    log_dry "create $DATA_ROOT/{${subdirs[*]}} (0700) — missing: ${created[*]:-none}"
    return 0
  fi

  mkdir -p "$DATA_ROOT"
  chmod 0700 "$DATA_ROOT"
  for d in "${subdirs[@]}"; do
    if [ -d "$DATA_ROOT/$d" ]; then
      existing+=("$d")
    else
      mkdir -p "$DATA_ROOT/$d"
      created+=("$d")
    fi
    chmod 0700 "$DATA_ROOT/$d"
  done

  local provenance_file="$DATA_ROOT/.provenance"
  local created_at="$TIMESTAMP"
  if [ -f "$provenance_file" ]; then
    created_at="$(grep -E '^created_at=' "$provenance_file" 2>/dev/null | head -n1 | cut -d= -f2- || true)"
    [ -n "$created_at" ] || created_at="$TIMESTAMP"
  fi
  {
    echo "# Provenance for $DATA_ROOT, written by bootstrap/install.sh."
    echo "# Contains no credentials — see SECURITY.md §3 for what does."
    echo "created_at=$created_at"
    echo "last_bootstrap_at=$TIMESTAMP"
    echo "ssot_repo_commit=$REPO_COMMIT"
    echo "hermes_pin_commit=$PIN_COMMIT"
    echo "bootstrap_script=$SCRIPT_PATH"
  } > "$provenance_file"
  chmod 0600 "$provenance_file"

  if [ "${#created[@]}" -gt 0 ]; then
    log_done "created data directories under $DATA_ROOT: ${created[*]}"
  else
    log_skip "all data directories already present under $DATA_ROOT"
  fi
}

# ---------------------------------------------------------------------------
# Stage: render non-secret runtime config
# ---------------------------------------------------------------------------
render_config() {
  local src="$REPO_ROOT/config/hermes.config.example.yaml"
  local dest_dir="$DATA_ROOT/config"
  local dest="$dest_dir/hermes.config.yaml"

  if [ ! -f "$src" ]; then
    log_err "missing template: $src"
    exit 1
  fi

  if [ "$DRY_RUN" = true ]; then
    if [ -f "$dest" ]; then
      log_dry "leave existing $dest untouched (already rendered)"
    else
      log_dry "render $dest from config/hermes.config.example.yaml (data_root: $DATA_ROOT)"
    fi
    return 0
  fi

  mkdir -p "$dest_dir"
  chmod 0700 "$dest_dir"

  if [ -f "$dest" ]; then
    log_skip "$dest already rendered — not overwriting operator edits"
    return 0
  fi

  {
    provenance_header "#" "config/hermes.config.example.yaml"
    echo "#"
    sed -E "s#^data_root:.*#data_root: $DATA_ROOT#" "$src"
  } > "$dest"
  chmod 0600 "$dest"
  log_done "rendered $dest"
}

# ---------------------------------------------------------------------------
# Stage: systemd supervision units
# ---------------------------------------------------------------------------
render_unit() {
  # $1 = source unit file in repo, $2 = destination path
  local src="$1" dest="$2" tmp
  tmp="$(mktemp)"
  {
    provenance_header "#" "systemd/$(basename "$src")"
    echo "#"
    sed \
      -e "s#@@REPO_ROOT@@#$REPO_ROOT#g" \
      -e "s#@@DATA_ROOT@@#$DATA_ROOT#g" \
      "$src"
  } > "$tmp"

  # Idempotency: the provenance header's "on $TIMESTAMP" clause is wall-clock
  # time and differs on every run by construction, so a raw byte compare
  # against $dest would always report "changed" and rewrite (and
  # daemon-reload) the unit on every re-run even when nothing meaningful
  # moved. Compare with that one volatile clause stripped instead; only a
  # real change to repo commit or unit content should trigger a rewrite.
  local strip_ts='s/ on [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\.$//'
  if [ -f "$dest" ] && \
      diff -q <(sed -E "$strip_ts" "$tmp") <(sed -E "$strip_ts" "$dest") >/dev/null 2>&1; then
    rm -f "$tmp"
    return 1 # unchanged
  fi
  mv "$tmp" "$dest"
  chmod 0644 "$dest"
  return 0 # changed
}

install_systemd_units() {
  if [ "$SKIP_SYSTEMD" = true ]; then
    log "skipping systemd unit stage (--skip-systemd)"
    return 0
  fi

  # Exactly one systemd unit, supervising the one Hermes container (see
  # docker/docker-compose.yml and ARCHITECTURE.md §9). "Hermes Gateway" is
  # a logical Monitor check on that same container/process, not a second
  # service — an earlier draft of this repository's tree mistakenly
  # planned a second hermes-gateway.service unit; that was corrected here
  # to satisfy the "exactly one systemd unit" constraint.
  local units=(hermes.service)
  local changed=() unchanged=()

  if [ "$DRY_RUN" = true ]; then
    for u in "${units[@]}"; do
      if [ -f "$SYSTEMD_DIR/$u" ]; then existing_note="update if changed"; else existing_note="create"; fi
      log_dry "$existing_note $SYSTEMD_DIR/$u from systemd/$u"
    done
    return 0
  fi

  mkdir -p "$SYSTEMD_DIR"
  for u in "${units[@]}"; do
    local src="$REPO_ROOT/systemd/$u"
    if [ ! -f "$src" ]; then
      log_err "missing unit source: $src"
      exit 1
    fi
    if render_unit "$src" "$SYSTEMD_DIR/$u"; then
      changed+=("$u")
    else
      unchanged+=("$u")
    fi
  done

  if [ "${#changed[@]}" -gt 0 ]; then
    log_done "installed/updated systemd units: ${changed[*]}"
    if [ "$SKIP_SYSTEMD_RELOAD" = true ]; then
      log "skipping daemon-reload (--skip-systemd-reload)"
    elif command -v systemctl >/dev/null 2>&1; then
      systemctl daemon-reload
      log_done "systemctl daemon-reload"
    else
      log_err "systemctl not found — this bootstrap targets systemd hosts; cannot reload unit changes (pass --skip-systemd-reload only for isolated testing)"
      exit 1
    fi
  else
    log_skip "systemd units already up to date: ${unchanged[*]}"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  log "Hermes Workstation SSOT — base bootstrap"
  log "repo root:    $REPO_ROOT"
  log "data root:    $DATA_ROOT"
  log "systemd dir:  $SYSTEMD_DIR"
  log "pinned commit: $PIN_COMMIT"
  [ "$DRY_RUN" = true ] && log "mode: DRY RUN (no changes will be made)"

  check_prereqs
  check_docker
  setup_data_dir
  render_config
  install_systemd_units

  echo
  log "bootstrap complete: $STAGE_COUNT stage(s) processed"
  log "Hermes Agent itself is installed inside the Docker image (docker/Dockerfile)."
  log "Credentials are configured by hermes-connect (Milestone 2, not yet implemented)."
}

main
