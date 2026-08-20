# Architecture

This document restates the non-negotiable architecture from
[`BUILD_DIRECTIVE.md`](BUILD_DIRECTIVE.md) §1–§10 in repository-local form,
and defines the proposed repository tree. `BUILD_DIRECTIVE.md` is
authoritative; this document must not drift from it. Any conflict is a bug
in this document, not a license to reinterpret the directive.

## 1. Mission

Single Source of Truth (SSOT) for a reproducible, shareable personal AI
workstation on AWS EC2. A fresh EC2 instance must be provisionable from
this repository, connect a user's own accounts via an interactive
connection command, operate through Discord, execute coding tasks through
Claude Code, supervise long-running work, verify results independently,
recover from common service failures, and remain understandable to a
single operator.

This is a clean redesign. It does not refactor or extend the existing AI
Project Factory, and does not copy its architecture. The existing server
may only be inspected as a reference for proven implementation details
(see §9 below).

## 2. Data flow

```text
Discord
  ↓
Hermes / Orchestrator
  ↓
Context → Decompose → Parallelize only if useful
  ↓
Runner → Claude Code worker(s)
  ↓
Monitor
  ↓
Verifier
  ↓
Integrate / Report
  ↓
Git / GitHub
```

Optimization order: simplicity, reproducibility, visible task state, safe
recovery, independent verification, secret-free redistribution.

## 3. Logical components (runtime contains only these)

### Hermes (orchestrator)
Discord interaction, intent interpretation, Context construction,
Decompose, sequential-vs-parallel decision, Integrate, final user report.
Hermes is the orchestrator, not the long-running worker.

### Runner
Creates a task workspace, creates `TASK.md`, launches Claude Code in the
correct repository/worktree, records PID/start time, captures
stdout/stderr, updates task state. Never claims semantic completion by
itself.

### Monitor
One implementation, two logical checks:

- **system_check** — Docker, Hermes container, Hermes Gateway, Discord
  connectivity. Recovers only the failed system layer when safe.
- **task_check** — Runner-owned work: worker PID/process identity, task
  state, last progress timestamp, `worker.log` modification time,
  workspace/git-diff activity. Does not restart a healthy worker merely
  because no Discord message was sent.

### Verifier
The mandatory completion gate, not merely another AI agent. Combines
deterministic checks (process exit status, actual git diff/changed files,
test results, build results, lint results, forbidden-path checks) with
semantic AI review where necessary (Acceptance Criteria satisfaction,
missing requirements, regression risk, obvious implementation defects). A
Worker saying "done" is never sufficient. Only the Verifier can return
PASS. Task status may become `COMPLETED` only after Verifier PASS.

### Git / GitHub
GitHub is the remote source/code collaboration layer. The repository
itself is the SSOT for workstation deployment.

None of Hermes/Runner/Monitor/Verifier are implemented yet — they begin at
Milestone 3 (Runner) and continue through Milestone 5 (Monitor). Milestone
1 (current) implements only the host/image bootstrap described in §6
below, not any of these logical components.

## 4. Task state (design, not yet implemented)

No SQLite, Redis, queues, leases, JobManager, or distributed state machine
in v0.1. Filesystem-backed task state only:

```text
/opt/hermes-data/
├── auth/
├── config/
├── workspaces/
├── tasks/
│   └── TASK-<id>/
│       ├── TASK.md
│       ├── state.json
│       ├── worker.log
│       └── REVIEW.md
├── logs/
└── backup/
```

Minimum states: `RECEIVED`, `PLANNING`, `RUNNING`, `VERIFYING`,
`COMPLETED`, `FAILED`, `STALLED`, `NEEDS_USER`.

Minimum `state.json` fields: `task_id`, `status`, `phase`, `pid`,
`process_start_time`, `started_at`, `updated_at`, `retry_count`,
`workspace`. Atomic file writes required for state updates.

`/opt/hermes-data/` is host-local runtime state, not part of this
repository, and holds credentials — see [`SECURITY.md`](SECURITY.md).

## 5. Explicitly forbidden in v0.1

Per `BUILD_DIRECTIVE.md` §10, none of the following exist in this
repository, and none may be added without first stopping to state (1) the
concrete failure mode, (2) why the minimal design cannot solve it, and (3)
the smallest additional component required:

- AI Project Factory (or any recreation of it)
- separate HTTP orchestrator service
- second orchestrator runtime
- SQLite task database
- Redis
- message broker
- JobManager abstraction
- lease system
- daemon-thread long-running jobs inside Hermes
- general DAG engine
- 13-question specification interview
- event outbox/delivery subsystem
- multiple overlapping watchdog daemons
- Kubernetes
- unnecessary microservices

One understandable process or script is preferred over several services.
Complexity must be justified by an observed failure mode, not anticipated
elegance. As of Milestone 1, **none of the above are present, and none are
planned** — see [`DEVIATIONS.md`](DEVIATIONS.md).

## 6. Proposed repository tree

This is the target tree across all milestones (`BUILD_DIRECTIVE.md` §7,
"You may improve names/layout if the result is simpler" — this layout
follows the directive's suggested layout as-is, no simplification needed).
Paths marked `(M0)` exist today; all others are placeholders today and
will be filled in during the milestone noted.

```text
README.md                              (M0)
ARCHITECTURE.md                        (M0)
WORK_PROTOCOL.md                       (M0)
SECURITY.md                            (M0)
CHANGELOG.md                           (M0)
MILESTONES.md                          (M0)
DEFINITION_OF_DONE.md                  (M0)
DEVIATIONS.md                          (M0)
CLAUDE.md                              (M0)
.gitignore                             (M0)

bootstrap/
  README.md                            (M0 — placeholder)
  install.sh                           (M1)
  hermes-commit.pin                    (M1)
  hermes-installer.sha256              (M1)
  connect.sh                           (M2)
  doctor.sh                            (M2)

config/
  discord.env.example                  (M0 — placeholder values only)
  openai.env.example                   (M0 — placeholder values only)
  claude.env.example                   (M0 — placeholder values only)
  github.env.example                   (M0 — placeholder values only)
  hermes.config.example.yaml           (M0 — placeholder values only)

systemd/
  README.md                            (M0 — placeholder)
  hermes.service                       (M1 — the only systemd unit)
  hermes-monitor.service               (M5)

docker/
  README.md                            (M0 — placeholder)
  Dockerfile                           (M1)
  docker-compose.yml                   (M1)
  entrypoint.sh                        (M1)

scripts/
  README.md                            (M0 — placeholder)
  runner                               (M3)
  monitor                              (M5)
  verifier                             (M4)

evidence/
  milestone-0/VERIFICATION.md          (M0 — durable verifier record)
  milestone-1/TASK.md                  (M1 — execution specification)
  milestone-1/TEST_EVIDENCE.md         (M1 — deterministic evidence)
  milestone-1/VERIFICATION.md          (M1 — verifier record)

tests/
  check_milestone0.sh                  (M0)
  bootstrap/                           (M1)
  connect/                             (M2)
  work_path/                           (M3)
  verifier/                            (M4)
  monitor/                             (M5)
  parallel/                            (M6)
  image_readiness/                     (M7)
```

`tests/` subdirectories for M1–M7 are not created yet; they are listed
here only to make the target shape explicit. Creating empty placeholder
directories for tests before there is anything to test would itself be
scope creep, so they are deferred to the milestone that needs them.

There is exactly one systemd unit (`hermes.service`) and exactly one
Docker Compose service/container (`hermes`, running `hermes gateway`).
"Hermes Gateway" in the Monitor's `system_check` (§3 above) is a
logical/application-layer check on that one container's one process, not
a second container or a second unit — an earlier draft of this tree
listed a separate `hermes-gateway.service`; that was corrected during
Milestone 1 to satisfy the "exactly one systemd unit" bootstrap
constraint.

## 7. What may be reused from the existing Factory/EC2

Per `BUILD_DIRECTIVE.md` §9, implementation *patterns* may be reused when
still appropriate, never credentials or user state:

- persistent `/opt/data`-style storage separation
- Hermes supervision
- bounded host health checking
- verified local backup concept
- Claude Code persistent wrapper pattern
- GitHub CLI + HTTPS credential helper pattern
- existing test/Ruff practices

Milestone 0 did not need to inspect the existing Factory/EC2 to produce
this design; the directive's specification was sufficient. Any future
milestone that wants to reuse a pattern from the existing system must say
so explicitly at the point of reuse.

## 8. Safety boundaries (design intent, enforced starting Milestone 3+)

Default automatic actions: inspect files, edit code in an approved
workspace, run tests, lint, local build, local verification.

Require explicit user approval for: production deployment, destructive
cloud operations, deleting repositories/resources, changing credentials,
broad IAM changes, irreversible migration, merge to protected branch.

Git commit/push behavior must be configurable and clearly documented
(not yet implemented — see [`MILESTONES.md`](MILESTONES.md)). Secrets are
never exposed to Worker prompts unnecessarily. Least privilege throughout.
