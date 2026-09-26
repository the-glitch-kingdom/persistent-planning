---
title: Mandatory Closing Phases
tier: standard
domains:
  - standards
audience:
  - developers
tags:
  - testing
status: active
last_updated: '2026-08-31'
version: 1.0.0
purpose: The three phases every persistent-planning plan must end with — cleanup,
  then validate success through comprehensive testing, then a documentation pass —
  why they exist, how they are seeded, and how to keep them last.
estimated_read_time: 4 minutes
word_count: 770
last_validated: '2026-08-31'
backlinks: []
---

# Mandatory Closing Phases

Every plan this plugin creates ends with the same three units of work, in the same
order, no exceptions:

1. **Cleanup — remove junk and unused code this work created**
2. **Validate success through comprehensive testing**
3. **Documentation pass — create / update / deprecate as many docs as needed to capture what was done, where it lives, how to troubleshoot it**

They are seeded into the templates so an agent never has to remember them, and
they are marked `MANDATORY` in the artifact itself so an agent re-reading the
plan mid-run can see they are not optional filler.

## Why they exist

A plan that stops at "execute/build" produces work nobody has proven and nobody
can operate. Both failures are invisible at the moment they happen and expensive
later:

- **Without the validation phase**, "done" means "the agent believes it works."
  The next change silently breaks it, because nothing fails when it does.
- **Without the documentation phase**, the knowledge of what changed lives only
  in a chat transcript that is discarded at the end of the session. The next
  contributor — human or agent — re-derives it from source, or gets it wrong.

Putting them *in the template* rather than in a style guide is the whole point.
Guidance in a style guide is read once; a checkbox in the plan the agent re-reads
before every decision stays in the attention window. This is the same
filesystem-as-working-memory reasoning behind the plan artifacts themselves — see
[Manus Context Engineering Principles](../architecture/context-engineering-principles.md).

## Where they live

| Mode | Artifact | Section | Seeded as |
|---|---|---|---|
| sm | `.planning/<slug>/task_plan.md` | `## Phases` | Phases 5, 6 and 7 of 7 |
| lg | `.planning/<phase-slug>/phase.md` | `## Tasks` | The last three task checkboxes |

In **sm mode** the plan is a single file, so the three phases are literally the
last three checkboxes under `## Phases`.

In **lg mode** the plan is a tree (phase → task → atom, see
[Lg-Mode Layered Planning Guide](../architecture/lg-mode.md)). The closing group is seeded at the
**phase** level, because a phase is the strategic unit that actually ships. Every
phase validates its own work and documents its own work; a phase cannot be marked
`done` until all three closing tasks are `done`. Individual tasks and atoms do **not**
each carry the group — that would produce a documentation pass per atom, which is
noise.

No closing task may be marked `parallelizable: true`. They gate on
everything before them by definition.

## The ordering rule

> New work is inserted **above** the closing group, never after it.

An agent adding phases to an sm plan renumbers the closing group so it remains
last (Phase 5/6/7 becomes Phase 6/7/8, and so on). An agent adding tasks to an lg
phase appends them above the three closing checkboxes. The template states this
rule inline, directly beneath the checkboxes, so it survives the plan being read
in isolation without this document.

The rule is mechanical rather than a judgment call precisely so that it is
enforceable — see [how it is tested](../testing/test-suite.md).

## What each phase actually requires

**Cleanup.** Remove what the work left behind: scratch and test scripts, temp
output and backups, debug and probe logging, one-off test functions, commented-out
code, and code, helpers, imports or dependencies left unused by abandoned
approaches. None of it fails a test and none of it is a doc, so neither of the
other closers catches it. Scope is only what this work created or changed — diff
against where it started — and never a refactor of code it did not touch. When
unsure whether something is used, record it in `notes.md` instead of deleting it.

Cleanup runs **first** of the three on purpose. It deletes things, so validation
has to come after it: the tests then prove every deletion safe against the code
that actually ships. Documentation stays last so it describes that final state.

**Validate success through comprehensive testing.** Prove the work with a check
that *fails if the change breaks*. A test that passes both before and after the
change validates nothing. For this repository that means adding assertions to
`tests/run.sh`; for a consuming project it means whatever that project's test
command is. Mutation-check the assertion at least once: break the thing on
purpose, confirm the test goes red, put it back.

**Documentation pass.** Create, update, or deprecate every doc the change
touches, answering: what it is, where it lives, how to fix it, how to operate it,
and why it matters. Deprecation counts — a doc made wrong by the change is worse
than a missing one. If [hit-em-with-the-docs](https://github.com/TheGlitchKing/hit-em-with-the-docs)
is installed, this pass **must** go through it (`hewtd integrate`, `hewtd
archive`, `hewtd maintain`) rather than hand-managed markdown, so the doc lands
in a domain and the indexes stay honest.

## How to operate it

Nothing to run — the phases arrive with the plan:

```bash
/start-planning "Refactor auth"          # sm: task_plan.md seeded with 7 phases
/start-planning "Foundation" --mode lg   # lg: phase.md seeded with 3 closing tasks
```

To confirm the templates still seed them correctly after editing:

```bash
npm test
```

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| A new plan has only 4 phases | Plan created by persistent-planning < 3.1.0 | Append the closing phases by hand; upgrade the plugin |
| Closing phases are no longer last | Work appended below them | Move the new phases above the group and renumber |
| A plan has validate/docs closers but no cleanup | Plan created by persistent-planning < 3.5.0 | Add a cleanup phase or task above validate by hand, or leave it — the gate is additive |
| `npm test` fails on "documentation phase is last" | A template edit added a checkbox after the group, or reworded it | Restore the ordering in `scripts/init-planning.sh` / `templates/lg/phase.md` |
| Phase marked `done` with closing tasks unchecked | Skipped the gate | Not done — finish all three, then mark the phase |


## How they are enforced (3.3.0+)

In lg mode the closers are no longer only checkbox lines. `init-phase.sh` scaffolds
each as a real task directory — `task.md` with `mandatory: true`, `notes.md`, `atoms/`,
and seeded atoms — so they are addressable artifacts like every other task.

Two mechanisms keep the rule true rather than advisory:

- **Ordering by construction.** `init-task.sh` inserts every new task *above* the first
  MANDATORY entry, so the closers cannot be pushed out of last place by adding work.
- **Completion gated on status.** `plan-status.sh` refuses `COMPLETE` while any
  `mandatory: true` task's own `status:` is not `done`. Ticking its checkbox is not
  enough — a closer that was ticked but never performed is exactly the failure being
  guarded.

Legacy plans without `mandatory:` frontmatter keep their previous behavior; the gate is
strictly additive. See [`mandatory:` frontmatter](../reference/mandatory-frontmatter.md)
and [lg plan artifact lifecycle](../architecture/lg-plan-artifact-lifecycle.md).
