---
title: Documentation pass — full hit-em-with-the-docs pass — Notes
tier: plan
domains:
  - planning
status: active
last_updated: "2026-10-23"
plan_kind: notes
scope: archive-plan-untracks-archived-plans-issue-26/documentation-pass-create-update-deprecate-docs
---

# Notes: Documentation pass — full hit-em-with-the-docs pass — Notes

**Scope**: `archive-plan-untracks-archived-plans-issue-26/documentation-pass-create-update-deprecate-docs` (which phase / task this notes file is attached to)

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

- **Updated:** `.documentation/procedures/plan-completion-and-archive.md`: step 3 now describes untracking; restore now includes `git add`; the "Archived plans show up in git status" row covers plans archived before this fix; new row for the staged-changes warning.
- **Updated:** `scripts/archive-plan.sh` header step 3; `CLAUDE.md` archive paragraph; `CHANGELOG.md` Unreleased entry (#26).
- **New gotcha fact:** `.documentation/knowledge-base/facts/git-rm-cached-moved-path-drops-staged.md`. Its verify_command reproduces the behaviour.
- No secrets in any doc. `hewtd audit`: 0 errors. The warnings are the existing README placement warning and hewtd flagging its own `knowledge-base/` folder.
