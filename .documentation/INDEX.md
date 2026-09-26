---
title: Documentation Index
tier: reference
domains: [root]
status: active
last_updated: '2026-09-26'
version: '1.0.0'
purpose: Navigation hub for all documentation
---

# Documentation Index

> Complete listing of all documentation organized by domain.

## Overview

| Domain | Documents | Description |
|--------|-----------|-------------|
| [Agents](#agents) | 0 | Expert agent documentation, specialty matrix |
| [API](#api) | 0 | API endpoints, routes, specifications, contracts |
| [Architecture](#architecture) | 4 | System design, AI coach, project registry, patterns |
| [Backups](#backups) | 0 | Backup/restore guides, disaster recovery |
| [Database](#database) | 0 | Schema, migrations, RLS, queries, procedures |
| [DevOps](#devops) | 0 | Deployment, CI/CD, Docker, environments, infrastructure |
| [Features](#features) | 0 | Feature implementation guides, admin docs |
| [Plans](#plans) | 0 | Planning documents, roadmaps, proposals |
| [Procedures](#procedures) | 2 | Step-by-step operational procedures (SOP) |
| [Quickstart](#quickstart) | 1 | Setup guides, dev workflow, onboarding |
| [Security](#security) | 0 | Security, auth, Vault, Keycloak, RLS |
| [Standards](#standards) | 2 | Coding standards (backend, frontend, database, devops, security) |
| [Testing](#testing) | 1 | Test strategies, fixtures, patterns, integration/e2e |
| [Troubleshooting](#troubleshooting) | 2 | Debug guides, common issues, solutions |
| [Workflows](#workflows) | 0 | Process documentation, multi-step operations |
| [Reference](#reference) | 3 | Schema, frontmatter, and CLI reference material for the planning artifacts |

---

## Agents

> Expert agent documentation, specialty matrix

**Path:** `agents/`

*No documents yet.*

---

## API

> API endpoints, routes, specifications, contracts

**Path:** `api/`

*No documents yet.*

---

## Architecture

> System design, AI coach, project registry, patterns

**Path:** `architecture/`

| Document | Tier | Status | Updated |
|----------|------|--------|----------|
| [Manus Context Engineering Principles](architecture/context-engineering-principles.md) | reference | active | 2026-08-31 |
| [Lg-Mode Layered Planning Guide](architecture/lg-mode.md) | guide | active | 2026-05-07 |
| [lg plan artifact lifecycle — who writes what](architecture/lg-plan-artifact-lifecycle.md) | reference | active | 2026-09-04 |
| [Skill linking and reclaim](architecture/skill-linking-and-reclaim.md) | reference | active | 2026-09-04 |

---

## Backups

> Backup/restore guides, disaster recovery

**Path:** `backups/`

*No documents yet.*

---

## Database

> Schema, migrations, RLS, queries, procedures

**Path:** `database/`

*No documents yet.*

---

## DevOps

> Deployment, CI/CD, Docker, environments, infrastructure

**Path:** `devops/`

*No documents yet.*

---

## Features

> Feature implementation guides, admin docs

**Path:** `features/`

*No documents yet.*

---

## Plans

> Planning documents, roadmaps, proposals

**Path:** `plans/`

*No documents yet.*

---

## Procedures

> Step-by-step operational procedures (SOP)

**Path:** `procedures/`

| Document | Tier | Status | Updated |
|----------|------|--------|----------|
| [Plan Completion and Archive](procedures/plan-completion-and-archive.md) | guide | active | 2026-08-31 |
| [Plugin update delivery — what actually runs, and when](procedures/plugin-update-delivery.md) | guide | active | 2026-09-04 |

---

## Quickstart

> Setup guides, dev workflow, onboarding

**Path:** `quickstart/`

| Document | Tier | Status | Updated |
|----------|------|--------|----------|
| [Examples: Persistent Planning in Action](quickstart/examples.md) | plan | active | 2026-08-31 |

---

## Security

> Security, auth, Vault, Keycloak, RLS

**Path:** `security/`

*No documents yet.*

---

## Standards

> Coding standards (backend, frontend, database, devops, security)

**Path:** `standards/`

| Document | Tier | Status | Updated |
|----------|------|--------|----------|
| [Atom Granularity (anti-pattern guide)](standards/atom-granularity.md) | standard | active | 2026-05-07 |
| [Mandatory Closing Phases](standards/mandatory-closing-phases.md) | standard | active | 2026-08-31 |

---

## Testing

> Test strategies, fixtures, patterns, integration/e2e

**Path:** `testing/`

| Document | Tier | Status | Updated |
|----------|------|--------|----------|
| [Test Suite](testing/test-suite.md) | guide | active | 2026-08-31 |

---

## Troubleshooting

> Debug guides, common issues, solutions

**Path:** `troubleshooting/`

| Document | Tier | Status | Updated |
|----------|------|--------|----------|
| [A plan won't read COMPLETE](troubleshooting/plan-never-reads-complete.md) | guide | active | 2026-09-04 |
| [Stale skill directory — commands run frozen code](troubleshooting/stale-skill-dir-drift.md) | guide | active | 2026-09-04 |

---

## Workflows

> Process documentation, multi-step operations

**Path:** `workflows/`

*No documents yet.*

---

## Reference

> Schema, frontmatter, and CLI reference material for the planning artifacts

**Path:** `reference/`

| Document | Tier | Status | Updated |
|----------|------|--------|----------|
| [`mandatory:` task frontmatter](reference/mandatory-frontmatter.md) | reference | active | 2026-09-04 |
| [Skill version marker (`.version`)](reference/skill-version-marker.md) | reference | active | 2026-09-04 |
| [workspace.json schema](reference/workspace-json.md) | standard | active | 2026-05-07 |

---

## Maintenance

- **Last generated:** 2026-09-26
- **Run maintenance:** `npx hit-em-with-the-docs maintain`
- **Regenerate index:** `npx hit-em-with-the-docs index`
