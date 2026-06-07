import SwiftUI
import AVKit

struct SessionDetailView: View {
    @EnvironmentObject var store: SessionStore
    @State private var session: Session
    @State private var player: AVPlayer?

    init(session: Session) {
        _session = State(initialValue: session)
    }

    private var currentSession: Session {
        store.sessions.first { $0.id == session.id } ?? session
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
                if currentSession.isDemo {
                    demoBanner
                }
                videoSection
                titleSection
                summarySection
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
                Text("A bundled demo built from a generic reference stroke — the clip shows an idealized forehand, not video of your own. Swipe to delete it from Sessions anytime.")
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
        .accessibilityLabel("Sample session. A bundled demo built from a generic reference stroke — the clip shows an idealized forehand, not video of your own. Swipe to delete it from Sessions anytime.")
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
                       value: Self.dateFormatter.string(from: currentSession.createdAt))
            LabeledRow(label: "Status", value: currentSession.status.displayName)
            if let duration = currentSession.durationSeconds, duration > 0 {
                LabeledRow(label: "Duration", value: formatDuration(duration))
            }
        }
    }

    // MARK: - Summary (SCA-1908: surface accurate, informative details up front)
    //
    // The old detail screen showed only Date/Status/Duration — "very basic". This
    // pulls the actual analysis result forward: overall mechanics score + grade,
    // stroke, rep count, contact time, the single most useful coaching point, and
    // per-category score bars so the screen is informative at a glance.

    private var scored: MechanicsScore? { currentSession.mechanicsScores.first }

    @ViewBuilder
    private var summarySection: some View {
        if let score = scored, !score.scores.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                scoreHeader(score)
                if let obs = headlineObservation(score) {
                    headlineCard(obs)
                }
                categoryBars(score)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func scoreHeader(_ score: MechanicsScore) -> some View {
        let overall = overallScore(score)
        return HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 0) {
                Text("\(overall)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor(overall))
                Text("/ 100").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(strokeDisplay(score)).font(.title3.bold())
                Text("\(gradeLabel(overall)) · \(repCount) rep\(repCount == 1 ? "" : "s") · contact \(String(format: "%.2f", score.keyFrameTimestamp))s")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(strokeDisplay(score)) mechanics score \(overall) out of 100, \(gradeLabel(overall)), \(repCount) reps.")
    }

    private func headlineCard(_ obs: FeedbackObservation) -> some View {
        let improving = obs.severity == .improvement
        return VStack(alignment: .leading, spacing: 4) {
            Label(improving ? "Top focus" : "Strength",
                  systemImage: improving ? "target" : "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(improving ? .orange : .green)
            Text(obs.observation).font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if improving, !obs.correction.isEmpty {
                Text(obs.correction).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func categoryBars(_ score: MechanicsScore) -> some View {
        // Worst category first — shows where the score is being lost.
        let rows = score.scores.sorted { $0.value < $1.value }
        return VStack(spacing: 6) {
            ForEach(rows, id: \.key) { key, value in
                HStack(spacing: 10) {
                    Text(MechanicsScoringEngine.categoryLabel(key).capitalized)
                        .font(.caption)
                        .frame(width: 120, alignment: .leading)
                    ProgressView(value: max(0, min(1, value / 100)))
                        .tint(gradeColor(Int(value.rounded())))
                    Text("\(Int(value.rounded()))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }

    private func overallScore(_ score: MechanicsScore) -> Int {
        guard !score.scores.isEmpty else { return 0 }
        return Int((score.scores.values.reduce(0, +) / Double(score.scores.count)).rounded())
    }

    private func gradeColor(_ s: Int) -> Color { s >= 80 ? .green : (s >= 60 ? .orange : .red) }
    private func gradeLabel(_ s: Int) -> String { s >= 80 ? "Strong" : (s >= 60 ? "Solid" : "Needs work") }

    private func strokeDisplay(_ score: MechanicsScore) -> String {
        score.strokeType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// The single most useful coaching point: prefer an improvement, else a
    /// strength, else any observation.
    private func headlineObservation(_ score: MechanicsScore) -> FeedbackObservation? {
        score.observations.first { $0.severity == .improvement }
            ?? score.observations.first { $0.severity == .strength }
            ?? score.observations.first
    }

    /// Rep count from the on-disk pose timeline (falls back to stored clips).
    private var repCount: Int {
        let frames = loadFrames()
        guard !frames.isEmpty else { return max(currentSession.clipIntervals.count, 1) }
        let n = SegmentationService().segment(frames: frames,
                                              videoDuration: currentSession.durationSeconds ?? 0).clips.count
        return max(n, 1)
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            // A demo session ships pre-analyzed, so lead with what it can show
            // rather than re-running analysis on a session with no video.
            if !currentSession.isDemo {
                NavigationLink {
                    AnalysisProgressView(session: currentSession)
                } label: {
                    Label("Analyze", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            // SCA-1904: rep clips path — segment the pose timeline into reps and
            // offer per-rep 4× slow-mo export with the pose overlay.
            NavigationLink {
                repClipsDestination
            } label: {
                Label("Rep Clips", systemImage: "film.stack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let score = currentSession.mechanicsScores.first {
                let link = NavigationLink {
                    MechanicsScorecardView(score: score, frames: loadFrames())
                } label: {
                    Label("Mechanics Score", systemImage: "chart.bar.doc.horizontal")
                        .frame(maxWidth: .infinity)
                }
                // Lead with the scorecard on the demo (its primary payoff).
                if currentSession.isDemo {
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
            if currentSession.isDemo {
                feedbackLink.buttonStyle(.borderedProminent)
            } else {
                feedbackLink.buttonStyle(.bordered)
            }

            NavigationLink {
                ComparisonContainerView(session: currentSession)
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
            sessionId: currentSession.id,
            shotType: "forehand_drive",
            analyzedAt: Date(),
            videoPath: "",
            videoDurationSeconds: currentSession.durationSeconds ?? 8.0,
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

    /// Builds the rep-clips screen: loads the session's pose timeline, segments it
    /// into rep intervals, and hands the clips + frames to RepClipsView for slow-mo
    /// export with the pose overlay (SCA-1904).
    @ViewBuilder
    private var repClipsDestination: some View {
        let frames = loadFrames()
        let result = SegmentationService().segment(
            frames: frames,
            videoDuration: currentSession.durationSeconds ?? 0
        )
        RepClipsView(
            session: currentSession,
            clips: result.clips,
            frames: frames,
            lowConfidenceReason: result.lowConfidenceReason
        )
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
