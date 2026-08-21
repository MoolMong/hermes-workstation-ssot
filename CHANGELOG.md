# Changelog

Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
Entries are keyed by milestone, since this repository is built in
milestones per `BUILD_DIRECTIVE.md` §12.

## [Unreleased]

## [0.1.0-m2] — 2026-08-21 — Milestone 2: Connection UX

### Added

- `bootstrap/connect.sh` (`hermes-connect`) — interactive connection
  command for Discord, OpenAI/Codex, Claude Code, and GitHub. Detects
  already-healthy integrations and skips them unless `--reconnect` is
  given; supports focused reconfiguration (`--discord`, `--openai`,
  `--claude`, `--github`); validates every integration immediately after
  configuration; never echoes or logs a secret value.
- `bootstrap/doctor.sh` (`hermes-doctor`) — read-only diagnostics
  (Docker, Hermes service/gateway, each integration, required
  directories/permissions, systemd unit validity, disk space, installed
  SSOT version/commit, image-readiness). No `--fix` flag by design.
- `bootstrap/connect-common.sh` — shared helpers, including
  `credential_paths()`, the single source of truth for every
  credential-bearing path (cross-checked against `SECURITY.md` §3).
- `docs/FRESH_EC2_VALIDATION.md` — the Fresh EC2 end-to-end validation
  plan required by `MILESTONE2_DIRECTIVE.md` §11, with an explicit STOP
  before any AWS resource is created.
- `tests/connection/` — `run.sh` (syntax checks + full suite runner)
  plus `lib_fakebin.sh` and seven `test_*.sh` scripts (Claude, Discord,
  read-only `hermes-doctor` behavior, GitHub, idempotency/already-
  configured detection, image-readiness credential detection,
  OpenAI/Codex) — all against fake/mocked external tools.
- `tests/bootstrap/test_no_m3_scope.sh` — supersedes the Milestone-1-era
  `test_no_m2_scope.sh`; asserts no Milestone 3+ path exists yet while
  confirming Milestone 2's own paths now legitimately do.
- `evidence/milestone-2/TASK.md`, `evidence/milestone-2/TEST_EVIDENCE.md`.
- `MILESTONE2_DIRECTIVE.md` — the directive this milestone was scoped
  against.

### Fixed

- `docker/docker-compose.yml`'s `command` ran `hermes gateway`, which
  only prints gateway subcommand help and does not start the gateway
  (`hermes_cli/subcommands/gateway.py`). Corrected to
  `["hermes", "gateway", "run"]`, the actual start subcommand, and
  re-verified by `tests/bootstrap/test_docker_compose.sh`. Also dropped
  the Milestone-1-planned `env_file` injection in that same file:
  grounding against the real upstream Hermes Agent CLI showed it
  auto-loads `$HERMES_HOME/.env` and persists `auth.json` itself, both
  already reachable through the existing bind mount, so `hermes-connect`
  writes directly into that volume instead of a separate Compose-level
  secret path.
- `tests/check_milestone0.sh` updated (`CURRENT_MILESTONE=2`,
  `MILESTONES.md` status table) to keep it a real regression check at
  Milestone 2 instead of failing permanently on newly-legitimate
  Milestone 2 paths.

### Verification evidence

- `bash tests/connection/run.sh`, `bash tests/bootstrap/run.sh`, and
  `bash tests/check_milestone0.sh` all pass deterministically; see
  [`evidence/milestone-2/TEST_EVIDENCE.md`](evidence/milestone-2/TEST_EVIDENCE.md)
  for the recorded run output and exact check counts.
- A genuinely fresh, independent read-only Claude Code verifier reran M0
  57/57, M1 22/22, M2 18/18, Bash syntax, and `git diff --check`, reviewed
  every Milestone 2 directive requirement and the three repaired path-doc
  defects, and returned explicit `VERDICT: PASS`. The chronological record
  is [`evidence/milestone-2/VERIFICATION.md`](evidence/milestone-2/VERIFICATION.md).
- Fresh EC2, Docker/Compose, and systemd runtime validation for the
  combined Milestone 1 + Milestone 2 stack, and any real Discord/OpenAI/
  Claude/GitHub account connection, were not authorized/available and
  remain explicitly `NOT RUN`/`BLOCKED`; the plan for that validation,
  including the required AWS-approval STOP, is
  [`docs/FRESH_EC2_VALIDATION.md`](docs/FRESH_EC2_VALIDATION.md).

### Deviations

- None. No forbidden component (`CLAUDE.md` "Forbidden components") was
  added and no architectural deviation was required; see
  `DEVIATIONS.md`.

### Process note

The Claude authoring worker did not commit or push this change, connect
any real account, start or enable any service, or create any AWS
resource. Per the current operating instructions, Git operations remain
with the operator/orchestrator.

### Not included (by design)

Milestones 3–7 (basic work path, verifier, monitor/recovery, parallel
execution, image readiness) — see `MILESTONES.md`.

## [0.1.0-m1] — 2026-08-20 — Milestone 1: Clean bootstrap

### Added

- `bootstrap/install.sh` — idempotent host bootstrap: OS prerequisites
  (`git`, `curl`, `xz-utils`, `ca-certificates`), the Docker engine +
  compose command (fail-closed, Ubuntu/Debian `apt` only, deterministic
  package-set fallback with post-install verification), the secret-free
  `/opt/hermes-data` tree (`0700` dirs), non-secret rendered config
  (`0600`), and the single `systemd/hermes.service` unit (installed and
  `daemon-reload`d, never enabled or started). Supports `--dry-run`;
  every written file carries a provenance header.
- `bootstrap/hermes-commit.pin`, `bootstrap/hermes-installer.sha256` —
  the pinned Hermes Agent commit (`044acf2bf700b8452e903f035406091146eb0245`,
  `NousResearch/hermes-agent`) and the SHA-256 of its installer script at
  that commit, fetched directly (no execution) on 2026-08-20.
- `docker/Dockerfile` — digest-pinned base image; downloads the installer
  from its immutable, commit-scoped `raw.githubusercontent.com` URL;
  verifies its SHA-256 before executing it; passes the same pinned commit
  to `--commit`; builds with `--skip-setup` so the image stays
  credential-free. Parses both pins from the `COPY`'d pin files — no
  duplicated hardcoded `ARG` defaults.
- `docker/docker-compose.yml` — exactly one service (`hermes`, container
  name `hermes`, `command: ["hermes", "gateway"]`, `restart: "no"`).
- `docker/entrypoint.sh` — first-run-only data-volume seeding from
  credential-free build-time scaffolding.
- `systemd/hermes.service` — the only systemd unit; bounded restart
  policy.
- `tests/bootstrap/run.sh` — syntax checks plus the full Milestone 1 test
  suite runner.
- `tests/bootstrap/test_dry_run.sh`, `test_idempotency.sh`,
  `test_file_provenance.sh`, `test_rendered_config.sh`,
  `test_permissions.sh`, `test_docker_compose.sh`,
  `test_systemd_supervision.sh`, `test_dockerfile_pins.sh`,
  `test_fail_closed.sh`, `test_no_m2_scope.sh`.
- `evidence/milestone-1/TASK.md`, `evidence/milestone-1/TEST_EVIDENCE.md`.

### Fixed

- `install.sh`'s systemd-unit provenance header embedded the wall-clock
  render timestamp, so re-running `install.sh` always rewrote (and
  `daemon-reload`d) the unit even with no substantive change — an
  idempotency defect, found by `tests/bootstrap/test_idempotency.sh`.
  Fixed by comparing rendered content with that one volatile clause
  stripped, so only a real change to repo commit or unit content triggers
  a rewrite.
- `tests/check_milestone0.sh`'s repository-tree and skeleton-directory
  checks were Milestone-0-only and would have failed permanently once
  Milestone 1 added real files to `bootstrap/`, `docker/`, `systemd/`.
  Made milestone-aware (a `CURRENT_MILESTONE` constant, cross-checked
  against `MILESTONES.md`'s own status table) instead of weakened.

### Verification evidence

- `bash tests/bootstrap/run.sh` and `bash tests/check_milestone0.sh` both
  pass deterministically; see
  [`evidence/milestone-1/TEST_EVIDENCE.md`](evidence/milestone-1/TEST_EVIDENCE.md)
  for the recorded run output and exact check counts.
- A fresh independent read-only Claude Code verifier reran the deterministic
  gates, inspected the implementation and immutable upstream inputs, and
  returned PASS. The chronological record is
  [`evidence/milestone-1/VERIFICATION.md`](evidence/milestone-1/VERIFICATION.md).
- Fresh EC2 and Docker runtime validation remain BLOCKED/not run; no PASS is
  claimed for those unavailable gates.

### Process note

The Claude authoring worker did not commit or push this change, start or
enable any service, or run a Docker build. Per the current operating
instructions, Git operations remain with the operator/orchestrator.

### Not included (by design)

Milestones 2–7 (connection UX, basic work path, verifier, monitor/
recovery, parallel execution, image readiness) — see `MILESTONES.md`.

## [0.1.0-m0] — 2026-08-20 — Milestone 0: Repository and design

### Added

- `README.md`, `ARCHITECTURE.md`, `WORK_PROTOCOL.md`, `SECURITY.md`,
  `MILESTONES.md`, `DEFINITION_OF_DONE.md`, `DEVIATIONS.md`, `CLAUDE.md`,
  `.gitignore`.
- Proposed repository tree, documented in `ARCHITECTURE.md` and mirrored
  on disk as a minimal, traceable skeleton (`bootstrap/`, `docker/`,
  `systemd/`, `scripts/`, each with a placeholder `README.md` only).
- `config/*.example` files (Discord, OpenAI, Claude, GitHub, Hermes) with
  placeholder values only.
- `tests/check_milestone0.sh` — deterministic Milestone 0 checks (document
  presence, forbidden-scope declaration, secret placeholders, repository
  tree consistency, no Milestone 1–7 functionality present).

### Verification evidence

- `bash tests/check_milestone0.sh` passes deterministically; see the run
  output recorded for the current change for the exact check count and
  result.
- The full chronological record of independent-verifier passes for
  Milestone 0 — including verdicts, scope, and findings — is kept
  durably in [`evidence/milestone-0/VERIFICATION.md`](evidence/milestone-0/VERIFICATION.md),
  not restated as a bare claim here. As of this entry: Pass 1 (content)
  returned PASS; Pass 2 (final-state) returned FAIL, because prior
  versions of this document, `README.md`, `MILESTONES.md`, and
  `DEFINITION_OF_DONE.md` asserted independent-verifier PASS without
  that durable artifact existing; Pass 3 (fresh, independent, final-state
  review of the repaired repository) returned PASS, confirming that
  evidence-integrity defect is fixed. Milestone 0 status is
  **complete**.

Summary of what `tests/check_milestone0.sh` asserts:

- All ten required Milestone 0 documents exist and are non-empty.
- `SECURITY.md` contains a threat-model section, a secret-model section,
  and a credential-location table covering Discord, OpenAI, Claude,
  GitHub, and the `/opt/hermes-data/` tree.
- Every item in `BUILD_DIRECTIVE.md` §10's forbidden-scope list is
  explicitly named in `ARCHITECTURE.md`'s forbidden-scope section, and no
  file in the repository implements any of them.
- No `config/*.example` file contains a real-looking secret (long
  hex/base64 token shape); each contains an explicit placeholder marker.
- The repository tree documented in `ARCHITECTURE.md` §6 (files marked
  `(M0)`) matches what is actually present on disk.
- `bootstrap/`, `docker/`, `systemd/`, `scripts/` contain only a
  `README.md` each — no scripts, unit files, or Dockerfiles yet.
- `evidence/milestone-0/VERIFICATION.md` exists, is non-empty, and
  records a chronological Pass 1 / Pass 2 / Pass 3 verification history;
  and `README.md`, `MILESTONES.md`, `DEFINITION_OF_DONE.md`, and this
  file each reference it rather than self-asserting a verification
  outcome.

### Process note

The Claude authoring worker did not commit or push this change. Per the
current operating instructions, the orchestrator owns the Milestone 0
commit (and any push/PR). This is also recorded in
`DEFINITION_OF_DONE.md`.

### Not included (by design)

Milestones 1–7 (bootstrap, connection UX, basic work path, verifier,
monitor/recovery, parallel execution, image readiness) — see
`MILESTONES.md`.
