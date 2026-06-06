import XCTest
@testable import PickleballCoach

/// SCA-1861 — deterministic forehand-drive mechanics scoring.
///
/// The headline acceptance criterion is determinism: scoring the same
/// [PoseFrame] input twice must produce a BITWISE-equal MechanicsScore. These
/// tests build inline fixtures (no bundle resources needed) so they run anywhere
/// the test target builds.
final class MechanicsScoringEngineTests: XCTestCase {

    // MARK: - Inline fixtures

    private func joint(_ x: Float, _ y: Float, _ c: Float = 0.95) -> JointPosition {
        JointPosition(x: x, y: y, confidence: c)
    }

    /// A pose with a standing torso and a right arm placed at (wristX, wristY).
    /// Torso length is ~0.30 (shoulders at y=0.70, hips at y=0.40).
    private func pose(wristX: Float, wristY: Float, elbowX: Float, elbowY: Float) -> [String: JointPosition] {
        [
            "left_shoulder":  joint(0.55, 0.70),
            "right_shoulder": joint(0.45, 0.70),
            "left_hip":       joint(0.54, 0.40),
            "right_hip":      joint(0.46, 0.40),
            "right_elbow":    joint(elbowX, elbowY),
            "right_wrist":    joint(wristX, wristY),
        ]
    }

    /// A 5-frame forehand-ish timeline. The wrist barely moves on frames 0→1 and
    /// 3→4, but JUMPS on frame 2 → frame 2 is the peak-wrist-speed key frame.
    private func timeline() -> [PoseFrame] {
        [
            PoseFrame(timestamp: 0.0, joints: pose(wristX: 0.30, wristY: 0.55, elbowX: 0.38, elbowY: 0.62), bodyDetected: true),
            PoseFrame(timestamp: 0.1, joints: pose(wristX: 0.31, wristY: 0.56, elbowX: 0.38, elbowY: 0.62), bodyDetected: true),
            PoseFrame(timestamp: 0.2, joints: pose(wristX: 0.62, wristY: 0.66, elbowX: 0.52, elbowY: 0.66), bodyDetected: true),
            PoseFrame(timestamp: 0.3, joints: pose(wristX: 0.64, wristY: 0.67, elbowX: 0.53, elbowY: 0.66), bodyDetected: true),
            PoseFrame(timestamp: 0.4, joints: pose(wristX: 0.65, wristY: 0.67, elbowX: 0.53, elbowY: 0.66), bodyDetected: true),
        ]
    }

    /// Minimal reference exemplar with a `contact` phase carrying the 3 forehand
    /// contact categories (mirrors reference_forehand_drive_v0.json).
    private func reference() -> ReferenceExemplar {
        let contact = ReferencePhase(
            phase: "contact",
            pose: [:],
            ranges: [
                "right_elbow_angle_deg":   ReferenceRange(idealMin: 150, idealMax: 175),
                "arm_extension_rel_torso": ReferenceRange(idealMin: 0.95, idealMax: 1.35),
                "wrist_height_rel_torso":  ReferenceRange(idealMin: -0.45, idealMax: 0.10),
            ]
        )
        return ReferenceExemplar(
            id: "exemplar-generic-pose-forehand-v0",
            strokeType: "forehand_drive",
            rightsStatus: "cleared-public",
            usageScope: "bundled-app",
            source: "test inline",
            description: "test",
            phases: [contact]
        )
    }

    private func clip() -> ClipInterval {
        ClipInterval(id: UUID(uuidString: "00000000-0000-0000-0000-000000001861")!,
                     startTime: 0, endTime: 0.4, strokeType: "forehand_drive", confidence: 1.0)
    }

    private func encode(_ score: MechanicsScore) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(score)
    }

    // MARK: - Acceptance: bitwise-deterministic output

    func testScoringIsBitwiseDeterministic() throws {
        let engine = MechanicsScoringEngine()
        let frames = timeline()
        let ref = reference()
        let clip = clip()

        let a = engine.score(frames: frames, clip: clip, reference: ref)
        let b = engine.score(frames: frames, clip: clip, reference: ref)

        let da = try encode(a)
        let db = try encode(b)
        XCTAssertEqual(da, db, "Two scoring runs on identical [PoseFrame] input must be byte-identical")
    }

    func testIdIsDerivedFromClipNotRandom() {
        let engine = MechanicsScoringEngine()
        let clip = clip()
        let score = engine.score(frames: timeline(), clip: clip, reference: reference())
        // id == clipId == clip.id: stable across runs (no fresh UUID).
        XCTAssertEqual(score.id, clip.id)
        XCTAssertEqual(score.clipId, clip.id)
    }

    // MARK: - Acceptance: 3–5 categories, measured vs reference (never bare)

    func testProducesThreeToFiveCategoriesWithMeasuredAndReference() {
        let engine = MechanicsScoringEngine()
        let score = engine.score(frames: timeline(), clip: clip(), reference: reference())

        XCTAssertGreaterThanOrEqual(score.scores.count, 3)
        XCTAssertLessThanOrEqual(score.scores.count, 5)
        XCTAssertEqual(score.observations.count, score.scores.count)

        for obs in score.observations {
            // Each observation pairs a measured value against the reference band.
            XCTAssertTrue(obs.observation.contains(" / ideal "),
                          "Observation must show measured vs reference, got: \(obs.observation)")
            XCTAssertNotEqual(obs.citedMetricValue, -1, "Measured value must be present for: \(obs.ruleId)")
            XCTAssertFalse(obs.citedFrameIndices.isEmpty, "Observation must cite the key frame")
        }
    }

    // MARK: - Key-frame selection

    func testKeyFrameIsPeakWristSpeedFrame() {
        let engine = MechanicsScoringEngine()
        let frames = timeline()
        let key = engine.selectKeyFrame(frames: frames, reference: reference())
        XCTAssertNotNil(key)
        // Frame 2 has the largest wrist jump → its timestamp is 0.2.
        XCTAssertEqual(key?.index, 2)
        XCTAssertEqual(key?.timestamp ?? -1, 0.2, accuracy: 1e-9)

        let score = engine.score(frames: frames, clip: clip(), reference: reference())
        XCTAssertEqual(score.keyFrameTimestamp, 0.2, accuracy: 1e-9)
        for obs in score.observations {
            XCTAssertEqual(obs.citedFrameIndices, [2])
        }
    }

    // MARK: - Degenerate input stays deterministic

    func testEmptyTimelineProducesDeterministicEmptyScore() throws {
        let engine = MechanicsScoringEngine()
        let clip = clip()
        let a = engine.score(frames: [], clip: clip, reference: reference())
        let b = engine.score(frames: [], clip: clip, reference: reference())

        XCTAssertEqual(a.keyFrameTimestamp, -1)
        XCTAssertTrue(a.scores.isEmpty)
        XCTAssertTrue(a.observations.isEmpty)
        XCTAssertEqual(try encode(a), try encode(b))
    }
}
