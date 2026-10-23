#!/usr/bin/env python3
"""
context-check.py — Babel Fish
Keeps the files Claude Code auto-loads at session start small and pointing at
things that exist (#20).

`CLAUDE.md` and every `.claude/rules/*.md` load into every session. Past the
harness limit (150k chars) rules stop binding and nothing reports it; before
that, growth is one paragraph at a time and nobody sees the total. Three checks:

1. BUDGET    — total chars under --budget (default 60k, well under the limit).
2. POINTERS  — every `→ `path``, backticked `.documentation/…md` path and
               relative markdown link names a file that exists. hewtd link-checks
               only INSIDE `.documentation/`, so archiving or renaming a doc a
               rule points at breaks the pointer silently.
3. RULE LINES (--map-style only) — in a rules file every bullet is
               `- ALWAYS|NEVER <rule> — <why> → `doc``; in CLAUDE.md every
               bullet with a pointer is. Opt-in: it is one repo's convention, and
               this runs from the pre-commit hook of every babel-fish install.

Deliberately NOT part of generate.py: the hook runs generate.py only when code
is staged, `.claude/` is outside the watch set, and the hook discards its
errors — a failure there could never block a commit.

Usage:
    python context-check.py [--budget N] [--map-style] [--descriptive a.md,b.md]
                            [--warn-only] [--project-root PATH]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent

HARNESS_LIMIT = 150_000
DEFAULT_BUDGET = 60_000
# Maps whose lines describe (tools, traps, vocabulary) rather than rule — exempt
# from the ALWAYS/NEVER form. project-vocabulary.md is babel-fish's own output.
DEFAULT_DESCRIPTIVE = {"operational-runbook.md", "project-vocabulary.md", "tool-registry.md"}

ARROW_RE = re.compile(r"→ `([^`\s*]+?\.md)(?:#[^`]*)?`")
DOC_PATH_RE = re.compile(r"`(\.documentation/[^`\s*]+?\.md)(?:#[^`]*)?`")
MD_LINK_RE = re.compile(r"\]\(([^)\s]+)\)")
FENCE_RE = re.compile(r"^```.*?^```", re.MULTILINE | re.DOTALL)
RULE_RE = re.compile(r"- (ALWAYS|NEVER)\b")


def configure_paths(project_root: Path) -> None:
    """Read root. Nothing here writes, but match the sibling scripts (#18)."""
    global PROJECT_ROOT
    PROJECT_ROOT = project_root


def loaded() -> dict[str, str]:
    """-> {relpath: text} for every file Claude Code loads at session start."""
    paths = [PROJECT_ROOT / n for n in ("CLAUDE.md", "CLAUDE.local.md", ".claude/CLAUDE.md")]
    # ponytail: rules with `paths:` frontmatter load lazily but are counted anyway —
    # over-counting errs toward the budget, not past the limit.
    paths += sorted((PROJECT_ROOT / ".claude" / "rules").rglob("*.md"))
    return {p.relative_to(PROJECT_ROOT).as_posix(): p.read_text(encoding="utf-8", errors="replace")
            for p in paths if p.is_file()}


def bullets(text: str) -> list[str]:
    return [ln for ln in text.split("\n") if ln.startswith("- ")]


def bad_rule_lines(text: str) -> list[str]:
    """-> bullets that are not `- ALWAYS|NEVER … → `path``."""
    return [ln for ln in bullets(text) if not RULE_RE.match(ln) or not ARROW_RE.search(ln)]


def unresolved(text: str, file_dir: Path) -> list[str]:
    """-> every pointer in `text` naming a path that does not exist.

    `→` pointers and backticked `.documentation/` paths are root-relative (that is
    how the map convention writes them); markdown links resolve relative to the file or
    to the root. Code fences are skipped — examples are not pointers.
    """
    text = FENCE_RE.sub("", text)
    missing = [p for p in set(ARROW_RE.findall(text)) | set(DOC_PATH_RE.findall(text))
               if not (PROJECT_ROOT / p).exists()]
    for link in MD_LINK_RE.findall(text):
        target = link.split("#", 1)[0]
        if not target or re.match(r"[a-z][a-z0-9+.-]*:", target, re.I):  # anchor-only, http:, mailto:
            continue
        target = target.lstrip("/")
        # File-relative is markdown; root-relative is how Claude reads a path, and
        # what the installer's own .claude/CLAUDE.md pointer uses. Either counts.
        if not ((file_dir / target).exists() or (PROJECT_ROOT / target).exists()):
            missing.append(link)
    return sorted(set(missing))


def run(budget: int, map_style: bool, descriptive: set[str]) -> int:
    """Print the report; return the number of failed checks."""
    fails = 0

    def check(name: str, ok: bool, detail: str = "") -> None:
        nonlocal fails
        print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f"  -- {detail}" if detail and not ok else ""))
        fails += not ok

    files = loaded()
    total = sum(len(t) for t in files.values())

    print("\nthe budget")
    check(f"auto-loaded context is under {budget:,} chars", total <= budget,
          f"{total:,} -- move detail into .documentation/ and leave one line pointing at it")
    for k, t in sorted(files.items(), key=lambda kv: -len(kv[1])):
        print(f"        {len(t):>7,}  {k}")
    print(f"        {total:>7,}  total ({total / HARNESS_LIMIT:.0%} of the {HARNESS_LIMIT:,} harness limit)")

    print("\nevery pointer resolves")
    for k, t in files.items():
        miss = unresolved(t, (PROJECT_ROOT / k).parent)
        check(f"{k}: all pointers exist", not miss, ", ".join(miss[:3]))

    if map_style:
        print("\nrule lines are ALWAYS/NEVER, with a pointer")
        for k, t in files.items():
            if Path(k).name in descriptive:
                continue
            if k.startswith(".claude/rules/"):
                bad = bad_rule_lines(t)
                check(f"{k}: every bullet is ALWAYS|NEVER → doc", not bad, bad[0][:80] if bad else "")
            else:  # CLAUDE.md: tool lines may go unpointed; a pointed bullet is a rule
                bad = [ln for ln in bad_rule_lines(t) if "→" in ln]
                check(f"{k}: every pointed bullet is ALWAYS|NEVER", not bad, bad[0][:80] if bad else "")

    print(f"\n{'OK' if not fails else f'{fails} FAILED'}")
    return fails


def main() -> None:
    ap = argparse.ArgumentParser(description="Check the context Claude Code auto-loads (#20).")
    ap.add_argument("--budget", type=int, default=DEFAULT_BUDGET,
                    help=f"max total chars (default {DEFAULT_BUDGET:,}; harness limit {HARNESS_LIMIT:,})")
    ap.add_argument("--map-style", action="store_true",
                    help="also require rule bullets to be `- ALWAYS|NEVER … → `doc``")
    ap.add_argument("--descriptive", default=",".join(sorted(DEFAULT_DESCRIPTIVE)),
                    help="comma-separated filenames exempt from --map-style (default: %(default)s)")
    ap.add_argument("--warn-only", action="store_true", help="report, but always exit 0")
    ap.add_argument("--project-root", type=Path, default=None)
    args = ap.parse_args()
    if args.project_root:
        configure_paths(args.project_root.resolve())
    fails = run(args.budget, args.map_style, {n.strip() for n in args.descriptive.split(",") if n.strip()})
    sys.exit(1 if fails and not args.warn_only else 0)


if __name__ == "__main__":
    main()
