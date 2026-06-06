import XCTest
@testable import PickleballCoach

// SCA-1870 — Gate 1 capture-success instrumentation.
//
// Covers the Session model field, its legacy-decode fallback, the re-import
// increment, and the CaptureAnalytics sink + gate verdict.
final class CaptureAnalyticsTests: XCTestCase {

    // MARK: - Session model

    func testNewSessionDefaultsToOneAttempt() {
        XCTAssertEqual(Session(title: "x").captureAttemptCount, 1)
    }

    func testLegacySessionJSONDecodesToOneAttempt() throws {
        // Pre-SCA-1870 payload: no captureAttemptCount key.
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Legacy",
          "createdAt": 0,
          "status": "ready",
          "clipIntervals": [],
          "mechanicsScores": []
        }
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(Session.self, from: json)
        XCTAssertEqual(session.captureAttemptCount, 1)
    }

    func testCaptureAttemptCountRoundTrips() throws {
        var session = Session(title: "Round trip")
        session.registerReimportAttempt()
        session.registerReimportAttempt()
        XCTAssertEqual(session.captureAttemptCount, 3)

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.captureAttemptCount, 3)
    }

    // MARK: - Analytics sink

    private func makeAnalytics() throws -> CaptureAnalytics {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-analytics-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return CaptureAnalytics(directory: dir)
    }

    func testRecordAndReadEvents() throws {
        let analytics = try makeAnalytics()
        let sid = UUID()
        analytics.record(sessionId: sid, captureAttemptCount: 1, accepted: false)
        analytics.record(sessionId: sid, captureAttemptCount: 2, accepted: true)

        let events = analytics.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].sessionId, sid)
        XCTAssertEqual(events[0].captureAttemptCount, 1)
        XCTAssertFalse(events[0].accepted)
        XCTAssertTrue(events[1].accepted)
        XCTAssertEqual(events[1].captureAttemptCount, 2)
    }

    // MARK: - Gate verdict

    func testGateSummaryCountsAttemptsToAcceptance() throws {
        let analytics = try makeAnalytics()
        let sid = UUID()
        // Two failed attempts then accepted on the third.
        analytics.record(sessionId: sid, captureAttemptCount: 1, accepted: false)
        analytics.record(sessionId: sid, captureAttemptCount: 2, accepted: false)
        analytics.record(sessionId: sid, captureAttemptCount: 3, accepted: true)

        let summary = analytics.gateSummary()
        XCTAssertEqual(summary.acceptedSessions, 1)
        XCTAssertEqual(summary.acceptedWithinTwoAttempts, 0) // accepted on attempt 3
    }

    func testGateSummaryUsesFirstAcceptingAttempt() throws {
        let analytics = try makeAnalytics()
        let sid = UUID()
        analytics.record(sessionId: sid, captureAttemptCount: 2, accepted: true)
        analytics.record(sessionId: sid, captureAttemptCount: 5, accepted: true)
        let summary = analytics.gateSummary()
        XCTAssertEqual(summary.acceptedSessions, 1)
        XCTAssertEqual(summary.acceptedWithinTwoAttempts, 1) // first accept was attempt 2
    }

    func testGatePassesAtEightyPercentWithEnoughData() throws {
        let analytics = try makeAnalytics()
        // 30 sessions: 24 accepted within 2 attempts, 6 needing 3.
        for i in 0..<30 {
            let sid = UUID()
            let attempt = i < 24 ? 2 : 3
            analytics.record(sessionId: sid, captureAttemptCount: attempt, accepted: true)
        }
        let summary = analytics.gateSummary()
        XCTAssertEqual(summary.acceptedSessions, 30)
        XCTAssertEqual(summary.acceptedWithinTwoAttempts, 24)
        XCTAssertEqual(summary.successRate, 0.80, accuracy: 0.001)
        XCTAssertTrue(summary.hasEnoughData)
        XCTAssertTrue(summary.passes)
    }

    func testGateDoesNotPassWithoutEnoughData() throws {
        let analytics = try makeAnalytics()
        for _ in 0..<5 {
            analytics.record(sessionId: UUID(), captureAttemptCount: 1, accepted: true)
        }
        let summary = analytics.gateSummary()
        XCTAssertFalse(summary.hasEnoughData)
        XCTAssertFalse(summary.passes) // 100% rate but < 30 sessions
    }
}
