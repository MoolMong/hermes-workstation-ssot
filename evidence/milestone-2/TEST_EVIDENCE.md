# Milestone 2 deterministic test evidence

Date: 2026-08-21 (final pre-integration rerun at 03:26 UTC / 12:26 KST)
Scope: Milestone 2 implementation checks only. This record is **not** an
independent semantic-verifier verdict — see `VERIFICATION.md`, whose fresh
Pass 3 returned **PASS**. All checks below are static and/or run against
fake/mocked external tools (`tests/connection/lib_fakebin.sh`); none used
a real Discord/OpenAI/Anthropic/GitHub account or a real EC2 instance.

## Deterministic suite — Milestone 2 connection tests

Command:

```bash
bash tests/connection/run.sh
```

Result: **PASS** (exit 0). Final rerun reported 18 checks, 0 failures, and
`RESULT: PASS`: 11 Bash syntax checks (`bootstrap/connect.sh`,
`bootstrap/connect-common.sh`, `bootstrap/doctor.sh`,
`tests/connection/lib_fakebin.sh`, and 7 `tests/connection/test_*.sh`
files) plus the 7 connection test scripts themselves
(`test_claude.sh`, `test_discord.sh`, `test_doctor_readonly.sh`,
`test_github.sh`, `test_idempotency.sh`, `test_image_readiness.sh`,
`test_openai.sh`).

What that suite covers, per `MILESTONE2_DIRECTIVE.md` §9:

- shell syntax (all M2 scripts),
- config rendering (`$HERMES_HOME/.env`, `config.yaml`, `auth.json`
  writes exercised by `test_discord.sh`/`test_openai.sh`),
- exact official commands (`hermes auth add openai-codex --no-browser`,
  `hermes auth status openai-codex`, the interactive `hermes model` picker,
  and a real `hermes -z` provider/model smoke; `claude setup-token`,
  `claude auth status`, `claude --version`, and a real bounded `claude -p`
  smoke; `gh auth login`/`gh auth status`, `gh auth setup-git`, `gh api
  user`, and `git ls-remote` — asserted via the fakebin call log in each
  `test_*.sh`),
  idempotency / already-configured detection (`test_idempotency.sh`),
- missing-config and failure behavior (each `test_*.sh`'s FAIL-path
  assertions),
- permissions (`0600`/`0700` assertions in `test_discord.sh` and
  `test_image_readiness.sh`),
- secret redaction (`test_discord.sh` asserts the token only ever reaches
  `curl` through a `0600` config file, never argv/stdout/stderr),
- `hermes-doctor` read-only behavior (`test_doctor_readonly.sh` —
  before/after filesystem snapshot plus no mutating fakebin subcommand
  called),
- image-readiness credential detection, cross-checked against
  `SECURITY.md` §3 (`test_image_readiness.sh`),
- exactly one Compose service running `hermes gateway run`
  (`tests/bootstrap/test_docker_compose.sh`, part of the Milestone 1
  suite below, re-verified here as still passing).

## Deterministic suite — Milestone 1 regression

Command:

```bash
bash tests/bootstrap/run.sh
```

Result: **PASS** (exit 0). Final rerun reported 22 checks, 0 failures, and
`RESULT: PASS`, including `tests/bootstrap/test_no_m3_scope.sh` (no
Milestone 3+ path exists; exactly one systemd unit; `connect.sh`/
`doctor.sh` legitimately exist now) and `test_docker_compose.sh` (exactly
one Compose service, `command: ["hermes", "gateway", "run"]`,
`restart: "no"`).

## Deterministic suite — Milestone 0 regression

Command:

```bash
bash tests/check_milestone0.sh
```

Result: **PASS** (exit 0). Final rerun reported 57 checks, 0 failures,
`RESULT: PASS`,
including the milestone-aware tree-consistency check now confirming
`MILESTONES.md` marks Milestone 2 as not-`Planned` while Milestone 3
remains `Planned`, and that every Milestone-0-through-2
`ARCHITECTURE.md`-declared path (including `docs/FRESH_EC2_VALIDATION.md`
and the three `evidence/milestone-2/` files, created by this pass) exists
on disk.

## Full syntax check

Command:

```bash
for f in bootstrap/*.sh docker/entrypoint.sh tests/bootstrap/*.sh \
         tests/connection/*.sh tests/check_milestone0.sh; do
  bash -n "$f" || echo "SYNTAX FAIL: $f"
done
```

Result: **PASS** — all 26 shell files selected by the final repository-wide
syntax sweep passed with no syntax failure.

## Whitespace check

Command:

```bash
git diff --check
```

Result: **PASS** (exit 0, no output).

## Final scope and secret scans

The final pre-integration run enumerated 61 tracked/untracked candidate
files and searched for private-key headers and real-looking GitHub, AWS,
Discord, Anthropic, and OpenAI credential shapes. Result: **PASS**, zero
hits. Separate forbidden-path/component-hint checks found no Milestone 3+
Runner/Monitor/Verifier state paths and no newly introduced runtime/package
component manifest. Result: **PASS**. No candidate secret values are
reproduced in this evidence record.

## What was not run and why

- **Real Discord/OpenAI/Claude Code/GitHub account connection**: not
  attempted. `MILESTONE2_DIRECTIVE.md` and this task's operating
  instructions forbid using real credentials in this authoring pass; all
  seven `tests/connection/test_*.sh` scripts validate the exact official
  commands and config-writing/permission/redaction behavior against a
  fakebin sandbox instead (`tests/connection/lib_fakebin.sh`). Result:
  **NOT RUN (by design)**.
- **Fresh EC2 provisioning and runtime validation**
  (`docs/FRESH_EC2_VALIDATION.md`, `MILESTONE2_DIRECTIVE.md` §11–§12): no
  AWS resource was created or modified by this pass. Result: **NOT
  PERFORMED**, per the explicit instruction not to touch AWS without
  prior user approval.
- **Docker image build / container runtime / systemd
  enable+start**: not exercised in this pass — this execution
  environment does not provide Docker/systemd runtime access, and
  Milestone 1's own evidence already records this boundary
  (`evidence/milestone-1/TEST_EVIDENCE.md`, "Runtime and deployment
  gates"). Result: **BLOCKED**, same boundary as Milestone 1, not
  widened or narrowed by Milestone 2.

## Evidence boundary

These results establish deterministic, credential-free implementation
checks only. Independent semantic verification is recorded separately in
`VERIFICATION.md` and returned PASS. Fresh EC2/runtime validation remains
NOT RUN and must be recorded separately after explicit approval to create
AWS resources; `MILESTONE2_DIRECTIVE.md` §10 and line 320 explicitly do not
permit that unperformed runtime gate to be claimed as part of this M2 PASS.
