import SwiftUI

// MARK: - SCA-1868 — Compare entry point
//
// The real "Compare" destination that replaces ReviewPlaceholderView. It loads a
// session's analyzed pose data from disk, builds the ComparisonEngine inputs via
// ComparisonInputBuilder, runs the comparison against the bundled generic
// reference exemplar for the selected stroke type, and renders the two-panel
// SideBySideComparisonView ("You | Reference (generic)").
//
// Stroke type is user-selectable (forehand / backhand) so both bundled
// references are reachable; it defaults from the analysis result's shotType when
// that is known.

struct ComparisonContainerView: View {
    let session: Session

    @State private var poses: [PhasePose] = []
    @State private var strokeType: StrokeType = .forehand
    @State private var loadState: LoadState = .loading

    enum StrokeType: String, CaseIterable, Identifiable {
        case forehand, backhand
        var id: String { rawValue }
        var title: String { self == .forehand ? "Forehand" : "Backhand" }
        var shotType: String { self == .forehand ? "forehand_drive" : "backhand_drive" }
    }

    enum LoadState: Equatable { case loading, noData, ready }

    var body: some View {
        Group {
            switch loadState {
            case .loading: loadingView
            case .noData:  noDataView
            case .ready:   comparisonView
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadPoses() }
    }

    // MARK: - States

    private var loadingView: some View {
        ProgressView("Loading analysis…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.tennis")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Analyze this clip first")
                .font(.headline)
            Text("Run Analyze on this session to extract pose data, then come back to compare it against the reference.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var comparisonView: some View {
        if let inputs = buildInputs() {
            ScrollView {
                VStack(spacing: 16) {
                    strokePicker
                    SideBySideComparisonView(
                        userPosesByPhase: inputs.user,
                        reference: inputs.reference,
                        report: inputs.report
                    )
                    .id(strokeType)   // rebuild phase selection when the reference changes
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Reference unavailable")
                    .font(.headline)
                Text("The bundled \(strokeType.title.lowercased()) reference could not be loaded.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var strokePicker: some View {
        Picker("Stroke", selection: $strokeType) {
            ForEach(StrokeType.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Build engine inputs

    private struct Inputs {
        let user: [String: [String: JointPosition]]
        let reference: ReferenceExemplar
        let report: ComparisonReport
    }

    private func buildInputs() -> Inputs? {
        let name = ComparisonInputBuilder.exemplarResourceName(forShotType: strokeType.shotType)
        guard let reference = try? ReferenceExemplar.load(named: name) else { return nil }
        let report = ComparisonEngine().compare(user: poses, reference: reference)
        let user = ComparisonInputBuilder.userPosesByPhase(from: poses)
        return Inputs(user: user, reference: reference, report: report)
    }

    // MARK: - Load analyzed pose data

    private func loadPoses() {
        guard loadState == .loading else { return }
        guard let loaded = Self.loadAnalysis(sessionId: session.id) else {
            loadState = .noData
            return
        }
        poses = loaded.poses
        if let shot = loaded.shotType {
            strokeType = shot.lowercased().contains("backhand") ? .backhand : .forehand
        }
        loadState = poses.isEmpty ? .noData : .ready
    }

    /// Resolves a session's analyzed pose data from the Documents directory.
    /// Prefers a full PoseAnalysisResult (`pose-analysis-<id>.json`, which also
    /// carries the stroke type and any per-sample phase labels); falls back to the
    /// raw pose timeline written by the extraction pipeline
    /// (`pose-timeline-<id>.json`).
    private static func loadAnalysis(sessionId: UUID) -> (poses: [PhasePose], shotType: String?)? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let analysisURL = docs.appendingPathComponent("pose-analysis-\(sessionId.uuidString).json")
        if let data = try? Data(contentsOf: analysisURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let result = try? decoder.decode(PoseAnalysisResult.self, from: data) {
                return (ComparisonInputBuilder.phasePoses(from: result), result.shotType)
            }
        }

        let timelineURL = docs.appendingPathComponent("pose-timeline-\(sessionId.uuidString).json")
        if let data = try? Data(contentsOf: timelineURL),
           let frames = try? JSONDecoder().decode([PoseFrame].self, from: data) {
            return (ComparisonInputBuilder.phasePoses(fromFrames: frames), nil)
        }

        return nil
    }
}
