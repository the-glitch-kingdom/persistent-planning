---
title: hewtd-aware documentation closer
tier: plan
domains:
  - planning
status: done
last_updated: "2026-10-23"
plan_kind: phase
parent: null
---

# Phase: hewtd-aware documentation closer

## Goal
When a project uses hit-em-with-the-docs, every new plan's last step is a full hewtd docs pass that captures all changes (procedures, tools, troubleshooting, gotchas, KB articles) and never secrets, so the user no longer has to ask for it on every implementation.

## Tasks
[Tasks created with `/start-task --parent hewtd-aware-documentation-closer` will be tracked here.
Each task is a bounded deliverable. Tasks default to dependencies-first scheduling.
Tasks with no inter-dependencies can be marked `parallelizable: true` in their frontmatter
so subagent teams can pick them up concurrently.]

- [x] **Detect hit-em-with-the-docs per project** (`detect-hit-em-with-the-docs-per-project`)
- [x] **lg docs closer variant** (`lg-docs-closer-variant`)
- [x] **sm docs phase variant** (`sm-docs-phase-variant`)
- [x] **Cleanup — remove junk and unused code** (`cleanup-remove-junk-and-unused-code`) (MANDATORY — third-to-last)
- [x] **Validate success through comprehensive testing** (`validate-success-through-comprehensive-testing`) (MANDATORY — second-to-last)
- [x] **Documentation pass — create/update/deprecate as many docs as needed to capture what was done, where it lives, how to troubleshoot it, etc. etc.. etc..** (`documentation-pass-create-update-deprecate-docs`) (MANDATORY — last)

> The three mandatory closing tasks above MUST remain the last three tasks of this phase.
> Add new tasks above them; never after. A phase cannot be marked `done` until all three
> are `done`, and none may be `parallelizable` — they gate on everything before them.
>
> - **Cleanup**: remove what this phase left behind — scratch and test scripts, temp
>   output, debug logging, one-off test functions, commented-out code, and code, imports
>   or dependencies left unused by abandoned approaches. Only what this phase changed;
>   never refactor code it did not touch. It runs before validation so the tests prove
>   every deletion safe.
> - **Validate success**: we need to validate success thoroughly through comprehensive
>   testing of our changes. Write the tests into this phase as you write its tasks --
>   don't wait to be asked. Add each check as an atom of the validation task, every kind
>   that applies: unit tests for new and changed logic, integration and end-to-end runs
>   through the real entry points, a regression test for the problem that prompted the
>   work, edge cases and failure paths, and the full existing suite. Each must fail if
>   the change breaks.
> - **Documentation pass**: create/update/deprecate every doc this phase touches —
>   what it is, where it lives, how to fix it, how to operate it, why it matters.
>   If hit-em-with-the-docs is installed, you MUST use it for this pass --
>   `npx hewtd integrate <file> -a` to create, `npx hewtd archive <file>` to retire,
>   `npx hewtd maintain --quick` to regenerate indexes. Never hand-edit INDEX.md or
>   REGISTRY.md; they are generated.

## Decisions Made
[Phase-level decisions that affect multiple tasks. Format: `**Decision**: rationale`.]

- **Detect per project, not per machine**: the user has hewtd installed for their whole account; that would put hewtd steps in plans for repos with no `.documentation/`.
- **Decide at init, not in a hook**: plans are written once; a hook would have to rewrite plans that already exist.
- **Slugs stay fixed**: the completion gate and existing plans key on `documentation-pass-create-update-deprecate-docs`.

## Status
**Done** — all tasks and closers complete; shipped as one PR.

Status enum: `draft | active | paused | done | archived`

When all tasks are `done`, mark this phase `done`. Checking every box in this phase
IS the completion signal — `/plan-status` reads it straight off the artifacts.

When complete, retire it with `/archive-plan hewtd-aware-documentation-closer`: the whole
directory (tasks and atoms with it) moves to the gitignored
`.planning/.archive/hewtd-aware-documentation-closer/` and the frontmatter above is stamped
`status: archived` + `archived_on`. Nothing is destroyed.

---

## Layer reference (lg mode)
- **Phase** (this file): strategic grouping of related tasks
- **Task** (`.planning/hewtd-aware-documentation-closer/<task-slug>/task.md`): bounded deliverable
- **Atom** (`.planning/hewtd-aware-documentation-closer/<task-slug>/atoms/<atom-slug>.md`): subagent hand-off unit
- **Notes** (`.planning/hewtd-aware-documentation-closer/notes.md` or per-task `notes.md`): cross-cutting references
