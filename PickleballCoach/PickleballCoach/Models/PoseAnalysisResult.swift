import Foundation

// Normalized joint position in Vision coordinate space.
// Origin: bottom-left corner. x and y are 0–1.
struct JointPosition: Codable, Hashable {
    let x: Float
    let y: Float
    let confidence: Float  // 0–1 from VNRecognizedPoint.confidence
}

// All recognized joints captured at a single sampled video timestamp.
struct JointSample: Codable {
    let timestamp: Double   // seconds from video start
    let frameIndex: Int     // original frame number in source video
    let joints: [String: JointPosition]
}

// Per-joint confidence summary across the full clip.
struct JointReliability: Codable {
    let meanConfidence: Float
    let minConfidence: Float
    let framesHighConfidence: Int  // frames where confidence > 0.7
    let framesMedConfidence: Int   // frames where confidence > 0.5
    let totalFrames: Int           // total sampled frames (not just frames where joint visible)
}

// Aggregate reliability verdict for the clip.
struct ConfidenceReport: Codable {
    let jointReliability: [String: JointReliability]
    // Whether wrist+elbow maintain ≥ 0.6/0.65 confidence in the contact zone (middle third of clip).
    let contactZoneReliable: Bool
    // True when ≥ 6 key joints exceed 0.65 mean confidence.
    let overallReliable: Bool
    let notes: [String]
}

struct PoseAnalysisResult: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let shotType: String             // e.g. "forehand_drive"
    let analyzedAt: Date
    let videoPath: String
    let videoDurationSeconds: Double
    let originalFrameCount: Int
    let samplingInterval: Int        // every Nth frame was sampled
    let sampledFrameCount: Int       // frames that produced a pose observation
    let jointSamples: [JointSample]
    let confidenceReport: ConfidenceReport

    init(
        sessionId: UUID,
        shotType: String,
        analyzedAt: Date,
        videoPath: String,
        videoDurationSeconds: Double,
        originalFrameCount: Int,
        samplingInterval: Int,
        sampledFrameCount: Int,
        jointSamples: [JointSample],
        confidenceReport: ConfidenceReport
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.shotType = shotType
        self.analyzedAt = analyzedAt
        self.videoPath = videoPath
        self.videoDurationSeconds = videoDurationSeconds
        self.originalFrameCount = originalFrameCount
        self.samplingInterval = samplingInterval
        self.sampledFrameCount = sampledFrameCount
        self.jointSamples = jointSamples
        self.confidenceReport = confidenceReport
    }
}
