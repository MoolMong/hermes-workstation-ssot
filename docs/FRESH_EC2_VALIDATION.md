# Fresh EC2 end-to-end validation plan (Milestone 1 + Milestone 2)

This is the exact plan required by `MILESTONE2_DIRECTIVE.md` §11 for the
first real runtime validation of this repository:

```text
GitHub SSOT
  ↓
Fresh EC2
  ↓
bootstrap
  ↓
hermes-connect
  ↓
hermes-doctor
  ↓
Hermes service start
  ↓
Discord connection
  ↓
Discord hello/request
  ↓
Hermes response
```

**This document is a plan only. No AWS resource has been created or
modified to produce it.** Every static/local deterministic check this
repository can run without AWS has already been run and is recorded in
`evidence/milestone-2/TEST_EVIDENCE.md`; this plan covers only the
runtime steps that require a real EC2 instance, which remain
`NOT YET PERFORMED` (`MILESTONE2_DIRECTIVE.md` baseline) until the user
explicitly approves AWS resource creation (`MILESTONE2_DIRECTIVE.md` §11,
"Do not create or modify AWS resources yet").

## 1. Supported EC2 OS/AMI assumptions

- Base AMI: current **Ubuntu Server 22.04 LTS (x86_64)** or **24.04 LTS
  (x86_64)** official Canonical AMI in the target region. `bootstrap/install.sh`
  is fail-closed to `apt`-based Ubuntu/Debian hosts only (see
  `tests/bootstrap/test_fail_closed.sh`); it will abort with a nonzero
  exit on any other OS rather than silently proceeding.
- A stock AMI is required — **not** a pre-existing/reused instance or a
  snapshot with prior Hermes state. `MILESTONE2_DIRECTIVE.md` §12: "Do
  not validate by reusing the old EC2."
- Instance must be freshly launched for this validation; no manual
  pre-installed packages beyond what the AMI ships.

## 2. Minimum instance sizing assumption

- Instance type: **`t3.small`** (2 vCPU, 2 GiB RAM) as the minimum
  assumption for running Docker, the Hermes Agent container, and the
  bootstrap/connection tooling concurrently. `t3.micro` (1 GiB RAM) is
  not assumed sufficient headroom for a Docker image build plus a running
  container.
- Root EBS volume: **20 GiB gp3**, `DeleteOnTermination=true` so no
  orphaned volume survives cleanup.

## 3. Required inbound/outbound networking

- **Inbound**: SSH (TCP/22) from the operator's IP only (no `0.0.0.0/0`).
  No other inbound port is required — the Hermes Agent's Discord
  connection is outbound-only (a Discord bot client, not an inbound
  webhook listener), so no inbound port needs to be opened for Discord.
- **Outbound**: HTTPS (TCP/443) to:
  - `github.com` / `raw.githubusercontent.com` (SSOT clone, pinned
    installer fetch),
  - Docker Hub / the pinned base-image registry (`docker/Dockerfile`'s
    digest-pinned base image),
  - `discord.com` / Discord gateway endpoints (bot connection),
  - the OpenAI/Codex and Anthropic (Claude Code) API endpoints,
  - `api.github.com` (GitHub CLI authentication and API read check).
  Standard outbound-open security group (default AWS security group
  outbound rule) is sufficient; no additional outbound port needs opening
  beyond 443/80 for package repositories.

## 4. Required AWS IAM permissions, if any

- No AWS IAM role is required **on** the instance — this design does not
  call any AWS API from inside the workstation (`BUILD_DIRECTIVE.md`
  forbidden-components list has no AWS SDK/orchestration dependency).
- The **operator's own** IAM principal (used from their local machine or
  CI to provision the instance) needs standard EC2 lifecycle permissions
  only: `ec2:RunInstances`, `ec2:TerminateInstances`, `ec2:Describe*`,
  `ec2:CreateSecurityGroup`/`ec2:AuthorizeSecurityGroupIngress` (for the
  SSH-only rule in §3), and `ec2:CreateTags`. No IAM role/policy creation
  for the instance itself is required.

## 5. Exact bootstrap command

From an SSH session on the fresh instance, as a user with `sudo`:

```bash
git clone https://github.com/MoolMong/hermes-workstation-ssot.git
cd hermes-workstation-ssot
sudo bootstrap/install.sh
```

`install.sh` is idempotent (`tests/bootstrap/test_idempotency.sh`); running
it a second time must converge with no further changes.

## 6. Exact connection flow

```bash
bootstrap/connect.sh
```

Run with no flags to walk all four integrations in order (Discord,
OpenAI/Codex, Claude Code, GitHub), per `bootstrap/connect.sh`'s
documented UX (`MILESTONE2_DIRECTIVE.md` §2's target transcript). Each
integration prompts only for what that integration requires, validates
immediately after configuration, and prints PASS/FAIL. A single
integration may be reconfigured in isolation:

```bash
bootstrap/connect.sh --discord
bootstrap/connect.sh --openai
bootstrap/connect.sh --claude
bootstrap/connect.sh --github
bootstrap/connect.sh --reconnect   # forces reconfiguration of an already-healthy integration
```

Required user-provided values for Discord (per `bootstrap/connect.sh`'s
prompts and `SECURITY.md` §3): a Discord bot token and at least one
allow-list entry (`DISCORD_ALLOWED_USERS`/`_ROLES`/`_CHANNELS`) — the tool
refuses an allow-all configuration.

## 7. Enable and start the Hermes service

`install.sh` installs and `daemon-reload`s `systemd/hermes.service` but
deliberately never enables or starts it (Milestone 1 constraint — no
credentials exist yet at that point). After `connect.sh` succeeds:

```bash
sudo systemctl enable --now hermes.service
sudo systemctl status hermes.service
```

## 8. Exact health checks

```bash
bootstrap/doctor.sh
```

Expected all-PASS output shape (`MILESTONE2_DIRECTIVE.md` §7):

```text
Hermes Workstation Doctor

Docker           PASS
Hermes service   PASS
Gateway          PASS
Discord          PASS
OpenAI           PASS
Claude Code      PASS
GitHub           PASS
Disk             PASS
```

Then the live Discord round-trip:

1. From a Discord client the operator controls, send a message the bot is
   configured to respond to (a "hello"/simple request) in an allow-listed
   channel to the connected bot/application.
2. Observe a Hermes response in that channel within a bounded time window
   (document the observed latency in the evidence file for this step —
   no fixed SLA is asserted by this plan).
3. `sudo journalctl -u hermes.service --since "5 minutes ago"` shows the
   inbound Discord event and outbound response with no credential values
   in the log output (`SECURITY.md` §2 — secrets never printed/logged).

## 9. Expected PASS evidence

For each of the 15 numbered items in `MILESTONE2_DIRECTIVE.md` §12,
record one of `PASS` / `FAIL` / `BLOCKED` with supporting command output
(redacted of any secret value) in a new
`evidence/milestone-2-fresh-ec2/` directory created at the time this
validation is actually run (`MILESTONE2_DIRECTIVE.md` §13: "create a
separate evidence section rather than rewriting history"). At minimum:

- bootstrap completes and is idempotent (re-running `install.sh` a second
  time makes no further changes),
- `docker compose config` / `docker compose up -d` (or systemd-driven
  equivalent) actually builds/pulls and starts the container,
- `systemctl status hermes.service` shows the unit loaded and active,
- `bootstrap/connect.sh` succeeds for all four integrations against the
  operator's real accounts,
- credentials under `/opt/hermes-data` survive `systemctl restart
  hermes.service` and a full `sudo reboot`,
- `bootstrap/doctor.sh` reports all-PASS post-reboot,
- a real Discord message receives a real Hermes response,
- no manual intervention outside the documented commands in this plan was
  required — any manual step found necessary is a defect in the SSOT to
  be fixed, not documented as an accepted one-off (`MILESTONE2_DIRECTIVE.md`
  §12).

## 10. Cleanup procedure

After evidence is captured:

```bash
# From the operator's machine, not the instance itself:
aws ec2 terminate-instances --instance-ids <instance-id>
aws ec2 delete-security-group --group-id <security-group-id>   # if created solely for this test
```

Confirm via `aws ec2 describe-instances --instance-ids <instance-id>` that
the instance reaches `terminated` state, and that the root EBS volume
(`DeleteOnTermination=true`, §2) is removed with it, leaving no orphaned
chargeable resource.

## 11. Expected AWS cost-impacting resources

- One EC2 instance (`t3.small` or larger, §2) for the duration of the
  test — on-demand hourly cost, terminated at cleanup (§10).
- One 20 GiB gp3 EBS root volume, deleted with the instance
  (`DeleteOnTermination=true`).
- Negligible data-transfer cost for package downloads, the container base
  image pull, and Discord/API traffic during the test window.
- No Elastic IP, load balancer, RDS, or other standing chargeable
  resource is part of this plan. No CloudWatch alarms are created.

## STOP — AWS approval required

**Do not create or modify any AWS resource under this plan until the user
explicitly approves it.** This includes launching the EC2 instance,
creating/modifying the security group, and any IAM change. Once approved,
perform the steps in §5–§9, then execute §10 cleanup, and record results
under a new `evidence/milestone-2-fresh-ec2/` directory rather than
editing this plan or `evidence/milestone-2/` after the fact.
