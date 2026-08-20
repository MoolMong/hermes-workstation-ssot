# CLAUDE.md

Instructions for any Claude Code agent (including future Runner-launched
workers, once Milestone 3 exists) working in this repository.

## Read this first

`BUILD_DIRECTIVE.md` is the governing requirement for this entire
repository. It is authoritative over every other document, including this
one. If an instruction here ever conflicts with it, the directive wins —
stop and flag the conflict rather than guessing.

Also read, in this order, before making non-trivial changes:

1. `BUILD_DIRECTIVE.md` — the mission and hard constraints.
2. `ARCHITECTURE.md` — the components that exist (or will exist) and the
   proposed repository tree.
3. `WORK_PROTOCOL.md` — the Context → Decompose → Parallelize → Verify →
   Integrate protocol to follow for actionable requests.
4. `MILESTONES.md` — what is currently in scope vs. planned.
5. `SECURITY.md` — the secret model and every credential-bearing location.

## Milestone discipline

Work proceeds one milestone at a time (`BUILD_DIRECTIVE.md` §12, §15). At
the time of writing, only **Milestone 0** (repository and design) is
implemented. Do not implement Milestone 1+ functionality — bootstrap
scripts, `hermes-connect`/`hermes-doctor`, Hermes/Runner/Monitor/Verifier
code, Discord integration, or AMI sanitization logic — until the current
milestone's Definition of Done (`DEFINITION_OF_DONE.md`) is met and the
milestone plan (`MILESTONES.md`) has been updated to reflect that the next
milestone is now in progress. Check `MILESTONES.md` for current status
before starting new work.

## Forbidden components

Do not add any of the following unless you first stop and state, in
writing, (1) the concrete failure mode observed, (2) why the current
minimal design cannot solve it, (3) the smallest additional component
required — and record it in `DEVIATIONS.md`:

AI Project Factory, a separate HTTP orchestrator service, a second
orchestrator runtime, SQLite task database, Redis, a message broker, a
JobManager abstraction, a lease system, daemon-thread long-running jobs
inside Hermes, a general DAG engine, a 13-question specification
interview, an event outbox/delivery subsystem, multiple overlapping
watchdog daemons, Kubernetes, or unnecessary microservices.

Prefer one understandable process or script over several services.

## Secrets

Never commit real credentials. Only `*.example` files with placeholder
values belong in `config/`. See `SECURITY.md` §3 for the full list of
credential-bearing locations and what must never appear in this
repository or in a distributable image. Never print or log a secret value.
Never include a credential in a prompt to a worker unless that specific
task concretely requires it.

## Safety boundaries

Default-automatic: inspect files, edit code in the approved workspace, run
tests, lint, local build, local verification.

Requires explicit user approval: production deployment, destructive cloud
operations, deleting repositories/resources, changing credentials, broad
IAM changes, irreversible migration, merge to a protected branch.

## Verification

A worker (human or agent) saying "done" is never sufficient. Follow
`WORK_PROTOCOL.md` §4: verify with deterministic checks (tests, build,
lint, diff review, forbidden-path checks) before considering work
complete. For this repository specifically, `tests/check_milestone0.sh`
is the current deterministic check; run it after any change that touches
Milestone 0 documents or the directory skeleton, and keep it passing.

## Git discipline

This repository's own operating constraints for the current change may
reserve commit/push/PR/deploy actions to an orchestrator or the human
operator — check the instructions you were given for this specific task
before running any Git write operation. Once implemented, the workstation
itself must make Git commit/push behavior configurable and clearly
documented (`BUILD_DIRECTIVE.md` §11) — do not assume auto-commit or
auto-push is acceptable by default.

## Existing Factory/EC2

This is a clean redesign. Do not copy the architecture of the existing AI
Project Factory. It may only be inspected as a reference for proven
implementation *details* (`BUILD_DIRECTIVE.md` §9), never as a template to
extend, and never for its credentials or user state.
