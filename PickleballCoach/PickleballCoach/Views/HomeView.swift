import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: SessionStore
    @State private var showingImport = false

    private var sortedSessions: [Session] {
        store.sessions.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
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

            Button {
                showingImport = true
            } label: {
                Label("Import a Video", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 36)
            .accessibilityHint("Opens your photo library to choose a practice video")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
