---
title: A plan's docs step has no hit-em-with-the-docs steps
tier: guide
domains:
  - troubleshooting
audience:
  - developers
tags: []
status: active
last_updated: '2026-10-23'
version: 1.0.0
purpose: Why a new plan in a hit-em-with-the-docs project got the generic docs step, and how to fix it.
estimated_read_time: 2 minutes
word_count: 224
last_validated: '2026-10-23'
backlinks: []
---

# A plan's docs step has no hit-em-with-the-docs steps

## Symptom

The project uses hit-em-with-the-docs, but a new plan's last step is the generic
one. sm: `Phase 7: Documentation pass -- create/update/deprecate as many docs as
needed to capture what was done…`. lg: the docs closer has no `hewtd audit`,
gotcha or KB-article atoms. The full hit-em-with-the-docs pass wording is missing.

## Cause

The init scripts choose the wording once, when the plan is written. They use the
hewtd variant only when the **project** has a `.documentation/` tree or
`.claude/hit-em-with-the-docs.json`. Common reasons it wasn't chosen:

- **hewtd is only installed for the machine** (e.g. a marketplace install).
  That's deliberate: otherwise every repo you plan in would get hewtd steps.
- **The plan predates the docs tree.** The project adopted hewtd after the plan
  was written. Existing plans are never rewritten.
- **`CLAUDE_PROJECT_DIR` points somewhere else.** The scripts look in
  `CLAUDE_PROJECT_DIR`, falling back to the current directory, not the git root.

## Fix

1. Check what the scripts see:
   ```bash
   ls -d "${CLAUDE_PROJECT_DIR:-$PWD}/.documentation" \
         "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hit-em-with-the-docs.json"
   ```
2. If neither exists, set the project up with hit-em-with-the-docs (that creates
   `.documentation/`), then start the plan again.
3. For a plan that already exists, edit its last step by hand. sm: the Phase 7
   line. lg: the docs closer's line in `phase.md` and its atoms. Or re-create it with
   `PLANNING_FORCE=1` if nothing in it is worth keeping. Keep the lg slug
   `documentation-pass-create-update-deprecate-docs`, because the completion gate
   depends on it.

See [mandatory closing phases](../standards/mandatory-closing-phases.md) for the
two variants.
