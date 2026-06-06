import SwiftUI

struct AnalysisProgressView: View {
    let session: Session

    @State private var result: PoseAnalysisResult?
    @State private var error: String?
    @State private var analysisStarted = false

    var body: some View {
        Group {
            if let result {
                PoseResultView(result: result)
            } else if let error {
                errorView(message: error)
            } else {
                runningView
            }
        }
        .navigationTitle(result != nil ? "Pose Analysis" : "Analyzing…")
        .navigationBarTitleDisplayMode(.inline)
        .task { await runAnalysis() }
    }

    // MARK: - States

    private var runningView: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.large)
            Text("Extracting body pose…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

        let service = PoseCaptureService()
        do {
            let analysis = try await service.analyze(videoURL: url, sessionId: session.id)
            persist(analysis)
            result = analysis
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func persist(_ analysis: PoseAnalysisResult) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(analysis) else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let file = docs.appendingPathComponent("pose-\(analysis.id.uuidString).json")
        try? data.write(to: file, options: .atomic)
    }
}

// MARK: - Result display

private struct PoseResultView: View {
    let result: PoseAnalysisResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                reliabilityCard
                if let midSample = midSample {
                    skeletonCard(sample: midSample)
                }
                notesCard
            }
            .padding()
        }
    }

    // Representative frame near estimated contact (middle third).
    private var midSample: JointSample? {
        let idx = result.jointSamples.count / 2
        return result.jointSamples.indices.contains(idx) ? result.jointSamples[idx] : nil
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary").font(.headline)
            InfoRow(label: "Shot type",
                    value: result.shotType.replacingOccurrences(of: "_", with: " ").capitalized)
            InfoRow(label: "Video duration",
                    value: String(format: "%.1f s", result.videoDurationSeconds))
            InfoRow(label: "Frames analyzed",
                    value: "\(result.sampledFrameCount) of \(result.originalFrameCount) (\(result.samplingInterval)× skip)")
            InfoRow(label: "Overall reliable",
                    value: result.confidenceReport.overallReliable ? "Yes ✓" : "No ✗")
            InfoRow(label: "Contact zone",
                    value: result.confidenceReport.contactZoneReliable ? "Reliable ✓" : "Marginal — use 60fps")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var reliabilityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Joint Reliability").font(.headline)
            ForEach(result.confidenceReport.jointReliability.keys.sorted(), id: \.self) { key in
                if let r = result.confidenceReport.jointReliability[key] {
                    HStack {
                        Circle()
                            .fill(confidenceColor(r.meanConfidence))
                            .frame(width: 8, height: 8)
                        Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0f%%", r.meanConfidence * 100))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func skeletonCard(sample: JointSample) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "Skeleton at %.2f s (contact zone)", sample.timestamp))
                .font(.headline)
            PoseOverlayView(sample: sample)
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

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            ForEach(result.confidenceReport.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func confidenceColor(_ c: Float) -> Color {
        c >= 0.7 ? .green : (c >= 0.5 ? .orange : .red)
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
    }
}
