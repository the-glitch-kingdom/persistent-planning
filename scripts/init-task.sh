#!/bin/bash
###############################################################################
# init-task.sh - Create a new task under a phase in lg-mode persistent-planning
#
# Usage:
#   bash scripts/init-task.sh "Task Name" --parent <phase-slug>
#
# Creates:
#   .planning/<phase-slug>/<task-slug>/task.md
#   .planning/<phase-slug>/<task-slug>/notes.md
#   .planning/<phase-slug>/<task-slug>/atoms/   (empty dir for future atoms)
#
# Refuses if mode is not lg, or if --parent doesn't reference an existing phase.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/planning.sh"

# Parse arguments
TASK_NAME=""
PARENT_PHASE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent)
      PARENT_PHASE="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: bash scripts/init-task.sh "Task Name" --parent <phase-slug>

Examples:
  bash scripts/init-task.sh "HEWTD schema extension" --parent foundation
  bash scripts/init-task.sh "Multi-corpus refactor" --parent semantic-memory-core
EOF
      exit 0
      ;;
    *)
      if [[ -z "$TASK_NAME" ]]; then
        TASK_NAME="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$TASK_NAME" || -z "$PARENT_PHASE" ]]; then
  planning_err "Both task name and --parent <phase-slug> are required."
  echo "Usage: bash scripts/init-task.sh \"Task Name\" --parent <phase-slug>"
  exit 1
fi

TASK_SLUG=$(planning_slugify "$TASK_NAME")

if [[ -z "$TASK_SLUG" ]]; then
  planning_err "Task name must contain at least one alphanumeric character."
  exit 1
fi

# Refuse non-lg
MODE=$(planning_mode)
if [[ "$MODE" != "lg" ]]; then
  planning_err "Current mode is '$MODE' but init-task.sh requires lg mode."
  exit 1
fi

ROOT=$(planning_root)
PLANNING="$(planning_dir)"
TODAY=$(planning_today)
PHASE_DIR="${PLANNING}/${PARENT_PHASE}"
TASK_DIR="${PHASE_DIR}/${TASK_SLUG}"
TEMPLATE_DIR="${ROOT}/templates/lg"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  TEMPLATE_DIR="${SCRIPT_DIR}/../templates/lg"
fi
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  planning_err "Cannot locate templates/lg directory."
  exit 1
fi

# Validate parent phase exists
if [[ ! -f "${PHASE_DIR}/phase.md" ]]; then
  planning_err "Parent phase not found: .planning/${PARENT_PHASE}/phase.md"
  echo "Create the phase first with:"
  echo "  /start-planning \"<phase name>\"     (which runs init-phase.sh in lg mode)"
  exit 1
fi

planning_log "Initializing task: ${TASK_NAME} (parent: ${PARENT_PHASE})"

mkdir -p "${TASK_DIR}/atoms"

planning_render_and_log \
  "${TEMPLATE_DIR}/task.md" \
  "${TASK_DIR}/task.md" \
  "task.md at ${TASK_DIR}/task.md" \
  "TASK_TITLE_PLACEHOLDER=${TASK_NAME}" \
  "TASK_SLUG_PLACEHOLDER=${TASK_SLUG}" \
  "PHASE_SLUG_PLACEHOLDER=${PARENT_PHASE}" \
  "TASK_DATE_PLACEHOLDER=${TODAY}"

planning_render_and_log \
  "${TEMPLATE_DIR}/notes.md" \
  "${TASK_DIR}/notes.md" \
  "notes.md at ${TASK_DIR}/notes.md" \
  "NOTES_TITLE_PLACEHOLDER=${TASK_NAME} — Notes" \
  "NOTES_SCOPE_PLACEHOLDER=${PARENT_PHASE}/${TASK_SLUG}" \
  "NOTES_DATE_PLACEHOLDER=${TODAY}"

# Write the task into its phase's list, above the mandatory closers. Before this,
# init-task.sh never touched phase.md and every list was maintained by hand (#12).
planning_insert_list_item \
  "${PHASE_DIR}/phase.md" \
  "## Tasks" \
  "- [ ] **${TASK_NAME}** (\`${TASK_SLUG}\`)"

planning_seed_rules "${ROOT}"

echo ""
planning_ok "Task '${TASK_NAME}' ready at .planning/${PARENT_PHASE}/${TASK_SLUG}/"
echo ""
echo "Next steps:"
echo "  1. Edit .planning/${PARENT_PHASE}/${TASK_SLUG}/task.md to describe the goal"
echo "  2. Add atoms with: /start-atom \"<atom name>\" --parent ${TASK_SLUG}"
echo "     (or add inline atom checkboxes in task.md for simple atoms)"
