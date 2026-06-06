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
            NavigationLink {
                AnalysisProgressView(session: session)
            } label: {
                Label("Analyze", systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink {
                ReviewPlaceholderView()
            } label: {
                Label("Review", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(session.status != .ready)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func configurePlayer() {
        guard player == nil, let url = session.videoURL() else { return }
        player = AVPlayer(url: url)
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
