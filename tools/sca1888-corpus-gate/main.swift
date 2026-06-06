import Foundation

// SCA-1888 corpus gate harness.
//
// Runs the REAL app pipeline — PoseExtractionService (Apple Vision
// VNDetectHumanBodyPoseRequest) → CaptureQualityGate — over real pickleball
// footage, headless on macOS. Purpose: empirically settle whether real
// (non-device-captured) pickleball footage passes CaptureQualityGate.
//
// Usage: corpus-gate <video1> [video2 ...]

let videos = Array(CommandLine.arguments.dropFirst())
guard !videos.isEmpty else {
    FileHandle.standardError.write(Data("usage: corpus-gate <video> [...]\n".utf8))
    exit(2)
}

let sema = DispatchSemaphore(value: 0)
var anyPassed = false

Task {
    for path in videos {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        do {
            let svc = PoseExtractionService()
            let frames = try await svc.extract(videoURL: url)
            let total = frames.count
            let detected = frames.filter(\.bodyDetected).count
            let coverage = total > 0 ? Double(detected) / Double(total) : 0
            let result = CaptureQualityGate.evaluate(frames, videoDuration: nil)

            print("── \(name)")
            print("   sampled frames     : \(total)")
            print("   bodyDetected frames: \(detected)  (need ≥ \(CaptureQualityGate.minimumDetectedFrames))")
            print(String(format: "   coverage           : %.1f%%  (need ≥ %.0f%%)",
                         coverage * 100, CaptureQualityGate.minimumCoverageRatio * 100))
            if result.passed {
                anyPassed = true
                print("   GATE VERDICT       : ✅ PASS")
            } else {
                print("   GATE VERDICT       : ❌ REJECT")
                for r in result.rejections { print("     - \(r)") }
            }
            print("")
        } catch {
            print("── \(name)")
            print("   GATE VERDICT       : ❌ ERROR — \(error.localizedDescription)\n")
        }
    }
    sema.signal()
}
sema.wait()
exit(anyPassed ? 0 : 1)
