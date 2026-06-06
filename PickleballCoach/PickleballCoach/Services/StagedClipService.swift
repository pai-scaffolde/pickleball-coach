import Foundation

// MARK: - SCA-1909 — Staged REAL-pipeline sample session
//
// The synthetic demo (DemoSessionService) is pre-scored and bypasses the real
// Vision pipeline, so a tester sees the scorecard UI but never exercises
// import → pose-extraction → quality-gate → scoring on actual footage. This
// service stages a second sample session that points at a bundled REAL clip in
// the `.imported` state, so tapping "Analyze" runs the genuine
// PoseExtractionService → CaptureQualityGate → MechanicsScoringEngine path.
//
// Rights: the bundled clip is `yt-forehand-drive-navratil-v0` — a public
// instructional video used as a concept example. The board ruled on SCA-1906
// (2026-06-06) that the internal-dev rights constraint was too tight for a demo
// app ("These videos are being used as concept examples. Stop blocking their
// use."), so the asset was promoted to usage_scope=bundled-app in
// exemplar-rights-register.json. RightsGate.check(.bundledApp) is enforced here
// at seed time, so the session is never staged unless the register permits it.
enum StagedClipService {

    /// Stable id so re-seeding is idempotent (no stacked duplicates).
    static let stagedSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000001909")!

    static let title = "Sample · Forehand Drive (Real Clip)"

    /// Rights-register asset id and the bundled resource name (sans extension).
    static let assetID = "yt-forehand-drive-navratil-v0"
    private static let bundledResource = "yt-forehand-drive-navratil-v0"
    private static let bundledExtension = "mp4"

    /// Real duration of the bundled clip (first 90s segment). The quality gate
    /// evaluates on extracted frames, not this value; it is used for display.
    private static let durationSeconds: Double = 90

    enum StagedClipError: LocalizedError {
        case rightsNotCleared(underlying: Error)
        case bundledClipMissing
        case copyFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .rightsNotCleared(let e):
                return "Staged clip failed the rights gate: \(e.localizedDescription)"
            case .bundledClipMissing:
                return "Bundled sample clip '\(bundledResource).\(bundledExtension)' is missing from the app bundle."
            case .copyFailed(let e):
                return "Could not stage the sample clip into Documents: \(e.localizedDescription)"
            }
        }
    }

    /// Builds the staged `.imported` session: enforces RightsGate for bundled-app
    /// use, copies the bundled clip into Documents (where Session.videoURL()
    /// resolves it), and returns a session whose "Analyze" action runs the real
    /// pipeline. Idempotent: the Documents copy is reused if already present.
    static func makeStagedSession() throws -> Session {
        // Hard rights gate — never stage a clip the register doesn't clear for bundling.
        do {
            try RightsGate.check(assetId: assetID, requiredScope: .bundledApp)
        } catch {
            throw StagedClipError.rightsNotCleared(underlying: error)
        }

        guard let bundledURL = Bundle.main.url(forResource: bundledResource,
                                               withExtension: bundledExtension) else {
            throw StagedClipError.bundledClipMissing
        }

        let videoFileName = stagedVideoFileName(sessionID: stagedSessionID)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docs.appendingPathComponent(videoFileName)

        if !FileManager.default.fileExists(atPath: destURL.path) {
            do {
                try FileManager.default.copyItem(at: bundledURL, to: destURL)
            } catch {
                throw StagedClipError.copyFailed(underlying: error)
            }
        }

        // NOT isDemo: unlike the synthetic DemoSessionService (pre-scored, no real
        // video), this is a genuine `.imported` session backed by real footage. It
        // must show the "Analyze" action so tapping it runs the real
        // PoseExtractionService → CaptureQualityGate → MechanicsScoringEngine path
        // — the whole point of the staged clip. The title ("…Real Clip") labels it
        // as a sample; the demo-only banner ("idealized forehand, not your own
        // video") would be inaccurate here.
        return Session(
            id: stagedSessionID,
            title: title,
            status: .imported,
            videoFileName: videoFileName,
            durationSeconds: durationSeconds,
            isDemo: false
        )
    }

    private static func stagedVideoFileName(sessionID: UUID) -> String {
        "staged-clip-\(sessionID.uuidString).mp4"
    }
}
