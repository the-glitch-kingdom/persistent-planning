---
title: Stale skill directory — commands run frozen code
tier: guide
domains:
  - troubleshooting
audience:
  - developers
tags: []
status: active
last_updated: '2026-09-04'
version: 1.0.0
purpose: Symptom, cause, detection and repair for a stale .claude/skills/persistent-planning
  directory that makes commands run frozen pre-3.1.0 code (issue #10).
estimated_read_time: 3 minutes
word_count: 403
last_validated: '2026-09-04'
backlinks: []
---

# Stale skill directory — commands run frozen code

`/start-planning` produces a plan that is missing the mandatory validate and
documentation phases, and has no `## On Completion` archive block. No warning is
shown. `npx persistent-planning status` reports the current version. Everything
exits 0.

This is the failure mode from [issue #10](https://github.com/the-glitch-kingdom/persistent-planning/issues/10),
fixed in 3.2.0.

## Symptom

A generated `task_plan.md` ends at Phase 4. A correct one ends:

```
- [ ] Phase 5: Cleanup -- remove junk and unused code this work created: scratch/test scripts, debug files, probe logging, one-off test functions, commented-out code, dead code from abandoned approaches (MANDATORY)
- [ ] Phase 6: Validate success through comprehensive testing (MANDATORY)
- [ ] Phase 7: Documentation pass -- create/update/deprecate as many docs as needed to capture what was done, where it lives, how to troubleshoot it, etc. etc.. etc.. (MANDATORY)
```

and carries an `## On Completion` section naming `/plan-status` and `/archive-plan`.

## Cause

`.claude/skills/persistent-planning/` is a **real directory** instead of a symlink
into the installed package. v1's `persistent-planning install` (removed in 2.0.0)
copied the skill dir. The v2+ linker only symlinks, and when it found a real
directory at the destination it warned once during `npm install` and skipped —
permanently.

The result: the update check read the *plugin's* version while `/start-planning`
executed the *skill dir's* frozen copy. Same version number, different artifact,
nothing reconciling them. `commands/start-planning.md` lists
`~/.claude/skills/persistent-planning/scripts/init-planning.sh` among its fallback
paths, and in a v1-era skill dir that file exists — so the stale copy wins.

## Detect

**Check the shape, not the contents:**

```bash
ls -ld .claude/skills/persistent-planning
```

A symlink is healthy. A real directory is drift — nothing in the current system
creates one.

**Confirm how far behind, by diff:**

```bash
diff <path-to-package>/scripts/init-planning.sh \
     .claude/skills/persistent-planning/scripts/init-planning.sh
```

> **Do not verify by keyword grep.** Counting `Phase` or `MANDATORY` occurrences
> reported the known-stale copies as healthy during triage; only `diff` exposed the
> 23-line gap. See [Skill version marker](../reference/skill-version-marker.md) for
> the version signal.

From 3.2.0 the SessionStart hook detects this for you and prints the path, the
running version vs the installed one, and the fix.

## Fix

On 3.2.0 or later, with `updatePolicy: auto`, the next session repairs it by itself
— once per plugin version. Otherwise:

```bash
npx persistent-planning relink
```

Either way the original is renamed to `.claude/skills/persistent-planning.bak-<timestamp>`.
**Nothing is deleted.** Delete the backup yourself once you are satisfied.

If the directory is tracked in git — v1's installer sometimes committed it — the
repair shows up as deleted files plus a new symlink. That is a real commit for that
repo to take, and a prompt to decide whether a skill dir belongs in version control
at all.

## When repair cannot run

`relink` reports a rename failure and leaves the directory alone rather than
deleting anything. Move it aside by hand and re-run. To manage the directory
yourself and silence the machinery:

```bash
PERSISTENT_PLANNING_NO_RECLAIM=1   # never reclaim
PERSISTENT_PLANNING_SKIP_LINK=1    # never link at all
```

`updatePolicy: off` also suppresses both the warning and the repair.

## Related

- [Skill linking and reclaim](../architecture/skill-linking-and-reclaim.md) — how it works
- [Plugin update delivery](../procedures/plugin-update-delivery.md) — why the hook, not postinstall
- [Skill version marker](../reference/skill-version-marker.md) — the `.version` contract
