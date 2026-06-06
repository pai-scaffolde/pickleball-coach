# Pickleball Coach Agent Instructions

This is a separate product project. Do not treat this repo as Scaffolde canonical source.

## Authority model

- Product artifacts for this app live here under `~/Projects/pickleball-coach`.
- Scaffolde capability source lives at `~/Projects/scaffolde-ai`.
- Runtime surfaces such as `~/.hermes`, `~/.codex`, `~/.claude`, and `~/.gstack` are projections or local state unless explicitly documented otherwise.
- Do not patch Scaffolde runtime roots directly for durable changes. If a Scaffolde capability is missing, fix Scaffolde canonical source or create a Paperclip remediation issue.

## Use Scaffolde capabilities

Use these capability lanes while building:

- Paperclip: backlog, milestones, acceptance criteria, project tracking.
- Hermes: orchestration, research synthesis, delegation, WhatsApp/user loop.
- GStack: iOS QA, iOS design review, review/ship/spec workflows where available.
- Scaffolde repo: canonical skills, agents, projection manifests, and runtime services.
- GBrain/SecondBrain: durable knowledge only when stable and useful beyond this sprint.

## Skill routing

When a task matches an available skill, load the skill before acting.

Relevant skills/routes:

- iOS live-device QA: `gstack-ios-qa`.
- iOS visual/design QA: `gstack-ios-design-review`.
- Planning/spec writing: `gstack-spec`, `software-development/writing-plans`, `PAI`.
- Test-driven implementation: `software-development/test-driven-development`.
- Systematic debugging: `software-development/systematic-debugging`.
- Scaffolde/Hermes/Paperclip friction: `software-development/scaffolde-platform-operations` and `autonomous-ai-agents/hermes-agent`.
- Research: `research/research-discovery-and-writing`.

## MVP constraints

- Build the import-video path before relying on live camera capture.
- Use Apple Vision first for pose extraction. Evaluate MediaPipe only if Vision is insufficient.
- Keep LLM feedback downstream of deterministic pose metrics.
- Do not use unlicensed pro footage as bundled commercial reference material.
- Do not claim medical-grade biomechanics or professional coaching accuracy.

## Verification standard

A task is not done until it has one of:

- a build/test command output,
- a simulator/device screenshot or video,
- a sample-video analysis artifact,
- a Paperclip issue with acceptance evidence.
