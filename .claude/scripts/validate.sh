#!/bin/bash
# validate.sh — Post-install validation
# Confirms generate.py ran successfully and sections exist
# Usage: bash validate.sh [project-root]
# Exit 0 = OK, Exit 1 = failed

PROJECT_ROOT="${1:-$(pwd)}"
MAP_DIR="$PROJECT_ROOT/.claude/project-map"

GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; CYAN='\033[36m'; RESET='\033[0m'

ok()   { printf '%b\n' "  ${GREEN}✓${RESET} $*"; }
fail() { printf '%b\n' "  ${RED}✗${RESET} $*"; FAILED=1; }
warn() { printf '%b\n' "  ${YELLOW}⚠${RESET} $*"; }

FAILED=0

printf '%b\n' "\n${CYAN}── Validation ──────────────────────────────────────${RESET}"

# Required files
[ -f "$MAP_DIR/generate.py" ]          && ok "generate.py exists"       || fail "generate.py missing"
[ -f "$MAP_DIR/grader.py" ]            && ok "grader.py exists"         || fail "grader.py missing"
[ -f "$MAP_DIR/PROJECT_MAP.md" ]       && ok "PROJECT_MAP.md generated" || fail "PROJECT_MAP.md not generated — did generate.py run?"
[ -f "$MAP_DIR/checksums.json" ]       && ok "checksums.json exists"    || warn "checksums.json missing (ok for first run)"
[ -d "$MAP_DIR/sections" ]             && ok "sections/ directory exists" || fail "sections/ directory missing"

# At least one section
SECTION_COUNT=$(find "$MAP_DIR/sections" -name "*.md" 2>/dev/null | wc -l)
if [ "$SECTION_COUNT" -gt 0 ]; then
    ok "sections/ has $SECTION_COUNT file(s)"
else
    warn "sections/ is empty (ok for greenfield — sections generate as code is added)"
fi

# Rules files
[ -f "$PROJECT_ROOT/.claude/rules/project-vocabulary.md" ] \
    && ok "project-vocabulary.md exists" || fail "project-vocabulary.md missing"
[ -f "$PROJECT_ROOT/.claude/rules/operational-runbook.md" ] \
    && ok "operational-runbook.md exists" || fail "operational-runbook.md missing"

# Skill
SKILL=$(find "$PROJECT_ROOT/.claude/skills" -name "SKILL.md" 2>/dev/null | head -1)
[ -n "$SKILL" ] && ok "Developer skill: $SKILL" || fail "No SKILL.md found in .claude/skills/"

# Git hooks
[ -f "$PROJECT_ROOT/.githooks/pre-commit" ] \
    && ok ".githooks/pre-commit exists" || warn ".githooks/pre-commit missing"
[ -x "$PROJECT_ROOT/.githooks/pre-commit" ] \
    && ok ".githooks/pre-commit is executable" || warn ".githooks/pre-commit is not executable"

printf '%b\n' "${CYAN}────────────────────────────────────────────────────${RESET}"

if [ "$FAILED" -eq 0 ]; then
    printf '%b\n' "\n${GREEN}✓ Validation passed${RESET}\n"
    exit 0
else
    printf '%b\n' "\n${RED}✗ Validation failed — see issues above${RESET}\n"
    exit 1
fi
