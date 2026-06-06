# Demo Path — Milestone 0-1

## Prerequisites

- Xcode 15+ installed
- iOS Simulator or iPhone running iOS 17+

## Opening the project

```bash
open /Users/gary/Projects/pickleball-coach/PickleballCoach/PickleballCoach.xcodeproj
```

Set your development team in Xcode → Targets → PickleballCoach → Signing & Capabilities → Team.

## Simulator demo (no device required)

1. Select any iPhone 15 simulator target in Xcode.
2. Build and run (`⌘R`). App launches to the session list with an empty state.
3. Tap **+** in the top-right corner. The photo picker appears.
4. In the simulator, the photo library is pre-populated with sample videos. Select one.
5. The app copies the video to its Documents directory and creates a session.
6. The session appears in the list with an **Imported** badge.
7. Tap the session row to open **Session Detail**.
8. The video player loads and plays the selected clip inline.
9. Tap the session title to rename it inline.
10. Force-quit and reopen the app — the session and video persist.

## Device demo

Same as simulator, but use a video from your Camera Roll. The app requests photo library access on first import attempt. Denying access shows an error alert; it does not crash.

## Navigation map

```
HomeView
├── + → ImportVideoView  (PhotosUI picker → copies video → new Session)
└── Session row → SessionDetailView
    ├── Analyze button → AnalysisProgressView  (placeholder, Milestone 2)
    └── Review button (enabled when status = ready) → ReviewPlaceholderView  (placeholder, Milestones 4-5)
```

## Known limitations (Milestone 0-1 scope)

- Analysis, segmentation, scoring, and coaching feedback are not yet implemented (Milestones 2-5).
- Camera capture is not yet wired (Milestone 1 follow-up; import path is the primary demo path).
- The Review button remains disabled until a session reaches `ready` status, which requires the Milestone 2 pipeline.
- Slow-motion clip export requires Milestone 3.
