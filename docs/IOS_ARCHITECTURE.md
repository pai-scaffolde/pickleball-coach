# iOS Architecture & QA Path — Pickleball Coach

> SCA-1825 · 2026-06-05

---

## 1. Layer Diagram

```
┌─────────────────────────────────────────────────────┐
│  Presentation (SwiftUI)                             │
│  HomeView · SessionDetailView · AnalysisProgressView│
│  ClipCarouselView · ScorecardView · FeedbackView    │
└─────────────────┬───────────────────────────────────┘
                  │ @StateObject / @EnvironmentObject
┌─────────────────▼───────────────────────────────────┐
│  Domain layer (pure Swift)                          │
│  Session · VideoAsset · PoseFrame · Clip            │
│  MechanicsScore · CoachingReport                   │
└────┬──────────┬──────────┬──────────┬───────────────┘
     │          │          │          │
┌────▼───┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────────────┐
│Capture │ │ Pose   │ │Segment/│ │ Feedback       │
│/Import │ │Analysis│ │Export  │ │ (mock → LLM)   │
│Module  │ │Module  │ │Module  │ │ Module         │
│AVFound │ │Vision  │ │AVFound │ │ Claude API     │
└────────┘ └────────┘ └────────┘ └────────────────┘
     │          │          │          │
┌────▼──────────▼──────────▼──────────▼─────────────┐
│  Persistence                                        │
│  SessionStore (FileManager + JSON)                 │
│  ReferenceLibrary (bundled JSON + clips)           │
└─────────────────────────────────────────────────────┘
```

---

## 2. Module Contracts

### 2.1 Capture / Import

```swift
protocol VideoSource {
    func importVideo() async throws -> VideoAsset
}

struct CameraCapture: VideoSource  // AVCaptureSession, high-fps if available
struct PhotoLibraryImport: VideoSource  // PHPickerViewController
struct BundledSampleImport: VideoSource  // dev/simulator fallback
```

**Key decisions:**
- Request camera + photo-library permissions lazily; surface denial state in UI.
- Write to app-private `Documents/sessions/<uuid>/raw.mov`.
- High-fps capture (`AVCaptureDevice.activeVideoMinFrameDuration`): prefer 60fps, fall back to 30fps.

---

### 2.2 Pose Analysis

```swift
struct PoseFrame: Codable {
    let timestamp: CMTime
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let confidence: Float
}

actor PoseAnalyzer {
    func analyze(videoURL: URL,
                 sampleRate: Int = 15,         // frames per second to sample
                 progressHandler: (Double) -> Void) async throws -> [PoseFrame]
}
```

**Pipeline:**
1. `AVAssetReader` + `AVAssetReaderTrackOutput` → `CMSampleBuffer`.
2. `VNImageRequestHandler` per sampled frame → `VNDetectHumanBodyPoseRequest`.
3. Normalize joint positions to [0,1] relative to bounding box.
4. Skip frames where body pose confidence < 0.5.
5. Persist timeline as `pose_timeline.json` beside the video.

**Optional silhouette pass** (disabled by default, enable via config flag):
- `VNGeneratePersonSegmentationRequest` at reduced resolution.
- Useful for clip thumbnail overlays; not required for scoring.

---

### 2.3 Segmentation & Clip Export

```swift
struct ClipInterval: Codable {
    let index: Int
    let start: CMTime
    let end: CMTime
    let strokeType: StrokeType    // .forehandDrive | .backhandDrive | .serve | .dink | .unknown
    let confidence: Float
}

actor RepSegmenter {
    func segment(frames: [PoseFrame], targetCount: Int = 8) async -> [ClipInterval]
}

actor ClipExporter {
    func export(sourceURL: URL, intervals: [ClipInterval],
                slowMotionFactor: Float = 0.33) async throws -> [URL]
}
```

**Segmentation heuristic:**
1. Compute per-frame motion intensity: Σ Δposition of wrist + shoulder + hip joints.
2. Smooth with a 5-frame rolling average.
3. Find local maxima (swing peaks) above a threshold.
4. Define clip = [peak - 0.5s, peak + 1.0s] clamped to video bounds.
5. Merge overlapping clips; take up to `targetCount` by confidence.

**Export:**
- `AVAssetExportSession` or `AVMutableComposition` with time-scaled segment.
- Output: `clips/<index>_slow.mp4` alongside raw video.

---

### 2.4 Mechanics Comparison

```swift
struct MechanicsScore: Codable {
    let category: MechanicsCategory   // .racketPrep | .contactPoint | .followThrough | .footwork | .balance
    let score: Float                  // 0.0–1.0
    let observation: String
}

struct ReferenceThreshold: Codable {
    let strokeType: StrokeType
    let category: MechanicsCategory
    let featureKey: String
    let idealRange: ClosedRange<Float>
    let description: String
}
```

**Bundled reference:** `Resources/reference_library.json` — hand-authored thresholds for forehand drive + backhand drive at MVP. Self-recorded or generic synthetic exemplar pose data (no unlicensed pro footage per RIGHTS_PLAN.md).

**Feature extraction per clip:**
- Elbow angle at contact, wrist height relative to shoulder, hip rotation delta, knee bend (hip-knee vertical), follow-through arc.

---

### 2.5 Feedback Module

```swift
protocol FeedbackProvider {
    func generate(report: AnalysisReport) async throws -> CoachingReport
}

struct MockFeedbackProvider: FeedbackProvider   // deterministic, no network
struct ClaudeFeedbackProvider: FeedbackProvider // Anthropic SDK, enabled via config
```

**Prompt contract (Claude provider):**
- System: coaching role, sport context, anti-overclaiming constraint.
- User: structured JSON with stroke type, per-category scores, observations, reference deltas.
- Output: `{ strengths: [String], improvements: [String], drill: String }`.
- Model: `claude-haiku-4-5-20251001` for latency; `claude-sonnet-4-6` for quality.

---

## 3. Persistence

```
Documents/
  sessions/
    <uuid>/
      meta.json          # Session struct
      raw.mov            # source video
      pose_timeline.json # [PoseFrame]
      clips/
        0_slow.mp4
        1_slow.mp4
        ...
      analysis.json      # AnalysisReport (clips + scores)
      coaching.json      # CoachingReport
```

`SessionStore` is an `@MainActor ObservableObject` that loads `meta.json` files on launch and exposes `[Session]`.

---

## 4. Configuration Flags

Stored in `Config.plist` (not Info.plist):

| Key | Default | Purpose |
|-----|---------|---------|
| `useLiveLLM` | `false` | Enable Claude API feedback |
| `enableSilhouette` | `false` | Run segmentation mask pass |
| `poseSampleRate` | `15` | Frames/sec sampled for pose |
| `slowMotionFactor` | `0.33` | Export speed (1.0 = real-time) |
| `maxClips` | `8` | Target rep count |

---

## 5. QA Path

### Phase 1: Simulator (no device required)
- `BundledSampleImport` with a bundled 60-sec practice clip.
- Pose pipeline: verify `pose_timeline.json` is written, ≥50% frames have high-confidence joints.
- Segmentation: verify 5-8 `ClipInterval` produced from sample.
- Export: verify `*_slow.mp4` files exist and are playable in-app.
- Mock feedback: deterministic round-trip returns a `CoachingReport`.

**ISC probes:**
1. `grep -r "VNDetectHumanBodyPoseRequest" PickleballCoach/` → non-empty.
2. Open app in simulator, import bundled sample → `AnalysisProgressView` reaches 100%.
3. `ls Documents/sessions/<uuid>/clips/` → ≥5 files.
4. `ReviewPlaceholderView` shows at least 3 mechanics scores.

### Phase 2: Real device (iPhone)
Trigger GStack `/ios-qa` after a build exists on TestFlight or local install.

**Test matrix:**
| Scenario | Expected |
|----------|----------|
| Record live session, 2 min | Session saved, pose extracted |
| Import MP4 from Photos | Session saved, pose extracted |
| Portrait + landscape video | Pose normalized correctly |
| No camera permission | Graceful error state |
| Short clip (<10 sec) | "Too short" message, no crash |
| 240fps slo-mo video | Analysis completes, clips playable |

### Phase 3: Design review
Trigger GStack `/ios-design-review` on a device screenshot set of:
- HomeView
- ImportVideoView
- AnalysisProgressView
- ClipCarouselView + ScorecardView
- FeedbackView

### Phase 4: LLM feedback integration
- Enable `useLiveLLM = true` in Config.plist.
- Verify structured prompt reaches Claude API.
- Verify response populates `CoachingReport`.
- Verify prompt does not include raw video bytes (cost + privacy).

---

## 6. Milestone → Task Mapping

| Milestone | Key tasks |
|-----------|-----------|
| M0 (done) | Skeleton, models, HomeView, ImportVideoView |
| M1 | CameraCapture, BundledSampleImport, SessionStore persistence |
| M2 | PoseAnalyzer, pose_timeline.json, debug overlay |
| M3 | RepSegmenter, ClipExporter, slow-motion playback |
| M4 | Feature extraction, ReferenceLibrary, MechanicsScore UI |
| M5 | MockFeedbackProvider, ClaudeFeedbackProvider, FeedbackView |
| M6 | GStack iOS QA + design review, demo script |

---

## 7. Open Decisions

| # | Question | Default if not decided |
|---|----------|----------------------|
| 1 | Use SwiftData instead of FileManager+JSON? | FileManager+JSON (simpler, no migration) |
| 2 | Pose overlay rendered at analysis or playback? | Playback (lower storage) |
| 3 | Single-model Claude vs. adaptive model selection? | Fixed haiku for MVP |
| 4 | Ship silhouette pass in M2 or defer to M4? | Defer to M4 |
| 5 | On-device CoreML supplement to Vision? | Out of MVP scope |
