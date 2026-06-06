import Foundation

// MARK: - Reference exemplar (Option C — pose-only generic, rights-safe)
//
// A bundled reference for one stroke type. It is a pose-only generic exemplar
// per docs/RIGHTS_PLAN.md: a hand-authored idealized skeleton plus generic
// ideal feature RANGES. It depicts no identifiable person and is not derived
// from any named pro's footage, so it carries usage_scope `bundled-app`.
//
// Two parts:
//   • `pose` per phase — an idealized normalized skeleton used to draw the
//     RIGHT-hand "reference" panel in the side-by-side view (no overlay on the
//     user's video).
//   • `ranges` per phase — generic ideal bands the user's measured features are
//     compared against (the actual scoring input; see ComparisonEngine).

struct ReferenceRange: Codable {
    let idealMin: Double
    let idealMax: Double
}

struct ReferencePhase: Codable {
    let phase: String
    let pose: [String: JointPosition]      // idealized normalized skeleton for rendering
    let ranges: [String: ReferenceRange]   // featureKey → generic ideal band

    /// Ranges keyed by FeatureKey, in a stable order for deterministic output.
    func sortedRanges() -> [(FeatureKey, ReferenceRange)] {
        FeatureKey.allCases.compactMap { key in
            guard let r = ranges[key.rawValue] else { return nil }
            return (key, r)
        }
    }
}

struct ReferenceExemplar: Codable {
    let id: String                 // matches a row id in docs/assets/exemplar-rights-register.json
    let strokeType: String
    let rightsStatus: String       // expected: "cleared-public"
    let usageScope: String         // expected: "bundled-app"
    let source: String
    let description: String
    let phases: [ReferencePhase]

    func phase(_ name: String) -> ReferencePhase? {
        phases.first { $0.phase == name }
    }

    /// Decodes a bundled reference JSON from the app bundle.
    static func load(named name: String, in bundle: Bundle = .main) throws -> ReferenceExemplar {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "ReferenceExemplar", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Missing bundled reference \(name).json"])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ReferenceExemplar.self, from: data)
    }
}
