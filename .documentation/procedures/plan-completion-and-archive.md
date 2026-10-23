---
title: Plan Completion and Archive
tier: guide
domains:
  - procedures
audience:
  - developers
tags: []
status: active
last_updated: '2026-10-23'
version: 1.0.0
purpose: How persistent-planning decides a plan is finished, how that reaches
  the agent automatically, and the procedure for retiring a completed plan into
  the gitignored .planning/.archive/ directory.
estimated_read_time: 5 minutes
word_count: 812
last_validated: '2026-08-31'
backlinks: []
---

# Plan Completion and Archive

## What it is

Two things that only make sense together:

- **Status tracking** — a plan's completion is *derived from the plan artifacts*,
  not stored anywhere else.
- **Archive** — a completed plan is moved out of the active `.planning/` tree into
  a gitignored `.planning/.archive/`, so what remains under `.planning/` is only
  ever live work.

## Why it matters

The failure this prevents is a finished plan that nobody retires. It sits in
`.planning/`, and every future session — human or agent — re-reads it, re-reasons
about whether it is still relevant, and burns context deciding it isn't. Multiply
by a dozen plans and the working-memory directory becomes the thing you have to
work around.

The reason completion is *derived* rather than *declared* is drift. A `done: true`
flag someone has to remember to set is wrong the moment they forget, and nothing
detects that. Checkbox state cannot drift from the plan, because it **is** the
plan. Checking the last box is the completion signal; there is no second step to
forget.

## Where it lives

| Piece | Path |
|---|---|
| Status scan (single implementation) | `scripts/plan-status.sh` |
| Archive operation | `scripts/archive-plan.sh` |
| Session-start nudge | `hooks/session-start.js` (shells out to `plan-status.sh --nudge`) |
| Slash commands | `commands/plan-status.md`, `commands/archive-plan.md` |
| Archived plans | `.planning/.archive/<slug>/` (gitignored) |

## The completion rule

A plan is **COMPLETE** when either holds:

1. Every checkbox in every markdown file under the plan directory is checked, or
2. The plan's top-level artifact (`phase.md`, `task_plan.md`, or `task.md`)
   declares `status: done` in frontmatter.

Other verdicts: `blocked` (an atom carries `status: blocked`), `empty` (no
checkboxes yet), `in progress` (anything else), `archived` (already stamped).

Because plans are seeded with [mandatory closing phases](../standards/mandatory-closing-phases.md),
a plan cannot read COMPLETE until its work has been tested *and* documented. The
two features are deliberately coupled: completion means finished, not "the fun
part is finished."

## How the agent finds out

Three escalating surfaces, cheapest first:

1. **SessionStart hook.** On every session, the hook runs `plan-status.sh --nudge`
   and merges any result into the session's context: *"persistent-planning: 1
   plan(s) complete but not archived — <slug>."* Silent when there is nothing to
   say, so it costs nothing in the normal case.
2. **`/plan-status`.** The full table, on demand.
3. **The plan artifact itself.** Both templates carry an `## On Completion`
   section stating the rule and the archive command, so an agent reading only the
   plan still learns the protocol.

## How to operate it

```bash
/plan-status                     # what is in progress, blocked, complete
/archive-plan <slug>             # retire one completed plan
/archive-plan --all-complete     # retire every completed plan
/archive-plan <slug> --dry-run   # show the move without making it
/archive-plan <slug> --force     # retire an unfinished plan (deliberate)
```

Machine-readable forms for scripts and subagents:

```bash
bash scripts/plan-status.sh --complete   # one complete plan slug per line
bash scripts/plan-status.sh --nudge      # one line, or nothing
```

Archiving performs four steps:

1. Verifies completion (skipped under `--force`).
2. Ensures `.planning/.archive/` exists and is in `.gitignore`.
3. Moves `.planning/<slug>/` → `.planning/.archive/<slug>/`. If the plan is tracked,
   it is also removed from git's index (`git rm -r --cached`; the files stay on
   disk), so the archive is local history and the next commit shows the plan as
   deleted. Its history stays in git. A plan with **staged** changes stays tracked
   with a warning, because untracking would drop content that only the index holds.
   Commit or unstage, then run `git rm -r --cached .planning/<slug>`.
4. Stamps the top-level artifact: `status: archived` + `archived_on` in
   frontmatter, or a dated footer for sm plans that have none.

**Nothing is ever deleted.** Archiving is a move plus a stamp; the git side is an untrack, not a delete.

## Restoring an archived plan

```bash
mv .planning/.archive/<slug> .planning/<slug>
git add .planning/<slug>          # it was untracked when archived
```

Then set `status:` back to `active` and remove the `archived_on` stamp. The plan
resumes reading as in-progress the moment a box is unchecked.

## How to fix it

| Symptom | Cause | Fix |
|---|---|---|
| Finished plan never reads COMPLETE | A checkbox is still unchecked somewhere in the tree — often in a nested atom file | `bash scripts/plan-status.sh` shows `checked/total`; grep the plan for `- [ ]` |
| A brand-new plan reads COMPLETE | Its template checkboxes were checked without doing the work, or the plan has no checkboxes and `status: done` was set by hand | Uncheck, or correct the frontmatter |
| `archive-plan.sh` refuses | The plan is genuinely incomplete | Finish it. `--force` exists for deliberate abandonment, not for impatience |
| "Already archived: … exists" | A plan with that slug was archived before | Rename or move the existing entry under `.planning/.archive/` first |
| Nudge never appears | No `.planning/` directory, or no plan is complete, or the hook is not registered | `npx persistent-planning status` reports hook registration |
| Archived plans show up in `git status` / are tracked under `.archive/` | Archived before the fix for #26: `archive-plan.sh` used `git mv` and kept them tracked ([#26](https://github.com/the-glitch-kingdom/persistent-planning/issues/26)); or the ignore line was added after the fact | Ensure `.gitignore` has `.planning/.archive/`, then `git rm -r --cached .planning/.archive` (stage any pending stamp first: `git add -f .planning/.archive/*/phase.md`). Files stay on disk |
| "Archived on disk, but git still tracks …" warning | The plan had staged changes; untracking would have dropped them | Commit or unstage them, then `git rm -r --cached .planning/<slug>` |

## Design notes

**One implementation of the scan.** The hook, the slash command, and
`archive-plan.sh`'s completion check all shell out to `plan-status.sh`. A second
copy of the "is this done?" rule in JavaScript would be a second copy that could
disagree.

**The hook merges rather than appends.** `@theglitchking/claude-plugin-runtime`
owns the single `SessionStart` JSON response and exposes no hook for adding to it,
and emitting a second response line would be invalid. `hooks/session-start.js`
intercepts that one write and merges the nudge into the same payload, failing
open — if the payload is not the shape it expects, it is written through
untouched and the update check still works.

**Archive is gitignored on purpose.** A completed plan is a record of how *this
machine* got somewhere. Sharing it with every clone would grow the repository
with reasoning nobody reads. If a particular plan is worth keeping, promote its
findings into a real doc — which is what the mandatory documentation phase is for.


## Completion also gates on mandatory tasks (3.3.0+)

"Every checkbox checked" is necessary but no longer sufficient. A plan containing any
task with `mandatory: true` whose `status:` is not `done` (or `archived`) reads
`in progress` however the boxes add up, and `archive-plan.sh` refuses it through the
same pre-flight — there is still exactly one implementation of the rule.

Plans with no `mandatory:` frontmatter are unaffected.

Symptoms and fixes: [Plan never reads complete](../troubleshooting/plan-never-reads-complete.md).


## What counts, and what does not (3.3.1+)

- **Checkboxes** are body content and are counted anywhere *except* inside a fenced code
  block. A quoted example is documentation, not work. An unterminated fence swallows the
  rest of the file — the safe direction, since ambiguous content is not counted as
  outstanding.
- **`status:` and `mandatory:`** are frontmatter fields and are read *only* from the
  leading `---` block. They are never matched in prose, tables or fenced examples, which
  is stricter than fence-stripping alone.


## What is tracked (3.4.0+)

Active plans are committed; only `.planning/.archive/` is gitignored. v1.0.0 ignored the
whole `.planning/` tree, which contradicted this procedure, `CLAUDE.md`, and the archive
rationale itself — and in lg mode, chosen because a team exists, it guaranteed no
teammate ever received the plans.

Repos carrying the old blanket line keep it: the init scripts warn once and never rewrite
a user's `.gitignore`. Replace `.planning/` with `.planning/.archive/` to start sharing.
