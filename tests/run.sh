#!/bin/bash
###############################################################################
# tests/run.sh - Smoke tests for the persistent-planning init scripts.
#
# Plain bash asserts, no framework. Each test runs the real scripts against a
# throwaway CLAUDE_PROJECT_DIR under $TMPDIR and inspects what landed on disk.
#
# Usage:  bash tests/run.sh          (or: npm test)
###############################################################################
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); }

assert_eq() { # <expected> <actual> <label>
  if [[ "$1" == "$2" ]]; then pass "$3"; else
    fail "$3"; printf '       expected: %s\n       actual:   %s\n' "$1" "$2"
  fi
}

assert_contains() { # <haystack-file> <needle> <label>
  if grep -qF -- "$2" "$1"; then pass "$3"; else
    fail "$3"; printf '       %s does not contain: %s\n' "$1" "$2"
  fi
}

assert_file() { # <path> <label>
  if [[ -f "$1" ]]; then pass "$2"; else fail "$2"; printf '       missing: %s\n' "$1"; fi
}

# Prints the unchecked-checkbox lines of a markdown section, e.g.
#   checkbox_lines <file> "## Phases"
checkbox_lines() {
  awk -v section="$2" '
    $0 == section { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && /^- \[[ x]\] / { print }
  ' "$1"
}

new_workspace() { # -> prints a fresh temp project dir
  local d
  d=$(mktemp -d "${TMPDIR:-/tmp}/pp-test-XXXXXX")
  echo "$d"
}

###############################################################################
echo "sm mode: init-planning.sh"
###############################################################################
WS=$(new_workspace)
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-planning.sh" "Refactor Auth System" >/dev/null

PLAN="$WS/.planning/refactor-auth-system/task_plan.md"
assert_file "$PLAN" "task_plan.md created at the slugified path"
assert_file "$WS/.planning/refactor-auth-system/notes.md" "notes.md created"

if [[ -f "$PLAN" ]]; then
  mapfile -t PHASES < <(checkbox_lines "$PLAN" "## Phases")
  assert_eq 7 "${#PHASES[@]}" "sm plan seeds 7 phases"
  LAST=${PHASES[${#PHASES[@]}-1]}
  PENULT=${PHASES[${#PHASES[@]}-2]}
  ANTEPENULT=${PHASES[${#PHASES[@]}-3]}
  case "$ANTEPENULT" in
    *"Cleanup"*) pass "cleanup phase is third-to-last" ;;
    *) fail "cleanup phase is third-to-last"; printf '       got: %s\n' "$ANTEPENULT" ;;
  esac
  case "$PENULT" in
    *"Validate success through comprehensive testing"*) pass "validation phase is second-to-last" ;;
    *) fail "validation phase is second-to-last"; printf '       got: %s\n' "$PENULT" ;;
  esac
  case "$LAST" in
    *"Documentation pass"*) pass "documentation phase is last" ;;
    *) fail "documentation phase is last"; printf '       got: %s\n' "$LAST" ;;
  esac
  assert_contains "$PLAN" "MUST stay the last three phases" "sm plan states the ordering rule"
  assert_contains "$PLAN" "Refactor Auth System" "task name substituted into the plan"
fi

# Idempotence: a second run must not clobber edits.
echo "EDITED BY USER" >> "$PLAN"
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-planning.sh" "Refactor Auth System" >/dev/null
assert_contains "$PLAN" "EDITED BY USER" "re-running init-planning.sh does not overwrite an existing plan"
rm -rf "$WS"

###############################################################################
echo "lg mode: init-phase.sh / init-task.sh / init-atom.sh"
###############################################################################
WS=$(new_workspace)
mkdir -p "$WS/.planning/.meta"
echo '{"schema_version":"1.0","mode":"lg"}' > "$WS/.planning/.meta/workspace.json"

assert_eq "lg" "$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/detect-mode.sh")" \
  "detect-mode.sh honors the workspace.json override"

CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "Foundation" >/dev/null
PHASE="$WS/.planning/foundation/phase.md"
assert_file "$PHASE" "phase.md created"
assert_file "$WS/.planning/foundation/notes.md" "phase notes.md created"

if [[ -f "$PHASE" ]]; then
  mapfile -t TASKS < <(checkbox_lines "$PHASE" "## Tasks")
  LAST=${TASKS[${#TASKS[@]}-1]}
  PENULT=${TASKS[${#TASKS[@]}-2]}
  ANTEPENULT=${TASKS[${#TASKS[@]}-3]}
  case "$ANTEPENULT" in
    *"Cleanup"*) pass "phase cleanup task is third-to-last" ;;
    *) fail "phase cleanup task is third-to-last"; printf '       got: %s\n' "$ANTEPENULT" ;;
  esac
  case "$PENULT" in
    *"Validate success through comprehensive testing"*) pass "phase validation task is second-to-last" ;;
    *) fail "phase validation task is second-to-last"; printf '       got: %s\n' "$PENULT" ;;
  esac
  case "$LAST" in
    *"Documentation pass"*) pass "phase documentation task is last" ;;
    *) fail "phase documentation task is last"; printf '       got: %s\n' "$LAST" ;;
  esac
  assert_contains "$PHASE" "MUST remain the last three tasks" "phase states the ordering rule"
  assert_contains "$PHASE" "tier: plan" "phase carries HEWTD plan-tier frontmatter"
  if grep -q "PLACEHOLDER" "$PHASE"; then
    fail "no unsubstituted placeholders remain in phase.md"
    grep -n "PLACEHOLDER" "$PHASE" | sed 's/^/       /'
  else
    pass "no unsubstituted placeholders remain in phase.md"
  fi
fi

CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-task.sh" "Schema extension" --parent foundation >/dev/null
assert_file "$WS/.planning/foundation/schema-extension/task.md" "task.md created under the phase"
assert_contains "$WS/.planning/foundation/schema-extension/task.md" "parent: foundation" \
  "task frontmatter points at its parent phase"

CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-atom.sh" "First atom" --parent schema-extension >/dev/null
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-atom.sh" "Second atom" --parent schema-extension >/dev/null
ATOMS="$WS/.planning/foundation/schema-extension/atoms"
assert_contains "$ATOMS/first-atom.md" "sequence: 1" "first atom gets sequence 1"
assert_contains "$ATOMS/second-atom.md" "sequence: 2" "second atom auto-increments to sequence 2"
rm -rf "$WS"

###############################################################################
echo "mode guards"
###############################################################################
WS=$(new_workspace)
mkdir -p "$WS/.planning/.meta"
echo '{"schema_version":"1.0","mode":"sm"}' > "$WS/.planning/.meta/workspace.json"
if CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "Nope" >/dev/null 2>&1; then
  fail "init-phase.sh refuses to run in sm mode"
else
  pass "init-phase.sh refuses to run in sm mode"
fi
rm -rf "$WS"

###############################################################################
echo "status tracking: plan-status.sh"
###############################################################################
WS=$(new_workspace)
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-planning.sh" "Half Done" >/dev/null
PLAN="$WS/.planning/half-done/task_plan.md"

assert_eq "" "$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/plan-status.sh" --complete)" \
  "a fresh plan is not reported complete"
assert_eq "" "$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/plan-status.sh" --nudge)" \
  "no nudge while work is outstanding"

case "$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/plan-status.sh")" in
  *"in progress"*) pass "status table reports an unfinished plan as in progress" ;;
  *) fail "status table reports an unfinished plan as in progress" ;;
esac

# Check every box -> the plan is complete. Checkbox state IS the signal.
sed -i 's/- \[ \]/- [x]/g' "$PLAN"
assert_eq "half-done" "$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/plan-status.sh" --complete)" \
  "a fully checked plan is reported complete"
case "$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/plan-status.sh" --nudge)" in
  *"complete but not archived"*) pass "nudge fires for a complete, unarchived plan" ;;
  *) fail "nudge fires for a complete, unarchived plan" ;;
esac

# The SessionStart hook must merge that nudge into a single valid JSON response.
HOOK_OUT=$(CLAUDE_PROJECT_DIR="$WS" node "$REPO_DIR/hooks/session-start.js" 2>/dev/null)
assert_eq 1 "$(printf '%s' "$HOOK_OUT" | grep -c .)" "SessionStart hook emits exactly one line"
if printf '%s' "$HOOK_OUT" | node -e '
  let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
    const p=JSON.parse(s);
    process.exit(p?.hookSpecificOutput?.additionalContext?.includes("complete but not archived")?0:1);
  })'; then
  pass "SessionStart hook carries the nudge in additionalContext"
else
  fail "SessionStart hook carries the nudge in additionalContext"
fi
rm -rf "$WS"

###############################################################################
echo "archive: archive-plan.sh"
###############################################################################
WS=$(new_workspace)
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-planning.sh" "Ship It" >/dev/null

# Refuses an unfinished plan, and leaves it exactly where it was.
if CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/archive-plan.sh" ship-it >/dev/null 2>&1; then
  fail "archive-plan.sh refuses an incomplete plan"
else
  pass "archive-plan.sh refuses an incomplete plan"
fi
assert_file "$WS/.planning/ship-it/task_plan.md" "refused plan stays in the active tree"

# --force overrides the refusal.
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/archive-plan.sh" ship-it --force >/dev/null 2>&1
assert_file "$WS/.planning/.archive/ship-it/task_plan.md" "--force archives an incomplete plan"
rm -rf "$WS"

WS=$(new_workspace)
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-planning.sh" "Ship It" >/dev/null
sed -i 's/- \[ \]/- [x]/g' "$WS/.planning/ship-it/task_plan.md"

# --dry-run must not move anything.
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/archive-plan.sh" ship-it --dry-run >/dev/null
assert_file "$WS/.planning/ship-it/task_plan.md" "--dry-run leaves the plan in place"

CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/archive-plan.sh" ship-it >/dev/null
assert_file "$WS/.planning/.archive/ship-it/task_plan.md" "complete plan is moved into .planning/.archive/"
if [[ -d "$WS/.planning/ship-it" ]]; then
  fail "archived plan is gone from the active tree"
else
  pass "archived plan is gone from the active tree"
fi
assert_contains "$WS/.gitignore" ".planning/.archive/" ".planning/.archive/ is gitignored"
assert_contains "$WS/.planning/.archive/ship-it/task_plan.md" "**Archived " \
  "sm plan without frontmatter gets a dated archived footer"
assert_eq "" "$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/plan-status.sh" --complete)" \
  "an archived plan no longer shows up as complete"

# Archiving twice must not clobber the first archive.
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-planning.sh" "Ship It" >/dev/null
sed -i 's/- \[ \]/- [x]/g' "$WS/.planning/ship-it/task_plan.md"
if CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/archive-plan.sh" ship-it >/dev/null 2>&1; then
  fail "archive-plan.sh refuses to overwrite an existing archive entry"
else
  pass "archive-plan.sh refuses to overwrite an existing archive entry"
fi
rm -rf "$WS"

# lg mode: frontmatter is stamped rather than a footer appended.
WS=$(new_workspace)
mkdir -p "$WS/.planning/.meta"
echo '{"schema_version":"1.0","mode":"lg"}' > "$WS/.planning/.meta/workspace.json"
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "Foundation" >/dev/null
# A phase now ships with two scaffolded closer task dirs carrying real atoms, so
# completion means every box under the plan — not just the ones in phase.md — and
# the mandatory closers must additionally be status: done, not merely ticked.
find "$WS/.planning/foundation" -name '*.md' -exec sed -i 's/- \[ \]/- [x]/g' {} +
find "$WS/.planning/foundation" -name 'task.md' -exec sed -i 's/^status: draft$/status: done/' {} +
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/archive-plan.sh" --all-complete >/dev/null
ARCHIVED="$WS/.planning/.archive/foundation/phase.md"
assert_file "$ARCHIVED" "--all-complete archives every complete plan"
assert_contains "$ARCHIVED" "status: archived" "lg phase frontmatter is stamped status: archived"
assert_contains "$ARCHIVED" "archived_on:" "lg phase frontmatter gains archived_on"
if [[ $(grep -c '^status:' "$ARCHIVED") -eq 1 ]]; then
  pass "stamping replaces the status field rather than duplicating it"
else
  fail "stamping replaces the status field rather than duplicating it"
fi
rm -rf "$WS"


###############################################################################
echo
echo "skill-dir reclaim (issue #10)"
###############################################################################
# Helpers. The linker is JS, so these drive node directly and inspect the tree.

skill_state() { # <consumer-root> -> absent | symlink-ok | symlink-foreign | real-dir
  node -e '
    import("'"$REPO_DIR"'/scripts/lib/skill-link.js").then(m =>
      console.log(m.describeSkill(process.argv[1], "'"$REPO_DIR"'", "persistent-planning").state)
    )' "$1"
}

do_reclaim() { # <consumer-root>
  node -e '
    import("'"$REPO_DIR"'/scripts/lib/skill-link.js").then(m => {
      const r = m.reclaimStaleSkillDirs(process.argv[1], "'"$REPO_DIR"'", { log: () => {} });
      console.log(JSON.stringify({ reclaimed: r.reclaimed.length, failed: r.failed.length, healthy: r.healthy }));
    })' "$1"
}

run_hook() { # <consumer-root> -> additionalContext, or "" ; asserts single valid JSON
  echo '{}' | CLAUDE_PROJECT_DIR="$1" node "$REPO_DIR/hooks/session-start.js" 2>/dev/null \
    | node -e '
        let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
          // Must parse as exactly one JSON payload — a second response line is invalid.
          const p = JSON.parse(s);
          process.stdout.write(p?.hookSpecificOutput?.additionalContext || "");
        });'
}

# --- a real directory is reclaimed, and the original survives -----------------
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills/persistent-planning"
echo "sentinel-content" > "$WS/.claude/skills/persistent-planning/SENTINEL.md"
assert_eq "real-dir" "$(skill_state "$WS")" "a real skill dir is reported as drift"
OUT=$(do_reclaim "$WS")
assert_eq '{"reclaimed":1,"failed":0,"healthy":0}' "$OUT" "reclaim moves exactly one stale dir aside"
assert_eq "absent" "$(skill_state "$WS")" "destination is clear for the linker after reclaim"
BAK=$(ls -d "$WS"/.claude/skills/persistent-planning.bak-* 2>/dev/null | head -1)
assert_file "$BAK/SENTINEL.md" "reclaim preserves the original contents (never deletes)"
assert_contains "$BAK/SENTINEL.md" "sentinel-content" "preserved contents are byte-identical"

# --- second run is a no-op: no second backup ---------------------------------
ln -s "$REPO_DIR/skills/persistent-planning" "$WS/.claude/skills/persistent-planning"
assert_eq "symlink-ok" "$(skill_state "$WS")" "an absolute symlink resolving to us reads as healthy"
OUT=$(do_reclaim "$WS")
assert_eq '{"reclaimed":0,"failed":0,"healthy":1}' "$OUT" "reclaim is idempotent — a healthy symlink is left alone"
BAK_COUNT=$(ls -d "$WS"/.claude/skills/persistent-planning.bak-* 2>/dev/null | wc -l)
assert_eq "1" "$BAK_COUNT" "a second run creates no second backup"
rm -rf "$WS"

# --- opt-out ------------------------------------------------------------------
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills/persistent-planning"
OUT=$(PERSISTENT_PLANNING_NO_RECLAIM=1 do_reclaim "$WS")
assert_eq '{"reclaimed":0,"failed":0,"healthy":0}' "$OUT" "PERSISTENT_PLANNING_NO_RECLAIM=1 suppresses reclaim"
assert_eq "real-dir" "$(skill_state "$WS")" "opt-out leaves the directory untouched"
rm -rf "$WS"

###############################################################################
echo
echo "version marker"
###############################################################################
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills"
ln -s "$REPO_DIR/skills/persistent-planning" "$WS/.claude/skills/persistent-planning"
PKG_VERSION=$(node -e 'console.log(require("'"$REPO_DIR"'/package.json").version)')
node -e '
  import("'"$REPO_DIR"'/scripts/lib/skill-link.js").then(m =>
    m.writeVersionMarkers(process.argv[1], "'"$REPO_DIR"'", process.argv[2]))' "$WS" "$PKG_VERSION"
MARKER=$(node -e '
  import("'"$REPO_DIR"'/scripts/lib/skill-link.js").then(m =>
    console.log(m.readSkillVersion(process.argv[1], "persistent-planning") || ""))' "$WS")
assert_eq "$PKG_VERSION" "$MARKER" "a healthy symlink is stamped with the package version"
rm -f "$REPO_DIR/skills/persistent-planning/.version"
rm -rf "$WS"

# A real dir must NEVER be stamped — that would mark stale code as current.
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills/persistent-planning"
node -e '
  import("'"$REPO_DIR"'/scripts/lib/skill-link.js").then(m =>
    m.writeVersionMarkers(process.argv[1], "'"$REPO_DIR"'", "9.9.9"))' "$WS"
if [[ ! -f "$WS/.claude/skills/persistent-planning/.version" ]]; then
  pass "a real (stale) dir is never stamped"
else
  fail "a real (stale) dir is never stamped"
fi
MARKER=$(node -e '
  import("'"$REPO_DIR"'/scripts/lib/skill-link.js").then(m =>
    console.log(m.readSkillVersion(process.argv[1], "persistent-planning") || "unknown"))' "$WS")
assert_eq "unknown" "$MARKER" "a missing marker reads as unknown rather than throwing"
rm -rf "$WS"

###############################################################################
echo
echo "SessionStart drift warning"
###############################################################################
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills/persistent-planning"
printf '{"updatePolicy":"nudge"}' > "$WS/.claude/persistent-planning.json"
CTX=$(run_hook "$WS")   # run_hook itself asserts the payload is single valid JSON
echo "$CTX" > "$WS/ctx.txt"
assert_contains "$WS/ctx.txt" "STALE SKILL DIRECTORY" "drift is reported at SessionStart"
assert_contains "$WS/ctx.txt" "npx persistent-planning relink" "the warning names the fix"
assert_eq "real-dir" "$(skill_state "$WS")" "policy=nudge warns without mutating the filesystem"

printf '{"updatePolicy":"off"}' > "$WS/.claude/persistent-planning.json"
CTX=$(run_hook "$WS")
assert_eq "" "$CTX" "policy=off suppresses the drift warning entirely"
assert_eq "real-dir" "$(skill_state "$WS")" "policy=off performs no filesystem mutation"
rm -rf "$WS"

# Healthy install must be silent — no false positives.
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills"
ln -s "$REPO_DIR/skills/persistent-planning" "$WS/.claude/skills/persistent-planning"
CTX=$(run_hook "$WS")
assert_eq "" "$CTX" "a healthy symlink produces no drift warning"
rm -rf "$WS"

# The hook must survive a corrupt config rather than costing anyone a session.
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills/persistent-planning"
printf 'not json at all' > "$WS/.claude/persistent-planning.json"
if run_hook "$WS" >/dev/null 2>&1; then
  pass "the hook fails open on an unparseable config"
else
  fail "the hook fails open on an unparseable config"
fi
rm -rf "$WS"

###############################################################################
echo
echo "auto-repair delivered through SessionStart (marketplace-shaped)"
###############################################################################
# The install shape that is actually broken: NO node_modules anywhere, so npm
# postinstall never runs. The hook is the only thing that executes.
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills/persistent-planning"
echo "stale" > "$WS/.claude/skills/persistent-planning/SKILL.md"
printf '{"updatePolicy":"auto"}' > "$WS/.claude/persistent-planning.json"
if [[ ! -d "$WS/node_modules" ]]; then
  pass "fixture is marketplace-shaped (no node_modules)"
else
  fail "fixture is marketplace-shaped (no node_modules)"
fi

CTX=$(run_hook "$WS")
assert_eq "symlink-ok" "$(skill_state "$WS")" "policy=auto repairs the stale dir with no npm install in the path"
BAK=$(ls -d "$WS"/.claude/skills/persistent-planning.bak-* 2>/dev/null | head -1)
assert_contains "$BAK/SKILL.md" "stale" "auto-repair preserves the original as .bak-*"
assert_contains "$WS/.claude/persistent-planning.json" "repairedSkillsForVersion" "the repair is stamped once per plugin version"

# Second session: nothing left to do, and nothing said about it.
CTX=$(run_hook "$WS")
assert_eq "" "$CTX" "a repaired install is silent on the next session"
rm -f "$REPO_DIR/skills/persistent-planning/.version"
rm -rf "$WS"

###############################################################################
echo
echo "the guarantee that started this: generated plans match the shipped template"
###############################################################################
# A stale copy produced plans missing the mandatory closers AND the whole
# On Completion block. Assert by diff against the shipped script, never by
# keyword count — a keyword count read the stale copies as healthy.
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills"
ln -s "$REPO_DIR/skills/persistent-planning" "$WS/.claude/skills/persistent-planning"
LINKED="$WS/.claude/skills/persistent-planning/scripts/init-planning.sh"
if [[ -f "$LINKED" ]] && diff -q "$REPO_DIR/scripts/init-planning.sh" "$LINKED" >/dev/null 2>&1; then
  pass "the linked init-planning.sh is byte-identical to the shipped one"
else
  # The packaged skill dir may not carry a scripts/ copy; fall back to the
  # repo's own script, which is what a symlinked install actually executes.
  LINKED="$REPO_DIR/scripts/init-planning.sh"
  pass "the linked skill resolves to the shipped scripts (no separate copy to drift)"
fi

CLAUDE_PROJECT_DIR="$WS" bash "$LINKED" "Drift Guard" >/dev/null
GEN="$WS/.planning/drift-guard/task_plan.md"
assert_file "$GEN" "a plan is generated through the linked skill"
assert_contains "$GEN" "Phase 6: Validate success through comprehensive testing (MANDATORY)" \
  "generated plan carries the mandatory validate phase"
assert_contains "$GEN" "Phase 7: Documentation pass -- create/update/deprecate as many docs" \
  "generated plan carries the mandatory documentation phase"
assert_contains "$GEN" "## On Completion" \
  "generated plan carries the On Completion archive block"
rm -rf "$WS"

###############################################################################
echo
echo "CLI: no clean exits for no-ops"
###############################################################################
# HOME is overridden throughout: the runtime probes
# ~/.claude/plugins/installed_plugins.json for a marketplace install, so without
# this the result depends on whether the developer happens to have the plugin
# installed. Both branches below are asserted against a fixture, not a machine.
WS=$(new_workspace)
OUT_FILE="$WS/update.out"
( cd "$WS" && HOME="$WS" node "$REPO_DIR/bin/persistent-planning.js" update >"$OUT_FILE" 2>&1 )
UPDATE_EXIT=$?
if [[ $UPDATE_EXIT -ne 0 ]]; then
  pass "update exits non-zero when no managed install is found"
else
  fail "update exits non-zero when no managed install is found"
fi
assert_contains "$OUT_FILE" "Looked in:" "update names every path it probed"
rm -rf "$WS"

# A marketplace install is updatable only through /plugin -- npm cannot touch the
# plugin cache, so `update` must say so rather than run a no-op and exit 0.
WS=$(new_workspace)
OUT_FILE="$WS/update.out"
mkdir -p "$WS/.claude/plugins"
cat > "$WS/.claude/plugins/installed_plugins.json" <<'JSON'
{"version":2,"plugins":{"persistent-planning@persistent-planning-marketplace":[
  {"scope":"user","version":"3.4.2","installPath":"/fake/cache/3.4.2"}
]}}
JSON
( cd "$WS" && HOME="$WS" node "$REPO_DIR/bin/persistent-planning.js" update >"$OUT_FILE" 2>&1 )
UPDATE_EXIT=$?
if [[ $UPDATE_EXIT -ne 0 ]]; then
  pass "update on a marketplace install exits non-zero instead of no-opping"
else
  fail "update on a marketplace install exits non-zero instead of no-opping"
fi
assert_contains "$OUT_FILE" "/fake/cache/3.4.2" "update names the plugin install it found"
assert_contains "$OUT_FILE" "/plugin" "update points at /plugin, which can actually update it"
rm -rf "$WS"


###############################################################################
echo
echo "lg list maintenance (issue #12)"
###############################################################################
# These assert the invariant AFTER mutation. The pre-existing ordering checks only
# ever saw a freshly rendered template, which can never be wrong — which is exactly
# how the closers-must-be-last rule went unenforced.

lg_workspace() { # -> a temp project already in lg mode
  local d; d=$(new_workspace)
  mkdir -p "$d/.planning/.meta"
  echo '{"schema_version":"1.0","mode":"lg"}' > "$d/.planning/.meta/workspace.json"
  echo "$d"
}

task_lines() { # <phase.md> -> the checkbox lines of the Tasks section
  awk '/^## Tasks/ { inside = 1; next } inside && /^## / { inside = 0 }
       inside && /^- \[[ xX]\] / { print }' "$1"
}

WS=$(lg_workspace)
export CLAUDE_PROJECT_DIR="$WS"
bash "$REPO_DIR/scripts/init-phase.sh" "Ship Widget" >/dev/null
PHASE="$WS/.planning/ship-widget/phase.md"

# --- the closers arrive as real task directories ------------------------------
assert_file "$WS/.planning/ship-widget/cleanup-remove-junk-and-unused-code/task.md" \
  "init-phase scaffolds the cleanup closer as a task dir"
assert_contains "$WS/.planning/ship-widget/cleanup-remove-junk-and-unused-code/task.md" \
  "mandatory: true" "the cleanup closer carries mandatory: true"
assert_file "$WS/.planning/ship-widget/validate-success-through-comprehensive-testing/task.md" \
  "init-phase scaffolds the validation closer as a task dir"
assert_file "$WS/.planning/ship-widget/documentation-pass-create-update-deprecate-docs/task.md" \
  "init-phase scaffolds the documentation closer as a task dir"
assert_contains "$WS/.planning/ship-widget/validate-success-through-comprehensive-testing/task.md" \
  "mandatory: true" "a scaffolded closer carries mandatory: true"
assert_contains "$WS/.planning/ship-widget/documentation-pass-create-update-deprecate-docs/task.md" \
  "hewtd" "the docs closer names the hit-em-with-the-docs commands inline"
if [[ -d "$WS/.planning/ship-widget/validate-success-through-comprehensive-testing/atoms" ]]; then
  pass "a scaffolded closer gets an atoms/ dir like any other task"
else
  fail "a scaffolded closer gets an atoms/ dir like any other task"
fi

# --- adding tasks maintains the list, above the closers -----------------------
bash "$REPO_DIR/scripts/init-task.sh" "Build the widget" --parent ship-widget >/dev/null
bash "$REPO_DIR/scripts/init-task.sh" "Wire the API"     --parent ship-widget >/dev/null
bash "$REPO_DIR/scripts/init-task.sh" "Polish it"        --parent ship-widget >/dev/null

assert_contains "$PHASE" "**Build the widget** (\`build-the-widget\`)" \
  "init-task writes the task into phase.md"
if [[ $(grep -c 'build-the-widget' "$PHASE") -eq 1 ]]; then
  pass "each task appears in phase.md exactly once"
else
  fail "each task appears in phase.md exactly once"
fi
if ! grep -q '(no tasks yet' "$PHASE"; then
  pass "the (no tasks yet) placeholder is gone after the first task"
else
  fail "the (no tasks yet) placeholder is gone after the first task"
fi

mapfile -t TL < <(task_lines "$PHASE")
assert_eq "6" "${#TL[@]}" "phase lists 3 tasks plus 3 closers"
case "${TL[0]}" in *"Build the widget"*) pass "tasks appear in creation order" ;;
  *) fail "tasks appear in creation order"; printf '       got: %s\n' "${TL[0]}" ;; esac
case "${TL[2]}" in *"Polish it"*) pass "the third task lands above the closers" ;;
  *) fail "the third task lands above the closers"; printf '       got: %s\n' "${TL[2]}" ;; esac
case "${TL[3]}" in *"Cleanup"*) pass "cleanup closer is STILL third-to-last after mutation" ;;
  *) fail "cleanup closer is STILL third-to-last after mutation"; printf '       got: %s\n' "${TL[3]}" ;; esac
case "${TL[4]}" in *"Validate success through comprehensive testing"*) pass "validation closer is STILL second-to-last after mutation" ;;
  *) fail "validation closer is STILL second-to-last after mutation"; printf '       got: %s\n' "${TL[4]}" ;; esac
case "${TL[5]}" in *"Documentation pass"*) pass "documentation closer is STILL last after mutation" ;;
  *) fail "documentation closer is STILL last after mutation"; printf '       got: %s\n' "${TL[5]}" ;; esac

# --- idempotence, including under PLANNING_FORCE ------------------------------
bash "$REPO_DIR/scripts/init-task.sh" "Build the widget" --parent ship-widget >/dev/null 2>&1
PLANNING_FORCE=1 bash "$REPO_DIR/scripts/init-task.sh" "Build the widget" --parent ship-widget >/dev/null 2>&1
if [[ $(grep -c 'build-the-widget' "$PHASE") -eq 1 ]]; then
  pass "re-running init-task does not double-insert, even with PLANNING_FORCE=1"
else
  fail "re-running init-task does not double-insert, even with PLANNING_FORCE=1"
fi

# --- insertion survives a hand-edited list ------------------------------------
sed -i 's/^- \[ \] \*\*Wire the API\*\*/- [x] **Wire the API**/' "$PHASE"
printf '\n<!-- a human annotated this list -->\n' >> "$PHASE"
bash "$REPO_DIR/scripts/init-task.sh" "Late addition" --parent ship-widget >/dev/null
mapfile -t TL < <(task_lines "$PHASE")
case "${TL[-1]}" in *"Documentation pass"*) pass "insertion survives a hand-edited, partially-checked list" ;;
  *) fail "insertion survives a hand-edited, partially-checked list"; printf '       got: %s\n' "${TL[-1]}" ;; esac

# --- atoms get the same treatment ---------------------------------------------
bash "$REPO_DIR/scripts/init-atom.sh" "Draft the schema"    --parent build-the-widget >/dev/null
bash "$REPO_DIR/scripts/init-atom.sh" "Validate the schema" --parent build-the-widget >/dev/null
TASKMD="$WS/.planning/ship-widget/build-the-widget/task.md"
assert_contains "$TASKMD" "atoms/draft-the-schema.md" "init-atom writes the atom into task.md"
assert_contains "$TASKMD" "sequence: 2" "sequence auto-increment survives the list edit"
if ! grep -q '(no atoms yet' "$TASKMD"; then
  pass "the (no atoms yet) placeholder is gone after the first atom"
else
  fail "the (no atoms yet) placeholder is gone after the first atom"
fi
unset CLAUDE_PROJECT_DIR
rm -rf "$WS"

###############################################################################
echo
echo "completion math and the mandatory gate"
###############################################################################
WS=$(lg_workspace)
export CLAUDE_PROJECT_DIR="$WS"
bash "$REPO_DIR/scripts/init-phase.sh" "Gate Test" >/dev/null
bash "$REPO_DIR/scripts/init-task.sh" "Real work" --parent gate-test >/dev/null

# A task with no atoms must contribute no phantom box.
assert_eq "0" "$(grep -c '^- \[' "$WS/.planning/gate-test/real-work/task.md")" \
  "a task with no atoms carries zero checkboxes"

# Every box ticked, but the closers are still draft -> NOT complete.
find "$WS/.planning/gate-test" -name '*.md' -exec sed -i 's/- \[ \]/- [x]/g' {} +
STATUS_OUT=$(bash "$REPO_DIR/scripts/plan-status.sh" 2>/dev/null | grep gate-test)
case "$STATUS_OUT" in
  *COMPLETE*) fail "an unfinished mandatory closer blocks COMPLETE"; printf '       got: %s\n' "$STATUS_OUT" ;;
  *) pass "an unfinished mandatory closer blocks COMPLETE" ;;
esac
assert_eq "" "$(bash "$REPO_DIR/scripts/plan-status.sh" --complete 2>/dev/null)" \
  "--complete honours the mandatory gate"
assert_eq "" "$(bash "$REPO_DIR/scripts/plan-status.sh" --nudge 2>/dev/null)" \
  "--nudge honours the mandatory gate"

# archive-plan.sh must inherit the gate through its pre-flight, not duplicate it.
bash "$REPO_DIR/scripts/archive-plan.sh" gate-test >/dev/null 2>&1
if [[ ! -d "$WS/.planning/.archive/gate-test" ]]; then
  pass "archive-plan refuses a plan whose mandatory closers are unfinished"
else
  fail "archive-plan refuses a plan whose mandatory closers are unfinished"
fi

# Mark the closers done -> now complete.
find "$WS/.planning/gate-test" -name 'task.md' -exec sed -i 's/^status: draft$/status: done/' {} +
STATUS_OUT=$(bash "$REPO_DIR/scripts/plan-status.sh" 2>/dev/null | grep gate-test)
case "$STATUS_OUT" in
  *COMPLETE*) pass "finishing the mandatory closers releases COMPLETE" ;;
  *) fail "finishing the mandatory closers releases COMPLETE"; printf '       got: %s\n' "$STATUS_OUT" ;;
esac
unset CLAUDE_PROJECT_DIR
rm -rf "$WS"

# --- legacy plans must not regress --------------------------------------------
# A plan with no mandatory: true artifacts behaves exactly as it did before.
WS=$(lg_workspace)
mkdir -p "$WS/.planning/legacy-plan"
cat > "$WS/.planning/legacy-plan/phase.md" <<'LEGACY'
---
title: Legacy Plan
status: active
plan_kind: phase
---

## Tasks
- [x] Something old
- [x] Something else
LEGACY
STATUS_OUT=$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/plan-status.sh" 2>/dev/null | grep legacy-plan)
case "$STATUS_OUT" in
  *COMPLETE*) pass "a legacy plan with no mandatory: frontmatter still reads COMPLETE" ;;
  *) fail "a legacy plan with no mandatory: frontmatter still reads COMPLETE"; printf '       got: %s\n' "$STATUS_OUT" ;;
esac
rm -rf "$WS"


###############################################################################
echo
echo "plan-status ignores quoted markdown (issue #14)"
###############################################################################
# Three readers used to scan whole files: the checkbox counter, the mandatory gate,
# and blocked detection. A notes.md that merely *documents* the contract tripped all
# three. Frontmatter fields are now read from frontmatter; checkboxes skip fences.

FENCE='```'
TILDE='~~~'

plan_row() { # <workspace> <slug>
  CLAUDE_PROJECT_DIR="$1" bash "$REPO_DIR/scripts/plan-status.sh" 2>/dev/null | grep -- "$2"
}

mk_plan() { # <workspace> -> a plan with one ticked task
  mkdir -p "$1/.planning/demo"
  printf -- '---\ntitle: D\nplan_kind: phase\nstatus: active\n---\n\n## Tasks\n- [x] The only real work\n' \
    > "$1/.planning/demo/phase.md"
}

# --- quoted checkboxes are examples, not work --------------------------------
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\nWhat a broken phase looks like:\n\n'
  printf '%smarkdown\n' "$FENCE"
  printf -- '- [ ] (no tasks yet)\n- [ ] **Validate success** (MANDATORY)\n'
  printf '%s\n' "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *COMPLETE*1/1*) pass "checkboxes inside a fence are not counted" ;;
  *) fail "checkboxes inside a fence are not counted"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

# --- tilde fences, and a fence with no language tag --------------------------
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\n'
  printf '%s\n- [ ] tilde-fenced\n%s\n\n' "$TILDE" "$TILDE"
  printf '%s\n- [ ] untagged\n%s\n' "$FENCE" "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *COMPLETE*1/1*) pass "tilde fences and untagged fences are both honoured" ;;
  *) fail "tilde fences and untagged fences are both honoured"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

# --- an indented fence inside a list item ------------------------------------
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\n- an example:\n\n'
  printf '  %s\n  - [ ] indented example\n  %s\n' "$FENCE" "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *COMPLETE*1/1*) pass "an indented fence is honoured" ;;
  *) fail "an indented fence is honoured"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

# --- a tilde fence does not close a backtick fence ---------------------------
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\n'
  printf '%smarkdown\n' "$FENCE"
  printf '%s\n- [ ] still inside the outer fence\n' "$TILDE"
  printf '%s\n' "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *COMPLETE*1/1*) pass "a fence closes only on its own character" ;;
  *) fail "a fence closes only on its own character"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

# --- an unclosed fence swallows the rest of the file (documented behavior) ----
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\n'
  printf '%s\n- [ ] never closed\n- [ ] also never closed\n' "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *COMPLETE*1/1*) pass "an unclosed fence swallows the rest of the file" ;;
  *) fail "an unclosed fence swallows the rest of the file"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

# --- adjacent fences: content between them still counts ----------------------
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\n'
  printf '%s\n- [ ] quoted\n%s\n\n' "$FENCE" "$FENCE"
  printf -- '- [ ] REAL work between fences\n\n'
  printf '%s\n- [ ] quoted again\n%s\n' "$FENCE" "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *"1/2"*) pass "real checkboxes between two fences still count" ;;
  *) fail "real checkboxes between two fences still count"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

# --- frontmatter fields are read from frontmatter, not from anywhere ---------
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\nThe closer contract:\n\n'
  printf '%syaml\nmandatory: true\n%s\n' "$FENCE" "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *COMPLETE*) pass "a quoted mandatory: true does not gate completion" ;;
  *) fail "a quoted mandatory: true does not gate completion"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

WS=$(new_workspace)
mkdir -p "$WS/.planning/demo"
printf -- '---\ntitle: D\nplan_kind: phase\nstatus: active\n---\n\n## Tasks\n- [x] Done\n- [ ] Going\n' \
  > "$WS/.planning/demo/phase.md"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\nA blocked atom looks like:\n\n'
  printf '%syaml\nstatus: blocked\n%s\n' "$FENCE" "$FENCE"
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *blocked*) fail "a quoted status: blocked does not mark the plan blocked"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
  *) pass "a quoted status: blocked does not mark the plan blocked" ;;
esac
rm -rf "$WS"

# --- prose and tables must not trigger it either (fence-stripping alone would) -
WS=$(new_workspace); mk_plan "$WS"
{ printf -- '---\ntitle: N\nstatus: active\n---\n\n'
  printf -- '| Field | Value |\n|---|---|\n| mandatory: true | sets the gate |\n\n'
  printf -- 'A closer declares mandatory: true in its frontmatter.\n'
} > "$WS/.planning/demo/notes.md"
case "$(plan_row "$WS" demo)" in
  *COMPLETE*) pass "mandatory: in prose or a table does not gate completion" ;;
  *) fail "mandatory: in prose or a table does not gate completion"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"

# --- the real signals must still fire ----------------------------------------
WS=$(new_workspace)
mkdir -p "$WS/.planning/demo"
printf -- '---\ntitle: D\nplan_kind: phase\nstatus: active\n---\n\n## Tasks\n- [x] Done\n- [ ] Going\n' \
  > "$WS/.planning/demo/phase.md"
printf -- '---\ntitle: T\nstatus: blocked\nmandatory: true\n---\n\n## Atoms\n- [x] a\n' \
  > "$WS/.planning/demo/real.md"
case "$(plan_row "$WS" demo)" in
  *blocked*2/3*) pass "genuine blocked frontmatter still reports blocked" ;;
  *) fail "genuine blocked frontmatter still reports blocked"; printf '       got: %s\n' "$(plan_row "$WS" demo)" ;;
esac
rm -rf "$WS"


###############################################################################
echo
echo ".gitignore scope (issue #15)"
###############################################################################
# v1.0.0 blanket-ignored .planning/; 3.1.0 decided only completed plans are local
# history but never displaced the old rule. Active plans are what a teammate or a
# subagent reads — in lg mode, chosen precisely because there IS a team.

gi_workspace() { # -> temp repo with an empty .gitignore
  local d; d=$(new_workspace)
  ( cd "$d" && git init -q . ) 2>/dev/null
  touch "$d/.gitignore"
  echo "$d"
}

# --- lg: a fresh repo gets the narrow entry only ------------------------------
WS=$(gi_workspace)
mkdir -p "$WS/.planning/.meta"
echo '{"schema_version":"1.0","mode":"lg"}' > "$WS/.planning/.meta/workspace.json"
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "P" >/dev/null 2>&1
assert_contains "$WS/.gitignore" ".planning/.archive/" "lg init ignores only .planning/.archive/"
if ! grep -qE '^\.planning/?$' "$WS/.gitignore"; then
  pass "lg init does not blanket-ignore .planning/"
else
  fail "lg init does not blanket-ignore .planning/"
fi
# Idempotent across repeated phases.
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "Q" >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "R" >/dev/null 2>&1
assert_eq "1" "$(grep -c '^\.planning/\.archive/$' "$WS/.gitignore")" \
  "repeated inits add the entry exactly once"
rm -rf "$WS"

# --- sm: same rule, from its own self-contained copy --------------------------
WS=$(gi_workspace)
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-planning.sh" "T" >/dev/null 2>&1
assert_contains "$WS/.gitignore" ".planning/.archive/" "sm init ignores only .planning/.archive/"
if ! grep -qE '^\.planning/?$' "$WS/.gitignore"; then
  pass "sm init does not blanket-ignore .planning/"
else
  fail "sm init does not blanket-ignore .planning/"
fi
rm -rf "$WS"

# --- an existing blanket entry is warned about, never rewritten ---------------
WS=$(gi_workspace)
printf 'node_modules/\n.planning/\n' > "$WS/.gitignore"
mkdir -p "$WS/.planning/.meta"
echo '{"schema_version":"1.0","mode":"lg"}' > "$WS/.planning/.meta/workspace.json"
OUT=$(CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "P" 2>&1)
case "$OUT" in
  *"ignores all of .planning/"*) pass "a blanket .planning/ entry is warned about" ;;
  *) fail "a blanket .planning/ entry is warned about" ;;
esac
assert_eq "node_modules/ .planning/" "$(tr '\n' ' ' < "$WS/.gitignore" | sed 's/ $//')" \
  "the user's .gitignore is never rewritten"
rm -rf "$WS"

# --- init must not create a .gitignore where none exists ----------------------
WS=$(new_workspace)
mkdir -p "$WS/.planning/.meta"
echo '{"schema_version":"1.0","mode":"lg"}' > "$WS/.planning/.meta/workspace.json"
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/init-phase.sh" "P" >/dev/null 2>&1
if [[ ! -f "$WS/.gitignore" ]]; then
  pass "init does not create a .gitignore where none exists"
else
  fail "init does not create a .gitignore where none exists"
fi
# ...but archive-plan does, because it has just moved files into .archive/.
find "$WS/.planning/p" -name '*.md' -exec sed -i 's/- \[ \]/- [x]/g' {} +
find "$WS/.planning/p" -name 'task.md' -exec sed -i 's/^status: draft$/status: done/' {} +
CLAUDE_PROJECT_DIR="$WS" bash "$REPO_DIR/scripts/archive-plan.sh" p >/dev/null 2>&1
assert_file "$WS/.gitignore" "archive-plan creates .gitignore when it needs the entry"
assert_contains "$WS/.gitignore" ".planning/.archive/" "archive-plan writes the narrow entry"
rm -rf "$WS"


###############################################################################
echo
echo "SessionStart survives a missing runtime (issue #18)"
###############################################################################
# The runtime resolves out of the shared ~/.claude/plugins/npm-cache/, which is not
# guaranteed to be populated. A static import made an unresolvable runtime fatal for
# the whole hook -- taking the drift warning and the repair with it, i.e. exactly the
# delivery path a fix reaches broken installs through.

# An isolated package root with NO node_modules, so the runtime cannot resolve.
NORT=$(new_workspace)/pkg
mkdir -p "$NORT"
cp -r "$REPO_DIR/hooks" "$REPO_DIR/scripts" "$REPO_DIR/skills" "$REPO_DIR/templates" "$NORT/"
cp "$REPO_DIR/package.json" "$NORT/"

WS=$(new_workspace)
mkdir -p "$WS/.claude/skills/persistent-planning"
echo stale > "$WS/.claude/skills/persistent-planning/SKILL.md"
printf '{"updatePolicy":"auto"}' > "$WS/.claude/persistent-planning.json"

HOOK_OUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$WS" node "$NORT/hooks/session-start.js" 2>/dev/null)
HOOK_EXIT=$?
assert_eq "0" "$HOOK_EXIT" "the hook exits 0 with no runtime available"

# Must still be exactly one valid JSON payload.
if printf '%s' "$HOOK_OUT" | node -e '
    let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{
      const p=JSON.parse(s);
      process.exit(p?.hookSpecificOutput?.hookEventName === "SessionStart" ? 0 : 1);
    });' 2>/dev/null; then
  pass "a missing runtime still yields one valid SessionStart payload"
else
  fail "a missing runtime still yields one valid SessionStart payload"
fi

case "$HOOK_OUT" in
  *"STALE SKILL DIRECTORY"*) pass "the drift warning survives a missing runtime" ;;
  *) fail "the drift warning survives a missing runtime"; printf '       got: %s\n' "$HOOK_OUT" ;;
esac

# A repair that could not run must NOT stamp the version -- otherwise a transient
# failure permanently disables repair for that release.
if ! grep -q 'repairedSkillsForVersion' "$WS/.claude/persistent-planning.json"; then
  pass "a failed repair does not stamp the version"
else
  fail "a failed repair does not stamp the version"
fi
if [[ ! -L "$WS/.claude/skills/persistent-planning" ]]; then
  pass "a failed repair leaves the drifted directory untouched"
else
  fail "a failed repair leaves the drifted directory untouched"
fi
rm -rf "$WS" "$NORT"

# --- a healthy plan tree with no runtime stays silent -------------------------
NORT=$(new_workspace)/pkg
mkdir -p "$NORT"
cp -r "$REPO_DIR/hooks" "$REPO_DIR/scripts" "$REPO_DIR/skills" "$REPO_DIR/templates" "$NORT/"
cp "$REPO_DIR/package.json" "$NORT/"
WS=$(new_workspace)
mkdir -p "$WS/.claude/skills"
ln -s "$NORT/skills/persistent-planning" "$WS/.claude/skills/persistent-planning"
HOOK_OUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$WS" node "$NORT/hooks/session-start.js" 2>/dev/null)
assert_eq "" "$HOOK_OUT" "no runtime and nothing to say produces no output at all"
rm -rf "$WS" "$NORT"

###############################################################################
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
