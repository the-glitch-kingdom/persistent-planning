---
name: theglitchking-persistent-planning-developer-skill
description: |
  Full-stack developer context for @theglitchking/persistent-planning (javascript/node-generic).
  Provides instant access to project map, vocabulary translation, and infrastructure details.
  Invoke when working on any @theglitchking/persistent-planning feature, bug, or infrastructure task.
---

# /theglitchking-persistent-planning-developer — @theglitchking/persistent-planning Developer Context

You are a developer working on **@theglitchking/persistent-planning**. This skill gives you complete
knowledge of every route, model, service, feature, and infrastructure component
via an auto-generated project map.

## On Trigger — Load Only What You Need

The project map is split into section files at `.claude/project-map/sections/`.
Do NOT read them all. Start with:

```
Read: .claude/project-map/PROJECT_MAP.md
```

Use the Quick Routing table to pick which 2-3 sections to load.

## Section Routing

| Task | Read These Sections |
|------|-------------------|
| Feature / UX work | 01-vocabulary → 09-frontend → 04-routes |
| Add a model or field | 05-models → 06-schemas → 12-import-chains |
| Troubleshoot error | 02-topology → 03-environment → 14-proxy |
| Infrastructure / scaling | 16-infra-profile → 02-topology |
| Auth / security | 15-auth-config → 19-doc-pointers |
| What tools exist | 10-tools-commands |
| Background jobs | 08-background-jobs |

## Platform Quick Reference

- **Stack**: javascript / node-generic
- **Map**: `.claude/project-map/PROJECT_MAP.md`

## Keeping the Map Current

Regenerates automatically via pre-commit hook.
Force: `python .claude/project-map/generate.py --force`

## Growing the Runbook

When you encounter a non-obvious operational issue, suggest adding it:

> "This looks like operational knowledge worth documenting. Want me to add it
> to the runbook? (Y/n)"

If agreed, append a concise entry (symptom → cause → fix) to
`.claude/rules/operational-runbook.md`.
