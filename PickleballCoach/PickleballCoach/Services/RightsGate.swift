import Foundation

// Hard enforcement gate for asset rights before any asset is surfaced in a
// bundled or public context.
//
// Loads docs/assets/exemplar-rights-register.json (bundled as a resource) and
// validates that the requested asset has the required usage_scope.
//
// Gate coverage: SCA-1826 Gate 7 (no named-pro/likeness/broadcast/social footage
// without written rights).
//
// Usage:
//   try RightsGate.check(assetId: "exemplar-generic-pose-forehand-v0",
//                        requiredScope: .bundledApp)
struct RightsGate {

    // MARK: - Usage scope hierarchy

    enum UsageScope: String, Codable, Comparable {
        case none            = "none"
        case internalDev     = "internal-dev"
        case bundledApp      = "bundled-app"
        case publicMarketing = "public-marketing"

        private var rank: Int {
            switch self {
            case .none:            return 0
            case .internalDev:     return 1
            case .bundledApp:      return 2
            case .publicMarketing: return 3
            }
        }

        static func < (lhs: UsageScope, rhs: UsageScope) -> Bool { lhs.rank < rhs.rank }

        /// True when this scope permits the required scope's surface.
        func satisfies(_ required: UsageScope) -> Bool { self >= required }
    }

    // MARK: - Errors

    enum GateError: LocalizedError {
        case registerNotFound
        case malformedRegister(underlying: Error)
        case assetNotRegistered(id: String)
        case rightsNotCleared(id: String, status: String)
        case insufficientScope(id: String, has: UsageScope, needs: UsageScope)

        var errorDescription: String? {
            switch self {
            case .registerNotFound:
                return "Rights register not found in app bundle. Bundle docs/assets/exemplar-rights-register.json as a resource."
            case .malformedRegister(let e):
                return "Rights register is malformed: \(e.localizedDescription)"
            case .assetNotRegistered(let id):
                return "Asset '\(id)' is missing from the rights register. Register it before shipping."
            case .rightsNotCleared(let id, let status):
                return "Asset '\(id)' has status '\(status)'. Obtain written rights clearance before shipping."
            case .insufficientScope(let id, let has, let needs):
                return "Asset '\(id)' is cleared for '\(has.rawValue)' but '\(needs.rawValue)' is required."
            }
        }
    }

    // MARK: - Gate check

    /// Throws if the asset is not in the register, rights are uncleared, or
    /// usage scope is insufficient for the requested surface.
    static func check(assetId: String, requiredScope: UsageScope) throws {
        let assets = try loadRegister()
        guard let asset = assets.first(where: { $0.id == assetId }) else {
            throw GateError.assetNotRegistered(id: assetId)
        }
        let unclearedStatuses: Set<String> = ["pending", "aspirational-reference", "prohibited"]
        if unclearedStatuses.contains(asset.rightsStatus) {
            throw GateError.rightsNotCleared(id: assetId, status: asset.rightsStatus)
        }
        let currentScope = UsageScope(rawValue: asset.usageScope) ?? .none
        guard currentScope.satisfies(requiredScope) else {
            throw GateError.insufficientScope(id: assetId, has: currentScope, needs: requiredScope)
        }
    }

    // MARK: - Register loading

    private struct RegisterAsset: Decodable {
        let id: String
        let usageScope: String
        let rightsStatus: String

        enum CodingKeys: String, CodingKey {
            case id
            case usageScope  = "usage_scope"
            case rightsStatus = "rights_status"
        }
    }

    private struct Register: Decodable {
        let assets: [RegisterAsset]
    }

    private static func loadRegister() throws -> [RegisterAsset] {
        guard let url = Bundle.main.url(forResource: "exemplar-rights-register",
                                        withExtension: "json") else {
            throw GateError.registerNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Register.self, from: data).assets
        } catch {
            throw GateError.malformedRegister(underlying: error)
        }
    }
}
