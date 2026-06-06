import Foundation

// Hard acceptance thresholds for a captured clip before feedback generation.
// Thresholds live here in one canonical place — never duplicated in callers.
// A clip that fails this gate is rejected with user-facing fix instructions;
// it is never silently analyzed with low-quality data.
//
// Gate coverage: SCA-1826 Gate 2 (pose confidence thresholds) and Gate 3
// (contact-phase reliability).
//
// Two entry points:
//  • evaluate(_:videoDuration:) — PoseExtractionService pipeline ([PoseFrame])
//  • evaluate(_:sampledFrameCount:) — PoseCaptureService pipeline (ConfidenceReport)
struct CaptureQualityGate {

    // MARK: - Thresholds (authoritative values for Gates 2 & 3)

    /// Minimum frames where bodyDetected == true (PoseFrame pipeline).
    static let minimumDetectedFrames = 15

    /// Minimum body-detection coverage (detectedFrames / totalFrames).
    static let minimumCoverageRatio: Double = 0.60

    /// Vision joint confidence threshold for contact-zone wrist check.
    static let contactZoneWristThreshold: Float = 0.60
    /// Vision joint confidence threshold for contact-zone elbow check.
    static let contactZoneElbowThreshold: Float = 0.65

    /// Minimum sampled frames for ConfidenceReport-based evaluation.
    static let minimumSampledFrames = 10

    // MARK: - Rejection reasons

    enum Rejection: Equatable, CustomStringConvertible {
        case tooFewDetectedFrames(detected: Int, required: Int)
        case coverageTooLow(percent: Int, required: Int)
        case contactZoneUnreliable
        case tooFewSampledFrames(sampled: Int, required: Int)
        case insufficientJointCoverage(reliableCount: Int, required: Int)

        var description: String {
            switch self {
            case .tooFewDetectedFrames(let d, let r):
                return "Body detected in only \(d) frames; need at least \(r)."
            case .coverageTooLow(let p, let r):
                return "Body visible in \(p)% of frames; need at least \(r)%."
            case .contactZoneUnreliable:
                return "Wrist/elbow confidence too low in the contact zone."
            case .tooFewSampledFrames(let s, let r):
                return "Only \(s) sampled frames; need at least \(r)."
            case .insufficientJointCoverage(let c, let r):
                return "Only \(c)/\(r) key joints met confidence threshold."
            }
        }
    }

    // MARK: - Gate result

    struct GateResult {
        let passed: Bool
        let rejections: [Rejection]
        /// Human-readable instructions to fix the rejected clip.
        let fixInstructions: [String]

        static let accepted = GateResult(passed: true, rejections: [], fixInstructions: [])
    }

    // MARK: - PoseExtractionService evaluation ([PoseFrame])

    static func evaluate(_ frames: [PoseFrame], videoDuration: Double?) -> GateResult {
        guard !frames.isEmpty else {
            return GateResult(
                passed: false,
                rejections: [.tooFewDetectedFrames(detected: 0, required: minimumDetectedFrames)],
                fixInstructions: ["Record at least 3 seconds of continuous stroke motion."]
            )
        }

        var rejections: [Rejection] = []
        var fixes: [String] = []

        let detected = frames.filter(\.bodyDetected).count
        let total = frames.count
        let coverageRatio = Double(detected) / Double(total)

        if detected < minimumDetectedFrames {
            rejections.append(.tooFewDetectedFrames(detected: detected, required: minimumDetectedFrames))
            fixes.append("Stand 2–3 m from the camera so your full body is visible. Record at least 3 seconds of continuous stroke motion.")
        }

        if coverageRatio < minimumCoverageRatio {
            rejections.append(.coverageTooLow(
                percent: Int((coverageRatio * 100).rounded()),
                required: Int(minimumCoverageRatio * 100)
            ))
            fixes.append("Use a plain background, even lighting, and ensure no one else is in the frame.")
        }

        if !contactZonePassesInFrames(frames) {
            rejections.append(.contactZoneUnreliable)
            fixes.append("The hitting zone was hard to track. Try slow-motion (60fps+) or improve lighting around the paddle at contact.")
        }

        return GateResult(passed: rejections.isEmpty, rejections: rejections, fixInstructions: fixes)
    }

    // MARK: - ConfidenceReport evaluation (PoseCaptureService / legacy)

    static func evaluate(_ report: ConfidenceReport, sampledFrameCount: Int) -> GateResult {
        var rejections: [Rejection] = []
        var fixes: [String] = []

        if sampledFrameCount < minimumSampledFrames {
            rejections.append(.tooFewSampledFrames(sampled: sampledFrameCount, required: minimumSampledFrames))
            fixes.append("Clip is too short. Record at least 3 seconds of continuous stroke motion.")
        }

        if !report.overallReliable {
            let reliableCount = report.jointReliability.values.filter {
                $0.meanConfidence >= 0.65 &&
                Float($0.framesHighConfidence) >= Float($0.totalFrames) * 0.45
            }.count
            rejections.append(.insufficientJointCoverage(reliableCount: reliableCount, required: 6))
            fixes.append("Stand 2–3 m from the camera with your full body visible. Use a plain background and good, even lighting.")
        }

        if !report.contactZoneReliable {
            rejections.append(.contactZoneUnreliable)
            fixes.append("The hitting zone was hard to track. Try slow-motion (60fps+) or improve lighting around the paddle at contact.")
        }

        return GateResult(passed: rejections.isEmpty, rejections: rejections, fixInstructions: fixes)
    }

    // MARK: - Helpers

    private static func contactZonePassesInFrames(_ frames: [PoseFrame]) -> Bool {
        let detected = frames.filter(\.bodyDetected)
        guard detected.count >= 4 else { return false }
        let lo = Int(Double(detected.count) * 0.30)
        let hi = min(Int(Double(detected.count) * 0.70), detected.count - 1)
        let zone = Array(detected[lo...hi])

        let wristConfs = zone.compactMap { $0.joints["right_wrist"]?.confidence }
        let elbowConfs = zone.compactMap { $0.joints["right_elbow"]?.confidence }
        guard !wristConfs.isEmpty, !elbowConfs.isEmpty else { return false }

        let wristMean = wristConfs.reduce(0, +) / Float(wristConfs.count)
        let elbowMean = elbowConfs.reduce(0, +) / Float(elbowConfs.count)
        return wristMean > contactZoneWristThreshold && elbowMean > contactZoneElbowThreshold
    }
}
