---
title: git rm --cached on a path whose files were moved away silently drops staged content
tier: fact
domains:
  - troubleshooting
status: active
last_updated: 2026-10-23
id: git-rm-cached-moved-path-drops-staged
confidence: high
last_verified: 2026-10-23
verify_command: |
  #!/usr/bin/env bash
  set -euo pipefail
  d=$(mktemp -d); cd "$d"; git init -q; echo a > f; git add f; git -c user.name=t -c user.email=t@t commit -qm a
  echo staged > f; git add f; echo a > f; mkdir moved; mv f moved/
  git rm -q --cached f && echo "rm --cached succeeded: staged blob dropped from index"
  cd /; rm -rf "${d:?}"
provenance:
  - .planning/archive-plan-untracks-archived-plans-issue-26/
sources:
  - scripts/archive-plan.sh
tags:
  - gotcha
  - git
invalidated_by:
  - git rm --cached starts refusing when the index entry differs from HEAD regardless of the worktree
---

# git rm --cached on a path whose files were moved away silently drops staged content

## Claim

`git rm --cached <path>` refuses ("staged content different from both the file and the HEAD")
only when it can compare against a **worktree file**. If the files at `<path>` have already been
moved elsewhere (e.g. `mv .planning/x .planning/.archive/x`), there is nothing to compare, and git
untracks the path without complaint. Any staged content that differed from the worktree copy is
then gone from the index. Only a dangling blob is left, which `git fsck` can find.

Found while fixing #26: the first fix moved the plan, then relied on `git rm --cached` refusing to
protect staged changes. It never refused.

## How to verify

Run `verify_command`. It stages content that differs from the worktree, moves the file away, and
`git rm --cached` succeeds.

## Instead

Check for staged changes **before** moving: `git diff --cached --quiet -- <path>` (non-zero means
staged changes). If there are any, don't untrack. Warn and let the user commit or unstage first.
This is what `scripts/archive-plan.sh` does.

## Consequences

Any "move, then untrack the old path" sequence needs its own staged-change check. Git's built-in
refusal won't protect it.
