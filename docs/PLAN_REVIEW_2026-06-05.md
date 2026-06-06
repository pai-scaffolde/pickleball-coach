# Plan Review — gstack autoplan gauntlet (2026-06-05)

Reviewed artifact: `docs/MVP_PLAN.md` (branch `docs/sca-1821-rights-plan`)
Gauntlet: CEO review → Engineering review → Design review → consolidation (auto-decision mode).
DX review skipped: consumer app, not a developer-facing product.

## Verdicts

| Review | Verdict |
| --- | --- |
| CEO | APPROVE-WITH-CHANGES |
| Engineering | APPROVE-WITH-CHANGES |
| Design | APPROVE-WITH-CHANGES |
| **Consolidated** | **APPROVE-WITH-CHANGES** — plan is sound; amendments below are binding for execution |

## Headline finding (all three reviews converged)

**The pose overlay is the product and it is missing from the plan.** The README
thesis promises "slow-motion clips with pose overlays"; the word "overlay" appears
zero times in `MVP_PLAN.md`. Without it the demo is a report card, not a coaching
tool. The overlay (user skeleton rendered on the clip, anchored to the reference at
the key stroke moment) is the screenshot/demo moment and is cheap once Vision pose
tracks exist.

## Consolidated decisions (auto-decided; veto by editing this doc)

| # | Decision | Source | Rationale |
| --- | --- | --- | --- |
| D1 | Add skeleton overlay to MVP scope (M2 debug render, M4 clip/scorecard render) | CEO + Design | Highest-leverage addition; thesis–plan gap |
| D2 | Cut camera capture from MVP gating; import-only demo | CEO + Eng | Device-only complexity, zero demo value; M6 must not block on it |
| D3 | Clip target 8–10 → 3–6 good clips | CEO (Eng acceptance reconciled) | Quality over count; simpler heuristic |
| D4 | One stroke type for MVP scoring: forehand drive | CEO (overrides Eng's "two types") | Three types triple reference/scoring work; spike footage still covers 3 strokes |
| D5 | Defer real LLM provider entirely; authored template mock IS the MVP feedback | CEO + Eng | Indistinguishable in demo; removes API-key/latency/cost variable |
| D6 | Resequence: M2 → M4-lite (scoring + overlay) → M3 (export with overlay) → M5 → M6 | CEO | Clips without scoring context are just trimmed video |
| D7 | Four data contracts committed before M2 starts (parallelization gate) | Eng | CV/scoring/feedback agent lanes need a shared contract |
| D8 | One canonical sample video committed/referenced as a test fixture | Eng | Without it every acceptance criterion is untestable |
| D9 | Time-based pose sampling (e.g., 10 Hz), not frame-index | Eng | Correct across 30–240 fps sources |
| D10 | 1-day Vision pose-confidence spike before any M2 build | Eng | #1 risk; Apple's model can't be patched if it fails on pickleball footage |

## Pre-Milestone-2 gate (do these first)

1. **Spike: Vision pose quality.** Run `VNDetectHumanBodyPoseRequest` over 3 short
   clips (forehand, backhand, serve) in a test harness; log per-joint confidence.
   Pass: ≥60% of frames have wrist+elbow+shoulder at confidence ≥0.5. Budget: 1 day.
2. **Commit schemas:**
   - `Models/PoseFrame.swift` — `{ timestamp, joints: [JointName: {x, y, confidence}], bodyDetected }`, pinned to the Vision joint names in use
   - `Models/ClipInterval.swift` — `{ id, startTime, endTime, strokeType?, confidence }`
   - `Models/MechanicsScore.swift` — `{ clipId, strokeType, scores: [Category: Double], observations }`
   - Extend `Session` with `poseTimelineFileName`, `clipIntervals`, `mechanicsScores`
3. **Commit fixture:** one canonical sample video (rights-cleared per
   `docs/RIGHTS_PLAN.md`) + `tests/fixtures/rep-annotations.json` with manually
   annotated rep boundaries for the spike clips.

## Revised milestone sequence

| Order | Milestone | Key amendment |
| --- | --- | --- |
| 1 | M2 Pose extraction | + debug overlay renders skeleton on ≥1 video frame (screenshot evidence); time-based sampling; orientation normalized via `CGImagePropertyOrientation` |
| 2 | M4-lite Mechanics scoring | Forehand only; scores carry measured vs reference metric values ("elbow angle: 142° / ideal: 155°"); bitwise-reproducibility XCTest; thresholds in versioned JSON with cited source |
| 3 | M3 Segmentation + slow-mo export | 3–6 clips; heuristic passes IoU ≥ 0.7 vs annotated fixtures; export asserts duration = 4× input ±5% and AVPlayer loads without error; overlay baked into or rendered over exported clips |
| 4 | M5 Feedback (mock only) | Template feedback keyed to score ranges, referencing ≥1 specific metric per clip; works offline (XCTest, no network); visible "AI-generated coaching feedback — not medical or professional advice" disclaimer |
| 5 | M6 Demo hardening | Scripted import→analyze→review ×3 without crash; camera capture explicitly NOT a gate |

## Design acceptance criteria added (binding)

- Analysis progress is **determinate** (phase label + frame count, updates ≤ every 2s) — pose extraction on a 1–3 min video is O(minutes) on device; an indeterminate spinner reads as a hang. (Design scored current plan 2/10 here.)
- Review screen: scrollable clip carousel with inline slow-mo playback; per-clip
  scorecard shows the skeleton overlay at the key frame (contact/peak of arc).
- Feedback presentation: compact score visual (gauge/bar/grade) + the measured
  metric, so LLM/template text reads grounded, not horoscope-y.

## Edge cases now in scope (Eng)

Video orientation metadata; fps variance (24–240); multi-person frames (use
highest-confidence body or fail with user message); partial-body visibility
(define minimum joint set); max video duration guard (~5 min) with
`AVAssetImageGenerator` streaming, never full-frame loads; simulator tests need the
committed fixture video (Vision needs a real person in frame).

## Unchanged

Hard constraints reaffirmed: Apple Vision first; import before capture; feedback
strictly downstream of deterministic metrics; rights register governs all pro
references (no row, no ship); no medical/professional-accuracy claims.

---
*Generated by the gstack autoplan gauntlet in auto-decision mode. `docs/MVP_PLAN.md`
was intentionally left unedited; fold these amendments in (or veto specific
decisions) before opening Milestone-2 Paperclip issues.*
