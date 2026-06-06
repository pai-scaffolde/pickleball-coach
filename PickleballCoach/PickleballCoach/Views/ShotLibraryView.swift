import SwiftUI
import AVKit

// MARK: - SCA-1911 — Shots to Practice library
//
// The browsable catalogue of clean example shots. Players scroll the list, open
// a shot, watch the clip (or study the idealized reference skeleton when no
// rights-cleared clip is bundled), and read the cues to mimic.

struct ShotLibraryView: View {
    let catalog: PracticeShotCatalog
    var onClose: (() -> Void)?

    init(catalog: PracticeShotCatalog = .load(), onClose: (() -> Void)? = nil) {
        self.catalog = catalog
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Group {
                if catalog.shots.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(catalog.shots) { shot in
                                NavigationLink {
                                    ShotDetailView(shot: shot)
                                } label: {
                                    ShotRow(shot: shot)
                                }
                            }
                        } header: {
                            Text("Watch a clean example, then mimic it in your own practice.")
                                .font(.caption)
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("Shots to Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onClose)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.play")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No shots available yet")
                .font(.headline)
            Text("The practice-shot catalogue is empty.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShotRow: View {
    let shot: PracticeShot

    private var hasClip: Bool { shot.clipURL() != nil }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.tint.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: hasClip ? "play.circle.fill" : "figure.pickleball")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(shot.name)
                    .font(.headline)
                Text(shot.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(hasClip ? "Video clip" : "Pose reference")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(hasClip ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shot.name). \(shot.summary). \(hasClip ? "Has a video clip." : "Pose reference only.")")
    }
}

// MARK: - Shot detail

struct ShotDetailView: View {
    let shot: PracticeShot

    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mimicPanel

                HStack {
                    Text(shot.name)
                        .font(.title2.bold())
                    Spacer()
                    Text(strokeLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.12), in: Capsule())
                        .foregroundStyle(.tint)
                }

                Text(shot.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What to watch for")
                        .font(.headline)
                    ForEach(Array(shot.whatToWatch.enumerated()), id: \.offset) { _, cue in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                                .font(.system(size: 16))
                                .padding(.top, 1)
                            Text(cue)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(shot.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setUpPlayer)
        .onDisappear(perform: tearDownPlayer)
    }

    // The "shot to mimic" panel: the playable clip if rights permit bundling,
    // otherwise the idealized reference skeleton.
    @ViewBuilder
    private var mimicPanel: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else if let frame = shot.referenceFrame() {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                PoseOverlayView(frame: frame)
                    .padding(24)
            }
            .frame(height: 260)
            .overlay(alignment: .bottom) {
                Text("Idealized reference skeleton — mimic this shape")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 260)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No reference available")
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }

    private var strokeLabel: String {
        shot.strokeType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func setUpPlayer() {
        guard player == nil, let url = shot.clipURL() else { return }
        let p = AVPlayer(url: url)
        p.isMuted = true
        // Loop the clip so the player can study the motion repeatedly.
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
        player = p
        p.play()
    }

    private func tearDownPlayer() {
        player?.pause()
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
        loopObserver = nil
        player = nil
    }
}
