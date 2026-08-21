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
**Milestone 1 (Clean bootstrap): complete and independently verified.**
**Milestone 2 (Connection UX): complete within the documented static/local boundary and independently verified.**

`tests/check_milestone0.sh` passes deterministically (see
[`CHANGELOG.md`](CHANGELOG.md) for the current check count and result).
Independent verification for Milestone 0 is recorded chronologically, in
full, in
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

`bootstrap/install.sh`, `docker/Dockerfile`, `docker/docker-compose.yml`,
`docker/entrypoint.sh`, and `systemd/hermes.service` implement Milestone 1,
with deterministic evidence in
[`evidence/milestone-1/TEST_EVIDENCE.md`](evidence/milestone-1/TEST_EVIDENCE.md).
A fresh independent read-only Claude Code verifier returned PASS; its
chronological review record is
[`evidence/milestone-1/VERIFICATION.md`](evidence/milestone-1/VERIFICATION.md).
Fresh EC2 and Docker runtime validation remain explicitly BLOCKED, not
fabricated as PASS; see those evidence files for the exact boundary.

`bootstrap/connect.sh` (`hermes-connect`) and `bootstrap/doctor.sh`
(`hermes-doctor`) implement Milestone 2, with deterministic evidence in
[`evidence/milestone-2/TEST_EVIDENCE.md`](evidence/milestone-2/TEST_EVIDENCE.md).
Fresh independent read-only verification returned **PASS** and is recorded
chronologically in
[`evidence/milestone-2/VERIFICATION.md`](evidence/milestone-2/VERIFICATION.md).
Fresh EC2, Docker/Compose, and systemd runtime validation for the combined
Milestone 1 + Milestone 2 stack, and any connection of real Discord/
OpenAI/Claude/GitHub accounts, were not authorized/available and remain
explicitly `NOT RUN`/`BLOCKED`; the plan for that validation, including
the required AWS-approval STOP, is
[`docs/FRESH_EC2_VALIDATION.md`](docs/FRESH_EC2_VALIDATION.md). The
directive that scoped this milestone is
[`MILESTONE2_DIRECTIVE.md`](MILESTONE2_DIRECTIVE.md).

Milestones 3–7 (basic work path, verifier, monitor/recovery, parallel
execution, image readiness) remain **planned, not implemented**. No
architectural deviation or forbidden component (`CLAUDE.md` "Forbidden
components") was added while implementing Milestone 2; see
[`DEVIATIONS.md`](DEVIATIONS.md). See [`MILESTONES.md`](MILESTONES.md)
for the full plan and current status of each milestone.

`scripts/` (Runner/Monitor/Verifier, Milestones 3–5) still contains only a
`README.md` placeholder describing what will live there and in which
milestone — no functional code yet. This is intentional: it keeps the
target repository tree traceable without pulling forward work that has not
been designed, tested, or verified yet.

## Document map

| Document | Purpose |
|---|---|
| [`BUILD_DIRECTIVE.md`](BUILD_DIRECTIVE.md) | Governing top-level requirement. Authoritative. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Non-negotiable components, data flow, proposed repository tree. |
| [`WORK_PROTOCOL.md`](WORK_PROTOCOL.md) | Context → Decompose → Parallelize → Verify → Integrate policy for every actionable request. |
| [`SECURITY.md`](SECURITY.md) | Threat model, secret model, every credential-bearing location, image-sanitization requirements. |
| [`MILESTONES.md`](MILESTONES.md) | Milestone-by-milestone plan and status (M0–M2 complete within their documented evidence boundaries). |
| [`DEFINITION_OF_DONE.md`](DEFINITION_OF_DONE.md) | Global Definition of Done plus the Milestone 0, Milestone 1, and Milestone 2 Definitions of Done. |
| [`DEVIATIONS.md`](DEVIATIONS.md) | Explicit deviations from `BUILD_DIRECTIVE.md` (expected: none). |
| [`CHANGELOG.md`](CHANGELOG.md) | Notable changes, keyed by milestone. |
| [`CLAUDE.md`](CLAUDE.md) | Project-level instructions for any Claude Code agent working in this repository. |
| [`MILESTONE2_DIRECTIVE.md`](MILESTONE2_DIRECTIVE.md) | The Milestone 2 + Fresh EC2 validation directive this milestone was scoped against. |
| [`docs/FRESH_EC2_VALIDATION.md`](docs/FRESH_EC2_VALIDATION.md) | The Fresh EC2 end-to-end validation plan for Milestone 1 + Milestone 2, with an explicit STOP before any AWS resource is created. |
| [`evidence/milestone-0/VERIFICATION.md`](evidence/milestone-0/VERIFICATION.md) | Durable, chronological record of independent-verifier passes for Milestone 0. Authoritative source for verification status claims made elsewhere. |
| [`evidence/milestone-1/TASK.md`](evidence/milestone-1/TASK.md) | Milestone 1 Context/Constraints/Acceptance Criteria (`WORK_PROTOCOL.md` §1). |
| [`evidence/milestone-1/TEST_EVIDENCE.md`](evidence/milestone-1/TEST_EVIDENCE.md) | Milestone 1 deterministic test run evidence. Explicitly not an independent-verifier `PASS` claim — see that document for what it does and does not assert. |
| [`evidence/milestone-1/VERIFICATION.md`](evidence/milestone-1/VERIFICATION.md) | Durable chronological record of independent semantic verification for Milestone 1. |
| [`evidence/milestone-2/TASK.md`](evidence/milestone-2/TASK.md) | Milestone 2 Context/Constraints/Acceptance Criteria (`WORK_PROTOCOL.md` §1). |
| [`evidence/milestone-2/TEST_EVIDENCE.md`](evidence/milestone-2/TEST_EVIDENCE.md) | Milestone 2 deterministic test run evidence. Explicitly not an independent-verifier `PASS` claim — see that document for what it does and does not assert. |
| [`evidence/milestone-2/VERIFICATION.md`](evidence/milestone-2/VERIFICATION.md) | Durable chronological record of independent semantic verification for Milestone 2; latest pass: `PASS`. |

## Repository layout (current, Milestone 0 + Milestone 1 + Milestone 2)

```text
.
├── ARCHITECTURE.md
├── BUILD_DIRECTIVE.md
├── CHANGELOG.md
├── CLAUDE.md
├── DEFINITION_OF_DONE.md
├── DEVIATIONS.md
├── MILESTONES.md
├── MILESTONE2_DIRECTIVE.md
├── README.md
├── SECURITY.md
├── WORK_PROTOCOL.md
├── .gitignore
├── bootstrap/
│   ├── README.md
│   ├── install.sh              # idempotent host bootstrap (Milestone 1)
│   ├── hermes-commit.pin       # pinned Hermes Agent commit (Milestone 1)
│   ├── hermes-installer.sha256 # pinned installer checksum (Milestone 1)
│   ├── connect.sh              # hermes-connect (Milestone 2)
│   ├── doctor.sh                # hermes-doctor (Milestone 2)
│   └── connect-common.sh        # shared helpers (Milestone 2)
├── config/
│   ├── discord.env.example
│   ├── openai.env.example
│   ├── claude.env.example
│   ├── github.env.example
│   └── hermes.config.example.yaml
├── docker/
│   ├── README.md
│   ├── Dockerfile              # Hermes Agent image (Milestone 1)
│   ├── docker-compose.yml      # single hermes service (Milestone 1)
│   └── entrypoint.sh           # data-volume seeding (Milestone 1)
├── systemd/
│   ├── README.md
│   └── hermes.service          # the only systemd unit (Milestone 1)
├── scripts/
│   └── README.md          # runner / monitor / verifier land here (Milestone 3–5)
├── docs/
│   └── FRESH_EC2_VALIDATION.md # Fresh EC2 validation plan (Milestone 2)
├── evidence/
│   ├── milestone-0/
│   │   └── VERIFICATION.md     # durable, chronological verifier record
│   ├── milestone-1/
│   │   ├── TASK.md             # Context/Constraints/Acceptance Criteria
│   │   ├── TEST_EVIDENCE.md    # deterministic test run evidence
│   │   └── VERIFICATION.md     # independent semantic verifier record
│   └── milestone-2/
│       ├── TASK.md             # Context/Constraints/Acceptance Criteria
│       ├── TEST_EVIDENCE.md    # deterministic test run evidence
│       └── VERIFICATION.md     # independent semantic verifier record (PASS)
└── tests/
    ├── check_milestone0.sh
    ├── bootstrap/
    │   ├── run.sh               # syntax checks + full suite runner
    │   └── test_*.sh
    └── connection/
        ├── run.sh               # syntax checks + full suite runner (Milestone 2)
        ├── lib_fakebin.sh
        └── test_*.sh
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full target tree (including
files that do not exist yet) and the reasoning behind it.

## Running the checks

```bash
bash tests/check_milestone0.sh   # documents, secret model, forbidden-scope,
                                  # repository-tree consistency (milestone-aware)
bash tests/bootstrap/run.sh      # Milestone 1: syntax checks + full test suite
bash tests/connection/run.sh     # Milestone 2: syntax checks + full test suite
```

`tests/check_milestone0.sh` is a deterministic, dependency-free check
(bash + coreutils only) that validates:

1. all required Milestone 0 documents exist and are non-empty,
2. `SECURITY.md` documents a threat model, a secret model, and enumerates
   credential-bearing locations,
3. the forbidden-scope list from `BUILD_DIRECTIVE.md` §10 is explicitly
   declared (and not silently implemented) in this repository,
4. `config/*.example` files contain only placeholder values, never
   real-looking secrets,
5. the repository tree documented in `ARCHITECTURE.md` matches what is
   actually on disk, for every milestone implemented so far (not just
   Milestone 0 — see the script's own comments for how it stays honest
   about which milestone is current),
6. no file exists outside what `ARCHITECTURE.md`'s tree declares for the
   milestones implemented so far (no undeclared or future-milestone
   scope creep).

`tests/bootstrap/run.sh` is Milestone 1's deterministic check: a
`bash -n` syntax check over every Milestone 1 shell script, plus the full
`tests/bootstrap/test_*.sh` suite (dry-run, idempotency, provenance,
rendered-config content, permissions, Compose single-service shape,
systemd bounded supervision, Dockerfile pin/checksum/URL guarantees,
package-stage fail-closed behavior, and absence of Milestone 2+ files).
Never invokes Docker, apt-get install, or systemctl enable/start/
daemon-reload against the real host.

`tests/connection/run.sh` is Milestone 2's deterministic check: a
`bash -n` syntax check over every Milestone 2 shell script, plus the full
`tests/connection/test_*.sh` suite (Claude, Discord, GitHub, and
OpenAI/Codex setup/validation, read-only `hermes-doctor` behavior,
idempotency/already-configured detection, and image-readiness credential
detection) — all run against fake/mocked external tools. Never invokes a
real Discord, OpenAI, Anthropic, or GitHub backend, and never creates AWS
resources.

## Non-goals for v0.1 (Milestone 0 through Milestone 2)

No runtime framework, no orchestrator process, no task state machine, no
Discord bot, no Claude Code runner, no monitor, no verifier. Those are
Milestones 3–7. Milestones 0–2 are documentation, repository scaffolding,
reproducible host/image bootstrap, and interactive connection UX only,
per `BUILD_DIRECTIVE.md` §12.
