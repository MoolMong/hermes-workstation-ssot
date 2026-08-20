# Milestone 1 deterministic test evidence

Date: 2026-08-20
Scope: Milestone 1 implementation checks only. This record is **not** an
independent semantic-verifier verdict.

## Deterministic suite

Command:

```bash
bash tests/bootstrap/run.sh
```

Result: **PASS** (exit 0). The runner reported 22 checks, 0 failures, and
`RESULT: PASS`: 12 Bash syntax checks plus 10 focused bootstrap regression
tests.

Command:

```bash
bash tests/check_milestone0.sh
```

Result: **PASS** (exit 0). The milestone-aware historical regression runner
reported 57 checks, 0 failures, and `RESULT: PASS`.

Command:

```bash
for f in bootstrap/install.sh docker/entrypoint.sh tests/bootstrap/*.sh tests/check_milestone0.sh; do bash -n "$f" || exit 1; done
```

Result: **PASS** (exit 0), 14 shell files checked.

Command:

```bash
git diff --check
```

Result: **PASS** (exit 0, no output).

## Immutable upstream installer integrity

The immutable URL was downloaded to a temporary file without execution:

```text
https://raw.githubusercontent.com/NousResearch/hermes-agent/044acf2bf700b8452e903f035406091146eb0245/scripts/install.sh
```

`sha256sum` returned:

```text
0582d9b1562efcb6e0ac62f4451021667830b830a72ce7d91eaea9fee8b6c09b
```

This exactly matched the non-comment value in
`bootstrap/hermes-installer.sha256`; result: **PASS**. The temporary file was
removed by the command trap and was never executed.

## Static Compose validation

`docker compose config --no-interpolate` was attempted without starting or
building containers. Result: **UNAVAILABLE** because this execution
environment does not provide both the Docker CLI and Compose command. The
pure static Compose contract is covered by
`tests/bootstrap/test_docker_compose.sh`, but that is not equivalent to a
real Compose parser or runtime test.

## Runtime and deployment gates

- Fresh EC2 bootstrap: **BLOCKED**. Provisioning a fresh/chargeable AWS
  instance was not authorized, so no fresh-EC2 PASS is claimed.
- Docker image build and isolated container runtime: **BLOCKED** in this
  run. The required Docker/Compose tooling was unavailable, and the task
  forbade touching the existing Docker socket/runtime. No image or container
  was created.
- systemd activation: intentionally **NOT RUN**. Milestone 1 installs and may
  daemon-reload the unit but must not enable/start it before Milestone 2
  credentials exist.

## Evidence boundary

These results establish deterministic implementation checks only. Milestone
1 is not complete until a fresh independent read-only verifier reviews the
final diff and returns PASS; that verdict must be recorded separately.
