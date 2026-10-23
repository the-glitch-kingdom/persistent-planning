---
title: Validate success through comprehensive testing — Notes
tier: plan
domains:
  - planning
status: active
last_updated: "2026-10-23"
plan_kind: notes
scope: hewtd-aware-documentation-closer/validate-success-through-comprehensive-testing
---

# Notes: Validate success through comprehensive testing — Notes

**Scope**: `hewtd-aware-documentation-closer/validate-success-through-comprehensive-testing` (which phase / task this notes file is attached to)

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

## Results (2026-10-23)

- `npm test`: **182 passed, 0 failed** (32 new asserts in the "hewtd-aware docs closer" section).
- Gate check verified against real output: all boxes ticked in a hewtd project reads `in progress 24/24`, not COMPLETE.
- Mutation check: forcing detection to false in both lib and sm turned **10** asserts red; restored from git.

## Behaviour tests (2026-10-23)

A subagent was given "Add a --json option to stats.py" in a fresh throwaway project and asked to plan it with the new scripts. The prompt said nothing about testing or docs.

| Run | Testing step | Docs step |
|---|---|---|
| plain sm #1 | 5 task-specific checks | generic wording (correct), 1 item (README) |
| hewtd lg #1 | 4 task-specific atoms | full hewtd wording (correct), **no task-specific atoms**: missed stale `.documentation/features/stats-cli.md` |
| plain sm #2 (after fix) | 5 task-specific checks | 3 named items (README, usage string, "no hewtd tree") |
| hewtd lg #2 (after fix) | 5 task-specific atoms | names `.documentation/features/stats-cli.md` + README, ahead of the hewtd atoms |

Fix between runs: the `docs-closer-asks-for-named-docs-up-front` task. `npm test`: 186 passed, 0 failed.
Caveat: the subagents ran from this repo, whose CLAUDE.md describes the closers.
