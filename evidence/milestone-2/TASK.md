# TASK.md — Milestone 2: Connection UX

Written per `WORK_PROTOCOL.md` §1 ("For every actionable request...
Create `TASK.md`"). This is the Context artifact for Milestone 2
(`MILESTONE2_DIRECTIVE.md`), covering both the original implementation
pass (`bootstrap/connect.sh`, `bootstrap/connect-common.sh`,
`bootstrap/doctor.sh`, `tests/connection/*`) and this closing pass, which
adds the missing `tests/connection/run.sh` runner, the required
`docs/FRESH_EC2_VALIDATION.md` plan, this evidence directory, and honest
documentation updates — without re-reading or rewriting the already-
implemented scripts except where a test failure required it.

## Goal

Implement `hermes-connect` (`bootstrap/connect.sh`) and `hermes-doctor`
(`bootstrap/doctor.sh`) per `MILESTONE2_DIRECTIVE.md`: an interactive
command that connects a fresh Hermes Workstation instance to the
operator's own Discord, OpenAI/Codex, Claude Code, and GitHub accounts,
and a read-only diagnostic command — both provable by deterministic,
credential-free tests, with independent semantic verification still
pending (`MILESTONE2_DIRECTIVE.md` §10: "independent verifier PASS is
obtained" is a completion-gate item, not something a single authoring
pass can self-certify).

## Context

- `MILESTONE2_DIRECTIVE.md` is the governing specification for this
  milestone: `hermes-connect` interface and per-integration requirements
  (§2–§6), `hermes-doctor` (§7), credential/redistribution rules (§8),
  testing requirements (§9), the Milestone 2 completion gate (§10), and
  the Fresh EC2 validation plan requirement (§11).
- `ARCHITECTURE.md` §6 declares the Milestone 2 file set:
  `bootstrap/connect.sh`, `bootstrap/doctor.sh`,
  `bootstrap/connect-common.sh`, `docs/FRESH_EC2_VALIDATION.md`,
  `evidence/milestone-2/{TASK.md,TEST_EVIDENCE.md,VERIFICATION.md}`,
  `tests/connection/`.
- `SECURITY.md` §3 is the single source of truth for every
  credential-bearing path this milestone introduces
  (`/opt/hermes-data/.env`, `/opt/hermes-data/auth.json`,
  `/opt/hermes-data/auth/claude/`, `/opt/hermes-data/auth/github/`) and
  is cross-checked against `bootstrap/connect-common.sh`'s
  `credential_paths()` by `tests/connection/test_image_readiness.sh` so
  the two cannot silently drift apart.
- `MILESTONES.md`'s sequencing rule: Milestone 3+ (Runner/Monitor/
  Verifier, Discord task execution) must not begin before this
  milestone's Definition of Done is met and recorded.
- At the start of this closing pass, `bootstrap/connect.sh`,
  `bootstrap/connect-common.sh`, `bootstrap/doctor.sh`, and all eight
  `tests/connection/*.sh` files (`lib_fakebin.sh` plus seven
  `test_*.sh` scripts covering Claude, Discord, doctor read-only
  behavior, GitHub, idempotency, image readiness, and OpenAI) already
  existed and were not rewritten by this pass. `tests/connection/run.sh`
  — the syntax-check-and-run-suite runner referenced by `ARCHITECTURE.md`
  §6 and required to make the suite executable as one command — did not
  exist yet. `tests/bootstrap/test_no_m3_scope.sh` (superseding the old
  `test_no_m2_scope.sh`, which asserted `connect.sh`/`doctor.sh` did not
  exist — no longer true) also already existed, untracked.
- `tests/check_milestone0.sh` was failing on exactly two checks at the
  start of this pass: `MILESTONES.md`'s status table still marked
  Milestone 2 `Planned` while the script's own `CURRENT_MILESTONE=2`
  constant expected otherwise, and four `ARCHITECTURE.md`-declared
  Milestone 2 paths (`docs/FRESH_EC2_VALIDATION.md` and the three
  `evidence/milestone-2/` files) did not exist on disk yet. Milestone 1's
  suite (`tests/bootstrap/run.sh`) and the new Milestone 2 connection
  suite were both already passing.

## Constraints

- No Milestone 3+ functionality: no Runner/Monitor/Verifier code, no
  Discord task-execution/state-machine logic, no second systemd unit
  (`CLAUDE.md` "Milestone discipline"; enforced by
  `tests/bootstrap/test_no_m3_scope.sh`).
- No forbidden components from `BUILD_DIRECTIVE.md` §10 (checked by
  `tests/check_milestone0.sh` §3).
- No real AWS resource creation, no real credential creation, no commit,
  no push (explicit constraint for this pass).
- Do not re-read or rewrite the already-implemented `bootstrap/connect.sh`,
  `bootstrap/connect-common.sh`, `bootstrap/doctor.sh`, or the eight
  existing `tests/connection/*.sh` files beyond what is required to fix an
  actual test failure — this pass finishes the partial M2 artifact
  narrowly rather than re-deriving it.
- Never store, echo, or log a real secret value anywhere in this
  repository or its evidence, including test evidence
  (`MILESTONE2_DIRECTIVE.md` §8, §13).
- Documentation must state the true, current evidence boundary:
  independent verifier result is **PENDING**, and all completed checks in
  this pass are static/local only — no real Discord/OpenAI/Claude/GitHub
  account was used, and no Fresh EC2 runtime validation has been
  performed (`MILESTONE2_DIRECTIVE.md` §10, "Do not claim Fresh EC2
  runtime PASS as part of Milestone 2 unless it has actually been
  performed").

## Acceptance Criteria

- `tests/connection/run.sh` exists, runs a `bash -n` syntax check over
  `bootstrap/connect.sh`, `bootstrap/connect-common.sh`,
  `bootstrap/doctor.sh`, `tests/connection/lib_fakebin.sh`, and every
  `tests/connection/test_*.sh`, then runs the full `test_*.sh` suite, and
  exits 0.
- `bash tests/bootstrap/run.sh` still exits 0 (Milestone 1 regression
  suite, including `test_no_m3_scope.sh` and `test_docker_compose.sh`'s
  single-service-plus-`hermes gateway run` check).
- `bash tests/check_milestone0.sh` exits 0: `MILESTONES.md` updated so
  its Milestone 2 status row is no longer `Planned` (while Milestone 3's
  row remains `Planned`), and `docs/FRESH_EC2_VALIDATION.md` plus all
  three `evidence/milestone-2/*.md` files exist on disk.
- `docs/FRESH_EC2_VALIDATION.md` states every field
  `MILESTONE2_DIRECTIVE.md` §11 requires (OS/AMI assumption, minimum
  instance sizing, required networking, required IAM permissions, exact
  bootstrap command, exact connection flow, exact health checks, expected
  PASS evidence, cleanup procedure, expected cost-impacting resources)
  plus an explicit AWS STOP block naming the exact actions requiring
  approval, matching `MILESTONE2_DIRECTIVE.md` §11's required report
  format.
- `evidence/milestone-2/TEST_EVIDENCE.md` and
  `evidence/milestone-2/VERIFICATION.md` truthfully record what was and
  was not run: deterministic suites PASS, independent-verifier result
  PENDING, no real-account/Fresh-EC2 validation performed.
- `README.md`, `MILESTONES.md`, `DEFINITION_OF_DONE.md`, `CHANGELOG.md`,
  `DEVIATIONS.md` accurately describe Milestone 2 as implemented at the
  repository level and awaiting independent verification — not as fully
  "complete" the way Milestone 1 is — and continue to state Milestone 3
  and Fresh EC2/Docker/systemd runtime validation as `Planned` /
  `NOT RUN` / `BLOCKED` respectively.
- `git diff --check` reports no whitespace errors in the changed files.
- No AWS action, no credential creation, no commit, no push is performed
  by this pass.

## Relevant Files

- `tests/connection/run.sh` (new, this pass)
- `docs/FRESH_EC2_VALIDATION.md` (new, this pass)
- `evidence/milestone-2/TASK.md`, `TEST_EVIDENCE.md`, `VERIFICATION.md`
  (new, this pass)
- `MILESTONES.md`, `DEFINITION_OF_DONE.md`, `CHANGELOG.md`,
  `DEVIATIONS.md`, `README.md` (updated, this pass)
- `bootstrap/connect.sh`, `bootstrap/connect-common.sh`,
  `bootstrap/doctor.sh`, `tests/connection/*.sh` (pre-existing, not
  rewritten by this pass)

## Unknowns / defects found and resolved during this pass

- None found in the pre-existing `bootstrap/connect.sh`,
  `bootstrap/connect-common.sh`, `bootstrap/doctor.sh`, or
  `tests/connection/*.sh` — all passed on first run via the new
  `tests/connection/run.sh` runner with no code changes required.
- `tests/check_milestone0.sh`'s two failures (§ Context above) were
  documentation/evidence gaps, not code defects, and are resolved by this
  pass's new/updated documents rather than by touching the check script
  itself.

## Execution Mode

Sequential, single authoring context, narrowly scoped to the missing
artifacts identified above. Not decomposed into parallel workers — the
runner, the Fresh EC2 plan, and the evidence/documentation set are small
and mutually referential (the plan cites the same command surface the
runner exercises), so splitting this across independent workers would not
have improved correctness or speed (`WORK_PROTOCOL.md` §2–§3).
