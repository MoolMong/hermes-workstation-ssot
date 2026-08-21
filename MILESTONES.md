# Milestones

Restated from `BUILD_DIRECTIVE.md` §12, with status. Work proceeds
milestone by milestone; for each milestone: implement, test, independently
verify, commit, record evidence, then continue (`BUILD_DIRECTIVE.md` §15).
Milestone 3 and later are not implemented yet. Milestone 2 is complete
within its documented static/local evidence boundary; Fresh EC2 runtime
validation is still outstanding (see the detailed scope below and
`evidence/milestone-2/`).

| # | Milestone | Status | Summary |
|---|---|---|---|
| 0 | Repository and design | **Complete** | Repository, README, architecture, work protocol, directory layout, threat/secret model, Definition of Done. No runtime framework. |
| 1 | Clean bootstrap | **Complete** | Reproducible base bootstrap implemented and independently verified within the documented local/static boundary. Fresh EC2/runtime validation remains BLOCKED. |
| 2 | Connection UX | **Complete** | `hermes-connect` configures and validates Discord/OpenAI/Claude/GitHub. `hermes-doctor` provides read-only diagnostics. Deterministic and independent semantic gates pass; Fresh EC2 runtime validation not yet performed. |
| 3 | Basic work path | Planned | Discord → Hermes → Runner → Claude → result. One worker only. |
| 4 | Verifier | Planned | Worker result → deterministic checks → semantic verification → PASS/FAIL. `COMPLETED` is impossible without PASS. |
| 5 | Monitor/recovery | Planned | System health + task health using one Monitor implementation where practical. Verify real failure scenarios. |
| 6 | Parallel execution | Planned | Only after the single-worker lifecycle is reliable: up to 3 independent workers. |
| 7 | Image readiness | Planned | Sanitize and validate that the installation can be safely converted to a reusable AMI. |

## Milestone 0 — detailed scope (complete)

Status: **Complete**. Deterministic checks (`tests/check_milestone0.sh`)
pass; see `CHANGELOG.md` for the current check count and result.
Independent verification is recorded chronologically in
`evidence/milestone-0/VERIFICATION.md`: Pass 1 (content) returned PASS,
Pass 2 (final-state) returned FAIL because status/evidence claims in this
repository were not traceable to a durable review artifact, and Pass 3
(fresh, independent, final-state review of the repaired repository)
returned PASS with that defect confirmed fixed. See
`DEFINITION_OF_DONE.md` for the checked-off Milestone 0 Definition of
Done. Milestone 1 (Clean bootstrap) has since started — see the detailed
scope below.

In scope:

- `README.md`, `ARCHITECTURE.md`, `WORK_PROTOCOL.md`, `SECURITY.md`,
  `MILESTONES.md`, `DEFINITION_OF_DONE.md`, `DEVIATIONS.md`,
  `CHANGELOG.md`, `CLAUDE.md`, `.gitignore`.
- Proposed repository tree (in `ARCHITECTURE.md`).
- Threat/secret model and full credential-bearing-location inventory (in
  `SECURITY.md`).
- Minimal, traceable directory skeleton: `bootstrap/`, `docker/`,
  `systemd/`, `scripts/` each contain only a `README.md` placeholder
  stating what lands there and in which milestone — no functional code.
- `config/*.example` files with placeholder (non-secret) values only.
- `tests/check_milestone0.sh` — deterministic checks for this milestone
  (document presence, forbidden-scope declaration, secret placeholders,
  tree consistency).

Explicitly out of scope for Milestone 0 (deferred to the milestone noted):

- any install/bootstrap logic (M1)
- `hermes-connect` / `hermes-doctor` (M2)
- Hermes, Runner, Monitor, Verifier implementations (M3–M5)
- Discord bot, filesystem task-state machine (M3)
- parallel execution (M6)
- AMI sanitization/validation logic (M7)
- any systemd unit, Dockerfile, or docker-compose file with real content
  (M1+)

## Milestone 1 — detailed scope (complete)

Status: **Complete.** Deterministic checks
(`bash tests/bootstrap/run.sh`, `bash tests/check_milestone0.sh`) pass;
see `evidence/milestone-1/TEST_EVIDENCE.md` for the recorded run output
and `evidence/milestone-1/TASK.md` for the Context/Constraints/Acceptance
Criteria this milestone worked against. A fresh independent read-only
Claude Code verifier returned PASS; the chronological semantic-review
record is `evidence/milestone-1/VERIFICATION.md`. Fresh EC2 provisioning and
Docker build/runtime validation were not authorized/available and remain
explicitly BLOCKED; completion here means the M1 repository artifact passed
its implemented deterministic and independent semantic gates, not that an
unperformed fresh-EC2 test was fabricated.

In scope (implemented):

- `bootstrap/install.sh` — idempotent host bootstrap: OS prerequisites,
  Docker engine + compose command (fail-closed, Ubuntu/Debian `apt`
  only, with a deterministic package-set fallback and post-install
  verification), the secret-free `/opt/hermes-data` tree (`0700`
  dirs/`0600` files), non-secret rendered config, and the single
  `systemd/hermes.service` unit (installed, `daemon-reload`d, but never
  enabled or started). Supports `--dry-run`; every written file carries a
  provenance header.
- `bootstrap/hermes-commit.pin`, `bootstrap/hermes-installer.sha256` —
  the pinned Hermes Agent commit and the installer script's SHA-256 at
  that commit, parsed directly by `docker/Dockerfile` (no duplicated
  hardcoded defaults).
- `docker/Dockerfile` — pinned base image (digest, not floating tag);
  downloads the installer from its immutable, commit-scoped
  `raw.githubusercontent.com` URL; verifies its SHA-256 before executing
  it; passes the same pinned commit to `--commit`; builds with
  `--skip-setup` so the image stays credential-free.
- `docker/docker-compose.yml` — exactly one service (`hermes`, container
  name `hermes`, `command: ["hermes", "gateway"]`, `restart: "no"` —
  systemd is the sole supervisor).
- `docker/entrypoint.sh` — seeds the bind-mounted data volume from
  credential-free build-time scaffolding, first run only.
- `systemd/hermes.service` — the only systemd unit; bounded restart
  policy (`StartLimitIntervalSec`/`StartLimitBurst`/
  `Restart=on-failure`/`RestartSec`).
- `tests/bootstrap/` — `run.sh` (syntax checks + full suite runner) plus
  test scripts covering dry-run, idempotency (including the systemd unit,
  not just rendered config), file provenance, rendered-config content,
  permissions, Compose single-service shape, systemd bounded supervision
  and no-enable/no-start, Dockerfile pin/checksum/URL/ordering
  guarantees, package-stage fail-closed behavior, and absence of any
  Milestone 2+ file.
- `tests/check_milestone0.sh` updated to be milestone-aware (see its own
  comments) so it remains a real regression check rather than a one-time
  Milestone-0 assertion that Milestone 1 would trivially fail.

Explicitly out of scope for Milestone 1 (confirmed absent, deferred to the
milestone noted):

- `hermes-connect` / `hermes-doctor`, any credential handling (M2)
- Hermes, Runner, Monitor, Verifier implementations (M3–M5)
- Discord bot, filesystem task-state machine (M3)
- a second systemd unit, parallel execution (M5–M6)
- AMI sanitization/validation logic (M7)
- enabling/starting the installed systemd unit (M2+, once credentials
  exist)

## Milestone 2 — detailed scope (complete)

Status: **Complete within the documented static/local evidence boundary.** Deterministic
checks (`bash tests/connection/run.sh`, `bash tests/bootstrap/run.sh`,
`bash tests/check_milestone0.sh`) pass; see
`evidence/milestone-2/TEST_EVIDENCE.md` for the recorded run output and
`evidence/milestone-2/TASK.md` for the Context/Constraints/Acceptance
Criteria this milestone worked against. A fresh, independent read-only
Claude Code verifier returned explicit `VERDICT: PASS`; the chronological
record is `evidence/milestone-2/VERIFICATION.md`. Fresh EC2,
Docker/Compose, and systemd runtime validation for the combined Milestone
1 + Milestone 2 stack were not authorized/available and remain explicitly
`NOT RUN`/`BLOCKED`; the plan for that validation, including the required
AWS-approval STOP, is `docs/FRESH_EC2_VALIDATION.md`.

In scope (implemented):

- `bootstrap/connect.sh` (`hermes-connect`) — interactive connection
  command for Discord, OpenAI/Codex, Claude Code, and GitHub. Detects
  already-healthy integrations and skips them unless `--reconnect` is
  given; supports focused reconfiguration (`--discord`, `--openai`,
  `--claude`, `--github`); validates every integration immediately after
  configuration; never echoes or logs a secret value.
- `bootstrap/doctor.sh` (`hermes-doctor`) — read-only diagnostics (Docker,
  Hermes service/gateway, each integration, required directories/
  permissions, systemd unit validity, disk space, installed SSOT
  version/commit, and image-readiness). No `--fix` flag by design; never
  mutates anything, even when it finds a problem.
- `bootstrap/connect-common.sh` — shared helpers for both commands,
  including `credential_paths()`, the single source of truth for every
  credential-bearing path (cross-checked against `SECURITY.md` §3 by
  `tests/connection/test_image_readiness.sh`).
- `docs/FRESH_EC2_VALIDATION.md` — the Fresh EC2 end-to-end validation
  plan required by `MILESTONE2_DIRECTIVE.md` §11, with an explicit STOP
  before any AWS resource is created.
- `tests/connection/` — `run.sh` (syntax checks + full suite runner) plus
  `lib_fakebin.sh` and seven `test_*.sh` scripts covering Claude, Discord,
  read-only `hermes-doctor` behavior, GitHub, idempotency/already-
  configured detection, image-readiness credential detection, and
  OpenAI/Codex — all against fake/mocked external tools, never a real
  Discord/OpenAI/Anthropic/GitHub backend.
- `tests/bootstrap/test_no_m3_scope.sh` — supersedes the Milestone-1-era
  `test_no_m2_scope.sh`; asserts no Milestone 3+ path
  (`scripts/runner`/`monitor`/`verifier`, a second systemd unit) exists
  yet, while confirming Milestone 2's own paths now legitimately do.
- `evidence/milestone-2/` — `TASK.md`, `TEST_EVIDENCE.md`,
  `VERIFICATION.md`.
- `tests/check_milestone0.sh` updated (`CURRENT_MILESTONE=2`,
  `MILESTONES.md` status table) to keep it a real regression check at
  Milestone 2.

Explicitly out of scope for Milestone 2 (confirmed absent, deferred to the
milestone noted):

- Hermes, Runner, Monitor, Verifier implementations (M3–M5)
- Discord bot task-execution/state-machine logic, `scripts/runner` (M3)
- a second systemd unit, parallel execution (M5–M6)
- AMI sanitization/validation logic (M7)
- enabling/starting the Milestone 1 systemd unit against a fresh EC2
  instance, and any real Discord/OpenAI/Claude/GitHub account connection
  (deferred to the approved Fresh EC2 validation in
  `docs/FRESH_EC2_VALIDATION.md`)

### First Fresh EC2 validation attempt (2026-08-21) — BLOCKED, defect fixed

The first authorized Fresh EC2 run against this milestone's plan happened
at HEAD `153a0f45c72b0d848d4b082230e7c3529606c046`. It reached bootstrap
(pass, idempotent), `docker compose config`, and a read-only
pre-connection `hermes-doctor` pass, then stopped: `docker compose build
--no-cache` failed twice on a transient HTTP 429 from
`raw.githubusercontent.com` while downloading the pinned Hermes Agent
installer, which had no retry/backoff. Everything from the image build
onward (real account connection, service start, Discord round-trip,
restart/reboot) was **NOT RUN**, not FAIL. The instance and all AWS
resources for that run were deleted afterward. Full itemized results:
`evidence/milestone-2-fresh-ec2/TEST_EVIDENCE.md`. The causing defect is
now fixed (`docker/Dockerfile`'s installer download now carries a bounded
retry/backoff policy, proven by `tests/bootstrap/test_installer_retry.sh`)
but **Fresh EC2 validation itself remains incomplete** — this milestone's
status above is unchanged by this attempt, and a fresh, real re-run is
still required before it can be claimed PASS.
`evidence/milestone-2-fresh-ec2/VERIFICATION.md` is intentionally
PENDING.

## Sequencing rule

Do not begin implementation of a later milestone before the current one's
Definition of Done (see `DEFINITION_OF_DONE.md`) is met and evidence is
recorded. Do not add infrastructure ahead of an observed failure mode —
if a milestone appears to need something outside its listed scope, stop
and state (1) the concrete failure mode, (2) why the minimal design
cannot solve it, (3) the smallest additional component required
(`BUILD_DIRECTIVE.md` §15).
