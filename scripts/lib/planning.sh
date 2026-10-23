#!/bin/bash
###############################################################################
# scripts/lib/planning.sh - Shared helpers for persistent-planning init scripts
#
# Source this file from init-phase.sh, init-task.sh, init-atom.sh, and any
# other planning-related script that needs slug, root, mode, or template
# rendering helpers.
#
# Usage:
#   #!/bin/bash
#   set -e
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/planning.sh"
#
# Provides:
#   - planning_slugify "Some Name"   →  "some-name" (echoed)
#   - planning_root                  →  prints project root (CLAUDE_PROJECT_DIR or pwd)
#   - planning_dir                   →  prints "<root>/.planning"
#   - planning_meta_dir              →  prints "<root>/.planning/.meta"
#   - planning_workspace_json        →  prints "<meta>/workspace.json"
#   - planning_mode                  →  prints active mode (sm | lg) via detect-mode.sh
#   - planning_today                 →  prints today's date as YYYY-MM-DD
#   - planning_render_template "<src>" "<dest>" "PLACEHOLDER1=value1" "PLACEHOLDER2=value2" ...
#       Renders a template file by sed-substituting PLACEHOLDER tokens.
#       Refuses to overwrite existing dest unless PLANNING_FORCE=1 in env.
#   - planning_seed_rules "<root>"   →  copies templates/rules/*.md into <root>/.claude/rules/
#       when absent; never overwrites. Appends templates/git-workflow-section.md once to
#       the repo's git workflow rule, or creates git-workflow.md
#   - planning_color_<name>          →  ANSI color codes (green, blue, yellow, cyan, red, reset)
#                                       (only set when stdout is a tty; empty otherwise)
#   - Color-coded log helpers: planning_log, planning_ok, planning_warn, planning_err
###############################################################################

# Color codes (only when stdout is a tty)
if [[ -t 1 ]]; then
  planning_color_green='\033[0;32m'
  planning_color_blue='\033[0;34m'
  planning_color_yellow='\033[1;33m'
  planning_color_cyan='\033[0;36m'
  planning_color_red='\033[0;31m'
  planning_color_reset='\033[0m'
else
  planning_color_green=''
  planning_color_blue=''
  planning_color_yellow=''
  planning_color_cyan=''
  planning_color_red=''
  planning_color_reset=''
fi

planning_log()  { printf "${planning_color_blue}[planning]${planning_color_reset} %s\n" "$*"; }
planning_ok()   { printf "${planning_color_green}[planning]${planning_color_reset} %s\n" "$*"; }
planning_warn() { printf "${planning_color_yellow}[planning]${planning_color_reset} %s\n" "$*"; }
planning_err()  { printf "${planning_color_red}[planning]${planning_color_reset} %s\n" "$*" >&2; }

planning_slugify() {
  local name="$1"
  name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  name=$(echo "$name" | sed 's/[[:space:]_]\+/-/g')
  name=$(echo "$name" | sed 's/[^a-z0-9-]//g')
  name=$(echo "$name" | sed 's/^-\+\|-\+$//g')
  name=$(echo "$name" | sed 's/-\+/-/g')
  echo "$name"
}

planning_root() {
  echo "${CLAUDE_PROJECT_DIR:-$(pwd)}"
}

planning_dir() {
  echo "$(planning_root)/.planning"
}

planning_meta_dir() {
  echo "$(planning_dir)/.meta"
}

planning_workspace_json() {
  echo "$(planning_meta_dir)/workspace.json"
}

planning_today() {
  date '+%Y-%m-%d'
}

planning_mode() {
  # Resolve via detect-mode.sh (in the same scripts/ dir as the caller's library).
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local detect="${lib_dir}/../detect-mode.sh"
  if [[ -x "$detect" ]]; then
    bash "$detect"
  else
    echo "sm"
  fi
}

# planning_render_template <template_src> <dest_path> <PLACEHOLDER1=value1> ...
# Renders a template file by sed-substituting placeholders.
#
# Return codes:
#   0  → rendered fresh
#   2  → skipped (dest already exists; pass PLANNING_FORCE=1 to overwrite)
#   1  → error (template not found, etc.)
#
# Callers can branch on the return code to log accurately.
planning_render_template() {
  local src="$1"
  local dest="$2"
  shift 2

  if [[ ! -f "$src" ]]; then
    planning_err "Template not found: $src"
    return 1
  fi

  if [[ -f "$dest" && "${PLANNING_FORCE:-0}" != "1" ]]; then
    planning_warn "Destination already exists, skipping: $dest"
    planning_warn "  (re-run with PLANNING_FORCE=1 to overwrite)"
    return 2
  fi

  # Copy template to dest
  cp "$src" "$dest"

  # Apply substitutions
  for kv in "$@"; do
    local key="${kv%%=*}"
    local value="${kv#*=}"
    # Use a safe delimiter (~) since values may contain /
    # Escape & and ~ in value
    local escaped_value
    escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\&~]/\\&/g')
    sed -i "s~${key}~${escaped_value}~g" "$dest"
  done
  return 0
}

# planning_render_and_log <template_src> <dest_path> <relative_label> <PLACEHOLDER=val> ...
# Wraps planning_render_template with accurate logging:
#   - Prints "Created <relative_label>" only when the template was actually rendered
#   - Prints nothing extra when skipped (the warn from render_template already covered it)
#   - Lets the script continue (set -e tolerant) regardless of skip vs render
planning_render_and_log() {
  local src="$1"
  local dest="$2"
  local label="$3"
  shift 3

  local rc=0
  planning_render_template "$src" "$dest" "$@" || rc=$?
  case $rc in
    0)
      planning_ok "Created ${label}"
      ;;
    2)
      # Already covered by the warn inside planning_render_template
      ;;
    *)
      planning_err "Failed to render ${label} (rc=$rc)"
      return $rc
      ;;
  esac
}

###############################################################################
# List maintenance
#
# A phase's task list and a task's atom list are stored markdown checkboxes,
# not derived views — plan-status.sh counts them, and humans edit them. So the
# init scripts have to write them. Before this existed, init-task.sh never
# touched phase.md at all and every list was maintained by hand (issue #12).
###############################################################################

# planning_insert_list_item <file> <section-heading> <line>
#
# Inserts <line> into the checkbox list under <section-heading> in <file>:
#   - above the first item marked MANDATORY, so closers stay last by
#     construction rather than by anyone remembering;
#   - after the last item when the section has no MANDATORY entries;
#   - dropping a "(no ... yet" placeholder, checkbox or italic, including its
#     continuation lines, the first time a real item lands.
#
# Idempotent: an identical line already in the section is left alone, so
# re-running with PLANNING_FORCE=1 cannot double-insert.
#
# Anchors on the MANDATORY marker, never on line numbers — the list is a
# human-editable surface and positions do not survive contact with editing.
planning_insert_list_item() {
  local file="$1" heading="$2" line="$3" tmp
  [[ -f "$file" ]] || return 0

  tmp="${file}.pp-tmp.$$"
  awk -v heading="$heading" -v newline="$line" '
    { L[NR] = $0; if ($0 == newline) seen = 1 }
    END {
      if (seen) { for (i = 1; i <= NR; i++) print L[i]; exit }

      # Section bounds: heading .. next "## " heading (or EOF).
      s = 0
      for (i = 1; i <= NR; i++) {
        if (L[i] == heading) { s = i; continue }
        if (s && L[i] ~ /^## /) { e = i - 1; break }
      }
      if (!s) { for (i = 1; i <= NR; i++) print L[i]; exit }
      if (!e) e = NR

      # Drop the "(no ... yet" placeholder and its indented continuation lines.
      for (i = s; i <= e; i++) {
        if (L[i] ~ /^- \[[ xX]\] \(no / || L[i] ~ /^_\(no /) {
          drop[i] = 1
          for (j = i + 1; j <= e; j++) {
            if (L[j] ~ /^[[:space:]]+[^[:space:]]/) drop[j] = 1; else break
          }
        }
      }

      # Anchor: first MANDATORY item, else after the last surviving list item,
      # else at the end of the section.
      at = 0
      for (i = s; i <= e; i++)
        if (!drop[i] && L[i] ~ /^- \[[ xX]\] .*MANDATORY/) { at = i; break }
      if (!at) {
        last = 0
        for (i = s; i <= e; i++) if (!drop[i] && L[i] ~ /^- \[[ xX]\] /) last = i
        if (last) {
          for (j = last + 1; j <= e; j++) {
            if (L[j] ~ /^[[:space:]]+[^[:space:]]/) last = j; else break
          }
          at = last + 1
        }
      }
      if (!at) { at = e + 1; while (at > s && L[at-1] == "") at-- }

      for (i = 1; i <= NR; i++) {
        if (i == at) print newline
        if (!drop[i]) print L[i]
      }
      if (at == NR + 1) print newline
    }
  ' "$file" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }

  if [[ -s "$tmp" ]]; then mv "$tmp" "$file"; else rm -f "$tmp"; fi
}

###############################################################################
# .gitignore scope
#
# Only completed plans are local history. Active plans are the artifact a team
# coordinates around and that subagents read via the planning MCP — in lg mode,
# selected precisely because there IS a team, ignoring them defeats the point.
#
# v1.0.0 blanket-ignored .planning/; 3.1.0's archive-plan.sh introduced the narrow
# entry with the reasoning above but never displaced the old rule, leaving four
# shipped docs describing a behavior the code did not have (issue #15).
###############################################################################

# planning_ensure_archive_gitignored <repo-root> [create-if-missing]
#
# Adds `.planning/.archive/` when absent. Never rewrites an existing blanket
# `.planning/` entry — that is the user's file and their call — but says once how to
# narrow it, because otherwise the plans they are about to create are invisible to
# everyone else and nothing tells them.
#
# The init scripts pass no second argument: creating a .gitignore in a repo that has
# none is not their business. archive-plan.sh passes 1 — it has just moved files into
# .archive/ and that path has to be ignored for the move to mean anything.
planning_ensure_archive_gitignored() {
  local gitignore="${1}/.gitignore" create="${2:-}"
  if [[ ! -f "$gitignore" ]]; then
    [[ "$create" == "1" ]] || return 0
    touch "$gitignore" 2>/dev/null || return 0
  fi

  if grep -qE '^\.planning/?$' "$gitignore" 2>/dev/null; then
    planning_warn ".gitignore ignores all of .planning/ — plans will not be shared."
    echo "           Active plans are what teammates and subagents read. To share them," >&2
    echo "           replace the '.planning/' line with '.planning/.archive/'." >&2
    return 0
  fi

  grep -qE '^\.planning/\.archive/?$' "$gitignore" 2>/dev/null && return 0

  printf '\n# Completed plans retired by scripts/archive-plan.sh (local history)\n.planning/.archive/\n' >> "$gitignore"
  planning_ok "Added .planning/.archive/ to .gitignore (active plans stay shareable)"
}

# planning_seed_rules <repo-root>
#
# Copies each templates/rules/*.md into <root>/.claude/rules/ when that file is absent.
# Written once: after that the rule is the repo's, so an existing file is never
# overwritten — not even under PLANNING_FORCE, which is for plan artifacts.
#
# The git-workflow section is the exception: it is appended to the repo's existing git
# workflow rule (babel-fish writes git-workflow.md) or creates one. Its first line is a
# marker, so it is added once and a repo's edits to it stick.
#
# Reads only the plugin's own templates, never <root>/templates: that name is generic
# enough that a project could have one, and its files are not ours to load.
# init-planning.sh (sm) keeps a self-contained copy of this function.
planning_seed_rules() {
  local root="$1" src dest target
  local tpl_dir rules="${1}/.claude/rules"
  tpl_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../templates"
  for src in "$tpl_dir"/rules/*.md; do
    [[ -f "$src" ]] || continue
    dest="${rules}/$(basename "$src")"
    [[ -e "$dest" ]] && continue
    if mkdir -p "$rules" && cp "$src" "$dest"; then
      planning_ok "Added .claude/rules/$(basename "$src")"
    else
      planning_warn "Could not write ${dest} (skipped)"
    fi
  done

  local section="${tpl_dir}/git-workflow-section.md"
  [[ -f "$section" ]] || return 0
  target=$(ls "$rules" 2>/dev/null | grep -iE 'git.?(work)?flow.*\.md$' | head -1)
  if [[ -n "$target" ]]; then
    target="${rules}/${target}"
    grep -qF "$(head -1 "$section")" "$target" && return 0
    if { printf '\n'; cat "$section"; } >> "$target"; then
      planning_ok "Added persistent-plan requirements to .claude/rules/$(basename "$target")"
    else
      planning_warn "Could not update ${target} (skipped)"
    fi
  elif mkdir -p "$rules" && { printf '# Git Workflow\n\n'; cat "$section"; } > "${rules}/git-workflow.md"; then
    planning_ok "Added .claude/rules/git-workflow.md"
  else
    planning_warn "Could not write ${rules}/git-workflow.md (skipped)"
  fi
  return 0
}
