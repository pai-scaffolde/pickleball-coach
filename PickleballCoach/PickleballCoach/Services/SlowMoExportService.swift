import Foundation
import AVFoundation

// Exports a time-trimmed, 4x slow-motion clip from a source video using
// AVMutableComposition + scaleTimeRange. The exported .mov file is written to
// the app's Documents directory and its URL is returned.
//
// Acceptance: exported duration = 4 × source-clip duration ±5%.
// AVPlayer must be able to initialize on the returned URL without error.
final class SlowMoExportService: Sendable {

    enum ExportError: LocalizedError {
        case sourceNotReadable
        case compositionFailed
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .sourceNotReadable:         return "Cannot open source video for slow-motion export."
            case .compositionFailed:          return "Failed to build slow-motion composition."
            case .exportFailed(let msg):      return "Export failed: \(msg)"
            }
        }
    }

    static let slowFactor: Double = 4.0    // 4× slow-motion
    static let outputPreset = AVAssetExportPresetHighestQuality

    // Exports one ClipInterval as a 4× slow-motion .mov.
    // outputFileName must be unique to avoid collisions when exporting multiple clips.
    func export(
        sourceURL: URL,
        clip: ClipInterval,
        outputFileName: String
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration: CMTime
        do { duration = try await asset.load(.duration) }
        catch { throw ExportError.sourceNotReadable }

        guard CMTimeGetSeconds(duration) > 0 else { throw ExportError.sourceNotReadable }

        let sourceStart = CMTime(seconds: clip.startTime, preferredTimescale: 600)
        let sourceEnd   = CMTime(seconds: min(clip.endTime, CMTimeGetSeconds(duration)),
                                 preferredTimescale: 600)
        let sourceDuration = CMTimeSubtract(sourceEnd, sourceStart)
        guard CMTimeGetSeconds(sourceDuration) > 0 else { throw ExportError.compositionFailed }

        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let audioTrackOrNil = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else { throw ExportError.compositionFailed }

        let sourceTimeRange = CMTimeRange(start: sourceStart, duration: sourceDuration)

        do {
            let srcVideoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let srcVideo = srcVideoTracks.first else { throw ExportError.sourceNotReadable }
            try videoTrack.insertTimeRange(sourceTimeRange, of: srcVideo, at: .zero)
        } catch is ExportError {
            throw ExportError.sourceNotReadable
        } catch {
            throw ExportError.sourceNotReadable
        }

        // Insert audio if available (optional — fails gracefully).
        let srcAudioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        if let srcAudio = srcAudioTracks.first {
            try? audioTrackOrNil.insertTimeRange(sourceTimeRange, of: srcAudio, at: .zero)
        }

        // Scale the inserted range to 4× duration (slow-motion).
        let slowDuration = CMTime(
            seconds: CMTimeGetSeconds(sourceDuration) * Self.slowFactor,
            preferredTimescale: 600
        )
        let insertedRange = CMTimeRange(start: .zero, duration: sourceDuration)
        composition.scaleTimeRange(insertedRange, toDuration: slowDuration)

        // Resolve output URL.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = docs.appendingPathComponent(outputFileName)
        // Remove stale export if present.
        try? FileManager.default.removeItem(at: outputURL)

        guard let exporter = AVAssetExportSession(asset: composition,
                                                   presetName: Self.outputPreset) else {
            throw ExportError.compositionFailed
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = false

        await exporter.export()

        switch exporter.status {
        case .completed:
            return outputURL
        case .failed:
            throw ExportError.exportFailed(exporter.error?.localizedDescription ?? "unknown")
        case .cancelled:
            throw ExportError.exportFailed("Export cancelled.")
        default:
            throw ExportError.exportFailed("Unexpected export status: \(exporter.status.rawValue)")
        }
    }
}
