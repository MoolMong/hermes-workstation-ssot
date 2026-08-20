# systemd/

Placeholder directory. Not implemented yet — Milestone 0 only creates this
file to make the target repository tree traceable (see `ARCHITECTURE.md`
§6). No unit files exist here yet.

Planned contents:

- `hermes.service` (Milestone 1) — supervises the Hermes container/process
  with a bounded restart policy.
- `hermes-gateway.service` (Milestone 1) — supervises the Hermes Gateway.
- `hermes-monitor.service` (Milestone 5) — supervises the Monitor.

Do not add unit files here before the milestone that owns them is in
progress. See `MILESTONES.md`.
