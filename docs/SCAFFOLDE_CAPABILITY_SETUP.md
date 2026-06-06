# Scaffolde Capability Setup

## Boundary

Pickleball Coach is a separate app project. Scaffolde is the factory we use to build it, not the app source tree.

- App project: `~/Projects/pickleball-coach`
- Scaffolde source: `~/Projects/scaffolde-ai`
- Hermes runtime: `~/.hermes`
- GStack generated Hermes skills: `~/.hermes/skills/gstack-*` and `~/.hermes/skills/gstack`
- Paperclip runtime/API: local Paperclip server, currently `http://127.0.0.1:3102/api`

## Current capability visibility

Hermes can see skills that are installed/projected into `~/.hermes/skills`.

Observed on 2026-06-05:

- Hermes live skill catalog: 319 `SKILL.md` files under `~/.hermes/skills`.
- Scaffolde repo: 977 `SKILL.md` files under `~/Projects/scaffolde-ai`, including source skills, fixtures, generated skills, and tool-specific skill catalogs.
- GStack skills are visible because `manifests/bundles/hermes-default.yaml` explicitly allowlists generated gstack skills for the Hermes surface.
- Paperclip's core skill exists in Scaffolde/Paperclip source, but is not currently projected into `~/.hermes/skills/paperclip`, so `skill_view('paperclip')` does not resolve in Hermes.

## GStack location

Canonical/source lane:

- `~/Projects/scaffolde-ai/skills/gstack`
- `~/Projects/scaffolde-ai/manifests/upstreams/gstack.yaml`
- `~/Projects/scaffolde-ai/manifests/bundles/hermes-default.yaml` lists the Hermes-projected gstack skill IDs.

Hermes live lane:

- `~/.hermes/skills/gstack/SKILL.md`
- `~/.hermes/skills/gstack-ios-qa/SKILL.md`
- `~/.hermes/skills/gstack-ios-design-review/SKILL.md`
- `~/.hermes/skills/gstack-spec/SKILL.md`
- and other `~/.hermes/skills/gstack-*` skills.

## Correct remediation for missing Paperclip skill in Hermes

Do not patch `~/.hermes` directly.

Smallest canonical fix:

1. Edit `~/Projects/scaffolde-ai/manifests/domains/agents.yaml`.
2. Add a `hermes` projection for the Paperclip integration skill beside the existing `claude` projection:

```yaml
projections:
  hermes:
    files:
      - from: integrations/paperclip/SKILL.md
        to: skills/paperclip/SKILL.md
      - from: integrations/paperclip-create-agent/SKILL.md
        to: skills/paperclip-create-agent/SKILL.md
      - from: integrations/paperclip-create-plugin/SKILL.md
        to: skills/paperclip-create-plugin/SKILL.md
```

3. Run from `~/Projects/scaffolde-ai`:

```bash
bun run sync:hermes
bun run validate:hermes:surface
```

Expected result:

- `~/.hermes/skills/paperclip/SKILL.md` exists.
- `skill_view('paperclip')` resolves in Hermes.

## Current blocker

The Scaffolde checkout is broadly dirty from other active lanes. Do not edit projection manifests in the main checkout casually. Use a linked worktree or a Paperclip remediation lane for the Paperclip-skill projection fix.

## Recommended live operating model for this app

1. Use this repo for app code and product docs.
2. Use Paperclip Pickleball Coach project for backlog/acceptance.
3. Use Hermes as orchestrator.
4. Use Scaffolde/GStack skills by loading from Hermes when available.
5. If a needed capability is not visible in Hermes, create a Scaffolde remediation task rather than bypassing the projection model.
