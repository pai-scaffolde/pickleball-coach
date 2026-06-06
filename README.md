# Pickleball Coach

[![iOS build](https://github.com/pai-scaffolde/pickleball-coach/actions/workflows/ios-build.yml/badge.svg?branch=main)](https://github.com/pai-scaffolde/pickleball-coach/actions/workflows/ios-build.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Stack](https://img.shields.io/badge/Swift-SwiftUI%20%C2%B7%20Vision%20%C2%B7%20AVFoundation-orange)

Point your iPhone at a practice session. Get back slow-motion clips of your
strokes with a pose-skeleton overlay, deterministic mechanics scores, and
coaching feedback grounded in computed body-mechanics metrics — not vibes.

```
import video ──▶ Vision pose timeline ──▶ rep segmentation ──▶ slow-mo clips
                                                                    │
   coaching feedback ◀── rules engine ◀── mechanics scoring ◀── overlay render
```

Every coaching statement is downstream of a measured metric. The LLM may
phrase feedback; it never invents biomechanical judgments.

## Screenshots

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/artifacts/sca1889/01-onboarding.png" alt="Onboarding — import a clip or try the demo" width="220"></td>
    <td align="center" width="25%"><img src="docs/artifacts/sca1889/02-detail.png" alt="Session detail — status, duration, and analysis entry points" width="220"></td>
    <td align="center" width="25%"><img src="docs/artifacts/sca1889/03-scorecard.png" alt="Mechanics score — pose-skeleton key frame with per-metric ideal bands" width="220"></td>
    <td align="center" width="25%"><img src="docs/artifacts/sca1889/04-comparison.png" alt="Compare — your stroke against a generic reference exemplar, phase by phase" width="220"></td>
  </tr>
  <tr>
    <td align="center"><b>Onboarding</b><br>Import a clip or run the bundled demo.</td>
    <td align="center"><b>Session</b><br>Status, duration, and the analysis entry points.</td>
    <td align="center"><b>Mechanics score</b><br>Contact key frame with per-metric ideal bands.</td>
    <td align="center"><b>Compare</b><br>Your stroke vs. a generic reference, phase by phase.</td>
  </tr>
</table>

> Screenshots are from the rights-clean in-app demo session, built from a
> generic pose-only reference exemplar — not a named athlete or licensed
> footage. See [`docs/RIGHTS_PLAN.md`](docs/RIGHTS_PLAN.md).

## Status

> **Source of truth: the Paperclip tracking issues, not this table.** Each
> milestone links to its issue; state is derived from that issue's status and
> its `blockedBy` dependency graph, so it can't silently drift. Don't hand-edit
> state here — close the linked issue. This snapshot was last reconciled against
> issue state on 2026-06-06.

| Milestone | Scope | Tracking issue | State |
| --- | --- | --- | --- |
| M0–1 | App skeleton, video import, session persistence, playback | SCA-1851 | ✅ done |
| Spike | Apple Vision pose capture validated on real footage | SCA-1819 | ✅ done |
| M2 gate | Pipeline data contracts (`PoseFrame`, `ClipInterval`, `MechanicsScore`) + canonical fixture | SCA-1859 | ✅ done |
| M2 | Vision pose extraction pipeline (time-based sampling, debug overlay) | SCA-1860 | ✅ done |
| M4-lite | Deterministic mechanics scoring (forehand) + skeleton overlay | SCA-1861 | ✅ done |
| M3 | Rep segmentation + slow-motion clip export (3–6 quality clips) | SCA-1862 | ✅ done |
| Feedback | Coach-reviewed rules engine (LLM phrases, never judges) | SCA-1823 | ✅ done |
| M6 | Demo hardening: import → analyze → clips → scores → feedback, offline | SCA-1863 | ✅ done |

Dependency chain (`blockedBy`, tracked under epic SCA-1858):

```
M0–1 ┐
     ├─→ M2 gate ─→ M2 ─→ M4-lite ─→ M3 ─┐
Spike┘                                    ├─→ M6
Spike ───────────────→ Feedback ─────────┘
```

**All MVP milestones are complete.** Remaining work is pre-launch quality gates,
each tracked as its own issue (not milestones):

- SCA-1826 — pre-launch red-team gates (blocked)
- SCA-1872 — G6 drill-recall survey, target ≥80% (blocked)
- SCA-1884 — coach-review v0 footage calibration (todo)
- SCA-1906 — app loads to Sessions first (in review)

## Try it

See [`docs/DEMO_PATH.md`](docs/DEMO_PATH.md). Short version: open
`PickleballCoach/PickleballCoach.xcodeproj` in Xcode 15+, run on any iPhone
simulator, tap **+**, pick a sample video, and the session persists with
inline playback.

## Documentation

| Doc | What it is |
| --- | --- |
| [`docs/MVP_PLAN.md`](docs/MVP_PLAN.md) | Implementation plan, milestones, acceptance criteria |
| [`docs/PLAN_REVIEW_2026-06-05.md`](docs/PLAN_REVIEW_2026-06-05.md) | Three-perspective plan review (CEO/Eng/Design) and the 10 binding execution decisions |
| [`docs/DEMO_PATH.md`](docs/DEMO_PATH.md) | Step-by-step demo instructions and current limitations |
| [`docs/RIGHTS_PLAN.md`](docs/RIGHTS_PLAN.md) | Rights policy for pro references and demo assets — binding |
| [`docs/assets/exemplar-rights-register.json`](docs/assets/exemplar-rights-register.json) | Per-asset rights register: **no row, no ship** |
| [`docs/SCAFFOLDE_CAPABILITY_SETUP.md`](docs/SCAFFOLDE_CAPABILITY_SETUP.md) | How this project consumes Scaffolde capabilities |
| [`AGENTS.md`](AGENTS.md) | Operating rules for AI agents working in this repo |

## How this is built

This repo is the product. The factory is
[Scaffolde](https://github.com/pai-scaffolde/scaffolde-ai) — a personal AI
infrastructure that plans, reviews, implements, and QAs through coordinated
agents:

- **Plan → review:** the MVP plan was pressure-tested by a three-reviewer
  gauntlet (CEO, engineering, design lenses); the converged decisions are
  committed as [`docs/PLAN_REVIEW_2026-06-05.md`](docs/PLAN_REVIEW_2026-06-05.md).
- **Backlog:** milestones live as dependency-chained issues in Paperclip
  (project `pickleball-coach`); each issue carries binary, tool-verifiable
  acceptance criteria, and agents auto-wake as their blockers resolve.
- **Implementation:** specialist agents (engineering, CV, QA) work the chain;
  every commit auto-pushes here, so this repo is always the live state.
- **Verification standard:** nothing is "done" without build/test output, a
  simulator screenshot, or an analysis artifact (see `AGENTS.md`).

## Boundaries

- Single-player practice analysis. Not a medical or professional biomechanics
  product — feedback carries an explicit disclaimer.
- No unlicensed pro footage, ever. Pro references (Ben Johns, Anna Leigh
  Waters, …) are aspirational until licensed; the rights register gates every
  exemplar asset.
- Local-first: the MVP demo requires no accounts, no cloud, no API keys.
