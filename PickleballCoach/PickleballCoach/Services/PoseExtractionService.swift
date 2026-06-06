import Foundation
import Vision
import AVFoundation
import ImageIO

// Time-based Apple Vision body-pose extraction (10 Hz default).
//
// Distinct from PoseCaptureService (frame-index sampler): this service samples
// at a wall-clock cadence so it stays correct across 24–240 fps sources (D9).
// Streams frames via AVAssetImageGenerator — never loads the whole video.
// Produces the durable PoseFrame pipeline contract.
final class PoseExtractionService {

    static let defaultSampleRate: Double = 10.0      // Hz
    static let maxDurationSeconds: Double = 300.0    // 5-minute guard
    static let minimumJointCount: Int = 6            // below this → bodyDetected = false

    // Samples per second of source video.
    let sampleRate: Double
    // Joints below this confidence are excluded from the frame.
    let minJointConfidence: Float

    struct ExtractionProgress: Sendable {
        enum Phase: String, Sendable { case loading, extracting, complete }
        let phase: Phase
        let framesProcessed: Int
        let totalFrames: Int
    }

    enum ExtractionError: LocalizedError {
        case videoNotReadable
        case durationExceedsLimit(seconds: Double)
        case noBodyDetected

        var errorDescription: String? {
            switch self {
            case .videoNotReadable:
                return "Cannot open video for pose extraction."
            case .durationExceedsLimit(let seconds):
                return String(format: "Video is %.0fs — exceeds the %.0fs limit. Trim to a single shot.",
                              seconds, PoseExtractionService.maxDurationSeconds)
            case .noBodyDetected:
                return "No body detected in any frame. Check framing and lighting."
            }
        }
    }

    // Joints tracked for pickleball forehand-drive analysis (same set as PoseCaptureService).
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

    init(sampleRate: Double = Self.defaultSampleRate, minJointConfidence: Float = 0.30) {
        self.sampleRate = sampleRate > 0 ? sampleRate : Self.defaultSampleRate
        self.minJointConfidence = minJointConfidence
    }

    // MARK: - Extraction

    func extract(
        videoURL: URL,
        onProgress: ((ExtractionProgress) -> Void)? = nil
    ) async throws -> [PoseFrame] {
        onProgress?(ExtractionProgress(phase: .loading, framesProcessed: 0, totalFrames: 0))

        let asset = AVURLAsset(url: videoURL)
        let duration: CMTime
        let videoTracks: [AVAssetTrack]
        do {
            duration = try await asset.load(.duration)
            videoTracks = try await asset.loadTracks(withMediaType: .video)
        } catch {
            throw ExtractionError.videoNotReadable
        }
        guard let videoTrack = videoTracks.first else { throw ExtractionError.videoNotReadable }

        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds.isFinite, totalSeconds > 0 else { throw ExtractionError.videoNotReadable }
        guard totalSeconds <= Self.maxDurationSeconds else {
            throw ExtractionError.durationExceedsLimit(seconds: totalSeconds)
        }

        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let orientation = imageOrientation(from: preferredTransform)

        // Time-based sampling: independent of source fps.
        let step = 1.0 / sampleRate
        var timestamps: [Double] = []
        var t = 0.0
        while t < totalSeconds {
            timestamps.append(t)
            t += step
        }

        let totalFrames = timestamps.count
        let videoURLForTask = videoURL
        let minConf = minJointConfidence
        let halfStep = step / 2.0

        let frames: [PoseFrame] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let gen = AVAssetImageGenerator(asset: AVURLAsset(url: videoURLForTask))
                // Orientation is normalized via the Vision request, NOT the generator.
                gen.appliesPreferredTrackTransform = false
                gen.maximumSize = CGSize(width: 480, height: 480)
                gen.requestedTimeToleranceBefore = CMTime(seconds: halfStep, preferredTimescale: 600)
                gen.requestedTimeToleranceAfter = CMTime(seconds: halfStep, preferredTimescale: 600)

                let request = VNDetectHumanBodyPoseRequest()
                var results: [PoseFrame] = []
                var processed = 0

                for seconds in timestamps {
                    let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
                    let frame: PoseFrame
                    if let cgImage = try? gen.copyCGImage(at: cmTime, actualTime: nil) {
                        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                        try? handler.perform([request])
                        let observation = self.highestConfidenceObservation(request.results)
                        frame = self.buildFrame(timestamp: seconds, observation: observation, minConfidence: minConf)
                    } else {
                        // Unreadable frame → empty, undetected.
                        frame = PoseFrame(timestamp: seconds, joints: [:], bodyDetected: false)
                    }
                    results.append(frame)
                    processed += 1
                    onProgress?(ExtractionProgress(phase: .extracting, framesProcessed: processed, totalFrames: totalFrames))
                }

                continuation.resume(returning: results)
            }
        }

        guard frames.contains(where: \.bodyDetected) else {
            throw ExtractionError.noBodyDetected
        }

        onProgress?(ExtractionProgress(phase: .complete, framesProcessed: totalFrames, totalFrames: totalFrames))
        return frames
    }

    // MARK: - Orientation

    // Maps a video track's preferredTransform to the CGImagePropertyOrientation that
    // Vision needs when appliesPreferredTrackTransform is disabled on the generator.
    func imageOrientation(from transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0):   return .right  // Portrait
        case (0, -1, 1, 0):   return .left   // Portrait upside-down
        case (-1, 0, 0, -1):  return .down   // Landscape left
        default:              return .up      // Landscape right (identity)
        }
    }

    // MARK: - Frame building

    // Picks the observation with the highest aggregate joint confidence (multi-person frames).
    private func highestConfidenceObservation(
        _ observations: [VNHumanBodyPoseObservation]?
    ) -> VNHumanBodyPoseObservation? {
        guard let observations, !observations.isEmpty else { return nil }
        return observations.max { meanConfidence($0) < meanConfidence($1) }
    }

    // Mean confidence across all tracked joints in an observation.
    private func meanConfidence(_ observation: VNHumanBodyPoseObservation) -> Float {
        var sum: Float = 0
        var count = 0
        for jn in Self.trackedJoints {
            if let pt = try? observation.recognizedPoint(jn) {
                sum += pt.confidence
                count += 1
            }
        }
        return count > 0 ? sum / Float(count) : 0
    }

    private func buildFrame(
        timestamp: Double,
        observation: VNHumanBodyPoseObservation?,
        minConfidence: Float
    ) -> PoseFrame {
        guard let observation else {
            return PoseFrame(timestamp: timestamp, joints: [:], bodyDetected: false)
        }

        var joints: [String: JointPosition] = [:]
        for jn in Self.trackedJoints {
            if let pt = try? observation.recognizedPoint(jn),
               pt.confidence >= minConfidence,
               let key = Self.jointNames[jn] {
                joints[key] = JointPosition(
                    x: Float(pt.location.x),
                    y: Float(pt.location.y),
                    confidence: Float(pt.confidence)
                )
            }
        }

        // Low-confidence frame: present but not reliably a body. Not an error.
        let detected = joints.count >= Self.minimumJointCount
        return PoseFrame(timestamp: timestamp, joints: joints, bodyDetected: detected)
    }
}
