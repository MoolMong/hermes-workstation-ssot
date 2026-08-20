# Hermes Workstation SSOT Repository Build Directive

## Mission

Create a new GitHub repository that is the **Single Source of Truth (SSOT)** for a reproducible, shareable personal AI workstation running on AWS EC2.

The repository must let a fresh EC2 instance be provisioned from source, connect a user's own accounts through an interactive English connection command, operate through Discord, execute coding tasks through Claude Code, supervise long-running work, verify results independently, recover from common service failures, and remain understandable to a single operator.

This is a clean redesign. **Do not refactor or extend the existing AI Project Factory. Do not copy its architecture.**
The existing server may be inspected only as a reference for proven implementation details.

The target system must stay intentionally small:

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

The system must optimize for:
1. simplicity,
2. reproducibility,
3. visible task state,
4. safe recovery,
5. independent verification,
6. secret-free redistribution.

---

# 1. Non-negotiable architecture

The runtime contains only these logical components:

### Hermes
Responsibilities:
- Discord interaction
- intent interpretation
- Context construction
- Decompose
- decide sequential vs parallel execution
- Integrate
- final user report

Hermes is the orchestrator, not the long-running worker.

### Runner
Responsibilities:
- create a task workspace
- create TASK.md
- launch Claude Code in the correct repository/worktree
- record PID/start time
- capture stdout/stderr
- update task state
- never claim semantic completion by itself

### Monitor
One implementation, two logical checks.

#### system_check
Monitor:
- Docker
- Hermes container
- Hermes Gateway
- Discord connectivity

Recover only the failed system layer when safe.

#### task_check
Monitor Runner-owned work:
- worker PID/process identity
- task state
- last progress timestamp
- worker.log modification time
- workspace/git-diff activity

Do not restart a healthy worker merely because no Discord message was sent.

### Verifier
Verifier means the mandatory completion gate, not merely another AI agent.

It must combine deterministic checks where possible:
- process exit status
- actual git diff / changed files
- test results
- build results
- lint results
- forbidden-path checks

and semantic AI review where necessary:
- Acceptance Criteria satisfaction
- missing requirements
- regression risk
- obvious implementation defects

A Worker saying "done" is never sufficient.

Only the Verifier can return PASS.

Task status may become COMPLETED only after Verifier PASS.

### Git / GitHub
GitHub is the remote source/code collaboration layer.
The repository itself is the SSOT for workstation deployment.

---

# 2. Work protocol

Implement the following protocol as a readable policy file, preferably `WORK_PROTOCOL.md`.

For every actionable request:

## Context
Collect only relevant context:
- user request
- repository instructions such as README / CLAUDE.md / AGENTS.md
- related source files
- current git status/diff
- relevant project context

Create `TASK.md` containing:

```text
Goal
Context
Constraints
Acceptance Criteria
Relevant Files
Unknowns
Execution Mode
```

Do not start a long interview.

Ask the user only when a missing fact makes safe execution impossible or materially changes the requested result.
Otherwise infer conservatively and proceed.

## Decompose
Do not decompose trivial work unnecessarily.

Split work only when doing so improves correctness or parallelism.

## Parallelize
Parallelize only tasks that do not depend on each other's outputs.

Default maximum worker count: 3.

If dependency exists, execute sequentially.

Do not add a general-purpose DAG engine in v0.1.

## Verify
Run a fresh verification step after implementation.

Verifier input should primarily be:
- TASK.md
- actual git diff
- changed source
- deterministic test/build/lint evidence
- runtime evidence when relevant

Do not rely on the worker's self-assessment.

On failure, provide only concrete defects to the repair worker.

Use a bounded repair count.

## Integrate
Hermes summarizes:
- what changed
- verification result
- important evidence
- unresolved issues
- whether user attention is required

---

# 3. Task state

Do not introduce SQLite, Redis, queues, leases, JobManager, or a distributed state machine in v0.1.

Use filesystem-backed task state.

Suggested structure:

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

Minimum states:

```text
RECEIVED
PLANNING
RUNNING
VERIFYING
COMPLETED
FAILED
STALLED
NEEDS_USER
```

Minimum `state.json` fields:

```text
task_id
status
phase
pid
process_start_time
started_at
updated_at
retry_count
workspace
```

Atomic file writes are required for state updates.

---

# 4. Discord behavior

The workstation must never silently accept a long-running task.

For work requests:

1. acknowledge receipt quickly,
2. provide task ID,
3. expose current phase,
4. provide periodic progress for long-running work without spamming,
5. report recovery attempts,
6. always report terminal states:
   - COMPLETED
   - FAILED
   - NEEDS_USER

Example:

```text
[TASK-A83F] Accepted.
Phase: Context
```

Progress:

```text
[TASK-A83F] Running.
Context: PASS
Planning: PASS
Implementation: RUNNING
```

Failure:

```text
[TASK-A83F] FAILED.
Reason: Claude worker exited unexpectedly.
Automatic recovery attempts: 1/1.
Action required: ...
```

Silence must never be treated as successful completion.

---

# 5. Recovery model

Keep recovery layered and simple.

## Process/service recovery
Use normal Linux/Docker supervision for:
- Docker
- Hermes
- Gateway

Use bounded restart policies.
Avoid infinite restart loops.

## Task recovery
Monitor only Runner-owned processes.

A task may be considered suspicious only using multiple signals, not a timer alone:
- PID/process identity
- process start time
- progress timestamp
- worker.log activity
- git/workspace activity

Do not kill/restart a worker based solely on "no output for N minutes."

If the worker process is confirmed dead:
- mark the task accordingly,
- retry only within a bounded retry budget,
- otherwise report FAILED/NEEDS_USER.

## EC2-level recovery
Important boundary:

A guest OS cannot restart its own EC2 instance after the instance itself is stopped or the underlying host becomes unavailable.

Therefore:
- service/process recovery belongs inside the instance;
- instance-level recovery must use an AWS-side mechanism.

Implement or document an **optional AWS-side recovery setup** using current AWS-supported mechanisms and least-privilege IAM.
Do not silently create chargeable or account-wide AWS resources.
If automatic AWS-side recovery requires permissions or infrastructure outside the AMI, expose it as an explicit setup step and explain exactly what it does.

User-initiated intentional shutdown must not be treated as an automatic failure unless the user explicitly opts into that behavior.

---

# 6. Connection UX

Create a clear English command:

```bash
hermes-connect
```

It should interactively connect and validate the user's own accounts.

Target integrations:

1. Discord
2. OpenAI / Codex provider used by Hermes
3. Claude Code
4. GitHub

Behavior:
- detect already configured integrations,
- prompt only for missing setup,
- never print secrets back to the screen/logs,
- validate each connection after setup,
- show PASS / FAIL,
- provide actionable recovery instructions on failure.

Example:

```text
Hermes Workstation Connection Setup

[1/4] Discord      PASS
[2/4] OpenAI       PASS
[3/4] Claude Code  PASS
[4/4] GitHub       PASS

All connections are ready.
```

Also provide:

```bash
hermes-doctor
```

for read-only health diagnostics.

`hermes-doctor` should check at minimum:
- Docker
- Hermes container
- Gateway
- Discord
- Claude Code availability/auth status
- GitHub CLI auth
- required directories/permissions
- monitor status
- disk space
- current version/commit identifier

It must not mutate configuration unless explicitly requested.

---

# 7. Reproducible deployment

The GitHub repository is the SSOT.

A new EC2 must be reproducible from this repository without relying on undocumented manual server modifications.

Repository should contain a minimal, understandable layout such as:

```text
README.md
ARCHITECTURE.md
WORK_PROTOCOL.md
SECURITY.md
CHANGELOG.md

bootstrap/
  install.sh
  connect.sh
  doctor.sh

config/
  *.example

systemd/
  ...

docker/
  ...

scripts/
  runner
  monitor
  verifier

tests/
  ...
```

You may improve names/layout if the result is simpler.

Every installed file or service must be traceable back to the repository.

Do not make the live EC2 the only source of configuration truth.

---

# 8. Shareable image / AMI requirements

The resulting base installation must be safe to turn into an AMI or equivalent reusable EC2 image.

The base image MUST NOT contain:
- Discord tokens
- OpenAI OAuth/session credentials
- Claude credentials
- GitHub credentials
- user memory
- conversation/session DB
- personal repositories
- private SSH keys
- shell history containing secrets
- task logs containing private content

Credentials are created only after the recipient launches their own instance and runs `hermes-connect`.

Provide an image-preparation/sanitization check that refuses to declare the system image-ready if known credential/session paths are populated.

Do not merely delete obvious token files. Document all credential-bearing locations used by this implementation.

---

# 9. Existing system: what may be reused

You may inspect the current EC2/repository as a reference.

Reuse implementation patterns only when they remain appropriate:

- persistent `/opt/data`-style storage separation
- Hermes supervision
- bounded host health checking
- verified local backup concept
- Claude Code persistent wrapper pattern
- GitHub CLI + HTTPS credential helper pattern
- existing test/Ruff practices

Do NOT copy credentials or user state.

---

# 10. Explicitly forbidden v0.1 scope

Do not recreate the old Factory.

Do not add these unless a concrete requirement cannot be met without them and you stop to justify the change first:

- AI Project Factory
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

Prefer one understandable process or script over several services.

Complexity must be justified by an observed failure mode, not anticipated elegance.

---

# 11. Safety boundaries

Default automatic actions:
- inspect files
- edit code in approved workspace
- run tests
- lint
- local build
- local verification

Require explicit user approval for high-impact actions such as:
- production deployment
- destructive cloud operations
- deleting repositories/resources
- changing credentials
- broad IAM changes
- irreversible migration
- merge to protected branch

Git commit/push behavior must be configurable and clearly documented.

Never expose secrets to Worker prompts unnecessarily.

Use least privilege.

---

# 12. Implementation strategy

Do NOT attempt the entire platform as one giant change.

Build it vertically in small milestones.

## Milestone 0 — Repository and design
Create:
- repository
- README
- architecture
- work protocol
- directory layout
- threat/secret model
- Definition of Done

No unnecessary runtime framework.

## Milestone 1 — Clean bootstrap
Fresh EC2 can install the base workstation reproducibly from the repo.

## Milestone 2 — Connection UX
`hermes-connect` configures and validates Discord/OpenAI/Claude/GitHub.

## Milestone 3 — Basic work path
Discord → Hermes → Runner → Claude → result.

One worker only.

## Milestone 4 — Verifier
Worker result → deterministic checks → semantic verification → PASS/FAIL.

COMPLETED is impossible without PASS.

## Milestone 5 — Monitor/recovery
System health + task health using one Monitor implementation where practical.

Verify real failure scenarios.

## Milestone 6 — Parallel execution
Only now add up to 3 independent workers.

Do not add parallelism before the single-worker lifecycle is reliable.

## Milestone 7 — Image readiness
Sanitize and validate that the installation can be safely converted to a reusable AMI.

---

# 13. Required tests / fault injection

Do not claim the workstation is finished based only on unit tests.

At minimum prove these scenarios:

1. fresh EC2 bootstrap succeeds,
2. `hermes-connect` succeeds with a test user's credentials,
3. Discord request receives immediate acknowledgement,
4. normal Claude task completes,
5. worker exits unexpectedly,
6. worker stalls/no progress,
7. Hermes Gateway restarts,
8. Hermes container restarts,
9. EC2 reboots,
10. task state survives relevant service restart,
11. Worker returns exit code 0 but produces no required changes → Verifier rejects,
12. tests fail → Verifier rejects,
13. forbidden path modified → Verifier rejects,
14. credentials removed → `hermes-doctor` clearly reports missing connection,
15. image-readiness check rejects an installation containing user credentials.

Record evidence for each test.

---

# 14. Definition of Done

Do not call the repository/platform complete until all of the following are true:

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
- a worker cannot self-declare COMPLETED,
- all secrets are outside the distributable image,
- image-readiness validation passes,
- documentation is sufficient for another technically competent user to deploy it,
- the implementation remains materially simpler than the old Factory architecture.

---

# 15. How you must work on this request

You are responsible for creating the SSOT repository and implementing this plan, but you must protect the architecture from scope drift.

Before implementation:

1. inspect the current environment only as needed,
2. create the new repository,
3. write `ARCHITECTURE.md`, `WORK_PROTOCOL.md`, and the milestone plan,
4. show the proposed repository tree and identify any deviations from this directive.

Then proceed milestone by milestone.

For each milestone:
- implement,
- test,
- independently verify,
- commit,
- record evidence,
- then continue.

If you believe additional infrastructure is necessary, do not silently add it.
State:
1. the concrete failure mode,
2. why the current minimal design cannot solve it,
3. the smallest additional component required.

The governing rule is:

> Build the smallest system that reliably turns a natural-language Discord request into a visible, supervised, independently verified result.

Do not optimize for architectural sophistication.
Optimize for reliability, comprehensibility, reproducibility, and safe redistribution.
