# Fresh EC2 validation — first real run — evidence

This is the evidence record for the **first authorized** Fresh EC2 runtime
validation of Milestone 1 + Milestone 2, run against the plan in
`docs/FRESH_EC2_VALIDATION.md` at repository HEAD
`153a0f45c72b0d848d4b082230e7c3529606c046`. It records what was actually
observed, including the failure that stopped the run and the exact
cleanup boundary. It is **not** a PASS claim for Fresh EC2 validation as a
whole — see "Overall result" below. Separately,
`evidence/milestone-2/TEST_EVIDENCE.md` and `evidence/milestone-2/
VERIFICATION.md` remain the evidence for Milestone 2's own static/local
completion and are not rewritten by this record
(`MILESTONE2_DIRECTIVE.md` §13: "create a separate evidence section
rather than rewriting history").

## Run environment

- AMI: official Ubuntu Server 24.04 LTS (x86_64), genuinely freshly
  launched — not a reused/pre-existing instance.
- Instance type: `t3.small`.
- Region: `ap-northeast-2`.
- Root EBS: encrypted, `DeleteOnTermination=true`.
- No credential was entered on the instance at any point during the run.

## Itemized results

Numbered against `MILESTONE2_DIRECTIVE.md` §12's required runtime
evidence list, plus the pre-clone step this run actually needed:

| # | Item | Result |
|---|---|---|
| 0 | AWS provisioning + SSH reachability | **PASS** |
| 0a | Unauthenticated `git clone https://github.com/MoolMong/hermes-workstation-ssot.git` | **FAIL** — the SSOT repository is private; anonymous HTTPS clone is rejected. `docs/FRESH_EC2_VALIDATION.md` §5 did not account for this at the time of this run. |
| 0b | Credential-free `git bundle` transfer (diagnostic continuation only) | Performed out-of-band, containing exactly the remote `main` SHA. Recorded explicitly as a **validation process deviation**, not as a `git clone` PASS — see `docs/FRESH_EC2_VALIDATION.md`'s updated §5 and `DEVIATIONS.md`. |
| 1 | Fresh instance bootstraps from the SSOT (`bootstrap/install.sh`, first run) | **PASS** |
| 2 | Bootstrap is repeatable/idempotent (`bootstrap/install.sh`, second run, stable hashes) | **PASS** |
| — | `docker compose config` | **PASS** |
| — | `hermes.service` stays disabled/inactive (Milestone 1 intent — no credentials exist pre-connection) | **PASS** (disabled, inactive, as designed) |
| — | `/opt/hermes-data` permissions `0700`, rendered config `0600` | **PASS** |
| — | Pre-connection `hermes-doctor` (byte-for-byte read-only) | **PASS** for its own read-only behavior. Reported: Docker **PASS**, Compose **PASS**, systemd unit validity **PASS**, required-command PATH checks **PASS**; all four integrations **NOT_CONFIGURED**/**BLOCKED** (correct — `hermes-connect` had not run yet); Hermes runtime **NOT_RUNNING** (correct — service intentionally not started yet); image-readiness **PASS**. |
| 3 | Docker/Compose runtime actually works | **BLOCKED** — see item 4. |
| 4 | Hermes image actually builds or pulls as designed | **FAIL** — `docker compose build --no-cache` failed **twice** at the `docker/Dockerfile` `RUN` step that downloads the pinned Hermes Agent installer from its immutable, commit-scoped `raw.githubusercontent.com` URL, with **HTTP 429**, including once after waiting 60 seconds before retrying manually. No credential was entered. This is the defect this change repairs. |
| 5 | systemd unit actually loads | **PASS** (unit loaded at bootstrap time, per item 1/2 — not re-verified post-build since the run stopped at item 4). |
| 6 | `hermes-connect` works with the user's integrations | **NOT RUN** — blocked by item 4; never reached. |
| 7 | credentials persist across relevant restart | **NOT RUN** |
| 8 | `hermes-doctor` reports correct state (post-connection) | **NOT RUN** beyond the pre-connection read-only pass above. |
| 9 | Hermes service starts | **NOT RUN** |
| 10 | Gateway starts | **NOT RUN** |
| 11 | Discord connects | **NOT RUN** |
| 12 | a real Discord message receives a real Hermes response | **NOT RUN** |
| 13 | service restart does not destroy credentials | **NOT RUN** |
| 14 | EC2 reboot returns the environment to the documented expected state | **NOT RUN** |
| 15 | no hidden manual fixes required | Not applicable — the run did not reach a state where this could be assessed; the one manual step taken (the bundle transfer, item 0b) is recorded as a deviation, not hidden. |
| — | Cleanup: instance, security group, encrypted root EBS (`DeleteOnTermination=true`), local temporary SSH key all deleted | **PASS** |

## Cleanup boundary

Cleanup was performed **after** the build failure was confirmed
reproducible (two failed `docker compose build --no-cache` attempts) and
**before** any further diagnosis or fix attempt on the live instance —
consistent with this repair being done entirely offline, in this
repository, with no AWS/credential/old-EC2/Factory/Codex access. No
instance, security group, or volume from this run remains.

## Overall result

**Fresh EC2 validation: BLOCKED at the Docker image build step (item 4).**
Items 0-2 and the pre-connection read-only diagnostics passed; items 3
and 4 failed (transient HTTP 429 on the pinned installer download, no
retry/backoff existed); items 5 is presumed unaffected but was not
re-verified after the point of failure; items 6-14 were never reached and
are **NOT RUN**, not FAIL. This is not a Milestone 2 regression — see
`evidence/milestone-2/TEST_EVIDENCE.md` and `evidence/milestone-2/
VERIFICATION.md`, which remain PASS for the static/local boundary they
cover. Fresh EC2 runtime validation as a whole remains **incomplete** and
requires a fresh, real re-run against the fix below before it can be
claimed PASS.

## The fix and its deterministic regression evidence

`docker/Dockerfile`'s pinned-installer `curl` invocation now sets bounded
`--retry 6 --retry-max-time 90 --retry-connrefused` (no fixed
`--retry-delay`, so curl's built-in exponential backoff — starting at 1
second, doubling per attempt — applies between attempts). This does not
touch the pinned commit-scoped URL, the `-fsSL` fail-closed flags, the
SHA-256 checksum verification, or the download → verify → execute
ordering — and does not touch the separate, unrelated GitHub CLI keyring
`curl` line.

Command:

```bash
bash tests/bootstrap/test_installer_retry.sh
```

Result: **PASS** (exit 0). All 16 checks passed: retry/backoff options
present and bounded, no fixed `--retry-delay`, `-fsSL` and the pinned URL
reference preserved, download/verify/execute ordering unchanged, and the
unrelated GitHub CLI keyring `curl` line confirmed untouched.

Command:

```bash
bash tests/bootstrap/test_dockerfile_pins.sh
```

Result: **PASS** (exit 0, unmodified from before this fix) — confirms the
pinned commit/SHA-256/URL/`--commit` invariants and the
download-then-verify-then-execute ordering are unaffected by the retry
addition.

Command:

```bash
bash tests/bootstrap/run.sh
```

Result: **PASS** (exit 0). 24 checks, 0 failures (previously 22; +2 from
the new `test_installer_retry.sh` syntax check and test-script run).

Command:

```bash
bash tests/connection/run.sh
```

Result: **PASS** (exit 0), unchanged by this repair — no Milestone 2
connection script was touched.

Command:

```bash
bash tests/check_milestone0.sh
```

Result: **PASS** (exit 0) — see the exact check count recorded in
`CHANGELOG.md` for this change.

Command:

```bash
git diff --check
```

Result: **PASS** (exit 0, no output).

## What this evidence does not claim

- This repair pass did not create, modify, or access any AWS resource,
  real credential, the old EC2, Factory, or Codex.
- This repair pass did not re-run the Fresh EC2 validation — the fix
  above is deterministically tested locally only. A fresh, real Fresh EC2
  run against this fix is still required before Fresh EC2 validation can
  be claimed PASS.
- `evidence/milestone-2-fresh-ec2/VERIFICATION.md` is intentionally left
  **PENDING** — no independent verifier pass has reviewed this repair
  yet.
