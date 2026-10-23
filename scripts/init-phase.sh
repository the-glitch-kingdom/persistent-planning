#!/bin/bash
###############################################################################
# init-phase.sh - Create a new phase in lg-mode persistent-planning
#
# Usage:
#   bash scripts/init-phase.sh "Phase Name"
#
# Creates:
#   .planning/<phase-slug>/phase.md         (HEWTD-frontmattered phase template)
#   .planning/<phase-slug>/notes.md         (cross-cutting notes for the phase)
#   .planning/.meta/workspace.json          (mode = lg, on first phase init)
#
# Refuses to run unless mode is lg. Run init-planning.sh for sm-mode tasks.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/planning.sh"

case "${1:-}" in
  -h|--help)
    cat <<EOF
Usage: bash scripts/init-phase.sh "Phase Name"

Creates:
  .planning/<phase-slug>/phase.md
  .planning/<phase-slug>/notes.md
  .planning/.meta/workspace.json (on first phase init, with mode=lg)

Refuses to run unless mode is lg. Run init-planning.sh for sm-mode tasks.

Examples:
  bash scripts/init-phase.sh "Foundation"
  bash scripts/init-phase.sh "Multi-corpus refactor"
EOF
    exit 0
    ;;
  "")
    planning_err "Phase name required."
    echo ""
    echo "Usage: bash scripts/init-phase.sh \"Phase Name\""
    echo "       bash scripts/init-phase.sh --help"
    exit 1
    ;;
esac

PHASE_NAME="$1"
PHASE_SLUG=$(planning_slugify "$PHASE_NAME")

if [[ -z "$PHASE_SLUG" ]]; then
  planning_err "Phase name must contain at least one alphanumeric character."
  exit 1
fi

# Refuse to run in sm mode
MODE=$(planning_mode)
if [[ "$MODE" != "lg" ]]; then
  planning_err "Current mode is '$MODE' but init-phase.sh requires lg mode."
  echo ""
  echo "Switch to lg mode by running:"
  echo "  /start-planning --mode lg \"<phase name>\""
  echo "or by editing .planning/.meta/workspace.json directly."
  exit 1
fi

ROOT=$(planning_root)
PLANNING="$(planning_dir)"
META="$(planning_meta_dir)"
WORKSPACE_JSON="$(planning_workspace_json)"
TODAY=$(planning_today)
PHASE_DIR="${PLANNING}/${PHASE_SLUG}"
TEMPLATE_DIR="${ROOT}/templates/lg"

# Fallback: when run from the installed plugin location, templates live in the
# plugin's own directory, not the project root.
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  TEMPLATE_DIR="${SCRIPT_DIR}/../templates/lg"
fi
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  planning_err "Cannot locate templates/lg directory. Tried:"
  echo "  ${ROOT}/templates/lg"
  echo "  ${SCRIPT_DIR}/../templates/lg"
  exit 1
fi

planning_log "Initializing phase: ${PHASE_NAME}"

# Bootstrap .planning/.meta/workspace.json if missing
mkdir -p "$META"
if [[ ! -f "$WORKSPACE_JSON" ]]; then
  CONTRIB=0
  if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    CONTRIB=$(git -C "$ROOT" log --since="90 days ago" --format='%ae' 2>/dev/null | sort -u | wc -l | tr -d ' ')
  fi
  cat > "$WORKSPACE_JSON" <<EOF
{
  "schema_version": "1.0",
  "mode": "lg",
  "auto_detected": true,
  "detected_contributors": ${CONTRIB},
  "created_at": "$(date -Iseconds)"
}
EOF
  planning_ok "Created .planning/.meta/workspace.json (mode=lg, contributors=${CONTRIB})"
fi

# Create phase directory
mkdir -p "$PHASE_DIR"

# The docs closer's wording depends on whether this project uses hit-em-with-the-docs.
# Its slug never changes: the completion gate and existing plans key on it.
# Both variants open by asking the planner to name the docs — the generic atoms alone
# left the closer unfilled while the validation closer, which asks, got filled.
DOCS_PLAN_ATOM="As this phase's tasks are written, add an atom here for each doc they create, change or make stale, naming the file — check the existing docs for ones this work makes wrong"
if planning_uses_hewtd "$ROOT"; then
  DOCS_CLOSER="Documentation pass — a full hit-em-with-the-docs pass to create/update/deprecate as many docs as needed to capture all our changes: new procedures, tools, troubleshooting steps, gotchas, KB articles, etc. Never include secrets or passwords"
  DOCS_TITLE="Documentation pass — full hit-em-with-the-docs pass"
  DOCS_ATOMS=(
    "$DOCS_PLAN_ATOM"
    "Full hit-em-with-the-docs pass: create/update/deprecate as many docs as needed to capture all our changes"
    "Create docs with \`npx hewtd integrate <file> -a\`; retire superseded ones with \`npx hewtd archive <file>\` — never by deleting"
    "Capture every new procedure and tool: what it is, where it lives, how to run it"
    "Add a troubleshooting entry for the symptom someone will actually search for"
    "Record each gotcha (a non-obvious failure with an observed fix) as a knowledge-base fact tagged \`gotcha\`, with an \`## Instead\` section"
    "Write KB articles for anything operational under \`.documentation/knowledge-base/\`"
    "Update every existing doc this phase made wrong — a stale doc is worse than a missing one"
    "Never include secrets, passwords, tokens or keys in any doc"
    "Run \`npx hewtd maintain --quick\` and \`npx hewtd audit\`; resolve every error"
    "Never hand-edit INDEX.md or REGISTRY.md — they are generated"
  )
else
  DOCS_CLOSER="Documentation pass — create/update/deprecate as many docs as needed to capture what was done, where it lives, how to troubleshoot it, etc. etc.. etc.."
  DOCS_TITLE="Documentation pass — create/update/deprecate docs"
  DOCS_ATOMS=(
    "$DOCS_PLAN_ATOM"
    "Create docs for what was built: what it is, where it lives, how it works"
    "Capture new procedures, tools, troubleshooting steps and gotchas — add a troubleshooting entry for the symptom someone will actually search for"
    "Update every existing doc this phase made wrong — a stale doc is worse than a missing one"
    "Retire superseded docs rather than leaving them wrong"
    "Never include secrets, passwords, tokens or keys in any doc"
    "If hit-em-with-the-docs is installed you MUST use it: \`npx hewtd integrate <file> -a\` to create, \`npx hewtd archive <file>\` to retire, \`npx hewtd maintain --quick\` to regenerate indexes"
  )
fi

# Render phase.md
planning_render_and_log \
  "${TEMPLATE_DIR}/phase.md" \
  "${PHASE_DIR}/phase.md" \
  "phase.md at ${PHASE_DIR}/phase.md" \
  "PHASE_TITLE_PLACEHOLDER=${PHASE_NAME}" \
  "PHASE_SLUG_PLACEHOLDER=${PHASE_SLUG}" \
  "PHASE_DATE_PLACEHOLDER=${TODAY}" \
  "DOCS_CLOSER_PLACEHOLDER=${DOCS_CLOSER}"

# Render notes.md (scoped to the phase)
planning_render_and_log \
  "${TEMPLATE_DIR}/notes.md" \
  "${PHASE_DIR}/notes.md" \
  "notes.md at ${PHASE_DIR}/notes.md" \
  "NOTES_TITLE_PLACEHOLDER=${PHASE_NAME} — Notes" \
  "NOTES_SCOPE_PLACEHOLDER=${PHASE_SLUG}" \
  "NOTES_DATE_PLACEHOLDER=${TODAY}"

# Scaffold the three mandatory closing tasks as real task directories.
#
# They used to exist only as two checkbox lines in phase.md, so the most important
# tasks in every plan were the only ones with no artifact for a subagent to read and
# nowhere to record decisions — and every real plan hand-built them (issue #12).
scaffold_closer() { # <slug> <title> <atom>...
  local slug="$1" title="$2"; shift 2
  local dir="${PHASE_DIR}/${slug}"
  mkdir -p "${dir}/atoms"

  planning_render_and_log \
    "${TEMPLATE_DIR}/task.md" \
    "${dir}/task.md" \
    "closer task at ${dir}/task.md" \
    "TASK_TITLE_PLACEHOLDER=${title}" \
    "TASK_SLUG_PLACEHOLDER=${slug}" \
    "PHASE_SLUG_PLACEHOLDER=${PHASE_SLUG}" \
    "TASK_DATE_PLACEHOLDER=${TODAY}"

  planning_render_and_log \
    "${TEMPLATE_DIR}/notes.md" \
    "${dir}/notes.md" \
    "closer notes at ${dir}/notes.md" \
    "NOTES_TITLE_PLACEHOLDER=${title} — Notes" \
    "NOTES_SCOPE_PLACEHOLDER=${PHASE_SLUG}/${slug}" \
    "NOTES_DATE_PLACEHOLDER=${TODAY}"

  # mandatory: true is what plan-status.sh gates on. parallelizable stays false —
  # a closer gates on everything before it.
  [[ -f "${dir}/task.md" ]] && sed -i 's/^mandatory: false$/mandatory: true/' "${dir}/task.md"

  local atom
  for atom in "$@"; do
    planning_insert_list_item "${dir}/task.md" "## Atoms" "- [ ] ${atom}"
  done
}

# Cleanup comes first so validation proves every deletion safe.
scaffold_closer \
  "cleanup-remove-junk-and-unused-code" \
  "Cleanup — remove junk and unused code" \
  "Scope it: diff against where this phase started — only what this phase created or changed is in scope" \
  "Remove scratch/test scripts, debug files, temp output and backups this phase created" \
  "Remove probe logging, one-off test functions and commented-out code" \
  "Remove code, helpers, imports and dependencies left unused by abandoned approaches" \
  "Never refactor code this phase did not touch; when unsure, record it in notes.md instead of deleting"

scaffold_closer \
  "validate-success-through-comprehensive-testing" \
  "Validate success through comprehensive testing" \
  "We need to validate success thoroughly through comprehensive testing of our changes: as this phase's tasks are written, add an atom here for each check they need" \
  "Cover every kind that applies: unit tests for new and changed logic, integration and end-to-end runs through the real entry points, edge cases and failure paths" \
  "Prove every claim this phase makes with a test that fails if it breaks" \
  "Test the invariant after mutation, not the shape of a freshly rendered template" \
  "Cover the failure mode that prompted the work, not just the happy path" \
  "Run the full suite green before closing this task"

scaffold_closer \
  "documentation-pass-create-update-deprecate-docs" \
  "$DOCS_TITLE" \
  "${DOCS_ATOMS[@]}"

# Only completed plans are local history — see planning_ensure_archive_gitignored.
planning_ensure_archive_gitignored "${ROOT}"
planning_seed_rules "${ROOT}"

echo ""
planning_ok "Phase '${PHASE_NAME}' ready at .planning/${PHASE_SLUG}/"
echo ""
echo "Next steps:"
echo "  1. Edit .planning/${PHASE_SLUG}/phase.md to describe the phase goal"
echo "  2. Add tasks with: /start-task \"<task name>\" --parent ${PHASE_SLUG}"
echo "  3. Add cross-cutting context to .planning/${PHASE_SLUG}/notes.md"
