---
title: Documentation pass — create/update/deprecate docs — Notes
tier: plan
domains:
  - planning
status: active
last_updated: "2026-10-23"
plan_kind: notes
scope: hewtd-aware-documentation-closer/documentation-pass-create-update-deprecate-docs
---

# Notes: Documentation pass — create/update/deprecate docs — Notes

**Scope**: `hewtd-aware-documentation-closer/documentation-pass-create-update-deprecate-docs` (which phase / task this notes file is attached to)

## Key Findings
[Findings that emerged during plan implementation. Things that didn't fit cleanly into
a task or atom but matter for context.]

## Research Sources
[External references, internal docs, conversations that informed decisions.]

## Synthesized Findings
[Patterns, themes, distilled understanding from the research.]

## Decisions Made
[Notes-level decisions that affect the parent task or phase. Promote to the parent's
Decisions Made section if they have wider impact.]

## Errors & Solutions
[Errors encountered + how they were resolved. Useful for future similar work.]

---

## Append-Only Log
[Chronological record of progress. Each entry is dated. Useful for handoff and
reconstructing context after time away.]

### 2026-10-23 — Initialized
- Notes file created

## Docs pass (2026-10-23)

- **Updated:** `.documentation/standards/mandatory-closing-phases.md`: both docs-step variants, detection, slug invariant.
- **Updated (stale since #22):** `.documentation/troubleshooting/stale-skill-dir-drift.md`: the "correct plan" example now shows the current Phase 6 line and notes the hewtd Phase 7 variant.
- **New troubleshooting:** `.documentation/troubleshooting/docs-closer-missing-hewtd-steps.md` (via `hewtd integrate -a`, frontmatter corrected to guide/active).
- **New gotcha fact:** `.documentation/knowledge-base/facts/claude-code-grep-v-exit-status.md`: Claude Code's Bash-tool `grep` (ugrep) exits 1 on `-v` when any line matches; use `command grep`. First KB entry in this repo; `hewtd maintain` generated the facts/incidents/symptoms indexes.
- **Also:** CLAUDE.md, commands/start-planning.md, SKILL.md, CHANGELOG.md.
- **No secrets** in any doc. `hewtd audit`: 0 errors, 2 warnings. One predates this work (`.documentation/README.md` placement). The other is hewtd flagging its own default vault folder `knowledge-base/` as unknown, which is upstream behaviour, not fixed here.
- Only index files with real content changes are committed; date-only regeneration churn is dropped.
