# systemd/

Milestone 1 (Clean bootstrap) is implemented here.

Current contents:

- `hermes.service` — the **only** systemd unit in this repository.
  Supervises the single Hermes container (`docker compose up hermes`)
  with a bounded, non-overlapping restart policy: `StartLimitIntervalSec`
  + `StartLimitBurst` cap total restart attempts in a window, and
  `Restart=on-failure` / `RestartSec=10` avoid a tight restart loop.
  `bootstrap/install.sh` installs (and, when changed, `daemon-reload`s)
  this unit, but never runs `systemctl enable` or `systemctl start` —
  activation is out of scope until Milestone 2 provides credentials.

Planned, not yet implemented:

- `hermes-monitor.service` (Milestone 5) — supervises the Monitor.

There is intentionally no `hermes-gateway.service`. "Hermes Gateway" is a
Monitor-level logical check on the one Hermes container's one process
(`hermes gateway`), not a separate service — see `ARCHITECTURE.md` §6/§9.
An earlier draft of this repository's planned tree listed a second unit;
that was corrected during Milestone 1 to satisfy the "exactly one systemd
unit" bootstrap constraint.

Do not add unit files here before the milestone that owns them is in
progress. See `MILESTONES.md`.
