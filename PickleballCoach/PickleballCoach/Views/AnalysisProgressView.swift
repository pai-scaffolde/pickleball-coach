import SwiftUI

struct AnalysisProgressView: View {
    let session: Session

    @EnvironmentObject private var store: SessionStore
    @State private var frames: [PoseFrame]?
    @State private var qualityGateResult: CaptureQualityGate.GateResult?
    @State private var progress: PoseExtractionService.ExtractionProgress?
    @State private var error: String?
    @State private var analysisStarted = false
    @State private var showReimport = false

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
        .sheet(isPresented: $showReimport) {
            ImportVideoView(reimportSessionID: session.id)
                .environmentObject(store)
        }
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

                Button {
                    showReimport = true
                } label: {
                    Label("Record a new clip", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
            finishAnalysis(with: extracted)
        } catch PoseExtractionService.ExtractionError.noBodyDetected {
            // SCA-1910: Live Vision returned no body — happens on the simulator
            // where VNDetectHumanBodyPoseRequest produces no observations. For the
            // staged sample session only, fall back to the pre-baked timeline that
            // was extracted on macOS from the same bundled clip. These are genuine
            // Vision-extracted poses, just pre-computed; nothing is synthesized.
            if session.id == StagedClipService.stagedSessionID,
               let fallback = loadBundledTimeline() {
                finishAnalysis(with: fallback)
            } else {
                self.error = PoseExtractionService.ExtractionError.noBodyDetected.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Shared completion path for both the live extraction and the bundled fallback.
    private func finishAnalysis(with extracted: [PoseFrame]) {
        let gate = CaptureQualityGate.evaluate(extracted, videoDuration: session.durationSeconds)
        // SCA-1870 (Gate 1): record every gate evaluation with the current
        // attempt count and whether it was accepted. The value at the first
        // accepted attempt is what the 80%-within-2-attempts gate measures.
        CaptureAnalytics.shared.record(sessionId: session.id,
                                       captureAttemptCount: session.captureAttemptCount,
                                       accepted: gate.passed)
        qualityGateResult = gate
        guard gate.passed else { return }
        // SCA-1910: score the analyzed timeline so the Mechanics Score card and
        // button are available — the headline payoff the synthetic demo shows.
        // Mirrors DemoSessionService scoring (load the forehand exemplar, build a
        // ClipInterval for the scored rep, run MechanicsScoringEngine). This runs
        // on the live-Vision path too, so real on-device analyze yields a score
        // via the same code path.
        let score = computeScore(for: extracted)
        persist(extracted, score: score)
        frames = extracted
    }

    /// Computes a real MechanicsScore from the analyzed timeline. Picks the
    /// scored-rep window from SegmentationService when available (so the contact
    /// frame lands inside a real swing), and falls back to the full timeline.
    /// The engine's peak-wrist-speed selector resolves the contact frame; the
    /// returned keyFrameTimestamp stays aligned with the persisted timeline, so
    /// the scorecard's skeleton lookup resolves the contact pose. Returns nil if
    /// the bundled exemplar can't be loaded or no frame is measurable.
    private func computeScore(for extracted: [PoseFrame]) -> MechanicsScore? {
        guard let exemplar = try? ReferenceExemplar.load(named: "reference_forehand_drive_v0") else {
            return nil
        }

        // Prefer the highest-confidence segmented rep so the contact frame is
        // chosen from within a real swing; fall back to the full timeline window.
        let duration = session.durationSeconds ?? extracted.last?.timestamp ?? 0
        let segmentation = SegmentationService().segment(frames: extracted, videoDuration: duration)
        let topClip = segmentation.clips.max(by: { $0.confidence < $1.confidence })

        let start = topClip?.startTime ?? extracted.first?.timestamp ?? 0
        let end = topClip?.endTime ?? extracted.last?.timestamp ?? 0
        let scoringFrames = topClip == nil
            ? extracted
            : extracted.filter { $0.timestamp >= start && $0.timestamp <= end }

        let clip = ClipInterval(
            id: session.id,
            startTime: start,
            endTime: end,
            strokeType: exemplar.strokeType,
            confidence: topClip?.confidence ?? 1.0
        )
        return MechanicsScoringEngine().score(frames: scoringFrames, clip: clip, reference: exemplar)
    }

    /// Loads the bundled pre-baked pose timeline for the staged sample session.
    /// Returns nil if the resource is missing or fails to decode.
    private func loadBundledTimeline() -> [PoseFrame]? {
        guard let url = Bundle.main.url(forResource: "pose-timeline-navratil-v0",
                                        withExtension: "json") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([PoseFrame].self, from: data)
    }

    private func persist(_ frames: [PoseFrame], score: MechanicsScore? = nil) {
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
        // SCA-1910: attach the computed MechanicsScore (and its clip interval) so
        // the detail screen shows the score summary card and the Mechanics Score
        // button. Only attach a score with measurable categories.
        var updated = session
        updated.poseTimelineFileName = fileName
        updated.status = .ready
        if let score, !score.scores.isEmpty {
            updated.mechanicsScores = [score]
            updated.clipIntervals = [
                ClipInterval(id: score.clipId,
                             startTime: updated.clipIntervals.first?.startTime ?? frames.first?.timestamp ?? 0,
                             endTime: updated.clipIntervals.first?.endTime ?? frames.last?.timestamp ?? 0,
                             strokeType: score.strokeType,
                             confidence: 1.0)
            ]
        }
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
