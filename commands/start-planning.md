---
name: start-planning
description: "Initialize persistent planning structure. In sm mode (solo/small) creates .planning/[task-slug]/ with task_plan.md + notes.md (v2 behavior). In lg mode (team/large), creates a phase: .planning/[phase-slug]/{phase.md, notes.md} and bootstraps .planning/.meta/workspace.json. Mode auto-detects via 90-day git author count (≥2 = lg) or can be forced with --mode."
---

# /start-planning

Initialize the persistent planning structure. Mode (sm vs lg) determines what gets created.

---

## Usage

```
/start-planning "Your name here"                    # auto-detect mode
/start-planning "Your name here" --mode sm          # force small mode (single task)
/start-planning "Your name here" --mode lg          # force large mode (phase)
```

## Mode behavior

- **sm mode** (solo / small): creates `.planning/<slug>/{task_plan.md, notes.md}`. Single-task flow. Identical to v2 behavior.
- **lg mode** (team / large): creates `.planning/<phase-slug>/{phase.md, notes.md}` — the new top-layer "phase" artifact. Add tasks under it with `/start-task`, atoms with `/start-atom`. Bootstraps `.planning/.meta/workspace.json`.

Mode is auto-detected via 90-day git author count (≥2 distinct authors → lg, else sm), with a printed decision banner. Once detected (or explicitly set with `--mode`), the choice is sticky in `.planning/.meta/workspace.json` for all subsequent runs.

## Examples

```
/start-planning "Refactor authentication system"        # solo: makes a task plan
/start-planning "Foundation"                            # team: makes a phase
/start-planning "Multi-corpus refactor" --mode lg       # force lg
/start-planning "Quick spike" --mode sm                 # force sm
```

---

## What To Do

When the user runs `/start-planning "<name>" [--mode sm|lg]`:

1. **Resolve mode**:
```bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/../scripts"
# Honor explicit --mode flag if given; otherwise detect.
if [ -n "$EXPLICIT_MODE" ]; then
    MODE="$EXPLICIT_MODE"
else
    MODE=$(bash "${SCRIPT_DIR}/detect-mode.sh" --explain)
fi
```

2. **Dispatch by mode**:

If `MODE=sm`:
```bash
bash "${SCRIPT_DIR}/init-planning.sh" "<name>"
```

If `MODE=lg`:
```bash
bash "${SCRIPT_DIR}/init-phase.sh" "<name>"
```

If `--mode lg` was passed but workspace.json already exists with `mode: sm` (or vice versa), update workspace.json to the new mode (the override sticks).

3. **After the script completes**:
   - sm mode: remind the user to edit `task_plan.md`, update `Status`, save to `notes.md`
   - lg mode: remind the user to add tasks via `/start-task "<task name>" --parent <phase-slug>`

If a script isn't found at the resolved path, try these fallbacks in order:
```bash
bash scripts/init-phase.sh "<name>"          # for lg
bash scripts/init-planning.sh "<name>"        # for sm
bash ~/.claude/skills/persistent-planning/scripts/init-phase.sh "<name>"
bash ~/.claude/skills/persistent-planning/scripts/init-planning.sh "<name>"
```

---

## What It Creates

### sm mode
```
.planning/
└── <slug>/
    ├── task_plan.md    # Track phases inline + progress
    └── notes.md        # Store research and findings
```

### lg mode
```
.planning/
├── .meta/
│   └── workspace.json    # {mode: "lg", auto_detected: true, ...}
└── <phase-slug>/
    ├── phase.md          # HEWTD-frontmattered top-layer artifact
    └── notes.md          # Cross-cutting notes for the phase
```

Add tasks under a phase with `/start-task "<name>" --parent <phase-slug>`.

### Both modes
`.claude/rules/persistent-planning.md` is added if the project does not already have
it. It is never overwritten, so edit it freely.

A "Persistent plans" git section (sync main, branch, commit per phase, one PR) is
appended once to the project's existing git workflow rule, or `.claude/rules/git-workflow.md`
is created to hold it.

## Slug conversion

Names are converted to URL-friendly slugs:
- "Refactor Authentication" → `refactor-authentication`
- "Multi-Corpus Refactor" → `multi-corpus-refactor`
- "Fix Bug #123" → `fix-bug-123`

## See also

- `/start-task` — add a task under a phase (lg mode only)
- `/start-atom` — add an atom (subagent hand-off unit) under a task (lg mode only)
- `.documentation/reference/workspace-json.md` — workspace.json schema reference
- `.documentation/architecture/lg-mode.md` — full lg-mode guide (phase / task / atom / notes layer model)
