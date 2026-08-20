# scripts/

Placeholder directory. Not implemented yet — Milestone 0 only creates this
file to make the target repository tree traceable (see `ARCHITECTURE.md`
§6). No functional script exists here yet.

Planned contents:

- `runner` (Milestone 3) — creates task workspaces, writes `TASK.md`,
  launches Claude Code, records PID/start time, captures output, updates
  task state. Never claims semantic completion by itself.
- `verifier` (Milestone 4) — the mandatory completion gate: deterministic
  checks plus semantic AI review. Only the Verifier may return PASS.
- `monitor` (Milestone 5) — one implementation, two logical checks
  (`system_check`, `task_check`), per `ARCHITECTURE.md` §3.

Do not add functional code here before the milestone that owns it is in
progress. See `MILESTONES.md`.
