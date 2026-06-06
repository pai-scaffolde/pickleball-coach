import Foundation

// SCA-1824 comparison harness.
// Runs ComparisonEngine over a user pose artifact + a generic reference
// exemplar and writes a comparison artifact. Pure Foundation; compiled headless
// with the app's Foundation-only sources. See docs/SIDE_BY_SIDE_COMPARISON.md.
//
// Usage: sca1824-harness <userArtifact.json> <reference.json> <out.json>

struct UserArtifact: Codable {
    let shotType: String?
    let jointSamples: [PhasePose]   // PhasePose ignores extra keys (frameIndex, timestamp)
}

struct OutputDoc: Codable {
    struct Meta: Codable {
        let artifact_type: String
        let issue: String
        let generated_by: String
        let user_source: String
        let reference_source: String
        let note: String
    }
    let _meta: Meta
    let report: ComparisonReport
}

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: sca1824-harness <user.json> <reference.json> <out.json>\n".data(using: .utf8)!)
    exit(2)
}

let userURL = URL(fileURLWithPath: args[1])
let refURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])

do {
    let userData = try Data(contentsOf: userURL)
    let user = try JSONDecoder().decode(UserArtifact.self, from: userData)

    let refData = try Data(contentsOf: refURL)
    let reference = try JSONDecoder().decode(ReferenceExemplar.self, from: refData)

    let engine = ComparisonEngine(minJointConfidence: 0.5)
    let report = engine.compare(user: user.jointSamples, reference: reference)

    let doc = OutputDoc(
        _meta: .init(
            artifact_type: "side_by_side_comparison_report",
            issue: "SCA-1824",
            generated_by: "ComparisonEngine (range/delta on scale-normalized features, no ghost overlay)",
            user_source: userURL.lastPathComponent,
            reference_source: refURL.lastPathComponent,
            note: "Phase-keyed comparison of a user clip against a pose-only generic exemplar (Option C). No pixel alignment, no pro footage, no ghost overlay."
        ),
        report: report
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let outData = try encoder.encode(doc)
    try outData.write(to: outURL)

    // Console summary for the heartbeat evidence log.
    print("SCA-1824 comparison complete")
    print("  reference: \(report.referenceId) [\(report.referenceRightsStatus)]")
    print("  method:    \(report.method) | ghostOverlay=\(report.ghostOverlay) | alignment=\(report.alignment)")
    print("  overall:   \(report.overallScore)/100 across \(report.measuredPhaseCount) measured phases")
    for p in report.phases {
        let mark = p.measured ? String(format: "%.1f", p.phaseScore) : "n/a"
        print("  - \(p.phase.padding(toLength: 16, withPad: " ", startingAt: 0)) score=\(mark)  frames=\(p.userFrameCount)")
    }
    print("  wrote: \(outURL.path)")
} catch {
    FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
    exit(1)
}
