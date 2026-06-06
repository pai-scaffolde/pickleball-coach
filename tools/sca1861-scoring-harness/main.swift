import Foundation

// SCA-1861 mechanics-scoring harness.
// Compiles the REAL MechanicsScoringEngine (+ ComparisonEngine it reuses) headless
// and scores a [PoseFrame] timeline against the generic reference exemplar, writing
// a MechanicsScore artifact. Pure Foundation; see verify_swift_parity.sh.
//
// Usage: sca1861-harness <pose-timeline.json> <reference.json> <out.json> [clipId]

struct Timeline: Codable { let frames: [PoseFrame] }

let args = CommandLine.arguments
guard args.count == 4 || args.count == 5 else {
    FileHandle.standardError.write("usage: sca1861-harness <timeline.json> <reference.json> <out.json> [clipId]\n".data(using: .utf8)!)
    exit(2)
}

let timelineURL = URL(fileURLWithPath: args[1])
let refURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])
let clipId = UUID(uuidString: args.count == 5 ? args[4] : "00000000-0000-0000-0000-000000001861")
    ?? UUID(uuidString: "00000000-0000-0000-0000-000000001861")!

do {
    let timeline = try JSONDecoder().decode(Timeline.self, from: try Data(contentsOf: timelineURL))
    let reference = try JSONDecoder().decode(ReferenceExemplar.self, from: try Data(contentsOf: refURL))

    let clip = ClipInterval(id: clipId, startTime: timeline.frames.first?.timestamp ?? 0,
                            endTime: timeline.frames.last?.timestamp ?? 0,
                            strokeType: reference.strokeType, confidence: 1.0)

    let engine = MechanicsScoringEngine(minJointConfidence: 0.5)
    let score = engine.score(frames: timeline.frames, clip: clip, reference: reference)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(score).write(to: outURL)

    print("SCA-1861 mechanics score complete")
    print("  stroke:      \(score.strokeType)")
    print("  keyFrame ts: \(score.keyFrameTimestamp)s")
    print("  categories:  \(score.scores.count)")
    for o in score.observations {
        print("  - \(o.severity.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0)) \(o.observation)")
    }
    print("  wrote: \(outURL.path)")
} catch {
    FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
    exit(1)
}
