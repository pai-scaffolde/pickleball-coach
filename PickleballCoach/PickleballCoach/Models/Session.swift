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
    var videoFileName: String?      // relative filename in app documents dir
    var durationSeconds: Double?

    init(id: UUID = UUID(),
         title: String = "",
         createdAt: Date = Date(),
         status: SessionStatus = .imported,
         videoFileName: String? = nil,
         durationSeconds: Double? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.status = status
        self.videoFileName = videoFileName
        self.durationSeconds = durationSeconds
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
