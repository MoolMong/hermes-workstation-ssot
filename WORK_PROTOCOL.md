# Work Protocol

This is the readable policy referenced by `BUILD_DIRECTIVE.md` §2. It
applies to Hermes (starting Milestone 3) and to any human or agent doing
work in this repository, including work on this repository itself.

For every actionable request:

## 1. Context

Collect only relevant context:

- the user request,
- repository instructions such as `README.md` / `CLAUDE.md` / `AGENTS.md`,
- related source files,
- current git status/diff,
- relevant project context.

Create `TASK.md` containing:

```text
Goal
Context
Constraints
Acceptance Criteria
Relevant Files
Unknowns
Execution Mode
```

Do not start a long interview. Ask the user only when a missing fact makes
safe execution impossible or materially changes the requested result.
Otherwise infer conservatively and proceed.

## 2. Decompose

Do not decompose trivial work unnecessarily. Split work only when doing so
improves correctness or parallelism.

## 3. Parallelize

Parallelize only tasks that do not depend on each other's outputs. Default
maximum worker count: 3. If a dependency exists, execute sequentially. Do
not add a general-purpose DAG engine in v0.1.

## 4. Verify

Run a fresh verification step after implementation. Verifier input should
primarily be:

- `TASK.md`,
- actual git diff,
- changed source,
- deterministic test/build/lint evidence,
- runtime evidence when relevant.

Do not rely on the worker's self-assessment. On failure, provide only
concrete defects to the repair worker. Use a bounded repair count.

## 5. Integrate

Hermes (or whoever is closing out the work) summarizes:

- what changed,
- verification result,
- important evidence,
- unresolved issues,
- whether user attention is required.

## Applying this protocol to Milestone 0

This document is itself a Milestone 0 deliverable, so the protocol above
was followed to produce it:

- **Context**: `BUILD_DIRECTIVE.md` in full, empty repository state.
- **Decompose**: one milestone (M0), not split further — it is already the
  smallest unit the directive defines.
- **Parallelize**: not applicable, single actor, single milestone.
- **Verify**: `tests/check_milestone0.sh` (deterministic, dependency-free)
  checks document presence, forbidden-scope declaration, secret
  placeholders, and repository tree consistency. See
  [`CHANGELOG.md`](CHANGELOG.md) for the recorded evidence.
- **Integrate**: summarized in the Milestone 0 changelog entry and in
  [`DEFINITION_OF_DONE.md`](DEFINITION_OF_DONE.md).
