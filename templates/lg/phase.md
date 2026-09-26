---
title: PHASE_TITLE_PLACEHOLDER
tier: plan
domains:
  - planning
status: draft
last_updated: "PHASE_DATE_PLACEHOLDER"
plan_kind: phase
parent: null
---

# Phase: PHASE_TITLE_PLACEHOLDER

## Goal
[One sentence describing what this phase achieves and the strategic boundary it represents.]

## Tasks
[Tasks created with `/start-task --parent PHASE_SLUG_PLACEHOLDER` will be tracked here.
Each task is a bounded deliverable. Tasks default to dependencies-first scheduling.
Tasks with no inter-dependencies can be marked `parallelizable: true` in their frontmatter
so subagent teams can pick them up concurrently.]

_(no tasks yet — run `/start-task "Task name" --parent PHASE_SLUG_PLACEHOLDER`)_
- [ ] **Cleanup — remove junk and unused code** (`cleanup-remove-junk-and-unused-code`) (MANDATORY — third-to-last)
- [ ] **Validate success through comprehensive testing** (`validate-success-through-comprehensive-testing`) (MANDATORY — second-to-last)
- [ ] **Documentation pass — create/update/deprecate as many docs as needed to capture what was done, where it lives, how to troubleshoot it, etc. etc.. etc..** (`documentation-pass-create-update-deprecate-docs`) (MANDATORY — last)

> The three mandatory closing tasks above MUST remain the last three tasks of this phase.
> Add new tasks above them; never after. A phase cannot be marked `done` until all three
> are `done`, and none may be `parallelizable` — they gate on everything before them.
>
> - **Cleanup**: remove what this phase left behind — scratch and test scripts, temp
>   output, debug logging, one-off test functions, commented-out code, and code, imports
>   or dependencies left unused by abandoned approaches. Only what this phase changed;
>   never refactor code it did not touch. It runs before validation so the tests prove
>   every deletion safe.
> - **Validate success**: prove the phase's work with tests that fail if it breaks.
> - **Documentation pass**: create/update/deprecate every doc this phase touches —
>   what it is, where it lives, how to fix it, how to operate it, why it matters.
>   If hit-em-with-the-docs is installed, you MUST use it for this pass --
>   `npx hewtd integrate <file> -a` to create, `npx hewtd archive <file>` to retire,
>   `npx hewtd maintain --quick` to regenerate indexes. Never hand-edit INDEX.md or
>   REGISTRY.md; they are generated.

## Decisions Made
[Phase-level decisions that affect multiple tasks. Format: `**Decision**: rationale`.]

## Status
**Currently draft** — phase has been initialized but no tasks defined.

Status enum: `draft | active | paused | done | archived`

When all tasks are `done`, mark this phase `done`. Checking every box in this phase
IS the completion signal — `/plan-status` reads it straight off the artifacts.

When complete, retire it with `/archive-plan PHASE_SLUG_PLACEHOLDER`: the whole
directory (tasks and atoms with it) moves to the gitignored
`.planning/.archive/PHASE_SLUG_PLACEHOLDER/` and the frontmatter above is stamped
`status: archived` + `archived_on`. Nothing is destroyed.

---

## Layer reference (lg mode)
- **Phase** (this file): strategic grouping of related tasks
- **Task** (`.planning/PHASE_SLUG_PLACEHOLDER/<task-slug>/task.md`): bounded deliverable
- **Atom** (`.planning/PHASE_SLUG_PLACEHOLDER/<task-slug>/atoms/<atom-slug>.md`): subagent hand-off unit
- **Notes** (`.planning/PHASE_SLUG_PLACEHOLDER/notes.md` or per-task `notes.md`): cross-cutting references
