import Foundation
import Combine

/// Persists and manages the list of coaching sessions. Sessions are stored as
/// JSON in `sessions.json` inside the app's Documents directory. All published
/// mutations and disk I/O are marshalled onto the main queue to keep the
/// `@Published` array and persisted file consistent.
final class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []

    private let fileName = "sessions.json"

    private var storeURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask)[0]
        return documents.appendingPathComponent(fileName)
    }

    init() {
        load()
        if sessions.isEmpty {
            seedDemo()
        }
    }

    // MARK: - Demo seeding

    /// Seeds the demo session on first launch so the app always has testable content.
    private func seedDemo() {
        guard let demo = try? DemoSessionService.makeDemoSession() else { return }
        sessions.append(demo)
        save()
    }

    // MARK: - Mutations

    func add(_ session: Session) {
        performOnMain {
            self.sessions.append(session)
            self.save()
        }
    }

    func delete(at offsets: IndexSet) {
        performOnMain {
            self.sessions.remove(atOffsets: offsets)
            self.save()
        }
    }

    func update(_ session: Session) {
        performOnMain {
            if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                self.sessions[index] = session
            }
            self.save()
        }
    }

    /// SCA-1870 (Gate 1): records a re-import attempt against an existing session.
    /// Swaps in the freshly imported clip, increments the capture-attempt counter,
    /// and resets the session to `.imported` so it re-runs the quality gate. The
    /// incremented count is what the next gate evaluation logs to analytics.
    func reimport(sessionID: UUID, videoFileName: String, durationSeconds: Double?) {
        performOnMain {
            guard let index = self.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
            self.sessions[index].registerReimportAttempt()
            self.sessions[index].videoFileName = videoFileName
            self.sessions[index].durationSeconds = durationSeconds
            self.sessions[index].status = .imported
            self.sessions[index].poseTimelineFileName = nil
            self.sessions[index].poseAnalysisFileName = nil
            self.save()
        }
    }

    // MARK: - Persistence

    private func load() {
        let work = {
            guard FileManager.default.fileExists(atPath: self.storeURL.path) else {
                self.sessions = []
                return
            }
            do {
                let data = try Data(contentsOf: self.storeURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                self.sessions = try decoder.decode([Session].self, from: data)
            } catch {
                // Corrupt or unreadable store: start empty rather than crash.
                self.sessions = []
            }
        }
        performOnMain(work)
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sessions)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            // Best-effort persistence: swallow write errors to avoid crashing
            // the UI. The in-memory list remains authoritative for this run.
        }
    }

    // MARK: - Threading

    /// Runs `block` synchronously if already on the main thread, otherwise
    /// dispatches asynchronously to the main queue. This keeps all state
    /// mutation serialized on main without deadlocking nested calls.
    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
