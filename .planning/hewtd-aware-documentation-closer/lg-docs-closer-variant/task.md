---
title: lg docs closer variant
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

# Task: lg docs closer variant

**Phase**: `hewtd-aware-documentation-closer`

## Goal
[One sentence describing the deliverable end-state for this task.]

## Atoms
[Atomic checkbox items that will be picked up by subagents. Each atom should be
something a single subagent can complete in one focused pass.

For complex atoms that need explicit subagent context, spawn a standalone atom file
via `/start-atom "Atom name" --parent lg-docs-closer-variant` — these become files
under `atoms/` that subagents read via the planning MCP.

Inline checkbox vs. standalone atom file — see anti-pattern doc:
.documentation/standards/atom-granularity.md.]

or run `/start-atom "Atom name" --parent lg-docs-closer-variant` for complex ones)_
- [x] templates/lg/phase.md: docs closer list line becomes DOCS_CLOSER_PLACEHOLDER, filled by init-phase.sh with the default or the hewtd text
- [x] init-phase.sh: hewtd variant of the docs closer title and atoms (full hewtd pass, procedures, tools, troubleshooting, gotchas as KB facts, KB articles, never secrets, maintain + audit); slug unchanged
- [x] Default variant: drop the unconditional npx hewtd archive / audit atoms; keep the if-installed fallback; add never-secrets
- [x] phase.md note: capture procedures, tools, troubleshooting, gotchas, KB articles; never secrets or passwords

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
