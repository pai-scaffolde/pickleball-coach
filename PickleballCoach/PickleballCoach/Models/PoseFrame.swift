import Foundation

// A single frame of pose data in the Vision pipeline.
// Keys use the canonical joint name strings from PoseCaptureService (e.g. "nose", "left_wrist").
// Distinct from JointSample (analysis-internal); PoseFrame is the durable pipeline contract.
struct PoseFrame: Codable {
    let timestamp: Double
    let joints: [String: JointPosition]
    let bodyDetected: Bool
}
