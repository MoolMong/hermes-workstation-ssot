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
