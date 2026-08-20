# docker/

Milestone 1 (Clean bootstrap) is implemented here.

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
  `hermes`, running `hermes gateway`). `restart: "no"` — supervision is
  systemd's job (`systemd/hermes.service`), not Docker's, so the two
  don't layer into overlapping restart loops for the same failure.
- `entrypoint.sh` — seeds the bind-mounted `/data` volume from the
  image's credential-free default scaffolding on first run only; never
  overwrites an already-initialized volume.

There is exactly one Hermes container/service, per
`BUILD_DIRECTIVE.md` §1 and the Milestone 1 hard constraints — see
`ARCHITECTURE.md` §6 for why "Hermes Gateway" is a Monitor-level check on
this one container, not a second container.

Do not add Milestone 2+ functional code here before Milestone 2 is in
progress. See `MILESTONES.md`.
