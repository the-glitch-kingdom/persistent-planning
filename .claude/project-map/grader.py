#!/usr/bin/env python3
"""
grader.py — Babel Fish Quality Grader
Grades generate.py output on a 0-100 scale across 7 weighted categories.
Writes a human-readable report and returns exit code 0 (pass) or 1 (fail).

Usage:
    python grader.py [--project-root PATH] [--iteration N] [--total N] [--report-path PATH]

Exit codes:
    0 = PASS (score >= 90%)
    1 = FAIL (score < 90%)
    2 = ERROR (could not run)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent
MAP_DIR      = SCRIPT_DIR
SECTIONS_DIR = MAP_DIR / "sections"
REPORTS_DIR  = MAP_DIR / "reports"
PROJECT_ROOT = MAP_DIR.parent.parent

REPORTS_DIR.mkdir(parents=True, exist_ok=True)


def configure_paths(project_root: Path) -> None:
    """Grade the map belonging to project_root, not the script's own.

    Previously --project-root moved only the path-validation root, so the
    script's own sections were graded against a different project's filesystem —
    producing a confident but meaningless score (0% vocabulary accuracy).
    """
    global PROJECT_ROOT, MAP_DIR, SECTIONS_DIR, REPORTS_DIR
    PROJECT_ROOT = project_root
    MAP_DIR      = project_root / '.claude' / 'project-map'
    SECTIONS_DIR = MAP_DIR / 'sections'
    REPORTS_DIR  = MAP_DIR / 'reports'
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

PASS_THRESHOLD = 90.0

# ── Secret pattern (identical to generate.SECRET_PATTERNS; test_grader pins it) ─
# generate.py redacts with it, so a hit here means something bypassed redaction.
SECRET_PATTERN = re.compile(
    r'(?i:password|secret|token|api_key|apikey|private_key|auth_token|'
    r'access_key|secret_key|client_secret|db_pass|database_password|'
    r'stripe_key|twilio_auth|sendgrid_key|aws_secret)\s*[=:]\s*(?!\[)[^\s`|"\',]+'
    r'|(?<=://)(?!\[REDACTED\])[^\s/@`|]+(?=@)'      # URL userinfo: postgres://user:pass@, DSN keys
    r'|\b[sr]k_(?:live|test)_[0-9A-Za-z]{8,}'        # Stripe
    r'|\bsk-[A-Za-z0-9_-]{16,}'                      # OpenAI / Anthropic style
    r'|\bgh[pousr]_[A-Za-z0-9]{20,}|\bgithub_pat_\w{20,}'
    r'|\bxox[abprs]-[A-Za-z0-9-]{10,}'               # Slack tokens
    r'|hooks\.slack\.com/services/[A-Za-z0-9/]+'
    r'|\bAKIA[0-9A-Z]{16}\b|\bAIza[0-9A-Za-z_-]{35}'  # AWS access key, Google API key
    r'|-----BEGIN [A-Z ]*PRIVATE KEY-----'
)

# ── Grading weights ───────────────────────────────────────────────────────────
WEIGHTS = {
    'section_completeness': 25,
    'vocabulary_accuracy':  20,
    'import_chain_validity':15,
    'secret_safety':        15,
    'section_size_bounds':  10,
    'structural_integrity': 10,
    'checksum_functionality': 5,
}

assert sum(WEIGHTS.values()) == 100

# ── Color helpers (ANSI) ──────────────────────────────────────────────────────
GREEN  = '\033[32m'
YELLOW = '\033[33m'
RED    = '\033[31m'
CYAN   = '\033[36m'
BOLD   = '\033[1m'
RESET  = '\033[0m'

def color_score(score: float) -> str:
    c = GREEN if score >= 90 else YELLOW if score >= 70 else RED
    return f"{c}{score:.1f}%{RESET}"

def color_pass(passed: bool) -> str:
    return f"{GREEN}PASS{RESET}" if passed else f"{RED}FAIL{RESET}"


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  GRADING FUNCTIONS                                                       ║
# ╚══════════════════════════════════════════════════════════════════════════╝

class GradeResult:
    def __init__(self, category: str, weight: int, raw_score: float,
                 details: str, issues: list[str], fixes: list[str] | None = None):
        self.category   = category
        self.weight     = weight
        self.raw_score  = max(0.0, min(100.0, raw_score))  # clamp 0-100
        self.weighted   = self.raw_score * weight / 100
        self.details    = details
        self.issues     = issues
        self.fixes      = fixes or []

    @property
    def display_name(self) -> str:
        return self.category.replace('_', ' ').title()


def grade_section_completeness() -> GradeResult:
    """25% — expected sections were generated."""
    issues = []
    expected = [f"{str(i).zfill(2)}-" for i in range(1, 20)]  # 01- through 19-
    present = set()

    if SECTIONS_DIR.exists():
        for f in SECTIONS_DIR.glob('*.md'):
            for exp in expected:
                if f.name.startswith(exp):
                    present.add(exp)

    missing = [e for e in expected if e not in present]
    for m in missing:
        issues.append(f"Missing section: {m}*.md")

    score = (len(present) / len(expected)) * 100 if expected else 100.0

    # Check PROJECT_MAP.md exists
    if not (MAP_DIR / 'PROJECT_MAP.md').exists():
        issues.append("PROJECT_MAP.md not generated")
        score = min(score, 50.0)

    details = f"{len(present)}/{len(expected)} sections present"
    return GradeResult('section_completeness', WEIGHTS['section_completeness'],
                       score, details, issues)


def grade_vocabulary_accuracy() -> GradeResult:
    """20% — vocabulary entries point to files that exist."""
    vocab_file = SECTIONS_DIR / '01-vocabulary.md'
    issues = []

    if not vocab_file.exists():
        return GradeResult('vocabulary_accuracy', WEIGHTS['vocabulary_accuracy'],
                           0.0, 'vocabulary section missing', ['01-vocabulary.md not found'])

    content = vocab_file.read_text(encoding='utf-8', errors='replace')

    # Extract location column from table rows
    # Format: | alias | type | location | notes |
    rows = re.findall(r'^\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|', content, re.MULTILINE)
    rows = [r for r in rows if not r[0].strip().startswith('-') and r[0].strip() != 'Alias']

    if not rows:
        # Greenfield — empty vocab is acceptable
        details = "No vocabulary entries yet (greenfield — ok)"
        return GradeResult('vocabulary_accuracy', WEIGHTS['vocabulary_accuracy'],
                           85.0, details, [])

    total = len(rows)
    valid = 0
    for _, _, location, _ in rows:
        loc = location.strip()
        if not loc or loc.startswith('_') or loc == '':
            valid += 1  # empty location is neutral
            continue
        # Check if any referenced file exists
        # Location may contain multiple paths separated by ', '
        paths = [p.strip() for p in loc.split(',')]
        any_exists = any((PROJECT_ROOT / p).exists() for p in paths if p and not p.startswith('('))
        if any_exists or loc.startswith('[LEARNED]') or '(learned' in loc.lower():
            valid += 1
        else:
            issues.append(f"Vocab entry points to non-existent path: {loc[:60]}")

    score = (valid / total * 100) if total > 0 else 85.0
    details = f"{valid}/{total} entries have valid file references"
    return GradeResult('vocabulary_accuracy', WEIGHTS['vocabulary_accuracy'],
                       score, details, issues[:5])  # cap at 5 issues in report


def grade_import_chains() -> GradeResult:
    """15% — import chains section exists and chains are plausible."""
    chains_file = SECTIONS_DIR / '12-import-chains.md'
    issues = []

    if not chains_file.exists():
        return GradeResult('import_chain_validity', WEIGHTS['import_chain_validity'],
                           0.0, 'section missing', ['12-import-chains.md not found'])

    content = chains_file.read_text(encoding='utf-8', errors='replace')

    if '_No import chains traced' in content:
        # For greenfield or non-Python: acceptable
        details = "No chains traced (greenfield or non-Python stack — ok)"
        return GradeResult('import_chain_validity', WEIGHTS['import_chain_validity'],
                           80.0, details, [])

    # Check that chains reference real files
    chain_lines = re.findall(r'```\n(.+)\n```', content)
    total = len(chain_lines)
    valid = 0
    for chain in chain_lines:
        files = re.findall(r'([\w/.-]+\.py)', chain)
        if not files:
            valid += 1
            continue
        if all((PROJECT_ROOT / f).exists() for f in files[:2]):
            valid += 1
        else:
            issues.append(f"Chain references missing files: {chain[:80]}")

    score = (valid / total * 100) if total > 0 else 80.0
    details = f"{valid}/{total} chains reference real files"
    return GradeResult('import_chain_validity', WEIGHTS['import_chain_validity'],
                       score, details, issues[:3])


def grade_secret_safety() -> GradeResult:
    """15% — no secrets leaked in any section or PROJECT_MAP.md."""
    issues = []
    files_checked = 0
    leaks_found = 0

    check_paths: list[Path] = [MAP_DIR / 'PROJECT_MAP.md', MAP_DIR / 'glossary.json']
    if SECTIONS_DIR.exists():
        check_paths.extend(SECTIONS_DIR.glob('*.md'))

    for path in check_paths:
        if not path.exists():
            continue
        files_checked += 1
        try:
            content = path.read_text(encoding='utf-8', errors='replace')
            for m in SECRET_PATTERN.finditer(content):
                line_num = content[:m.start()].count('\n') + 1
                leaks_found += 1
                # Never echo the match: this text lands in the committed install report.
                issues.append(f"Potential secret in {path.name}:{line_num} (value withheld)")
        except Exception as e:
            issues.append(f"Could not read {path.name}: {e}")

    # Secret leaks are a hard fail — each leak heavily penalizes
    score = max(0.0, 100.0 - (leaks_found * 25))
    details = f"Checked {files_checked} files — {leaks_found} potential leak(s)"
    return GradeResult('secret_safety', WEIGHTS['secret_safety'],
                       score, details, issues)


def grade_section_sizes() -> GradeResult:
    """10% — sections are within 0.1KB–50KB bounds."""
    issues = []
    if not SECTIONS_DIR.exists():
        return GradeResult('section_size_bounds', WEIGHTS['section_size_bounds'],
                           0.0, 'sections/ directory missing', ['sections/ not found'])

    sections = list(SECTIONS_DIR.glob('*.md'))
    if not sections:
        # Greenfield — no sections yet means they were written as empty placeholders
        return GradeResult('section_size_bounds', WEIGHTS['section_size_bounds'],
                           85.0, 'sections exist (greenfield content expected to be minimal)', [])

    violations = 0
    for f in sections:
        size_kb = f.stat().st_size / 1024
        if size_kb < 0.05:
            issues.append(f"{f.name}: {size_kb:.2f}KB — suspiciously empty")
            violations += 1
        elif size_kb > 50:
            issues.append(f"{f.name}: {size_kb:.1f}KB — exceeds 50KB limit (should be split)")
            violations += 1

    score = max(0.0, 100.0 - (violations / max(len(sections), 1)) * 100)
    details = f"{len(sections)} sections, {violations} size violations"
    return GradeResult('section_size_bounds', WEIGHTS['section_size_bounds'],
                       score, details, issues[:5])


def grade_structural_integrity() -> GradeResult:
    """10% — valid markdown, proper headings, TOC links resolve."""
    issues = []
    score = 100.0

    project_map = MAP_DIR / 'PROJECT_MAP.md'
    if not project_map.exists():
        return GradeResult('structural_integrity', WEIGHTS['structural_integrity'],
                           0.0, 'PROJECT_MAP.md missing', ['PROJECT_MAP.md not found'])

    content = project_map.read_text(encoding='utf-8', errors='replace')

    # Must have a top-level heading
    if not re.search(r'^# .+', content, re.MULTILINE):
        issues.append("PROJECT_MAP.md missing top-level heading")
        score -= 20

    # Must have Stats section
    if '## Stats' not in content:
        issues.append("PROJECT_MAP.md missing ## Stats section")
        score -= 15

    # Must have Section Index
    if 'Section Index' not in content:
        issues.append("PROJECT_MAP.md missing Section Index")
        score -= 15

    # Must have Quick Routing
    if 'Quick Routing' not in content:
        issues.append("PROJECT_MAP.md missing Quick Routing table")
        score -= 10

    # Check that section links in TOC point to real files
    link_pattern = re.compile(r'\[(\d+)\]\(sections/([^)]+)\)')
    broken_links = 0
    for m in link_pattern.finditer(content):
        target = SECTIONS_DIR / m.group(2)
        if not target.exists():
            issues.append(f"Broken TOC link: sections/{m.group(2)}")
            broken_links += 1
    if broken_links:
        score -= broken_links * 5

    # Check each section has a top-level heading
    if SECTIONS_DIR.exists():
        for f in SECTIONS_DIR.glob('*.md'):
            try:
                first_line = f.read_text(encoding='utf-8', errors='replace').split('\n')[0]
                if not first_line.startswith('#'):
                    issues.append(f"{f.name}: missing top-level heading")
                    score -= 2
            except Exception:
                pass

    details = f"{broken_links} broken TOC links, {len(issues)} structural issues"
    return GradeResult('structural_integrity', WEIGHTS['structural_integrity'],
                       max(0.0, score), details, issues[:5])


def grade_checksum_functionality() -> GradeResult:
    """5% — checksums.json exists and looks valid."""
    issues = []

    checksums_path = MAP_DIR / 'checksums.json'
    if not checksums_path.exists():
        return GradeResult('checksum_functionality', WEIGHTS['checksum_functionality'],
                           0.0, 'checksums.json missing', ['checksums.json not found — checksum skip will not work'])

    try:
        data = json.loads(checksums_path.read_text())
        if 'input_hash' not in data:
            issues.append("checksums.json missing 'input_hash' key")
            return GradeResult('checksum_functionality', WEIGHTS['checksum_functionality'],
                               50.0, 'checksums.json malformed', issues)
        if not isinstance(data['input_hash'], str) or len(data['input_hash']) < 32:
            issues.append("checksums.json has invalid hash value")
            return GradeResult('checksum_functionality', WEIGHTS['checksum_functionality'],
                               60.0, 'checksums.json has weak hash', issues)
    except json.JSONDecodeError as e:
        return GradeResult('checksum_functionality', WEIGHTS['checksum_functionality'],
                           0.0, f'checksums.json parse error: {e}', [str(e)])

    details = f"checksums.json valid (hash: {data['input_hash'][:12]}...)"
    return GradeResult('checksum_functionality', WEIGHTS['checksum_functionality'],
                       100.0, details, [])


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  REPORT BUILDER                                                          ║
# ╚══════════════════════════════════════════════════════════════════════════╝

def build_report(
    results: list[GradeResult],
    total_score: float,
    passed: bool,
    iteration: int,
    total_iterations: int,
    previous_score: float | None,
) -> str:
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    verdict = "✅ PASSED" if passed else "❌ FAILED"
    threshold_note = f"{PASS_THRESHOLD:.0f}% threshold"

    delta_str = ''
    if previous_score is not None:
        delta = total_score - previous_score
        sign = '+' if delta >= 0 else ''
        delta_str = f" ({sign}{delta:.1f}% from previous)"

    lines = [
        f"# Babel Fish — Installation Report",
        f"",
        f"**Generated**: {now}",
        f"**Iteration**: {iteration} of {total_iterations}  ",
        f"**Score**: {total_score:.1f}%{delta_str}  ",
        f"**Result**: {verdict} ({threshold_note})",
        f"",
        "---",
        "",
        "## Scoring Breakdown",
        "",
        "| Category | Score | Weight | Weighted | Status |",
        "|----------|-------|--------|----------|--------|",
    ]

    for r in results:
        status = "✅" if r.raw_score >= 90 else "⚠️" if r.raw_score >= 70 else "❌"
        lines.append(
            f"| {r.display_name} | {r.raw_score:.1f}% | {r.weight}% "
            f"| {r.weighted:.1f} | {status} {r.details} |"
        )

    lines += [
        "",
        f"**Total: {total_score:.1f} / 100**",
        "",
        "---",
        "",
        "## Issues Found",
        "",
    ]

    all_issues = [(r.display_name, issue) for r in results for issue in r.issues]
    if all_issues:
        for category, issue in all_issues:
            lines.append(f"- ❌ **{category}**: {issue}")
    else:
        lines.append("_No issues found._")

    if iteration > 1:
        lines += [
            "",
            "---",
            "",
            "## Improvements Made This Iteration",
            "",
        ]
        all_fixes = [(r.display_name, fix) for r in results for fix in r.fixes]
        if all_fixes:
            for category, fix in all_fixes:
                lines.append(f"- ✅ **{category}**: {fix}")
        else:
            lines.append("_No specific improvements recorded._")

    lines += [
        "",
        "---",
        "",
        "## Final Verdict",
        "",
    ]

    if passed:
        lines += [
            f"✅ **PASSED ({total_score:.1f}%)** — Map is production-ready.",
            "",
            "The project map meets quality standards and is ready to use.",
            "Future sessions will load relevant sections automatically via the developer skill.",
        ]
    else:
        remaining = total_iterations - iteration
        if remaining > 0:
            lines += [
                f"❌ **FAILED ({total_score:.1f}%)** — Below {PASS_THRESHOLD:.0f}% threshold.",
                "",
                f"{remaining} iteration(s) remaining. Addressing issues above and retrying...",
            ]
        else:
            lines += [
                f"⚠️ **COMPLETED WITH WARNINGS ({total_score:.1f}%)** — Final iteration reached.",
                "",
                "The map was generated but did not reach the 90% quality threshold.",
                "Review the issues above and consider running `python generate.py --force` after",
                "addressing them, then re-running `python grader.py` to verify.",
            ]

    lines += [
        "",
        "---",
        "",
        "## How to Use the Project Map",
        "",
        "```bash",
        "# Read the map index",
        "cat .claude/project-map/PROJECT_MAP.md",
        "",
        "# Force regeneration",
        "python .claude/project-map/generate.py --force",
        "",
        "# Re-run grader",
        "python .claude/project-map/grader.py",
        "```",
        "",
        "_Report generated by `grader.py` — part of the Babel Fish plugin._",
    ]

    return '\n'.join(lines) + '\n'


def print_terminal_summary(results: list[GradeResult], total_score: float, passed: bool,
                            iteration: int, total_iterations: int) -> None:
    """Print a concise terminal summary with color."""
    print(f"\n{CYAN}{'─' * 55}{RESET}")
    print(f"{BOLD}  Babel Fish — Grade Report  "
          f"(Iteration {iteration}/{total_iterations}){RESET}")
    print(f"{CYAN}{'─' * 55}{RESET}\n")

    for r in results:
        bar_filled = int(r.raw_score / 10)
        bar = ('█' * bar_filled) + ('░' * (10 - bar_filled))
        c = GREEN if r.raw_score >= 90 else YELLOW if r.raw_score >= 70 else RED
        print(f"  {r.display_name:<30} {c}{bar}{RESET}  {r.raw_score:5.1f}%  (×{r.weight}%)")

    print(f"\n{CYAN}{'─' * 55}{RESET}")
    score_color = GREEN if passed else (YELLOW if total_score >= 70 else RED)
    verdict = f"{GREEN}PASS ✓{RESET}" if passed else f"{RED}FAIL ✗{RESET}"
    print(f"  {'TOTAL SCORE':<30} {score_color}{total_score:5.1f}%{RESET}  → {verdict}")
    print(f"{CYAN}{'─' * 55}{RESET}\n")

    pop, total_sections = populated_sections()
    if total_sections:
        print(f"  {'Sections populated':<30} {pop}/{total_sections}"
              f"  (diagnostic — not scored)")
        print()

    for w in usefulness_warnings():
        print(f"{YELLOW}  ⚠ {w}{RESET}")
    if usefulness_warnings():
        print()

    all_issues = [(r.display_name, i) for r in results for i in r.issues]
    if all_issues:
        print(f"{YELLOW}  Issues:{RESET}")
        for cat, issue in all_issues[:8]:
            print(f"    ✗ {cat}: {issue}")
        if len(all_issues) > 8:
            print(f"    ... and {len(all_issues) - 8} more (see report)")
        print()


# ── Usefulness diagnostics (reported, never scored) ──────────────────────────
# The seven graded categories all measure FORM, and generate.py always emits
# well-formed output — so an empty map and a populated one score identically
# (both 97.0% before this was added). The information that separates them is
# not in the map, so it is surfaced as a warning rather than folded into the
# score: making it scored would fail legitimately sparse repos, which is a
# worse failure than the one it fixes.

def _stat(content: str, label: str) -> int | None:
    m = re.search(rf'^\|\s*{re.escape(label)}\s*\|\s*(\d+)\s*\|', content, re.MULTILINE)
    return int(m.group(1)) if m else None


def usefulness_warnings() -> list[str]:
    map_file = MAP_DIR / 'PROJECT_MAP.md'
    if not map_file.exists():
        return []
    content = map_file.read_text(encoding='utf-8', errors='replace')
    warnings = []

    # Vocabulary is the product. Zero entries means the map gave the user
    # nothing, whatever the seven form categories say. This is the signal that
    # would have surfaced issue #6 at install time.
    vocab = _stat(content, 'Vocabulary Entries')
    if vocab == 0:
        warnings.append(
            "Vocabulary is empty — the map's primary output produced nothing. "
            "Expected on a repo with no source code; otherwise an extractor "
            "does not understand this project's shape."
        )

    # Source files present but nothing extracted from them: a parser that does
    # not fit the stack, rather than a repo with nothing to find.
    scanned = 0
    block = re.search(r'### Source files scanned(.*?)(?:\n## |\Z)', content, re.DOTALL)
    if block:
        scanned = sum(int(n) for n in re.findall(r'^\|[^|]+\|\s*(\d+)\s*\|',
                                                 block.group(1), re.MULTILINE))
    extracted = sum(v or 0 for v in (
        _stat(content, 'API Routes'), _stat(content, 'Data Models'),
        _stat(content, 'Schemas/DTOs'), _stat(content, 'Frontend Features')))
    if scanned >= 10 and extracted == 0:
        warnings.append(
            f"Scanned {scanned} source file(s) but extracted no routes, models, "
            f"schemas or features — likely an unsupported framework."
        )
    return warnings


def populated_sections() -> tuple[int, int]:
    """Sections carrying real content. Diagnostic only — 19 is aspirational,
    not a target: a plugin repo can never populate routes or migrations."""
    files = sorted(SECTIONS_DIR.glob('*.md')) if SECTIONS_DIR.exists() else []
    pop = 0
    for f in files:
        body = f.read_text(encoding='utf-8', errors='replace')
        meat = [ln for ln in body.splitlines()
                if ln.strip() and not ln.startswith(('#', '>'))
                and not re.fullmatch(r'\|[\s|:-]*\|', ln.strip())
                and not re.match(r'^_\(?(no|none|not)\b', ln.strip(), re.I)]
        if meat:
            pop += 1
    return pop, len(files)


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  MAIN                                                                    ║
# ╚══════════════════════════════════════════════════════════════════════════╝

def main() -> None:
    parser = argparse.ArgumentParser(description='Grade babel-fish output')
    parser.add_argument('--project-root', type=Path, default=None)
    parser.add_argument('--iteration', type=int, default=1)
    parser.add_argument('--total', type=int, default=3, help='Total iterations planned')
    parser.add_argument('--previous-score', type=float, default=None)
    parser.add_argument('--report-path', type=Path, default=None,
                        help='Override report output path')
    args = parser.parse_args()

    if args.project_root:
        configure_paths(args.project_root.resolve())

    print(f"[grader] Grading iteration {args.iteration}/{args.total}...")

    results = [
        grade_section_completeness(),
        grade_vocabulary_accuracy(),
        grade_import_chains(),
        grade_secret_safety(),
        grade_section_sizes(),
        grade_structural_integrity(),
        grade_checksum_functionality(),
    ]

    total_score = sum(r.weighted for r in results)
    passed = total_score >= PASS_THRESHOLD

    print_terminal_summary(results, total_score, passed, args.iteration, args.total)

    # Write report
    report_content = build_report(results, total_score, passed,
                                  args.iteration, args.total, args.previous_score)

    report_path = args.report_path or (REPORTS_DIR / f"iteration-{args.iteration:02d}-report.md")
    report_path.write_text(report_content, encoding='utf-8')

    # Also write/update the main install report
    install_report = REPORTS_DIR / "install-report.md"
    if args.iteration == 1:
        install_report.write_text(report_content, encoding='utf-8')
    else:
        # Append this iteration's report
        existing = install_report.read_text(encoding='utf-8') if install_report.exists() else ''
        separator = f"\n\n{'='*60}\n\n"
        install_report.write_text(existing + separator + report_content, encoding='utf-8')

    print(f"[grader] Report written → {report_path}")
    print(f"[grader] Install report → {install_report}")

    # Output score as JSON for installer to read
    score_data = {
        'score': round(total_score, 2),
        'passed': passed,
        'threshold': PASS_THRESHOLD,
        'iteration': args.iteration,
        'issues': [
            {'category': r.category, 'issue': i}
            for r in results for i in r.issues
        ],
    }
    score_json = REPORTS_DIR / f"iteration-{args.iteration:02d}-score.json"
    score_json.write_text(json.dumps(score_data, indent=2), encoding='utf-8')

    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
