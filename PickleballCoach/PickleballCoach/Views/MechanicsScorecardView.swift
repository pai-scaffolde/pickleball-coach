import SwiftUI

// MARK: - SCA-1861 — Forehand mechanics scorecard
//
// Renders a MechanicsScore: the skeleton overlay drawn on the CONTACT KEY FRAME
// (reusing PoseOverlayView — the same overlay primitive SCA-1824 uses, not a
// fork) plus one row per mechanics category showing the MEASURED value paired
// with the reference band (never a bare number) and a 0–100 category score.
struct MechanicsScorecardView: View {
    let score: MechanicsScore
    /// The pose timeline for the clip; the contact key frame is located by
    /// matching `score.keyFrameTimestamp`.
    let frames: [PoseFrame]

    private var keyFrame: PoseFrame? {
        guard score.keyFrameTimestamp >= 0 else { return nil }
        return frames.min(by: {
            abs($0.timestamp - score.keyFrameTimestamp) < abs($1.timestamp - score.keyFrameTimestamp)
        })
    }

    private var overall: Int {
        guard !score.scores.isEmpty else { return 0 }
        return Int((score.scores.values.reduce(0, +) / Double(score.scores.count)).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                keyFramePanel
                Divider()
                categories
            }
            .padding()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(score.strokeType.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.title2).bold()
            if score.keyFrameTimestamp >= 0 {
                Text("Overall \(overall)/100 · contact at \(String(format: "%.2f", score.keyFrameTimestamp))s")
                    .font(.subheadline).foregroundColor(.secondary)
            } else {
                Text("Not enough reliable pose data to score this clip")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
    }

    // MARK: Key-frame skeleton overlay

    @ViewBuilder private var keyFramePanel: some View {
        if let frame = keyFrame {
            VStack(alignment: .leading, spacing: 6) {
                Text("CONTACT KEY FRAME").font(.caption).foregroundColor(.secondary)
                ZStack {
                    Color.black.opacity(0.85)
                    PoseOverlayView(frame: frame)   // reused overlay primitive
                }
                .aspectRatio(0.75, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: Category rows (measured vs reference)

    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mechanics").font(.headline)
            ForEach(score.observations, id: \.ruleId) { obs in
                categoryRow(obs)
            }
        }
    }

    private func categoryRow(_ obs: FeedbackObservation) -> some View {
        let value = score.scores[obs.citedMetricName] ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(color(for: obs.severity)).frame(width: 8, height: 8)
                // obs.observation is already "label: measured / ideal min–max".
                Text(obs.observation).font(.subheadline)
                Spacer()
                Text("\(Int(value.rounded()))").font(.subheadline).bold()
                    .foregroundColor(color(for: obs.severity))
            }
            ProgressView(value: max(0, min(value, 100)), total: 100)
                .tint(color(for: obs.severity))
            if obs.severity != .strength {
                Text(obs.correction).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func color(for severity: FeedbackSeverity) -> Color {
        switch severity {
        case .strength:    return .green
        case .improvement: return .orange
        case .neutral:     return .gray
        }
    }
}
