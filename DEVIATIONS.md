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

## Future milestones

Any deviation discovered during Milestones 1–7 must be recorded here, at
the time it is introduced, following the format required by
`BUILD_DIRECTIVE.md` §15:

1. the concrete failure mode observed,
2. why the current minimal design cannot solve it,
3. the smallest additional component required.

A deviation entry without all three items is incomplete and must not be
treated as authorization to add the component.
