---
title: Documentation pass — full hit-em-with-the-docs pass
tier: plan
domains:
  - planning
status: draft
last_updated: "2026-10-23"
plan_kind: task
parent: archive-plan-untracks-archived-plans-issue-26
depends_on: []
parallelizable: false
mandatory: true
---

# Task: Documentation pass — full hit-em-with-the-docs pass

**Phase**: `archive-plan-untracks-archived-plans-issue-26`

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
- [ ] As this phase's tasks are written, add an atom here for each doc they create, change or make stale, naming the file — check the existing docs for ones this work makes wrong
- [ ] Full hit-em-with-the-docs pass: create/update/deprecate as many docs as needed to capture all our changes
- [ ] Create docs with `npx hewtd integrate <file> -a`; retire superseded ones with `npx hewtd archive <file>` — never by deleting
- [ ] Capture every new procedure and tool: what it is, where it lives, how to run it
- [ ] Add a troubleshooting entry for the symptom someone will actually search for
- [ ] Record each gotcha (a non-obvious failure with an observed fix) as a knowledge-base fact tagged `gotcha`, with an `## Instead` section
- [ ] Write KB articles for anything operational under `.documentation/knowledge-base/`
- [ ] Update every existing doc this phase made wrong — a stale doc is worse than a missing one
- [ ] Never include secrets, passwords, tokens or keys in any doc
- [ ] Run `npx hewtd maintain --quick` and `npx hewtd audit`; resolve every error
- [ ] Never hand-edit INDEX.md or REGISTRY.md — they are generated
- [ ] .documentation/procedures/plan-completion-and-archive.md: step 3 (git mv) describes untracking instead; reword the 'Archived plans show up in git status' troubleshooting row for repos archived before the fix
- [ ] scripts/archive-plan.sh header comment step 3
- [ ] CLAUDE.md completion/archive paragraph if it mentions how archiving treats git
- [ ] CHANGELOG.md Unreleased entry referencing #26

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
