# TASK.md — Defect-only repair after the first authorized Fresh EC2 runtime validation

Written per `WORK_PROTOCOL.md` §1 ("For every actionable request... Create
`TASK.md`"). This is the Context artifact for the change that repairs the
defect found by the first authorized Fresh EC2 runtime validation of
Milestone 1 + Milestone 2 (`MILESTONE2_DIRECTIVE.md` §11-§13,
`docs/FRESH_EC2_VALIDATION.md`). This is a defect repair, not a new
milestone: Milestone 2 remains complete within its documented
static/local evidence boundary, and Fresh EC2 runtime validation remains
incomplete pending a re-run against this fix.

## Goal

Fix the concrete defect that stopped the first real Fresh EC2 validation
run from proceeding past the Docker image build step, add deterministic
regression coverage proving the fix is bounded and does not weaken the
existing pinned-URL/checksum integrity gate, and record the actual run
honestly — including the parts that could not be exercised because the
build failed — without claiming any unperformed step as PASS.

## Context

- Baseline: repository HEAD `153a0f45c72b0d848d4b082230e7c3529606c046`
  (`feat(milestone-2): complete connection UX`), the same commit
  `docs/FRESH_EC2_VALIDATION.md` was written against.
- Run environment: a genuinely fresh, official Ubuntu 24.04 LTS (x86_64)
  AMI, `t3.small`, region `ap-northeast-2` — matching
  `docs/FRESH_EC2_VALIDATION.md` §1-§2's stated assumptions. Not a reused
  instance.
- `docs/FRESH_EC2_VALIDATION.md` §5 ("Exact bootstrap command") assumed an
  unauthenticated `git clone https://github.com/MoolMong/hermes-workstation-ssot.git`
  would succeed. It does not: the SSOT repository is private, so the plan
  as written was incomplete for the actual repository visibility. To
  continue diagnosis on the same run, without expanding scope into
  authenticated `git clone` UX work mid-run, a credential-free `git
  bundle` containing exactly the remote `main` SHA was transferred to the
  instance out-of-band. This is recorded as an explicit **validation
  process deviation**, not as a passing `git clone` step, and not as
  authorization to make the repository public (see `SECURITY.md`'s
  redistribution model and `CLAUDE.md` "Existing Factory/EC2" —
  visibility of the SSOT repository itself is an operator decision, not
  one this repair makes).
- The real defect: `docker compose build --no-cache` failed twice at the
  `docker/Dockerfile` `RUN` step that downloads the pinned Hermes Agent
  installer from its immutable, commit-scoped
  `raw.githubusercontent.com` URL — `curl -fsSL -o /tmp/hermes-install.sh
  "$HERMES_INSTALLER_URL"` — with HTTP 429, including on a retry attempted
  manually after waiting 60 seconds. The original `curl` invocation had no
  retry/backoff of its own, so a single transient rate-limit response
  failed the entire build.
- Everything upstream of the Docker build (AWS provisioning/SSH,
  `bootstrap/install.sh` first and second run, `docker compose config`,
  `hermes.service` staying disabled/inactive as Milestone 1 intends, data/
  config permissions, and a pre-connection, read-only `hermes-doctor` run)
  passed and is not touched by this repair — see
  `evidence/milestone-2-fresh-ec2/TEST_EVIDENCE.md` for the itemized
  results.
- No real account was connected and no credential was entered during the
  run; the run stopped at the build failure before `hermes-connect` would
  have been exercised.
- After the build failure was confirmed reproducible, the instance,
  security group, encrypted root EBS volume (`DeleteOnTermination=true`),
  and the local temporary SSH key used for the run were deleted per
  `docs/FRESH_EC2_VALIDATION.md` §10.

## Constraints

- Defect-only repair: fix the smallest change that makes the pinned
  installer download resilient to the observed transient HTTP 429/network
  failure class, with clear fail-closed behavior if retries are
  exhausted. Do not weaken the pinned commit URL or the SHA-256
  verification gate (`docker/Dockerfile`'s existing
  download-then-verify-then-execute ordering, covered by
  `tests/bootstrap/test_dockerfile_pins.sh`).
- Do not add a service, daemon, dependency, or new component
  (`CLAUDE.md` "Forbidden components").
- Do not implement Milestone 3+.
- Work only in this repository; no AWS, credential, old-EC2, Factory, or
  Codex access for this repair pass.
- Do not commit or push.
- Do not claim the bundle-based diagnostic clone was a `git clone` PASS,
  and do not claim any step after the build failure (real account
  connection, service start, Discord round-trip, restart/reboot) as
  PASS, FAIL, or anything other than **NOT RUN**.
- `docs/FRESH_EC2_VALIDATION.md` must be updated to handle a private SSOT
  explicitly (interactive GitHub authentication before clone, or an
  explicitly labeled provenance-verified bundle diagnostic path) without
  claiming authorization to make the repository public.
- Update `CHANGELOG.md`/`DEVIATIONS.md`/`README.md`/
  `DEFINITION_OF_DONE.md`/`MILESTONES.md` only as narrowly as needed to
  stay honest: Milestone 2 remains complete within its static/local
  boundary; Fresh EC2 validation remains incomplete (now with one real
  attempt recorded, BLOCKED at the build step, and the causing defect
  fixed).

## Acceptance Criteria

- `docker/Dockerfile`'s pinned-installer `curl` invocation gains a
  bounded `--retry`/`--retry-max-time`/`--retry-connrefused` policy (no
  fixed `--retry-delay`, so curl's own exponential backoff applies), with
  the pinned commit-scoped URL, `-fsSL` fail-closed behavior, and the
  download → checksum-verify → execute ordering all unchanged.
- `tests/bootstrap/test_dockerfile_pins.sh` still passes unmodified,
  proving the pin/URL/ordering invariants survive the fix.
- A new deterministic test proves the retry options are present and
  bounded (nonzero, not unbounded) and that the unrelated GitHub CLI
  keyring `curl` line was not touched by this narrowly-scoped fix.
- `evidence/milestone-2-fresh-ec2/TASK.md` (this file) and
  `TEST_EVIDENCE.md` record the actual first run's PASS/FAIL/BLOCKED
  results and the exact point the run stopped (cleanup boundary).
  `VERIFICATION.md` is created but left explicitly **PENDING** — this
  repair pass does not self-certify; a fresh independent verifier pass is
  still required.
- `docs/FRESH_EC2_VALIDATION.md` is updated to require either interactive
  GitHub authentication before `git clone`, or an explicitly labeled
  provenance-verified bundle diagnostic path — and explicitly states that
  a bundle transfer is not a `git clone` PASS and that converting the
  SSOT repository to public is not authorized by this repair.
- `CHANGELOG.md`, `DEVIATIONS.md`, `README.md`, `DEFINITION_OF_DONE.md`,
  `MILESTONES.md` are updated narrowly: Milestone 2 status unchanged
  (complete within its static/local boundary); Fresh EC2 validation
  status unchanged in substance (still not complete) but now reflects
  that one real attempt was made, what it found, and that the causing
  defect is fixed and awaiting re-validation.
- `bash tests/check_milestone0.sh`, `bash tests/bootstrap/run.sh`, and
  `bash tests/connection/run.sh` all exit 0. `git diff --check` reports no
  whitespace errors.
- No AWS action, no credential creation, no commit, no push is performed
  by this pass.

## Relevant Files

- `docker/Dockerfile` (fixed — installer `curl` line only)
- `tests/bootstrap/test_installer_retry.sh` (new)
- `evidence/milestone-2-fresh-ec2/TASK.md`, `TEST_EVIDENCE.md`,
  `VERIFICATION.md` (new)
- `docs/FRESH_EC2_VALIDATION.md` (updated)
- `ARCHITECTURE.md`, `CHANGELOG.md`, `DEVIATIONS.md`, `README.md`,
  `DEFINITION_OF_DONE.md`, `MILESTONES.md` (updated narrowly)

## Unknowns

- Whether the observed HTTP 429 was `raw.githubusercontent.com`-wide rate
  limiting, IP-based, or specific to the build window — not knowable
  without another live run, which is out of scope for this repair pass
  (no AWS access). The fix is written to tolerate any of these transient
  causes within a bounded retry budget rather than to diagnose the exact
  cause.
- Whether the private-SSOT `git clone` gap in
  `docs/FRESH_EC2_VALIDATION.md` §5 has been hit before this run — not
  recorded in any prior evidence file found in this repository; treated
  here as a real gap in the plan, not a one-off.

## Execution Mode

Sequential, single authoring context. The Dockerfile fix, its regression
test, the new evidence directory, and the narrow documentation updates
are small and mutually referential (the evidence file names the exact
defect the test proves is fixed), so splitting this across independent
workers would not have improved correctness or speed
(`WORK_PROTOCOL.md` §2-§3).

---

## Attempt 2 — second defect-only repair (this change)

Written for the second authorized Fresh EC2 runtime validation attempt,
run against repository HEAD `000f06b57d06a495236cad5682ffc0356bcc70de`
(the commit containing the attempt-1 retry fix, above, plus its
independently-verified `PASS` chronology in `VERIFICATION.md` Passes
1-3). Same defect-only repair discipline as attempt 1: Milestone 2
remains complete within its documented static/local boundary, and Fresh
EC2 runtime validation remains incomplete pending a re-run against this
fix.

### Goal

Fix the concrete new defect that stopped the second real Fresh EC2
validation run — which confirmed the attempt-1 retry fix works against a
real, live HTTP 429 sequence, then failed later in the same build step —
add deterministic regression coverage for the fix, and record the actual
attempt-2 run honestly, without claiming Docker build or runtime success
and without erasing the attempt-1 evidence or verification chronology.

### Context

- Baseline: repository HEAD `000f06b57d06a495236cad5682ffc0356bcc70de`
  (`fix: harden fresh EC2 bootstrap validation`), the attempt-1 repair
  commit.
- Run environment: official fresh Ubuntu 24.04 LTS (x86_64) AMI,
  `t3.small`; source delivered via the same SSH/provenance-matched bundle
  diagnostic path used in attempt 1 (not a `git clone` PASS claim), at
  the exact HEAD above.
- `docker compose build --no-cache` this time got past installer
  download: `raw.githubusercontent.com` returned HTTP 429 three times,
  the fourth attempt succeeded under the attempt-1 retry policy, the
  pinned installer checksum verified OK, and Python 3.11 was installed —
  proving the attempt-1 fix works live. The build then failed **exit
  127** immediately after `Downloading node-v26.7.0-linux-x64.tar.xz` /
  `Extracting to ~/.hermes/node/...`.
- The pinned installer source (`bootstrap/hermes-commit.pin`) was fetched
  and checksum-verified locally as part of this repair (no re-pin
  needed); its lines 952-956 call `tar xf`/`tar xzf` directly to extract
  downloaded archives.
- `docker/Dockerfile`'s prerequisite package stage installs `git curl
  xz-utils ca-certificates` but omits `tar`. `xz-utils` provides
  `xz`/`unxz`, not the `tar` binary itself — so the installer's own `tar`
  call failed with exit 127 (command not found) on the minimal,
  `--no-install-recommends` base image.
- Instance/security group/encrypted root EBS (`DeleteOnTermination=true`)
  /temporary SSH key were fully cleaned up after the failure was
  confirmed — same cleanup discipline as attempt 1.
- Account connection, service start, Discord round-trip, and
  restart/reboot were **NOT RUN** — the run stopped at the build failure
  before any of them could be reached.

### Constraints (same as attempt 1, restated for this pass)

- Defect-only repair: the smallest change that makes the pinned
  installer's archive extraction step succeed — adding the missing
  distro package it depends on — without weakening the pinned
  commit/checksum/URL gate or the attempt-1 retry policy.
- No AWS/network/credentials, Factory, or Codex access for this repair
  pass. No commit, push, or Milestone 3+ implementation.
- Do not claim Docker build/runtime PASS — this repair is deterministic
  and local only; a fresh, real re-run is still required.
- Preserve the attempt-1 evidence and `VERIFICATION.md` Passes 1-3 as-is;
  set the document's overall status to **PENDING** for a fresh verifier
  pass over this specific repair, without erasing the earlier PASS.

### Acceptance Criteria

- `docker/Dockerfile`'s prerequisite package stage includes `tar`
  alongside the existing `git curl xz-utils ca-certificates`, with no
  other line changed.
- A new deterministic test (`tests/bootstrap/test_installer_extract_deps.sh`)
  proves both `tar` and `xz-utils` are present in that exact pre-installer
  stage, that the stage runs before the pinned installer executes, and
  that the attempt-1 retry policy is untouched.
- `tests/bootstrap/test_dockerfile_pins.sh` and
  `tests/bootstrap/test_installer_retry.sh` still pass unmodified.
- `evidence/milestone-2-fresh-ec2/TEST_EVIDENCE.md` records the attempt-2
  itemized results, the new defect, the fix, and its regression evidence
  as an appended section — the attempt-1 section is preserved, not
  rewritten.
- `evidence/milestone-2-fresh-ec2/VERIFICATION.md` preserves Passes 1-3
  and records the attempt-2 repair as awaiting a fresh verifier pass;
  overall status set to **PENDING**.
- `CHANGELOG.md`, `README.md`, `MILESTONES.md`, `DEFINITION_OF_DONE.md`
  updated narrowly to reflect the second attempt and its fix, without
  changing Milestone 2's completion status or fabricating a Fresh EC2
  PASS.
- `bash tests/check_milestone0.sh`, `bash tests/bootstrap/run.sh`, and
  `bash tests/connection/run.sh` all exit 0. `git diff --check` reports no
  whitespace errors.
- No AWS action, no credential creation, no commit, no push is performed
  by this pass.

### Relevant Files (attempt 2)

- `docker/Dockerfile` (fixed — prerequisite package list only)
- `tests/bootstrap/test_installer_extract_deps.sh` (new)
- `evidence/milestone-2-fresh-ec2/TASK.md` (this section),
  `TEST_EVIDENCE.md`, `VERIFICATION.md` (updated)
- `CHANGELOG.md`, `README.md`, `MILESTONES.md`, `DEFINITION_OF_DONE.md`
  (updated narrowly)
