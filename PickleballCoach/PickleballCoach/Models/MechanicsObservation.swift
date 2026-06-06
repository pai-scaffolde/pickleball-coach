import Foundation

/// Confidence tier for a computed mechanics metric.
/// Derived from contributing frame count and mean Vision pose confidence in the analysis window.
enum MetricConfidence: String, Codable {
    /// ≥5 frames contributed, mean joint confidence ≥0.65
    case high
    /// 3–4 contributing frames, or mean confidence 0.50–0.64
    case medium
    /// 1–2 frames, or mean confidence <0.50
    case insufficient
    /// Required joints were never detected in the target window
    case noData

    var displayLabel: String {
        switch self {
        case .high:         return "High confidence"
        case .medium:       return "Moderate confidence"
        case .insufficient: return "Low confidence"
        case .noData:       return "Not enough evidence"
        }
    }

    init(frameCount: Int, meanConfidence: Double) {
        if frameCount >= 5 && meanConfidence >= 0.65 {
            self = .high
        } else if frameCount >= 3 && meanConfidence >= 0.50 {
            self = .medium
        } else if frameCount >= 1 {
            self = .insufficient
        } else {
            self = .noData
        }
    }
}

/// A single computed biomechanical metric derived from pose joint samples.
/// Every FeedbackObservation that references a metric traces back here.
struct MechanicsMetric: Codable {
    let name: String
    let value: Double
    let unit: String           // "ratio", "degrees", "normalized"
    let confidence: MetricConfidence
    /// Frame indices from the source JointSample array that contributed to this value.
    let citedFrameIndices: [Int]
    let citedTimestamps: [Double]
}

enum FeedbackSeverity: String, Codable {
    case strength
    case improvement
    case neutral
}

/// A single coaching observation produced by one FeedbackRule.
/// Cites the exact metric and source frames so the user can verify the basis of the comment.
struct FeedbackObservation: Codable {
    let ruleId: String
    let severity: FeedbackSeverity
    /// Final observation text with metric value substituted in.
    let observation: String
    let correction: String
    let drill: String
    let citedMetricName: String
    let citedMetricValue: Double
    let citedFrameIndices: [Int]
    let metricConfidence: MetricConfidence
}

/// Coaching output for one phase of a stroke clip.
/// Produced by FeedbackEngine from a PoseAnalysisResult.
/// score is -1 and primaryObservation is nil when confidence is insufficient.
struct ClipFeedback: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    /// 1-based phase index matching the coaching clip template.
    let phaseIndex: Int
    let phaseTitle: String
    let strokeType: String
    let clipStartSeconds: Double
    let clipEndSeconds: Double
    /// 0–100 derived deterministically from primary metric; -1 when confidence is too low.
    let score: Int
    let scoreDimensionLabel: String
    let primaryObservation: FeedbackObservation?
    let additionalObservations: [FeedbackObservation]
    let metrics: [MechanicsMetric]
    let overallConfidence: MetricConfidence
    /// Human-readable explanation of why confidence is low; nil when confidence is sufficient.
    let insufficientDataNote: String?
    let highlightJointNames: [String]
}
