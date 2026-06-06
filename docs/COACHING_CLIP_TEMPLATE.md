# Coaching Clip Template — Slow-Motion Analysis Cards

Status: **design spec** · Owner: Design · Issue: SCA-1822 · Last updated: 2026-06-05

This document defines the template for the 8-10 slow-motion coaching clip cards produced in
Milestone 3–4. It covers per-card layout, evidence frames, overlay rendering, scorecard
placement, annotation style, and the complete storyboard — one entry per clip phase.

Rights constraint: every reference exemplar shown in the UI must be a **pose-only generic
exemplar (Option C)** per `docs/RIGHTS_PLAN.md`. No named athlete footage, no licensed
third-party clips. Pose skeletons and threshold-derived ghost overlays qualify; real
identifiable persons do not until a register row confirms `cleared-public`.

---

## 1. Card Anatomy

Each coaching clip card is a self-contained SwiftUI screen (or carousel page). It has five
vertical zones:

```
┌────────────────────────────────────┐
│  ZONE 1 — Video / Evidence Frame   │  ~42 % of screen height
│  (slow-motion player + overlay)    │
├────────────────────────────────────┤
│  ZONE 2 — Phase Header             │  44 pt fixed
├────────────────────────────────────┤
│  ZONE 3 — Scorecard Bar            │  56 pt fixed
├────────────────────────────────────┤
│  ZONE 4 — Coaching Panels          │  fills remaining height
│  (Observation / Correction / Cue)  │
├────────────────────────────────────┤
│  ZONE 5 — Navigation Controls      │  44 pt fixed
└────────────────────────────────────┘
```

### Zone 1 — Evidence frame player

- Aspect ratio: 9:16 cropped to a 4:3 viewport (letterboxed on tall devices).
- Default state: paused at the **key frame** for the phase (see storyboard below).
- Tap to play/pause slow-motion loop; double-tap to advance to next phase.
- Overlay layer renders on top (see Section 3).
- A small pill button top-right toggles the overlay on/off: label "Skeleton On / Off".
- No pro athlete names, logos, or identifiable likenesses appear in this zone.

### Zone 2 — Phase header

```
  [Phase number badge]  [Phase title]          [Stroke type chip]
  e.g. "5 of 9"         "Hip / Shoulder Turn"  "Forehand Drive"
```

- Phase number badge: 24×24 pt rounded rectangle, `.systemGray5` fill, SF Mono 12.
- Phase title: SF Pro Display Semibold 17 pt, `.label`.
- Stroke type chip: SF Pro Text Regular 13 pt, tinted `.systemBlue` background at 12 %
  opacity, `.systemBlue` text, 6 pt corner radius.

### Zone 3 — Scorecard bar

Displays a single composite score (0–100) for the mechanics dimension that matters most
for this phase (see storyboard). One score per card — resist the urge to stack multiple
scores here; the detail is in Zone 4.

```
  [Dimension label, SF Pro Text 13 pt, .secondaryLabel]
  [Score bar: full width, 8 pt height, rounded capsule]
  [Score value right-aligned, SF Pro Display Bold 24 pt, tinted by tier]
```

Color tiers for score value and bar fill:
- ≥ 80: `.systemGreen`
- 60 – 79: `.systemOrange`
- < 60: `.systemRed`

### Zone 4 — Coaching panels

Three stacked cards with 8 pt gap between them:

```
┌──────────────────────────────────────┐
│ 👁  Observation                      │  icon + label (SF Pro Semibold 13pt)
│    [one sentence, .body, .label]     │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ ↕  Correction                        │
│    [one sentence, .body, .label]     │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ 🎯  Drill / Cue                      │
│    [one sentence, .body, .label]     │
└──────────────────────────────────────┘
```

- Card background: `.secondarySystemBackground`, 10 pt corner radius, no shadow.
- Icons: SF Symbols. Observation → `eye`, Correction → `arrow.up.arrow.down.circle`,
  Drill → `target`.
- Text is never truncated — panels expand vertically with the content.
- Keep every entry to one sentence (≤ 90 characters). If longer, the copy is wrong.

### Zone 5 — Navigation controls

```
  [← Prev]  ●●●●●○○○○○  [Next →]
```

- Prev/Next: `chevron.left` / `chevron.right` system images, `.systemBlue` tint.
- Progress dots: 8 pt diameter, active `.systemBlue`, inactive `.systemGray4`,
  6 pt spacing.
- On first card, Prev is hidden. On last card, Next becomes "Done".

---

## 2. Scorecard Placement Rationale

The single per-card score sits between the video and the coaching text (Zone 3) so the
user reads: **see the frame → see the grade → understand why**. Stacking multiple
dimension scores was deliberately rejected because it fragments attention before the user
has read the observation. Per-clip scores are aggregated into a session-level scorecard
on the summary screen (out of scope for this template).

---

## 3. Overlay Rendering Spec

Overlays are rendered as a transparent `Canvas` layer over Zone 1. The rendering system
receives a normalized `PoseFrame` (joint positions in 0.0–1.0 coordinate space) and
phase-specific highlight instructions.

### Base skeleton

- Joint dots: 6 pt diameter filled circle, `.white` at 85 % opacity.
- Bone lines: 2 pt stroke, `.white` at 70 % opacity, round line caps.
- Rendered for all detected joints in the frame.

### Highlight style

Each phase specifies a `highlightJoints` list (see storyboard). Highlighted elements use:
- Joint dot: 8 pt, `.systemYellow` at 100 % opacity.
- Connecting bone: 3 pt, `.systemYellow` at 90 % opacity.

### Problem indicator

When the score for the card's primary dimension is < 70, overlay adds a small amber
`⚠` glyph (SF Symbol `exclamationmark.triangle.fill`, `.systemOrange`) adjacent to the
primary problem joint. One indicator maximum per frame — pick the joint contributing most
to the score deficit.

### Reference ghost (optional, Milestone 4+)

A second skeleton rendered from the bundled generic exemplar for the phase:
- All joints/bones: `.systemTeal` at 35 % opacity.
- Offset from user skeleton if overlap exceeds 80 % by ±4 pt x-jitter to distinguish.
- The ghost represents an **anonymous, pose-only generic exemplar** (Option C). It must
  never be labeled with a named athlete.

### Contact-zone annotation (phases 6 and 7 only)

A dashed rectangle drawn in front of the player's torso indicating the ideal contact
zone (derived from generic thresholds, not pro footage):
- 2 pt dashed stroke, `.systemCyan` at 70 % opacity, 6 pt corner radius.
- Width: 18 % of frame width. Height: 24 % of frame height.
- Label "Contact zone" in SF Pro Text 10 pt `.systemCyan`, top-left of the rectangle.

### Angle arc (phases 5 and 7 only)

An arc drawn between the shoulder line and hip line (phase 5) or arm and torso (phase 7):
- 2 pt stroke, `.systemPurple` at 80 % opacity.
- Degree label alongside the arc in SF Mono 11 pt `.systemPurple`.

---

## 4. Storyboard — All 10 Phase Clip Cards

Format per entry:
- **Key frame**: which moment in the clip to pause on by default.
- **Highlight joints**: joints to emphasize in the overlay.
- **Primary score dimension**: the single mechanics metric shown in Zone 3.
- **Observation**: one sentence describing what the system measured.
- **Correction**: one sentence prescribing the fix.
- **Drill / Cue**: one sentence describing a practice action.
- **Rights note**: confirms asset compliance.

---

### Phase 1 — Ready Position

| Field | Value |
|---|---|
| **Key frame** | First frame where player is stationary and paddle is raised in front of body |
| **Highlight joints** | Both ankles, both knees, wrists |
| **Primary score** | Stance Readiness (0–100): composite of knee bend depth, foot spread, paddle height |
| **Observation** | "Your stance width is [X]% of shoulder width; ideal range is 100–120%." |
| **Correction** | "Widen your base to shoulder width and soften your knees to 15–20° of bend." |
| **Drill / Cue** | "Shadow drill: bounce on your toes ten times, freeze in ready position each bounce." |
| **Rights note** | Skeleton overlay on user's own pose; no pro reference shown |

---

### Phase 2 — Foot Setup / Stance Width

| Field | Value |
|---|---|
| **Key frame** | Frame where both feet are planted after the split-step, just before swing initiation |
| **Highlight joints** | Both feet (ankles), hip midpoint |
| **Primary score** | Split-Step Timing (0–100): frames between opponent's contact and player's foot plant |
| **Observation** | "Split-step completed [N] frames after the detected incoming ball, [early/late/on time]." |
| **Correction** | "Time your split-step to land as your opponent's paddle contacts the ball." |
| **Drill / Cue** | "Verbal cue drill: say 'bounce' aloud whenever your opponent hits; match foot plant to the word." |
| **Rights note** | Skeleton overlay only; no real footage reference shown |

---

### Phase 3 — Weight Load

| Field | Value |
|---|---|
| **Key frame** | Frame of maximum lateral hip shift toward the dominant side, before paddle takeback |
| **Highlight joints** | Dominant hip, dominant knee, dominant ankle |
| **Primary score** | Weight Transfer (0–100): lateral center-of-mass displacement toward dominant side |
| **Observation** | "Hip loaded to [X]% of detected ideal range before backswing." |
| **Correction** | "Shift your weight fully onto your dominant leg before moving the paddle back." |
| **Drill / Cue** | "Hip-touch drill: brush your dominant hip with your free hand as you initiate the backswing." |
| **Rights note** | User pose only; reference ghost is generic exemplar (Option C) if shown |

---

### Phase 4 — Paddle Takeback

| Field | Value |
|---|---|
| **Key frame** | Frame of maximum paddle distance from body (furthest back point of backswing) |
| **Highlight joints** | Dominant wrist, dominant elbow, dominant shoulder |
| **Primary score** | Takeback Compactness (0–100): paddle path length relative to contact zone; shorter is higher |
| **Observation** | "Paddle traveled [X]% above the ideal contact height during takeback." |
| **Correction** | "Keep the paddle below shoulder level on takeback for a more compact loop." |
| **Drill / Cue** | "One-handed shadow: slow-motion takeback with eyes closed, feel paddle stay below ear level." |
| **Rights note** | User pose only; no pro reference |

---

### Phase 5 — Hip / Shoulder Turn

| Field | Value |
|---|---|
| **Key frame** | Frame of maximum hip rotation, mid-forward-swing |
| **Highlight joints** | Both hips, both shoulders |
| **Primary score** | Kinetic Chain Score (0–100): hip-to-shoulder separation angle at peak turn |
| **Observation** | "Hip led shoulder rotation by [X]°; optimal range is 30–45°." |
| **Correction** | "Let hips initiate and drive the swing; shoulders follow, not lead." |
| **Drill / Cue** | "Seated towel drill: sit, drape towel across shoulders, practice rotating hips first each rep." |
| **Rights note** | Angle-arc overlay drawn from user pose data; no identifiable reference person |

---

### Phase 6 — Contact Preparation

| Field | Value |
|---|---|
| **Key frame** | Two frames before estimated contact, arm extending toward contact zone |
| **Highlight joints** | Dominant wrist, dominant elbow; contact zone rectangle shown |
| **Primary score** | Wrist Firmness Readiness (0–100): angular velocity of wrist joint in the 3 frames before contact |
| **Observation** | "Wrist angular velocity [X] rad/s at pre-contact; values above [threshold] indicate instability." |
| **Correction** | "Lock your wrist firm before the paddle reaches the ball; avoid late wrist roll." |
| **Drill / Cue** | "Wall-tap drill: firm-tap paddle face against wall ×20, focusing on zero wrist bend at contact." |
| **Rights note** | Contact-zone annotation is a computed generic threshold; no athlete shown |

---

### Phase 7 — Contact Point

| Field | Value |
|---|---|
| **Key frame** | Exact contact frame (lowest wrist velocity transition, typically detectable as motion blur minimum) |
| **Highlight joints** | Dominant wrist; arm extension line drawn |
| **Primary score** | Contact Position (0–100): normalized distance between contact point and ideal zone center |
| **Observation** | "Contact occurred [in front of / beside / behind] the lead foot by [X] cm estimated distance." |
| **Correction** | "Meet the ball in front of your lead foot with your arm ~80% extended, not fully straight." |
| **Drill / Cue** | "Target feed drill: partner feeds to a cone target; freeze your pose at contact each rep." |
| **Rights note** | Angle arc and contact ring are computed geometry; user skeleton only |

---

### Phase 8 — Follow-Through

| Field | Value |
|---|---|
| **Key frame** | Frame where paddle arc reaches its highest post-contact point |
| **Highlight joints** | Dominant wrist, dominant shoulder; paddle-path arc drawn |
| **Primary score** | Follow-Through Completion (0–100): paddle finish height relative to shoulder and crossing of body center |
| **Observation** | "Paddle finished at [X]% of shoulder height and [crossed / did not cross] body center." |
| **Correction** | "Finish the paddle across your body and above shoulder height on every full drive." |
| **Drill / Cue** | "Slow-finish drill: after each practice rep, consciously slow the follow-through and hold the end position 2 seconds." |
| **Rights note** | Path arc computed from user joint data; no third-party footage |

---

### Phase 9 — Recovery / Next-Shot Readiness

| Field | Value |
|---|---|
| **Key frame** | Frame ~0.5 s after follow-through peak, player returning toward neutral stance |
| **Highlight joints** | Both feet, hip midpoint |
| **Primary score** | Recovery Speed (0–100): frames to return to ready-position joint configuration from follow-through peak |
| **Observation** | "Recovery to ready stance took [X] frames (~[Y] ms); optimal is < [threshold] ms." |
| **Correction** | "Begin resetting your stance immediately after contact; don't watch the ball before moving." |
| **Drill / Cue** | "Hit-and-recover drill: after every practice shot, sprint back to a marked ready-position X on the court." |
| **Rights note** | User pose only |

---

### Phase 10 (Optional) — Balance / Reset

Included when the segmentation module detects a detectable neutral pause between reps.
If no stable recovery frame is found, this card is skipped and the session has 9 cards.

| Field | Value |
|---|---|
| **Key frame** | Most stable frame between reps (lowest total joint velocity) |
| **Highlight joints** | Both ankles, spine midpoint (center-of-mass proxy) |
| **Primary score** | Balance Score (0–100): deviation of computed center of mass from midpoint of foot base |
| **Observation** | "Center of mass deviated [X] cm from balanced midpoint between shots." |
| **Correction** | "Absorb the follow-through momentum into a wide, low base before the next movement." |
| **Drill / Cue** | "Balance-line drill: practice recovery with feet straddling a court line; re-center on the line after each shot." |
| **Rights note** | Generic center-of-mass proxy computed from user pose; no reference footage |

---

## 5. Content Rules

These rules apply to all 10 cards and any variant copy:

1. **One sentence per panel.** If it won't fit in 90 characters, shorten it.
2. **Observations use computed values.** Populate `[X]` and `[Y]` from the mechanics
   comparison module at runtime. Never hard-code specific numeric advice.
3. **Corrections are prescriptive, not diagnostic.** Tell the user what to do, not what
   is wrong — that's the Observation's job.
4. **Drills are reproducible solo.** Every drill can be done without a partner unless
   the card explicitly says "partner feeds". Keep it simple enough to attempt in a driveway.
5. **No medical language.** Avoid: "injury risk", "pain", "biomechanical deficiency",
   "clinical", "strain", "correct this before you get hurt". The app is not a medical device.
6. **No named athletes.** Per `AGENTS.md` and `docs/RIGHTS_PLAN.md`, no pro athlete names
   appear in card copy, overlay labels, or reference identifiers.

---

## 6. SwiftUI Component Map

The implementation of this template maps to the following component hierarchy (for
Engineering reference — detailed implementation is in scope for Milestone 3–4):

```
CoachingClipCardView
├── VideoPlayerZone
│   ├── AVPlayerLayer (slow-motion)
│   └── PoseOverlayCanvas
│       ├── BaseSkeletonLayer
│       ├── HighlightJointsLayer
│       ├── ReferenceGhostLayer (optional)
│       ├── ContactZoneAnnotation (phases 6–7)
│       └── AngleArcAnnotation (phases 5, 7)
├── PhaseHeaderView
├── ScorecardBarView
├── CoachingPanelStack
│   ├── CoachingPanel(type: .observation)
│   ├── CoachingPanel(type: .correction)
│   └── CoachingPanel(type: .drill)
└── ClipNavigationControls
```

Each `CoachingPanel` receives a plain `String`. The parent `CoachingClipCardView` is
initialized from a `ClipAnalysisResult` model that Engineering will define; it must carry:
- `clipURL: URL`
- `phaseIndex: Int` (1-based)
- `phaseTitle: String`
- `strokeType: StrokeType`
- `score: Double` (0.0–1.0, displayed as 0–100)
- `scoreDimensionLabel: String`
- `observation: String`
- `correction: String`
- `drill: String`
- `highlightJoints: [VNHumanBodyPoseObservation.JointName]`
- `poseFrames: [PoseFrame]`
- `referenceGhost: PoseFrame?` (nil if not shown; must be Option C asset)

---

## 7. Open Questions

These must be answered before Milestone 4 implementation begins:

| # | Question | Owner |
|---|---|---|
| 1 | How many joints does Vision reliably detect on a full-body pickleball shot from a phone camera 10–15 ft away? Affects overlay richness. | CV agent |
| 2 | What frame rate is the slow-motion export? Determines the granularity of "frames" in scoring. | iOS agent |
| 3 | Does Phase 10 (Balance/Reset) have enough stable inter-rep frames to detect reliably, or should it be removed from the default template? | CV agent |
| 4 | Is a 9:16 video crop the right aspect ratio for the evidence frame? The app may be used with landscape video. | iOS agent |
| 5 | Should the reference ghost be rendered for all phases or only when score < 70? | Product |

---

## Related

- `docs/RIGHTS_PLAN.md` — asset rights policy (Option C: pose-only generic exemplar is the safe path)
- `docs/assets/exemplar-rights-register.json` — per-asset rights tracking
- `docs/MVP_PLAN.md` — Milestone 3 (segmentation + export) and Milestone 4 (mechanics comparison)
- `PickleballCoach/Views/ReviewPlaceholderView.swift` — current placeholder this template replaces
