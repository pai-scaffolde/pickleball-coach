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
        VStack(spacing: 12) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No sessions yet. Tap + to import a video.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
