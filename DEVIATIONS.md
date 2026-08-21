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

## Fresh EC2 validation (post-Milestone-2, defect repair)

**One diagnostic-only process deviation**, recorded per the three-part
format required above:

1. **Concrete failure mode observed:** during the first authorized Fresh
   EC2 runtime validation run, the unauthenticated `git clone
   https://github.com/MoolMong/hermes-workstation-ssot.git` step assumed
   by `docs/FRESH_EC2_VALIDATION.md` §5 (as it stood at repository HEAD
   `153a0f45c72b0d848d4b082230e7c3529606c046`) failed: the SSOT repository
   is private, so anonymous HTTPS clone is rejected.
2. **Why the current minimal design could not solve it:** by design, no
   credential is present on a fresh instance before `hermes-connect` has
   run (Milestone 1's credential-free bootstrap, Milestone 2's
   connect-on-demand model), so an authenticated clone was not available
   at this point in the flow; and converting the SSOT repository to
   public is a repository-visibility decision reserved to the operator
   (`SECURITY.md`'s redistribution model, `CLAUDE.md` "Existing
   Factory/EC2"), not something this validation run or repair pass is
   authorized to change. Neither option could be exercised without
   expanding scope mid-run.
3. **Smallest diagnostic-only process deviation:** a credential-free `git
   bundle` containing exactly the remote `main` SHA was transferred to
   the instance out-of-band, so diagnosis of the actual defect (the
   Docker build failure below) could continue on the same live instance
   without waiting for a second run.

This deviation is explicitly **not** a `git clone` PASS — item 0a in
`evidence/milestone-2-fresh-ec2/TEST_EVIDENCE.md` records the clone
attempt itself as **FAIL**, with the bundle transfer recorded separately
as item 0b — and it is **not** a production bootstrap design: no
long-term bundle-transfer mechanism was added to `bootstrap/install.sh`,
`docker/`, or any other shipped path. `docs/FRESH_EC2_VALIDATION.md` §5
is updated to require either interactive GitHub authentication before
`git clone` or this explicitly labeled provenance-verified bundle
diagnostic path for future runs against a private SSOT repository, still
without claiming authorization to make the repository public.

The separately-fixed defect that this same run found — the pinned
installer `curl` step failing closed on transient HTTP 429 with no
retry/backoff — is a bug fix within the existing design (a bounded
`--retry`/`--retry-max-time`/`--retry-connrefused` policy on that one
`curl` line), not an architectural deviation, and is recorded in
`CHANGELOG.md`'s Unreleased section rather than here.

## Future milestones

Any deviation discovered during Milestones 3–7 must be recorded here, at
the time it is introduced, following the format required by
`BUILD_DIRECTIVE.md` §15:

1. the concrete failure mode observed,
2. why the current minimal design cannot solve it,
3. the smallest additional component required.

A deviation entry without all three items is incomplete and must not be
treated as authorization to add the component.
