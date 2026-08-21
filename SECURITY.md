# Security

This document is the threat model, secret model, and credential-location
inventory required by `BUILD_DIRECTIVE.md` §8 and §11. It is a Milestone 0
design document: nothing described here as "will store" or "will read" is
implemented yet. Every location below is called out precisely so that
later milestones — and the Milestone 7 image-readiness check — have a
concrete, non-negotiable checklist to validate against instead of an
after-the-fact guess.

## 1. Threat model

### In scope

- **Secret leakage into the distributable image/AMI.** The base image
  must never carry Discord tokens, OpenAI OAuth/session credentials,
  Claude credentials, GitHub credentials, user memory, conversation/session
  DBs, personal repositories, private SSH keys, shell history containing
  secrets, or task logs containing private content (`BUILD_DIRECTIVE.md`
  §8).
- **Secret leakage into Worker prompts.** Claude Code workers must not
  receive credentials they do not need to complete a task
  (`BUILD_DIRECTIVE.md` §11, "Never expose secrets to Worker prompts
  unnecessarily").
- **Secret leakage into logs.** `worker.log`, Discord messages, and
  `state.json` must never contain raw credential values.
- **Unauthorized high-impact actions.** Production deployment, destructive
  cloud operations, resource deletion, credential changes, broad IAM
  changes, irreversible migration, and merges to protected branches
  require explicit user approval — they are never default-automatic.
- **Forbidden-path modification.** A worker changing files outside its
  approved workspace, or touching paths declared off-limits for a task,
  must be caught by the Verifier's forbidden-path check, not discovered
  after the fact.
- **Silent task failure.** A Worker or Runner going quiet (crash, stall)
  must not be misreported as success. This is a safety property, not just
  a UX one: silent success reporting on a failed/incomplete change is a
  path to shipping unreviewed or unverified code.
- **A worker self-declaring completion.** Only the Verifier may set
  `COMPLETED`. A compromised or confused worker claiming success must not
  be trusted.

### Out of scope for this repository

- Physical/host security of the EC2 instance itself (AWS/OS responsibility,
  standard hardening applies, not re-specified here).
- Security of third-party services (Discord, OpenAI, Anthropic, GitHub)
  beyond how this project stores and uses credentials for them.
- Multi-tenant isolation — this is a **personal, single-operator**
  workstation by design (`BUILD_DIRECTIVE.md` mission statement).

## 2. Secret model

Principles, binding from Milestone 1 onward:

1. **Secrets never live in this Git repository.** Only `*.example` files
   with placeholder values are committed. Real credential files are
   git-ignored (see `.gitignore`) and created only on the target instance.
2. **Secrets are created only after `hermes-connect` runs on a real,
   recipient-owned instance.** The base image ships with zero credentials.
3. **Secrets are never printed to screen or logs.** `hermes-connect` and
   `hermes-doctor` show PASS/FAIL per integration, never the credential
   value.
4. **Secrets are not exposed to Worker prompts unless a task concretely
   requires that specific credential**, and even then the minimum
   necessary scope is used.
5. **Image sanitization is a hard gate, not a best-effort cleanup.**
   Milestone 7 must implement a check that *refuses to declare an image
   ready* if any known credential/session path (enumerated in §3 below) is
   populated. Deleting a few obvious token files is explicitly insufficient
   (`BUILD_DIRECTIVE.md` §8) — the check must walk the full location list.

## 3. Credential-bearing locations

This is the authoritative list every later milestone and the image-
readiness check must reference. It will grow only if a milestone
concretely introduces a new credential-bearing path, and any such addition
must be reflected here in the same change.

As implemented in Milestone 2, every path below is inside the single
bind-mounted data volume, host `/opt/hermes-data` → container `/data`
(`HERMES_HOME=/data`, `docker/docker-compose.yml`). `bootstrap/
connect-common.sh`'s `credential_paths()` function is the single source of
truth in code for this list — `hermes-doctor`'s image-readiness check and
`hermes-connect`'s "already configured" detection both read it from there
so this table and the implementation cannot silently drift apart
(`tests/connection/test_image_readiness.sh` checks the two stay
consistent).

| Location (actual) | Holds | Introduced by | Must be absent from base image |
|---|---|---|---|
| `/opt/hermes-data/.env` | Discord bot token (`DISCORD_BOT_TOKEN`) and the Discord allow-list (`DISCORD_ALLOWED_USERS`/`_ROLES`/`_CHANNELS`, `DISCORD_ALLOW_ALL_USERS`) — the exact env vars the upstream Hermes Agent Discord platform plugin reads, auto-loaded by the `hermes` CLI at startup | Milestone 2 (`hermes-connect --discord`) | Yes |
| `/opt/hermes-data/auth.json` | The Hermes Agent CLI's own pooled-credential store (`hermes auth add/status`), including OpenAI/Codex OAuth/session state | Milestone 2 (`hermes-connect --openai`, via `hermes auth add openai-codex --no-browser`) | Yes |
| `/opt/hermes-data/config.yaml` | Non-secret Hermes Agent configuration; must never itself hold raw secret values — secrets belong in `.env`/`auth.json`/`auth/`, not here | Milestone 1 (rendered), read by Milestone 2 tooling | Yes (rendered config only; must not contain real values) |
| `/opt/hermes-data/auth/claude/` | Claude Code CLI credentials/session state — container `CLAUDE_CONFIG_DIR` and `HOME` are both set to `/data/auth/claude` (`docker/Dockerfile`), so this is Claude Code's real, official persistent credential directory, not a guess | Milestone 2 (`hermes-connect --claude`, via `claude setup-token`) | Yes |
| `/opt/hermes-data/auth/github/gh/` | GitHub CLI auth (`gh auth login --hostname github.com --git-protocol https --web`) — container `GH_CONFIG_DIR` | Milestone 2 (`hermes-connect --github`) | Yes |
| `/opt/hermes-data/auth/github/.gitconfig` | Git HTTPS credential-helper config written by `gh auth setup-git` — container `GIT_CONFIG_GLOBAL` | Milestone 2 (`hermes-connect --github`) | Yes |
| `/opt/hermes-data/tasks/TASK-<id>/worker.log` | May incidentally contain private task content (not credentials by design, but must be excluded from any image/export regardless) | Milestone 3 | Yes |
| `/opt/hermes-data/workspaces/` | Personal repositories cloned/worked on by workers | Milestone 3 | Yes |
| `/opt/hermes-data/backup/` | Backups of the above — inherits the same sensitivity | Milestone 1 (concept), populated from Milestone 3 | Yes |
| Shell history on the instance (e.g. `~/.bash_history`) | May capture secrets if a user pastes a token on the command line | N/A (host-level risk) | Yes — must be checked/cleared before imaging |
| Private SSH keys used for Git operations on the instance | Not used by this design — GitHub access is HTTPS + the `gh` credential helper only (`MILESTONE2_DIRECTIVE.md` §6: "Do not add SSH key management unless it is actually required"); kept as a standing exclusion in case an operator adds one manually | N/A | Yes, if present |

`hermes-connect` never writes to `config/*.env` in this repository/instance
checkout — those files are git-ignored, `*.example`-documented references
only (see each `config/*.env.example` file); the real, git-ignored
persistence lives entirely under `/opt/hermes-data/`, per the table above.

`hermes-doctor`'s image-readiness check (`bootstrap/doctor.sh`, backed by
`credential_paths()` in `bootstrap/connect-common.sh`) walks exactly the
paths in this table (all four rows marked Milestone 2) and refuses to
report the instance image-safe if any is populated.

## 4. `config/*.example` files in this repository

The `config/` directory in this repository (see `ARCHITECTURE.md` §6)
contains only historical/design reference `*.example` files with
placeholder values such as `REPLACE_ME`. Milestone 2 does **not** copy or
populate integration-specific `config/*.env` files: `hermes-connect`
writes only the official persistent locations inventoried in §3 under the
bind-mounted `/opt/hermes-data`. The bootstrap renders the non-secret
`config.yaml` separately. No `*.example` file may contain a real token,
key, or credential-shaped string —
`tests/check_milestone0.sh` checks this deterministically (pattern-based,
not exhaustive; human review still applies).

## 5. Safety boundaries (restated from `BUILD_DIRECTIVE.md` §11)

Default automatic actions: inspect files, edit code in an approved
workspace, run tests, lint, local build, local verification.

Actions requiring explicit user approval: production deployment,
destructive cloud operations, deleting repositories/resources, changing
credentials, broad IAM changes, irreversible migration, merge to protected
branch.

Git commit/push behavior must be configurable and clearly documented once
implemented (Milestone 1+). As of Milestone 0, this repository has no
automation that commits or pushes on anyone's behalf.

## 6. EC2-level recovery and IAM

Per `BUILD_DIRECTIVE.md` §5, any AWS-side recovery mechanism (e.g.
instance auto-recovery, EventBridge + Lambda, Auto Scaling Group of size
1) is **optional**, must use least-privilege IAM, must not silently create
chargeable or account-wide AWS resources, and must be an explicit,
documented setup step if it requires permissions/infrastructure outside
the AMI. This is not designed yet — it belongs to Milestone 5 (service
recovery) and Milestone 7 (image readiness) and will be specified there
before any IAM policy is written.

## 7. Reporting

This is a personal, single-operator project with no external users at
Milestone 0. There is no public vulnerability-disclosure process yet; one
should be added if/when this repository is shared beyond its original
operator.
