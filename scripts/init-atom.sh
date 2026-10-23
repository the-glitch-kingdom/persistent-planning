#!/bin/bash
###############################################################################
# init-atom.sh - Create a new atom (subagent hand-off unit) under a task in lg mode
#
# Usage:
#   bash scripts/init-atom.sh "Atom Name" --parent <task-slug>
#
# Creates:
#   .planning/<phase-slug>/<task-slug>/atoms/<atom-slug>.md
#
# The atom's sequence number is auto-assigned: 1 + (max existing sequence in
# the same task's atoms/ directory). Atoms within a task default to sequential
# processing.
#
# --parent must be a task-slug. The phase is auto-resolved by walking the
# .planning/ tree to find the task.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/planning.sh"

# Parse arguments
ATOM_NAME=""
PARENT_TASK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent)
      PARENT_TASK="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: bash scripts/init-atom.sh "Atom Name" --parent <task-slug>

Examples:
  bash scripts/init-atom.sh "Update zod schema" --parent hewtd-schema-extension
  bash scripts/init-atom.sh "Add plan-tier tests" --parent hewtd-schema-extension
EOF
      exit 0
      ;;
    *)
      if [[ -z "$ATOM_NAME" ]]; then
        ATOM_NAME="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$ATOM_NAME" || -z "$PARENT_TASK" ]]; then
  planning_err "Both atom name and --parent <task-slug> are required."
  echo "Usage: bash scripts/init-atom.sh \"Atom Name\" --parent <task-slug>"
  exit 1
fi

ATOM_SLUG=$(planning_slugify "$ATOM_NAME")

if [[ -z "$ATOM_SLUG" ]]; then
  planning_err "Atom name must contain at least one alphanumeric character."
  exit 1
fi

MODE=$(planning_mode)
if [[ "$MODE" != "lg" ]]; then
  planning_err "Current mode is '$MODE' but init-atom.sh requires lg mode."
  exit 1
fi

ROOT=$(planning_root)
PLANNING="$(planning_dir)"
TODAY=$(planning_today)
TEMPLATE_DIR="${ROOT}/templates/lg"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  TEMPLATE_DIR="${SCRIPT_DIR}/../templates/lg"
fi
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  planning_err "Cannot locate templates/lg directory."
  exit 1
fi

# Find the parent task — walk .planning/<phase>/<task>/task.md
TASK_DIR=""
for phase_path in "${PLANNING}"/*/; do
  candidate="${phase_path%/}/${PARENT_TASK}"
  if [[ -f "${candidate}/task.md" ]]; then
    TASK_DIR="$candidate"
    break
  fi
done

if [[ -z "$TASK_DIR" ]]; then
  planning_err "Parent task '${PARENT_TASK}' not found under .planning/<phase>/."
  echo ""
  echo "Available tasks:"
  for phase_path in "${PLANNING}"/*/; do
    phase_slug=$(basename "$phase_path")
    [[ "$phase_slug" == ".meta" || "$phase_slug" == "archive" ]] && continue
    for task_path in "${phase_path%/}"/*/; do
      task_slug=$(basename "$task_path")
      if [[ -f "${task_path}task.md" ]]; then
        echo "  --parent ${task_slug}     (in phase: ${phase_slug})"
      fi
    done
  done
  exit 1
fi

ATOMS_DIR="${TASK_DIR}/atoms"
mkdir -p "$ATOMS_DIR"

# Auto-assign sequence: 1 + max existing sequence in the atoms/ dir
NEXT_SEQUENCE=1
if compgen -G "${ATOMS_DIR}/*.md" >/dev/null 2>&1; then
  MAX_SEQ=$(grep -h '^sequence:' "${ATOMS_DIR}"/*.md 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)
  if [[ -n "$MAX_SEQ" ]]; then
    NEXT_SEQUENCE=$((MAX_SEQ + 1))
  fi
fi

planning_log "Initializing atom: ${ATOM_NAME} (parent: ${PARENT_TASK}, sequence: ${NEXT_SEQUENCE})"

planning_render_and_log \
  "${TEMPLATE_DIR}/atom.md" \
  "${ATOMS_DIR}/${ATOM_SLUG}.md" \
  "atom at ${ATOMS_DIR}/${ATOM_SLUG}.md (sequence: ${NEXT_SEQUENCE})" \
  "ATOM_TITLE_PLACEHOLDER=${ATOM_NAME}" \
  "TASK_SLUG_PLACEHOLDER=${PARENT_TASK}" \
  "ATOM_DATE_PLACEHOLDER=${TODAY}" \
  "ATOM_SEQUENCE_PLACEHOLDER=${NEXT_SEQUENCE}"

# Write the atom into its task's list. Same gap as init-task.sh had with
# phase.md: the atom file was created and never referenced anywhere (#12).
planning_insert_list_item \
  "${TASK_DIR}/task.md" \
  "## Atoms" \
  "- [ ] **${ATOM_NAME}** (\`atoms/${ATOM_SLUG}.md\`, sequence: ${NEXT_SEQUENCE})"

planning_seed_rules "${ROOT}"

echo ""
planning_ok "Atom '${ATOM_NAME}' ready"
echo ""
echo "Next steps:"
echo "  1. Edit ${ATOMS_DIR}/${ATOM_SLUG}.md to define what to do, inputs, outputs, and acceptance criteria"
echo "  2. A subagent will pick up this atom when status: ready"
echo "  3. Status transitions: ready → in_progress → done (or → blocked)"
