import SwiftUI

struct ReviewPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Clip review and coaching feedback will appear here (Milestone 4–5)")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ReviewPlaceholderView()
    }
}
