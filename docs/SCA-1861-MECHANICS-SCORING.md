# SCA-1861 — Deterministic forehand mechanics scoring + skeleton overlay

Milestone 4-lite. Scores forehand-drive mechanics from a `[PoseFrame]` timeline and
renders the skeleton overlay on the contact key frame (decisions D1, D4 — forehand
only).

## What was built

| Piece | File |
| --- | --- |
| Scoring engine (pure, deterministic) | `PickleballCoach/PickleballCoach/Services/MechanicsScoringEngine.swift` |
| `MechanicsScore` + `keyFrameTimestamp` | `PickleballCoach/PickleballCoach/Models/MechanicsScore.swift` |
| Versioned, cited thresholds | `PickleballCoach/PickleballCoach/Resources/reference_forehand_drive_v0.json` (`mechanicsThresholds`) |
| Scorecard UI (overlay + measured/reference) | `PickleballCoach/PickleballCoach/Views/MechanicsScorecardView.swift` |
| Determinism XCTest | `PickleballCoach/PickleballCoachTests/MechanicsScoringEngineTests.swift` |
| Sudo-free determinism harness + Swift parity | `tools/sca1861-scoring-harness/` |
| Scorecard artifact (evidence) | `docs/artifacts/SCA-1861-mechanics-score-artifact.json` |

## Design — reuse, don't fork (SCA-1824 coordination)

The engine **reuses `ComparisonEngine`** (SCA-1824) for all geometry, feature
extraction, and range/delta scoring. The scorecard **reuses `PoseOverlayView`** for
the skeleton overlay. The thresholds live in the **same** `reference_forehand_drive_v0.json`
ranges both engines read, so comparison and scoring never drift. The only new logic is:

1. **Deterministic key-frame selection** — the contact frame is the body-detected
   frame of **peak right-wrist speed** (wrist displacement between measurable frames,
   torso-normalized) — the textbook proxy for ball contact. Ties resolve to the lowest
   index. `PoseFrame` carries no phase labels (segmentation is a later milestone), so
   contact is detected kinematically; an annotated contact window can override it later.
2. **Reshaping** the contact-phase comparison into a `MechanicsScore` whose observations
   carry **measured vs reference** pairs (never a bare number), e.g.
   `elbow extension: 173° / ideal 150°–175°`.

## Determinism contract

`score(frames:clip:reference:)` on identical `[PoseFrame]` input is **bitwise-equal**:
`id` is derived from `clip.id` (no fresh UUID), no `Date`, no randomness, fixed
key-frame tie-break, fixed `FeatureKey` category order.

## Acceptance status

- ✅ **XCTest deterministic** — `testScoringIsBitwiseDeterministic` encodes two runs and
  asserts byte-equality. Proven headlessly too: `verify_determinism.sh` runs the engine
  twice on the canonical fixture and `cmp`s the output → byte-identical
  (sha256 `8e10139e…`). Runs on every PR via the Linux `determinism` CI job.
- ✅ **Reference thresholds versioned + source cited** — `mechanicsThresholds.version 1.0.0`
  with a per-category `source` citation (USA Pickleball technique guidance; Plagenhoef
  segment proportions).
- ⏳ **Scorecard screenshot** — view is built and wired (`MechanicsScorecardView` +
  `PoseOverlayView`). Capturing the rendered screenshot needs an Xcode/simulator build
  (local Swift toolchain is broken; builds route to CI). The iOS CI job now runs the
  XCTest; the screenshot is the remaining human/visual step.

## Run it

```bash
# Headless determinism proof (no Xcode needed):
bash tools/sca1861-scoring-harness/verify_determinism.sh
# Swift↔Python parity once Xcode is present:
bash tools/sca1861-scoring-harness/verify_swift_parity.sh
```
