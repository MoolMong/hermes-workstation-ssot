# TASK.md — Milestone 1: Clean bootstrap

Written per `WORK_PROTOCOL.md` §1 ("For every actionable request... Create
`TASK.md`"). This is the Context artifact for Milestone 1
(`BUILD_DIRECTIVE.md` §12: "Fresh EC2 can install the base workstation
reproducibly from the repo."), covering both the original implementation
pass and the repair pass that closed the gaps found afterward (see
`evidence/milestone-1/TEST_EVIDENCE.md`).

## Goal

Make a fresh EC2 (or any equivalent clean Ubuntu/Debian host) able to
install the base Hermes Workstation reproducibly from this repository
alone: OS prerequisites, the Docker engine, the secret-free
`/opt/hermes-data` directory tree, non-secret rendered configuration, the
single Hermes container image (built from a pinned, checksum-verified
Hermes Agent installer), and the single bounded-restart systemd
supervision unit — with no undocumented manual steps and no credentials
anywhere in the process (`SECURITY.md` §2, `BUILD_DIRECTIVE.md` §7-§8).

## Context

- `BUILD_DIRECTIVE.md` §7 requires the repository to be the deployment
  SSOT; §8 requires the base image to ship with zero credentials; §12
  scopes Milestone 1 to "clean bootstrap" only — not `hermes-connect`,
  not Hermes/Runner/Monitor/Verifier code, not Discord.
- `ARCHITECTURE.md` §6 is authoritative for which files belong to
  Milestone 1: `bootstrap/install.sh`, `bootstrap/hermes-commit.pin`,
  `bootstrap/hermes-installer.sha256`, `docker/Dockerfile`,
  `docker/docker-compose.yml`, `docker/entrypoint.sh`,
  `systemd/hermes.service`, `tests/bootstrap/`. It also documents (§6,
  note below the tree) that there is exactly one systemd unit and exactly
  one Compose service/container, and that an earlier draft's second
  `hermes-gateway.service` unit was a mistake, corrected during this
  milestone.
- `MILESTONES.md`'s sequencing rule: do not begin Milestone 2
  (`hermes-connect`/`hermes-doctor`) or later work before this milestone's
  Definition of Done is met and recorded.
- The upstream Hermes Agent lives in `NousResearch/hermes-agent` on
  GitHub. This repository pins to commit
  `044acf2bf700b8452e903f035406091146eb0245` (see
  `bootstrap/hermes-commit.pin`) rather than a floating branch, per the
  explicit instruction to pin an exact revision. The installer script at
  that commit (`scripts/install.sh`) was downloaded directly (no
  execution) from its immutable, commit-scoped
  `raw.githubusercontent.com` URL and its SHA-256 computed and recorded in
  `bootstrap/hermes-installer.sha256` on 2026-08-20, so `docker/Dockerfile`
  can verify it before ever executing it.
- A prior work pass left Milestone 1 partially implemented and
  uncommitted (recorded in `.hermes-work-status`: "Milestone 1 partial;
  Claude limit ...; uncommitted defects require repair"). This TASK.md and
  the repair pass that follows close that gap: they do not restart
  Milestone 1 from scratch, they finish and correct what was already
  written on disk (`bootstrap/install.sh`, `docker/Dockerfile`,
  `docker/docker-compose.yml`, `docker/entrypoint.sh`,
  `systemd/hermes.service`, and the first four `tests/bootstrap/*.sh`
  files all predate this TASK.md and were preserved, not rewritten, except
  where a concrete defect was found — see Unknowns/defects below).

## Constraints

- No Milestone 2+ functionality: no `hermes-connect`/`hermes-doctor`, no
  credential handling, no Hermes/Runner/Monitor/Verifier runtime code, no
  Discord integration (`CLAUDE.md` "Milestone discipline").
- No forbidden components from `BUILD_DIRECTIVE.md` §10 (no SQLite,
  Redis, message broker, JobManager, lease system, DAG engine, second
  orchestrator, etc.).
- Exactly one systemd unit; exactly one Docker Compose service/container.
  Docker's own restart policy must not overlap with systemd's — only one
  supervisor per failure mode.
- Every installed/rendered file must carry a provenance comment back to
  its source in this repository (`BUILD_DIRECTIVE.md` §7).
- The image must remain secret-free by construction (`--skip-setup`,
  nothing under `config/*.env` baked into a layer).
- Package installation must fail closed: an unsupported host, a missing
  `apt-get`, a non-root invocation, or a package that isn't actually
  detected after "successful" install must abort with a nonzero exit —
  never silently report success.
- The Hermes installer must be downloaded to a file, its SHA-256 verified
  against the repository-recorded value, and only then executed — never
  curl-piped directly to a shell.
- `bootstrap/install.sh` must be idempotent (safe to re-run, no
  duplication, no unnecessary rewrites) and support `--dry-run` (make zero
  filesystem/package/systemd changes).
- Data-root directories and rendered files that will hold or lead to
  credentials must be `0700`/`0600` from first bootstrap onward
  (`SECURITY.md` §3).
- `install.sh` must never call `systemctl enable` or `systemctl start` —
  activation is Milestone 2+ territory once credentials exist.
- This authoring pass does not commit, push, start/enable services, run
  Docker builds, or provision a real EC2 instance — static and
  in-temp-directory dynamic checks only (per the operating instructions
  for this change; git/deploy actions remain with the operator/orchestrator
  per `CLAUDE.md` "Git discipline").

## Acceptance Criteria

- `bash tests/bootstrap/run.sh` runs every Milestone 1 test and a
  `bash -n` syntax check over every Milestone 1 shell script, and exits 0.
- Every claim above is backed by an executable, deterministic test in
  `tests/bootstrap/`: dry-run makes no changes, two runs converge
  (idempotency, including the systemd unit — not just the rendered
  config), every written file/dir carries correct provenance and
  permissions, the Compose file declares exactly one service with
  `restart: "no"`, the systemd unit is the only one and has a bounded
  restart policy, `install.sh` never enables/starts the unit, the
  Dockerfile parses both pins from the `COPY`'d files (never duplicating
  them as a hardcoded `ARG` default), builds the installer URL from the
  pinned commit, verifies the checksum strictly before executing the
  installer, passes the same pinned commit to `--commit`, pins the base
  image by digest, the package stages fail closed off apt/root, and no
  Milestone 2+ file exists yet.
- `bash tests/check_milestone0.sh` still exits 0 after Milestone 1 lands —
  updated to be milestone-aware so it remains a real regression check
  rather than a one-time Milestone-0 assertion that Milestone 1 would
  trivially fail.
- `ARCHITECTURE.md`, `README.md`, `MILESTONES.md`, `DEFINITION_OF_DONE.md`,
  `CHANGELOG.md`, and the `bootstrap/`/`docker/`/`systemd/` `README.md`
  files accurately describe what Milestone 1 actually contains, without
  asserting an independent-verifier `PASS` this authoring pass did not
  obtain (see `evidence/milestone-1/TEST_EVIDENCE.md` for exactly what
  evidence does and does not exist).
- `git diff --check` reports no whitespace errors in the changed files.

## Relevant Files

- `bootstrap/install.sh`, `bootstrap/hermes-commit.pin`,
  `bootstrap/hermes-installer.sha256`, `bootstrap/README.md`
- `docker/Dockerfile`, `docker/docker-compose.yml`, `docker/entrypoint.sh`,
  `docker/README.md`
- `systemd/hermes.service`, `systemd/README.md`
- `tests/bootstrap/*.sh` (test suite + `run.sh` runner)
- `tests/check_milestone0.sh` (updated to be milestone-aware)
- `ARCHITECTURE.md`, `README.md`, `MILESTONES.md`, `DEFINITION_OF_DONE.md`,
  `CHANGELOG.md`

## Unknowns / defects found and resolved during this pass

- **Idempotency defect**: `install.sh`'s systemd-unit provenance header
  embedded the wall-clock render timestamp, so a byte-for-byte compare
  against the already-installed unit always differed and the unit (and a
  `daemon-reload`) was rewritten on every re-run, even with zero
  substantive change. Fixed by comparing with that one volatile clause
  stripped; confirmed by `tests/bootstrap/test_idempotency.sh`, which was
  failing before the fix and passes after.
- **`tests/check_milestone0.sh` staleness**: its repository-tree and
  skeleton-directory checks were written for a Milestone-0-only tree and
  would fail permanently once Milestone 1 added real files to
  `bootstrap/`, `docker/`, `systemd/`. Resolved by making both checks
  milestone-aware (a `CURRENT_MILESTONE` constant, cross-checked against
  `MILESTONES.md`'s own status table so it can't silently drift) rather
  than weakening what they actually verify.
- No independent (fresh-agent, separate-context) verification pass has
  been run against this Milestone 1 implementation, unlike Milestone 0's
  Pass 1/2/3 history in `evidence/milestone-0/VERIFICATION.md`. This is
  recorded explicitly, not implied, in
  `evidence/milestone-1/TEST_EVIDENCE.md`, `MILESTONES.md`, and `README.md`.

## Execution Mode

Sequential, single authoring context. Not decomposed into parallel workers
— the bootstrap script, Dockerfile, compose file, systemd unit, and their
tests are tightly coupled (each test exercises the same `install.sh`
across multiple stages), so splitting this across independent workers
would not have improved correctness or speed (`WORK_PROTOCOL.md` §2-§3).
