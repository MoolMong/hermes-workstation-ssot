# Definition of Done

## Whole-project Definition of Done (`BUILD_DIRECTIVE.md` §14)

The repository/platform is not complete until all of the following are
true. None of these are true yet — they are the finish line for the whole
directive, not for Milestone 0:

- a fresh EC2 can be built from the SSOT repository,
- no undocumented manual setup is required,
- `hermes-connect` connects the required user integrations,
- `hermes-doctor` diagnoses the environment,
- Discord never silently accepts long-running work,
- Runner-owned tasks have visible state,
- Monitor distinguishes system health from task health,
- service failures are recovered within bounded policy,
- unrecoverable failures are reported,
- Verifier is a hard completion gate,
- a worker cannot self-declare `COMPLETED`,
- all secrets are outside the distributable image,
- image-readiness validation passes,
- documentation is sufficient for another technically competent user to
  deploy it,
- the implementation remains materially simpler than the old Factory
  architecture.

## Milestone 0 Definition of Done (this change)

Milestone 0 is done when all of the following are true:

- [x] `README.md`, `ARCHITECTURE.md`, `WORK_PROTOCOL.md`, `SECURITY.md`,
      `MILESTONES.md`, `DEFINITION_OF_DONE.md`, `DEVIATIONS.md`,
      `CHANGELOG.md`, `CLAUDE.md`, and `.gitignore` all exist and are
      non-empty.
- [x] `SECURITY.md` contains an explicit threat model, an explicit secret
      model, and an explicit table of every credential-bearing location
      planned for this implementation.
- [x] `ARCHITECTURE.md` documents the proposed repository tree, and that
      tree matches the actual repository contents at Milestone 0 (files
      marked with a future milestone are allowed to not exist yet).
- [x] The forbidden-scope list from `BUILD_DIRECTIVE.md` §10 is
      explicitly declared in this repository (`ARCHITECTURE.md` §5) and,
      by inspection, none of the listed items are present.
- [x] `DEVIATIONS.md` exists and states the actual deviation count
      (expected: none).
- [x] `config/*.example` files exist for Discord, OpenAI, Claude, and
      GitHub, contain only placeholder values, and are the only
      config-shaped files tracked by Git (`.gitignore` excludes their
      real, non-`.example` counterparts).
- [x] A minimal, traceable directory skeleton exists for `bootstrap/`,
      `docker/`, `systemd/`, and `scripts/`, each containing only a
      `README.md` that states what will be added and in which milestone —
      no functional code for Milestones 1–7.
- [x] `tests/check_milestone0.sh` exists, runs without external
      dependencies beyond bash/coreutils, and deterministically checks
      items above.
- [x] Running `tests/check_milestone0.sh` exits 0, and its output is
      recorded as evidence in `CHANGELOG.md`.
- [x] No commit/push/PR/deploy has been performed by the Claude authoring
      worker — Git operations remain with the orchestrator per the
      current operating instructions. The orchestrator owns the
      Milestone 0 commit (and any subsequent push/PR). *(Not a
      repository-content item; recorded here for traceability of the
      constraint under which Milestone 0 was produced.)*
- [x] A durable, chronological verification-evidence artifact exists at
      `evidence/milestone-0/VERIFICATION.md`, and every status/evidence
      claim about independent verification made in this document,
      `README.md`, `MILESTONES.md`, and `CHANGELOG.md` is traceable to
      it rather than self-asserted.

The repository-content items above are satisfied, and Milestone 0 is
**complete**: `tests/check_milestone0.sh` passes deterministically (see
`CHANGELOG.md` for the current check count and result), and
`evidence/milestone-0/VERIFICATION.md` records that the most recent
chronological independent-verifier pass (Pass 3, final-state review of
the repaired repository) returned a semantic `PASS`. Pass 2 had returned
a semantic `FAIL` — the repository claimed independent-verifier PASS in
four documents without a durable review artifact to prove it — and Pass 3
confirms that evidence-integrity defect is fixed. Milestone 1 may now
begin.

Milestone 0 does **not** require: any bootstrap script logic, any
connection/validation logic, any Hermes/Runner/Monitor/Verifier code, any
Discord integration, or any AMI sanitization logic. Introducing any of
those now would itself be a Milestone-0 Definition-of-Done violation
(scope creep ahead of the milestone that owns it).

## Milestone 1 Definition of Done (this change)

Milestone 1 is done when all of the following are true:

- [x] `bootstrap/install.sh` idempotently bootstraps a host: OS
      prerequisites, Docker engine + compose, the secret-free
      `/opt/hermes-data` tree, non-secret rendered config, and the single
      `systemd/hermes.service` unit — installed and `daemon-reload`d, but
      never enabled or started.
- [x] `--dry-run` makes zero filesystem/package/systemd changes.
- [x] Package installation stages fail closed on an unsupported host, a
      missing `apt-get`, or a non-root invocation — never silently report
      success without verifying the resulting state.
- [x] Every file `install.sh` writes or renders carries a provenance
      comment tracing it back to this repository
      (`BUILD_DIRECTIVE.md` §7).
- [x] Data-root directories are `0700` and credential-adjacent rendered
      files are `0600`, from the first bootstrap onward.
- [x] `docker/Dockerfile` builds the single Hermes Agent image from a
      digest-pinned base image; downloads the installer from its
      immutable, commit-scoped `raw.githubusercontent.com` URL; verifies
      the installer's SHA-256 (parsed from `bootstrap/hermes-installer.sha256`,
      never duplicated as a hardcoded `ARG` default) strictly before
      executing it; passes the same pinned commit
      (`bootstrap/hermes-commit.pin`) to `--commit`; and builds with
      `--skip-setup` so the image stays credential-free.
- [x] `docker/docker-compose.yml` declares exactly one service/container
      (`hermes`, running `hermes gateway`) with `restart: "no"` — Docker
      does not supervise; `systemd/hermes.service` does, with a bounded
      restart policy (`StartLimitIntervalSec`/`StartLimitBurst`/
      `Restart=on-failure`/`RestartSec`), so the two never overlap into a
      double restart loop for one failure.
- [x] Exactly one systemd unit exists in this repository; there is no
      `hermes-gateway.service` or any second unit.
- [x] `bash tests/bootstrap/run.sh` — a `bash -n` syntax check over every
      Milestone 1 shell script, plus the full Milestone 1 test suite
      (dry-run, idempotency including the systemd unit, provenance,
      rendered-config content, permissions, Compose single-service shape,
      systemd bounded supervision and no-enable/no-start, Dockerfile
      pin/checksum/URL/ordering guarantees, package-stage fail-closed
      behavior, and absence of any Milestone 2+ file) — exits 0.
- [x] `bash tests/check_milestone0.sh` exits 0, updated to be
      milestone-aware so it continues to check what it always checked
      (documents, secret model, forbidden-scope, no undeclared/scope-creep
      files) without permanently expecting a Milestone-0-only tree.
- [x] No Milestone 2+ functionality exists: no `hermes-connect`/
      `hermes-doctor`, no credential handling, no Hermes/Runner/Monitor/
      Verifier code, no Discord integration, no second systemd unit.
- [x] `evidence/milestone-1/TASK.md` records the Context/Constraints/
      Acceptance Criteria this milestone worked against, and
      `evidence/milestone-1/TEST_EVIDENCE.md` records the actual
      deterministic test run this Definition of Done relies on.
- [x] A fresh independent read-only Claude Code verifier checked the final
      Milestone 1 implementation against `BUILD_DIRECTIVE.md`, reran the
      deterministic gates, inspected upstream installer compatibility and
      immutable pins, and returned PASS. The chronological record is
      `evidence/milestone-1/VERIFICATION.md`; it also preserves the explicit
      BLOCKED status of fresh EC2 and Docker runtime validation.
- [x] No commit/push/PR/deploy has been performed by the Claude authoring
      worker for this change — Git operations remain with the operator/
      orchestrator per `CLAUDE.md` "Git discipline".

The implementation-content items above are satisfied and recorded in
`evidence/milestone-1/TEST_EVIDENCE.md`; independent semantic verification
is recorded in `evidence/milestone-1/VERIFICATION.md`. Milestone 1 is
**complete** within the explicitly documented evidence boundary. Fresh EC2
and Docker runtime validation remain BLOCKED and are not claimed as PASS.
Milestone 2 is next but is not implemented by this change.
