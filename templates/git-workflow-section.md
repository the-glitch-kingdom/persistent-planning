<!-- persistent-planning:git-workflow -->
## Persistent plans

These are hard requirements on every plan under `.planning/`:

1. **Sync `main` first.** `git checkout main && git fetch origin main && git merge --ff-only origin/main`.
2. **Cut a new branch** for the plan before changing anything: `git checkout -b <type>/<plan-slug>`.
3. **Implement the plan through to completion**: every phase, including the mandatory cleanup,
   validation and documentation steps, until `/plan-status` reads COMPLETE.
4. **Commit at the end of each phase** (sm: each item under `## Phases`; lg: each task).
5. **Finish with a single PR** for the whole plan, against `main`.
