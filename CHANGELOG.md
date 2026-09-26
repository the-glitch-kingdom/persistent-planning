# Changelog

All notable changes to this project will be documented in this file.

## [3.5.0] - 2026-09-26

### Added — a mandatory cleanup closer at the end of every phase (#20)

Every plan now ends with three mandatory closers instead of two:

1. **Cleanup — remove junk and unused code** (new)
2. Validate success through comprehensive testing
3. Documentation pass

Agent-driven work reliably leaves debris: scratch and test scripts, temp
output, probe logging, one-off test functions, commented-out code, and code or
imports left unused by abandoned approaches. None of it fails a test and none
of it is a doc, so neither existing closer caught it.

Cleanup runs *first* of the three so validation proves every deletion safe, and
docs describe the final state. Its scope is only what the phase created or
changed; uncertain items go in `notes.md` instead of being deleted.

- **lg**: `init-phase.sh` scaffolds `cleanup-remove-junk-and-unused-code/` as a
  real task dir with `mandatory: true` and seeded atoms, third-to-last in
  `phase.md`. Insertion and the completion gate needed no change — new tasks
  already land above the first `MANDATORY` entry, and `plan-status.sh` already
  gates on every `mandatory: true` task.
- **sm**: `task_plan.md` gains Phase 5 Cleanup; validate and docs renumber to 6
  and 7. This is a deliberate change to the v2 sm template, as #5 was.

Existing plans are untouched; they simply lack the third closer.

## [3.4.2] - 2026-09-05

### Changed — the local `update` guard moves upstream into the runtime

3.4.0 added a `preAction` guard in `bin/persistent-planning.js` because the
runtime's `update` resolved installation state from `<cwd>/node_modules` and
`CLAUDE_PLUGIN_ROOT` only, found neither in a marketplace-only install, and
exited 0 after an `npm update` that touched nothing. The guard worked, but it
was a workaround living in one plugin while every sibling stayed broken —
babel-fish#17 was the same defect reported against babel-fish.

Fixed properly in `@theglitchking/claude-plugin-runtime` 0.1.1, which this
release requires. `resolveInstall()` there probes npm dep → `CLAUDE_PLUGIN_ROOT`
→ the marketplace record in `~/.claude/plugins/installed_plugins.json`, so the
26-line guard is deleted rather than reimplemented.

The result is strictly better than the guard it replaces. Previously a
marketplace install satisfied the guard and fell through to a no-op `npm update`
that exited 0; now it is recognised, named by path, and refused with a pointer
at `/plugin` — the only thing that can actually update a plugin-cache copy.

The dependency floor is `^0.1.1`, not `^0.1.0`: the shared plugin dep tree at
`~/.claude/plugins/npm-cache` pins the runtime at 0.1.0 in its lockfile, and
0.1.0 still satisfies `^0.1.0`, so the broken copy would have survived.

### Fixed — the CLI test depended on the developer's own machine

`tests/run.sh` ran `update` in a temp workspace but inherited the real `$HOME`,
so once the runtime learned to read `~/.claude/plugins/installed_plugins.json`
the assertion passed or failed depending on whether the person running it
happened to have the plugin installed. `HOME` is now overridden, and the
marketplace branch is asserted against a fixture rather than a machine.

## [3.4.1] - 2026-09-04

### Fixed — the SessionStart hook could not survive a missing runtime (#18)

`hooks/session-start.js` imported `@theglitchking/claude-plugin-runtime` statically. That
package resolves out of the shared `~/.claude/plugins/npm-cache/`, which a marketplace
plugin cache does not carry itself, so when it could not resolve the **entire hook died** —
`ERR_MODULE_NOT_FOUND` before any of its work ran.

That took down the drift warning and `autoRepair` along with the update check: the two
things #10 built precisely so a fix could reach an install that is already broken. The
delivery path had a single point of failure the payload was meant to survive.

- **The runtime is loaded lazily now**, in a try/catch returning `null`. A resolution
  failure costs only the update check; the completion nudge, drift warning and repair all
  still run, and the hook emits its own valid `SessionStart` payload since nothing else
  will.
- **A failed repair no longer stamps the version.** `autoRepair` previously stamped
  `repairedSkillsForVersion` regardless of outcome, to avoid retrying every session — which
  turned a *transient* failure into a permanent one. Reproduced: one session without a
  resolvable runtime marked 3.4.0 done, and the repair was then skipped forever even once
  the runtime returned. It stamps on success only; a failure costs one spawn per session
  while genuinely drifted, and the drift warning fires alongside it naming the manual fix.

Both defects came from the #10 work and shipped in 3.4.0. Test suite grows to 125
assertions, including a fixture with no `node_modules` at all.

## [3.4.0] - 2026-09-04

### Changed — only completed plans are gitignored (#15)

Both init scripts blanket-ignored the entire `.planning/` tree, a v1.0.0 behavior
(`fb35f19`) that 3.1.0 implicitly reversed and never removed. `archive-plan.sh` had
already decided only completed plans are local history, and four shipped docs —
`SKILL.md`, `lg-mode.md` (twice), `README.md` — described `.planning/.archive/` as *the*
gitignored path. The code did the opposite.

In lg mode the contradiction was sharpest: that mode is selected because ≥2 git authors
exist, plans are what subagents read via the planning MCP, and the first thing
`init-phase.sh` did was guarantee no teammate would ever receive them. The blanket entry
also suppressed `archive-plan.sh`'s narrow one — its first guard returns early when the
whole tree is ignored — so the narrow entry could never appear in a repo where
`/start-planning` had run, which is every repo.

- **Active plans are tracked; only `.planning/.archive/` is ignored.** One rule, shared by
  both lg init and `archive-plan.sh` via `planning_ensure_archive_gitignored`;
  `init-planning.sh` keeps its own copy since it is deliberately self-contained.
- **An existing blanket `.planning/` line is never rewritten.** It is the user's file. The
  tool says once how to narrow it and moves on — otherwise the plans someone is about to
  create are invisible to their team and nothing tells them.
- **Init still never creates a `.gitignore`** where none exists. `archive-plan.sh` does,
  because it has just moved files into `.archive/` and that path must be ignored for the
  move to mean anything.

sm plan output remains byte-identical. Test suite grows to 119 assertions.

## [3.3.1] - 2026-09-04

### Fixed — a plan that documented markdown could not complete (#14)

`plan-status.sh` had one correct frontmatter reader and three that scanned whole files:
the checkbox counter, the mandatory gate, and blocked detection. A `notes.md` that merely
*documented* the contract — which is what notes.md is for — tripped all three:

- a fenced `- [ ]` example inflated the denominator, so the plan could never reach
  COMPLETE. A quoted `- [x]` cancelled out; a quoted `- [ ]` did not.
- a fenced `mandatory: true` held the plan open with the box count showing a perfect
  `1/1` — **no visible signal at all**, and the documented triage steps pointed at a
  notes file that was pure prose. Regression from #13.
- a fenced `status: blocked` produced a false `blocked` verdict, masked whenever the plan
  was otherwise COMPLETE, so it surfaced only intermittently.

`archive-plan.sh` inherited all three through its pre-flight and refused to archive,
advising `--force` — wrong advice for a miscount.

The fix splits in two, because these are not the same defect:

- **Checkboxes are body content**, so counting is now fence-aware — backtick and tilde
  fences, tagged or not, indented, closing only on their own character. An unterminated
  fence swallows the rest of the file: ambiguous content is not counted as outstanding.
- **`status:` and `mandatory:` are frontmatter fields**, so they are read from the leading
  `---` block via the existing scoped reader, generalised as `frontmatter_field`. That is
  strictly stronger than fence-stripping — it also rejects the field appearing in prose or
  a table.

All consumers — `archive-plan.sh`, `/plan-status`, the SessionStart hook — shell out to
`plan-status.sh` and needed no change. Test suite grows to 109 assertions.

## [3.3.0] - 2026-09-04

### Fixed — lg task lists were maintained by hand, and the mandatory closers were unenforceable (#12)

`init-task.sh` never wrote to `phase.md` — it referenced the file only in an existence
check — and `init-atom.sh` never wrote the atom into its task. So **every lg task list was
maintained by hand**: create six task directories and the phase still reported
`(no tasks yet)`. The "closers must stay last" rule therefore governed a list no tool
produced, and the test that claimed to cover it only ever inspected a freshly rendered
template, which can never be wrong.

- **Creating a child writes it into its parent's list.** `planning_insert_list_item` in
  `scripts/lib/planning.sh` inserts above the first `MANDATORY` entry — so the closers stay
  last *by construction* — appends after the last item in sections with no MANDATORY
  entries, drops the placeholder on first use, is idempotent under `PLANNING_FORCE=1`, and
  is section-scoped. It anchors on the MANDATORY marker, never on line numbers, because the
  list is a human-editable surface.
- **The closers are real task directories now.** `init-phase.sh` scaffolds
  `validate-success-through-comprehensive-testing/` and
  `documentation-pass-create-update-deprecate-docs/` with `task.md` (`mandatory: true`,
  `parallelizable: false`), `notes.md`, `atoms/`, and seeded atoms. Previously the two most
  important tasks in every plan were the only ones with no artifact a subagent could read.
- **Placeholders stopped counting as work.** `(no tasks yet …)` and `(no atoms yet …)`
  shipped as real checkboxes, and `plan-status.sh` counts every box under a plan — a fresh
  phase with two tasks reported `0/5`, a plan could reach 100% by ticking lines asserting
  nothing existed, and a finished phase stayed open until someone ticked "no tasks yet".
  They are italic text now; `plan-status.sh` needed no change.
- **The completion gate is real.** `plan-status.sh` refuses `COMPLETE` while any
  `mandatory: true` task's own `status:` is not `done`. Ticking its checkbox is not enough.
  `archive-plan.sh` inherits this through its existing pre-flight rather than duplicating
  the rule. Strictly additive: plans with no `mandatory:` frontmatter behave exactly as
  before.

Test suite grows to 99 assertions, every new one mutating the plan before asserting.
sm mode verified byte-identical against the pre-change render. New docs:
`.documentation/architecture/lg-plan-artifact-lifecycle.md`,
`.documentation/reference/mandatory-frontmatter.md`,
`.documentation/troubleshooting/plan-never-reads-complete.md`.

## [3.2.0] - 2026-09-04

### Fixed — Stale skill directories run frozen code (#10)

A consumer repo could run a **pre-3.1.0 copy** of the skill indefinitely while the update
check reported the current version — no nudge, no warning, exit 0 everywhere. Plans
generated that way silently omitted the mandatory validate and documentation phases and
the entire `## On Completion` archive block: precisely the guarantees 3.1.0 was released
to make.

**Cause.** v1's `persistent-planning install` (removed in 2.0.0) *copied*
`skills/persistent-planning/` into `.claude/skills/`. The v2+ linker only symlinks, and
when it finds a real directory at the destination it warns and skips — permanently. So
`installedVersion()` reported the plugin's version while `/start-planning` executed the
skill dir's frozen copy. Two artifacts, nothing reconciling them. (The linker was never
copying, as first reported; it was refusing to reclaim what v1 left behind.)

- **Reclaim instead of skip** — `scripts/lib/skill-link.js` renames a real directory to
  `<name>.bak-<ISO8601>` before the runtime's linker runs, leaving a clean destination it
  then symlinks normally. Nothing is ever deleted; a failed rename falls through to the
  old skip but says so loudly and names the fix. Idempotent — a healthy symlink is left
  alone, so a second run makes no second backup. Opt out with
  `PERSISTENT_PLANNING_NO_RECLAIM=1`.
- **The drift is detectable now.** The primary signal is structural: a real directory at
  `.claude/skills/<name>` is *always* drift, because nothing in the current system creates
  one. A `.version` marker beside `SKILL.md` is the secondary signal — how far behind a
  drifted copy is, and the only signal available where symlinks are impossible. Only
  healthy symlinks are stamped; stamping a stale copy would mark it current.
- **SessionStart reports it**, naming the path, the running vs installed version, the
  user-visible consequence, and `npx persistent-planning relink`. Merged into the existing
  single JSON response; fails open; silent under `updatePolicy: off`.
- **SessionStart repairs it under `updatePolicy: auto`**, once per plugin version. This is
  the part that reaches the installs that are actually broken: a marketplace install has
  no `node_modules` in the plugin cache and **never runs npm postinstall**, so a fix
  shipped only through postinstall would reach nobody affected. The hook is the one thing
  that runs every session in that shape. `nudge` warns without touching the filesystem;
  `off` does nothing at all.
- **No more clean exits for no-ops.** `update` with no managed install exits 1 and lists
  every path probed, instead of printing `(not installed)` twice and exiting 0. `relink`
  gained `CLAUDE_PLUGIN_ROOT/scripts/` and self-package probes — it previously could not
  run at all in a marketplace-only install, the shape that needs it most — and no longer
  swallows the linker's exit code.

Test suite grows to 74 assertions, including a marketplace-shaped fixture with no
`node_modules`. New docs: `.documentation/troubleshooting/stale-skill-dir-drift.md`,
`.documentation/architecture/skill-linking-and-reclaim.md`,
`.documentation/reference/skill-version-marker.md`,
`.documentation/procedures/plugin-update-delivery.md`.

## [3.1.0] - 2026-08-31

### Added — Status tracking and completion archive (#4)

Plans now report their own completion, and completed plans get retired out of the active tree.

**Completion is derived, not declared.** A plan is COMPLETE when every checkbox under it is checked, or when its top-level artifact (`phase.md` / `task_plan.md` / `task.md`) declares `status: done`. Nothing has to be remembered or kept in sync — checking the last box *is* the signal. Combined with the mandatory closing phases above, a plan cannot read COMPLETE until its work has been tested and documented.

- `scripts/plan-status.sh` — the single implementation of the scan. Default output is a table (`in progress` / `blocked` / `COMPLETE` / `empty` / `archived` with a checked/total count); `--complete` prints one complete slug per line; `--nudge` prints a one-line notice or nothing.
- `scripts/archive-plan.sh` — moves `.planning/<slug>/` to `.planning/.archive/<slug>/`, ensures that path is gitignored, and stamps the top-level artifact `status: archived` + `archived_on` (or a dated footer for sm plans without frontmatter). Prefers `git mv` when the plan is tracked. Refuses incomplete plans unless `--force`; also supports `--all-complete` and `--dry-run`. Nothing is ever deleted.
- `hooks/session-start.js` — now surfaces complete-but-unarchived plans in the session's context. It merges the notice into the runtime's single `SessionStart` response by intercepting that one stdout write, since the runtime exposes no append hook and a second response line would be invalid; it fails open, so the update check is unaffected if the payload isn't the expected shape.
- `/plan-status` and `/archive-plan` slash commands.
- Both plan templates gained an `## On Completion` section stating the rule and the archive command, so an agent reading only the plan still learns the protocol.

`.planning/.archive/` is gitignored on purpose: a completed plan is local history. Anything worth sharing gets promoted into a real doc by the mandatory documentation phase.

Test suite grows to 42 assertions. New doc: `.documentation/procedures/plan-completion-and-archive.md`.

### Added — Mandatory closing phases (#5)

Every plan now ends with the same two units of work, seeded by the templates so an agent never has to remember them:

1. **Validate success through comprehensive testing**
2. **Documentation pass — create/update/deprecate docs**

- **sm mode**: `task_plan.md` seeds 6 phases instead of 4; phases 5 and 6 are the mandatory pair, marked `MANDATORY`.
- **lg mode**: `templates/lg/phase.md` seeds the pair as the last two task checkboxes. A phase cannot be marked `done` until both are `done`, and neither may be `parallelizable`.
- Both templates carry the ordering rule inline: new work is inserted **above** the pair, never after it.

### Added — Test suite

`tests/run.sh` — plain bash asserts (no framework), wired to `npm test`. 21 assertions covering sm/lg init, the closing-phase ordering, slug conversion, template placeholder substitution, atom sequence auto-increment, idempotent re-runs, and the lg-mode guard on `init-phase.sh`.

### Changed — Documentation moved to hit-em-with-the-docs

`docs/` is gone; documentation now lives in a hewtd-managed `.documentation/` tree, split by domain:

| Was | Now |
|---|---|
| `docs/lg-mode.md` | `.documentation/architecture/lg-mode.md` |
| `docs/reference.md` | `.documentation/architecture/context-engineering-principles.md` |
| `docs/atom-granularity.md` | `.documentation/standards/atom-granularity.md` |
| `docs/workspace-json.md` | `.documentation/reference/workspace-json.md` |
| `docs/examples.md` | `.documentation/quickstart/examples.md` |

New docs: `.documentation/standards/mandatory-closing-phases.md` and `.documentation/testing/test-suite.md`. A custom `reference` domain is registered in `.claude/hit-em-with-the-docs.json`. The npm `files` array now ships `.documentation/` in place of `docs/`.

Links in older CHANGELOG entries still point at the old `docs/` paths; they are left as written, since they describe the layout as it was at those releases.

## [3.0.1] - 2026-05-08

### Fixed
- **Critical: lg-mode init scripts and templates were excluded from the npm package.** The 3.0.0 release had `scripts/link-skills.js` (singular file) in the package.json `files` array instead of `scripts/` (whole dir), and `templates/` was missing entirely. As a result, users installing v3.0.0 got the slash command markdown but the underlying `init-phase.sh`, `init-task.sh`, `init-atom.sh`, `detect-mode.sh`, `lib/planning.sh`, and the four lg-mode templates (`phase.md`, `task.md`, `atom.md`, `notes.md`) were all missing — meaning lg mode silently broke on first invocation.

  This patch updates the `files` array to include `scripts/` and `templates/` directories, and bumps to 3.0.1. v3.0.0 should be considered broken; consumers should upgrade to 3.0.1 immediately.

### How this happened
The `files` array was the legacy v2 contents (which only needed `scripts/link-skills.js`). When v3.0 added new scripts and templates I missed updating the array. Caught when verifying the published 3.0.0 tarball contents.

## [3.0.0] - 2026-05-07

### Added — Lg-mode (large/team) layered planning

v3.0 introduces a new **layered planning mode** alongside the existing single-task flow. The mode is auto-detected (90-day git-author-count heuristic; ≥2 distinct authors → lg) and is sticky once chosen.

**Four layers** in lg mode:

- **Phase** — strategic grouping of related tasks (top)
- **Task** — bounded deliverable; declares `depends_on` + `parallelizable` for subagent team scheduling
- **Atom** — subagent hand-off unit; sequential within a task; status: `ready | in_progress | done | blocked` with reopen support
- **Notes** — cross-cutting references scoped to a phase or task

All four layers carry HEWTD-aligned frontmatter (`tier: plan`). `version` is intentionally omitted — HEWTD 2.2.0+ makes it conditionally optional for plan-tier docs.

### Added — `/start-task` and `/start-atom` slash commands

- `/start-task "<name>" --parent <phase>` — adds a task under an existing phase (lg only)
- `/start-atom "<name>" --parent <task>` — adds an atom (subagent hand-off unit) under a task (lg only); auto-resolves the parent phase by walking `.planning/`; auto-assigns sequence number
- `/start-planning` updated to dispatch sm vs lg based on detect-mode.sh; accepts `--mode sm|lg` for explicit override

### Added — `.planning/.meta/workspace.json`

Per-project mode tracker. Fields: `schema_version`, `mode`, `auto_detected`, `detected_contributors`, `created_at`. Bootstrapped on first lg-mode init. See `docs/workspace-json.md` for the full schema.

### Added — Documentation

- `docs/lg-mode.md` — full lg-mode guide
- `docs/atom-granularity.md` — anti-pattern guide for inline-checkbox-vs-standalone-atom
- `docs/workspace-json.md` — workspace.json schema reference

### Added — Scripts

- `scripts/detect-mode.sh` — sm/lg resolution
- `scripts/lib/planning.sh` — shared bash helpers
- `scripts/init-phase.sh`, `scripts/init-task.sh`, `scripts/init-atom.sh` — lg-mode init scripts

### Added — Templates

- `templates/lg/{phase,task,atom,notes}.md` — HEWTD-frontmattered layer templates

### Subagent contract (requires semantic-memory 1.0)

Lg-mode plans are designed to be read by subagents via semantic-memory's MCP verbs (registered conditionally on the `plans` corpus). When semantic-memory is absent, persistent-planning falls back to filesystem-based reads — slash commands still work; subagent comprehension degrades.

### Backwards compatibility

- **Sm mode preserved exactly**: existing `.planning/<task-slug>/{task_plan.md, notes.md}` directories continue to work without changes. The original `/start-planning "Task name"` flow is identical to v2.
- **Auto-detection is non-disruptive**: existing v2 plans aren't migrated. New `/start-planning` invocations auto-detect mode and create new artifacts using the resolved mode.

### Optional dependencies

- `@theglitchking/hit-em-with-the-docs ^2.2.0` — required for `hewtd validate` to accept lg-mode plan frontmatter (introduces `tier: "plan"` + conditional `version`)
- `@theglitchking/semantic-memory ^1.0.0` (formerly `semantic-sidekick`) — required for the planning MCP verbs that subagents use to read/mutate lg-mode plans

When neither is installed, lg mode still works as a pure file-authoring flow.

## [2.0.0] - 2026-04-18

### ⚠️ Breaking changes

v2.0.0 removes the hand-rolled `persistent-planning install|uninstall`
flow in favor of standard Claude Code plugin distribution and npm install
paths. Plugin skill and command files are now delivered **automatically**
— no manual copy step.

**If you're an existing v1 user**, here's what to expect and how to
upgrade:

- `persistent-planning install --scope user` is gone. Install instead via
  the plugin marketplace:

  ```
  /plugin marketplace add TheGlitchKing/persistent-planning
  /plugin install persistent-planning@persistent-planning-marketplace
  ```

  Or, for a project-local install that's visible to teammates and CI:

  ```
  npm install --save-dev @theglitchking/persistent-planning
  ```

- `persistent-planning uninstall` is gone. Use `/plugin uninstall` or
  `npm uninstall @theglitchking/persistent-planning` depending on how you
  installed it.

- **Old skill/command files in `~/.claude/` or `./.claude/`** placed by
  v1's installer will keep working until you remove them — but the
  marketplace plugin and the npm postinstall both place their own copies,
  so to avoid duplication you should delete the manually-installed
  copies once you've adopted v2:

  ```
  # If you installed with --scope user:
  rm -rf ~/.claude/skills/persistent-planning
  rm ~/.claude/commands/start-planning.md

  # If you installed with --scope project:
  rm -rf .claude/skills/persistent-planning
  rm .claude/commands/start-planning.md
  ```

- The old `install`/`uninstall` subcommands still exist as deprecation
  shims — running them prints a migration pointer and exits cleanly
  instead of failing.

### Added
- Adopts `@theglitchking/claude-plugin-runtime` for postinstall skill
  symlinking, SessionStart update nudge/auto-apply, and standardized
  `update`/`policy`/`status`/`relink` CLI subcommands.
- Default `updatePolicy: "nudge"` — on session start, the plugin checks
  npm for a newer version and prints a one-liner when one exists. Opt
  into `auto` for background auto-update, or `off` to silence entirely.
- Four new slash commands: `/persistent-planning:update`,
  `/persistent-planning:policy`, `/persistent-planning:status`,
  `/persistent-planning:relink`.

### Changed
- **Skill layout**: `skills/SKILL.md` moved to
  `skills/persistent-planning/SKILL.md` so the runtime can symlink it
  into consuming projects' `.claude/skills/persistent-planning/`.
- **Slash command location**: `.claude/commands/start-planning.md` moved
  to `commands/start-planning.md` (top-level, matching the marketplace
  plugin convention).
- Node >= 20 required (was >= 16).

### Removed
- `install.sh`, `uninstall.sh`, and the `postinstall.js` banner script.
- The root-level `plugin.json` — manifest is now only at
  `.claude-plugin/plugin.json`.

## [1.0.0] - 2026-02-12

### Added
- Core skill definition (`skills/SKILL.md`) with persistent markdown-based planning
- `/start-planning` slash command for one-command setup
- `init-planning.sh` script for automated `.planning/` directory creation
- Task-specific subdirectories (`.planning/[task-slug]/`)
- `task_plan.md` and `notes.md` templates
- Multiple concurrent task support
- Reference documentation on Manus context engineering principles
- Worked examples for research, bug fix, and feature development workflows
- `install.sh` installer with user/project scope support
- `uninstall.sh` for clean removal
- Plugin manifest files for marketplace compatibility

### Based On
- Context engineering principles from [Manus AI](https://manus.im/de/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- Original [planning-with-files](https://github.com/OthmanAdi/planning-with-files) skill by Ahmad Othman Ammar Adi
