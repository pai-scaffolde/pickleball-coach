import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: SessionStore
    @State private var showingImport = false
    @State private var showingOnboarding = false
    @State private var showingShotLibrary = false
    @State private var presentedSession: Session?
    @State private var sampleError: String?

    private var sortedSessions: [Session] {
        store.sessions.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedSessions.isEmpty {
                    emptyState
                } else {
                    populatedHome
                }
            }
            .navigationTitle("Pickleball Coach")
            .toolbar {
                // SCA-1906: the onboarding flow must stay reachable once sessions
                // are seeded — otherwise there's no way to navigate back to it from
                // the Sessions screen. This presents it as a dismissable sheet.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingOnboarding = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How it works")
                }
                // SCA-1911: the "Shots to Practice" catalogue must be reachable
                // from the home screen — it's the library of clean example shots
                // a player watches and mimics.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingShotLibrary = true
                    } label: {
                        Image(systemName: "rectangle.stack.badge.play")
                    }
                    .accessibilityLabel("Shots to Practice")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImport = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import Video")
                }
            }
            .sheet(isPresented: $showingImport) {
                ImportVideoView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingShotLibrary) {
                ShotLibraryView { showingShotLibrary = false }
            }
            .sheet(isPresented: $showingOnboarding) {
                onboardingSheet
            }
            .navigationDestination(item: $presentedSession) { session in
                SessionDetailView(session: session)
                    .environmentObject(store)
            }
            .alert("Sample unavailable", isPresented: sampleErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sampleError ?? "")
            }
        }
    }

    private var sampleErrorBinding: Binding<Bool> {
        Binding(get: { sampleError != nil }, set: { if !$0 { sampleError = nil } })
    }

    /// Builds (or refreshes) the bundled rights-clean sample session and opens it.
    /// Idempotent: the demo has a stable id, so re-tapping reuses the same row.
    private func startDemo() {
        do {
            let demo = try DemoSessionService.makeDemoSession()
            if store.sessions.contains(where: { $0.id == demo.id }) {
                store.update(demo)
            } else {
                store.add(demo)
            }
            presentedSession = demo
        } catch {
            sampleError = error.localizedDescription
        }
    }

    /// SCA-1909: stages a bundled REAL clip as an `.imported` session and opens it,
    /// so tapping "Analyze" in the detail screen runs the genuine
    /// PoseExtractionService → CaptureQualityGate → MechanicsScoringEngine pipeline.
    /// The synthetic demo above is pre-scored and bypasses that path; this is the
    /// only in-app affordance that exercises the real Vision pipeline end-to-end.
    /// Idempotent via the staged session's stable id.
    private func startStagedClip() {
        do {
            let staged = try StagedClipService.makeStagedSession()
            if store.sessions.contains(where: { $0.id == staged.id }) {
                store.update(staged)
            } else {
                store.add(staged)
            }
            presentedSession = staged
        } catch {
            sampleError = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 28) {
            onboardingContent

            VStack(spacing: 12) {
                actionButtons

                shotLibraryButton

                Text("No video needed — explore a sample stroke first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The welcome + 3-step explainer, shared between the first-launch empty state
    /// and the "How it works" sheet (SCA-1906) so the onboarding flow stays
    /// reachable from the Sessions screen.
    @ViewBuilder
    private var onboardingContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "figure.pickleball")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                Text("Welcome to Pickleball Coach")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Import a practice clip and get instant pose analysis, rep-by-rep feedback, and a mechanics score.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 16) {
                onboardingStep(number: 1, icon: "photo.on.rectangle.angled",
                               title: "Pick a video",
                               detail: "Choose a practice clip from your Photos library.")
                onboardingStep(number: 2, icon: "waveform.path.ecg",
                               title: "We analyze it",
                               detail: "Vision tracks your pose and segments each rep automatically.")
                onboardingStep(number: 3, icon: "chart.bar.doc.horizontal",
                               title: "Get coached",
                               detail: "See mechanics scores and side-by-side comparisons against an ideal stroke.")
            }
            .padding(.horizontal, 36)
        }
    }

    /// Onboarding presented as a dismissable sheet from the Sessions screen so the
    /// user can always navigate back to the explainer and the demo/import CTAs
    /// (SCA-1906: there was previously no way off the Sessions screen).
    private var onboardingSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    onboardingContent

                    Text("Use the buttons on the Sessions screen to import a clip or try the sample.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingOnboarding = false }
                }
            }
        }
    }

    /// The two primary calls-to-action shown on the home screen, shared between
    /// the first-launch empty state and the populated home (where staged
    /// sessions already exist). Keeping these always visible is the fix for
    /// SCA-1906: the demo button must be reachable even once sessions are seeded.
    @ViewBuilder
    private var actionButtons: some View {
        Button {
            showingImport = true
        } label: {
            Label("Import a Video", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Opens your photo library to choose a practice video")

        Button {
            startDemo()
        } label: {
            Label("Try the Demo", systemImage: "play.circle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Opens a bundled sample session with a scorecard and side-by-side comparison")

        Button {
            startStagedClip()
        } label: {
            Label("Try a Real Clip", systemImage: "video.badge.waveform")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Stages a bundled real pickleball clip so Analyze runs the full pose-analysis pipeline")
    }

    /// SCA-1911: entry point to the "Shots to Practice" catalogue — the library
    /// of clean example shots a player watches and mimics. Kept additive and
    /// separate from the board-locked import/demo CTAs above.
    private var shotLibraryButton: some View {
        Button {
            showingShotLibrary = true
        } label: {
            Label("Shots to Practice", systemImage: "rectangle.stack.badge.play")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Opens a catalogue of example shots to watch and mimic")
    }

    /// Home screen shown once sessions exist: the demo/import CTAs stay pinned at
    /// the top so the demo is always one tap away, with staged sessions below.
    private var populatedHome: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                actionButtons

                shotLibraryButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            sessionList
        }
    }

    private func onboardingStep(number: Int, icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(detail)")
    }

    private var sessionList: some View {
        List {
            Section("Your Sessions") {
                ForEach(sortedSessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                            .environmentObject(store)
                    } label: {
                        SessionRow(session: session)
                    }
                }
                .onDelete(perform: deleteSorted)
            }
        }
    }

    /// Maps deletions from the sorted view back to indices in the store's array.
    private func deleteSorted(at offsets: IndexSet) {
        let idsToDelete = offsets.map { sortedSessions[$0].id }
        let storeOffsets = IndexSet(
            store.sessions.enumerated()
                .filter { idsToDelete.contains($0.element.id) }
                .map { $0.offset }
        )
        store.delete(at: storeOffsets)
    }
}

private struct SessionRow: View {
    let session: Session

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title.isEmpty ? "Untitled Session" : session.title)
                .font(.headline)
            Text(Self.dateFormatter.string(from: session.createdAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(session.status.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch session.status {
        case .imported: return .blue
        case .analyzing: return .orange
        case .ready: return .green
        case .failed: return .red
        }
    }
}
