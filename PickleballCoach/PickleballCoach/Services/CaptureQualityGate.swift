import Foundation

// Hard acceptance thresholds for a captured clip before feedback generation.
// Mirrors the ConfidenceReport logic in PoseCaptureService so thresholds
// live in one canonical place rather than being duplicated across callers.
// A clip that fails this gate is rejected with user-facing fix instructions —
// never silently analyzed with low-quality data.
//
// Gate coverage: SCA-1826 Gate 2 (pose confidence thresholds) and Gate 3
// (contact-phase reliability).
struct CaptureQualityGate {

    // MARK: - Thresholds (authoritative values for Gates 2 & 3)

    /// Minimum key joints that must pass the mean-confidence threshold.
    static let minimumReliableJoints = 6

    /// Vision mean confidence a joint must reach to be counted as reliable.
    static let jointMeanConfidenceThreshold: Float = 0.65

    /// Fraction of high-confidence frames (confidence > 0.70) a joint must have.
    static let minHighConfidenceFraction: Float = 0.45

    /// Minimum sampled frames required for any analysis to be meaningful.
    static let minimumSampledFrames = 10

    // MARK: - Rejection reasons

    enum Rejection: Equatable, CustomStringConvertible {
        case tooFewFrames(sampled: Int, required: Int)
        case insufficientJointCoverage(reliableCount: Int, required: Int)
        case contactZoneUnreliable

        var description: String {
            switch self {
            case .tooFewFrames(let s, let r):
                return "Only \(s) sampled frames; need at least \(r)."
            case .insufficientJointCoverage(let c, let r):
                return "Only \(c)/\(r) key joints met confidence threshold."
            case .contactZoneUnreliable:
                return "Wrist/elbow confidence too low in the contact zone."
            }
        }
    }

    // MARK: - Gate result

    struct GateResult {
        let passed: Bool
        let rejections: [Rejection]
        /// User-facing instructions to fix the rejected clip.
        let fixInstructions: [String]

        static let accepted = GateResult(passed: true, rejections: [], fixInstructions: [])
    }

    // MARK: - Evaluation

    static func evaluate(_ report: ConfidenceReport, sampledFrameCount: Int) -> GateResult {
        var rejections: [Rejection] = []
        var fixes: [String] = []

        if sampledFrameCount < minimumSampledFrames {
            rejections.append(.tooFewFrames(sampled: sampledFrameCount, required: minimumSampledFrames))
            fixes.append("Clip is too short. Record at least 3 seconds of continuous stroke motion.")
        }

        if !report.overallReliable {
            let reliableCount = report.jointReliability.values.filter {
                $0.meanConfidence >= jointMeanConfidenceThreshold &&
                Float($0.framesHighConfidence) >= Float($0.totalFrames) * minHighConfidenceFraction
            }.count
            rejections.append(.insufficientJointCoverage(
                reliableCount: reliableCount,
                required: minimumReliableJoints
            ))
            fixes.append("Stand 2–3 m from the camera with your full body visible from head to feet. Use a plain background and good, even lighting.")
        }

        if !report.contactZoneReliable {
            rejections.append(.contactZoneUnreliable)
            fixes.append("The hitting zone was hard to track. Try shooting in slow-motion (60fps+) or improve lighting around the hitting area.")
        }

        return GateResult(passed: rejections.isEmpty, rejections: rejections, fixInstructions: fixes)
    }
}
