---
title: Docs closer asks for named docs up front
tier: plan
domains:
  - planning
status: done
last_updated: "2026-10-23"
plan_kind: task
parent: hewtd-aware-documentation-closer
depends_on: []
parallelizable: false
mandatory: false
---

# Task: Docs closer asks for named docs up front

**Phase**: `hewtd-aware-documentation-closer`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent docs-closer-asks-for-named-docs-up-front` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent docs-closer-asks-for-named-docs-up-front` for complex ones)_
- [x] Docs closer's first atom (both lg variants) asks the planner to name each doc the tasks create, change or make stale
- [x] phase.md, sm note and SKILL.md ask the same; persistent-planning.md rule gains a docs line
- [x] Unit asserts: first docs atom in both lg variants, notes in sm and lg
- [x] Behaviour re-test: fresh hewtd lg + plain sm projects planned by a subagent with a neutral prompt

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
