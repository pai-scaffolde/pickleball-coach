import SwiftUI
import AVKit

// SCA-1862 — Rep clips player with slow-motion export and overlay.
//
// Shows segmented ClipIntervals for a session; each row plays the 4× slow-mo
// export with a pose-skeleton overlay drawn at the clip's key-frame pose.
// Low-confidence segments are clearly labelled.
struct RepClipsView: View {
    let session: Session
    let clips: [ClipInterval]
    let frames: [PoseFrame]
    let lowConfidenceReason: String?

    @State private var exportedURLs: [UUID: URL] = [:]
    @State private var exportingIDs: Set<UUID> = []
    @State private var exportErrors: [UUID: String] = [:]

    private var videoURL: URL? { session.videoURL() }

    private var mockFeedback: [ClipFeedback] {
        let engine = MockFeedbackEngine()
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
        return engine.generateFeedback(from: stub)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBanner
                reviewCoachingButton
                ForEach(clips) { clip in
                    clipCard(clip)
                }
                if clips.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Rep Clips")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Review coaching button

    private var reviewCoachingButton: some View {
        NavigationLink {
            ClipFeedbackView(feedbackCards: mockFeedback)
        } label: {
            Label("Review Coaching Feedback", systemImage: "list.bullet.clipboard")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Header

    @ViewBuilder private var headerBanner: some View {
        if let reason = lowConfidenceReason {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Clip card

    private func clipCard(_ clip: ClipInterval) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            clipMetaRow(clip)
            if let url = exportedURLs[clip.id] {
                videoWithOverlay(url: url, clip: clip)
            } else {
                exportButton(clip)
            }
            if let err = exportErrors[clip.id] {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func clipMetaRow(_ clip: ClipInterval) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.2f s – %.2f s", clip.startTime, clip.endTime))
                    .font(.subheadline).bold()
                Text(String(format: "Confidence: %.0f%%", clip.confidence * 100))
                    .font(.caption)
                    .foregroundStyle(clip.confidence < 0.4 ? .orange : .secondary)
            }
            Spacer()
            if clip.confidence < 0.4 {
                Label("Low confidence", systemImage: "exclamationmark.circle")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func videoWithOverlay(url: URL, clip: ClipInterval) -> some View {
        ZStack {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if let frame = keyFrame(for: clip) {
                PoseOverlayView(frame: frame)
                    .frame(height: 280)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 280)
    }

    private func exportButton(_ clip: ClipInterval) -> some View {
        Button {
            Task { await exportClip(clip) }
        } label: {
            HStack {
                if exportingIDs.contains(clip.id) {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "slowmo")
                }
                Text(exportingIDs.contains(clip.id) ? "Exporting…" : "Export 4× Slow-Mo")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(exportingIDs.contains(clip.id) || videoURL == nil)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No rep clips found")
                .font(.headline)
            Text(lowConfidenceReason ?? "Not enough motion signal to segment reps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Export

    @MainActor
    private func exportClip(_ clip: ClipInterval) async {
        guard let sourceURL = videoURL else { return }
        exportingIDs.insert(clip.id)
        exportErrors.removeValue(forKey: clip.id)

        let fileName = "slowmo-\(session.id.uuidString)-\(clip.id.uuidString).mov"
        let service = SlowMoExportService()
        do {
            let url = try await service.export(sourceURL: sourceURL, clip: clip, outputFileName: fileName)
            exportedURLs[clip.id] = url
        } catch {
            exportErrors[clip.id] = error.localizedDescription
        }
        exportingIDs.remove(clip.id)
    }

    // MARK: - Key-frame lookup

    // Returns the PoseFrame nearest the midpoint of the clip (representative stance).
    private func keyFrame(for clip: ClipInterval) -> PoseFrame? {
        let mid = (clip.startTime + clip.endTime) / 2.0
        return frames.min(by: { abs($0.timestamp - mid) < abs($1.timestamp - mid) })
    }
}

// MARK: - Preview

#Preview("Rep Clips") {
    let clip = ClipInterval(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001862")!,
        startTime: 0.4,
        endTime: 2.8,
        strokeType: "forehand_drive",
        confidence: 0.85
    )
    let lowClip = ClipInterval(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001863")!,
        startTime: 3.0,
        endTime: 3.3,
        strokeType: nil,
        confidence: 0.22
    )
    let session = Session(title: "Forehand session")
    return NavigationStack {
        RepClipsView(
            session: session,
            clips: [clip, lowClip],
            frames: [],
            lowConfidenceReason: nil
        )
    }
}
