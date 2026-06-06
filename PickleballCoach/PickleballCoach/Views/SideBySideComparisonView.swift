import SwiftUI

// MARK: - SCA-1824 — Side-by-side reference comparison (no ghost overlay)
//
// Renders the user's pose and a pose-only generic exemplar in TWO SEPARATE
// panels (You | Reference) for a selected phase, with a range/delta readout
// underneath. It deliberately does NOT superimpose the reference on the user's
// video (no ghost overlay) — per docs/RIGHTS_PLAN.md that pattern is deferred
// until rights + alignment quality are solved. Each panel is independently
// body-scale normalized so the two skeletons are visually comparable without
// pixel registration.

// Bone connections shared by both panels.
private let kBones: [(String, String)] = [
    ("nose", "neck"), ("neck", "right_shoulder"), ("neck", "left_shoulder"),
    ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
    ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
    ("right_shoulder", "right_hip"), ("left_shoulder", "left_hip"),
    ("right_hip", "left_hip"), ("right_shoulder", "left_shoulder"),
    ("right_hip", "right_knee"), ("right_knee", "right_ankle"),
    ("left_hip", "left_knee"), ("left_knee", "left_ankle"),
]

/// Draws a single skeleton, body-scale normalized to fill its rect. Vision space
/// is bottom-left origin; SwiftUI is top-left, so y is flipped.
struct SkeletonCanvas: View {
    let joints: [String: JointPosition]
    var highlight: Set<String> = []
    var tint: Color = .primary

    var body: some View {
        Canvas { ctx, size in
            let pts = normalizedPoints(in: size)
            // Bones
            for (a, b) in kBones {
                guard let pa = pts[a], let pb = pts[b] else { continue }
                var path = Path()
                path.move(to: pa); path.addLine(to: pb)
                ctx.stroke(path, with: .color(tint.opacity(0.7)), lineWidth: 2)
            }
            // Joints
            for (name, p) in pts {
                let on = highlight.contains(name)
                let r: CGFloat = on ? 5 : 3.5
                let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
                ctx.fill(Path(ellipseIn: rect), with: .color(on ? .yellow : tint))
            }
        }
    }

    /// Translate (root-centred) and scale (by torso length) so the skeleton
    /// fills the rect regardless of body size or original frame placement.
    private func normalizedPoints(in size: CGSize) -> [String: CGPoint] {
        func raw(_ n: String) -> CGPoint? {
            guard let j = joints[n], j.confidence >= 0.5 else { return nil }
            return CGPoint(x: CGFloat(j.x), y: CGFloat(j.y))
        }
        func midOf(_ a: String, _ b: String) -> CGPoint? {
            guard let pa = raw(a), let pb = raw(b) else { return nil }
            return CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
        }
        guard let sh = midOf("left_shoulder", "right_shoulder"),
              let hip = midOf("left_hip", "right_hip") else { return [:] }
        let torso = max(hypot(sh.x - hip.x, sh.y - hip.y), 0.0001)
        let root = hip
        // Fit ~3 torso-lengths into the rect with padding.
        let scale = min(size.width, size.height) / (torso * 3.2)
        let cx = size.width / 2, cy = size.height / 2
        var out: [String: CGPoint] = [:]
        for (name, j) in joints where j.confidence >= 0.5 {
            let nx = (CGFloat(j.x) - root.x) * scale
            let ny = (CGFloat(j.y) - root.y) * scale
            // Flip y (Vision bottom-left → SwiftUI top-left).
            out[name] = CGPoint(x: cx + nx, y: cy - ny)
        }
        return out
    }
}

struct SideBySideComparisonView: View {
    let userPosesByPhase: [String: [String: JointPosition]]  // canonical phase → representative user pose
    let reference: ReferenceExemplar
    let report: ComparisonReport

    @State private var selectedPhase: String

    init(userPosesByPhase: [String: [String: JointPosition]],
         reference: ReferenceExemplar,
         report: ComparisonReport) {
        self.userPosesByPhase = userPosesByPhase
        self.reference = reference
        self.report = report
        _selectedPhase = State(initialValue: report.phases.first?.phase ?? "ready")
    }

    private var phaseReport: PhaseComparison? {
        report.phases.first { $0.phase == selectedPhase }
    }

    private var highlightedJoints: Set<String> {
        // Highlight joints tied to features that are out of range this phase.
        var s: Set<String> = []
        for f in phaseReport?.features ?? [] where f.status == "below" || f.status == "above" {
            switch f.feature {
            case "right_elbow_angle_deg": s.formUnion(["right_shoulder", "right_elbow", "right_wrist"])
            case "right_knee_angle_deg":  s.formUnion(["right_hip", "right_knee", "right_ankle"])
            case "hip_shoulder_separation_deg": s.formUnion(["left_shoulder", "right_shoulder", "left_hip", "right_hip"])
            case "wrist_height_rel_torso", "arm_extension_rel_torso": s.formUnion(["right_shoulder", "right_wrist"])
            default: break
            }
        }
        return s
    }

    var body: some View {
        VStack(spacing: 12) {
            phasePicker

            HStack(spacing: 8) {
                panel(title: "You", joints: userPosesByPhase[selectedPhase] ?? [:],
                      tint: .blue, highlight: highlightedJoints)
                panel(title: "Reference (generic)",
                      joints: reference.phase(selectedPhase)?.pose ?? [:],
                      tint: .teal, highlight: [])
            }
            .frame(height: 240)

            scoreBar
            deltaList

            Text("Reference is a pose-only generic exemplar — not a named athlete. Skeletons are compared by range and delta, not pixel overlay.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Compare")
    }

    private var phasePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(report.phases, id: \.phase) { p in
                    Button {
                        selectedPhase = p.phase
                    } label: {
                        Text(p.phase.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedPhase == p.phase ? Color.blue.opacity(0.18) : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedPhase == p.phase ? Color.blue : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func panel(title: String, joints: [String: JointPosition], tint: Color, highlight: Set<String>) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            SkeletonCanvas(joints: joints, highlight: highlight, tint: tint)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var scoreBar: some View {
        if let pr = phaseReport, pr.measured {
            let score = pr.phaseScore
            let color: Color = score >= 80 ? .green : (score >= 60 ? .orange : .red)
            HStack {
                Text("Phase match").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(score.rounded()))").font(.title3.bold()).foregroundStyle(color)
            }
        } else {
            Text("Not enough confident pose data for this phase.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var deltaList: some View {
        VStack(spacing: 6) {
            ForEach(phaseReport?.features ?? [], id: \.feature) { f in
                HStack {
                    Text(label(for: f.feature)).font(.callout)
                    Spacer()
                    if let v = f.userValue {
                        Text(verbatim: "\(trim(v)) (ideal \(trim(f.idealMin))–\(trim(f.idealMax)))")
                            .font(.caption).foregroundStyle(.secondary)
                        statusChip(f.status)
                    } else {
                        Text("low confidence").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func statusChip(_ status: String) -> some View {
        let color: Color = status == "within" ? .green : .orange
        let text = status == "within" ? "in range" : status
        return Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.18)).foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func label(for feature: String) -> String {
        switch feature {
        case "right_elbow_angle_deg": return "Elbow angle"
        case "right_knee_angle_deg": return "Knee bend"
        case "hip_shoulder_separation_deg": return "Hip/shoulder turn"
        case "wrist_height_rel_torso": return "Wrist height"
        case "arm_extension_rel_torso": return "Arm extension"
        default: return feature
        }
    }

    private func trim(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }
}

// MARK: - Preview (SCA-1866 two-panel render verification)

/// A small synthetic frontal skeleton (Vision space, 0–1, bottom-left origin)
/// so the preview lays out without any bundled asset or capture pipeline.
private func previewSamplePose() -> [String: JointPosition] {
    func j(_ x: Float, _ y: Float) -> JointPosition { JointPosition(x: x, y: y, confidence: 0.9) }
    return [
        "nose": j(0.50, 0.92), "neck": j(0.50, 0.82),
        "left_shoulder": j(0.42, 0.80), "right_shoulder": j(0.58, 0.80),
        "left_elbow": j(0.38, 0.68), "right_elbow": j(0.63, 0.69),
        "left_wrist": j(0.36, 0.56), "right_wrist": j(0.68, 0.60),
        "left_hip": j(0.45, 0.55), "right_hip": j(0.55, 0.55),
        "left_knee": j(0.44, 0.35), "right_knee": j(0.56, 0.35),
        "left_ankle": j(0.43, 0.15), "right_ankle": j(0.57, 0.15),
    ]
}

#Preview("You | Reference (generic)") {
    let phase = "contact"
    let reference = ReferenceExemplar(
        id: "exemplar-generic-pose-forehand-v0",
        strokeType: "forehand_drive",
        rightsStatus: "cleared-public",
        usageScope: "bundled-app",
        source: "hand-authored generic exemplar (preview)",
        description: "Pose-only generic exemplar — not a named athlete.",
        phases: [
            ReferencePhase(
                phase: phase,
                pose: previewSamplePose(),
                ranges: [
                    "right_elbow_angle_deg": ReferenceRange(idealMin: 150, idealMax: 175),
                    "right_knee_angle_deg": ReferenceRange(idealMin: 150, idealMax: 172),
                ]
            )
        ]
    )
    let report = ComparisonReport(
        strokeType: "forehand_drive",
        referenceId: reference.id,
        referenceRightsStatus: "cleared-public",
        method: "range_delta_on_scale_normalized_features",
        ghostOverlay: false,
        alignment: "phase_keyed_not_pixel",
        minJointConfidence: 0.5,
        phases: [
            PhaseComparison(
                phase: phase,
                userFrameCount: 5,
                features: [
                    FeatureComparison(feature: "right_elbow_angle_deg", userValue: 142, idealMin: 150, idealMax: 175, delta: -8, status: "below", featureScore: 0.68),
                    FeatureComparison(feature: "right_knee_angle_deg", userValue: 160, idealMin: 150, idealMax: 172, delta: 0, status: "within", featureScore: 1.0),
                ],
                phaseScore: 84.0,
                measured: true
            )
        ],
        overallScore: 84.0,
        measuredPhaseCount: 1,
        notes: ["Preview: range/delta comparison, no ghost overlay."]
    )
    return NavigationStack {
        SideBySideComparisonView(
            userPosesByPhase: [phase: previewSamplePose()],
            reference: reference,
            report: report
        )
    }
}
