import Foundation

// MARK: - SCA-1911 — "Shots to Practice" catalogue
//
// A browsable library of clean, coachable example shots. Each entry is a shot a
// player can review and mimic: a short clip (when rights permit bundling) plus
// the idealized reference skeleton and the cues to watch for.
//
// The catalogue is bundled JSON (`practice-shots-catalog.json`). Rights are
// enforced at access time, not decode time: a shot decodes fine, but its clip
// URL only resolves if the clip's rights-register row clears `bundled-app`
// distribution (RightsGate). A shot whose clip is not cleared still appears in
// the library as a pose-only reference — it just never surfaces a playable clip.

struct PracticeShot: Identifiable, Codable {
    let id: String
    let name: String                 // "Forehand Drive"
    let strokeType: String           // "forehand_drive"
    let summary: String              // one-line description shown in the list
    let whatToWatch: [String]        // coaching cues the player should mimic
    let clipResource: String?        // bundled clip name (sans extension), or nil
    let clipExtension: String?       // e.g. "mp4"
    let clipAssetID: String?         // rights-register id for the clip
    let referenceExemplar: String?   // pose-only exemplar JSON name (skeleton mimic panel)

    /// Resolves a playable clip URL only when the clip's rights asset clears
    /// `bundled-app`. Returns nil for pose-only shots or uncleared clips, so the
    /// UI can never play a clip the register doesn't permit bundling.
    func clipURL(in bundle: Bundle = .main) -> URL? {
        guard let clipResource, let clipExtension, let clipAssetID else { return nil }
        do {
            try RightsGate.check(assetId: clipAssetID, requiredScope: .bundledApp)
        } catch {
            return nil
        }
        return bundle.url(forResource: clipResource, withExtension: clipExtension)
    }

    /// The idealized reference skeleton (first/"ready" phase) used to draw the
    /// "shot to mimic" panel when no playable clip is available. Pose-only
    /// generic exemplars are rights-safe (no identifiable person) and are
    /// themselves gated through RightsGate by `ReferenceExemplar.load`.
    func referenceFrame(in bundle: Bundle = .main) -> PoseFrame? {
        guard let referenceExemplar,
              let exemplar = try? ReferenceExemplar.load(named: referenceExemplar, in: bundle),
              let phase = exemplar.phases.first else { return nil }
        return PoseFrame(timestamp: 0, joints: phase.pose, bodyDetected: true)
    }
}

/// Bundled catalogue container. Loads defensively: a missing or malformed
/// catalogue yields an empty library rather than crashing the Shots screen.
struct PracticeShotCatalog: Codable {
    let version: String
    let shots: [PracticeShot]

    static func load(in bundle: Bundle = .main) -> PracticeShotCatalog {
        guard let url = bundle.url(forResource: "practice-shots-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(PracticeShotCatalog.self, from: data) else {
            return PracticeShotCatalog(version: "v0", shots: [])
        }
        return catalog
    }
}
