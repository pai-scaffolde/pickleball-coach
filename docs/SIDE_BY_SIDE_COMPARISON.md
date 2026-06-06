# Side-by-Side Reference Comparison — Safe Pattern (No Ghost Overlay)

Status: **prototype** · Owner: CV/Product · Issue: SCA-1824 · Last updated: 2026-06-05

This document specifies the comparison pattern Pickleball Coach uses to grade a user's
stroke against a reference, and the prototype that proves it. It deliberately **avoids the
pro silhouette / ghost overlay** pattern (a reference skeleton superimposed on the user's
video) until rights *and* alignment quality are solved (`docs/RIGHTS_PLAN.md`, MVP_PLAN
"out of scope: bundled unlicensed pro footage").

---

## 1. Why not a ghost overlay (yet)

A ghost overlay superimposes a reference skeleton/silhouette over the user's body. It is
attractive but carries two unsolved problems for the MVP:

1. **Rights.** A recognizable pro silhouette or pose track derived from a named athlete's
   footage is restricted (`RIGHTS_PLAN.md` §3). Until a `cleared-public` register row
   exists, no such overlay may ship.
2. **Alignment quality.** Overlaying two bodies requires accurate per-frame spatial
   registration (scale, translation, rotation, limb correspondence) and temporal
   registration (matching swing phase frame-for-frame). Small errors read as "you're
   wrong" when the real cause is misalignment. This is the classic *raw pixel alignment*
   trap the issue calls out.

The safe pattern sidesteps both: **two separate panels** (the user and a generic exemplar)
plus a **range/delta readout** computed from scale-invariant features.

---

## 2. The pattern

```
┌───────────────────────┬───────────────────────┐
│   You                 │   Reference (generic) │   ← two independent panels,
│   [user skeleton]     │   [exemplar skeleton] │     each body-scale normalized,
│                       │                       │     NOT superimposed
├───────────────────────┴───────────────────────┤
│  Phase match: 64        Elbow angle  144 (ideal 150–175)  below │
│                         Wrist height -0.71 (ideal -0.45–0.1) below │
└────────────────────────────────────────────────┘
```

Three normalization + comparison rules, matching the issue's MVP comparison list:

1. **User skeleton overlay** — on the *user's own* video only (the left panel / their clip).
   No third-party body is drawn on top of it.
2. **Reference skeleton, side-by-side** — drawn in its own panel from a **cleared asset**
   (Option C pose-only generic exemplar). Never overlaid on the user.
3. **Normalize by body scale and phase timing**
   - *Body scale*: every skeleton is translated to a root (hip midpoint) and scaled by
     **torso length** (shoulder-midpoint → hip-midpoint distance). A tall user filmed
     close and the exemplar filmed far become directly comparable.
   - *Phase timing*: the two clips are aligned by **canonical phase**
     (ready → load → takeback → turn → contact → follow-through → recovery), not by frame
     index. The clips need not have the same duration or frame rate.
4. **Compare ranges and deltas, not raw pixel alignment** — comparison runs on
   scale-invariant **features** (joint angles, torso-normalized ratios) against generic
   ideal **ranges**, reporting a signed **delta** when outside the band. The engine never
   compares pixel positions between the two skeletons.

---

## 3. Features and ranges

Per phase, the engine measures the user's mean of each available feature (low-confidence
joints skipped, threshold 0.5) and compares to the exemplar's generic ideal range:

| Feature key | Meaning | Scale-invariant via |
|---|---|---|
| `right_elbow_angle_deg` | shoulder–elbow–wrist interior angle | angle (unitless) |
| `right_knee_angle_deg` | hip–knee–ankle interior angle | angle |
| `hip_shoulder_separation_deg` | shoulder-line vs hip-line orientation gap | angle |
| `wrist_height_rel_torso` | signed wrist-above-shoulder height | ÷ torso length |
| `arm_extension_rel_torso` | shoulder→wrist distance | ÷ torso length |

`delta = userValue − nearest range bound` (0 when within). `featureScore = max(0, 1 −
|delta| / rangeWidth)`. Phase score = mean of available feature scores ×100. Overall =
mean of measured phase scores.

The ideal ranges are **hand-authored generic bands** (`reference_forehand_drive_v0.json`),
not values lifted from a specific pro's footage. They encode "a compact takeback keeps the
elbow 80–120°", not "match athlete X frame 47".

---

## 4. Prototype components

| Component | Path | Role |
|---|---|---|
| Comparison engine | `PickleballCoach/Services/ComparisonEngine.swift` | Pure Swift. Phase mapping, body-scale normalization, feature extraction, range/delta scoring. |
| Reference model | `PickleballCoach/Models/ReferenceExemplar.swift` | Codable for the generic exemplar (pose track + ranges + rights metadata). |
| Reference asset | `PickleballCoach/Resources/reference_forehand_drive_v0.json` | Option C generic exemplar, 7 phases. Register id `exemplar-generic-pose-forehand-v0` (`cleared-public`, `bundled-app`). |
| Reference asset (backhand) | `PickleballCoach/Resources/reference_backhand_drive_v0.json` | Option C generic exemplar, 7 phases. Register id `exemplar-generic-pose-backhand-v0` (`cleared-public`, `bundled-app`). Added SCA-1864 (Milestone 4 — second stroke type). |
| Side-by-side view | `PickleballCoach/Views/SideBySideComparisonView.swift` | SwiftUI two-panel skeletons + delta readout. No overlay. |
| Run harness | `tools/sca1824-comparison-harness/main.swift` | Swift CLI that runs the engine over a pose artifact + reference and writes the report. |
| Reference port | `tools/sca1824-comparison-harness/reference_port.py` | Identical-behaviour Python port to regenerate the artifact where the local Swift toolchain is broken (see §6). |
| Output artifact | `docs/artifacts/SCA-1824-comparison-artifact.json` | The comparison report (evidence). |

---

## 5. Prototype run (evidence)

Input: the SCA-1819 forehand-drive pose artifact (user) vs the generic exemplar
(reference). Result (`docs/artifacts/SCA-1824-comparison-artifact.json`):

```
overall: 48.3/100 across 7 measured phases   (SCA-1864 recalibrated; was 41.8)
  ready           40.3     takeback   50.0     contact         63.5
  load            28.5     turn       88.9     follow_through    2.6
  recovery        64.6
method=range_delta_on_scale_normalized_features  ghostOverlay=false  alignment=phase_keyed_not_pixel
```

> **SCA-1864 change.** `turn` no longer false-zeros (0.0 → 88.9): the phase now scores
> on 2D-observable features (elbow angle, arm extension) and the unreliable
> `hip_shoulder_separation_deg` is down-weighted (×0.25). `ready`/`recovery`/`load` drop
> slightly because the previously full-weight separation feature — which read a *false*
> ~0° "in range" — no longer inflates them. See §6.

The deltas are explainable, e.g. at **contact** the user's elbow is 144° vs ideal 150–175°
(delta −5.5°, slightly under-extended) and the wrist sits low (−0.71 vs −0.45–0.10). These
are coachable observations, exactly the inputs the feedback module (SCA-1823) consumes.

---

## 6. Known limitations (honest)

- **2D rotation under-detection — mitigated in SCA-1864.** `hip_shoulder_separation_deg`
  measured ~0.4° (ideal 30–45°) → phase `turn` scored a *false* 0. Root cause is deeper
  than "side-on": a 2D **line-angle** between two near-horizontal segments cannot observe
  **axial** torso rotation (the hip/shoulder X-factor) from a single camera on a side-on
  *or* a frontal view. Mitigation shipped: (1) the feature is **down-weighted ×0.25** so it
  cannot dominate a phase score; (2) it is **fully excluded** (`low_view_confidence`) on
  true side-on captures (shoulder-width/torso < 0.30), where even tilt is unreadable;
  (3) phases that depended on it (e.g. `turn`) now also carry 2D-observable features
  (elbow angle, arm extension) so they score on real signal. **True** axial rotation still
  needs depth/3D pose (VNHumanBodyPose3D / ARKit) — tracked as the SCA-1864 3D follow-up
  child. The mitigation is verified in both the down-weight path (frontal: `turn` 0.0 →
  88.9) and the exclude path (synthetic side-on: separation → `low_view_confidence`).
- **Single representative frame for rendering.** The side-by-side panels draw one
  representative pose per phase; scoring still uses all in-phase frames.
- **Generic ranges are v0.** The bands are reasonable but uncalibrated; tighten with
  Option A self-recorded footage before any quality claims. No medical/biomechanical
  certainty is implied (`AGENTS.md`).
- **Local Swift build blocked.** This host's CommandLineTools install has a duplicate
  `SwiftBridging` modulemap (`/Library/Developer/CommandLineTools/usr/include/swift/`),
  so `swiftc` fails on any system-module import. The Swift sources are the product code
  (compiled via Xcode/CI); the Python reference port regenerates the artifact locally with
  identical geometry/scoring. Tracked as a follow-up.

---

## 7. Rights posture

- Reference is **Option C** (pose-only generic exemplar). No named athlete, footage, or
  pro-derived pose track is involved → rights-safe by construction.
- The view label is literally "Reference (generic)" and the UI states the reference is not
  a named athlete and that comparison is range/delta, not overlay.
- Register row `exemplar-generic-pose-forehand-v0` is `cleared-public` / `bundled-app`
  with `asset_path` set. **No row, no ship** holds.

---

## Related

- `docs/RIGHTS_PLAN.md` — Option C is the safe reference path; ghost overlay deferred.
- `docs/COACHING_CLIP_TEMPLATE.md` — §3 "Reference ghost (optional, Milestone 4+)" is the
  deferred overlay this pattern replaces for the MVP.
- `docs/IOS_ARCHITECTURE.md` — §2.4 Mechanics Comparison module.
- `docs/artifacts/SCA-1819-pose-spike-artifact.json` — the user-side input.
