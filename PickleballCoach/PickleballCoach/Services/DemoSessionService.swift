import Foundation

// MARK: - SCA-1889 — Rights-clean in-app demo / sample experience
//
// Builds a fully pre-populated "sample" session from the bundled GENERIC pose
// exemplar (exemplar-generic-pose-forehand-v0 — usage_scope=bundled-app /
// cleared-public, a synthetic skeleton depicting no identifiable person). No
// third-party footage is involved: the demo's "you" pose timeline is synthesized
// from the idealized skeleton itself, so RightsGate passes and a first-launch
// user can immediately explore the mechanics scorecard and the side-by-side
// comparison UI.
//
// The session is flagged `isDemo` so the UI labels it a sample; it is removable
// like any other session (swipe-to-delete in the Sessions list).
enum DemoSessionService {

    /// Stable id so "Try the demo" is idempotent — re-tapping opens/refreshes the
    /// existing demo rather than stacking duplicates.
    static let demoSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000001889")!

    /// Stable clip id keeps the derived MechanicsScore id deterministic
    /// (MechanicsScoringEngine derives the score id from the clip id).
    private static let demoClipID = UUID(uuidString: "00000000-0000-0000-0000-000000018890")!

    static let title = "Demo · Forehand (Sample)"

    private static let exemplarResource = "reference_forehand_drive_v0"

    enum DemoError: LocalizedError {
        case exemplarUnavailable(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .exemplarUnavailable(let e):
                return "Could not build the demo from the bundled exemplar: \(e.localizedDescription)"
            }
        }
    }

    /// Builds (or rebuilds) the demo session: loads the bundled exemplar through
    /// RightsGate, synthesizes a pose timeline from it, writes that timeline to
    /// Documents as `pose-timeline-<id>.json` (where ComparisonContainerView looks
    /// for analyzed pose data), scores it, and returns a `.ready` Session.
    ///
    /// Throws `DemoError.exemplarUnavailable` if the bundled exemplar is missing
    /// or fails the rights gate — the only failure mode worth surfacing.
    static func makeDemoSession() throws -> Session {
        let exemplar: ReferenceExemplar
        do {
            // RightsGate.check(requiredScope: .bundledApp) runs inside load().
            exemplar = try ReferenceExemplar.load(named: exemplarResource)
        } catch {
            throw DemoError.exemplarUnavailable(underlying: error)
        }

        let frames = timeline(from: exemplar)
        writeTimeline(frames, sessionID: demoSessionID)

        let clip = ClipInterval(
            id: demoClipID,
            startTime: frames.first?.timestamp ?? 0,
            endTime: frames.last?.timestamp ?? 0,
            strokeType: exemplar.strokeType,
            confidence: 1.0
        )
        // Score the CONTACT key frame specifically. The engine selects its key
        // frame by peak wrist DISPLACEMENT — a good proxy on dense real video, but
        // on one-frame-per-phase synthetic data the recovery swing-back registers
        // the largest displacement and would mis-score the sample. Feeding the
        // engine just the approach→contact pair forces the selector onto the
        // contact pose. keyFrameTimestamp stays aligned with the contact frame in
        // the full on-disk timeline, so the scorecard's skeleton lookup still
        // resolves the contact pose, and the side-by-side comparison still reads
        // the complete 7-phase timeline.
        let scoringFrames = contactApproach(in: frames, exemplar: exemplar)
        let score = MechanicsScoringEngine().score(frames: scoringFrames, clip: clip, reference: exemplar)

        return Session(
            id: demoSessionID,
            title: title,
            status: .ready,
            videoFileName: nil,
            durationSeconds: frames.last?.timestamp,
            poseTimelineFileName: timelineFileName(sessionID: demoSessionID),
            clipIntervals: [clip],
            mechanicsScores: [score],
            isDemo: true
        )
    }

    // MARK: - Synthetic timeline

    /// One frame per canonical phase, in order, at evenly spaced timestamps, each
    /// using that phase's idealized exemplar skeleton. The wrist sweeps forward
    /// through the swing so the scoring engine's peak-wrist-speed key frame lands
    /// on the contact arc; time-window segmentation re-tags the frames back to
    /// their phases for the side-by-side "You" panel (identity mapping, since the
    /// phase count matches CanonicalPhase.allCases).
    private static func timeline(from exemplar: ReferenceExemplar) -> [PoseFrame] {
        let dt = 0.3
        return exemplar.phases.enumerated().map { idx, phase in
            PoseFrame(timestamp: Double(idx) * dt, joints: phase.pose, bodyDetected: true)
        }
    }

    /// The approach→contact frame pair (the frame before contact, then contact),
    /// so MechanicsScoringEngine's peak-wrist-speed selector lands on the contact
    /// pose. Falls back to the full timeline if the contact phase isn't present.
    private static func contactApproach(in frames: [PoseFrame], exemplar: ReferenceExemplar) -> [PoseFrame] {
        guard let idx = exemplar.phases.firstIndex(where: { $0.phase == MechanicsScoringEngine.scoredPhase }),
              idx > 0, idx < frames.count else {
            return frames
        }
        return Array(frames[(idx - 1)...idx])
    }

    private static func timelineFileName(sessionID: UUID) -> String {
        "pose-timeline-\(sessionID.uuidString).json"
    }

    private static func writeTimeline(_ frames: [PoseFrame], sessionID: UUID) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(frames) else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(timelineFileName(sessionID: sessionID))
        try? data.write(to: url, options: .atomic)
    }
}
