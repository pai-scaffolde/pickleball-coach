import XCTest
@testable import PickleballCoach

// SCA-1889 — Rights-clean in-app demo experience.
//
// Proves the demo session is buildable, rights-clean (RightsGate passes for the
// bundled generic exemplar and would REJECT the internal-dev YouTube clips),
// scorable (renders a mechanics scorecard), and deterministic.
final class DemoSessionServiceTests: XCTestCase {

    // MARK: - Builds and is flagged a sample

    func testMakeDemoSessionSucceedsAndIsFlaggedDemo() throws {
        let session = try DemoSessionService.makeDemoSession()
        XCTAssertTrue(session.isDemo, "demo session must be flagged so the UI can label it a sample")
        XCTAssertEqual(session.status, .ready, "demo ships pre-analyzed")
        XCTAssertNil(session.videoFileName, "demo must not reference any bundled video footage")
        XCTAssertFalse(session.title.isEmpty)
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

        // Negative control: the internal-dev YouTube clips must be REJECTED for
        // bundling — proves the gate actually discriminates and the demo took the
        // rights-clean path (board decision SCA-1875: never bundle these).
        XCTAssertThrowsError(
            try RightsGate.check(assetId: "yt-forehand-drive-navratil-v0",
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
