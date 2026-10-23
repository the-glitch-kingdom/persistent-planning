# Persistent Planning

> Auto-loaded every session. Written once by persistent-planning's init scripts and never
> overwritten: edit it to fit this repo.

Plans live in `.planning/`, on disk, so they survive context resets and can be handed to
teammates and subagents. The files are the working memory: read them, keep them current.

## Working a plan

- **Before starting work**, run `/plan-status` and read the active plan. Re-read it before any
  major decision.
- **Create plans with the commands**, never by hand: `/start-planning`, then (team mode)
  `/start-task --parent <phase>` and `/start-atom --parent <task>`. They keep each parent's list
  in order and the closing steps last.
- **Update as you go**: tick each box when it is done, record decisions and errors as they
  happen, and put research in `notes.md` instead of the conversation.
- The layers are **phase → task → atom**, plus **notes** for context at phase or task level.
  Use those words. Do work in dependency order first; mark work `parallelizable: true` only
  when nothing it depends on is unfinished.

## Finishing a plan

- Every plan ends with three **mandatory** steps, always last, in this order: cleanup of junk
  and unused code, validation by testing, a documentation pass. Add new work above them, never
  after, and never skip them.
- **A plan is done when `/plan-status` says COMPLETE.** Don't mark it done any other way.
- Retire a finished plan with `/archive-plan <slug>`. Never delete a plan.
- Active plans are committed to git; only `.planning/.archive/` is ignored.
