# Scaffolde Capability Setup

## Boundary

Pickleball Coach is a separate app project. Scaffolde is the factory we use to
build it, not the app source tree.

- App project: `~/Projects/pickleball-coach` (remote: `github.com/pai-scaffolde/pickleball-coach`, auto-pushed — see `AGENTS.md`)
- Scaffolde source: `~/Projects/scaffolde-ai`
- Hermes runtime: `~/.hermes` (projection — never patch directly)
- Paperclip runtime/API: local Paperclip server, currently `http://127.0.0.1:3102/api`
- Paperclip project: Pickleball Coach, ID `d78b78a0-1a6c-45d5-ac6b-6863d9958a3e`

## Capability lanes

| Need | Use |
| --- | --- |
| Backlog, milestones, acceptance evidence | Paperclip (project above) |
| Orchestration, delegation, user loop | Hermes (`~/.hermes` skills: `paperclip`, `gstack-*`, etc.) |
| iOS live-device QA | `gstack-ios-qa` |
| iOS visual/design QA | `gstack-ios-design-review` |
| Plan/spec/review workflows | `gstack-spec`, `gstack-autoplan`, plan-review skills |
| Durable knowledge | GBrain/SecondBrain (only when stable beyond this sprint) |

## If a capability is missing from a runtime surface

Do not patch `~/.hermes`, `~/.claude`, or any other runtime root directly —
projections are rebuilt from Scaffolde canonical and direct edits get clobbered.

Fix the projection manifest in `~/Projects/scaffolde-ai` (usually
`manifests/domains/*.yaml` or `manifests/bundles/*.yaml`), re-run the surface
sync (`bun run sync:hermes` / `bun run sync:claude`), and land it as a PR from a
linked worktree if the main checkout is dirty. If you can't do that now, file a
Scaffolde remediation issue in Paperclip instead of working around it.

Precedent: the Paperclip skills were missing from Hermes and were fixed exactly
this way — `manifests/domains/agents.yaml` hermes projection, landed as
[scaffolde-ai#662](https://github.com/pai-scaffolde/scaffolde-ai/pull/662).
