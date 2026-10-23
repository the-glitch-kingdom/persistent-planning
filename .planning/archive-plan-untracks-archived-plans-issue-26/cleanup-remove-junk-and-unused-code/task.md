---
title: Cleanup — remove junk and unused code
tier: plan
domains:
  - planning
status: done
last_updated: "2026-10-23"
plan_kind: task
parent: archive-plan-untracks-archived-plans-issue-26
depends_on: []
parallelizable: false
mandatory: true
---

# Task: Cleanup — remove junk and unused code

**Phase**: `archive-plan-untracks-archived-plans-issue-26`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent cleanup-remove-junk-and-unused-code` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent cleanup-remove-junk-and-unused-code` for complex ones)_
- [x] Scope it: diff against where this phase started — only what this phase created or changed is in scope
- [x] Remove scratch/test scripts, debug files, temp output and backups this phase created
- [x] Remove probe logging, one-off test functions and commented-out code
- [x] Remove code, helpers, imports and dependencies left unused by abandoned approaches
- [x] Never refactor code this phase did not touch; when unsure, record it in notes.md instead of deleting

## Decisions Made
[Task-level decisions. Format: `**Decision**: rationale`.]

## Status
**Currently draft** — task has been initialized but no atoms defined.

Status enum: `draft | active | paused | done | archived`

## Dependencies
This task does not currently depend on other tasks. Edit `depends_on:` in frontmatter
to declare dependencies on other tasks within the same phase. Tasks with no
inter-dependencies should set `parallelizable: true`.

---

## Layer reference
- **Phase** (`../phase.md`): the strategic grouping this task belongs to
- **This task**: the bounded deliverable
- **Atoms** (`atoms/<atom-slug>.md`): subagent hand-off units (sequential within this task)
- **Notes** (`notes.md`): cross-cutting references for this task's implementation
