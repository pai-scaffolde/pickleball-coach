import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// Presents the system photo picker filtered to videos, copies the selected
/// video into the app's Documents directory, and creates a new Session.
struct ImportVideoView: View {
    /// When set, the picked clip replaces the video on this existing session and
    /// increments its capture-attempt count (SCA-1870 Gate 1) instead of creating
    /// a new session. Used by the quality-gate "try again" re-import path.
    var reimportSessionID: UUID? = nil

    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoPicker(
                    isImporting: $isImporting,
                    onComplete: handlePickedVideo,
                    onError: presentError,
                    onCancel: { dismiss() }
                )
                .ignoresSafeArea()

                if isImporting {
                    Color(.systemBackground).opacity(0.85)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Importing video…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import Video")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Import Failed", isPresented: $showError, actions: {
                Button("OK", role: .cancel) { dismiss() }
            }, message: {
                Text(errorMessage ?? "Something went wrong while importing the video.")
            })
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
        isImporting = false
    }

    /// Copies the picked video URL into Documents and records a Session.
    private func handlePickedVideo(_ sourceURL: URL) {
        isImporting = true
        let fileName = "\(UUID().uuidString).\(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)"
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask)[0]
        let destURL = documents.appendingPathComponent(fileName)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                let asset = AVURLAsset(url: destURL)
                let duration = CMTimeGetSeconds(asset.duration)
                let safeDuration = duration.isFinite ? duration : 0

                DispatchQueue.main.async {
                    if let reimportSessionID {
                        store.reimport(sessionID: reimportSessionID,
                                       videoFileName: fileName,
                                       durationSeconds: safeDuration)
                    } else {
                        store.add(Session(
                            title: defaultTitle(),
                            status: .imported,
                            videoFileName: fileName,
                            durationSeconds: safeDuration
                        ))
                    }
                    isImporting = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    presentError("Could not save the selected video: \(error.localizedDescription)")
                }
            }
        }
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Session \(formatter.string(from: Date()))"
    }
}

/// UIViewControllerRepresentable wrapper around PHPickerViewController.
private struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var isImporting: Bool
    let onComplete: (URL) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.onCancel()
                return
            }

            let provider = result.itemProvider
            let movieType = UTType.movie.identifier

            guard provider.hasItemConformingToTypeIdentifier(movieType) else {
                parent.onError("The selected item is not a supported video format.")
                return
            }

            parent.isImporting = true

            // loadFileRepresentation hands us a temporary URL that is removed
            // when the completion handler returns, so the copy must happen
            // synchronously inside onComplete.
            provider.loadFileRepresentation(forTypeIdentifier: movieType) { url, error in
                if let error {
                    DispatchQueue.main.async {
                        self.parent.onError("Failed to load video: \(error.localizedDescription)")
                    }
                    return
                }
                guard let url else {
                    DispatchQueue.main.async {
                        self.parent.onError("Could not access the selected video.")
                    }
                    return
                }

                // Copy to a stable temp location synchronously before the
                // provider's temporary file is reclaimed.
                let tempDir = FileManager.default.temporaryDirectory
                let stagedURL = tempDir.appendingPathComponent(
                    "staged-\(UUID().uuidString).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)"
                )
                do {
                    if FileManager.default.fileExists(atPath: stagedURL.path) {
                        try FileManager.default.removeItem(at: stagedURL)
                    }
                    try FileManager.default.copyItem(at: url, to: stagedURL)
                    DispatchQueue.main.async {
                        self.parent.onComplete(stagedURL)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.onError("Could not read the selected video: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
