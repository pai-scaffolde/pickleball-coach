import Foundation

// SCA-1910 timeline-dump tool.
//
// Runs PoseExtractionService (Apple Vision) over a bundled clip on macOS and
// dumps the resulting [PoseFrame] as a plain JSON array — the exact format
// AnalysisProgressView.persist(_:) writes. The output is meant to be bundled
// into the app as a pre-baked timeline so the simulator fallback can load it
// without running live Vision.
//
// Usage: timeline-dump <video> <output.json>

let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: timeline-dump <video> <output.json>\n".utf8))
    exit(2)
}

let videoPath = args[0]
let outputPath = args[1]

let sema = DispatchSemaphore(value: 0)

Task {
    let url = URL(fileURLWithPath: videoPath)
    do {
        var lastPct = -1
        let frames = try await PoseExtractionService().extract(videoURL: url) { progress in
            if progress.totalFrames > 0, progress.phase == .extracting {
                let pct = (progress.framesProcessed * 100) / progress.totalFrames
                if pct != lastPct && pct % 10 == 0 {
                    lastPct = pct
                    print("  \(pct)%  (\(progress.framesProcessed)/\(progress.totalFrames))")
                }
            }
        }

        let detected = frames.filter(\.bodyDetected).count
        let coveragePct = Double(detected) / Double(frames.count) * 100
        print(String(format: "Extracted %d frames, %d body-detected (%.1f%% coverage)",
                     frames.count, detected, coveragePct))

        // Encode as a plain [PoseFrame] array — same encoder config as
        // AnalysisProgressView.persist(_:) so the app can decode it directly.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(frames)
        try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        print("Wrote \(data.count) bytes to \(outputPath)")

        // Verify the gate passes on this data.
        let gate = CaptureQualityGate.evaluate(frames, videoDuration: nil)
        if gate.passed {
            print("CaptureQualityGate: ✅ PASS — bundled timeline will be accepted by the fallback.")
        } else {
            print("CaptureQualityGate: ❌ REJECT — \(gate.rejections)")
            exit(1)
        }
    } catch {
        FileHandle.standardError.write(Data("ERROR: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
    sema.signal()
}

sema.wait()
exit(0)
