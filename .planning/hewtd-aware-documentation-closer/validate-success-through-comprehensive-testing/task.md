---
title: Validate success through comprehensive testing
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

# Task: Validate success through comprehensive testing

**Phase**: `hewtd-aware-documentation-closer`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent validate-success-through-comprehensive-testing` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent validate-success-through-comprehensive-testing` for complex ones)_
- [ ] We need to validate success thoroughly through comprehensive testing of our changes: as this phase's tasks are written, add an atom here for each check they need
- [ ] Cover every kind that applies: unit tests for new and changed logic, integration and end-to-end runs through the real entry points, edge cases and failure paths
- [ ] Prove every claim this phase makes with a test that fails if it breaks
- [ ] Test the invariant after mutation, not the shape of a freshly rendered template
- [ ] Cover the failure mode that prompted the work, not just the happy path
- [ ] Run the full suite green before closing this task
- [ ] Detection: .documentation/ only -> hewtd; .claude/hit-em-with-the-docs.json only -> hewtd; neither -> default
- [ ] Detection: a machine-wide install (HOME fixture with installed_plugins.json listing hewtd) and no project signal -> default
- [ ] lg e2e, hewtd project: phase.md docs line and closer task.md carry the full-hewtd-pass text, gotcha/KB/secrets atoms and the hewtd commands
- [ ] lg e2e, plain project (regression): no npx hewtd archive / audit atoms; never-secrets atom present
- [ ] sm e2e, both variants: Phase 7 line text; default byte-identical to the pre-change line
- [ ] Both modes, both variants: no PLACEHOLDER left in any rendered file; docs closer slug unchanged; closer still last after adding tasks; plan-status gate still blocks until closers are done
- [ ] Re-running init-phase in a hewtd project does not rewrite an existing phase.md
- [ ] npm pack --dry-run includes every changed template

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
