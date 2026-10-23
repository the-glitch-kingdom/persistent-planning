---
title: Untrack the plan when archiving
tier: plan
domains:
  - planning
status: done
last_updated: "2026-10-23"
plan_kind: task
parent: archive-plan-untracks-archived-plans-issue-26
depends_on: []
parallelizable: false
mandatory: false
---

# Task: Untrack the plan when archiving

**Phase**: `archive-plan-untracks-archived-plans-issue-26`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent untrack-the-plan-when-archiving` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent untrack-the-plan-when-archiving` for complex ones)_
- [x] archive_one: for a tracked plan, plain mv into .archive/ then git rm -r -q --cached .planning/<slug> (replaces git mv)
- [x] If git rm --cached refuses (staged content that would be lost), warn with the manual fix instead of forcing; never touch the files on disk
- [x] Untracked plans and non-git roots keep the plain mv path unchanged; --dry-run says it would also untrack

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
