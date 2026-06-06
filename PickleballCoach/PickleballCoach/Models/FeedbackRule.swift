import Foundation

enum RuleConditionType: String, Codable {
    case below        // value < threshold → fires
    case above        // value > threshold → fires
    case insideRange  // okMin ≤ value ≤ okMax → fires (strength condition)
    case outsideRange // value < okMin || value > okMax → fires (improvement)
}

/// A coach-reviewed rule mapping a computed metric to coaching feedback.
/// All thresholds and observation text are static data authored by a human coach.
/// The engine evaluates conditions and substitutes values; it does not generate judgments.
struct FeedbackRule {
    let ruleId: String
    let phaseIndex: Int
    let phaseTitle: String
    let metricName: String
    let scoreDimensionLabel: String
    /// Joints required in each window sample; missing joints → .noData confidence.
    let requiredJoints: [String]
    /// Minimum contributing frames for confidence ≥ .medium.
    let minFrames: Int
    /// Normalized window within the clip's joint sample timeline (0.0 = start, 1.0 = end).
    let windowStart: Double
    let windowEnd: Double
    let conditionType: RuleConditionType
    let threshold: Double?
    let okMin: Double?
    let okMax: Double?
    let higherIsBetter: Bool
    let severity: FeedbackSeverity
    /// Observation text template. Tokens: {value} → formatted float, {value_int} → int.
    let observationTemplate: String
    let correction: String
    let drill: String
    let highlightJointNames: [String]

    /// Whether this rule's condition is met for a given metric value.
    func fires(for value: Double) -> Bool {
        switch conditionType {
        case .below:
            return threshold.map { value < $0 } ?? false
        case .above:
            return threshold.map { value > $0 } ?? false
        case .insideRange:
            guard let lo = okMin, let hi = okMax else { return false }
            return value >= lo && value <= hi
        case .outsideRange:
            guard let lo = okMin, let hi = okMax else { return false }
            return value < lo || value > hi
        }
    }

    /// Derives a 0–100 score. Centered on the ideal range; decays outside it.
    func score(for value: Double) -> Int {
        guard let lo = okMin, let hi = okMax else {
            return (fires(for: value) && severity == .strength) ? 80 : 40
        }
        let center = (lo + hi) / 2.0
        let halfWidth = max((hi - lo) / 2.0, 1e-6)
        let deviation = abs(value - center)
        let normalized = deviation / halfWidth
        let raw = max(0.0, 1.0 - max(0.0, normalized - 1.0) * 0.5)
        return min(100, Int((raw * 100).rounded()))
    }

    /// Substitutes tokens in the observation template:
    ///   {value}     → 1-decimal float (e.g. "1.2")
    ///   {value_int} → rounded integer (e.g. "155")
    ///   {value_pct} → value × 100 as integer (e.g. "87" for ratio 0.87)
    func formatObservation(_ value: Double) -> String {
        observationTemplate
            .replacingOccurrences(of: "{value}", with: String(format: "%.1f", value))
            .replacingOccurrences(of: "{value_int}", with: "\(Int(value.rounded()))")
            .replacingOccurrences(of: "{value_pct}", with: "\(Int((value * 100).rounded()))")
    }
}
