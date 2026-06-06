# SCA-1870 — Gate 1: Capture success rate ≥ 80% by second try

Beta gate that decides whether capture guidance is good enough to ship: a new
user should get an analyzable clip **within two tries** at least **80%** of the
time.

## Instrumentation (shipped)

1. **`Session.captureAttemptCount: Int`** (default `1`) —
   `PickleballCoach/Models/Session.swift`. Decodes legacy (pre-SCA-1870)
   sessions to `1` via `decodeIfPresent`, so no existing session store is
   invalidated.
2. **Increment on re-import** — `SessionStore.reimport(sessionID:videoFileName:durationSeconds:)`
   calls `Session.registerReimportAttempt()`, swaps in the new clip, and resets
   the session to `.imported` so it re-runs the quality gate. The count is
   frozen once an analysis is accepted (the session becomes `.ready`).
   - User entry point: the "Record a new clip" button on the quality-rejection
     screen (`AnalysisProgressView`), which presents
     `ImportVideoView(reimportSessionID:)`.
3. **Analytics log** — `CaptureAnalytics`
   (`PickleballCoach/Services/CaptureAnalytics.swift`) appends one event per
   gate evaluation:
   ```json
   { "sessionId": "<uuid>", "captureAttemptCount": <int>, "accepted": <bool>, "timestamp": "<iso8601>" }
   ```
   Events are written to `capture-analytics.json` in the app's Documents
   directory (no external SDK). `AnalysisProgressView.runAnalysis()` records the
   event immediately after `CaptureQualityGate.evaluate(...)`, with
   `accepted = gate.passed`.

## Measurement protocol

- Track the **first 30 beta sessions** that reach acceptance.
- For each accepted session, the `captureAttemptCount` on its **first accepted
  event** is its attempts-to-acceptance.
- **Gate passes** when ≥ 24 / 30 (80%) reached acceptance within **2** attempts.

`CaptureAnalytics.gateSummary(threshold:requiredSessions:maxAttempts:)` computes
the verdict directly from the recorded events:

| Field | Meaning |
| --- | --- |
| `acceptedSessions` | distinct sessions that ever reached acceptance |
| `acceptedWithinTwoAttempts` | of those, how many on attempt 1 or 2 |
| `successRate` | `acceptedWithinTwoAttempts / acceptedSessions` |
| `hasEnoughData` | `acceptedSessions >= 30` |
| `passes` | `hasEnoughData && successRate >= 0.80` |

Defaults: `threshold = 0.80`, `requiredSessions = 30`, `maxAttempts = 2`.

### Reading the result

Pull `capture-analytics.json` from a beta device's container (or call
`CaptureAnalytics.shared.gateSummary()` from a debug surface) once ≥ 30 sessions
have been accepted. `passes == true` clears Gate 1.

## Fail action

If the gate does not pass, improve capture guidance before re-measuring:
- Pre-import framing checklist.
- Real-time distance/angle overlay during capture.

## Verification

- Foundation logic (model default, legacy decode, round-trip, increment,
  analytics record/read, gate verdict at the 80% boundary) verified by
  compiling the model + service slice with the Xcode toolchain `swiftc` and
  running assertions — all pass.
- Unit tests: `PickleballCoachTests/CaptureAnalyticsTests.swift` (8 cases),
  registered in the test target. Full `xcodebuild test` runs in CI (local
  `xcodebuild` requires `xcode-select` + license).

Spec: SCA-1826 Gates Spec.
