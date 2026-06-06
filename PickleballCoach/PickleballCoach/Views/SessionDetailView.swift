import SwiftUI
import AVKit

struct SessionDetailView: View {
    @EnvironmentObject var store: SessionStore
    @State private var session: Session
    @State private var player: AVPlayer?

    init(session: Session) {
        _session = State(initialValue: session)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if session.isDemo {
                    demoBanner
                }
                videoSection
                titleSection
                metadataSection
                actionSection
            }
            .padding()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: configurePlayer)
        .onDisappear { player?.pause() }
    }

    // MARK: - Sections

    private var demoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sample session")
                    .font(.subheadline.weight(.semibold))
                Text("A bundled demo built from a generic reference stroke — no video of your own. Swipe to delete it from Sessions anytime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(.tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample session. A bundled demo built from a generic reference stroke. Swipe to delete it from Sessions anytime.")
    }

    @ViewBuilder
    private var videoSection: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 240)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No video available")
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Session title", text: $session.title)
                .textFieldStyle(.roundedBorder)
                .onSubmit { store.update(session) }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledRow(label: "Date",
                       value: Self.dateFormatter.string(from: session.createdAt))
            LabeledRow(label: "Status", value: session.status.displayName)
            if let duration = session.durationSeconds, duration > 0 {
                LabeledRow(label: "Duration", value: formatDuration(duration))
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            // A demo session ships pre-analyzed, so lead with what it can show
            // rather than re-running analysis on a session with no video.
            if !session.isDemo {
                NavigationLink {
                    AnalysisProgressView(session: session)
                } label: {
                    Label("Analyze", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if let score = session.mechanicsScores.first {
                let link = NavigationLink {
                    MechanicsScorecardView(score: score, frames: loadFrames())
                } label: {
                    Label("Mechanics Score", systemImage: "chart.bar.doc.horizontal")
                        .frame(maxWidth: .infinity)
                }
                // Lead with the scorecard on the demo (its primary payoff).
                if session.isDemo {
                    link.buttonStyle(.borderedProminent)
                } else {
                    link.buttonStyle(.bordered)
                }
            }

            // SCA-1890: route to the coaching feedback screen so the prominent
            // "Practice this" drill (the G6 recall target) is user-reachable.
            let feedbackLink = NavigationLink {
                ClipFeedbackView(feedbackCards: feedbackCards)
            } label: {
                Label("Review Coaching Feedback", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity)
            }
            if session.isDemo {
                feedbackLink.buttonStyle(.borderedProminent)
            } else {
                feedbackLink.buttonStyle(.bordered)
            }

            NavigationLink {
                ComparisonContainerView(session: session)
            } label: {
                Label("Compare", systemImage: "figure.tennis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func configurePlayer() {
        guard player == nil, let url = session.videoURL() else { return }
        player = AVPlayer(url: url)
    }

    /// Coaching feedback cards rendered by ClipFeedbackView. The analyze→feedback
    /// pipeline is still placeholder, so this produces deterministic demo feedback
    /// (the same MockFeedbackEngine path RepClipsView uses) — enough for the
    /// prominent "Practice this" drill to be reachable (SCA-1890). Real rule-based
    /// feedback wiring follows the analyze pipeline.
    private var feedbackCards: [ClipFeedback] {
        let stub = PoseAnalysisResult(
            sessionId: session.id,
            shotType: "forehand_drive",
            analyzedAt: Date(),
            videoPath: "",
            videoDurationSeconds: session.durationSeconds ?? 8.0,
            originalFrameCount: 0,
            samplingInterval: 5,
            sampledFrameCount: 0,
            jointSamples: [],
            confidenceReport: ConfidenceReport(
                jointReliability: [:],
                contactZoneReliable: true,
                overallReliable: true,
                notes: []
            )
        )
        return MockFeedbackEngine().generateFeedback(from: stub)
    }

    /// Loads the session's pose timeline from Documents so the scorecard can draw
    /// the contact key-frame skeleton. Returns [] if the timeline isn't on disk
    /// (the scorecard still renders its category rows from the stored score).
    private func loadFrames() -> [PoseFrame] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("pose-timeline-\(session.id.uuidString).json")
        guard let data = try? Data(contentsOf: url),
              let frames = try? JSONDecoder().decode([PoseFrame].self, from: data) else {
            return []
        }
        return frames
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
