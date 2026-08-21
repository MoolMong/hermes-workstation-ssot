# Deviations from `BUILD_DIRECTIVE.md`

`BUILD_DIRECTIVE.md` §15 requires the proposed repository tree and any
deviations from the directive to be identified explicitly before
implementation proceeds.

## Milestone 0

**No deviations.**

- The repository tree in `ARCHITECTURE.md` §6 follows the layout suggested
  in `BUILD_DIRECTIVE.md` §7 as-is; no renaming or restructuring was
  judged necessary ("You may improve names/layout if the result is
  simpler" — the directive's own suggested layout was already the
  simplest option found).
- The task-state directory layout, state list, and `state.json` fields in
  `ARCHITECTURE.md` §4 are copied verbatim from `BUILD_DIRECTIVE.md` §3.
- The forbidden-scope list in `ARCHITECTURE.md` §5 is copied verbatim from
  `BUILD_DIRECTIVE.md` §10, and nothing on that list has been added.
- The existing Factory/EC2 was not inspected to produce Milestone 0; the
  directive's own specification was sufficient, consistent with
  `BUILD_DIRECTIVE.md` §9 treating that inspection as optional reference
  material, not a requirement.

## Milestone 1

**No deviations.**

## Milestone 2

**No deviations.**

- `hermes-connect`/`hermes-doctor` are implemented as CLI scripts under
  `bootstrap/`, per `MILESTONE2_DIRECTIVE.md` §1 ("Milestone 2 should
  primarily be CLI commands, config generation") — no background
  connection service, credential-manager daemon, or connection database
  was added, consistent with the forbidden-scope list in `CLAUDE.md`.
- `docker/docker-compose.yml`'s command and `env_file` handling were
  corrected against the real upstream Hermes Agent CLI's actual behavior
  (see `CHANGELOG.md`'s Milestone 2 "Fixed" entry). This is a bug fix to
  Milestone 1 output within the existing design, not an architectural
  deviation or new component.

## Future milestones

Any deviation discovered during Milestones 3–7 must be recorded here, at
the time it is introduced, following the format required by
`BUILD_DIRECTIVE.md` §15:

1. the concrete failure mode observed,
2. why the current minimal design cannot solve it,
3. the smallest additional component required.

A deviation entry without all three items is incomplete and must not be
treated as authorization to add the component.
