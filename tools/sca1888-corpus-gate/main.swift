import Foundation

// SCA-1888 corpus gate harness.
//
// Runs the REAL app pipeline — PoseExtractionService (Apple Vision
// VNDetectHumanBodyPoseRequest) → CaptureQualityGate — over real pickleball
// footage, headless on macOS. Purpose: empirically settle whether real
// (non-device-captured) pickleball footage passes CaptureQualityGate.
//
// Usage: corpus-gate <video1> [video2 ...]

// Modes:
//   corpus-gate <video> [video2 ...]
//       Whole-clip gate verdict per video.
//   corpus-gate --corpus <windowSeconds> <outManifest.json> <video> [video2 ...]
//       Slice each real timeline into non-overlapping windows of <windowSeconds>
//       and gate each window independently, emitting a corpus manifest. Proves
//       the real pipeline yields corpus-scale gate-passing real-footage clips.

var argv = Array(CommandLine.arguments.dropFirst())
guard !argv.isEmpty else {
    FileHandle.standardError.write(Data("usage: corpus-gate [--corpus <sec> <out.json>] <video> [...]\n".utf8))
    exit(2)
}

var corpusMode = false
var windowSeconds = 3.0
var manifestPath = ""
if argv.first == "--corpus" {
    corpusMode = true
    guard argv.count >= 4, let w = Double(argv[1]) else {
        FileHandle.standardError.write(Data("usage: corpus-gate --corpus <sec> <out.json> <video> [...]\n".utf8))
        exit(2)
    }
    windowSeconds = w
    manifestPath = argv[2]
    argv = Array(argv.dropFirst(3))
}
let videos = argv

let sema = DispatchSemaphore(value: 0)
var anyPassed = false
var passCount = 0
var clipRecords: [[String: Any]] = []

func gateWhole(_ frames: [PoseFrame], name: String) {
    let total = frames.count
    let detected = frames.filter(\.bodyDetected).count
    let coverage = total > 0 ? Double(detected) / Double(total) : 0
    let result = CaptureQualityGate.evaluate(frames, videoDuration: nil)
    print("── \(name)")
    print("   sampled frames     : \(total)")
    print("   bodyDetected frames: \(detected)  (need ≥ \(CaptureQualityGate.minimumDetectedFrames))")
    print(String(format: "   coverage           : %.1f%%  (need ≥ %.0f%%)",
                 coverage * 100, CaptureQualityGate.minimumCoverageRatio * 100))
    if result.passed { anyPassed = true; print("   GATE VERDICT       : ✅ PASS") }
    else { print("   GATE VERDICT       : ❌ REJECT"); for r in result.rejections { print("     - \(r)") } }
    print("")
}

func gateWindows(_ frames: [PoseFrame], name: String) {
    guard let lastT = frames.last?.timestamp, lastT > 0 else { return }
    var start = 0.0
    var idx = 0
    while start + windowSeconds <= lastT + 0.0001 {
        let end = start + windowSeconds
        let window = frames.filter { $0.timestamp >= start && $0.timestamp < end }
        let result = CaptureQualityGate.evaluate(window, videoDuration: windowSeconds)
        let detected = window.filter(\.bodyDetected).count
        let clipId = String(format: "%@#w%02d", name, idx)
        if result.passed { passCount += 1 }
        clipRecords.append([
            "clipId": clipId,
            "source": name,
            "startSeconds": start,
            "endSeconds": end,
            "sampledFrames": window.count,
            "detectedFrames": detected,
            "passed": result.passed,
            "rejections": result.rejections.map { "\($0)" }
        ])
        print(String(format: "   %@  [%5.1f–%5.1fs]  frames=%2d detected=%2d  %@",
                     clipId, start, end, window.count, detected, result.passed ? "✅ PASS" : "❌ \(result.rejections.map{"\($0)"}.joined(separator: "; "))"))
        start = end
        idx += 1
    }
}

Task {
    for path in videos {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        do {
            let frames = try await PoseExtractionService().extract(videoURL: url)
            if corpusMode { print("── \(name)"); gateWindows(frames, name: name); print("") }
            else { gateWhole(frames, name: name) }
        } catch {
            print("── \(name)\n   ❌ ERROR — \(error.localizedDescription)\n")
        }
    }
    if corpusMode {
        let manifest: [String: Any] = [
            "_meta": [
                "issue": "SCA-1888",
                "purpose": "tooling-validation corpus — real footage windowed into independent clips and scored by the real CaptureQualityGate. NOT a beta-user corpus (does not measure human capture/feedback/recall outcomes).",
                "windowSeconds": windowSeconds,
                "gatePassingClips": passCount,
                "totalClips": clipRecords.count
            ],
            "clips": clipRecords
        ]
        if let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: manifestPath))
            print("→ wrote \(passCount) gate-passing / \(clipRecords.count) total clips to \(manifestPath)")
        }
        anyPassed = passCount > 0
    }
    sema.signal()
}
sema.wait()
exit(anyPassed ? 0 : 1)
