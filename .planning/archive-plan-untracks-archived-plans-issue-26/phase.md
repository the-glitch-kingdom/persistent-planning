---
title: archive-plan untracks archived plans (issue 26)
tier: plan
domains:
  - planning
status: active
last_updated: "2026-10-23"
plan_kind: phase
parent: null
---

# Phase: archive-plan untracks archived plans (issue 26)

## Goal
Archiving a tracked plan leaves it on disk in .planning/.archive/ and out of git's index, so archived plans are local history as designed (issue #26).

## Tasks
[Tasks created with `/start-task --parent archive-plan-untracks-archived-plans-issue-26` will be tracked here.
Each task is a bounded deliverable. Tasks default to dependencies-first scheduling.
Tasks with no inter-dependencies can be marked `parallelizable: true` in their frontmatter
so subagent teams can pick them up concurrently.]

- [x] **Untrack the plan when archiving** (`untrack-the-plan-when-archiving`)
- [ ] **Cleanup — remove junk and unused code** (`cleanup-remove-junk-and-unused-code`) (MANDATORY — third-to-last)
- [ ] **Validate success through comprehensive testing** (`validate-success-through-comprehensive-testing`) (MANDATORY — second-to-last)
- [ ] **Documentation pass — a full hit-em-with-the-docs pass to create/update/deprecate as many docs as needed to capture all our changes: new procedures, tools, troubleshooting steps, gotchas, KB articles, etc. Never include secrets or passwords** (`documentation-pass-create-update-deprecate-docs`) (MANDATORY — last)

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
>   Capture new procedures, tools, troubleshooting steps, gotchas and KB articles too.
>   Never include secrets or passwords. Write the docs work into this phase as you write
>   its tasks -- don't wait to be asked. Add an atom to the documentation task for each
>   doc they create, change or make stale, naming the file.
>   If hit-em-with-the-docs is installed, you MUST use it for this pass --
>   `npx hewtd integrate <file> -a` to create, `npx hewtd archive <file>` to retire,
>   `npx hewtd maintain --quick` to regenerate indexes. Never hand-edit INDEX.md or
>   REGISTRY.md; they are generated.

## Decisions Made
[Phase-level decisions that affect multiple tasks. Format: `**Decision**: rationale`.]

- **Plain mv + untrack the old path, not git mv + untrack the new one**: nothing in .archive/ is ever staged, and the archive stamp lands on an untracked file, so there is no staged-vs-worktree conflict.
- **Never force**: if git refuses to untrack (staged content that would be lost), warn and leave it to the user.

## Status
**Currently draft** — phase has been initialized but no tasks defined.

Status enum: `draft | active | paused | done | archived`

When all tasks are `done`, mark this phase `done`. Checking every box in this phase
IS the completion signal — `/plan-status` reads it straight off the artifacts.

When complete, retire it with `/archive-plan archive-plan-untracks-archived-plans-issue-26`: the whole
directory (tasks and atoms with it) moves to the gitignored
`.planning/.archive/archive-plan-untracks-archived-plans-issue-26/` and the frontmatter above is stamped
`status: archived` + `archived_on`. Nothing is destroyed.

---

## Layer reference (lg mode)
- **Phase** (this file): strategic grouping of related tasks
- **Task** (`.planning/archive-plan-untracks-archived-plans-issue-26/<task-slug>/task.md`): bounded deliverable
- **Atom** (`.planning/archive-plan-untracks-archived-plans-issue-26/<task-slug>/atoms/<atom-slug>.md`): subagent hand-off unit
- **Notes** (`.planning/archive-plan-untracks-archived-plans-issue-26/notes.md` or per-task `notes.md`): cross-cutting references
