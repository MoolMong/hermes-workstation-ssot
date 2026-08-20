# Changelog

Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
Entries are keyed by milestone, since this repository is built in
milestones per `BUILD_DIRECTIVE.md` §12.

## [Unreleased]

## [0.1.0-m0] — 2026-08-20 — Milestone 0: Repository and design

### Added

- `README.md`, `ARCHITECTURE.md`, `WORK_PROTOCOL.md`, `SECURITY.md`,
  `MILESTONES.md`, `DEFINITION_OF_DONE.md`, `DEVIATIONS.md`, `CLAUDE.md`,
  `.gitignore`.
- Proposed repository tree, documented in `ARCHITECTURE.md` and mirrored
  on disk as a minimal, traceable skeleton (`bootstrap/`, `docker/`,
  `systemd/`, `scripts/`, each with a placeholder `README.md` only).
- `config/*.example` files (Discord, OpenAI, Claude, GitHub, Hermes) with
  placeholder values only.
- `tests/check_milestone0.sh` — deterministic Milestone 0 checks (document
  presence, forbidden-scope declaration, secret placeholders, repository
  tree consistency, no Milestone 1–7 functionality present).

### Verification evidence

- `bash tests/check_milestone0.sh` passes deterministically; see the run
  output recorded for the current change for the exact check count and
  result.
- The full chronological record of independent-verifier passes for
  Milestone 0 — including verdicts, scope, and findings — is kept
  durably in [`evidence/milestone-0/VERIFICATION.md`](evidence/milestone-0/VERIFICATION.md),
  not restated as a bare claim here. As of this entry: Pass 1 (content)
  returned PASS; Pass 2 (final-state) returned FAIL, because prior
  versions of this document, `README.md`, `MILESTONES.md`, and
  `DEFINITION_OF_DONE.md` asserted independent-verifier PASS without
  that durable artifact existing; Pass 3 (fresh, independent, final-state
  review of the repaired repository) returned PASS, confirming that
  evidence-integrity defect is fixed. Milestone 0 status is
  **complete**.

Summary of what `tests/check_milestone0.sh` asserts:

- All ten required Milestone 0 documents exist and are non-empty.
- `SECURITY.md` contains a threat-model section, a secret-model section,
  and a credential-location table covering Discord, OpenAI, Claude,
  GitHub, and the `/opt/hermes-data/` tree.
- Every item in `BUILD_DIRECTIVE.md` §10's forbidden-scope list is
  explicitly named in `ARCHITECTURE.md`'s forbidden-scope section, and no
  file in the repository implements any of them.
- No `config/*.example` file contains a real-looking secret (long
  hex/base64 token shape); each contains an explicit placeholder marker.
- The repository tree documented in `ARCHITECTURE.md` §6 (files marked
  `(M0)`) matches what is actually present on disk.
- `bootstrap/`, `docker/`, `systemd/`, `scripts/` contain only a
  `README.md` each — no scripts, unit files, or Dockerfiles yet.
- `evidence/milestone-0/VERIFICATION.md` exists, is non-empty, and
  records a chronological Pass 1 / Pass 2 / Pass 3 verification history;
  and `README.md`, `MILESTONES.md`, `DEFINITION_OF_DONE.md`, and this
  file each reference it rather than self-asserting a verification
  outcome.

### Process note

The Claude authoring worker did not commit or push this change. Per the
current operating instructions, the orchestrator owns the Milestone 0
commit (and any push/PR). This is also recorded in
`DEFINITION_OF_DONE.md`.

### Not included (by design)

Milestones 1–7 (bootstrap, connection UX, basic work path, verifier,
monitor/recovery, parallel execution, image readiness) — see
`MILESTONES.md`.
