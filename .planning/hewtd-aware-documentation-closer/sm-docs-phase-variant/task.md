---
title: sm docs phase variant
tier: plan
domains:
  - planning
status: done
last_updated: "2026-10-23"
plan_kind: task
parent: hewtd-aware-documentation-closer
depends_on: [detect-hit-em-with-the-docs-per-project]
parallelizable: false
mandatory: false
---

# Task: sm docs phase variant

**Phase**: `hewtd-aware-documentation-closer`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent sm-docs-phase-variant` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent sm-docs-phase-variant` for complex ones)_
- [x] init-planning.sh: Phase 7 line becomes DOCS_PHASE_PLACEHOLDER, default text byte-identical to today, hewtd text when detected
- [x] Same note addition as lg; mirror both in SKILL.md example

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
