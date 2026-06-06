import Foundation

// Aggregated mechanics scores for one ClipInterval, keyed by evaluation category.
// scores maps category label → 0–100 (e.g. ["contact_point": 82.0, "hip_rotation": 67.0]).
struct MechanicsScore: Identifiable, Codable {
    let id: UUID
    let clipId: UUID
    let strokeType: String
    let scores: [String: Double]
    let observations: [FeedbackObservation]
}
