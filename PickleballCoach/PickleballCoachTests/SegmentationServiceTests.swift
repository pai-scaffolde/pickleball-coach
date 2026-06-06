import XCTest
@testable import PickleballCoach

// SCA-1862 — SegmentationService acceptance tests.
//
// Canonical fixture: forehand-pose-timeline-v0.json (23 frames, 0.00–2.93s).
// Annotation ground-truth: rep-annotations.json → rep 1: [0.40, 2.80].
// Acceptance: at least one returned ClipInterval must have IoU >= 0.70 vs ground truth.
final class SegmentationServiceTests: XCTestCase {

    // MARK: - Fixture loading

    private struct TimelineWrapper: Decodable {
        let frames: [PoseFrame]
    }

    /// Loads the pose-frame fixture from tests/fixtures/forehand-pose-timeline-v0.json.
    private func loadFixtureFrames() throws -> [PoseFrame] {
        let url = fixtureURL("forehand-pose-timeline-v0.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Pose timeline fixture not found at \(url.path)")
        }
        let data = try Data(contentsOf: url)
        let wrapper = try JSONDecoder().decode(TimelineWrapper.self, from: data)
        return wrapper.frames
    }

    /// Ground-truth rep boundaries from rep-annotations.json.
    private struct RepAnnotation: Decodable {
        struct Rep: Decodable {
            let start_time: Double
            let end_time: Double
        }
        let reps: [Rep]
        let video_duration_seconds: Double
    }

    private func loadAnnotations() throws -> RepAnnotation {
        let url = fixtureURL("rep-annotations.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Rep annotations fixture not found at \(url.path)")
        }
        return try JSONDecoder().decode(RepAnnotation.self, from: Data(contentsOf: url))
    }

    // MARK: - IoU helper

    private func iou(_ a: (Double, Double), _ b: (Double, Double)) -> Double {
        let intStart = max(a.0, b.0)
        let intEnd   = min(a.1, b.1)
        let intersection = max(0, intEnd - intStart)
        let union = max(a.1, b.1) - min(a.0, b.0)
        return union > 0 ? intersection / union : 0
    }

    // MARK: - Acceptance: IoU >= 0.70 on canonical fixture

    func testSegmentationOnCanonicalFixtureHasIoUAbove0_7() throws {
        let frames = try loadFixtureFrames()
        let annotations = try loadAnnotations()
        let videoDuration = annotations.video_duration_seconds

        let service = SegmentationService()
        let result = service.segment(frames: frames, videoDuration: videoDuration)

        XCTAssertFalse(result.clips.isEmpty,
            "Expected at least one clip from canonical fixture (got none; reason: \(result.lowConfidenceReason ?? "nil"))")

        for rep in annotations.reps {
            let gt = (rep.start_time, rep.end_time)
            let bestIoU = result.clips.map { iou((($0.startTime, $0.endTime)), gt) }.max() ?? 0
            XCTAssertGreaterThanOrEqual(bestIoU, 0.70,
                "Best IoU for rep [\(rep.start_time), \(rep.end_time)] was \(String(format: "%.3f", bestIoU)) — need >= 0.70")
        }
    }

    // MARK: - Acceptance: caps at maxClips

    func testMaxClipsCap() throws {
        // Build a synthetic 60-frame timeline with alternating high/low motion.
        var syntheticFrames: [PoseFrame] = []
        for i in 0..<60 {
            let ts = Double(i) * 0.1
            let wristX: Float = i % 10 < 5 ? Float(0.30 + Double(i % 5) * 0.05) : 0.30
            syntheticFrames.append(PoseFrame(
                timestamp: ts,
                joints: [
                    "right_wrist":    JointPosition(x: wristX, y: 0.60, confidence: 0.90),
                    "left_wrist":     JointPosition(x: 0.70 - wristX, y: 0.60, confidence: 0.90),
                    "right_shoulder": JointPosition(x: 0.45, y: 0.70, confidence: 0.90),
                    "left_shoulder":  JointPosition(x: 0.55, y: 0.70, confidence: 0.90),
                    "right_hip":      JointPosition(x: 0.46, y: 0.40, confidence: 0.90),
                    "left_hip":       JointPosition(x: 0.54, y: 0.40, confidence: 0.90),
                ],
                bodyDetected: true
            ))
        }

        let service = SegmentationService()
        let result = service.segment(frames: syntheticFrames, videoDuration: 6.0)
        XCTAssertLessThanOrEqual(result.clips.count, SegmentationService.maxClips,
            "SegmentationService must return at most \(SegmentationService.maxClips) clips")
    }

    // MARK: - Low-confidence: insufficient frames

    func testInsufficientFramesReturnsLowConfidence() {
        // Only 2 body-detected frames → below minimum.
        let sparse: [PoseFrame] = [
            PoseFrame(timestamp: 0.0, joints: ["right_wrist": JointPosition(x: 0.3, y: 0.6, confidence: 0.9)], bodyDetected: true),
            PoseFrame(timestamp: 0.1, joints: ["right_wrist": JointPosition(x: 0.4, y: 0.6, confidence: 0.9)], bodyDetected: true),
            PoseFrame(timestamp: 0.2, joints: [:], bodyDetected: false),
        ]
        let service = SegmentationService()
        let result = service.segment(frames: sparse, videoDuration: 1.0)
        XCTAssertTrue(result.clips.isEmpty || result.lowConfidenceReason != nil,
            "Sparse input should produce empty clips or a low-confidence reason")
    }

    // MARK: - Empty input is safe

    func testEmptyFramesIsHandledGracefully() {
        let service = SegmentationService()
        let result = service.segment(frames: [], videoDuration: 5.0)
        XCTAssertTrue(result.clips.isEmpty)
        XCTAssertNotNil(result.lowConfidenceReason)
    }

    // MARK: - Determinism

    func testResultIsDeterministic() throws {
        let frames = try loadFixtureFrames()
        let annotations = try loadAnnotations()
        let service = SegmentationService()
        let r1 = service.segment(frames: frames, videoDuration: annotations.video_duration_seconds)
        let r2 = service.segment(frames: frames, videoDuration: annotations.video_duration_seconds)
        XCTAssertEqual(r1.clips.count, r2.clips.count)
        for (a, b) in zip(r1.clips, r2.clips) {
            XCTAssertEqual(a.startTime, b.startTime)
            XCTAssertEqual(a.endTime,   b.endTime)
            XCTAssertEqual(a.confidence, b.confidence)
        }
    }

    // MARK: - Motion intensity

    func testMotionIntensityIndexZeroIsZero() {
        let frames: [PoseFrame] = [
            PoseFrame(timestamp: 0.0, joints: ["right_wrist": JointPosition(x: 0.3, y: 0.6, confidence: 0.9)], bodyDetected: true),
            PoseFrame(timestamp: 0.1, joints: ["right_wrist": JointPosition(x: 0.5, y: 0.6, confidence: 0.9)], bodyDetected: true),
        ]
        let intensities = SegmentationService().motionIntensities(frames: frames)
        XCTAssertEqual(intensities[0], 0.0, "First frame has no previous → intensity must be 0")
        XCTAssertGreaterThan(intensities[1], 0.0, "Second frame moved → intensity must be > 0")
    }

    // MARK: - Helper

    private func fixtureURL(_ filename: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // PickleballCoachTests/
            .deletingLastPathComponent()  // PickleballCoach/
            .deletingLastPathComponent()  // pickleball-coach/
            .appendingPathComponent("tests/fixtures/\(filename)")
    }
}
