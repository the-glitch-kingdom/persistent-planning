---
title: babel-fish's pre-commit hook commits an untracked project map into the next qualifying commit
tier: fact
domains:
  - troubleshooting
status: active
last_updated: 2026-10-23
id: babel-fish-hook-adds-untracked-map
confidence: high
last_verified: 2026-10-23
verify_command: |
  command grep -n "git add .claude/project-map" .githooks/pre-commit
provenance:
  - .planning/hewtd-aware-documentation-closer/
sources:
  - .githooks/pre-commit
tags:
  - gotcha
  - babel-fish
  - git
invalidated_by:
  - babel-fish's hook stops running git add on the map, or only re-adds files that are already tracked
---

# babel-fish's pre-commit hook commits an untracked project map into the next qualifying commit

## Claim

Once the babel-fish installer has run (`core.hooksPath=.githooks`), any commit that stages a
`.py`, `.ts`, `.js`, `.go`, `.java`, `.yaml`/`.yml`, `package.json`, `Cargo.toml`, `go.mod` or
docker-compose file runs the codebase mapper. The mapper then runs
`git add .claude/project-map/...`. If the map has never been committed, this stages the whole
map (about 25 files) into that commit. Nothing reports it beyond the generator's progress lines.

It happened on the 3.6.0 release commit: bumping `package.json` brought in the entire map,
and it was pushed before anyone noticed.

## How to verify

`.githooks/pre-commit` contains `git add .claude/project-map/PROJECT_MAP.md ...` inside the
"Codebase Mapper" block. After a commit touching one of those file types, run
`git show --stat HEAD`, which lists `.claude/project-map/` files you didn't stage.

## Instead

Right after installing babel-fish, commit its output on its own: `.claude/project-map/`,
`.claude/rules/`, `.claude/CLAUDE.md`, `.githooks/` and the generated developer skill.
After that the hook only stages real map changes. To keep the map out of git, gitignore
`.claude/project-map/`, which turns the hook's `git add` into a no-op. Removing the map from a commit the hook
already touched means re-committing, and the hook re-adds it. So commit the map first and
rebuild the branch on top, rather than amending past the hook with `--no-verify`.

## Consequences

Release and feature commits pick up unrelated generated files. Check
`git show --stat HEAD` after the first commit in a repo where babel-fish was just installed.
