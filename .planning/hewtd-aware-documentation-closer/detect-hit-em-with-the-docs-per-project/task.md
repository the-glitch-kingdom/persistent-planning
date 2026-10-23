---
title: Detect hit-em-with-the-docs per project
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

# Task: Detect hit-em-with-the-docs per project

**Phase**: `hewtd-aware-documentation-closer`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent detect-hit-em-with-the-docs-per-project` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent detect-hit-em-with-the-docs-per-project` for complex ones)_
- [x] planning_uses_hewtd <root> in scripts/lib/planning.sh: true when <root>/.documentation/ or <root>/.claude/hit-em-with-the-docs.json exists; never a machine-wide install
- [x] Self-contained copy of the check in init-planning.sh (sm stays lib-free)

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
