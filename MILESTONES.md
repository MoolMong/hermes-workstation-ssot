# Milestones

Restated from `BUILD_DIRECTIVE.md` §12, with status. Work proceeds
milestone by milestone; for each milestone: implement, test, independently
verify, commit, record evidence, then continue (`BUILD_DIRECTIVE.md` §15).
No milestone after M0 is implemented yet.

| # | Milestone | Status | Summary |
|---|---|---|---|
| 0 | Repository and design | **Complete** | Repository, README, architecture, work protocol, directory layout, threat/secret model, Definition of Done. No runtime framework. |
| 1 | Clean bootstrap | Planned | Fresh EC2 can install the base workstation reproducibly from the repo. |
| 2 | Connection UX | Planned | `hermes-connect` configures and validates Discord/OpenAI/Claude/GitHub. `hermes-doctor` provides read-only diagnostics. |
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
Done. Milestone 1 (Clean bootstrap) is next; per the sequencing rule
below, it has not started.

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

## Sequencing rule

Do not begin implementation of a later milestone before the current one's
Definition of Done (see `DEFINITION_OF_DONE.md`) is met and evidence is
recorded. Do not add infrastructure ahead of an observed failure mode —
if a milestone appears to need something outside its listed scope, stop
and state (1) the concrete failure mode, (2) why the minimal design
cannot solve it, (3) the smallest additional component required
(`BUILD_DIRECTIVE.md` §15).
