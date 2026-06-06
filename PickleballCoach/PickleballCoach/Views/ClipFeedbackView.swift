import SwiftUI

// SCA-1863 — Coaching feedback screen for the MVP demo path.
// Renders ClipFeedback cards produced by FeedbackEngine (real or mock).
// The disclaimer at the bottom satisfies the SCA-1863 M6 acceptance criterion.
struct ClipFeedbackView: View {
    let feedbackCards: [ClipFeedback]

    /// The "one thing to practice" the G6 recall gate measures: the top
    /// recommendation, i.e. the first card carrying an improvement observation
    /// ordered by phaseIndex (matches Gate 4's top-recommendation definition).
    private var topCardID: ClipFeedback.ID? {
        feedbackCards
            .sorted { $0.phaseIndex < $1.phaseIndex }
            .first { $0.primaryObservation?.severity == .improvement }?
            .id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(feedbackCards) { card in
                    FeedbackCardRow(card: card, isTopRecommendation: card.id == topCardID)
                }
                disclaimerBanner
            }
            .padding()
        }
        .navigationTitle("Coaching Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var disclaimerBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("AI-generated coaching feedback — not medical or professional advice.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Card row

private struct FeedbackCardRow: View {
    let card: ClipFeedback
    /// Top recommendation card — gets the "one thing to practice" banner and
    /// an accent border so the drill the G6 gate measures is unmistakable.
    var isTopRecommendation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isTopRecommendation, card.primaryObservation != nil {
                topRecommendationBadge
            }
            phaseHeader
            if let obs = card.primaryObservation {
                observationBody(obs)
            } else if let note = card.insufficientDataNote {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isTopRecommendation ? Color.blue : Color.clear,
                              lineWidth: isTopRecommendation ? 2 : 0)
        )
    }

    private var topRecommendationBadge: some View {
        Label("The one thing to practice today", systemImage: "star.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.blue)
            .textCase(.uppercase)
    }

    private var phaseHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.phaseTitle)
                    .font(.headline)
                Text(card.scoreDimensionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if card.score >= 0 {
                Text("\(card.score)")
                    .font(.title2).bold()
                    .foregroundStyle(scoreColor)
            }
        }
    }

    private var scoreColor: Color {
        switch card.score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private func observationBody(_ obs: FeedbackObservation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(obs.observation, systemImage: severityIcon(obs.severity))
                .foregroundStyle(severityColor(obs.severity))
                .font(.subheadline)
            if !obs.correction.isEmpty {
                Text("Fix: \(obs.correction)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !obs.drill.isEmpty {
                drillCallout(obs.drill)
            }
        }
    }

    /// Prominent "Practice this" CTA — the drill is the recall target of the
    /// G6 gate, so it is the visual hero of the card: bold label, headline-weight
    /// drill text, accent-tinted block. (SCA-1872)
    private func drillCallout(_ drill: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Practice this", systemImage: "figure.pickleball")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.blue)
            Text(drill)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
        )
    }

    private func severityIcon(_ s: FeedbackSeverity) -> String {
        switch s {
        case .strength:    return "checkmark.circle.fill"
        case .improvement: return "arrow.up.circle.fill"
        case .neutral:     return "circle.fill"
        }
    }

    private func severityColor(_ s: FeedbackSeverity) -> Color {
        switch s {
        case .strength:    return .green
        case .improvement: return .orange
        case .neutral:     return .gray
        }
    }
}

// MARK: - Preview

#Preview("Coaching Feedback — Mock") {
    let session = Session(title: "Demo session")
    let engine = MockFeedbackEngine()
    let stub = PoseAnalysisResult(
        sessionId: session.id,
        shotType: "forehand_drive",
        analyzedAt: Date(),
        videoPath: "",
        videoDurationSeconds: 8.0,
        originalFrameCount: 240,
        samplingInterval: 5,
        sampledFrameCount: 48,
        jointSamples: [],
        confidenceReport: ConfidenceReport(
            jointReliability: [:],
            contactZoneReliable: true,
            overallReliable: true,
            notes: []
        )
    )
    return NavigationStack {
        ClipFeedbackView(feedbackCards: engine.generateFeedback(from: stub))
    }
}
