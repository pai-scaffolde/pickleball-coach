import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: SessionStore
    @State private var showingImport = false
    @State private var demoSession: Session?
    @State private var demoError: String?

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
            .navigationDestination(item: $demoSession) { session in
                SessionDetailView(session: session)
                    .environmentObject(store)
            }
            .alert("Demo unavailable", isPresented: demoErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(demoError ?? "")
            }
        }
    }

    private var demoErrorBinding: Binding<Bool> {
        Binding(get: { demoError != nil }, set: { if !$0 { demoError = nil } })
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
            demoSession = demo
        } catch {
            demoError = error.localizedDescription
        }
    }

    private var emptyState: some View {
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

            VStack(spacing: 12) {
                actionButtons

                Text("No video needed — explore a sample stroke first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }

    /// Home screen shown once sessions exist: the demo/import CTAs stay pinned at
    /// the top so the demo is always one tap away, with staged sessions below.
    private var populatedHome: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                actionButtons
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
