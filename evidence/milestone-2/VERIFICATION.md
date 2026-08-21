# Milestone 2 independent verification

This file is the durable chronological record for Milestone 2 semantic
verification, matching the format used by
`evidence/milestone-0/VERIFICATION.md` and
`evidence/milestone-1/VERIFICATION.md`. Deterministic command evidence is
separate at `TEST_EVIDENCE.md`.

## Status: PASS

The latest chronological pass below is Pass 3: a genuinely fresh,
independent, read-only Claude Code session returned explicit
`VERDICT: PASS` after independently rerunning the deterministic gates and
reviewing every Milestone 2 directive requirement. Earlier FAIL/BLOCKED
attempts remain below for evidence integrity.

## Pass 1 — 2026-08-20 — FAIL

A fresh read-only Claude Code verifier independently reran all deterministic
gates (M0 57/57, M1 22/22, M2 18/18, `git diff --check`) and found three
documentation-consistency defects: `config/github.env.example`,
`config/hermes.config.example.yaml`, and `SECURITY.md` §4 incorrectly
described integration-specific `config/*.env` files as runtime credential
locations. The verifier returned `VERDICT: FAIL`. Those three defects were
then repaired to point only to the official bind-mounted locations in
`SECURITY.md` §3.

## Pass 2 attempt — 2026-08-20 — BLOCKED

The required fresh read-only re-verification was invoked after repair, but
Claude Code returned `You've hit your session limit · resets 3:20am (UTC)`
before beginning a review. This is an external quota blocker, not a PASS.
No commit or push is permitted until a later fresh verifier returns PASS.
The working tree and all repairs have been preserved; deterministic gates
were rerun after repair, with the final M0 placeholder-marker defect fixed
immediately afterward and queued for the same future verification pass.

## Pass 3 — 2026-08-21 — PASS

Verifier identity and isolation: a genuinely fresh Claude Code 2.1.233
print-mode session, restricted to `Read` and `Bash`, with no session
persistence and no permission to edit, commit, push, authenticate, invoke
Docker/systemd/AWS, access real credentials, or use Factory/Codex.

Inputs reviewed: `BUILD_DIRECTIVE.md`, `MILESTONE2_DIRECTIVE.md`,
`evidence/milestone-2/TASK.md`, the complete baseline-to-working-tree diff,
all Milestone 2 implementation/tests/docs, and prior evidence.

Independent deterministic reruns:

- Milestone 0: **57/57 PASS**
- Milestone 1: **22/22 PASS**
- Milestone 2: **18/18 PASS**
- repository-wide Bash syntax: **PASS**, no syntax failures
- `git diff --check`: **PASS**, no output

Semantic review confirmed: all four integrations have supported setup and
validation paths; already-healthy skip/reconnect behavior; secret-safe
handling and documented persistent paths/permissions; Discord allow-list
safety; OpenAI/Codex no-fake-fallback; Claude authentication plus bounded
real invocation smoke; GitHub HTTPS helper/API/optional remote-read path;
read-only `hermes-doctor`; image-readiness credential detection; exactly
one Compose service running `hermes gateway run`; statically prepared image
tooling; no Milestone 3+ or forbidden component; and honest NOT RUN/BLOCKED
claims for real-account, Docker/systemd runtime, Fresh EC2, and AWS gates.

The verifier explicitly rechecked the three Pass 1 defects and confirmed
that `config/github.env.example`, `config/hermes.config.example.yaml`, and
`SECURITY.md` §4 now identify templates as non-runtime while `SECURITY.md`
§3 remains the authoritative runtime credential-path inventory. Its scan
found no token-shaped secret, private-key block, or hard-coded Discord ID.

Limitations: this was deliberately a credential-free static/deterministic
review. It did not invoke Docker, systemd, AWS, or real external accounts.
Those runtime gates remain NOT RUN/BLOCKED and are not part of the claimed
PASS.

**Final verifier line:** `VERDICT: PASS`
