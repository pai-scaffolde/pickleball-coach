import Foundation
import AVFoundation

// SCA-1904 M3 headless verification harness.
// Compiles the REAL SegmentationService + SlowMoExportService against real repo
// fixtures and proves:
//   (1) single-rep canonical fixture -> exactly 1 clip matching ground truth
//       (sanity: the unit suite already asserts IoU>=0.70 here);
//   (2) real 90s multi-rep footage (Navratil forehand drives) -> 3-6 clips,
//       the service's design target band;
//   (3) slow-mo export from the real video -> ~4x clip a player can open.
//
// JointPosition is redeclared here (it lives in PoseAnalysisResult.swift, which
// drags Vision-only deps); the shape matches the app model exactly.
struct JointPosition: Codable, Hashable {
    let x: Float
    let y: Float
    let confidence: Float
}

private struct TimelineWrapper: Decodable { let frames: [PoseFrame] }

// Schema of docs/artifacts/sca1869-poses/*-poses-v0.json (real extracted poses).
private struct PoseArtifact: Decodable {
    struct Sample: Decodable {
        let timestamp: Double
        let joints: [String: JointPosition]
    }
    let jointSamples: [Sample]
    let videoDurationSeconds: Double
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data(("FAIL: " + msg + "\n").utf8))
    exit(1)
}

let repoRoot = URL(fileURLWithPath: #file)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let fixtures = repoRoot.appendingPathComponent("tests/fixtures")
let poses = repoRoot.appendingPathComponent("docs/artifacts/sca1869-poses")

// MARK: - 1. Single-rep canonical fixture -> 1 clip (sanity).

let timelineURL = fixtures.appendingPathComponent("forehand-pose-timeline-v0.json")
let canonFrames = (try? JSONDecoder().decode(
    TimelineWrapper.self, from: Data(contentsOf: timelineURL)))?.frames ?? []
guard !canonFrames.isEmpty else { fail("decoded 0 frames from canonical timeline") }
let canonDur = (canonFrames.last?.timestamp ?? 0) + 0.5
let canonSeg = SegmentationService().segment(frames: canonFrames, videoDuration: canonDur)
print("CANONICAL (single-rep): \(canonSeg.clips.count) clip(s) on \(canonFrames.count) frames")
for c in canonSeg.clips {
    print(String(format: "  %.2f-%.2fs conf %.2f", c.startTime, c.endTime, c.confidence))
}
guard canonSeg.clips.count == 1 else { fail("single-rep fixture should yield 1 clip, got \(canonSeg.clips.count)") }
print("PASS: single rep -> 1 clip")

// MARK: - 2. Real multi-rep footage -> 3-6 clips (design-target band).

let artURL = poses.appendingPathComponent("forehand-navratil-poses-v0.json")
guard let artData = try? Data(contentsOf: artURL),
      let art = try? JSONDecoder().decode(PoseArtifact.self, from: artData) else {
    fail("could not read/decode \(artURL.path)")
}
let multiFrames = art.jointSamples.map {
    PoseFrame(timestamp: $0.timestamp, joints: $0.joints, bodyDetected: !$0.joints.isEmpty)
}
let multiSeg = SegmentationService().segment(frames: multiFrames, videoDuration: art.videoDurationSeconds)
print("\nNAVRATIL (real 90s, \(multiFrames.count) samples): \(multiSeg.clips.count) clips")
for (i, c) in multiSeg.clips.enumerated() {
    print(String(format: "  clip %d: %.2f-%.2fs  conf %.2f", i + 1, c.startTime, c.endTime, c.confidence))
}
if let r = multiSeg.lowConfidenceReason { print("  lowConfidenceReason: \(r)") }
guard (3...6).contains(multiSeg.clips.count) else {
    fail("real multi-rep footage expected 3-6 clips, got \(multiSeg.clips.count)")
}
print("PASS: real footage -> \(multiSeg.clips.count) clips (in 3-6 band)")

// MARK: - 3. Slow-mo export from the real video -> ~4x, playable.

let videoURL = fixtures.appendingPathComponent("yt-forehand-drive-navratil-v0.mp4")
guard FileManager.default.fileExists(atPath: videoURL.path) else { fail("missing \(videoURL.path)") }
let clip = multiSeg.clips[0]

let sem = DispatchSemaphore(value: 0)
Task {
    let srcClipDur = clip.endTime - clip.startTime
    do {
        let out = try await SlowMoExportService().export(
            sourceURL: videoURL, clip: clip, outputFileName: "sca1904-harness-export.mov")
        let outAsset = AVURLAsset(url: out)
        let outDur = (try? await outAsset.load(.duration)).map { CMTimeGetSeconds($0) } ?? 0
        let expected = srcClipDur * SlowMoExportService.slowFactor
        let pctErr = abs(outDur - expected) / expected * 100
        let vTracks = (try? await outAsset.loadTracks(withMediaType: .video)) ?? []
        let playable = (try? await outAsset.load(.isPlayable)) ?? false
        print(String(format: "\nEXPORT: src-clip %.2fs -> out %.2fs (expected %.2fs, err %.1f%%)",
                     srcClipDur, outDur, expected, pctErr))
        print("  \(out.lastPathComponent)  videoTracks=\(vTracks.count)  isPlayable=\(playable)")
        if pctErr > 5.0 { fail("4x duration off by \(String(format: "%.1f", pctErr))%") }
        if vTracks.isEmpty { fail("no video track in export") }
        if !playable { fail("export not playable") }
        print("PASS: 4x export within +/-5%, playable, has video track")
        try? FileManager.default.removeItem(at: out)
    } catch { fail("export threw: \(error)") }
    sem.signal()
}
sem.wait()
print("\nALL CHECKS PASSED")
