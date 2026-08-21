# bootstrap/

Milestone 1 (Clean bootstrap) and Milestone 2 (Connection UX) are
implemented here. Milestone 2 is awaiting independent verification; no
Fresh EC2 or real-account runtime PASS is claimed.

Current contents:

- `install.sh` — idempotent host bootstrap. Installs OS prerequisites
  (git, curl, xz-utils, ca-certificates) and the Docker engine + compose
  command via a deterministic, fail-closed apt package strategy; creates
  the secret-free `/opt/hermes-data` tree (`0700`); renders non-secret
  runtime config from `config/hermes.config.example.yaml`; installs (but
  never enables or starts) the single `systemd/hermes.service` unit. Every
  written file carries a provenance header pointing back to this
  repository. Supports `--dry-run` (true no-write dry run) and is safe to
  re-run (idempotent). Run `bash bootstrap/install.sh --help` for options.
- `hermes-commit.pin` — the exact Hermes Agent source commit this
  repository pins. Read and parsed directly by `docker/Dockerfile` (never
  duplicated as a hardcoded `ARG` default) to build the immutable,
  commit-scoped installer URL:
  `https://raw.githubusercontent.com/NousResearch/hermes-agent/<pinned
  commit>/scripts/install.sh` — never a floating branch/tag URL such as
  `.../main/scripts/install.sh`, which could silently start serving
  different content.
- `hermes-installer.sha256` — the exact SHA-256 of the installer script
  fetched from that same immutable URL, at that pinned commit.
  `docker/Dockerfile` downloads the installer from the URL above at build
  time and refuses to execute it unless the computed digest matches this
  file exactly (verified before execution, never after).
- `connect.sh` — implements the installed `hermes-connect` launcher:
  configures and validates Discord, OpenAI/Codex, Claude Code, and GitHub.
- `doctor.sh` — implements the installed, read-only `hermes-doctor`
  launcher and image-readiness diagnostics.
- `connect-common.sh` — shared connection/diagnostic helpers; it is a
  sourced library, not a service or second runtime.

`install.sh` does **not** install the Hermes Agent itself — that happens
inside `docker/Dockerfile`, so the container image remains the single
reproducible, traceable build artifact. `install.sh` never handles credentials; it only installs traceable launcher
wrappers for the Milestone 2 scripts. Credentials are created later by the
operator through `hermes-connect`; see `SECURITY.md` §3.

Do not add Milestone 3+ functional code here before that milestone is in
progress. See `MILESTONES.md`.
