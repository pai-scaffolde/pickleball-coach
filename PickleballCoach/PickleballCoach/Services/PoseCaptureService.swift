import Foundation
import Vision
import AVFoundation

// Apple Vision body-pose extraction for a single pickleball shot clip.
// Run analyze() on a background task — it issues synchronous Vision requests
// and blocks a thread until all sampled frames are processed.
final class PoseCaptureService {

    enum ServiceError: LocalizedError {
        case videoNotReadable
        case noDetectedPoses

        var errorDescription: String? {
            switch self {
            case .videoNotReadable: "Cannot open video for pose analysis."
            case .noDetectedPoses: "No body poses detected in video. Check framing and lighting."
            }
        }
    }

    // Joints tracked for pickleball forehand drive analysis.
    private static let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .neck,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle,
        .root
    ]

    // Human-readable keys for JSON output and UI display.
    private static let jointNames: [VNHumanBodyPoseObservation.JointName: String] = [
        .nose: "nose",
        .neck: "neck",
        .leftShoulder: "left_shoulder",
        .rightShoulder: "right_shoulder",
        .leftElbow: "left_elbow",
        .rightElbow: "right_elbow",
        .leftWrist: "left_wrist",
        .rightWrist: "right_wrist",
        .leftHip: "left_hip",
        .rightHip: "right_hip",
        .leftKnee: "left_knee",
        .rightKnee: "right_knee",
        .leftAnkle: "left_ankle",
        .rightAnkle: "right_ankle",
        .root: "root"
    ]

    // Sample every N frames. 4 → ~7.5fps at 30fps source (good balance of coverage vs speed).
    let samplingInterval: Int
    // Joints below this confidence threshold are excluded from output entirely.
    let minConfidence: Float

    init(samplingInterval: Int = 4, minConfidence: Float = 0.30) {
        self.samplingInterval = max(1, samplingInterval)
        self.minConfidence = minConfidence
    }

    func analyze(
        videoURL: URL,
        sessionId: UUID,
        shotType: String = "forehand_drive"
    ) async throws -> PoseAnalysisResult {
        let asset = AVURLAsset(url: videoURL)

        let duration: CMTime
        let videoTracks: [AVAssetTrack]
        do {
            duration = try await asset.load(.duration)
            videoTracks = try await asset.loadTracks(withMediaType: .video)
        } catch {
            throw ServiceError.videoNotReadable
        }
        guard let videoTrack = videoTracks.first else { throw ServiceError.videoNotReadable }

        let fps = try await videoTrack.load(.nominalFrameRate)
        let totalSeconds = CMTimeGetSeconds(duration)
        let totalFrames = Int((totalSeconds * Double(fps)).rounded())
        let interval = samplingInterval
        let minConf = minConfidence

        var sampleTimes: [(frameIndex: Int, seconds: Double)] = []
        var f = 0
        while f < totalFrames {
            sampleTimes.append((f, Double(f) / Double(fps)))
            f += interval
        }

        let videoURLForTask = videoURL
        let samples: [JointSample] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let gen = AVAssetImageGenerator(asset: AVURLAsset(url: videoURLForTask))
                    gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
                    gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
                    gen.appliesPreferredTrackTransform = true
                    // Downsample for speed — Vision pose model works well at 480px.
                    gen.maximumSize = CGSize(width: 480, height: 480)

                    let request = VNDetectHumanBodyPoseRequest()
                    var results: [JointSample] = []

                    for (frameIdx, seconds) in sampleTimes {
                        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
                        guard let cgImage = try? gen.copyCGImage(at: cmTime, actualTime: nil) else { continue }

                        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                        try handler.perform([request])
                        guard let obs = request.results?.first else { continue }

                        var joints: [String: JointPosition] = [:]
                        for jn in PoseCaptureService.trackedJoints {
                            if let pt = try? obs.recognizedPoint(jn),
                               pt.confidence >= minConf,
                               let key = PoseCaptureService.jointNames[jn] {
                                joints[key] = JointPosition(
                                    x: Float(pt.location.x),
                                    y: Float(pt.location.y),
                                    confidence: Float(pt.confidence)
                                )
                            }
                        }
                        if !joints.isEmpty {
                            results.append(JointSample(
                                timestamp: seconds,
                                frameIndex: frameIdx,
                                joints: joints
                            ))
                        }
                    }
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        if samples.isEmpty { throw ServiceError.noDetectedPoses }

        let report = buildReport(samples: samples, totalSampleCount: sampleTimes.count)
        return PoseAnalysisResult(
            sessionId: sessionId,
            shotType: shotType,
            analyzedAt: Date(),
            videoPath: videoURL.lastPathComponent,
            videoDurationSeconds: totalSeconds,
            originalFrameCount: totalFrames,
            samplingInterval: interval,
            sampledFrameCount: samples.count,
            jointSamples: samples,
            confidenceReport: report
        )
    }

    // MARK: - Confidence report

    private func buildReport(samples: [JointSample], totalSampleCount: Int) -> ConfidenceReport {
        var acc: [String: [Float]] = [:]
        for sample in samples {
            for (k, v) in sample.joints {
                acc[k, default: []].append(v.confidence)
            }
        }

        var reliability: [String: JointReliability] = [:]
        for (name, confs) in acc {
            reliability[name] = JointReliability(
                meanConfidence: confs.reduce(0, +) / Float(confs.count),
                minConfidence: confs.min() ?? 0,
                framesHighConfidence: confs.filter { $0 > 0.70 }.count,
                framesMedConfidence: confs.filter { $0 > 0.50 }.count,
                totalFrames: totalSampleCount
            )
        }

        // Contact zone = middle 40% of the clip (forehand drive contact typically peaks here).
        let lo = Int(Double(samples.count) * 0.30)
        let hi = min(Int(Double(samples.count) * 0.70), samples.count - 1)
        let zone = samples.count > 4 ? Array(samples[lo...hi]) : samples

        func zoneMean(key: String) -> Float {
            let c = zone.compactMap { $0.joints[key]?.confidence }
            return c.isEmpty ? 0 : c.reduce(0, +) / Float(c.count)
        }
        let contactZoneReliable = zoneMean(key: "right_wrist") > 0.60 &&
                                  zoneMean(key: "right_elbow") > 0.65

        let reliableCount = reliability.values.filter {
            $0.meanConfidence >= 0.65 &&
            Float($0.framesHighConfidence) >= Float(totalSampleCount) * 0.45
        }.count
        let overallReliable = reliableCount >= 6

        var notes: [String] = []
        if overallReliable && contactZoneReliable {
            notes.append("Pose pipeline validated for forehand drive analysis on this footage.")
            notes.append("Unblocks Milestone 2: SCA-1824 (biomechanics metrics) and SCA-1823 (LLM coach feedback).")
        } else {
            if !contactZoneReliable {
                notes.append("Wrist/elbow confidence drops near contact. Use 60fps+ or slow-motion source for contact-zone accuracy.")
            }
            if !overallReliable {
                notes.append("Fewer than 6 key joints are reliable. Use full-body framing at 2–3m with a clear background.")
            }
        }

        return ConfidenceReport(
            jointReliability: reliability,
            contactZoneReliable: contactZoneReliable,
            overallReliable: overallReliable,
            notes: notes
        )
    }
}
