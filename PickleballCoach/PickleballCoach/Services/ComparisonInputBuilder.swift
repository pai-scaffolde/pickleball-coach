import Foundation

// MARK: - SCA-1868 — Adapt analyzed pose data into ComparisonEngine inputs
//
// Bridges the analysis pipeline to the side-by-side comparison feature. It is
// Foundation-only and pure (no Vision, no SwiftUI), so it compiles and runs
// headless alongside ComparisonEngine and is verified by the Python parity port
// in tools/sca1824-comparison-harness.
//
// Responsibilities:
//   1. Map a session's stroke type to the bundled generic reference exemplar
//      (forehand or backhand).
//   2. Turn analyzed pose data — either a PoseAnalysisResult ([JointSample]) or a
//      raw [PoseFrame] timeline — into the [PhasePose] the engine consumes.
//      Per-sample phase labels are honored when present (SCA-1819 artifact);
//      otherwise samples are segmented into the canonical phases by their
//      position in the clip timeline.
//   3. Pick a representative user pose per canonical phase for the "You" panel.

enum ComparisonInputBuilder {

    // MARK: Stroke type → bundled exemplar

    /// Bundled reference resource (JSON, no extension) for a session's stroke
    /// type. Backhand maps to the backhand exemplar; everything else (including
    /// the default "forehand_drive") maps to the forehand exemplar.
    static func exemplarResourceName(forShotType shotType: String) -> String {
        shotType.lowercased().contains("backhand")
            ? "reference_backhand_drive_v0"
            : "reference_forehand_drive_v0"
    }

    // MARK: PoseAnalysisResult → [PhasePose]

    /// Phase-tagged poses from an analysis result. If any sample carries a phase
    /// label (SCA-1819 artifact), labels are used directly; otherwise the clip is
    /// segmented into the canonical phases by timestamp.
    static func phasePoses(from analysis: PoseAnalysisResult) -> [PhasePose] {
        let samples = analysis.jointSamples
        guard !samples.isEmpty else { return [] }

        if samples.contains(where: { ($0.phase?.isEmpty == false) }) {
            return samples.compactMap { s in
                guard let phase = s.phase, !phase.isEmpty else { return nil }
                return PhasePose(phase: phase, joints: s.joints)
            }
        }
        return timeWindowSegmented(samples.map { (timestamp: $0.timestamp, joints: $0.joints) })
    }

    // MARK: [PoseFrame] → [PhasePose]

    /// Phase-tagged poses from a raw pose timeline (the live extraction pipeline's
    /// durable artifact). Frames carry no phase label, so the clip is segmented
    /// into the canonical phases by timestamp. Undetected frames are dropped.
    static func phasePoses(fromFrames frames: [PoseFrame]) -> [PhasePose] {
        let detected = frames.filter { $0.bodyDetected && !$0.joints.isEmpty }
        guard !detected.isEmpty else { return [] }
        return timeWindowSegmented(detected.map { (timestamp: $0.timestamp, joints: $0.joints) })
    }

    // MARK: Representative pose per phase (for the "You" panel)

    /// One representative user pose per canonical phase: the middle frame of that
    /// phase's window (the most settled moment). Keyed by canonical phase rawValue
    /// so it lines up with the report's phases and the phase picker.
    static func userPosesByPhase(from poses: [PhasePose]) -> [String: [String: JointPosition]] {
        var grouped: [String: [PhasePose]] = [:]
        for p in poses {
            guard let cp = CanonicalPhase.from(rawLabel: p.phase) else { continue }
            grouped[cp.rawValue, default: []].append(p)
        }
        var out: [String: [String: JointPosition]] = [:]
        for (phase, list) in grouped {
            out[phase] = list[list.count / 2].joints
        }
        return out
    }

    // MARK: - Time-window segmentation

    /// Splits a timeline into the seven canonical phases by even time windows and
    /// tags each pose with its canonical phase rawValue. Used when no per-sample
    /// segmentation label is available.
    private static func timeWindowSegmented(_ timed: [(timestamp: Double, joints: [String: JointPosition])]) -> [PhasePose] {
        let phases = CanonicalPhase.allCases
        let times = timed.map(\.timestamp)
        let lo = times.min() ?? 0
        let hi = times.max() ?? lo
        let span = hi - lo
        return timed.map { entry in
            let frac = span > 1e-9 ? (entry.timestamp - lo) / span : 0
            let idx = min(phases.count - 1, max(0, Int(frac * Double(phases.count))))
            return PhasePose(phase: phases[idx].rawValue, joints: entry.joints)
        }
    }
}
