# Hermes Workstation — Milestone 2 + First End-to-End Validation Directive

Continue the `hermes-workstation-ssot` project from the current verified Milestone 1 state.

Current baseline:
- Repository: `MoolMong/hermes-workstation-ssot`
- Branch: `main`
- Milestone 1 commit: `3f649c3707cefceb2f4382043e2a29092527432b`
- Milestone 1 static/bootstrap verification: PASS
- Fresh EC2 runtime validation: NOT YET PERFORMED
- Docker/Compose runtime validation: NOT YET PERFORMED
- systemd runtime validation: NOT YET PERFORMED

The next objective is:

1. implement **Milestone 2 — Connection UX**,
2. independently verify it,
3. commit and push it,
4. prepare a reproducible **Fresh EC2 end-to-end validation** for Milestone 1 + Milestone 2,
5. STOP before creating any new AWS resource unless the user explicitly approves that AWS resource creation.

Do not implement Milestone 3 or later.

---

# 1. Preserve the architecture

Do not redesign the system.

Keep the existing minimal architecture and responsibilities.

Do NOT introduce:
- SQLite
- Redis
- connection database
- credential manager daemon
- background connection service
- JobManager
- lease system
- message broker
- HTTP orchestrator
- second runtime
- additional watchdog services
- general plugin framework
- Kubernetes
- any new long-running service solely for connection setup

Milestone 2 should primarily be:
- CLI commands,
- config generation,
- official authentication flows,
- validation logic,
- clear diagnostics.

Prefer simple scripts and explicit files over new services.

---

# 2. Implement `hermes-connect`

Create an English interactive connection command:

```bash
hermes-connect
```

Its purpose is to connect the current EC2 instance to the user's own accounts.

Target integrations:

1. Discord
2. OpenAI / Codex provider used by Hermes
3. Claude Code
4. GitHub

The command must:

- detect already configured integrations,
- skip already healthy integrations unless the user explicitly asks to reconnect,
- guide the user only through missing or failed integrations,
- use each tool/provider's supported authentication mechanism,
- never echo secrets back to the terminal,
- never write secrets into normal logs,
- store credentials only in documented persistent credential locations,
- use restrictive permissions,
- validate every integration immediately after configuration,
- return clear PASS / FAIL results,
- provide actionable recovery instructions on failure.

Target UX:

```text
Hermes Workstation Connection Setup

[1/4] Discord      PASS
[2/4] OpenAI       PASS
[3/4] Claude Code  PASS
[4/4] GitHub       PASS

All connections are ready.
```

Support focused reconfiguration where practical, for example:

```bash
hermes-connect --discord
hermes-connect --openai
hermes-connect --claude
hermes-connect --github
```

Do not invent flags if they materially complicate the design; document the final interface.

---

# 3. Discord connection requirements

The Discord setup must be understandable to a user who has the required Discord bot/application information but does not know the internal Hermes configuration format.

The setup should:

- ask only for required user-provided values,
- validate the resulting configuration,
- verify that Hermes can establish the intended Discord connection,
- avoid storing Discord tokens in shell history or ordinary logs,
- document where the credential is stored,
- document required Discord-side prerequisites.

Do not hard-code the current owner's Discord identifiers or credentials into the SSOT.

The repository must remain redistributable.

---

# 4. OpenAI / Codex connection requirements

Configure the provider used by Hermes using the supported authentication path.

Requirements:

- no owner-specific OAuth/session data in the repository,
- credentials persist across container/service restart,
- authentication status can be checked non-destructively,
- failure states are reported clearly,
- setup does not silently fall back to a fake/mock provider.

Document the exact persistent credential path used by this implementation without exposing credential contents.

---

# 5. Claude Code connection requirements

Use the established persistent-wrapper concept where appropriate, but implement it cleanly within the new SSOT design.

Requirements:

- Claude Code CLI availability check,
- supported login/authentication flow,
- persistent credential location,
- non-destructive authentication check,
- a minimal real invocation smoke test when safe,
- no credential values in evidence/logs.

A successful login alone is not enough if a safe minimal invocation can verify real usability.

---

# 6. GitHub connection requirements

Use GitHub CLI and the HTTPS credential-helper approach unless the current SSOT design has a simpler already-approved equivalent.

Requirements:

- `gh` authentication validation,
- git credential/helper validation,
- authenticated GitHub API read check,
- git remote-read capability check when a test repository is available,
- no owner-specific credential material in the repository,
- persistent config paths documented.

Do not add SSH key management unless it is actually required.

---

# 7. Implement `hermes-doctor`

Create a read-only diagnostic command:

```bash
hermes-doctor
```

Its default mode must NOT mutate configuration.

At minimum check:

- required OS commands
- Docker availability
- Compose availability if used
- Hermes container/service definition
- Hermes Gateway status when runtime is active
- Discord configuration/connectivity when credentials exist
- OpenAI/Codex authentication status
- Claude Code availability/authentication
- GitHub CLI authentication
- required persistent directories
- required file/directory permissions
- systemd unit validity/status where applicable
- disk space
- current installed SSOT version / git commit identifier
- whether the instance is image-safe or contains user credentials

Output must distinguish:

```text
PASS
FAIL
NOT_CONFIGURED
NOT_RUNNING
BLOCKED
WARNING
```

where useful.

Example:

```text
Hermes Workstation Doctor

Docker           PASS
Hermes service   PASS
Gateway          PASS
Discord          FAIL
OpenAI           PASS
Claude Code      PASS
GitHub           PASS
Disk             PASS

Issue:
Discord connection unavailable.

Suggested action:
Run: hermes-connect --discord
```

Diagnostics must be actionable, not merely descriptive.

---

# 8. Credential and redistribution rules

The SSOT repository and distributable base image must contain no user-specific credentials.

Document every path that can contain:

- Discord token
- OpenAI/Codex OAuth/session data
- Claude credentials
- GitHub credentials
- shell/session state
- Hermes user/session data

Add or extend image-readiness checks so that a base image is rejected if user credentials are present.

Do not log secret values.

Use file permissions such as 0600/0700 where appropriate.

Do not copy any credentials from the old EC2 into the repository.

The old EC2 may be inspected only to understand proven path/persistence patterns.

---

# 9. Testing requirements for Milestone 2

Add automated tests for everything that can be tested without real external credentials.

At minimum cover:

- shell syntax
- config rendering
- idempotency
- already-configured detection
- missing-config behavior
- failure behavior
- permissions
- secret redaction
- `hermes-doctor` read-only behavior
- image-readiness credential detection
- no Milestone 3+ implementation
- no forbidden architecture components added

For real authentication tests, record evidence without recording secrets.

Use fresh independent verification after implementation.

A self-review by the implementation worker is not sufficient.

---

# 10. Milestone 2 completion gate

Milestone 2 may be marked complete only if:

- `hermes-connect` exists and has a clear interface,
- all four integrations have a defined setup path,
- all four have a defined validation path,
- `hermes-doctor` exists,
- secrets are not committed or logged,
- persistent credential paths are documented,
- image-readiness behavior is updated,
- automated tests pass,
- independent verifier PASS is obtained,
- git working tree is clean,
- commit is pushed,
- remote read-back SHA matches local HEAD.

Do not claim Fresh EC2 runtime PASS as part of Milestone 2 unless it has actually been performed.

---

# 11. Prepare the first real Fresh EC2 validation

After Milestone 2 is committed and pushed, prepare the exact validation plan for:

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

This is the first real Milestone 1 + Milestone 2 end-to-end runtime validation.

The validation plan must include:

- supported EC2 OS/AMI assumptions,
- minimum instance sizing assumption,
- required inbound/outbound networking,
- required AWS IAM permissions, if any,
- exact bootstrap command,
- exact connection flow,
- exact health checks,
- expected PASS evidence,
- cleanup procedure,
- expected AWS cost-impacting resources.

Important:

**Do not create or modify AWS resources yet.**

Before creating a new EC2 instance, changing IAM, security groups, EBS, Elastic IPs, CloudWatch alarms, or any other chargeable/account-level AWS resource:

STOP and report:

```text
Milestone 2 implementation: COMPLETE / NOT COMPLETE
Fresh EC2 validation: READY / NOT READY

AWS actions requiring approval:
- ...
- ...

Expected purpose:
- ...

Expected cost-impacting resources:
- ...

Awaiting user approval.
```

Only proceed with AWS resource creation after explicit user approval.

---

# 12. Runtime validation after approval

Once the user explicitly approves Fresh EC2 creation, perform the validation on a genuinely fresh instance.

Do not validate by reusing the old EC2.

Required runtime evidence:

1. fresh instance can bootstrap from the SSOT,
2. bootstrap is repeatable/idempotent,
3. Docker/Compose runtime actually works,
4. Hermes image actually builds or pulls as designed,
5. systemd unit actually loads,
6. `hermes-connect` works with the user's integrations,
7. credentials persist across relevant restart,
8. `hermes-doctor` reports correct state,
9. Hermes service starts,
10. Gateway starts,
11. Discord connects,
12. a real Discord message receives a Hermes response,
13. service restart does not destroy credentials,
14. EC2 reboot returns the environment to the documented expected state,
15. no hidden manual fixes are required.

If any manual intervention is needed, treat that as a defect in reproducibility and fix the SSOT rather than merely documenting a one-off server patch.

---

# 13. Evidence and reporting

Store milestone evidence in the repository in the existing evidence convention.

For Milestone 2 include at least:

```text
evidence/milestone-2/
├── TASK.md
├── TEST_EVIDENCE.md
└── VERIFICATION.md
```

For the later Fresh EC2 integration test, create a separate evidence section rather than rewriting history.

Never include:
- tokens,
- OAuth values,
- private user identifiers unnecessarily,
- secret-bearing command output.

At the end of this continuation, report only:

- Milestone 2 status
- commit SHA
- remote read-back
- tests
- verifier result
- known limitations
- Fresh EC2 validation readiness
- exact AWS actions awaiting approval

Do not implement Milestone 3.

---

# Governing rule

Keep the system simple.

`hermes-connect` configures.
`hermes-doctor` diagnoses.

Do not build a connection platform around them.

The next architectural layer — Runner / Monitor / Verifier work execution — belongs to later milestones and must not be introduced during Milestone 2.
