import Foundation

// A time-bounded stroke interval within a session video.
// Produced by rep segmentation or manual annotation; consumed by the mechanics scoring pipeline.
struct ClipInterval: Identifiable, Codable {
    let id: UUID
    let startTime: Double    // seconds from video start
    let endTime: Double      // seconds from video start
    let strokeType: String?  // e.g. "forehand_drive", "dink"
    let confidence: Double   // 0–1; 1.0 for manually annotated intervals
}
