import Foundation

// Rep segmentation from a pose-frame timeline using motion intensity.
//
// Algorithm: per-frame mean joint displacement (wrist/shoulder/hip) → threshold
// at 10% of global peak → group consecutive above-threshold frames with a 0.5s
// merge gap tolerance → rank by peak intensity → emit up to 6 ClipIntervals.
//
// Targets 3-6 clips (quality over count). Reports a low-confidence reason when
// the motion signal is weak or data is sparse.
final class SegmentationService: Sendable {

    struct SegmentationResult: Sendable {
        let clips: [ClipInterval]
        /// nil when segmentation is reliable; a human-readable reason otherwise.
        let lowConfidenceReason: String?
    }

    static let maxClips = 6
    static let minClipDurationSeconds: Double = 0.30
    // A region is "active" if its peak intensity is at least this fraction of global peak.
    static let motionThresholdFraction: Double = 0.10
    // Adjacent above-threshold windows within this gap are merged into one region.
    static let mergeGapSeconds: Double = 0.50

    private static let motionJoints = [
        "right_wrist", "left_wrist",
        "right_shoulder", "left_shoulder",
        "right_hip", "left_hip",
    ]

    func segment(frames: [PoseFrame], videoDuration: Double) -> SegmentationResult {
        let detected = frames.filter(\.bodyDetected)
        guard detected.count >= 3 else {
            return SegmentationResult(clips: [], lowConfidenceReason: "Not enough body-detected frames to find rep boundaries.")
        }

        let intensities = motionIntensities(frames: frames)
        guard let maxIntensity = intensities.max(), maxIntensity > 1e-10 else {
            return SegmentationResult(clips: [], lowConfidenceReason: "No motion detected in video.")
        }

        let threshold = maxIntensity * Self.motionThresholdFraction
        // Half the typical inter-frame step, used as a boundary cushion.
        let halfStep: Double = {
            guard frames.count > 1 else { return 0.05 }
            return (frames[1].timestamp - frames[0].timestamp) / 2.0
        }()

        // Collect frames above threshold in chronological order.
        var activeFrames: [(timestamp: Double, intensity: Double)] = []
        for i in 0..<frames.count {
            if intensities[i] >= threshold {
                activeFrames.append((frames[i].timestamp, intensities[i]))
            }
        }

        guard !activeFrames.isEmpty else {
            return SegmentationResult(clips: [], lowConfidenceReason: "No rep candidates found above motion threshold.")
        }

        // Group into contiguous regions, bridging gaps up to mergeGapSeconds.
        var regions: [(start: Double, end: Double, peakIntensity: Double)] = []
        var regionStart = activeFrames[0].timestamp
        var regionEnd = activeFrames[0].timestamp
        var regionPeak = activeFrames[0].intensity

        for i in 1..<activeFrames.count {
            let gap = activeFrames[i].timestamp - regionEnd
            if gap <= Self.mergeGapSeconds {
                regionEnd = activeFrames[i].timestamp
                regionPeak = max(regionPeak, activeFrames[i].intensity)
            } else {
                regions.append((start: regionStart - halfStep,
                                end: regionEnd + halfStep,
                                peakIntensity: regionPeak))
                regionStart = activeFrames[i].timestamp
                regionEnd = activeFrames[i].timestamp
                regionPeak = activeFrames[i].intensity
            }
        }
        regions.append((start: regionStart - halfStep,
                        end: regionEnd + halfStep,
                        peakIntensity: regionPeak))

        // Filter out very short windows (noise).
        let validRegions = regions.filter { $0.end - $0.start >= Self.minClipDurationSeconds }

        // Rank by peak intensity descending; take top maxClips.
        let top = Array(validRegions.sorted { $0.peakIntensity > $1.peakIntensity }.prefix(Self.maxClips))

        let clips: [ClipInterval] = top.map { r in
            ClipInterval(
                id: UUID(),
                startTime: max(0, r.start),
                endTime: min(videoDuration, r.end),
                strokeType: nil,
                confidence: r.peakIntensity / maxIntensity
            )
        }

        let lowConf: String?
        if clips.isEmpty {
            lowConf = "No valid rep segments found."
        } else if clips.allSatisfy({ $0.confidence < 0.30 }) {
            lowConf = "Low motion signal — rep boundaries may be inaccurate. Ensure the full stroke is visible."
        } else {
            lowConf = nil
        }

        return SegmentationResult(clips: clips, lowConfidenceReason: lowConf)
    }

    // MARK: - Motion intensity

    // Per-frame mean displacement of tracked joints from the previous frame.
    // Index 0 is always 0 (no previous frame).
    func motionIntensities(frames: [PoseFrame]) -> [Double] {
        var result = Array(repeating: 0.0, count: frames.count)
        for i in 1..<frames.count {
            let prev = frames[i - 1].joints
            let cur  = frames[i].joints
            var total = 0.0
            var count = 0
            for joint in Self.motionJoints {
                guard let p = prev[joint], let c = cur[joint] else { continue }
                let dx = Double(c.x - p.x)
                let dy = Double(c.y - p.y)
                total += (dx * dx + dy * dy).squareRoot()
                count += 1
            }
            result[i] = count > 0 ? total / Double(count) : 0
        }
        return result
    }
}
