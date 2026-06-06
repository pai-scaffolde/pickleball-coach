import XCTest
@testable import PickleballCoach

final class PoseExtractionServiceTests: XCTestCase {

    // MARK: - Orientation mapping (no video needed)

    func testOrientationPortrait() {
        let service = PoseExtractionService()
        let t = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
        XCTAssertEqual(service.imageOrientation(from: t), .right)
    }

    func testOrientationLandscapeRight() {
        let service = PoseExtractionService()
        let t = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        XCTAssertEqual(service.imageOrientation(from: t), .up)
    }

    func testOrientationLandscapeLeft() {
        let service = PoseExtractionService()
        let t = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        XCTAssertEqual(service.imageOrientation(from: t), .down)
    }

    // MARK: - Constants

    func testDefaultSampleRate() {
        XCTAssertEqual(PoseExtractionService.defaultSampleRate, 10.0)
    }

    func testMaxDurationIs5Minutes() {
        XCTAssertEqual(PoseExtractionService.maxDurationSeconds, 300.0)
    }

    func testMinimumJointCount() {
        XCTAssertEqual(PoseExtractionService.minimumJointCount, 6)
    }

    // MARK: - Canonical fixture (skipped when video absent)

    func testExtractOnCanonicalFixture() async throws {
        let fixtureURL = fixtureVideoURL()
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("Canonical fixture video not present — place fixture-forehand-drive-1rep-v0.mp4 in tests/fixtures/")
        }

        let service = PoseExtractionService()
        let frames = try await service.extract(videoURL: fixtureURL)

        // 3.5s × 10 Hz = 35 expected minimum frames
        let fixtureDuration = 3.5
        let expectedMin = Int(fixtureDuration * PoseExtractionService.defaultSampleRate)
        XCTAssertGreaterThanOrEqual(frames.count, expectedMin,
            "Expected ≥\(expectedMin) frames for \(fixtureDuration)s at \(PoseExtractionService.defaultSampleRate)Hz")

        // At least one frame must have body detected
        XCTAssertTrue(frames.contains(where: \.bodyDetected),
            "At least one frame should have bodyDetected=true on the fixture video")

        // bodyDetected=true frames must have ≥ minimumJointCount joints
        for frame in frames where frame.bodyDetected {
            XCTAssertGreaterThanOrEqual(frame.joints.count, PoseExtractionService.minimumJointCount,
                "bodyDetected frame at \(frame.timestamp)s has only \(frame.joints.count) joints")
        }
    }

    func testProgressHookFiresOnFixture() async throws {
        let fixtureURL = fixtureVideoURL()
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("Canonical fixture video not present")
        }

        var phases: Set<String> = []
        var maxProcessed = 0
        var lastTotal = 0

        let service = PoseExtractionService()
        _ = try await service.extract(videoURL: fixtureURL) { p in
            phases.insert(p.phase.rawValue)
            maxProcessed = max(maxProcessed, p.framesProcessed)
            if p.totalFrames > 0 { lastTotal = p.totalFrames }
        }

        XCTAssertTrue(phases.contains("loading"))
        XCTAssertTrue(phases.contains("extracting"))
        XCTAssertTrue(phases.contains("complete"))
        XCTAssertEqual(maxProcessed, lastTotal, "framesProcessed must reach totalFrames")
    }

    // MARK: - Helper

    private func fixtureVideoURL() -> URL {
        // Navigate from test file up to project root, then into tests/fixtures/
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // PickleballCoachTests/
            .deletingLastPathComponent()  // PickleballCoach/
            .deletingLastPathComponent()  // pickleball-coach/
            .appendingPathComponent("tests/fixtures/fixture-forehand-drive-1rep-v0.mp4")
    }
}
