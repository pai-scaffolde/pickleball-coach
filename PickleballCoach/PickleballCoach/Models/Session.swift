import Foundation

enum SessionStatus: String, Codable, CaseIterable {
    case imported, analyzing, ready, failed

    var displayName: String {
        switch self {
        case .imported: return "Imported"
        case .analyzing: return "Analyzing"
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }
}

struct Session: Identifiable, Codable {
    var id: UUID
    var title: String
    var createdAt: Date
    var status: SessionStatus
    var videoFileName: String?           // relative filename in app documents dir
    var durationSeconds: Double?
    var poseAnalysisFileName: String?    // relative filename for PoseAnalysisResult JSON
    var poseTimelineFileName: String?    // relative filename for [PoseFrame] JSON timeline
    var clipIntervals: [ClipInterval]
    var mechanicsScores: [MechanicsScore]

    /// SCA-1870 (Gate 1) instrumentation: how many capture attempts this session
    /// has taken. Starts at 1 for the initial import and is incremented on every
    /// re-import attempt made before an analysis is accepted
    /// (`CaptureQualityGate.passed == true`). The value at acceptance is what the
    /// beta gate measures (target: ≥80% of sessions accepted within 2 attempts).
    var captureAttemptCount: Int

    init(id: UUID = UUID(),
         title: String = "",
         createdAt: Date = Date(),
         status: SessionStatus = .imported,
         videoFileName: String? = nil,
         durationSeconds: Double? = nil,
         poseAnalysisFileName: String? = nil,
         poseTimelineFileName: String? = nil,
         clipIntervals: [ClipInterval] = [],
         mechanicsScores: [MechanicsScore] = [],
         captureAttemptCount: Int = 1) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.status = status
        self.videoFileName = videoFileName
        self.durationSeconds = durationSeconds
        self.poseAnalysisFileName = poseAnalysisFileName
        self.poseTimelineFileName = poseTimelineFileName
        self.clipIntervals = clipIntervals
        self.mechanicsScores = mechanicsScores
        self.captureAttemptCount = captureAttemptCount
    }

    // Custom Decodable init so legacy session JSON (pre-M2) lacking clipIntervals or
    // mechanicsScores decodes successfully — missing keys fall back to empty arrays
    // rather than causing a decode error that silently wipes the session store.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        status = try c.decode(SessionStatus.self, forKey: .status)
        videoFileName = try c.decodeIfPresent(String.self, forKey: .videoFileName)
        durationSeconds = try c.decodeIfPresent(Double.self, forKey: .durationSeconds)
        poseAnalysisFileName = try c.decodeIfPresent(String.self, forKey: .poseAnalysisFileName)
        poseTimelineFileName = try c.decodeIfPresent(String.self, forKey: .poseTimelineFileName)
        clipIntervals = try c.decodeIfPresent([ClipInterval].self, forKey: .clipIntervals) ?? []
        mechanicsScores = try c.decodeIfPresent([MechanicsScore].self, forKey: .mechanicsScores) ?? []
        // Legacy sessions (pre-SCA-1870) lack captureAttemptCount; treat them as a
        // single attempt rather than failing the decode.
        captureAttemptCount = try c.decodeIfPresent(Int.self, forKey: .captureAttemptCount) ?? 1
    }

    /// Marks a re-import attempt: bumps the capture-attempt counter. Only
    /// meaningful before acceptance — once an analysis passes the quality gate the
    /// session is `.ready` and the count is frozen for measurement.
    mutating func registerReimportAttempt() {
        captureAttemptCount += 1
    }

    /// Resolves the full URL to the video file by looking it up in the app's
    /// Documents directory. Returns nil if no file is associated or the file
    /// does not exist on disk.
    func videoURL() -> URL? {
        guard let videoFileName, !videoFileName.isEmpty else { return nil }
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask)[0]
        let url = documents.appendingPathComponent(videoFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
