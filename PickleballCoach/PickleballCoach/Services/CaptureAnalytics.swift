import Foundation

// SCA-1870 (Gate 1) — capture-success instrumentation.
//
// Records one event each time a capture attempt is evaluated by the quality gate,
// carrying the session id, the capture-attempt count at evaluation time, and
// whether the attempt was accepted (`CaptureQualityGate.passed == true`).
//
// This is a deliberately minimal, dependency-free sink: events are appended to a
// JSON file in the app's Documents directory so the first-30-beta-sessions
// measurement can be read back without any external analytics SDK. The reader
// API (`events()`, `gateSummary(sessionLimit:)`) computes the gate verdict
// directly from the recorded acceptances.
struct CaptureAnalytics {

    /// One recorded capture-attempt evaluation.
    struct Event: Codable, Equatable {
        let sessionId: UUID
        let captureAttemptCount: Int
        let accepted: Bool
        let timestamp: Date
    }

    /// Roll-up of the Gate 1 measurement protocol over accepted sessions.
    struct GateSummary: Equatable {
        /// Number of distinct sessions that reached acceptance.
        let acceptedSessions: Int
        /// Accepted sessions whose accepting attempt was within 2 tries.
        let acceptedWithinTwoAttempts: Int
        /// Threshold the gate is measured against (default 0.80).
        let threshold: Double
        /// Sessions required to evaluate the gate (default 30).
        let requiredSessions: Int

        /// True once enough sessions are recorded to render a verdict.
        var hasEnoughData: Bool { acceptedSessions >= requiredSessions }
        /// Fraction of accepted sessions that succeeded within 2 attempts.
        var successRate: Double {
            acceptedSessions == 0 ? 0 : Double(acceptedWithinTwoAttempts) / Double(acceptedSessions)
        }
        /// Gate passes only with enough data AND success rate ≥ threshold.
        var passes: Bool { hasEnoughData && successRate >= threshold }
    }

    private let storeURL: URL

    /// - Parameter directory: where the event log lives. Defaults to the app's
    ///   Documents directory; tests inject a temporary directory.
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .documentDirectory,
                                                        in: .userDomainMask)[0]
        self.storeURL = dir.appendingPathComponent("capture-analytics.json")
    }

    /// Shared instance writing to the app's Documents directory.
    static let shared = CaptureAnalytics()

    // MARK: - Write

    /// Appends a capture-attempt evaluation event. Best-effort: write failures are
    /// swallowed so instrumentation never crashes the capture flow.
    func record(sessionId: UUID, captureAttemptCount: Int, accepted: Bool, at timestamp: Date = Date()) {
        var all = events()
        all.append(Event(sessionId: sessionId,
                         captureAttemptCount: captureAttemptCount,
                         accepted: accepted,
                         timestamp: timestamp))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(all) else { return }
        try? data.write(to: storeURL, options: [.atomic])
    }

    // MARK: - Read

    /// All recorded events in insertion order (empty if none / unreadable).
    func events() -> [Event] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Event].self, from: data)) ?? []
    }

    /// Computes the Gate 1 verdict from recorded acceptances.
    /// For each session that ever reached an accepted attempt, the
    /// `captureAttemptCount` of that accepting event is the attempts-to-acceptance.
    /// - Parameters:
    ///   - threshold: success fraction the gate requires (default 0.80).
    ///   - requiredSessions: sessions needed before a verdict (default 30).
    ///   - maxAttempts: attempts that count as success (default 2).
    func gateSummary(threshold: Double = 0.80,
                     requiredSessions: Int = 30,
                     maxAttempts: Int = 2) -> GateSummary {
        // First accepting event per session = its attempts-to-acceptance.
        var acceptedAt: [UUID: Int] = [:]
        for event in events() where event.accepted {
            if acceptedAt[event.sessionId] == nil {
                acceptedAt[event.sessionId] = event.captureAttemptCount
            }
        }
        let accepted = acceptedAt.count
        let withinTwo = acceptedAt.values.filter { $0 <= maxAttempts }.count
        return GateSummary(acceptedSessions: accepted,
                           acceptedWithinTwoAttempts: withinTwo,
                           threshold: threshold,
                           requiredSessions: requiredSessions)
    }
}
