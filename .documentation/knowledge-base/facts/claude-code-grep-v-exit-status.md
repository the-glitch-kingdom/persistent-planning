---
title: In Claude Code's Bash tool, grep -v exits 1 when any line matches
tier: fact
domains:
  - troubleshooting
status: active
last_updated: 2026-10-23
id: claude-code-grep-v-exit-status
confidence: high
last_verified: 2026-10-23
verify_command: |
  printf 'abc\nxyz\n' | command grep -v xyz >/dev/null; echo "GNU grep: $? (expect 0)"; type -t grep
provenance:
  - .planning/hewtd-aware-documentation-closer/
tags:
  - gotcha
  - claude-code
  - shell
invalidated_by:
  - Claude Code stops wrapping grep in a shell function, or its ugrep matches GNU grep's -v exit status
---

# In Claude Code's Bash tool, grep -v exits 1 when any line matches

## Claim

In Claude Code's Bash tool, `grep` is a shell function that runs Claude Code's bundled ugrep.
With `-v`, it prints the right (non-matching) lines but **exits 1 whenever any input line
matches the pattern**. GNU grep exits 0 as long as some line was selected. So
`if … | grep -vq PATTERN` reads "nothing selected" when lines were selected. That includes
`-vqE`, `-v -q -E` and `-vE`.

Observed while filtering date-only `hewtd index` churn: a loop meant to keep index files
with real changes (`grep -vqE "last_updated|Last updated"`) reverted every file, including
the new doc's index entry.

## How to verify

In the Claude Code Bash tool: `type -t grep` prints `function`. Then
`printf 'abc\nxyz\n' | grep -v xyz >/dev/null; echo $?` prints `1`. The same line with
`command grep` prints `0`. The `verify_command` above checks the GNU side. The ugrep
side only reproduces inside Claude Code's Bash tool.

## Instead

Use `command grep` whenever the **exit status** of `grep -v` matters (`if`, `&&`, `||`, `-q`).
Scripts run as child processes (`bash script.sh`, `npm test`) are unaffected, because the
function isn't exported, so `tests/run.sh` and the init scripts use GNU grep. Only commands
typed straight into the tool are affected.

## Consequences

A silent wrong branch, not an error. Here it discarded generated index changes that should
have been committed. Anywhere `grep -v` is used as a test, the "some lines selected" case is
read as "none selected".
