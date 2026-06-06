import XCTest
import AVFoundation
@testable import PickleballCoach

// SCA-1889 — Rights-clean in-app demo experience.
// SCA-1907 — Demo session now carries a runtime-rendered synthetic video clip.
//
// Proves the demo session is buildable, rights-clean (RightsGate passes for the
// bundled generic exemplar and would REJECT the internal-dev YouTube clips),
// scorable (renders a mechanics scorecard), and deterministic.
//
// The video is a skeleton animation rendered at runtime from the bundled generic
// pose exemplar (usage_scope=bundled-app/cleared-public). No third-party footage.
final class DemoSessionServiceTests: XCTestCase {

    // MARK: - Builds and is flagged a sample

    func testMakeDemoSessionSucceedsAndIsFlaggedDemo() throws {
        let session = try DemoSessionService.makeDemoSession()
        XCTAssertTrue(session.isDemo, "demo session must be flagged so the UI can label it a sample")
        XCTAssertEqual(session.status, .ready, "demo ships pre-analyzed")
        // SCA-1907: demo now references a runtime-rendered rights-clean synthetic clip.
        let videoFileName = try XCTUnwrap(session.videoFileName,
            "demo must carry a videoFileName pointing to the runtime-rendered skeleton animation")
        XCTAssertFalse(videoFileName.isEmpty)
        // The file must exist on disk after makeDemoSession() returns.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoURL = docs.appendingPathComponent(videoFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path),
            "rendered demo clip must exist in Documents at \(videoURL.path)")
        // session.videoURL() must resolve (file-existence check inside).
        XCTAssertNotNil(session.videoURL(),
            "session.videoURL() must resolve to the rendered clip URL")
        XCTAssertFalse(session.title.isEmpty)
    }

    // MARK: - Rendered clip is playable

    func testDemoVideoIsPlayable() throws {
        let session = try DemoSessionService.makeDemoSession()
        let url = try XCTUnwrap(session.videoURL(),
            "demo session must have a resolvable video URL")
        let asset = AVURLAsset(url: url)
        // Load duration synchronously via semaphore for test convenience.
        let sema = DispatchSemaphore(value: 0)
        var duration: CMTime = .zero
        Task {
            duration = (try? await asset.load(.duration)) ?? .zero
            sema.signal()
        }
        sema.wait()
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0,
            "AVURLAsset duration must be > 0 for the rendered demo clip")
    }

    // MARK: - Renders the mechanics scorecard (contact key frame)

    func testDemoProducesContactScorecard() throws {
        let session = try DemoSessionService.makeDemoSession()
        let score = try XCTUnwrap(session.mechanicsScores.first,
                                  "demo must carry a mechanics score so the scorecard renders")
        XCTAssertEqual(score.strokeType, "forehand_drive")
        XCTAssertGreaterThanOrEqual(score.keyFrameTimestamp, 0,
                                    "a measurable contact key frame must be selected")
        // Contact frame is index 4 in the 7-phase timeline at dt=0.3s → 1.2s.
        XCTAssertEqual(score.keyFrameTimestamp, 1.2, accuracy: 0.001,
                       "the scored key frame must be the contact pose, not the recovery swing-back")
        XCTAssertFalse(score.scores.isEmpty, "scorecard needs at least one category")
        XCTAssertTrue((3...5).contains(score.scores.count),
                      "contact phase carries 3–5 categories")
        XCTAssertEqual(score.observations.count, score.scores.count)
    }

    // MARK: - Rights-clean: gate passes for the bundled exemplar, rejects the clips

    func testRightsGatePassesForBundledExemplarAndRejectsInternalClips() throws {
        // The asset the demo is built from is cleared for bundling.
        XCTAssertNoThrow(
            try RightsGate.check(assetId: "exemplar-generic-pose-forehand-v0",
                                 requiredScope: .bundledApp),
            "the generic pose exemplar must pass the bundled-app rights gate")

        // The Navratil forehand clip was promoted internal-dev → bundled-app per
        // the board decision on SCA-1906 (2026-06-06: "These videos are being used
        // as concept examples. Stop blocking their use."). It now clears the gate so
        // it can be bundled as the staged real-pipeline sample (SCA-1909).
        XCTAssertNoThrow(
            try RightsGate.check(assetId: "yt-forehand-drive-navratil-v0",
                                 requiredScope: .bundledApp),
            "the Navratil concept-example clip must pass the bundled-app gate (SCA-1906 board decision)")

        // Negative control: an asset still scoped internal-dev must be REJECTED for
        // bundling — proves the gate still discriminates and nothing un-cleared slips
        // into the binary. The Selkirk backhand clip remains internal-dev only.
        XCTAssertThrowsError(
            try RightsGate.check(assetId: "yt-backhand-drive-selkirk-v0",
                                 requiredScope: .bundledApp),
            "internal-dev footage must never clear the bundled-app gate") { error in
            guard case RightsGate.GateError.insufficientScope = error else {
                return XCTFail("expected insufficientScope, got \(error)")
            }
        }
    }

    // MARK: - Writes a decodable pose timeline the comparison/scorecard read

    func testDemoWritesSevenPhasePoseTimeline() throws {
        let session = try DemoSessionService.makeDemoSession()
        let fileName = try XCTUnwrap(session.poseTimelineFileName)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(fileName)
        let data = try Data(contentsOf: url)
        let frames = try JSONDecoder().decode([PoseFrame].self, from: data)
        XCTAssertEqual(frames.count, 7, "timeline spans the 7 canonical phases")
        XCTAssertTrue(frames.allSatisfy { $0.bodyDetected })
    }

    // MARK: - Determinism

    func testDemoIsDeterministic() throws {
        let a = try DemoSessionService.makeDemoSession()
        let b = try DemoSessionService.makeDemoSession()
        XCTAssertEqual(a.id, b.id, "demo id is stable so 'Try the demo' is idempotent")
        XCTAssertEqual(a.mechanicsScores.first?.id, b.mechanicsScores.first?.id)
        XCTAssertEqual(a.mechanicsScores.first?.scores, b.mechanicsScores.first?.scores)
    }
}
