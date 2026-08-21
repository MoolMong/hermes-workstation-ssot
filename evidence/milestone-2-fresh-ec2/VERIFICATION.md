# Fresh EC2 validation (first run) + defect repair — independent verification

This file is the durable chronological record for independent semantic
verification of the first Fresh EC2 validation run and the defect repair
that followed it, matching the format used by
`evidence/milestone-0/VERIFICATION.md`, `evidence/milestone-1/
VERIFICATION.md`, and `evidence/milestone-2/VERIFICATION.md`.
Deterministic command evidence is separate, at
`evidence/milestone-2-fresh-ec2/TEST_EVIDENCE.md`.

## Status: PASS

The latest chronological pass below is Pass 4: a genuinely fresh,
independent, read-only Claude Code session returned explicit
`VERDICT: PASS` for the attempt-2 `tar` prerequisite repair. Pass 3 remains
the independent PASS for the earlier retry repair; earlier failures remain
recorded for evidence integrity.

## Pass 1 — 2026-08-21 — FAIL (non-actionable output)

A fresh read-only verifier returned only `VERDICT: FAIL` without the
required concrete defect list. This was not treated as a PASS and was not
used as a repair specification.

## Pass 2 — 2026-08-21 — FAIL

A second fresh, read-only forensic verifier identified two concrete
documentation-consistency defects:

1. `CHANGELOG.md` did not record the observed HTTP 429 failure, bounded
   retry repair, or current deterministic check counts even though the
   evidence cited it.
2. `DEVIATIONS.md` did not record the provenance-verified Git bundle used
   solely to continue diagnosis after unauthenticated clone of the private
   SSOT failed, even though `TASK.md` and `TEST_EVIDENCE.md` cited that
   deviation.

A defect-only repair updated only those two files. It did not alter code,
tests, runtime evidence, or milestone status.

## Pass 3 — 2026-08-21 — PASS

Verifier identity and isolation: a genuinely fresh Claude Code 2.1.233
print-mode session restricted to `Read` and `Bash`, with no session
persistence and no permission to edit, commit, push, access credentials,
or invoke AWS/network operations.

Independent deterministic reruns:

- Milestone 0: **57/57 PASS**
- Milestone 1/bootstrap: **24/24 PASS**
- Milestone 2/connection: **18/18 PASS**
- `git diff --check`: **PASS**, no output

Semantic review confirmed:

- installer download retries are bounded by `--retry 6` and
  `--retry-max-time 90`, preserve curl's exponential backoff, and leave the
  immutable commit-scoped URL, pinned commit, checksum, and
  checksum-before-execution ordering unchanged;
- the new retry regression test is scoped to that installer download and
  does not weaken fail-closed behavior;
- Fresh EC2 evidence honestly marks unauthenticated private-repository
  clone and Docker build as FAIL, later account/runtime/reboot checks as
  NOT RUN, and resource cleanup as PASS;
- the Git bundle is documented only as a provenance-verified diagnostic
  transfer matching `origin/main`, not as a GitHub clone PASS or a
  production bootstrap design;
- no secret-shaped values, private keys, AWS account/instance/security
  group IDs, or IP addresses are present in the repository diff;
- no Milestone 3+ implementation or forbidden component was introduced;
- Milestone 2 remains complete only within its prior static/local boundary,
  while the full Fresh EC2 validation remains incomplete.

**Final verifier line:** `VERDICT: PASS`

## Pass 4 — 2026-08-21 — PASS

Verifier identity and isolation: a new Claude Code 2.1.233 print-mode
session restricted to `Read` and `Bash`, with no session persistence and no
permission to edit, commit, push, access credentials, or invoke AWS/network
operations.

Independent deterministic reruns:

- Milestone 0: **57/57 PASS**
- Milestone 1/bootstrap: **26/26 PASS**
- Milestone 2/connection: **18/18 PASS**
- `git diff --check`: **PASS**, no output

Semantic review confirmed:

- `tar` and `xz-utils` are installed together in the exact prerequisite
  package stage before the pinned installer executes;
- `tests/bootstrap/test_installer_extract_deps.sh` meaningfully checks the
  package presence and ordering and reports eight passing assertions;
- the immutable URL, commit pin, checksum-before-execution ordering, and
  bounded retry policy are unchanged;
- Attempt 2 evidence and cleanup claims are honest, all later account and
  runtime steps remain NOT RUN, and Fresh EC2 completion remains unchecked;
- README, milestones, Definition of Done, and changelog now consistently
  describe Attempt 2 without fabricating Docker/runtime PASS;
- no secrets, AWS resource IDs, IP addresses, Milestone 3+ implementation,
  or forbidden components were introduced.

**Final verifier line:** `VERDICT: PASS`
