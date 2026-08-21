# docker/

Milestone 1 (Clean bootstrap) and the narrow image prerequisites for
Milestone 2 (Connection UX) are implemented here. Runtime validation on a
fresh EC2 remains not run.

Current contents:

- `Dockerfile` — the Hermes Agent image. Pinned base image
  (`ubuntu:24.04@sha256:...`, digest verified 2026-08-20 — see the
  `FROM` line for the exact value). The only place in this repository
  that fetches and executes the official Hermes installer: it `COPY`s
  `bootstrap/hermes-commit.pin` and `bootstrap/hermes-installer.sha256`
  and parses both directly (no duplicated pin `ARG` defaults), derives
  the immutable, commit-scoped installer URL
  (`https://raw.githubusercontent.com/NousResearch/hermes-agent/<pinned
  commit>/scripts/install.sh`), downloads it, verifies its SHA-256 against
  the repository-recorded value **before** execution, and passes the same
  pinned commit to `--commit`. Built with `--skip-setup`, so no
  credentials ever enter an image layer.
- `docker-compose.yml` — exactly one service (`hermes`, container name
  `hermes`, running `hermes gateway run`). `restart: "no"` — supervision is
  systemd's job (`systemd/hermes.service`), not Docker's, so the two
  don't layer into overlapping restart loops for the same failure.
- `entrypoint.sh` — seeds the bind-mounted `/data` volume from the
  image's credential-free default scaffolding on first run only; never
  overwrites an already-initialized volume.

There is exactly one Hermes container/service, per
`BUILD_DIRECTIVE.md` §1 and the Milestone 1 hard constraints — see
`ARCHITECTURE.md` §6 for why "Hermes Gateway" is a Monitor-level check on
this one container, not a second container.

The image also installs GitHub CLI using its official apt repository and
pins Claude Code at `@anthropic-ai/claude-code@2.1.237`; persistent
authentication state remains outside the image under the `/data` bind
mount. Do not add Milestone 3+ functional code here before that milestone
is in progress. See `MILESTONES.md` and `SECURITY.md`.
