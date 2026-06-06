# Pickleball Coach MVP Plan

## Goal

Build a pragmatic iOS MVP that records or imports a pickleball practice video, extracts pose/key-frame data, segments the session into 8-10 short slow-motion clips, compares each clip against a small reference mechanics library, and generates concise coaching feedback.

This is not a full coaching platform. The MVP proves the loop:

1. Capture or import practice video.
2. Detect pose and segment reps.
3. Generate slow-motion clips.
4. Score basic mechanics.
5. Produce LLM coaching feedback grounded in computed metrics.
6. Present results in a simple iOS review UI.

## MVP scope

### In scope

- Native iOS prototype.
- iPhone-oriented capture using AVFoundation.
- Video import fallback for simulator/development.
- Pose extraction using Apple Vision first.
- Single-player practice analysis.
- 2-3 supported stroke types for MVP: forehand drive, backhand drive, serve or dink.
- Automatic or semi-automatic segmentation into 8-10 clips.
- Basic mechanics scoring from pose-derived features.
- Small bundled reference library with JSON pose metrics and short annotated example clips. All reference assets must be rights-cleared per `docs/RIGHTS_PLAN.md` (use pose-only generic exemplars or self-recorded/licensed footage; no unlicensed pro footage).
- LLM-generated feedback from structured analysis data, not raw video.
- Simple result screen with clips, scores, and coaching notes.

### Out of scope

- Real-time on-court coaching.
- Multi-player tracking.
- Ball tracking as a hard requirement.
- Production cloud sync/accounts/payments.
- App Store polish.
- Medical or professional biomechanics claims.
- Bundled unlicensed pro footage.

## Architecture

### iOS app stack

- Swift
- SwiftUI
- AVFoundation
- Vision
- AVKit
- PhotosUI
- Codable JSON models
- Mock feedback provider first, optional real LLM provider later

### Modules

1. Capture/import module
   - Record high-frame-rate video where supported.
   - Import local sample video for simulator/development.
   - Persist video as a practice session.

2. Pose analysis module
   - Sample video frames.
   - Run Vision body pose detection.
   - Normalize keypoints.
   - Store frame-level pose timeline JSON.

3. Segmentation module
   - Detect candidate reps from motion intensity and wrist/shoulder/hip movement.
   - Produce 8-10 clip intervals.
   - Fall back to manual/low-confidence messaging if needed.

4. Clip generation module
   - Use AVFoundation export/composition APIs.
   - Export slow-motion review clips.

5. Mechanics comparison module
   - Convert pose tracks into simple features.
   - Compare against bundled reference thresholds.
   - Produce deterministic scores and observations.

6. Feedback module
   - Build a structured prompt from stroke type, scores, observations, reference deltas, and clip timestamps.
   - Generate concise coaching feedback.
   - Mock provider first; real LLM provider behind config flag.

7. Review UI
   - Session list.
   - Analysis progress.
   - Clip list/carousel.
   - Per-clip scorecard.
   - Coaching summary.

## Scaffolde operating model

This app is separate from Scaffolde, but Scaffolde is the build substrate.

Use:

- Paperclip for backlog, issue hierarchy, and acceptance evidence.
- Hermes as orchestrator and delegation surface.
- GStack iOS skills for live-device QA and iOS design review once app exists.
- Scaffolde skills/agents for planning, review, QA, debugging, and remediation.

Suggested agent lanes:

- Planner/Product agent: keeps scope constrained and issues clean.
- iOS agent: SwiftUI, AVFoundation, Vision implementation.
- Computer Vision agent: pose sampling, normalization, segmentation heuristics.
- LLM/Prompt agent: feedback schema and prompt contract.
- QA agent: sample-video test matrix and device/simulator verification.
- Reviewer agent: PR/stack review and regression checks.
- Platform remediation agent: fixes Hermes/Scaffolde capability friction in canonical Scaffolde when needed.

## Milestones

### Milestone 0: Project setup and MVP definition

Outcome: buildable iOS app skeleton with clear architecture and sample-data path.

Deliverables:

- Xcode project or Swift app scaffold.
- Basic SwiftUI navigation.
- Session model.
- Placeholder review screen.
- Paperclip epic and implementation tasks.

Acceptance:

- App builds locally.
- App launches to a home screen.
- User can choose Record Session or Import Video.
- MVP scope and non-goals are documented.

### Milestone 1: Video capture and import

Outcome: user can capture or import practice video and persist it as an analyzable session.

Acceptance:

- On device, user can record and save a session video.
- In simulator/dev mode, user can import an existing video.
- Session detail can play the video.
- Permission denial is handled gracefully.

### Milestone 2: Pose extraction pipeline

Outcome: app extracts pose data from sampled video frames.

Acceptance:

- Given a sample video, app produces pose data for sampled frames.
- Low-confidence frames are skipped or marked.
- Pose timeline includes timestamps and normalized joints.
- Developer can inspect pose output in logs or UI.

### Milestone 3: Rep segmentation and slow-motion clip export

Outcome: app identifies candidate reps and exports slow-motion review clips.

Acceptance:

- Given a 1-3 minute sample video, system proposes up to 8-10 clips.
- Each clip has start/end timestamp and confidence.
- Exported clips play inside the app.
- Low-confidence or insufficient clips are reported clearly.

### Milestone 4: Mechanics comparison

Outcome: each clip receives deterministic mechanics observations and a simple score.

Acceptance:

- At least two stroke types have reference definitions.
- Each clip gets scores for 3-5 mechanics categories.
- Scores are reproducible from the same pose data.
- UI displays score, strengths, and improvement areas per clip.

### Milestone 5: LLM coaching feedback

Outcome: app generates concise coaching feedback from structured analysis data.

Acceptance:

- Feedback is generated from scores/observations, not raw video alone.
- Feedback includes strengths, improvements, and one next-practice drill.
- Mock provider works without network/API keys.
- Real provider can be enabled later without blocking MVP demo.
- Prompt avoids medical certainty and overclaiming.

### Milestone 6: MVP demo hardening

Outcome: end-to-end demo is reliable enough to show.

Acceptance:

- Import sample video → analyze → clips → scores → feedback works repeatedly.
- Known limitations are documented.
- Demo script exists.
- No obvious crashes on missing permissions, empty analysis, or export failure.

## First 10 build tasks

1. Create MVP iOS app skeleton.
2. Define core domain models.
3. Implement local session storage.
4. Add video import flow.
5. Add camera capture flow.
6. Build pose extraction service.
7. Add pose debug viewer.
8. Implement rep segmentation heuristic.
9. Export slow-motion clips.
10. Implement mechanics scoring v0.

## Overall acceptance criteria

The MVP is accepted when:

- A user can import or record a pickleball practice video.
- The app extracts timestamped pose data from the video.
- The app creates candidate slow-motion clips from a repeatable sample video.
- The app compares pose-derived mechanics to bundled references.
- The app generates coaching feedback from structured analysis.
- The app displays clips, scores, and feedback.
- The full flow works on at least one repeatable sample video.
- Limitations and demo instructions are documented.
- All MVP tasks are tracked in Paperclip with acceptance evidence.
- No production-only infrastructure is required to run the demo.

## Immediate next decision

Start with Milestone 0 and 1 in one branch/stack:

- SwiftUI app skeleton.
- Import video path.
- Session model/storage.
- Placeholder review flow.

This unblocks simulator development before camera/device-specific work.
