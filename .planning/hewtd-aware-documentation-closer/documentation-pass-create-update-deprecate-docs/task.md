---
title: Documentation pass — create/update/deprecate docs
tier: plan
domains:
  - planning
status: draft
last_updated: "2026-10-23"
plan_kind: task
parent: hewtd-aware-documentation-closer
depends_on: []
parallelizable: false
mandatory: true
---

# Task: Documentation pass — create/update/deprecate docs

**Phase**: `hewtd-aware-documentation-closer`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent documentation-pass-create-update-deprecate-docs` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent documentation-pass-create-update-deprecate-docs` for complex ones)_
- [ ] Create docs for what was built: what it is, where it lives, how it works
- [ ] Add a troubleshooting entry for the symptom someone will actually search for
- [ ] Update every existing doc this phase made wrong — a stale doc is worse than a missing one
- [ ] Retire superseded docs with `npx hewtd archive <file>` — never by deleting
- [ ] If hit-em-with-the-docs is installed you MUST use it: `npx hewtd integrate <file> -a` to create, `npx hewtd maintain --quick` to regenerate indexes
- [ ] Run `npx hewtd audit` and resolve every error
- [ ] Never hand-edit INDEX.md or REGISTRY.md — they are generated

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
