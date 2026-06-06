import Foundation

// MARK: - SCA-1861 — Deterministic forehand-drive mechanics scoring
//
// Scores forehand-drive mechanics from a [PoseFrame] timeline against the
// generic reference exemplar's CONTACT-phase ideal ranges, evaluated at a
// deterministically-chosen key frame (peak arm extension = contact / peak of the
// swing arc — decision D1/D4, forehand only).
//
// It REUSES ComparisonEngine (SCA-1824) for ALL geometry, feature extraction and
// range/delta scoring — it does not fork the comparison primitives. The only
// thing this engine adds is (a) deterministic key-frame selection over the
// timeline and (b) reshaping the contact-phase comparison into a MechanicsScore
// whose observations carry measured-vs-reference pairs (never a bare number).
//
// Determinism contract (SCA-1861 acceptance):
//   score(frames:clip:reference:) called twice on identical [PoseFrame] input
//   produces a BITWISE-equal MechanicsScore. Guaranteed because:
//     • `id` is derived from the clip (clip.id), not a fresh UUID;
//     • there is no Date / no randomness;
//     • the key frame is an argmax with a lowest-index tie-break;
//     • categories are emitted in ComparisonEngine's fixed FeatureKey order;
//     • all math is the pure, deterministic ComparisonEngine.
//
// Foundation-only and pure, so it compiles and runs headless (see
// tools/sca1861-scoring-harness) as well as inside the app target.
struct MechanicsScoringEngine {
    /// Joints below this confidence are treated as missing (passed through to
    /// ComparisonEngine). Matches the comparison default.
    let minJointConfidence: Double

    /// Reference phase whose ideal ranges define "ideal contact mechanics". The
    /// forehand exemplar's `contact` phase carries 3 categories: elbow angle,
    /// arm extension, and wrist (contact) height — within the issue's 3–5 range.
    static let scoredPhase = "contact"

    init(minJointConfidence: Double = 0.5) {
        self.minJointConfidence = minJointConfidence
    }

    /// The chosen contact key frame and the contact-phase comparison computed for
    /// it (kept so the caller does not recompute).
    struct ScoredKeyFrame {
        let index: Int
        let timestamp: Double
        let frame: PoseFrame
        let contact: PhaseComparison
    }

    /// Score one forehand-drive clip's pose timeline into a MechanicsScore.
    func score(frames: [PoseFrame], clip: ClipInterval, reference: ReferenceExemplar) -> MechanicsScore {
        let strokeType = clip.strokeType ?? reference.strokeType
        guard let key = selectKeyFrame(frames: frames, reference: reference) else {
            // No frame had measurable contact joints — empty, deterministic score.
            return MechanicsScore(id: clip.id, clipId: clip.id, strokeType: strokeType,
                                  keyFrameTimestamp: -1, scores: [:], observations: [])
        }

        var scores: [String: Double] = [:]
        var observations: [FeedbackObservation] = []
        // contact.features is already in ComparisonEngine's fixed FeatureKey order
        // (built from sortedRanges()), so iteration order is deterministic.
        for fc in key.contact.features {
            scores[fc.feature] = round1(fc.featureScore * 100)
            observations.append(observation(for: fc, frameIndex: key.index))
        }

        return MechanicsScore(
            id: clip.id,                 // deterministic: derived from the clip
            clipId: clip.id,
            strokeType: strokeType,
            keyFrameTimestamp: key.timestamp,
            scores: scores,
            observations: observations
        )
    }

    // MARK: Deterministic key-frame selection

    /// The contact key frame = the body-detected frame of PEAK RIGHT-WRIST SPEED,
    /// the textbook proxy for ball contact in a racquet swing (hand/racquet speed
    /// peaks at/near contact). Speed is the right_wrist displacement from the
    /// previous measurable frame, normalized by torso length so it is body-scale
    /// invariant. Ties resolve to the LOWEST frame index.
    ///
    /// Key-frame SELECTION is this engine's own concern; the per-category SCORING
    /// at that frame is still delegated to ComparisonEngine (no forked scoring).
    /// PoseFrame carries no phase labels (segmentation is a later milestone), so
    /// contact is detected kinematically rather than read from a phase tag — when
    /// segmentation lands, the annotated contact window can override this.
    ///
    /// Falls back to the first measurable frame when speed is uncomputable
    /// (fewer than two frames with a usable wrist+torso). Returns nil when no
    /// frame yields a measurable contact comparison at all.
    func selectKeyFrame(frames: [PoseFrame], reference: ReferenceExemplar) -> ScoredKeyFrame? {
        let engine = ComparisonEngine(minJointConfidence: minJointConfidence)

        var bestIndex: Int? = nil
        var bestSpeed = -Double.greatestFiniteMagnitude
        var firstMeasurable: Int? = nil
        var prevWrist: (x: Double, y: Double)? = nil

        for (idx, frame) in frames.enumerated() {
            guard frame.bodyDetected,
                  let wrist = wristPoint(frame),
                  let torso = torsoLength(frame) else { continue }
            if firstMeasurable == nil { firstMeasurable = idx }
            if let p = prevWrist {
                let speed = hypot(wrist.x - p.x, wrist.y - p.y) / torso
                if speed > bestSpeed {
                    bestSpeed = speed
                    bestIndex = idx
                }
            }
            prevWrist = wrist
        }

        guard let chosen = bestIndex ?? firstMeasurable else { return nil }
        let frame = frames[chosen]
        let pose = PhasePose(phase: Self.scoredPhase, joints: frame.joints)
        let report = engine.compare(user: [pose], reference: reference)
        guard let contact = report.phases.first(where: { $0.phase == Self.scoredPhase }) else { return nil }
        return ScoredKeyFrame(index: chosen, timestamp: frame.timestamp, frame: frame, contact: contact)
    }

    // MARK: Key-frame geometry (selection only — scoring stays in ComparisonEngine)

    private func wristPoint(_ frame: PoseFrame) -> (x: Double, y: Double)? {
        guard let j = frame.joints["right_wrist"], Double(j.confidence) >= minJointConfidence else { return nil }
        return (Double(j.x), Double(j.y))
    }

    /// torso length = distance(shoulder midpoint, hip midpoint); nil if either
    /// midpoint is unmeasurable. Used only to scale-normalize wrist speed.
    private func torsoLength(_ frame: PoseFrame) -> Double? {
        func mid(_ a: String, _ b: String) -> (x: Double, y: Double)? {
            guard let ja = frame.joints[a], Double(ja.confidence) >= minJointConfidence,
                  let jb = frame.joints[b], Double(jb.confidence) >= minJointConfidence else { return nil }
            return ((Double(ja.x) + Double(jb.x)) / 2, (Double(ja.y) + Double(jb.y)) / 2)
        }
        guard let sh = mid("left_shoulder", "right_shoulder"),
              let hip = mid("left_hip", "right_hip") else { return nil }
        let d = hypot(sh.x - hip.x, sh.y - hip.y)
        return d > 1e-4 ? d : nil
    }

    // MARK: Observation building (measured vs reference — never a bare number)

    private func observation(for fc: FeatureComparison, frameIndex: Int) -> FeedbackObservation {
        let label = Self.categoryLabel(fc.feature)
        let unit = Self.categoryUnit(fc.feature)
        let severity: FeedbackSeverity
        let confidence: MetricConfidence
        let measured: String

        if let v = fc.userValue {
            measured = format(v, unit: unit)
            switch fc.status {
            case "within":          severity = .strength
            case "below", "above":  severity = .improvement
            default:                severity = .neutral
            }
            confidence = (fc.status == "low_view_confidence") ? .medium : .high
        } else {
            measured = "not measurable"
            severity = .neutral
            confidence = .noData
        }

        let idealRange = "\(format(fc.idealMin, unit: unit))–\(format(fc.idealMax, unit: unit))"
        // Measured value paired with the reference band, e.g.
        // "elbow extension: 142° / ideal 150°–175°".
        let text = "\(label): \(measured) / ideal \(idealRange)"
        let correction = Self.correction(for: fc.status, label: label)

        return FeedbackObservation(
            ruleId: "mechanics.\(fc.feature)",
            severity: severity,
            observation: text,
            correction: correction,
            drill: "",
            citedMetricName: fc.feature,
            citedMetricValue: fc.userValue ?? -1,
            citedFrameIndices: [frameIndex],
            metricConfidence: confidence
        )
    }

    // MARK: Display mapping (units / labels / corrections per category)

    static func categoryLabel(_ feature: String) -> String {
        switch feature {
        case FeatureKey.rightElbowAngleDeg.rawValue:       return "elbow extension"
        case FeatureKey.rightKneeAngleDeg.rawValue:        return "knee bend"
        case FeatureKey.hipShoulderSeparationDeg.rawValue: return "hip–shoulder separation"
        case FeatureKey.wristHeightRelTorso.rawValue:      return "contact height"
        case FeatureKey.armExtensionRelTorso.rawValue:     return "arm extension"
        default:                                           return feature
        }
    }

    static func categoryUnit(_ feature: String) -> String {
        switch feature {
        case FeatureKey.rightElbowAngleDeg.rawValue,
             FeatureKey.rightKneeAngleDeg.rawValue,
             FeatureKey.hipShoulderSeparationDeg.rawValue:
            return "°"
        default:
            return ""   // torso-normalized ratios are unitless
        }
    }

    private static func correction(for status: String, label: String) -> String {
        switch status {
        case "within":  return "On target — keep this \(label)."
        case "below":   return "Increase your \(label) toward the ideal band."
        case "above":   return "Reduce your \(label) toward the ideal band."
        default:        return "Not enough reliable pose data to coach \(label) this rep."
        }
    }

    // MARK: Formatting

    private func format(_ v: Double, unit: String) -> String {
        // Degrees render as whole numbers; ratios keep 2 dp. Deterministic.
        if unit == "°" {
            return "\(Int(v.rounded()))\(unit)"
        }
        let r = (v * 100).rounded() / 100
        return String(format: "%.2f", r)
    }

    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}
