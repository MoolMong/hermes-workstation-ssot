# bootstrap/

Placeholder directory. Not implemented yet — Milestone 0 only creates this
file to make the target repository tree traceable (see `ARCHITECTURE.md`
§6). No functional script exists here yet.

Planned contents:

- `install.sh` (Milestone 1) — installs the base workstation on a fresh
  EC2 instance, reproducibly, from this repository.
- `connect.sh` (Milestone 2) — implements `hermes-connect`: interactively
  connects and validates Discord, OpenAI, Claude Code, and GitHub.
- `doctor.sh` (Milestone 2) — implements `hermes-doctor`: read-only health
  diagnostics.

Do not add functional code here before the milestone that owns it is in
progress. See `MILESTONES.md`.
