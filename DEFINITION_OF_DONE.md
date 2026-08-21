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
Milestone 2 has since been implemented — see the section below.

## Milestone 2 Definition of Done (this change)

Per `MILESTONE2_DIRECTIVE.md` §10 ("Milestone 2 completion gate"),
Milestone 2 is **complete** within the documented static/local evidence
boundary because every §10 implementation, deterministic, semantic, and
repository-integration gate is satisfied. Fresh EC2/runtime validation is
a separately approval-gated follow-up and is not claimed as PASS.

- [x] `bootstrap/connect.sh` (`hermes-connect`) implements interactive
      setup and validation for Discord, OpenAI/Codex, Claude Code, and
      GitHub, detects already-healthy integrations, supports focused
      reconfiguration (`--discord`/`--openai`/`--claude`/`--github`,
      `--reconnect`), and never echoes or logs a secret value.
- [x] `bootstrap/doctor.sh` (`hermes-doctor`) provides read-only
      diagnostics (Docker, Hermes service/gateway, each integration,
      required directories/permissions, systemd unit validity, disk
      space, installed SSOT version/commit, image-readiness) and never
      mutates anything — no `--fix` flag.
- [x] `bootstrap/connect-common.sh` provides shared helpers, including
      `credential_paths()` as the single source of truth for every
      credential-bearing path, cross-checked against `SECURITY.md` §3.
- [x] `docs/FRESH_EC2_VALIDATION.md` records the Fresh EC2 end-to-end
      validation plan required by `MILESTONE2_DIRECTIVE.md` §11, with an
      explicit STOP before any AWS resource is created.
- [x] `tests/connection/run.sh` — a `bash -n` syntax check over every
      Milestone 2 shell script, plus the full `tests/connection/test_*.sh`
      suite (Claude, Discord, read-only `hermes-doctor` behavior, GitHub,
      idempotency/already-configured detection, image-readiness
      credential detection, OpenAI/Codex) — exits 0, against fake/mocked
      external tools only; never a real Discord/OpenAI/Anthropic/GitHub
      backend.
- [x] `bash tests/bootstrap/run.sh` and `bash tests/check_milestone0.sh`
      (both updated to be current at Milestone 2 — `CURRENT_MILESTONE=2`,
      `MILESTONES.md` status table, `tests/bootstrap/test_no_m3_scope.sh`
      superseding the Milestone-1-era `test_no_m2_scope.sh`) continue to
      exit 0.
- [x] The Milestone 1 gateway command defect (`docker-compose.yml`
      previously running `hermes gateway` rather than the correct
      `hermes gateway run`) is corrected and re-verified by
      `tests/bootstrap/test_docker_compose.sh`.
- [x] No Milestone 3+ functionality exists: no Hermes/Runner/Monitor/
      Verifier code, no Discord bot task-execution logic, no second
      systemd unit, no parallel execution, no AMI sanitization logic.
- [x] No forbidden component (`CLAUDE.md` "Forbidden components") was
      added; no architectural deviation was required — see
      `DEVIATIONS.md`.
- [x] `evidence/milestone-2/TASK.md` records the Context/Constraints/
      Acceptance Criteria this milestone worked against, and
      `evidence/milestone-2/TEST_EVIDENCE.md` records the actual
      deterministic test run this Definition of Done relies on.
- [x] **A fresh independent read-only Claude Code verifier pass against
      the final Milestone 2 diff, recorded chronologically in
      `evidence/milestone-2/VERIFICATION.md`.** Status: **PASS** — Pass 3
      reran 57/57 M0, 22/22 M1, and 18/18 M2 checks and returned explicit
      `VERDICT: PASS` after semantic review.
- [ ] **Fresh EC2 provisioning, Docker/Compose build+run, and systemd
      enable/start validation for the combined Milestone 1 + Milestone 2
      stack**, per the plan in `docs/FRESH_EC2_VALIDATION.md`. Status:
      **NOT COMPLETE** — a first real attempt was made on 2026-08-21
      (`evidence/milestone-2-fresh-ec2/TEST_EVIDENCE.md`) and reached
      bootstrap/idempotency/`docker compose config`/pre-connection
      `hermes-doctor` PASS, then BLOCKED at `docker compose build
      --no-cache` (transient HTTP 429 downloading the pinned installer,
      no retry/backoff). Everything from the image build onward was NOT
      RUN. The causing defect is fixed
      (`tests/bootstrap/test_installer_retry.sh`). A second authorized
      attempt on 2026-08-21, at baseline
      `000f06b57d06a495236cad5682ffc0356bcc70de`, confirmed that retry fix
      live (three real HTTP 429s then success, checksum OK) and again
      passed SSH/provenance diagnostic bundle transfer, bootstrap twice
      with stable hashes, and `docker compose config`, before the Docker
      build failed **exit 127**: the pinned installer's `tar xf`/`tar
      xzf` archive extraction had no `tar` binary, since
      `docker/Dockerfile`'s prerequisite stage installed `xz-utils`
      without `tar`. Account/service/Discord/restart/reboot were again
      NOT RUN; instance/security group/encrypted `DeleteOnTermination`
      EBS/temporary SSH key were cleaned up. The smallest repair — adding
      `tar` to that prerequisite package list plus
      `tests/bootstrap/test_installer_extract_deps.sh` — is applied
      (deterministic: `tests/check_milestone0.sh` 57/57,
      `tests/bootstrap/run.sh` 26/26, `tests/connection/run.sh` 18/18);
      a fresh independent verifier pass over this repair is still
      pending, so this item remains unchecked and a fresh real re-run is
      still required. Not fabricated as PASS.
- [x] The Claude authoring/verifying workers performed no commit, push,
      PR, deploy, credential connection, Docker/systemd runtime action, or
      AWS action. Repository integration remains with the orchestrator per
      `CLAUDE.md` "Git discipline".

Milestone 2 is **complete** within its explicitly documented evidence
boundary. The unchecked Fresh EC2 item is READY/NOT RUN and requires
explicit AWS approval; it is not silently converted into a runtime PASS.
Milestone 3 remains planned and was not started by this change.
