# Hermes Workstation SSOT

Single Source of Truth (SSOT) repository for a reproducible, shareable
personal AI workstation running on AWS EC2. A fresh EC2 instance must be
provisionable from this repository alone, connect a user's own accounts
through an interactive command, operate through Discord, execute coding
tasks through Claude Code, supervise long-running work, verify results
independently, recover from common service failures, and remain
understandable to a single operator.

This repository is governed end-to-end by [`BUILD_DIRECTIVE.md`](BUILD_DIRECTIVE.md).
If anything in this document (or any other document here) appears to
conflict with the directive, the directive wins.

## Status

**Milestone 0 (Repository and design): complete.**

`tests/check_milestone0.sh` passes deterministically (see
[`CHANGELOG.md`](CHANGELOG.md) for the current check count and result).
Independent verification is recorded chronologically, in full, in
[`evidence/milestone-0/VERIFICATION.md`](evidence/milestone-0/VERIFICATION.md):
Pass 1 (content) returned a semantic `PASS`; Pass 2 (final-state) returned
a semantic `FAIL`, because the repository asserted independent-verifier
`PASS` in multiple documents without a durable review artifact to prove
it; that evidence-integrity defect was repaired, and Pass 3 (fresh,
independent, final-state review of the repaired repository) returned a
semantic `PASS`. This document and
[`DEFINITION_OF_DONE.md`](DEFINITION_OF_DONE.md) do not predeclare a
verifier outcome; they point to
[`evidence/milestone-0/VERIFICATION.md`](evidence/milestone-0/VERIFICATION.md)
as the source of truth for verification status.

Milestones 1–7 (bootstrap, connection UX, basic work path, verifier,
monitor/recovery, parallel execution, image readiness) remain **planned,
not implemented**. See [`MILESTONES.md`](MILESTONES.md) for the full plan
and current status of each milestone.

Directories that correspond to future milestones (`bootstrap/`, `systemd/`,
`docker/`, `scripts/`) currently contain only a `README.md` placeholder
describing what will live there and in which milestone — no functional
code. This is intentional: it makes the target repository tree traceable
now without pulling forward work that has not been designed, tested, or
verified yet.

## Document map

| Document | Purpose |
|---|---|
| [`BUILD_DIRECTIVE.md`](BUILD_DIRECTIVE.md) | Governing top-level requirement. Authoritative. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Non-negotiable components, data flow, proposed repository tree. |
| [`WORK_PROTOCOL.md`](WORK_PROTOCOL.md) | Context → Decompose → Parallelize → Verify → Integrate policy for every actionable request. |
| [`SECURITY.md`](SECURITY.md) | Threat model, secret model, every credential-bearing location, image-sanitization requirements. |
| [`MILESTONES.md`](MILESTONES.md) | Milestone-by-milestone plan and status (M0 only implemented). |
| [`DEFINITION_OF_DONE.md`](DEFINITION_OF_DONE.md) | Global Definition of Done plus the Milestone 0 Definition of Done. |
| [`DEVIATIONS.md`](DEVIATIONS.md) | Explicit deviations from `BUILD_DIRECTIVE.md` (expected: none). |
| [`CHANGELOG.md`](CHANGELOG.md) | Notable changes, keyed by milestone. |
| [`CLAUDE.md`](CLAUDE.md) | Project-level instructions for any Claude Code agent working in this repository. |
| [`evidence/milestone-0/VERIFICATION.md`](evidence/milestone-0/VERIFICATION.md) | Durable, chronological record of independent-verifier passes for Milestone 0. Authoritative source for verification status claims made elsewhere. |

## Repository layout (current, Milestone 0)

```text
.
├── ARCHITECTURE.md
├── BUILD_DIRECTIVE.md
├── CHANGELOG.md
├── CLAUDE.md
├── DEFINITION_OF_DONE.md
├── DEVIATIONS.md
├── MILESTONES.md
├── README.md
├── SECURITY.md
├── WORK_PROTOCOL.md
├── .gitignore
├── bootstrap/
│   └── README.md          # install.sh / connect.sh / doctor.sh land here (Milestone 1–2)
├── config/
│   ├── discord.env.example
│   ├── openai.env.example
│   ├── claude.env.example
│   ├── github.env.example
│   └── hermes.config.example.yaml
├── docker/
│   └── README.md          # container definitions land here (Milestone 1+)
├── systemd/
│   └── README.md          # unit files land here (Milestone 1+)
├── scripts/
│   └── README.md          # runner / monitor / verifier land here (Milestone 3–5)
├── evidence/
│   └── milestone-0/
│       └── VERIFICATION.md # durable, chronological verifier record
└── tests/
    └── check_milestone0.sh
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full target tree (including
files that do not exist yet) and the reasoning behind it.

## Running the Milestone 0 checks

```bash
bash tests/check_milestone0.sh
```

This is a deterministic, dependency-free check (bash + coreutils only) that
validates:

1. all required Milestone 0 documents exist and are non-empty,
2. `SECURITY.md` documents a threat model, a secret model, and enumerates
   credential-bearing locations,
3. the forbidden-scope list from `BUILD_DIRECTIVE.md` §10 is explicitly
   declared (and not silently implemented) in this repository,
4. `config/*.example` files contain only placeholder values, never
   real-looking secrets,
5. the repository tree documented in `ARCHITECTURE.md` matches what is
   actually on disk,
6. no Milestone 1–7 functionality has been implemented yet (placeholder
   directories stay placeholders).

## Non-goals for v0.1 (Milestone 0)

No runtime framework, no orchestrator process, no task state machine, no
Discord bot, no Claude Code runner, no monitor, no verifier. Those are
Milestones 1–7. Milestone 0 is documentation and repository scaffolding
only, per `BUILD_DIRECTIVE.md` §12.
