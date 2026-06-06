import Foundation

// MARK: - SCA-1824 — Safe side-by-side reference comparison (no ghost overlay)
//
// This engine implements the comparison pattern defined in
// docs/SIDE_BY_SIDE_COMPARISON.md. It deliberately does NOT do pixel-level
// alignment or render a pro silhouette/ghost over the user's video. Instead it:
//
//   1. Normalizes both poses by BODY SCALE (torso length) and translation
//      (root-centred), so a tall user filmed close and a generic exemplar
//      filmed far are directly comparable.
//   2. Aligns user and reference by PHASE (ready → load → … → recovery), not by
//      frame index, so the two clips do not need identical timing.
//   3. Compares scale-invariant FEATURES (joint angles and torso-normalized
//      ratios) against generic ideal RANGES, reporting signed DELTAS — never raw
//      pixel distance between the two skeletons.
//
// The reference is always a pose-only generic exemplar (Option C in
// docs/RIGHTS_PLAN.md). No named athlete, footage, or pro-derived pose track is
// involved, so the comparison is rights-safe by construction.
//
// This file is Foundation-only and pure, so it compiles and runs headless
// (see tools/sca1824-comparison-harness) as well as inside the app target.

// MARK: Input

/// A single sampled pose tagged with the stroke phase it belongs to. The
/// segmentation module (Milestone 3) supplies the phase label; for the SCA-1824
/// prototype it is read from the SCA-1819 pose artifact.
struct PhasePose: Codable {
    let phase: String
    let joints: [String: JointPosition]   // JointPosition defined in PoseAnalysisResult.swift
}

// MARK: Canonical phase taxonomy

/// Canonical phases used to align any two clips. Raw segmentation labels (which
/// vary in granularity) are mapped onto these so comparison is phase-keyed.
enum CanonicalPhase: String, CaseIterable, Codable {
    case ready, load, takeback, turn, contact, followThrough = "follow_through", recovery

    /// Maps a raw phase label (from segmentation or the pose artifact) to a
    /// canonical phase. Unknown labels return nil and are ignored.
    static func from(rawLabel raw: String) -> CanonicalPhase? {
        switch raw {
        case "ready":                          return .ready
        case "preparation", "load", "weight_load": return .load
        case "backswing", "backswing_peak", "takeback": return .takeback
        case "forward_swing", "turn", "hip_shoulder_turn": return .turn
        case "pre_contact", "contact", "contact_zone": return .contact
        case "follow_through":                 return .followThrough
        case "recovery", "reset", "balance":   return .recovery
        default:                               return nil
        }
    }
}

// MARK: Feature keys

/// Scale- and rotation-tolerant mechanics features. Angles are in degrees;
/// ratios are normalized by torso length so they are body-scale invariant.
enum FeatureKey: String, CaseIterable, Codable {
    case rightElbowAngleDeg        = "right_elbow_angle_deg"
    case rightKneeAngleDeg         = "right_knee_angle_deg"
    case hipShoulderSeparationDeg  = "hip_shoulder_separation_deg"
    case wristHeightRelTorso       = "wrist_height_rel_torso"   // signed: + = wrist above shoulder
    case armExtensionRelTorso      = "arm_extension_rel_torso"  // shoulder→wrist distance / torso length
}

// MARK: Output

struct FeatureComparison: Codable {
    let feature: String
    let userValue: Double?      // nil when joints were too low-confidence to measure
    let idealMin: Double
    let idealMax: Double
    let delta: Double           // signed distance outside the range (0 when within)
    let status: String          // "within" | "below" | "above" | "insufficient_confidence" | "low_view_confidence"
    let featureScore: Double    // 0–1, 1 when within range, decays with delta

    /// SCA-1864: re-tag a measured feature as unreliable for the current camera
    /// view (e.g. axial rotation on a side-on capture). The measured value is
    /// preserved for display, but the feature is excluded from the phase score.
    func markedLowViewConfidence() -> FeatureComparison {
        FeatureComparison(feature: feature, userValue: userValue, idealMin: idealMin,
                          idealMax: idealMax, delta: delta, status: "low_view_confidence",
                          featureScore: featureScore)
    }
}

struct PhaseComparison: Codable {
    let phase: String
    let userFrameCount: Int
    let features: [FeatureComparison]
    let phaseScore: Double      // 0–100, mean of available feature scores (nil features excluded)
    let measured: Bool          // false when no feature could be measured for the phase
}

struct ComparisonReport: Codable {
    let strokeType: String
    let referenceId: String
    let referenceRightsStatus: String
    let method: String
    let ghostOverlay: Bool
    let alignment: String
    let minJointConfidence: Double
    let phases: [PhaseComparison]
    let overallScore: Double    // 0–100, mean of measured phase scores
    let measuredPhaseCount: Int
    let notes: [String]
}

// MARK: - Engine

struct ComparisonEngine {
    /// Joints below this confidence are treated as missing for feature math.
    let minJointConfidence: Double

    /// Below this shoulder-width / torso-length ratio the capture is treated as
    /// (near) side-on, where the 2D line-angle separation feature is excluded
    /// from scoring rather than reporting a false ~0°. The bundled exemplar and a
    /// frontal/three-quarter user both sit well above this (~0.5).
    static let sideOnFrontalityThreshold = 0.30

    init(minJointConfidence: Double = 0.5) {
        self.minJointConfidence = minJointConfidence
    }

    /// SCA-1864: per-feature scoring weight. `hip_shoulder_separation_deg` is a
    /// weak axial-rotation proxy in single-camera 2D, so it is down-weighted and
    /// cannot dominate a phase score. All other features weigh equally.
    static func weight(for key: FeatureKey) -> Double {
        switch key {
        case .hipShoulderSeparationDeg: return 0.25
        default:                        return 1.0
        }
    }

    func compare(user: [PhasePose], reference: ReferenceExemplar) -> ComparisonReport {
        // Group user poses by canonical phase.
        var byPhase: [CanonicalPhase: [PhasePose]] = [:]
        for pose in user {
            guard let cp = CanonicalPhase.from(rawLabel: pose.phase) else { continue }
            byPhase[cp, default: []].append(pose)
        }

        var phaseReports: [PhaseComparison] = []
        var measuredScores: [Double] = []

        // Iterate reference phases in canonical order so output is deterministic.
        for cp in CanonicalPhase.allCases {
            guard let refPhase = reference.phase(cp.rawValue) else { continue }
            let poses = byPhase[cp] ?? []

            var featureReports: [FeatureComparison] = []
            var weightedSum = 0.0
            var weightTotal = 0.0

            for (key, range) in refPhase.sortedRanges() {
                let userValue = meanFeature(key, across: poses)
                var report = compareFeature(key: key, userValue: userValue, range: range)
                // SCA-1864: 2D rotation under-detection. A line-angle between two
                // near-horizontal segments cannot observe AXIAL torso rotation
                // (the hip/shoulder "X-factor") from a single camera — on a side-on
                // OR a frontal view the shoulder and hip lines stay near-parallel,
                // so the separation reads ~0° regardless of the real coil. We
                // therefore (a) DOWN-WEIGHT this feature so it can't dominate a
                // phase score, and (b) fully EXCLUDE it on true side-on captures
                // where projected body width collapses and even tilt is unreadable.
                // True axial rotation needs depth/3D pose (tracked: SCA-1864 #4 → 3D).
                if key == .hipShoulderSeparationDeg, report.status != "insufficient_confidence",
                   let frontality = meanFrontality(across: poses), frontality < Self.sideOnFrontalityThreshold {
                    report = report.markedLowViewConfidence()
                }
                featureReports.append(report)
                if report.status != "insufficient_confidence", report.status != "low_view_confidence" {
                    let w = Self.weight(for: key)
                    weightedSum += report.featureScore * w
                    weightTotal += w
                }
            }

            let measured = weightTotal > 0
            let phaseScore = measured ? (weightedSum / weightTotal) * 100 : 0
            if measured { measuredScores.append(phaseScore) }

            phaseReports.append(PhaseComparison(
                phase: cp.rawValue,
                userFrameCount: poses.count,
                features: featureReports,
                phaseScore: (phaseScore * 10).rounded() / 10,
                measured: measured
            ))
        }

        let overall = measuredScores.isEmpty ? 0 : measuredScores.reduce(0, +) / Double(measuredScores.count)

        var notes: [String] = []
        let unmeasured = phaseReports.filter { !$0.measured }.map { $0.phase }
        if !unmeasured.isEmpty {
            notes.append("Phases with no measurable features (missing segment or low confidence): \(unmeasured.joined(separator: ", ")).")
        }
        let sideOnPhases = phaseReports
            .filter { $0.features.contains { $0.status == "low_view_confidence" } }
            .map { $0.phase }
        if !sideOnPhases.isEmpty {
            notes.append("hip_shoulder_separation_deg excluded as low-view-confidence (side-on capture; 2D cannot read axial rotation) for: \(sideOnPhases.joined(separator: ", ")).")
        }
        notes.append("hip_shoulder_separation_deg is down-weighted (×0.25): a single-camera 2D line-angle is a weak axial-rotation proxy. Reliable torso rotation needs depth/3D pose.")
        notes.append("Comparison is range/delta on scale-normalized features. No pixel alignment, no ghost overlay, no pro footage.")

        return ComparisonReport(
            strokeType: reference.strokeType,
            referenceId: reference.id,
            referenceRightsStatus: reference.rightsStatus,
            method: "range_delta_on_scale_normalized_features",
            ghostOverlay: false,
            alignment: "phase_keyed_not_pixel",
            minJointConfidence: minJointConfidence,
            phases: phaseReports,
            overallScore: (overall * 10).rounded() / 10,
            measuredPhaseCount: measuredScores.count,
            notes: notes
        )
    }

    // MARK: Feature comparison

    private func compareFeature(key: FeatureKey, userValue: Double?, range: ReferenceRange) -> FeatureComparison {
        guard let v = userValue else {
            return FeatureComparison(feature: key.rawValue, userValue: nil,
                                     idealMin: range.idealMin, idealMax: range.idealMax,
                                     delta: 0, status: "insufficient_confidence", featureScore: 0)
        }
        let width = max(range.idealMax - range.idealMin, 1e-6)
        let delta: Double
        let status: String
        if v < range.idealMin {
            delta = v - range.idealMin; status = "below"
        } else if v > range.idealMax {
            delta = v - range.idealMax; status = "above"
        } else {
            delta = 0; status = "within"
        }
        // Score decays over one range-width of tolerance beyond the band.
        let score = max(0, 1 - abs(delta) / width)
        return FeatureComparison(feature: key.rawValue, userValue: round3(v),
                                 idealMin: range.idealMin, idealMax: range.idealMax,
                                 delta: round3(delta), status: status, featureScore: round3(score))
    }

    // MARK: Feature extraction (mean across a phase's frames, low-confidence skipped)

    private func meanFeature(_ key: FeatureKey, across poses: [PhasePose]) -> Double? {
        var values: [Double] = []
        for pose in poses {
            if let v = feature(key, in: pose) { values.append(v) }
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// SCA-1864: mean "frontality" = shoulder-width / torso-length across a
    /// phase's frames. ~0.5 for a frontal/three-quarter view; collapses toward 0
    /// as the body turns side-on and the shoulder line foreshortens. Used to gate
    /// the (2D-unreliable) axial-rotation feature. nil when unmeasurable.
    private func meanFrontality(across poses: [PhasePose]) -> Double? {
        var values: [Double] = []
        for pose in poses {
            guard let torso = torsoLength(in: pose),
                  let ls = point("left_shoulder", in: pose),
                  let rs = point("right_shoulder", in: pose) else { continue }
            values.append(dist(ls, rs) / torso)
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func feature(_ key: FeatureKey, in pose: PhasePose) -> Double? {
        switch key {
        case .rightElbowAngleDeg:
            return angle(at: "right_elbow", a: "right_shoulder", b: "right_wrist", in: pose)
        case .rightKneeAngleDeg:
            return angle(at: "right_knee", a: "right_hip", b: "right_ankle", in: pose)
        case .hipShoulderSeparationDeg:
            guard let shoulderLine = lineAngle("left_shoulder", "right_shoulder", in: pose),
                  let hipLine = lineAngle("left_hip", "right_hip", in: pose) else { return nil }
            return abs(angularDifference(shoulderLine, hipLine))
        case .wristHeightRelTorso:
            guard let torso = torsoLength(in: pose),
                  let wrist = point("right_wrist", in: pose),
                  let shoulder = point("right_shoulder", in: pose) else { return nil }
            return Double(wrist.y - shoulder.y) / torso
        case .armExtensionRelTorso:
            guard let torso = torsoLength(in: pose),
                  let shoulder = point("right_shoulder", in: pose),
                  let wrist = point("right_wrist", in: pose) else { return nil }
            return dist(shoulder, wrist) / torso
        }
    }

    // MARK: Geometry helpers

    private struct P { let x: Double; let y: Double }

    private func point(_ name: String, in pose: PhasePose) -> P? {
        guard let j = pose.joints[name], Double(j.confidence) >= minJointConfidence else { return nil }
        return P(x: Double(j.x), y: Double(j.y))
    }

    private func midpoint(_ a: String, _ b: String, in pose: PhasePose) -> P? {
        guard let pa = point(a, in: pose), let pb = point(b, in: pose) else { return nil }
        return P(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
    }

    /// Torso length = distance(shoulder midpoint, hip midpoint). The body-scale
    /// normalizer: dividing positional features by it removes body-size and
    /// camera-distance dependence.
    private func torsoLength(in pose: PhasePose) -> Double? {
        guard let sh = midpoint("left_shoulder", "right_shoulder", in: pose),
              let hip = midpoint("left_hip", "right_hip", in: pose) else { return nil }
        let d = dist(sh, hip)
        return d > 1e-4 ? d : nil
    }

    /// Interior angle (degrees) at vertex `at` formed by rays to `a` and `b`.
    private func angle(at vertex: String, a: String, b: String, in pose: PhasePose) -> Double? {
        guard let v = point(vertex, in: pose), let pa = point(a, in: pose), let pb = point(b, in: pose) else { return nil }
        let v1 = P(x: pa.x - v.x, y: pa.y - v.y)
        let v2 = P(x: pb.x - v.x, y: pb.y - v.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let m1 = (v1.x * v1.x + v1.y * v1.y).squareRoot()
        let m2 = (v2.x * v2.x + v2.y * v2.y).squareRoot()
        guard m1 > 1e-6, m2 > 1e-6 else { return nil }
        let cosv = max(-1, min(1, dot / (m1 * m2)))
        return acos(cosv) * 180 / .pi
    }

    /// Orientation of the line a→b in degrees (−180…180).
    private func lineAngle(_ a: String, _ b: String, in pose: PhasePose) -> Double? {
        guard let pa = point(a, in: pose), let pb = point(b, in: pose) else { return nil }
        return atan2(pb.y - pa.y, pb.x - pa.x) * 180 / .pi
    }

    private func angularDifference(_ a: Double, _ b: Double) -> Double {
        var d = a - b
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    private func dist(_ a: P, _ b: P) -> Double {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private func round3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
}
