import Foundation

/// Lightweight struct for a video file managed by the app.
struct VideoAsset: Codable, Identifiable {
    var id: UUID
    var fileName: String
    var durationSeconds: Double
    var importedAt: Date

    init(id: UUID = UUID(),
         fileName: String,
         durationSeconds: Double = 0,
         importedAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.durationSeconds = durationSeconds
        self.importedAt = importedAt
    }

    /// Resolves the on-disk URL for this asset in the app's Documents directory.
    func localURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask)[0]
        return documents.appendingPathComponent(fileName)
    }
}
