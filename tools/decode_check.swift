// SCA-1867 decode-at-runtime probe.
// Compiled in CI against the real Foundation-only model/service sources, this
// executes the same JSONDecoder().decode(ReferenceExemplar.self, ...) path that
// ReferenceExemplar.load(named:) uses — proving both bundled fixtures decode
// into ReferenceExemplar at runtime (acceptance bullet 3 of SCA-1867).
import Foundation

let resourceDir = "PickleballCoach/PickleballCoach/Resources"
let fixtures = ["reference_forehand_drive_v0", "reference_backhand_drive_v0"]

var failures = 0
for name in fixtures {
    let url = URL(fileURLWithPath: "\(resourceDir)/\(name).json")
    do {
        let data = try Data(contentsOf: url)
        let exemplar = try JSONDecoder().decode(ReferenceExemplar.self, from: data)
        // Structural sanity: a usable exemplar must carry phases, each with a
        // renderable pose and at least one scoring range.
        precondition(!exemplar.phases.isEmpty, "\(name): no phases decoded")
        for phase in exemplar.phases {
            precondition(!phase.pose.isEmpty, "\(name): phase '\(phase.phase)' has empty pose")
            precondition(!phase.ranges.isEmpty, "\(name): phase '\(phase.phase)' has empty ranges")
        }
        print("✓ \(name): id=\(exemplar.id) strokeType=\(exemplar.strokeType) "
            + "phases=\(exemplar.phases.count) rights=\(exemplar.rightsStatus) scope=\(exemplar.usageScope)")
    } catch {
        print("✗ \(name): FAILED to decode — \(error)")
        failures += 1
    }
}

if failures > 0 {
    FileHandle.standardError.write("decode_check: \(failures) fixture(s) failed\n".data(using: .utf8)!)
    exit(1)
}
print("decode_check: all \(fixtures.count) fixtures decoded into ReferenceExemplar")
