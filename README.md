# Pickleball Coach

Separate product project for the Pickleball Coach iOS MVP.

This repo is not Scaffolde itself. Scaffolde is the capability factory and operator substrate used to build this project through Hermes, Paperclip, GStack, and specialist agents.

## MVP thesis

Use iPhone video to turn a practice session into 8-10 slow-motion clips with pose overlays, mechanics scoring, and LLM-generated coaching feedback grounded in computed body-mechanics metrics.

## Canonical artifacts

- `docs/MVP_PLAN.md` — implementation plan and acceptance criteria.
- `docs/SCAFFOLDE_CAPABILITY_SETUP.md` — how this project uses Scaffolde capabilities without becoming part of Scaffolde.
- Paperclip project: Pickleball Coach, ID `d78b78a0-1a6c-45d5-ac6b-6863d9958a3e`.

## First build target

A local-first iOS prototype:

1. Import or record a sample video.
2. Extract body pose over time.
3. Segment candidate reps.
4. Export slow-motion clips.
5. Score simple mechanics.
6. Generate constrained coaching feedback from structured data.
