import SwiftUI

struct AnalysisProgressView: View {
    let session: Session

    @EnvironmentObject private var store: SessionStore
    @State private var frames: [PoseFrame]?
    @State private var qualityGateResult: CaptureQualityGate.GateResult?
    @State private var progress: PoseExtractionService.ExtractionProgress?
    @State private var error: String?
    @State private var analysisStarted = false

    var body: some View {
        Group {
            if let gateResult = qualityGateResult, !gateResult.passed {
                qualityRejectionView(gateResult: gateResult)
            } else if let frames {
                ExtractionResultView(frames: frames, videoDuration: session.durationSeconds)
            } else if let error {
                errorView(message: error)
            } else {
                runningView
            }
        }
        .navigationTitle(frames != nil ? "Pose Analysis" : "Analyzing…")
        .navigationBarTitleDisplayMode(.inline)
        .task { await runAnalysis() }
    }

    // MARK: - States

    private var runningView: some View {
        VStack(spacing: 20) {
            if let p = progress, p.totalFrames > 0, p.phase == .extracting {
                ProgressView(value: Double(p.framesProcessed), total: Double(p.totalFrames))
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 240)
            } else {
                ProgressView().controlSize(.large)
            }
            Text(progressMessage)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var progressMessage: String {
        guard let p = progress else { return "Loading video…" }
        switch p.phase {
        case .loading:
            return "Loading video…"
        case .extracting:
            return "Extracting… \(p.framesProcessed) / \(p.totalFrames) frames"
        case .complete:
            return "Finalizing…"
        }
    }

    private func qualityRejectionView(gateResult: CaptureQualityGate.GateResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clip quality too low")
                            .font(.headline)
                        Text("This clip can't be analyzed reliably. Record a new one using the tips below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !gateResult.fixInstructions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to fix it")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ForEach(Array(gateResult.fixInstructions.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                                    .font(.subheadline)
                                Text(tip)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Analysis failed")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Analysis

    private func runAnalysis() async {
        guard !analysisStarted else { return }
        analysisStarted = true

        guard let url = session.videoURL() else {
            error = "No video file associated with this session."
            return
        }

        let service = PoseExtractionService()
        do {
            let extracted = try await service.extract(videoURL: url) { p in
                Task { @MainActor in self.progress = p }
            }
            let gate = CaptureQualityGate.evaluate(extracted, videoDuration: session.durationSeconds)
            qualityGateResult = gate
            guard gate.passed else { return }
            persist(extracted)
            frames = extracted
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func persist(_ frames: [PoseFrame]) {
        let fileName = "pose-timeline-\(session.id.uuidString).json"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(frames) else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let file = docs.appendingPathComponent(fileName)
        try? data.write(to: file, options: .atomic)

        // SCA-1868: record the artifact and mark the session ready so the Compare
        // entry point can find this clip's pose data and the session reflects that
        // analysis completed.
        var updated = session
        updated.poseTimelineFileName = fileName
        updated.status = .ready
        store.update(updated)
    }
}

// MARK: - Result display

private struct ExtractionResultView: View {
    let frames: [PoseFrame]
    let videoDuration: Double?

    private var detectedFrames: [PoseFrame] {
        frames.filter(\.bodyDetected)
    }

    // Representative frame near estimated contact (middle of detected frames).
    private var representativeFrame: PoseFrame? {
        let detected = detectedFrames
        guard !detected.isEmpty else { return nil }
        return detected[detected.count / 2]
    }

    private var coveragePercent: Double {
        guard !frames.isEmpty else { return 0 }
        return Double(detectedFrames.count) / Double(frames.count) * 100
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                if let frame = representativeFrame {
                    skeletonCard(frame: frame)
                }
            }
            .padding()
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary").font(.headline)
            InfoRow(label: "Total frames", value: "\(frames.count)")
            InfoRow(label: "Body detected", value: "\(detectedFrames.count)")
            InfoRow(label: "Coverage", value: String(format: "%.0f%%", coveragePercent))
            InfoRow(label: "Video duration",
                    value: videoDuration.map { String(format: "%.1f s", $0) } ?? "—")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func skeletonCard(frame: PoseFrame) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "Skeleton at %.2fs", frame.timestamp))
                .font(.headline)
            PoseOverlayView(frame: frame)
                .frame(height: 300)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Green = confident  •  Orange = low confidence")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        AnalysisProgressView(session: Session(title: "Preview — no video"))
            .environmentObject(SessionStore())
    }
}
